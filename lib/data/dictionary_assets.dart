/// Asset paths for the generated dictionary.
///
/// Kept free of Flutter imports so the generator in `tool/` — a plain Dart CLI
/// — can write to exactly the paths the app reads from.
library;

/// The generated dictionary database.
const String dictionaryAssetPath = 'assets/db/dictionary.db';

/// A sha256 of [dictionaryAssetPath], written by the generator.
///
/// The app compares this against the stamp saved beside the installed copy to
/// decide whether to re-copy after an app update.
const String dictionaryVersionPath = 'assets/db/dictionary.version';
