import 'package:bla_bla_in_english/sentence_format.dart';

/// How many sentences every word gets. The app's scheduler walks a word through
/// these one per day, so changing it changes the pace of the whole app.
const int sentencesPerWord = 5;

/// The shape the model must return, shown as an example inside the prompt.
///
/// DeepSeek has no JSON Schema enforcement — `response_format: json_object`
/// only guarantees the body parses. So the contract lives in the prompt, and
/// [WordEntry.validate] is what actually protects the database.
const String jsonExample = '''
{
  "words": [
    {
      "word": "book",
      "sentences": [
        {
          "text": "She left her #book# open on the kitchen table.",
          "correct": "a set of printed pages bound together to be read",
          "near": "a set of blank pages bound together to be written in",
          "wrong": "a container with a lid, used for carrying tools"
        }
      ]
    },
    {
      "word": "light",
      "sentences": [
        {
          "text": "The #light# from the window woke him early.",
          "correct": "the brightness that lets us see things",
          "near": "the warmth that comes from the sun",
          "wrong": "a sudden loud noise that startles someone"
        }
      ]
    }
  ]
}''';

const String systemPrompt = '''
You write vocabulary exercises for learners of English. All output is in
English — the learner is being taught to think in English, so never translate.

You are given a list of words. For every word in the list you produce
$sentencesPerWord sentences and, for each sentence, three candidate meanings of
that word as it is used there.

The three meanings are the whole exercise, so their relationship matters:

- "correct" is the meaning the word actually carries in that sentence.
- "near" is the trap. It must be genuinely tempting: a different sense of the
  same word, the right idea at the wrong strength, a word the learner is likely
  to confuse it with, or the right meaning for a different part of speech. A
  learner who half-knows the word should hesitate. Never make it a synonym of
  "correct" — it has to be defensibly wrong.
- "wrong" is unrelated, but still a plausible-sounding dictionary definition.
  Not nonsense, not a joke — just the meaning of some other word entirely.

Rules for the sentences:

- Wrap the target word in $sentenceDivider, exactly once per sentence, e.g.
  "The ${sentenceDivider}book$sentenceDivider is on the table." Inflected forms
  are fine ("${sentenceDivider}booked$sentenceDivider"), and the marked span
  must be the target word itself, never a whole phrase.
- Vary the sentences. When a word has several common senses, spread the
  sentences across them rather than repeating one sense five times. When it has
  one sense, vary the register and the grammar instead.
- Keep sentences natural and self-contained — the learner sees no other
  context. Around 6 to 14 words.
- Write definitions the way a learner dictionary does: short, plain, and
  without using the target word itself.

Reply with json only — no prose, no markdown fence, no commentary. The json
object must have exactly this shape: a "words" array with one entry per word you
were given, in the same order, each with exactly $sentencesPerWord entries in
"sentences". Repeat the word in its "word" field exactly as it was given to you,
so each entry can be matched back. Never merge, skip, or invent words.

$jsonExample
''';

String userPromptFor(List<String> words) =>
    'Write the $sentencesPerWord sentences and their meaning options for each '
    'of these ${words.length} English words:\n'
    '${words.map((word) => '- $word').join('\n')}';

/// What came back from one multi-word request: the entries that survived, and
/// the words that did not, with the reason.
///
/// Keeping these together is the point of batching safely. A batch of 20 words
/// where the model botched one must yield 19 usable entries and one retry — not
/// 20 lost words.
class BatchOutcome {
  const BatchOutcome({required this.entries, required this.failures});

  final List<WordEntry> entries;

  /// Keyed by the requested word, so the caller can retry exactly these.
  final Map<String, String> failures;

