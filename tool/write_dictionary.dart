import 'dart:io';

import 'package:bla_bla_in_english/data/schema.dart';
import 'package:bla_bla_in_english/data/stable_id.dart';
import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:bla_bla_in_english/services/dictionary_content.dart';

/// Writes [entries] to a fresh dictionary file at [path].
///
/// Uses `package:sqlite3` rather than `sqflite_common_ffi`: the latter crashes
/// the Dart FFI transformer under plain `dart run` on this SDK, and the tool
/// scripts are CLI programs, not Flutter apps.
///
/// The file is always rebuilt from scratch. The app treats the dictionary as
/// immutable content and swaps it wholesale, so a half-updated file would be
/// worse than no file.
void writeDictionary(List<WordEntry> entries, String path) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  if (file.existsSync()) file.deleteSync();

  final db = sqlite3.open(path);
  try {
    for (final statement in dictionarySchema) {
      db.execute(statement);
    }

    // Rank order keeps ids and frequency aligned, which makes the generated
    // file easier to eyeball.
    entries.sort((a, b) => a.frequencyRank.compareTo(b.frequencyRank));

    final insertWord = db.prepare(
      'INSERT INTO words (id, word, frequency_rank) VALUES (?, ?, ?)',
    );
    final insertSentence = db.prepare(
      'INSERT INTO sentences (id, word_id, position, text) VALUES (?, ?, ?, ?)',
    );
    final insertOption = db.prepare(
      'INSERT INTO options (id, sentence_id, text, kind) VALUES (?, ?, ?, ?)',
    );

    // Guards the (astronomically unlikely) hash collision. Silently merging two
    // words into one id would be far worse than failing here.
    final seenIds = <int, String>{};
    void claim(int id, String what) {
      final previous = seenIds[id];
      if (previous != null) {
        throw StateError('id collision: "$what" and "$previous" both hash to $id');
      }
      seenIds[id] = what;
    }

    db.execute('BEGIN');
    for (final entry in entries) {
      final wordId = stableId(entry.word);
      claim(wordId, entry.word);
      insertWord.execute([wordId, entry.word, entry.frequencyRank]);

      for (final (index, sentence) in entry.sentences.indexed) {
        final position = index + 1;
        final sentenceId = sentenceIdFor(entry.word, position);
        claim(sentenceId, '${entry.word} sentence $position');
        insertSentence.execute([sentenceId, wordId, position, sentence.text]);

        for (final (kind, text) in [
          (0, sentence.correct),
          (1, sentence.near),
          (2, sentence.wrong),
        ]) {
          final optionId = optionIdFor(entry.word, position, kind);
          claim(optionId, '${entry.word} sentence $position option $kind');
          insertOption.execute([optionId, sentenceId, text, kind]);
        }
      }
    }
    db.execute('COMMIT');

    insertWord.close();
    insertSentence.close();
    insertOption.close();
  } finally {
    db.close();
  }

  final size = file.lengthSync();
  final version = _writeVersionStamp(file);

  stdout.writeln(
    'Wrote ${entries.length} words '
    '(${entries.length * sentencesPerWord} sentences) to $path '
    '— ${(size / 1024).toStringAsFixed(0)} KB',
  );
  stdout.writeln('Version stamp: $version');
}

/// Writes the content hash beside the database it describes.
///
/// The app uses this to decide whether an installed copy is stale. File size
/// alone is not enough: SQLite pads to 4 KB pages, so editing one definition
/// leaves the size identical and a size check would silently keep serving the
/// old dictionary to anyone who already installed the app.
///
/// The path is derived from [database] rather than fixed, so writing a test
/// dictionary somewhere else cannot overwrite the stamp of the real asset —
/// which would leave the shipped pair permanently mismatched.
String _writeVersionStamp(File database) {
  final digest = sha256.convert(database.readAsBytesSync()).toString();
  File(versionPathFor(database.path)).writeAsStringSync(digest);
  return digest.substring(0, 12);
}

/// `.../dictionary.db` -> `.../dictionary.version`
String versionPathFor(String databasePath) =>
    '${databasePath.substring(0, databasePath.lastIndexOf('.'))}.version';
