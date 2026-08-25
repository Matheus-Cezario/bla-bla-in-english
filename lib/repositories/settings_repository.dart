import 'package:sqflite/sqflite.dart';

/// User preferences, stored as a key/value table so adding a setting never
/// needs a schema migration.
class SettingsRepository {
  const SettingsRepository(this._db);

  final Database _db;

  static const String _wordsPerDayKey = 'words_per_day';

  /// Where the user's DeepSeek key is kept.
  ///
  /// Public because the backup has to know to strip this row before handing the
  /// file to a share sheet — a backup the user mails to themselves must not
  /// carry a live API key.
  static const String deepSeekApiKeyKey = 'deepseek_api_key';

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

  /// The user's DeepSeek key, or null when they have not set one. Without it
  /// the app never contacts DeepSeek at all.
  Future<String?> deepSeekApiKey() async {
    final rows = await _db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [deepSeekApiKeyKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = (rows.first['value']! as String).trim();
    return value.isEmpty ? null : value;
  }

  /// Stores the key, or clears it when [value] is blank.
  Future<void> setDeepSeekApiKey(String? value) async {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      await _db.delete('settings',
          where: 'key = ?', whereArgs: [deepSeekApiKeyKey]);
      return;
    }
    await _db.insert(
      'settings',
      {'key': deepSeekApiKeyKey, 'value': trimmed},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
