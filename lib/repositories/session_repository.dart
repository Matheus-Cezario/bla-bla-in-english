import 'package:bla_bla_in_english/data/schema.dart';
import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:bla_bla_in_english/models/meaning_option.dart';
import 'package:bla_bla_in_english/models/practice_item.dart';
import 'package:bla_bla_in_english/models/word_search_result.dart';
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
    return _loadItems(await _todaySessionId(wordsPerDay));
  }

  /// Draws another [wordsPerDay] words into today's session, for the user who
  /// finished the day's list and wants to keep going.
  ///
  /// Words already in the session are excluded from the draw: after a session
  /// of twenty wrong answers the "wrong" bucket holds exactly those twenty
  /// words, and without the exclusion the extension would hand every one of
  /// them straight back.
  ///
  /// Returns the whole session, extension included. When the dictionary has
  /// nothing left to offer, the session comes back unchanged and its target is
  /// left alone. On a day with no session yet there is nothing to extend, so
  /// this just plans the day.
  Future<List<PracticeItem>> extendTodaySession({
    required int wordsPerDay,
  }) async {
    final sessionId = await _todaySessionIdOrNull();
    if (sessionId == null) {
      // Nothing to extend yet: planning the day is the whole job.
      return _loadItems(await _createSession(dayKey(), wordsPerDay));
    }

    final candidates = planner.plan(
      byStatus: await _candidatesByStatus(
        limitPerBucket: wordsPerDay,
        excluding: await _wordIdsIn(sessionId),
      ),
      targetWords: wordsPerDay,
    );
    if (candidates.isNotEmpty) await _appendItems(sessionId, candidates);

    return _loadItems(sessionId);
  }

  /// Appends hand-picked words — the ones chosen on the search screen — to
  /// today's session, in the order they were picked.
  ///
  /// Words the session already holds are skipped, so confirming the same
  /// selection twice cannot queue a word twice.
  Future<List<PracticeItem>> addWordsToTodaySession({
    required List<int> wordIds,
    required int wordsPerDay,
  }) async {
    final sessionId = await _todaySessionId(wordsPerDay);
    final drawn = await _wordIdsIn(sessionId);
    final wanted = [
      for (final id in wordIds)
        if (!drawn.contains(id)) id,
    ];
    if (wanted.isEmpty) return _loadItems(sessionId);

    final candidates = await _candidatesFor(wanted);
    if (candidates.isNotEmpty) await _appendItems(sessionId, candidates);

    return _loadItems(sessionId);
  }

  /// How many words one page of the search screen holds.
  static const int searchPageSize = 40;

  /// One page of dictionary words for the search screen.
  ///
  /// With an empty [query] this is the whole dictionary in the order the app
  /// introduces words — most common first — so the screen has something to
  /// browse before anything is typed.
  ///
  /// With a query it matches by prefix: exact first, then the shortest, then
  /// the most common. Typing `run` offers `run` before `runaway`.
  Future<List<WordSearchResult>> searchWords(
    String query, {
    int limit = searchPageSize,
    int offset = 0,
  }) async {
    final term = query.trim().toLowerCase();

    // -1 never matches a session id, so a day with no session planned yet
    // simply reports every word as "not in the session".
    final sessionId = await _todaySessionIdOrNull() ?? -1;

    // The tiebreaker on w.id earns its keep here: paging walks the same
    // ORDER BY twice at different offsets, and two rows the sort cannot
    // separate are free to swap places between the calls — which shows one
    // word twice on the seam and silently skips another.
    final filter = term.isEmpty ? '' : "WHERE w.word LIKE ? ESCAPE '\\'";
    final order = term.isEmpty
        ? 'ORDER BY w.frequency_rank, w.id'
        : 'ORDER BY (w.word = ?) DESC, LENGTH(w.word), w.frequency_rank, w.id';

    // Placeholders bind in the order they appear in the statement: the session
    // id inside the SELECT, then the filter's, then the order's, then paging.
    final rows = await _db.rawQuery('''
      SELECT
        w.id     AS word_id,
        w.word   AS word,
        p.status AS status,
        EXISTS (
          SELECT 1 FROM session_items si
          WHERE si.session_id = ? AND si.word_id = w.id
        ) AS in_session
      FROM $dictionaryAlias.words w
      LEFT JOIN word_progress p ON p.word_id = w.id
      $filter
      $order
      LIMIT ? OFFSET ?
    ''', [
      sessionId,
      if (term.isNotEmpty) ...['${_escapeLike(term)}%', term],
      limit,
      offset,
    ]);

    return [
      for (final row in rows)
        WordSearchResult(
          wordId: row['word_id']! as int,
          word: row['word']! as String,
          status: row['status'] == null
              ? WordStatus.fresh
              : WordStatus.fromId(row['status']! as int),
          inTodaySession: (row['in_session']! as int) == 1,
        ),
    ];
  }

  /// `%` and `_` are wildcards in LIKE, so a user typing one must not turn
  /// their search into a match-everything pattern.
  static String _escapeLike(String term) => term
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  Future<int?> _todaySessionIdOrNull() async {
    final rows = await _db.query(
      'sessions',
      columns: ['id'],
      where: 'day = ?',
      whereArgs: [dayKey()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id']! as int;
  }

  /// Today's session id, planning the day on the first call.
  Future<int> _todaySessionId(int wordsPerDay) async {
    final existing = await _todaySessionIdOrNull();
    return existing ?? await _createSession(dayKey(), wordsPerDay);
  }

  Future<Set<int>> _wordIdsIn(int sessionId) async {
    final rows = await _db.query(
      'session_items',
      columns: ['word_id'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return {for (final row in rows) row['word_id']! as int};
  }

  /// Where the next item goes. Read from the items themselves rather than from
  /// `target_words`, which counts what the day aims for and drifts away from
  /// the real positions as soon as the dictionary runs short.
  Future<int> _nextPosition(int sessionId) async {
    final rows = await _db.rawQuery(
      'SELECT MAX(position) AS last FROM session_items WHERE session_id = ?',
      [sessionId],
    );
    final last = rows.first['last'] as int?;
    return last == null ? 0 : last + 1;
  }

  /// Adds [candidates] to the end of a session and raises its target to match.
  Future<void> _appendItems(
    int sessionId,
    List<WordCandidate> candidates,
  ) async {
    final start = await _nextPosition(sessionId);

    await _db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE sessions SET target_words = target_words + ? WHERE id = ?',
        [candidates.length, sessionId],
      );

      final batch = txn.batch();
      for (var i = 0; i < candidates.length; i++) {
        final candidate = candidates[i];
        batch.insert('session_items', {
          'session_id': sessionId,
          'word_id': candidate.wordId,
          'sentence_id': candidate.sentenceId,
          'position': start + i,
          'drawn_status': candidate.status.id,
        });
      }
      await batch.commit(noResult: true);
    });
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

  /// Resolves hand-picked words to the sentence they should show next — where
  /// the user left the word off, or its first sentence if it is new — keeping
  /// the order the ids came in.
  Future<List<WordCandidate>> _candidatesFor(List<int> wordIds) async {
    final placeholders = List.filled(wordIds.length, '?').join(',');
    final rows = await _db.rawQuery('''
      SELECT
        w.id     AS word_id,
        w.word   AS word,
        p.status AS status,
        COALESCE(
          (SELECT s.id FROM $dictionaryAlias.sentences s
             WHERE s.word_id = w.id AND s.position = COALESCE(p.next_position, 1)),
          (SELECT s.id FROM $dictionaryAlias.sentences s
             WHERE s.word_id = w.id ORDER BY s.position LIMIT 1)
        ) AS sentence_id
      FROM $dictionaryAlias.words w
      LEFT JOIN word_progress p ON p.word_id = w.id
      WHERE w.id IN ($placeholders)
    ''', wordIds);

    final byId = {
      for (final row in rows)
        // A word with no sentence at all cannot be practised; drop it rather
        // than writing a session item that points at nothing.
        if (row['sentence_id'] != null)
          row['word_id']! as int: WordCandidate(
            wordId: row['word_id']! as int,
            word: row['word']! as String,
            status: row['status'] == null
                ? WordStatus.fresh
                : WordStatus.fromId(row['status']! as int),
            sentenceId: row['sentence_id']! as int,
          ),
    };

    return [
      for (final id in wordIds)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }

  /// Gathers eligible words per bucket, each already ordered by how much it
  /// deserves to come back first. [excluding] drops the words a session is
  /// already holding.
  Future<Map<WordStatus, List<WordCandidate>>> _candidatesByStatus({
    required int limitPerBucket,
    Set<int> excluding = const {},
  }) async {
    final skip = excluding.toList();
    final skipClause = skip.isEmpty
        ? ''
        : 'AND w.id NOT IN (${List.filled(skip.length, '?').join(',')})';

    // Never practised: introduce the most common words first.
    final freshQuery = '''
      SELECT w.id AS word_id, w.word, s.id AS sentence_id
      FROM $dictionaryAlias.words w
      JOIN $dictionaryAlias.sentences s
        ON s.word_id = w.id AND s.position = 1
      WHERE NOT EXISTS (
        SELECT 1 FROM word_progress p WHERE p.word_id = w.id
      )
      $skipClause
      ORDER BY w.frequency_rank
      LIMIT ?
    ''';

    // Seen before: the one left alone longest comes back first.
    final seenQuery = '''
      SELECT w.id AS word_id, w.word, s.id AS sentence_id
      FROM word_progress p
      JOIN $dictionaryAlias.words w ON w.id = p.word_id
      JOIN $dictionaryAlias.sentences s
        ON s.word_id = p.word_id AND s.position = p.next_position
      WHERE p.status = ?
      $skipClause
      ORDER BY p.last_answered_at ASC
      LIMIT ?
    ''';

    final result = <WordStatus, List<WordCandidate>>{};

    for (final status in WordStatus.values) {
      final rows = status == WordStatus.fresh
          ? await _db.rawQuery(freshQuery, [...skip, limitPerBucket])
          : await _db.rawQuery(seenQuery, [status.id, ...skip, limitPerBucket]);

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
