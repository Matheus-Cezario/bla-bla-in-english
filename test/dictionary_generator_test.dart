import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/deepseek_client.dart';
import '../tool/dictionary_content.dart';
import '../tool/generate_dictionary.dart';
import '../tool/write_dictionary.dart';
import 'package:bla_bla_in_english/data/dictionary_assets.dart';

WordEntry entryFor(String word, {int rank = 1}) => WordEntry(
      word: word,
      frequencyRank: rank,
      sentences: [
        for (var i = 1; i <= sentencesPerWord; i++)
          GeneratedSentence(
            text: 'A #$word# in sentence $i.',
            correct: 'correct $i',
            near: 'near $i',
            wrong: 'wrong $i',
          ),
      ],
    );

void main() {
  group('prompt', () {
    test('contains the literal word "json"', () {
      // DeepSeek rejects response_format json_object unless the prompt says
      // "json" somewhere. Losing this silently breaks every request.
      expect(systemPrompt.toLowerCase(), contains('json'));
    });

    test('embeds the example shape, since the API enforces no schema', () {
      expect(systemPrompt, contains('"sentences"'));
      expect(systemPrompt, contains('"near"'));
      expect(systemPrompt, contains(sentencesPerWord.toString()));
    });
  });

  group('off-peak window', () {
    // DeepSeek peak is 01:00-04:00 and 06:00-10:00 UTC, Monday to Friday.
    test('weekday peak hours are peak', () {
      expect(DeepSeekClient.isOffPeak(DateTime.utc(2026, 8, 24, 2)), isFalse);
      expect(DeepSeekClient.isOffPeak(DateTime.utc(2026, 8, 24, 7)), isFalse);
    });

    test('weekday gaps and nights are off-peak', () {
      expect(DeepSeekClient.isOffPeak(DateTime.utc(2026, 8, 24, 5)), isTrue);
      expect(DeepSeekClient.isOffPeak(DateTime.utc(2026, 8, 24, 12)), isTrue);
      expect(DeepSeekClient.isOffPeak(DateTime.utc(2026, 8, 24, 0)), isTrue);
    });

    test('boundaries fall on the right side', () {
      expect(DeepSeekClient.isOffPeak(DateTime.utc(2026, 8, 24, 1)), isFalse);
      expect(DeepSeekClient.isOffPeak(DateTime.utc(2026, 8, 24, 4)), isTrue);
      expect(DeepSeekClient.isOffPeak(DateTime.utc(2026, 8, 24, 10)), isTrue);
    });

    test('weekends are always off-peak', () {
      // 2026-08-29 is a Saturday, 08-30 a Sunday.
      expect(DeepSeekClient.isOffPeak(DateTime.utc(2026, 8, 29, 2)), isTrue);
      expect(DeepSeekClient.isOffPeak(DateTime.utc(2026, 8, 30, 7)), isTrue);
    });

    test('peak costs exactly double off-peak', () {
      final off = DeepSeekClient.costEstimate(
        DeepSeekClient.defaultModel,
        1000,
        at: DateTime.utc(2026, 8, 24, 12),
      );
      final peak = DeepSeekClient.costEstimate(
        DeepSeekClient.defaultModel,
        1000,
        at: DateTime.utc(2026, 8, 24, 2),
      );
      expect(off, contains('off-peak'));
      expect(peak, contains('PEAK'));

      double dollars(String s) =>
          double.parse(RegExp(r'\$([\d.]+)').firstMatch(s)!.group(1)!);
      expect(dollars(peak), closeTo(dollars(off) * 2, 0.01));
    });
  });

  test('batching cuts cost, and the saving flattens out', () {
    double dollars(int batchSize) {
      final text = DeepSeekClient.costEstimate(
        DeepSeekClient.defaultModel,
        30000,
        batchSize: batchSize,
        at: DateTime.utc(2026, 8, 24, 12),
      );
      return double.parse(RegExp(r'\$([\d.]+)').firstMatch(text)!.group(1)!);
    }

    // Only the system prompt is amortised, so the saving is real but bounded:
    // output tokens dominate and scale with the word count either way.
    expect(dollars(10), lessThan(dollars(1)));
    expect(dollars(20), lessThan(dollars(10)));
    // Diminishing returns — doubling again saves far less than the first jump.
    expect(dollars(10) - dollars(20), lessThan(dollars(1) - dollars(10)));
  });

  group('stable ids', () {
    // Progress lives in a separate database keyed by word_id and sentence_id.
    // If regenerating the dictionary renumbers rows, every existing install
    // silently re-points its history at different words.
    test('the same key always yields the same id', () {
      expect(stableId('book'), stableId('book'));
      expect(stableId('book:1'), stableId('book:1'));
    });

    test('different keys yield different ids', () {
      final ids = {
        stableId('book'),
        stableId('bank'),
        stableId('book:1'),
        stableId('book:2'),
        stableId('book:1:0'),
        stableId('book:1:1'),
      };
      expect(ids, hasLength(6));
    });

    test('ids are positive, so they are valid SQLite row ids', () {
      for (final key in ['book', 'a', 'zzzz', 'word:5:2']) {
        expect(stableId(key), greaterThan(0));
      }
    });

    test('no collisions across a realistic dictionary', () {
      final ids = <int>{};
      for (var w = 0; w < 4000; w++) {
        ids.add(stableId('word$w'));
        for (var p = 1; p <= 5; p++) {
          ids.add(stableId('word$w:$p'));
          for (var k = 0; k < 3; k++) {
            ids.add(stableId('word$w:$p:$k'));
          }
        }
      }
      expect(ids, hasLength(4000 * (1 + 5 + 15)));
    });
  });

  test('the derived version path matches what the app reads', () {
    // The generator writes the stamp beside the database; the app looks it up
    // at a fixed asset path. If these drift, every install silently keeps a
    // stale dictionary.
    expect(versionPathFor(dictionaryAssetPath), dictionaryVersionPath);
    expect(versionPathFor('/tmp/out.db'), '/tmp/out.version');
  });

  group('batching', () {
    Map<String, Object?> wordJson(String word, {int sentences = sentencesPerWord}) => {
          'word': word,
          'sentences': [
            for (var i = 1; i <= sentences; i++)
              {
                'text': 'A #$word# number $i.',
                'correct': 'correct $i',
                'near': 'near $i',
                'wrong': 'wrong $i',
              },
          ],
        };

    const ranks = {'book': 1, 'light': 2, 'run': 3};

    test('splits a clean batch into entries, no failures', () {
      final outcome = BatchOutcome.parse(
        {'words': [wordJson('book'), wordJson('light'), wordJson('run')]},
        requestedRanks: ranks,
      );

      expect(outcome.failures, isEmpty);
      expect(outcome.entries.map((e) => e.word), ['book', 'light', 'run']);
      expect(outcome.entries.map((e) => e.frequencyRank), [1, 2, 3]);
    });

    test('one bad word does not sink the rest of the batch', () {
      final outcome = BatchOutcome.parse(
        {
          'words': [
            wordJson('book'),
            wordJson('light', sentences: 2), // too few sentences
            wordJson('run'),
          ],
        },
        requestedRanks: ranks,
      );

      expect(outcome.entries.map((e) => e.word), ['book', 'run']);
      expect(outcome.failures.keys, ['light']);
      expect(outcome.failures['light'], contains('expected'));
    });

    test('a word the model dropped is reported for retry', () {
      final outcome = BatchOutcome.parse(
        {'words': [wordJson('book'), wordJson('run')]},
        requestedRanks: ranks,
      );

      expect(outcome.entries.map((e) => e.word), ['book', 'run']);
      expect(outcome.failures['light'], contains('missing'));
    });

    test('an invented word is dropped without failing anything', () {
      final outcome = BatchOutcome.parse(
        {
          'words': [
            wordJson('book'),
            wordJson('light'),
            wordJson('run'),
            wordJson('banana'), // never requested
          ],
        },
        requestedRanks: ranks,
      );

      expect(outcome.entries.map((e) => e.word), ['book', 'light', 'run']);
      expect(outcome.failures, isEmpty);
    });

    test('a duplicated word is taken once', () {
      final outcome = BatchOutcome.parse(
        {
          'words': [
            wordJson('book'),
            wordJson('book'),
            wordJson('light'),
            wordJson('run'),
          ],
        },
        requestedRanks: ranks,
      );

      expect(outcome.entries.where((e) => e.word == 'book'), hasLength(1));
      expect(outcome.failures, isEmpty);
    });

    test('capitalisation is matched back to the requested word', () {
      final outcome = BatchOutcome.parse(
        {'words': [wordJson('Book'), wordJson('LIGHT'), wordJson(' run ')]},
        requestedRanks: ranks,
      );

      expect(outcome.entries.map((e) => e.word), ['book', 'light', 'run']);
      expect(outcome.failures, isEmpty);
    });

    test('a response with no words array fails every word for retry', () {
      final outcome = BatchOutcome.parse(
        {'error': 'nope'},
        requestedRanks: ranks,
      );

      expect(outcome.entries, isEmpty);
      expect(outcome.failures.keys.toSet(), ranks.keys.toSet());
    });
  });

  group('resumable cache', () {
    late Directory dir;
    late GenerationCache cache;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('blabla_cache');
      cache = GenerationCache('${dir.path}/cache.jsonl');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('a missing cache reads as empty rather than throwing', () {
      expect(cache.readAll(), isEmpty);
      expect(cache.completedWords(), isEmpty);
    });

    test('round-trips a word through the file', () async {
      cache.append(entryFor('book', rank: 3));
      await cache.close();

      final reloaded = GenerationCache(cache.path).readAll();
      expect(reloaded, hasLength(1));
      expect(reloaded.single.word, 'book');
      expect(reloaded.single.frequencyRank, 3);
      expect(reloaded.single.sentences, hasLength(sentencesPerWord));
      expect(reloaded.single.sentences.first.near, 'near 1');
      expect(reloaded.single.validate(), isEmpty);
    });

    test('reports completed words so a rerun can skip them', () async {
      cache
        ..append(entryFor('book'))
        ..append(entryFor('light', rank: 2));
      await cache.close();

      expect(
        GenerationCache(cache.path).completedWords(),
        {'book', 'light'},
      );
    });

    test('appending continues an existing file instead of truncating it',
        () async {
      cache.append(entryFor('book'));
      await cache.close();

      // A second run of the tool opens the same path again.
      final second = GenerationCache(cache.path)..append(entryFor('run', rank: 2));
      await second.close();

      expect(GenerationCache(cache.path).completedWords(), {'book', 'run'});
    });

    test('a torn final line is dropped, keeping the rest of the run', () async {
      cache.append(entryFor('book'));
      await cache.close();
      // Simulate a kill mid-write.
      File(cache.path).writeAsStringSync(
        '{"word":"light","frequency_rank":2,"sen',
        mode: FileMode.append,
      );

      final reloaded = GenerationCache(cache.path).readAll();
      expect(reloaded.map((e) => e.word), ['book']);
    });
  });

  group('defensive parsing', () {
    // json_object mode guarantees the body parses and nothing else, so every
    // one of these is an expected response, not a hypothetical.
    test('rejects a missing sentences array', () {
      expect(
        () => WordEntry.fromJson({'word': 'book'}, word: 'book', frequencyRank: 1),
        throwsFormatException,
      );
    });

    test('rejects a sentence that is not an object', () {
      expect(
        () => WordEntry.fromJson(
          {
            'sentences': ['nope'],
          },
          word: 'book',
          frequencyRank: 1,
        ),
        throwsFormatException,
      );
    });

    test('rejects a missing option field', () {
      expect(
        () => WordEntry.fromJson(
          {
            'sentences': [
              {'text': 'A #book# here.', 'correct': 'x', 'near': 'y'},
            ],
          },
          word: 'book',
          frequencyRank: 1,
        ),
        throwsFormatException,
      );
    });

    test('validate catches structurally valid but unusable content', () {
      final missingMarkers = WordEntry(
        word: 'book',
        frequencyRank: 1,
        sentences: [
          for (var i = 0; i < sentencesPerWord; i++)
            const GeneratedSentence(
              text: 'No markers at all.',
              correct: 'a',
              near: 'b',
              wrong: 'c',
            ),
        ],
      );
      expect(missingMarkers.validate(), isNotEmpty);

      final duplicateOptions = WordEntry(
        word: 'book',
        frequencyRank: 1,
        sentences: [
          for (var i = 0; i < sentencesPerWord; i++)
            const GeneratedSentence(
              text: 'A #book# here.',
              correct: 'same',
              near: 'same',
              wrong: 'other',
            ),
        ],
      );
      expect(
        duplicateOptions.validate().first,
        contains('duplicate'),
      );
    });

    test('accepts well-formed content', () {
      expect(entryFor('book').validate(), isEmpty);
    });
  });
}
