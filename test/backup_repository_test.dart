import 'dart:io';

import 'package:bla_bla_in_english/data/schema.dart';
import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:bla_bla_in_english/repositories/backup_repository.dart';
import 'package:bla_bla_in_english/repositories/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_database.dart';

void main() {
  sqfliteFfiInit();

  late Directory dir;
  late Database db;
  late SessionRepository sessions;
  late BackupRepository backups;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('blabla_backup_test');
    db = await openTestDatabase(dir, words: 50);
    // The progress database carries its schema version, and a restore checks
    // it — the test fixture has to stamp it the way sqflite does at runtime.
    await db.setVersion(progressSchemaVersion);
    sessions = SessionRepository(db);
    backups = BackupRepository(db);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  /// Answers a few words so there is something worth losing.
  Future<void> practise({AnswerKind kind = AnswerKind.wrong}) async {
    final items = await sessions.todaySession(wordsPerDay: 5);
    for (final item in items.take(3)) {
      await sessions.recordAnswer(item: item, kind: kind);
    }
  }

  test('a backup round-trips the whole history', () async {
    await practise();
    final before = await db.query('answers');
    final progressBefore = await db.query('word_progress');
    final file = await backups.export();

    // Wipe everything, the way a reinstall would.
    await db.delete('session_items');
    await db.delete('sessions');
    await db.delete('answers');
    await db.delete('word_progress');
    expect(await db.query('answers'), isEmpty);

    final summary = await backups.restore(await file.readAsBytes());

    expect(summary.answers, before.length);
    expect(summary.words, progressBefore.length);
    expect(await db.query('answers'), before);
    expect(await db.query('word_progress'), progressBefore);
  });

  test('restoring replaces what is there instead of merging into it', () async {
    await practise();
    final file = await backups.export();

    // Carry on practising after the backup was taken.
    await db.delete('sessions');
    await practise(kind: AnswerKind.correct);
    expect((await db.query('answers')).length, greaterThan(3));

    await backups.restore(await file.readAsBytes());

    final answers = await db.query('answers');
    expect(answers, hasLength(3), reason: 'the later answers are gone');
    expect(
      answers.every((row) => row['kind'] == AnswerKind.wrong.id),
      isTrue,
    );
  });

  test('the daily target travels with the backup', () async {
    await db.insert('settings', {'key': 'words_per_day', 'value': '35'});
    final file = await backups.export();

    await db.update('settings', {'value': '5'}, where: 'key = ?',
        whereArgs: ['words_per_day']);
    await backups.restore(await file.readAsBytes());

    final rows = await db.query('settings', where: 'key = ?',
        whereArgs: ['words_per_day']);
    expect(rows.single['value'], '35');
  });

  test('the session that was open when the backup was taken comes back',
      () async {
    await practise();
    final file = await backups.export();
    await db.delete('sessions');

    await backups.restore(await file.readAsBytes());

    final items = await sessions.todaySession(wordsPerDay: 5);
    expect(items, hasLength(5));
    expect(items.take(3).every((item) => item.isAnswered), isTrue,
        reason: 'the three answered items are still answered');
  });

  test('a file that is not a database is refused before anything is deleted',
      () async {
    await practise();
    final junk = File(p.join(dir.path, 'notes.txt'));
    await junk.writeAsString('isso aqui não é um banco de dados');

    await expectLater(
      backups.restore(await junk.readAsBytes()),
      throwsA(isA<BackupFormatException>()),
    );
    expect(await db.query('answers'), hasLength(3),
        reason: 'a rejected restore must not touch the current progress');
  });

  test('the dictionary is not mistaken for a backup', () async {
    await practise();
    final dictionary = File(p.join(dir.path, 'dictionary.db'));

    await expectLater(
      backups.restore(await dictionary.readAsBytes()),
      throwsA(isA<BackupFormatException>()),
    );
    expect(await db.query('answers'), hasLength(3));
  });

  test('a backup from a newer schema is refused with a readable reason',
      () async {
    final file = await backups.export();
    final future = await databaseFactoryFfi.openDatabase(file.path);
    await future.setVersion(progressSchemaVersion + 1);
    await future.close();

    await expectLater(
      backups.restore(await file.readAsBytes()),
      throwsA(
        isA<BackupFormatException>().having(
          (e) => e.message,
          'message',
          contains('versão'),
        ),
      ),
    );
  });

  test('a failed restore leaves the connection usable', () async {
    await practise();
    try {
      await backups.restore(await File(p.join(dir.path, 'dictionary.db'))
          .readAsBytes());
    } on BackupFormatException {
      // expected
    }

    // The staging file is gone and nothing is left attached, so the next
    // restore is not blocked by the last one's wreckage.
    expect(File(p.join(p.dirname(db.path), 'restore-staging.db')).existsSync(),
        isFalse);
    final file = await backups.export();
    await backups.restore(await file.readAsBytes());
    expect(await db.query('answers'), hasLength(3));
  });

  test('the export is named by the day it was taken', () {
    expect(
      BackupRepository.fileNameFor(DateTime(2026, 8, 4)),
      'bla-bla-progresso-2026-08-04.db',
    );
  });

  test('only the latest export is kept around', () async {
    await practise();
    final first = await backups.export(at: DateTime(2026, 1, 1));
    final second = await backups.export(at: DateTime(2026, 2, 2));

    expect(first.existsSync(), isFalse, reason: 'replaced, not piled up');
    expect(second.existsSync(), isTrue);
  });
}
