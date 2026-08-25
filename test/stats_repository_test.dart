import 'dart:io';

import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:bla_bla_in_english/models/word_status.dart';
import 'package:bla_bla_in_english/repositories/stats_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_database.dart';

void main() {
  sqfliteFfiInit();

  late Directory dir;
  late Database db;
  late StatsRepository repo;

  /// Midnight today, local — the anchor every relative day in these tests hangs
  /// off, so a run at 23:59 buckets the same way as one at noon.
  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime daysAgo(int days) {
    final base = today();
    return DateTime(base.year, base.month, base.day - days);
  }

  Future<void> answerOn(
    DateTime day,
    AnswerKind kind, {
    int wordId = 1,
    int times = 1,
    int hour = 12,
  }) async {
    final at = DateTime(day.year, day.month, day.day, hour);
    for (var i = 0; i < times; i++) {
      await db.insert('answers', {
        'word_id': wordId,
        'sentence_id': wordId * 10 + 1,
        'kind': kind.id,
        'answered_at': at.millisecondsSinceEpoch,
      });
    }
  }

  Future<void> progressFor(int wordId, WordStatus status) async {
    await db.insert('word_progress', {
      'word_id': wordId,
      'status': status.id,
      'next_position': 2,
      'times_answered': 1,
      'last_answered_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('blabla_stats_test');
    db = await openTestDatabase(dir, words: 50);
    repo = StatsRepository(db);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('a fresh install reports no history rather than a wall of zeroes',
      () async {
    final stats = await repo.load();

    expect(stats.hasHistory, isFalse);
    expect(stats.totalAnswers, 0);
    expect(stats.currentStreak, 0);
    expect(stats.dictionaryWords, 50);
    // Every word is untouched, so none of them is missing from the breakdown.
    expect(stats.countOfStatus(WordStatus.fresh), 50);
  });

  test('counts answers by kind, and accuracy ignores near misses', () async {
    await answerOn(today(), AnswerKind.correct, times: 6);
    await answerOn(today(), AnswerKind.near, times: 2);
    await answerOn(today(), AnswerKind.wrong, times: 2);

    final stats = await repo.load();

    expect(stats.totalAnswers, 10);
    expect(stats.countOfKind(AnswerKind.correct), 6);
    expect(stats.countOfKind(AnswerKind.near), 2);
    expect(stats.countOfKind(AnswerKind.wrong), 2);
    expect(stats.accuracy, 0.6);
  });

  test('untouched dictionary words are counted as fresh', () async {
    await progressFor(1, WordStatus.learned);
    await progressFor(2, WordStatus.wrong);
    await progressFor(3, WordStatus.wrong);

    final stats = await repo.load();

    expect(stats.practisedWords, 3);
    expect(stats.countOfStatus(WordStatus.wrong), 2);
    expect(stats.countOfStatus(WordStatus.learned), 1);
    expect(stats.countOfStatus(WordStatus.near), 0);
    expect(stats.countOfStatus(WordStatus.fresh), 47);
  });

  test('progress for words the dictionary no longer has cannot go negative',
      () async {
    for (var wordId = 1; wordId <= 50; wordId++) {
      await progressFor(wordId, WordStatus.learned);
    }
    await progressFor(9999, WordStatus.learned); // dropped from the dictionary

    final stats = await repo.load();
    expect(stats.countOfStatus(WordStatus.fresh), 0);
  });

  group('streaks', () {
    test('counts the days in a row up to today', () async {
      await answerOn(daysAgo(2), AnswerKind.correct);
      await answerOn(daysAgo(1), AnswerKind.correct);
      await answerOn(today(), AnswerKind.correct);

      final stats = await repo.load();
      expect(stats.currentStreak, 3);
      expect(stats.bestStreak, 3);
      expect(stats.daysPractised, 3);
    });

    test('survives a today that has not started yet', () async {
      await answerOn(daysAgo(2), AnswerKind.correct);
      await answerOn(daysAgo(1), AnswerKind.correct);

      final stats = await repo.load();
      expect(stats.currentStreak, 2,
          reason: 'the streak must not read 0 every morning');
      expect(stats.answersToday, 0);
    });

    test('breaks once a whole day goes by with nothing', () async {
      await answerOn(daysAgo(4), AnswerKind.correct);
      await answerOn(daysAgo(3), AnswerKind.correct);
      await answerOn(daysAgo(2), AnswerKind.correct);

      final stats = await repo.load();
      expect(stats.currentStreak, 0);
      expect(stats.bestStreak, 3, reason: 'the best run is still on record');
    });

    test('several answers on one day are still one day', () async {
      await answerOn(today(), AnswerKind.correct, times: 20);

      final stats = await repo.load();
      expect(stats.daysPractised, 1);
      expect(stats.currentStreak, 1);
      expect(stats.totalAnswers, 20);
    });
  });

  group('the activity window', () {
    test('ends today and fills the quiet days with zeroes', () async {
      await answerOn(daysAgo(3), AnswerKind.correct, times: 4);
      await answerOn(today(), AnswerKind.wrong, times: 7);

      final stats = await repo.load();
      final days = stats.recentDays;

      expect(days, hasLength(StatsRepository.recentDayCount));
      expect(days.last.day, today());
      expect(days.last.count, 7);
      expect(stats.answersToday, 7);
      expect(days[days.length - 4].count, 4);
      expect(days[days.length - 2].count, 0, reason: 'a quiet day still shows');
    });

    test('is ordered oldest first, one entry per calendar day', () async {
      final days = (await repo.load()).recentDays;

      for (var i = 1; i < days.length; i++) {
        expect(days[i].day.difference(days[i - 1].day).inDays, 1);
      }
    });

    test('a late-night answer counts for the day the user was living',
        () async {
      await answerOn(today(), AnswerKind.correct, hour: 23);

      final stats = await repo.load();
      expect(stats.answersToday, 1,
          reason: 'bucketing must use local time, not UTC');
    });
  });
}
