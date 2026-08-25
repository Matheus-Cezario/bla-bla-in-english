import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A row id derived from [key] rather than from insertion order.
///
/// The user's progress is stored against `word_id` and `sentence_id` in a
/// separate database that survives a dictionary swap. With autoincrement ids,
/// regenerating the dictionary — adding words, pruning junk, fixing a typo —
/// renumbers everything, and every existing install silently re-points its
/// history at different words: "you got *bank* wrong" becomes "you got *and*
/// wrong". Deriving the id from the word itself keeps progress attached to the
/// word it was earned on.
///
/// It also lets the app and the generator agree without talking: a word created
/// on the phone gets the same id it would have been given by a full rebuild, so
/// when that word later ships in the real dictionary the progress already
/// earned on it carries straight over.
///
/// 63 bits, so the value is always a positive SQLite INTEGER. For a dictionary
/// of this size the collision probability is around 1 in 20 billion, and both
/// writers fail loudly if one ever happens.
int stableId(String key) {
  final digest = sha256.convert(utf8.encode(key)).bytes;
  var value = 0;
  for (var i = 0; i < 8; i++) {
    value = (value << 8) | digest[i];
  }
  return value & 0x7FFFFFFFFFFFFFFF;
}

/// The id of the sentence at [position] (1-based) of [word].
int sentenceIdFor(String word, int position) => stableId('$word:$position');

/// The id of the option of [kind] on that sentence.
int optionIdFor(String word, int position, int kind) =>
    stableId('$word:$position:$kind');
