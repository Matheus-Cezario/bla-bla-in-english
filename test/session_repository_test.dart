import 'dart:io';

import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:bla_bla_in_english/models/word_status.dart';
import 'package:bla_bla_in_english/repositories/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_database.dart';

void main() {
  sqfliteFfiInit();

  late Directory dir;
  late Database db;
  late SessionRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('blabla_test');
    db = await openTestDatabase(dir, words: 50);
    repo = SessionRepository(db);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('a fresh install draws the most common words first', () async {
    final items = await repo.todaySession(wordsPerDay: 5);

    expect(items, hasLength(5));
    expect(items.map((i) => i.word), ['word1', 'word2', 'word3', 'word4', 'word5']);
    // frequency_rank 1..5 are the lowest ranks in the fixture.
    expect(items.every((i) => i.options.length == 3), isTrue);
  });

  test('the day plan is stable across reloads', () async {
    final first = await repo.todaySession(wordsPerDay: 5);
    final second = await repo.todaySession(wordsPerDay: 5);

    expect(
      second.map((i) => i.sessionItemId),
      first.map((i) => i.sessionItemId),
    );
    // A second call must not create a second session row.
    final sessions = await db.query('sessions');
    expect(sessions, hasLength(1));
  });

  test('option order is stable but not always correct-first', () async {
    final first = await repo.todaySession(wordsPerDay: 10);
    final second = await repo.todaySession(wordsPerDay: 10);

    for (var i = 0; i < first.length; i++) {
      expect(
        second[i].options.map((o) => o.id),
        first[i].options.map((o) => o.id),
        reason: 'option order must survive a reload',
      );
    }

    final correctSlots = first
        .map((item) => item.options.indexWhere((o) => o.kind == AnswerKind.correct))
        .toSet();
    expect(correctSlots.length, greaterThan(1),
        reason: 'the right answer must not always sit in the same slot');
  });

  test('answering records history, status and the session item', () async {
    final items = await repo.todaySession(wordsPerDay: 3);
    await repo.recordAnswer(item: items.first, kind: AnswerKind.near);

    final answers = await db.query('answers');
    expect(answers, hasLength(1));
    expect(answers.first['kind'], AnswerKind.near.id);

    final progress = await db.query('word_progress');
    expect(progress.first['status'], WordStatus.near.id);
    expect(progress.first['times_answered'], 1);
    // First sentence done, so the word should be queued on its second.
    expect(progress.first['next_position'], 2);

    final sessionItems = await db.query('session_items',
        where: 'id = ?', whereArgs: [items.first.sessionItemId]);
    expect(sessionItems.first['answered_kind'], AnswerKind.near.id);
  });

  test('a word walks through its five sentences, then wraps', () async {
    final seen = <String>[];
    for (var day = 1; day <= 6; day++) {
      // One word per day keeps the same word coming back.
      final items = await repo.todaySession(wordsPerDay: 1);
      seen.add(items.single.sentenceText);
      await repo.recordAnswer(item: items.single, kind: AnswerKind.wrong);
      await db.delete('sessions'); // simulate the next calendar day
    }

    expect(seen.take(5), [
      for (var position = 1; position <= 5; position++)
        'A #word1# in sentence $position.',
    ]);
    // Sixth encounter wraps back to the first sentence.
    expect(seen.last, 'A #word1# in sentence 1.');
  });

  test('wrong words outrank near, fresh and learned, but all four appear',
      () async {
    // Seed one word into each of the three answered buckets, leaving the rest
    // fresh, then check the shape of the next session.
    final setup = await repo.todaySession(wordsPerDay: 12);
    for (final (index, kind) in [
      AnswerKind.wrong,
      AnswerKind.wrong,
      AnswerKind.wrong,
      AnswerKind.wrong,
      AnswerKind.near,
      AnswerKind.correct,
    ].indexed) {
      await repo.recordAnswer(item: setup[index], kind: kind);
    }
    await db.delete('sessions');

    final items = await repo.todaySession(wordsPerDay: 6);
    final drawn = await db.rawQuery(
      'SELECT drawn_status, COUNT(*) AS n FROM session_items '
      'WHERE session_id = (SELECT MAX(id) FROM sessions) GROUP BY drawn_status',
    );
    final counts = {
      for (final row in drawn) row['drawn_status']! as int: row['n']! as int,
    };

    expect(items, hasLength(6));
    // 6 slots, one reserved for each of the other three buckets.
    expect(counts[WordStatus.wrong.id], 3, reason: 'wrong words fill the rest');
    expect(counts[WordStatus.near.id], 1);
    expect(counts[WordStatus.fresh.id], 1);
    expect(counts[WordStatus.learned.id], 1);
  });

  test('runs out gracefully when the dictionary is smaller than the target',
      () async {
    final items = await repo.todaySession(wordsPerDay: 200);
    expect(items, hasLength(50));
  });

  group('extending the day', () {
    test('adds new words instead of handing back the ones already queued',
        () async {
      final first = await repo.todaySession(wordsPerDay: 5);
      final extended = await repo.extendTodaySession(wordsPerDay: 5);

      expect(extended, hasLength(10));
      // The first five must survive untouched, in place.
      expect(
        extended.take(5).map((i) => i.sessionItemId),
        first.map((i) => i.sessionItemId),
      );
      // And nothing may be queued twice.
      expect(extended.map((i) => i.wordId).toSet(), hasLength(10));

      final sessions = await db.query('sessions');
      expect(sessions, hasLength(1), reason: 'still the same day');
      expect(sessions.first['target_words'], 10);
    });

    test('re-draws words the user just answered only when nothing else is left',
        () async {
      final items = await repo.todaySession(wordsPerDay: 5);
      for (final item in items) {
        await repo.recordAnswer(item: item, kind: AnswerKind.wrong);
      }

      final extended = await repo.extendTodaySession(wordsPerDay: 5);
      expect(extended.map((i) => i.wordId).toSet(), hasLength(10));
    });

    test('leaves the session alone when the dictionary is exhausted', () async {
      final full = await repo.todaySession(wordsPerDay: 50);
      final extended = await repo.extendTodaySession(wordsPerDay: 5);

      expect(extended, hasLength(full.length));
      final sessions = await db.query('sessions');
      expect(sessions.first['target_words'], 50,
          reason: 'the target must not grow when nothing was added');
    });

    test('only plans the day when there is no session to extend yet', () async {
      final items = await repo.extendTodaySession(wordsPerDay: 4);

      expect(items, hasLength(4));
      expect(await db.query('sessions'), hasLength(1));
    });
  });

  group('searching words', () {
    test('matches by prefix, exact match first', () async {
      final results = await repo.searchWords('word1');

      expect(results.first.word, 'word1');
      // word1, word10..word19
      expect(results.map((r) => r.word), hasLength(11));
      expect(results.every((r) => r.word.startsWith('word1')), isTrue);
    });

    test('reports status and whether the word is already queued today',
        () async {
      final items = await repo.todaySession(wordsPerDay: 3);
      await repo.recordAnswer(item: items.first, kind: AnswerKind.wrong);

      final queued = (await repo.searchWords('word1')).first;
      expect(queued.word, 'word1');
      expect(queued.inTodaySession, isTrue);
      expect(queued.status, WordStatus.wrong);

      final untouched =
          (await repo.searchWords('word40')).firstWhere((r) => r.word == 'word40');
      expect(untouched.inTodaySession, isFalse);
      expect(untouched.status, WordStatus.fresh);
    });

    test('an empty query browses the dictionary, most common first', () async {
      final results = await repo.searchWords('   ');

      expect(results, hasLength(SessionRepository.searchPageSize));
      expect(
        results.take(3).map((r) => r.word),
        ['word1', 'word2', 'word3'],
        reason: 'frequency_rank 1..3 are the most common in the fixture',
      );
    });

    test('paging walks the dictionary without repeating or skipping a word',
        () async {
      final seen = <String>[];
      for (var offset = 0; offset < 50; offset += 20) {
        final page = await repo.searchWords('', limit: 20, offset: offset);
        seen.addAll(page.map((r) => r.word));
      }

      expect(seen, hasLength(50));
      expect(seen.toSet(), hasLength(50), reason: 'no word appears twice');
      expect(seen.first, 'word1');
      expect(seen.last, 'word50');
    });

    test('a short page is how the end of the dictionary announces itself',
        () async {
      final last = await repo.searchWords('', limit: 20, offset: 40);

      expect(last, hasLength(10));
      expect(last.length, lessThan(20));
    });

    test('paging a search stays inside the matches', () async {
      // word1, word10..word19 — eleven matches.
      final first = await repo.searchWords('word1', limit: 4);
      final second = await repo.searchWords('word1', limit: 4, offset: 4);
      final third = await repo.searchWords('word1', limit: 4, offset: 8);

      final all = [...first, ...second, ...third].map((r) => r.word).toList();
      expect(all, hasLength(11));
      expect(all.toSet(), hasLength(11));
      expect(all.every((word) => word.startsWith('word1')), isTrue);
      expect(all.first, 'word1', reason: 'the exact match still leads');
    });

    test('LIKE wildcards typed by the user are matched literally', () async {
      expect(await repo.searchWords('%'), isEmpty);
      expect(await repo.searchWords('word_'), isEmpty);
    });
  });

  group('adding picked words', () {
    test('appends them to the end, in the order they were picked', () async {
      final before = await repo.todaySession(wordsPerDay: 3);
      final items = await repo.addWordsToTodaySession(
        wordIds: [40, 12],
        wordsPerDay: 3,
      );

      expect(items, hasLength(before.length + 2));
      expect(items.skip(3).map((i) => i.word), ['word40', 'word12']);
      expect((await db.query('sessions')).first['target_words'], 5);
    });

    test('skips words the session already holds', () async {
      final before = await repo.todaySession(wordsPerDay: 3);
      await repo.addWordsToTodaySession(wordIds: [40], wordsPerDay: 3);
      final again = await repo.addWordsToTodaySession(
        wordIds: [40, 1],
        wordsPerDay: 3,
      );

      expect(again, hasLength(before.length + 1));
      expect(again.map((i) => i.wordId).toSet(), hasLength(again.length));
    });

    test('picks up the word where the user left it off', () async {
      final items = await repo.todaySession(wordsPerDay: 3);
      final word2 = items.firstWhere((i) => i.word == 'word2');
      await repo.recordAnswer(item: word2, kind: AnswerKind.near);
      await db.delete('sessions'); // simulate the next calendar day

      final added = await repo.addWordsToTodaySession(
        wordIds: [word2.wordId],
        wordsPerDay: 1,
      );

      expect(
        added.firstWhere((i) => i.word == 'word2').sentenceText,
        'A #word2# in sentence 2.',
        reason: 'the first sentence is already done',
      );
    });

    test('an unknown word id is ignored', () async {
      final before = await repo.todaySession(wordsPerDay: 3);
      final items =
          await repo.addWordsToTodaySession(wordIds: [9999], wordsPerDay: 3);

      expect(items, hasLength(before.length));
    });
  });

  test('sentence parts split the target word out for highlighting', () async {
    final items = await repo.todaySession(wordsPerDay: 1);
    final parts = items.single.parts;

    expect(parts.map((p) => p.text), ['A ', 'word1', ' in sentence 1.']);
    expect(parts.map((p) => p.isTarget), [false, true, false]);
  });
}
