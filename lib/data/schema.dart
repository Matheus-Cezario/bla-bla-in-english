/// The app keeps two SQLite files side by side:
///
///  * `dictionary.db` — read-only content (words, sentences, options), built by
///    `tool/generate_dictionary.dart` and shipped as an asset. Regenerating the
///    dictionary is a file swap; no on-device migration, no user data at risk.
///  * `progress.db` — everything the user produces. Lives only on the device.
///
/// `progress.db` is the connection the app opens; `dictionary.db` is ATTACHed
/// to it under the [dictionaryAlias] schema, so a single query can join a word
/// to its progress. SQLite does not enforce foreign keys across attached
/// databases, which is why the progress tables reference word ids without a
/// FOREIGN KEY clause.
library;

/// Schema alias the dictionary is attached under.
const String dictionaryAlias = 'dict';

/// Bump together with a migration in `AppDatabase._migrateProgress`.
const int progressSchemaVersion = 1;

/// Bump when the generator changes the dictionary layout. The app refuses to
/// run against a dictionary built for a different version.
const int dictionarySchemaVersion = 1;

/// Statements that build `dictionary.db`. Used by the generator, and by tests.
const List<String> dictionarySchema = [
  '''
  CREATE TABLE words (
    id              INTEGER PRIMARY KEY,
    word            TEXT    NOT NULL UNIQUE,
    -- Position in a frequency list; drives the order new words are introduced,
    -- so the user meets common words before rare ones.
    frequency_rank  INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_words_frequency ON words (frequency_rank)',
  '''
  CREATE TABLE sentences (
    id        INTEGER PRIMARY KEY,
    word_id   INTEGER NOT NULL REFERENCES words (id) ON DELETE CASCADE,
    -- 1..5; the order the sentences of a word are worked through.
    position  INTEGER NOT NULL,
    -- The target word is wrapped in '#', e.g. 'The #book# is on the table.'
    text      TEXT    NOT NULL,
    UNIQUE (word_id, position)
  )
  ''',
  '''
  CREATE TABLE options (
    id           INTEGER PRIMARY KEY,
    sentence_id  INTEGER NOT NULL REFERENCES sentences (id) ON DELETE CASCADE,
    -- An English definition of the word as used in that sentence.
    text         TEXT    NOT NULL,
    -- AnswerKind: 0 correct, 1 near, 2 wrong. One row of each per sentence.
    kind         INTEGER NOT NULL,
    UNIQUE (sentence_id, kind)
  )
  ''',
];

/// Statements that build an empty `progress.db`.
const List<String> progressSchema = [
  '''
  -- Current state of every word the user has touched. A word with no row here
  -- has never been practised and counts as WordStatus.fresh.
  CREATE TABLE word_progress (
    word_id           INTEGER PRIMARY KEY,
    -- WordStatus id, derived from the most recent answer.
    status            INTEGER NOT NULL,
    -- Which sentence (1..5) this word shows next. Wraps back to 1 after 5 so a
    -- fully-seen word can still come back for review.
    next_position     INTEGER NOT NULL DEFAULT 1,
    times_answered    INTEGER NOT NULL DEFAULT 0,
    last_answered_at  INTEGER
  )
  ''',
  'CREATE INDEX idx_progress_status ON word_progress (status, last_answered_at)',
  '''
  -- Full answer history, kept separate from word_progress so statistics and
  -- future scheduling changes are not limited by what the current state keeps.
  CREATE TABLE answers (
    id           INTEGER PRIMARY KEY,
    word_id      INTEGER NOT NULL,
    sentence_id  INTEGER NOT NULL,
    kind         INTEGER NOT NULL,
    answered_at  INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_answers_word ON answers (word_id, answered_at)',
  '''
  -- One row per day the user practises. Storing the plan makes the day's list
  -- stable across app restarts instead of being re-drawn on every launch.
  CREATE TABLE sessions (
    id            INTEGER PRIMARY KEY,
    -- Local calendar day, 'YYYY-MM-DD'.
    day           TEXT    NOT NULL UNIQUE,
    target_words  INTEGER NOT NULL,
    created_at    INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE session_items (
    id            INTEGER PRIMARY KEY,
    session_id    INTEGER NOT NULL REFERENCES sessions (id) ON DELETE CASCADE,
    word_id       INTEGER NOT NULL,
    sentence_id   INTEGER NOT NULL,
    -- Order within the session.
    position      INTEGER NOT NULL,
    -- The bucket the word was drawn from, kept for the end-of-session summary.
    drawn_status  INTEGER NOT NULL,
    -- AnswerKind id, or NULL while unanswered.
    answered_kind INTEGER,
    answered_at   INTEGER,
    UNIQUE (session_id, position)
  )
  ''',
  'CREATE INDEX idx_session_items_session ON session_items (session_id, position)',
  '''
  CREATE TABLE settings (
    key    TEXT PRIMARY KEY,
    value  TEXT NOT NULL
  )
  ''',
];
