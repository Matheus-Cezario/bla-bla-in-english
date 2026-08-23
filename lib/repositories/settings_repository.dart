import 'package:sqflite/sqflite.dart';

/// User preferences, stored as a key/value table so adding a setting never
/// needs a schema migration.
class SettingsRepository {
  const SettingsRepository(this._db);

  final Database _db;

  static const String _wordsPerDayKey = 'words_per_day';

  /// Default daily load for a new install.
  static const int defaultWordsPerDay = 20;

  /// The range the settings screen offers.
  static const int minWordsPerDay = 5;
  static const int maxWordsPerDay = 100;

  Future<int> wordsPerDay() async {
    final rows = await _db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_wordsPerDayKey],
      limit: 1,
    );
    if (rows.isEmpty) return defaultWordsPerDay;
    return int.tryParse(rows.first['value']! as String) ?? defaultWordsPerDay;
  }

  Future<void> setWordsPerDay(int value) async {
    final clamped = value.clamp(minWordsPerDay, maxWordsPerDay);
    await _db.insert(
      'settings',
      {'key': _wordsPerDayKey, 'value': '$clamped'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
