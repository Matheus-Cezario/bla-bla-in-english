import 'dart:io';

import 'package:bla_bla_in_english/data/schema.dart';
import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:bla_bla_in_english/models/word_status.dart';
import 'package:bla_bla_in_english/repositories/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Builds a progress database with a dictionary attached, mirroring how
/// [AppDatabase] wires the two files together at runtime.
Future<Database> openTestDatabase(Directory dir, {required int words}) async {
  final dictionaryPath = p.join(dir.path, 'dictionary.db');

  final dictionary = await databaseFactoryFfi.openDatabase(dictionaryPath);
  for (final statement in dictionarySchema) {
    await dictionary.execute(statement);
  }

  // Every word gets 5 sentences, each with the three kinds of option, so the
  // fixtures match what the generator is contracted to produce.
  for (var w = 1; w <= words; w++) {
    await dictionary.insert('words', {
      'id': w,
      'word': 'word$w',
      'frequency_rank': w,
    });
    for (var position = 1; position <= 5; position++) {
      final sentenceId = w * 10 + position;
      await dictionary.insert('sentences', {
        'id': sentenceId,
        'word_id': w,
        'position': position,
        'text': 'A #word$w# in sentence $position.',
      });
      for (final kind in AnswerKind.values) {
        await dictionary.insert('options', {
          'sentence_id': sentenceId,
          'text': '${kind.name} meaning of word$w ($position)',
          'kind': kind.id,
        });
      }
    }
  }
  await dictionary.close();

  final db = await databaseFactoryFfi.openDatabase(
    p.join(dir.path, 'progress.db'),
  );
  // Mirrors AppDatabase.onConfigure. Without it ON DELETE CASCADE is inert and
  // deleting a session would leave its items behind.
  await db.execute('PRAGMA foreign_keys = ON');
  for (final statement in progressSchema) {
    await db.execute(statement);
  }
  await db.execute('ATTACH DATABASE ? AS $dictionaryAlias', [dictionaryPath]);
  return db;
}

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

  test('sentence parts split the target word out for highlighting', () async {
    final items = await repo.todaySession(wordsPerDay: 1);
    final parts = items.single.parts;

    expect(parts.map((p) => p.text), ['A ', 'word1', ' in sentence 1.']);
    expect(parts.map((p) => p.isTarget), [false, true, false]);
  });
}
