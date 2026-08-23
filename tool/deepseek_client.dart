import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Minimal DeepSeek chat-completions client.
///
/// The API is OpenAI-compatible, so this is a plain POST to
/// `/chat/completions` with a bearer token. Dart has no DeepSeek SDK.
class DeepSeekClient {
  DeepSeekClient({
    required this.apiKey,
    this.model = defaultModel,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _http;

  static const String _base = 'https://api.deepseek.com';

  /// Better distractors are worth the price difference: the "near miss" option
  /// is the whole exercise, and a weaker model tends to produce one that is
  /// obviously wrong. Override with `--model deepseek-v4-flash` to cut the bill
  /// to roughly a third.
  static const String defaultModel = 'deepseek-v4-pro';
  static const String cheapModel = 'deepseek-v4-flash';

  /// Off-peak prices, USD per million tokens. Peak is double.
  static const Map<String, ({double input, double output})> _offPeakPricing = {
    'deepseek-v4-pro': (input: 0.66, output: 1.98),
    'deepseek-v4-flash': (input: 0.22, output: 0.66),
  };

  /// DeepSeek bills peak rates 01:00–04:00 and 06:00–10:00 UTC on weekdays;
  /// everything else is half price.
  static bool isOffPeak(DateTime when) {
    final utc = when.toUtc();
    if (utc.weekday == DateTime.saturday || utc.weekday == DateTime.sunday) {
      return true;
    }
    final hour = utc.hour;
    final peak = (hour >= 1 && hour < 4) || (hour >= 6 && hour < 10);
    return !peak;
  }

  /// Tokens the system prompt costs, paid once per request regardless of how
  /// many words share it. This is what batching saves.
  static const int _systemPromptTokens = 700;

  /// Per-word cost of naming it in the user message.
  static const int _promptTokensPerWord = 10;

  /// Measured average output for one word: 5 sentences with 3 options each.
  static const int _outputTokensPerWord = 900;

  /// Rough cost for [words] words at [batchSize] words per request.
  static String costEstimate(
    String model,
    int words, {
    int batchSize = 1,
    DateTime? at,
  }) {
    final price = _offPeakPricing[model];
    if (price == null) return 'Unknown model "$model" — no price on file.';

    final requests = (words / batchSize).ceil();
    final inputTokens =
        requests * _systemPromptTokens + words * _promptTokensPerWord;
    final outputTokens = words * _outputTokensPerWord;

    final offPeak = isOffPeak(at ?? DateTime.now());
    final multiplier = offPeak ? 1.0 : 2.0;
    final total =
        (inputTokens / 1e6 * price.input + outputTokens / 1e6 * price.output) *
            multiplier;

    final window = offPeak ? 'off-peak' : 'PEAK (double price)';
    final buffer = StringBuffer()
      ..write('Estimated cost: ~US\$${total.toStringAsFixed(2)} ')
      ..write('($model, $window, $requests requests of $batchSize words)');
    if (!offPeak) {
      buffer
          .write('. Off-peak would be ~US\$${(total / 2).toStringAsFixed(2)}');
    }
    return buffer.toString();
  }

  /// How long to wait for a response.
  ///
  /// This has to scale with the size of the request. These are non-streaming
  /// calls, so nothing arrives until the model has written the whole answer: a
  /// 100-word batch is ~90k output tokens, which takes far longer than any
  /// fixed timeout that is sane for a small batch. Getting this wrong is
  /// expensive — the request is still generating (and still billable) when the
  /// client gives up on it.
  static Duration timeoutFor(int maxTokens) {
    const tokensPerSecond = 25; // deliberately pessimistic
    final seconds = 60 + (maxTokens / tokensPerSecond).ceil();
    return Duration(seconds: seconds);
  }

  /// Sends one prompt and returns the JSON object the model produced.
  ///
  /// DeepSeek has no schema enforcement — `json_object` only guarantees the
  /// body parses, not that it has the right shape — and the docs warn that the
  /// API occasionally returns empty content. Both are treated as retryable.
  ///
  /// [maxTokens] is the expected size of the answer. It is not sent to the API
  /// (see the request body below); it sizes the client timeout.
  Future<Map<String, Object?>> completeJson({
    required String system,
    required String prompt,
    int maxTokens = 4000,
    int maxAttempts = 4,
  }) async {
    Object? lastError;
    final timeout = timeoutFor(maxTokens);

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _http
            .post(
              Uri.parse('$_base/chat/completions'),
              headers: {
                'content-type': 'application/json',
                'authorization': 'Bearer $apiKey',
              },
              body: jsonEncode({
                'model': model,
                'response_format': {'type': 'json_object'},
                'messages': [
                  {'role': 'system', 'content': system},
                  {'role': 'user', 'content': prompt},
                ],
              }),
            )
            .timeout(timeout);

        if (response.statusCode == 429 || response.statusCode >= 500) {
          lastError = DeepSeekException(response.statusCode, response.body);
          await _backoff(attempt);
          continue;
        }
        if (response.statusCode != 200) {
          // 400/401/403 will not fix themselves; fail fast.
          throw DeepSeekException(response.statusCode, response.body);
        }

        final body =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
        final choices = (body['choices'] as List<Object?>? ?? const [])
            .cast<Map<String, Object?>>();
        if (choices.isEmpty) {
          lastError = DeepSeekException(200, 'No choices in response.');
          await _backoff(attempt);
          continue;
        }

        final choice = choices.first;
        if (choice['finish_reason'] == 'length') {
          throw DeepSeekException(
            200,
            'Response was truncated (finish_reason=length). Raise --max-tokens.',
          );
        }

        final content =
            (choice['message'] as Map<String, Object?>?)?['content'] as String?;
        if (content == null || content.trim().isEmpty) {
          // Documented DeepSeek behaviour, not a bug on our side.
          lastError = DeepSeekException(200, 'Empty content returned.');
          await _backoff(attempt);
          continue;
        }

        return jsonDecode(content) as Map<String, Object?>;
      } on DeepSeekException {
        rethrow;
      } on Object catch (error) {
        // Network blips, timeouts, and JSON that did not parse.
        lastError = error;
        if (attempt == maxAttempts) break;
        await _backoff(attempt);
      }
    }

    throw DeepSeekException(
        0, 'Gave up after $maxAttempts attempts: $lastError');
  }

  static Future<void> _backoff(int attempt) {
    // Exponential with jitter, so a rate-limited fleet of workers does not all
    // retry on the same tick.
    final base = Duration(seconds: pow(2, attempt).toInt());
    final jitter = Duration(milliseconds: Random().nextInt(1000));
    return Future<void>.delayed(base + jitter);
  }

  void close() => _http.close();
}

class DeepSeekException implements Exception {
  DeepSeekException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'DeepSeekException($statusCode): $body';
}
