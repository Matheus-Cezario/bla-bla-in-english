import 'package:bla_bla_in_english/data/schema.dart';
import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:bla_bla_in_english/models/meaning_option.dart';
import 'package:bla_bla_in_english/models/practice_item.dart';
import 'package:bla_bla_in_english/models/word_status.dart';
import 'package:bla_bla_in_english/services/session_planner.dart';
import 'package:sqflite/sqflite.dart';

/// Reads and writes everything about a day's practice session.
class SessionRepository {
  const SessionRepository(this._db, {this.planner = const SessionPlanner()});

  final Database _db;
  final SessionPlanner planner;

  /// The local calendar day used to key sessions.
  static String dayKey([DateTime? at]) {
    final date = at ?? DateTime.now();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Returns today's session, planning it on the first call of the day.
  ///
  /// The plan is persisted, so reopening the app mid-session resumes the same
  /// list of words rather than drawing a new one.
  Future<List<PracticeItem>> todaySession({required int wordsPerDay}) async {
    final day = dayKey();
    final existing = await _db.query(
      'sessions',
      columns: ['id'],
      where: 'day = ?',
      whereArgs: [day],
      limit: 1,
    );

    final sessionId = existing.isNotEmpty
        ? existing.first['id']! as int
        : await _createSession(day, wordsPerDay);

    return _loadItems(sessionId);
  }

  Future<int> _createSession(String day, int wordsPerDay) async {
    final candidates = planner.plan(
      byStatus: await _candidatesByStatus(limitPerBucket: wordsPerDay),
      targetWords: wordsPerDay,
    );

    return _db.transaction((txn) async {
      final sessionId = await txn.insert('sessions', {
        'day': day,
        'target_words': wordsPerDay,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      final batch = txn.batch();
      for (var i = 0; i < candidates.length; i++) {
        final candidate = candidates[i];
        batch.insert('session_items', {
          'session_id': sessionId,
          'word_id': candidate.wordId,
          'sentence_id': candidate.sentenceId,
          'position': i,
          'drawn_status': candidate.status.id,
        });
      }
      await batch.commit(noResult: true);

      return sessionId;
    });
  }

  /// Gathers eligible words per bucket, each already ordered by how much it
  /// deserves to come back first.
  Future<Map<WordStatus, List<WordCandidate>>> _candidatesByStatus({
    required int limitPerBucket,
  }) async {
    // Never practised: introduce the most common words first.
    const freshQuery = '''
      SELECT w.id AS word_id, w.word, s.id AS sentence_id
      FROM $dictionaryAlias.words w
      JOIN $dictionaryAlias.sentences s
        ON s.word_id = w.id AND s.position = 1
      WHERE NOT EXISTS (
        SELECT 1 FROM word_progress p WHERE p.word_id = w.id
      )
      ORDER BY w.frequency_rank
      LIMIT ?
    ''';

    // Seen before: the one left alone longest comes back first.
    const seenQuery = '''
      SELECT w.id AS word_id, w.word, s.id AS sentence_id
      FROM word_progress p
      JOIN $dictionaryAlias.words w ON w.id = p.word_id
      JOIN $dictionaryAlias.sentences s
        ON s.word_id = p.word_id AND s.position = p.next_position
      WHERE p.status = ?
      ORDER BY p.last_answered_at ASC
      LIMIT ?
    ''';

    final result = <WordStatus, List<WordCandidate>>{};

    for (final status in WordStatus.values) {
      final rows = status == WordStatus.fresh
          ? await _db.rawQuery(freshQuery, [limitPerBucket])
          : await _db.rawQuery(seenQuery, [status.id, limitPerBucket]);

      result[status] = [
        for (final row in rows)
          WordCandidate(
            wordId: row['word_id']! as int,
            word: row['word']! as String,
            status: status,
            sentenceId: row['sentence_id']! as int,
          ),
      ];
    }

    return result;
  }

  Future<List<PracticeItem>> _loadItems(int sessionId) async {
    const itemsQuery = '''
      SELECT
        si.id            AS session_item_id,
        si.word_id       AS word_id,
        si.sentence_id   AS sentence_id,
        si.answered_kind AS answered_kind,
        w.word           AS word,
        s.text           AS sentence_text
      FROM session_items si
      JOIN $dictionaryAlias.words w ON w.id = si.word_id
      JOIN $dictionaryAlias.sentences s ON s.id = si.sentence_id
      WHERE si.session_id = ?
      ORDER BY si.position
    ''';

    final rows = await _db.rawQuery(itemsQuery, [sessionId]);
    if (rows.isEmpty) return const [];

    final optionsBySentence = await _optionsFor(
      rows.map((row) => row['sentence_id']! as int).toList(),
    );

    return [
      for (final row in rows)
        PracticeItem(
          sessionItemId: row['session_item_id']! as int,
          wordId: row['word_id']! as int,
          word: row['word']! as String,
          sentenceId: row['sentence_id']! as int,
          sentenceText: row['sentence_text']! as String,
          options: optionsBySentence[row['sentence_id']] ?? const [],
          answeredKind: row['answered_kind'] == null
              ? null
              : AnswerKind.fromId(row['answered_kind']! as int),
        ),
    ];
  }

  /// Loads the three options for every sentence in one query.
  ///
  /// Options are ordered by a key derived from the sentence and option ids, so
  /// the order is stable: reopening the app must not move the right answer
  /// around, and the correct option must not always sit in the same slot.
  Future<Map<int, List<MeaningOption>>> _optionsFor(
    List<int> sentenceIds,
  ) async {
    final placeholders = List.filled(sentenceIds.length, '?').join(',');
    final rows = await _db.rawQuery(
      'SELECT id, sentence_id, text, kind FROM $dictionaryAlias.options '
      'WHERE sentence_id IN ($placeholders)',
      sentenceIds,
    );

    final grouped = <int, List<MeaningOption>>{};
    for (final row in rows) {
      grouped
          .putIfAbsent(row['sentence_id']! as int, () => <MeaningOption>[])
          .add(MeaningOption.fromRow(row));
    }

    for (final entry in grouped.entries) {
      entry.value.sort(
        (a, b) => _shuffleKey(entry.key, a.id).compareTo(
          _shuffleKey(entry.key, b.id),
        ),
      );
    }
    return grouped;
  }

  static int _shuffleKey(int sentenceId, int optionId) =>
      (sentenceId * 7919 + optionId * 40503) % 997;

  /// Records an answer: appends to history, advances the word, and marks the
  /// session item. All three must land together, hence the transaction.
  Future<void> recordAnswer({
    required PracticeItem item,
    required AnswerKind kind,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final status = WordStatus.fromAnswer(kind);

    // Advance to the word's next sentence, wrapping after the last one so a
    // finished word can still come back for review.
    const progressUpsert = '''
      INSERT INTO word_progress
        (word_id, status, next_position, times_answered, last_answered_at)
      VALUES (?, ?, 2, 1, ?)
      ON CONFLICT (word_id) DO UPDATE SET
        status = excluded.status,
        times_answered = word_progress.times_answered + 1,
        last_answered_at = excluded.last_answered_at,
        next_position = CASE
          WHEN word_progress.next_position >= (
            SELECT COUNT(*) FROM $dictionaryAlias.sentences
            WHERE word_id = word_progress.word_id
          ) THEN 1
          ELSE word_progress.next_position + 1
        END
    ''';

    await _db.transaction((txn) async {
      await txn.insert('answers', {
        'word_id': item.wordId,
        'sentence_id': item.sentenceId,
        'kind': kind.id,
        'answered_at': now,
      });

      await txn.rawInsert(progressUpsert, [item.wordId, status.id, now]);

      await txn.update(
        'session_items',
        {'answered_kind': kind.id, 'answered_at': now},
        where: 'id = ?',
        whereArgs: [item.sessionItemId],
      );
    });

    item.answeredKind = kind;
  }
}
