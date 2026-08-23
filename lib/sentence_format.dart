/// The marker wrapping the target word inside a practice sentence, e.g.
/// `The #book# is on the table.`
///
/// Deliberately free of Flutter imports: the dictionary generator in `tool/`
/// runs as a plain Dart CLI and needs this constant, and importing
/// `package:flutter` from a CLI breaks compilation.
const String sentenceDivider = '#';
