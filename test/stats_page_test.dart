import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:bla_bla_in_english/models/practice_stats.dart';
import 'package:bla_bla_in_english/models/word_status.dart';
import 'package:bla_bla_in_english/pages/stats_page.dart';
import 'package:bla_bla_in_english/repositories/stats_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the statistics screen at phone width.
///
/// A chart is the one thing static analysis cannot check: the numbers can be
/// right while fourteen bars run off the side of a narrow screen. Any RenderFlex
/// overflow while these frames are built fails the test.
void main() {
  PracticeStats statsWith({
    int correct = 412,
    int near = 96,
    int wrong = 137,
    int learned = 180,
    int nearWords = 40,
    int wrongWords = 55,
    int dictionaryWords = 5432,
    int currentStreak = 6,
    int bestStreak = 21,
    int daysPractised = 34,
    List<int>? dailyCounts,
  }) {
    final counts = dailyCounts ??
        [0, 12, 18, 0, 0, 24, 31, 9, 0, 14, 40, 22, 7, 19];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return PracticeStats(
      dictionaryWords: dictionaryWords,
      wordsByStatus: {
        WordStatus.learned: learned,
        WordStatus.near: nearWords,
        WordStatus.wrong: wrongWords,
        WordStatus.fresh:
            dictionaryWords - learned - nearWords - wrongWords,
      },
      answersByKind: {
        AnswerKind.correct: correct,
        AnswerKind.near: near,
        AnswerKind.wrong: wrong,
      },
      daysPractised: daysPractised,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      recentDays: [
        for (var back = counts.length - 1; back >= 0; back--)
          DailyCount(
            day: DateTime(today.year, today.month, today.day - back),
            count: counts[counts.length - 1 - back],
          ),
      ],
    );
  }

  Future<void> pumpView(WidgetTester tester, PracticeStats stats) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: StatsView(stats: stats))),
    );
  }

  testWidgets('lays out on a narrow phone without overflowing', (tester) async {
    await pumpView(tester, statsWith());

    expect(find.text('dias seguidos'), findsOneWidget);
    expect(find.text('Últimos ${StatsRepository.recentDayCount} dias'),
        findsOneWidget);
    expect(find.text('Onde estão suas palavras'), findsOneWidget);

    // 412 of 645 answers.
    expect(find.text('64%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolls to the bottom panel without overflowing',
      (tester) async {
    await pumpView(tester, statsWith());

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump();

    expect(find.text('Todas as suas respostas'), findsOneWidget);
    // Every coloured slice is named in writing, so nothing on this screen is
    // encoded by colour alone.
    expect(find.text('Acertou'), findsOneWidget);
    expect(find.text('Quase'), findsOneWidget);
    expect(find.text('Errou'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives the widest numbers a long user could reach',
      (tester) async {
    await pumpView(
      tester,
      statsWith(
        correct: 128400,
        near: 44120,
        wrong: 61330,
        daysPractised: 1250,
        currentStreak: 999,
        bestStreak: 1200,
        dailyCounts: List.filled(StatsRepository.recentDayCount, 4321),
      ),
    );

    expect(find.text('999'), findsOneWidget);
    expect(find.text('233.850'), findsOneWidget, reason: 'pt-BR thousands');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a quiet fortnight still draws fourteen days', (tester) async {
    await pumpView(
      tester,
      statsWith(dailyCounts: List.filled(StatsRepository.recentDayCount, 0)),
    );

    expect(find.text('Nada respondido hoje ainda.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fresh install gets an invitation, not empty charts',
      (tester) async {
    await pumpView(
      tester,
      statsWith(correct: 0, near: 0, wrong: 0),
    );

    expect(find.textContaining('Responda algumas palavras'), findsOneWidget);
    expect(find.text('dias seguidos'), findsNothing);
  });
}
