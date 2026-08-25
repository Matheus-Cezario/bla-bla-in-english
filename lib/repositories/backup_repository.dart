import 'dart:io';
import 'dart:typed_data';

import 'package:bla_bla_in_english/data/schema.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Raised when the file the user picked is not a progress backup this app can
/// read. Carries a message meant to be shown as-is.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What a backup contains, so a restore can report what it brought back.
class BackupSummary {
  const BackupSummary({required this.answers, required this.words});

  final int answers;
  final int words;
}

/// Saves and restores everything the user has produced.
///
/// Android gives an app a private directory and deletes it along with the app.
/// Nothing written from inside the app can survive its own uninstall, so the
/// only real guarantee is a file the user keeps somewhere the app cannot reach.
/// That is what this class produces.
class BackupRepository {
  const BackupRepository(this._db);

  final Database _db;

  /// The schema a restore is attached under. Sits alongside the dictionary's
  /// own alias for the length of one restore.
  static const String _restoreAlias = 'restore';

  static const String _stagingName = 'restore-staging.db';

  /// The progress tables and the columns copied out of them, listed so a
  /// restore never depends on two files happening to declare their columns in
  /// the same order.
  ///
  /// The order matters: `session_items` references `sessions`, so sessions are
  /// written first — and, running the list backwards, cleared last.
  static const Map<String, List<String>> _tables = {
    'word_progress': [
      'word_id',
      'status',
      'next_position',
      'times_answered',
      'last_answered_at',
    ],
    'answers': ['id', 'word_id', 'sentence_id', 'kind', 'answered_at'],
    'sessions': ['id', 'day', 'target_words', 'created_at'],
    'session_items': [
      'id',
      'session_id',
      'word_id',
      'sentence_id',
      'position',
      'drawn_status',
      'answered_kind',
      'answered_at',
    ],
    'settings': ['key', 'value'],
  };

  /// Writes a copy of the progress database and returns it, ready to be handed
  /// to the share sheet.
  ///
  /// Only one export is kept: the previous one is replaced rather than piling
  /// up copies of a database inside the app's own storage.
  Future<File> export({DateTime? at}) async {
    // Fold the write-ahead log back into the main file first. A plain copy
    // taken while the -wal still holds recent answers would be a backup of
    // yesterday, which is the kind of bug you only discover when restoring.
    await _db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');

    final directory = Directory(p.join(p.dirname(_db.path), 'backups'));
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
    directory.createSync(recursive: true);

    final target = p.join(directory.path, fileNameFor(at ?? DateTime.now()));
    return File(_db.path).copy(target);
  }

  /// `bla-bla-progresso-2026-08-24.db`
  static String fileNameFor(DateTime at) {
    final month = at.month.toString().padLeft(2, '0');
    final day = at.day.toString().padLeft(2, '0');
    return 'bla-bla-progresso-${at.year}-$month-$day.db';
  }

  /// Replaces every bit of progress with what [bytes] holds.
  ///
  /// Takes bytes rather than a path because the Android file picker hands back
  /// a `content://` stream as often as a real file, and SQLite can only attach
  /// something on disk.
  ///
  /// The rows are copied into the live database instead of the file being
  /// swapped underneath it: the app holds this connection open, with the
  /// dictionary attached to it, and replacing the file under an open handle is
  /// how databases get corrupted. It also means one failed statement rolls the
  /// whole restore back and leaves the user where they were.
  Future<BackupSummary> restore(Uint8List bytes) async {
    final staging = File(p.join(p.dirname(_db.path), _stagingName));
    await staging.writeAsBytes(bytes, flush: true);

    try {
      await _db.execute('ATTACH DATABASE ? AS $_restoreAlias', [staging.path]);
    } on DatabaseException {
      await staging.delete();
      throw const BackupFormatException(
        'Esse arquivo não é um backup do Blá Blá in English.',
      );
    }

    try {
      await _verify();
      final summary = await _summarise();

      await _db.transaction((txn) async {
        for (final table in _tables.keys.toList().reversed) {
          await txn.delete(table);
        }
        for (final entry in _tables.entries) {
          final columns = entry.value.join(', ');
          await txn.rawInsert(
            'INSERT INTO ${entry.key} ($columns) '
            'SELECT $columns FROM $_restoreAlias.${entry.key}',
          );
        }
      });

      return summary;
    } finally {
      await _db.execute('DETACH DATABASE $_restoreAlias');
      if (staging.existsSync()) await staging.delete();
    }
  }

  /// Refuses anything that is not this app's progress database before a single
  /// row is deleted. A restore is destructive; finding out halfway through that
  /// the file was the dictionary is too late.
  Future<void> _verify() async {
    final version = Sqflite.firstIntValue(
      await _db.rawQuery('PRAGMA $_restoreAlias.user_version'),
    );
    if (version != progressSchemaVersion) {
      throw BackupFormatException(
        version == 0
            ? 'Esse arquivo não é um backup do Blá Blá in English.'
            : 'Esse backup é da versão $version do app e esta espera a '
                '$progressSchemaVersion.',
      );
    }

    final present = {
      for (final row in await _db.rawQuery(
        "SELECT name FROM $_restoreAlias.sqlite_master WHERE type = 'table'",
      ))
        row['name']! as String,
    };
    final missing = _tables.keys.where((table) => !present.contains(table));
    if (missing.isNotEmpty) {
      throw BackupFormatException(
        'O backup está incompleto: falta ${missing.join(', ')}.',
      );
    }
  }

  Future<BackupSummary> _summarise() async {
    final answers = Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM $_restoreAlias.answers'),
        ) ??
        0;
    final words = Sqflite.firstIntValue(
          await _db
              .rawQuery('SELECT COUNT(*) FROM $_restoreAlias.word_progress'),
        ) ??
        0;
    return BackupSummary(answers: answers, words: words);
  }
}
