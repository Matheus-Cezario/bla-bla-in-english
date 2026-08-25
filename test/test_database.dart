import 'dart:io';

import 'package:bla_bla_in_english/data/schema.dart';
import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Builds a progress database with a dictionary attached, mirroring how
/// [AppDatabase] wires the two files together at runtime.
Future<Database> openTestDatabase(Directory dir, {required int words}) async {
  final dictionaryPath = p.join(dir.path, 'dictionary.db');

  final dictionary = await databaseFactoryFfi.openDatabase(dictionaryPath);
  for (final statement in dictionarySchema) {
    await dictionary.execute(statement);
  }

  // Every word gets 5 sentences, each with the three kinds of option, so the
  // fixtures match what the generator is contracted to produce.
  for (var w = 1; w <= words; w++) {
    await dictionary.insert('words', {
      'id': w,
      'word': 'word$w',
      'frequency_rank': w,
    });
    for (var position = 1; position <= 5; position++) {
      final sentenceId = w * 10 + position;
      await dictionary.insert('sentences', {
        'id': sentenceId,
        'word_id': w,
        'position': position,
        'text': 'A #word$w# in sentence $position.',
      });
      for (final kind in AnswerKind.values) {
        await dictionary.insert('options', {
          'sentence_id': sentenceId,
          'text': '${kind.name} meaning of word$w ($position)',
          'kind': kind.id,
        });
      }
    }
  }
  await dictionary.close();

  final db = await databaseFactoryFfi.openDatabase(
    p.join(dir.path, 'progress.db'),
  );
  // Mirrors AppDatabase.onConfigure. Without it ON DELETE CASCADE is inert and
  // deleting a session would leave its items behind.
  await db.execute('PRAGMA foreign_keys = ON');
  for (final statement in progressSchema) {
    await db.execute(statement);
  }
  await db.execute('ATTACH DATABASE ? AS $dictionaryAlias', [dictionaryPath]);
  return db;
}

