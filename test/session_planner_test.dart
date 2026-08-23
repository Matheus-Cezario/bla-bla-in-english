import 'package:bla_bla_in_english/models/word_status.dart';
import 'package:bla_bla_in_english/services/session_planner.dart';
import 'package:flutter_test/flutter_test.dart';

Map<WordStatus, List<WordCandidate>> buckets({
  int wrong = 0,
  int near = 0,
  int fresh = 0,
  int learned = 0,
}) {
  var id = 0;
  List<WordCandidate> make(WordStatus status, int count) => [
        for (var i = 0; i < count; i++)
          WordCandidate(
            wordId: ++id,
            word: '${status.name}$i',
            status: status,
            sentenceId: id,
          ),
      ];
  return {
    WordStatus.wrong: make(WordStatus.wrong, wrong),
    WordStatus.near: make(WordStatus.near, near),
    WordStatus.fresh: make(WordStatus.fresh, fresh),
    WordStatus.learned: make(WordStatus.learned, learned),
  };
}

Map<WordStatus, int> countByStatus(List<WordCandidate> picked) {
  final counts = {for (final s in WordStatus.values) s: 0};
  for (final c in picked) {
    counts[c.status] = counts[c.status]! + 1;
  }
  return counts;
}

void main() {
  const planner = SessionPlanner();

  test('reserves one of every bucket, then fills by priority', () {
    final picked =
        planner.plan(byStatus: buckets(wrong: 50, near: 50, fresh: 50, learned: 50), targetWords: 20);

    expect(picked, hasLength(20));
    expect(countByStatus(picked), {
      WordStatus.wrong: 17,
      WordStatus.near: 1,
      WordStatus.fresh: 1,
      WordStatus.learned: 1,
    });
  });

  test('gives urgent buckets the slots when the target is smaller than 4', () {
    final picked =
        planner.plan(byStatus: buckets(wrong: 5, near: 5, fresh: 5, learned: 5), targetWords: 2);

    expect(picked.map((c) => c.status), [WordStatus.wrong, WordStatus.near]);
  });

  test('redistributes the reserved slots of empty buckets', () {
    // Nothing wrong and nothing learned yet: those slots must not be wasted.
    final picked =
        planner.plan(byStatus: buckets(near: 3, fresh: 40), targetWords: 10);

    expect(picked, hasLength(10));
    expect(countByStatus(picked), {
      WordStatus.wrong: 0,
      WordStatus.near: 3,
      WordStatus.fresh: 7,
      WordStatus.learned: 0,
    });
  });

  test('a fresh install draws only new words', () {
    final picked = planner.plan(byStatus: buckets(fresh: 100), targetWords: 20);

    expect(picked, hasLength(20));
    expect(picked.every((c) => c.status == WordStatus.fresh), isTrue);
  });

  test('returns everything available when the dictionary runs short', () {
    final picked =
        planner.plan(byStatus: buckets(wrong: 2, near: 1), targetWords: 20);

    expect(picked, hasLength(3));
  });

  test('preserves the order each bucket was given in', () {
    final picked = planner.plan(byStatus: buckets(wrong: 5), targetWords: 3);

    expect(picked.map((c) => c.word), ['wrong0', 'wrong1', 'wrong2']);
  });

  test('never returns the same word twice', () {
    final picked =
        planner.plan(byStatus: buckets(wrong: 30, near: 2, fresh: 2, learned: 2), targetWords: 25);

    expect(picked.map((c) => c.wordId).toSet(), hasLength(picked.length));
  });

  test('a larger reserve makes the session more balanced', () {
    const balanced = SessionPlanner(reservedPerBucket: 4);
    final picked = balanced.plan(
        byStatus: buckets(wrong: 50, near: 50, fresh: 50, learned: 50), targetWords: 20);

    expect(countByStatus(picked), {
      WordStatus.wrong: 8,
      WordStatus.near: 4,
      WordStatus.fresh: 4,
      WordStatus.learned: 4,
    });
  });

  test('an empty day yields nothing', () {
    expect(planner.plan(byStatus: buckets(), targetWords: 20), isEmpty);
    expect(planner.plan(byStatus: buckets(wrong: 5), targetWords: 0), isEmpty);
  });
}
