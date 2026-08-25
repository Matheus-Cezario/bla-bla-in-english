import 'package:bla_bla_in_english/models/word_search_result.dart';
import 'package:bla_bla_in_english/models/word_status.dart';
import 'package:bla_bla_in_english/pages/word_search_page.dart';
import 'package:bla_bla_in_english/repositories/session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A dictionary of 120 words that records how it was paged through.
///
/// `noSuchMethod` covers the rest of the repository: this screen only ever
/// calls [searchWords], and a real database in a widget test fights the fake
/// clock the test runs on.
class _FakeRepository implements SessionRepository {
  final List<int> offsets = [];
  final List<String> queries = [];

  static final List<String> words = [
    for (var i = 1; i <= 120; i++) 'palavra${i.toString().padLeft(3, '0')}',
  ];

  @override
  Future<List<WordSearchResult>> searchWords(
    String query, {
    int limit = SessionRepository.searchPageSize,
    int offset = 0,
  }) async {
    offsets.add(offset);
    queries.add(query);

    final term = query.trim().toLowerCase();
    final matches = term.isEmpty
        ? words
        : [
            for (final word in words)
              if (word.startsWith(term)) word,
          ];

    return [
      for (final word in matches.skip(offset).take(limit))
        WordSearchResult(
          wordId: words.indexOf(word) + 1,
          word: word,
          status: WordStatus.fresh,
          inTodaySession: false,
        ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  late _FakeRepository repository;

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    repository = _FakeRepository();
    await tester.pumpWidget(
      Provider<SessionRepository>.value(
        value: repository,
        child: const MaterialApp(home: WordSearchPage()),
      ),
    );
    // One frame to run initState's load, one to build what it returned.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('opens on the dictionary instead of an empty screen',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('palavra001'), findsOneWidget);
    expect(repository.offsets, [0]);
    expect(repository.queries, ['']);
    expect(
      find.textContaining('Todo o dicionário'),
      findsOneWidget,
      reason: 'the list needs to say what it is showing',
    );
  });

  testWidgets('scrolling to the bottom pulls the next page', (tester) async {
    await pumpPage(tester);
    expect(repository.offsets, [0]);

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pump();
    await tester.pump();

    expect(repository.offsets, [0, 40], reason: 'a second page was asked for');

    // A word from the second page is now reachable.
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pump();
    expect(find.text('palavra050'), findsOneWidget);
  });

  testWidgets('keeps paging until the dictionary runs out', (tester) async {
    await pumpPage(tester);

    for (var i = 0; i < 5; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pump();
      await tester.pump();
    }

    expect(repository.offsets, [0, 40, 80, 120]);
    // 120 is a short page (empty), so the list stops asking and drops the
    // trailing spinner.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('typing restarts the list from the first page', (tester) async {
    await pumpPage(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pump();
    await tester.pump();
    expect(repository.offsets, [0, 40]);

    await tester.enterText(find.byType(TextField), 'palavra01');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(repository.offsets.last, 0, reason: 'a new query starts over');
    expect(repository.queries.last, 'palavra01');
    expect(find.text('palavra010'), findsOneWidget);
    expect(find.text('palavra050'), findsNothing);
  });

  testWidgets('a search with no matches says so', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.textContaining('Nenhuma palavra encontrada'), findsOneWidget);
  });

  testWidgets('picking words keeps them through a new search', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('palavra001'));
    await tester.pump();
    expect(find.text('Adicionar 1 à sessão de hoje'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'palavra09');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(
      find.text('Adicionar 1 à sessão de hoje'),
      findsOneWidget,
      reason: 'a word chosen before the search must not be dropped by it',
    );
  });
}
