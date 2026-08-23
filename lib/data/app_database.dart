import 'dart:io';

import 'package:bla_bla_in_english/data/dictionary_assets.dart';
import 'package:bla_bla_in_english/data/schema.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens `progress.db` with `dictionary.db` attached, and keeps the single
/// connection the rest of the app uses.
///
/// The dictionary asset is copied to the device on first run and re-copied
/// whenever the bundled asset is newer than the copy (see [_syncDictionary]),
/// which is how a regenerated dictionary reaches an already-installed app.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static AppDatabase? _instance;

  static Future<AppDatabase> open() async {
    if (_instance != null) return _instance!;

    final dbDir = await getDatabasesPath();
    await Directory(dbDir).create(recursive: true);

    final dictionaryPath = p.join(dbDir, 'dictionary.db');
    await _syncDictionary(dictionaryPath);

    final database = await openDatabase(
      p.join(dbDir, 'progress.db'),
      version: progressSchemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        final batch = db.batch();
        for (final statement in progressSchema) {
          batch.execute(statement);
        }
        await batch.commit(noResult: true);
      },
      onUpgrade: _migrateProgress,
    );

    // Attach after opening so every query can reach `dict.words` and friends.
    await database.execute(
      "ATTACH DATABASE ? AS $dictionaryAlias",
      [dictionaryPath],
    );

    return _instance = AppDatabase._(database);
  }

  /// Copies the bundled dictionary onto the device when the installed copy is
  /// missing or stale.
  ///
  /// Staleness is decided by the generator's content hash, not by file size.
  /// SQLite pads to 4 KB pages, so a regenerated dictionary that fixes a typo
  /// or keeps the same word count is byte-for-byte a different file at exactly
  /// the same size — a size check would leave every existing install on the old
  /// content, silently, forever.
  static Future<void> _syncDictionary(String destinationPath) async {
    final bundledVersion =
        (await rootBundle.loadString(dictionaryVersionPath)).trim();

    final stampFile = File('$destinationPath.version');
    final database = File(destinationPath);

    if (database.existsSync() && stampFile.existsSync()) {
      final installedVersion = (await stampFile.readAsString()).trim();
      if (installedVersion == bundledVersion) return;
    }

    final bytes = await rootBundle.load(dictionaryAssetPath);
    await database.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    // Written only after the copy succeeds, so a failure mid-copy retries on
    // the next launch instead of marking a partial file as current.
    await stampFile.writeAsString(bundledVersion, flush: true);
  }

  static Future<void> _migrateProgress(Database db, int from, int to) async {
    // No migrations yet; progressSchemaVersion is still 1.
  }

  Future<void> close() async {
    await db.close();
    _instance = null;
  }
}
