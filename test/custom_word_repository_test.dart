import 'dart:convert';
import 'dart:io';

import 'package:bla_bla_in_english/data/schema.dart';
import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:bla_bla_in_english/data/stable_id.dart';
import 'package:bla_bla_in_english/repositories/custom_word_repository.dart';
import 'package:bla_bla_in_english/repositories/session_repository.dart';
import 'package:bla_bla_in_english/services/deepseek_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_database.dart';

/// A DeepSeek that never leaves the process.
///
/// Returns whatever body the test hands it, wrapped in the envelope the real
/// API uses, so the client's own parsing is exercised rather than stubbed out.
http.Client _fakeApi(
  String content, {
  int status = 200,
  void Function(Map<String, Object?> request)? onRequest,
}) {
  return MockClient((request) async {
    onRequest?.call(
      jsonDecode(request.body) as Map<String, Object?>,
    );
    if (status != 200) {
      return http.Response('{"error":"nope"}', status);
    }
    return http.Response(
      jsonEncode({
        'choices': [
          {
            'finish_reason': 'stop',
            'message': {'content': content},
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

/// The shape the generator's prompt asks for, for one word.
String _wordJson(String word, {int sentences = 5, bool duplicateOptions = false}) {
  return jsonEncode({
    'words': [
      {
        'word': word,
        'sentences': [
          for (var i = 1; i <= sentences; i++)
            {
              'text': 'A #$word# in sentence $i.',
              'correct': 'the right meaning $i',
              'near': duplicateOptions
                  ? 'the right meaning $i'
                  : 'the tempting meaning $i',
              'wrong': 'the unrelated meaning $i',
            },
        ],
      },
    ],
  });
}

void main() {
  sqfliteFfiInit();

  late Directory dir;
  late Database db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('blabla_custom_test');
    db = await openTestDatabase(dir, words: 50);
    // progressSchema already carries the custom-word tables.
    await db.setVersion(progressSchemaVersion);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  CustomWordRepository repositoryReturning(
    String content, {
    int status = 200,
    void Function(Map<String, Object?>)? onRequest,
  }) {
    return CustomWordRepository(
      db,
      client: (apiKey) => DeepSeekClient(
        apiKey: apiKey,
        httpClient: _fakeApi(content, status: status, onRequest: onRequest),
      ),
    );
  }

  test('a created word lands in the dictionary, ready to practise', () async {
    final repo = repositoryReturning(_wordJson('serendipity'));
    await repo.create('serendipity', apiKey: 'sk-test');

    final words = await db.rawQuery(
      'SELECT id, word, frequency_rank FROM $dictionaryAlias.words '
      'WHERE word = ?',
      ['serendipity'],
    );
    expect(words, hasLength(1));
    expect(words.first['id'], stableId('serendipity'));
    expect(words.first['frequency_rank'], 51,
        reason: 'after the 50 words the fixture ships');

    final sentences = await db.rawQuery(
      'SELECT id, position FROM $dictionaryAlias.sentences WHERE word_id = ? '
      'ORDER BY position',
      [stableId('serendipity')],
    );
    expect(sentences, hasLength(5));
    expect(sentences.first['id'], sentenceIdFor('serendipity', 1));

    final options = await db.rawQuery(
      'SELECT kind FROM $dictionaryAlias.options WHERE sentence_id = ?',
      [sentenceIdFor('serendipity', 1)],
    );
    expect(options.map((row) => row['kind']).toSet(), {0, 1, 2});
  });

  test('the word is practisable through the normal session machinery',
      () async {
    await repositoryReturning(_wordJson('serendipity'))
        .create('serendipity', apiKey: 'sk-test');

    final sessions = SessionRepository(db);
    final items = await sessions.addWordsToTodaySession(
      wordIds: [stableId('serendipity')],
      wordsPerDay: 5,
    );

    final added = items.firstWhere((item) => item.word == 'serendipity');
    expect(added.sentenceText, 'A #serendipity# in sentence 1.');
    expect(added.options, hasLength(3),
        reason: 'a created word is indistinguishable from a shipped one');
  });

  test('it is kept outside the dictionary too, where updates cannot reach it',
      () async {
    await repositoryReturning(_wordJson('serendipity'))
        .create('serendipity', apiKey: 'sk-test');

    final mirrored = await db.query('custom_words');
    expect(mirrored, hasLength(1));
    expect(mirrored.first['word'], 'serendipity');
    expect(await db.query('custom_sentences'), hasLength(5));
    expect(await db.query('custom_options'), hasLength(15));
  });

  test('a word already in the dictionary is refused before any request is sent',
      () async {
    var called = false;
    final repo = repositoryReturning(
      _wordJson('word1'),
      onRequest: (_) => called = true,
    );

    await expectLater(
      repo.create('word1', apiKey: 'sk-test'),
      throwsA(isA<WordCreationException>()),
    );
    expect(called, isFalse, reason: 'nobody should pay for a word we have');
  });

  test('the request carries the generator prompt, not a second one', () async {
    Map<String, Object?>? sent;
    final repo = repositoryReturning(
      _wordJson('serendipity'),
      onRequest: (request) => sent = request,
    );
    await repo.create('serendipity', apiKey: 'sk-test');

    final messages = (sent!['messages']! as List).cast<Map<String, Object?>>();
    expect(messages.first['role'], 'system');
    expect(messages.first['content'], contains('vocabulary exercises'));
    expect(messages.last['content'], contains('serendipity'));
    expect(sent!['response_format'], {'type': 'json_object'});
  });

  test('a response that fails validation is refused, not stored', () async {
    // Four sentences where the contract says five.
    final repo = repositoryReturning(_wordJson('serendipity', sentences: 4));

    await expectLater(
      repo.create('serendipity', apiKey: 'sk-test'),
      throwsA(isA<WordCreationException>()),
    );
    expect(await db.query('custom_words'), isEmpty);
    expect(
      await db.rawQuery(
        'SELECT 1 FROM $dictionaryAlias.words WHERE word = ?',
        ['serendipity'],
      ),
      isEmpty,
      reason: 'a half-good word must not reach the dictionary',
    );
  });

  test('duplicate options are caught by the generator validation', () async {
    final repo = repositoryReturning(
      _wordJson('serendipity', duplicateOptions: true),
    );

    await expectLater(
      repo.create('serendipity', apiKey: 'sk-test'),
      throwsA(isA<WordCreationException>()),
    );
  });

  test('a rejected key is reported as a key problem, not a network one',
      () async {
    final repo = repositoryReturning('', status: 401);

    await expectLater(
      repo.create('serendipity', apiKey: 'sk-wrong'),
      throwsA(
        isA<WordCreationException>()
            .having((e) => e.message, 'message', contains('chave')),
      ),
    );
  });

  group('surviving a dictionary update', () {
    /// Wipes the attached dictionary of everything to do with a word, the way
    /// shipping a regenerated dictionary.db does.
    Future<void> replaceDictionary(int wordId) async {
      await db.rawDelete(
        'DELETE FROM $dictionaryAlias.options WHERE sentence_id IN '
        '(SELECT id FROM $dictionaryAlias.sentences WHERE word_id = ?)',
        [wordId],
      );
      await db.rawDelete(
        'DELETE FROM $dictionaryAlias.sentences WHERE word_id = ?',
        [wordId],
      );
      await db.rawDelete(
        'DELETE FROM $dictionaryAlias.words WHERE id = ?',
        [wordId],
      );
    }

    test('a created word is put back after the dictionary is replaced',
        () async {
      final repo = repositoryReturning(_wordJson('serendipity'));
      await repo.create('serendipity', apiKey: 'sk-test');
      final wordId = stableId('serendipity');

      await replaceDictionary(wordId);
      expect(
        await db.rawQuery(
            'SELECT 1 FROM $dictionaryAlias.words WHERE id = ?', [wordId]),
        isEmpty,
        reason: 'the update really did take it out',
      );

      expect(await repo.replayIntoDictionary(), 1);

      final restored = await db.rawQuery(
        'SELECT word FROM $dictionaryAlias.words WHERE id = ?',
        [wordId],
      );
      expect(restored.single['word'], 'serendipity');
      expect(
        await db.rawQuery(
          'SELECT 1 FROM $dictionaryAlias.sentences WHERE word_id = ?',
          [wordId],
        ),
        hasLength(5),
      );
      expect(
        await db.rawQuery(
          'SELECT 1 FROM $dictionaryAlias.options WHERE sentence_id = ?',
          [sentenceIdFor('serendipity', 1)],
        ),
        hasLength(3),
      );
    });

    test('progress earned on the word survives with it', () async {
      final repo = repositoryReturning(_wordJson('serendipity'));
      await repo.create('serendipity', apiKey: 'sk-test');
      final wordId = stableId('serendipity');

      final sessions = SessionRepository(db);
      final items = await sessions.addWordsToTodaySession(
        wordIds: [wordId],
        wordsPerDay: 3,
      );
      await sessions.recordAnswer(
        item: items.firstWhere((i) => i.word == 'serendipity'),
        kind: AnswerKind.wrong,
      );

      await replaceDictionary(wordId);
      await repo.replayIntoDictionary();

      // The id is derived from the word, so the progress row still points at
      // the same thing it was earned on.
      final progress = await db.query('word_progress',
          where: 'word_id = ?', whereArgs: [wordId]);
      expect(progress, hasLength(1));
      final reloaded = await sessions.todaySession(wordsPerDay: 3);
      expect(reloaded.any((item) => item.word == 'serendipity'), isTrue);
    });

    test('nothing to put back is not a write', () async {
      final repo = repositoryReturning(_wordJson('serendipity'));
      await repo.create('serendipity', apiKey: 'sk-test');

      expect(await repo.replayIntoDictionary(), 0,
          reason: 'the word is already there');
    });

    test('a word that has since shipped for real is left alone', () async {
      final repo = repositoryReturning(_wordJson('serendipity'));
      await repo.create('serendipity', apiKey: 'sk-test');

      // The new dictionary carries it, with its own wording.
      await db.rawUpdate(
        'UPDATE $dictionaryAlias.sentences SET text = ? WHERE id = ?',
        ['The official #serendipity# sentence.', sentenceIdFor('serendipity', 1)],
      );

      await repo.replayIntoDictionary();

      final text = await db.rawQuery(
        'SELECT text FROM $dictionaryAlias.sentences WHERE id = ?',
        [sentenceIdFor('serendipity', 1)],
      );
      expect(text.single['text'], 'The official #serendipity# sentence.',
          reason: 'the shipped version wins over the phone-made one');
    });
  });

  group('what can be asked for', () {
    test('accepts an ordinary word', () {
      expect(CustomWordRepository.rejectionReason('serendipity'), isNull);
      expect(CustomWordRepository.rejectionReason("don't"), isNull);
      expect(CustomWordRepository.rejectionReason('well-known'), isNull);
    });

    test('refuses what the exercise format cannot carry', () {
      expect(CustomWordRepository.rejectionReason(''), isNotNull);
      expect(CustomWordRepository.rejectionReason('two words'), isNotNull);
      expect(CustomWordRepository.rejectionReason('123'), isNotNull);
      expect(CustomWordRepository.rejectionReason('a' * 41), isNotNull);
    });
  });
}