  /// Splits a model response against the words that were asked for.
  ///
  /// Everything about the response is treated as untrusted: DeepSeek enforces
  /// no schema, and a model given 20 words can drop some, duplicate some, or
  /// invent one that was never requested.
  static BatchOutcome parse(
    Map<String, Object?> json, {
    required Map<String, int> requestedRanks,
  }) {
    final entries = <WordEntry>[];
    final failures = <String, String>{};

    final rawWords = json['words'];
    if (rawWords is! List) {
      // Nothing usable — fail every word in the batch so they are all retried.
      return BatchOutcome(
        entries: const [],
        failures: {
          for (final word in requestedRanks.keys)
            word: 'response had no "words" array (got ${rawWords.runtimeType})',
        },
      );
    }

    // Case-insensitive lookup: the model is told to echo the word verbatim, but
    // capitalising it is a harmless deviation that should not cost a retry.
    final byLowercase = {
      for (final entry in requestedRanks.entries) entry.key.toLowerCase(): entry.key,
    };
    final seen = <String>{};

    for (final (index, raw) in rawWords.indexed) {
      if (raw is! Map<String, Object?>) {
        continue; // No word attached, so nothing to blame it on; see the sweep.
      }

      final label = raw['word'];
      if (label is! String) continue;

      final requested = byLowercase[label.trim().toLowerCase()];
      if (requested == null) {
        continue; // A word nobody asked for. Drop it silently.
      }
      if (!seen.add(requested)) {
        continue; // Duplicate entry for a word already taken.
      }

      try {
        final entry = WordEntry.fromJson(
          raw,
          word: requested,
          frequencyRank: requestedRanks[requested]!,
        );
        final problems = entry.validate();
        if (problems.isEmpty) {
          entries.add(entry);
        } else {
          failures[requested] = problems.join('; ');
        }
      } on FormatException catch (error) {
        failures[requested] = 'entry $index: ${error.message}';
      }
    }

    // Anything requested that never came back at all.
    for (final word in requestedRanks.keys) {
      if (!seen.contains(word)) {
        failures[word] = 'missing from the response';
      }
    }

    return BatchOutcome(entries: entries, failures: failures);
  }
}

/// One generated word, ready to be written to the dictionary.
class WordEntry {
  const WordEntry({
    required this.word,
    required this.frequencyRank,
    required this.sentences,
  });

  final String word;
  final int frequencyRank;
  final List<GeneratedSentence> sentences;

  /// Parses a model response.
  ///
  /// Nothing here can assume well-formed input: DeepSeek's `json_object` mode
  /// guarantees the body parses as JSON and nothing more, so a missing or
  /// mistyped key is an expected outcome, not a bug. Every failure is raised as
  /// a [FormatException] the caller records against the word and moves on.
  factory WordEntry.fromJson(
    Map<String, Object?> json, {
    required String word,
    required int frequencyRank,
  }) {
    final rawSentences = json['sentences'];
    if (rawSentences is! List) {
      throw FormatException(
        'expected a "sentences" array, got ${rawSentences.runtimeType}',
      );
    }

    String field(Map<String, Object?> map, String key, int index) {
      final value = map[key];
      if (value is! String) {
        throw FormatException(
          'sentence $index: "$key" is ${value.runtimeType}, expected a string',
        );
      }
      return value.trim();
    }

    return WordEntry(
      word: word,
      frequencyRank: frequencyRank,
      sentences: [
        for (final (index, sentence) in rawSentences.indexed)
          if (sentence is! Map<String, Object?>)
            throw FormatException('sentence $index is not an object')
          else
            GeneratedSentence(
              text: field(sentence, 'text', index),
              correct: field(sentence, 'correct', index),
              near: field(sentence, 'near', index),
              wrong: field(sentence, 'wrong', index),
            ),
      ],
    );
  }

  /// Returns the reasons this entry is unusable, empty when it is fine.
  ///
  /// The schema guarantees shape, not sense. These are the failures seen in
  /// practice: the divider missing or unbalanced, and options that repeat.
  List<String> validate() {
    final problems = <String>[];

    if (sentences.length != sentencesPerWord) {
      problems.add('expected $sentencesPerWord sentences, '
          'got ${sentences.length}');
    }

    for (final (index, sentence) in sentences.indexed) {
      final markers = sentenceDivider.allMatches(sentence.text).length;
      if (markers != 2) {
        problems.add('sentence $index has $markers "$sentenceDivider" markers, '
            'expected 2');
      }
      if (sentence.target.isEmpty) {
        problems.add('sentence $index marks an empty span');
      }
      final options = {sentence.correct, sentence.near, sentence.wrong};
      if (options.length != 3) {
        problems.add('sentence $index has duplicate options');
      }
      if (options.any((option) => option.isEmpty)) {
        problems.add('sentence $index has an empty option');
      }
    }

    return problems;
  }
}

class GeneratedSentence {
  const GeneratedSentence({
    required this.text,
    required this.correct,
    required this.near,
    required this.wrong,
  });

  final String text;
  final String correct;
  final String near;
  final String wrong;

  /// The span the model marked, i.e. the inflected target word.
  String get target {
    final parts = text.split(sentenceDivider);
    return parts.length >= 2 ? parts[1] : '';
  }
}
