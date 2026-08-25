import 'package:bla_bla_in_english/data/schema.dart';
import 'package:bla_bla_in_english/data/stable_id.dart';
import 'package:bla_bla_in_english/services/deepseek_client.dart';
import 'package:bla_bla_in_english/services/dictionary_content.dart';
import 'package:sqflite/sqflite.dart';

/// Why a word could not be created, phrased for the person who asked for it.
class WordCreationException implements Exception {
  const WordCreationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Creates a dictionary word on the phone, using the user's own DeepSeek key.
///
/// The shipped dictionary is a fixed list; this is the escape hatch for the
/// word someone ran into today that is not in it. The prompt, the parsing and
/// the validation are the generator's own — [systemPrompt] and [WordEntry] are
/// shared code, not a second implementation — so a word created here is
/// indistinguishable from one that shipped.
class CustomWordRepository {
  CustomWordRepository(this._db, {DeepSeekClientFactory? client})
      : _client = client ?? _defaultClient;

  final Database _db;
  final DeepSeekClientFactory _client;

  static DeepSeekClient _defaultClient(String apiKey) =>
      DeepSeekClient(apiKey: apiKey);

  /// Anything longer is a phrase, not a word, and the exercise format cannot
  /// carry it.
  static const int maxWordLength = 40;

  /// Letters, plus the hyphen and apostrophe English words actually use.
  static final RegExp _shape = RegExp(r"^[a-zA-Z][a-zA-Z'-]*$");

  /// Returns the reason [word] cannot be asked for, or null when it can.
  ///
  /// Checked before spending a request: the model will happily write five
  /// sentences for "asdfgh" and the user pays for them.
  static String? rejectionReason(String word) {
    final term = word.trim();
    if (term.isEmpty) return 'Digite uma palavra.';
    if (term.length > maxWordLength) {
      return 'Isso é longo demais para uma palavra.';
    }
    if (term.contains(RegExp(r'\s'))) {
      return 'Peça uma palavra de cada vez, sem espaços.';
    }
    if (!_shape.hasMatch(term)) {
      return 'Use só letras — é um dicionário de inglês.';
    }
    return null;
  }

  /// Asks DeepSeek for [word] and writes it into the dictionary.
  ///
  /// Returns the word as it was stored. Throws [WordCreationException] with a
  /// message meant to be shown as-is.
  Future<String> create(String word, {required String apiKey}) async {
    final term = word.trim().toLowerCase();

    final rejection = rejectionReason(term);
    if (rejection != null) throw WordCreationException(rejection);

    if (await _exists(term)) {
      throw WordCreationException('"$term" já está no dicionário.');
    }

    final entry = await _generate(term, apiKey: apiKey);
    await _store(entry);
    return term;
  }

  /// Puts back every word the user created that the installed dictionary does
  /// not carry, and reports how many that was.
  ///
  /// The dictionary is content, replaced wholesale whenever a newer one ships.
  /// Without this, every dictionary update would silently delete the words the
  /// user asked DeepSeek for — and leave their progress rows pointing at words
  /// that no longer exist, which shows up as a session that quietly skips them.
  ///
  /// The count comes first because the answer is "nothing to do" on almost
  /// every launch. INSERT OR IGNORE covers the rest: a word that has since
  /// shipped for real is already there, under the very same id.
  Future<int> replayIntoDictionary() async {
    final missing = Sqflite.firstIntValue(await _db.rawQuery('''
      SELECT COUNT(*) FROM custom_words cw
      WHERE NOT EXISTS (
        SELECT 1 FROM $dictionaryAlias.words w WHERE w.id = cw.id
      )
    '''));
    if (missing == null || missing == 0) return 0;

    await _db.transaction((txn) async {
      // Words before sentences before options: each references the one above.
      await txn.execute('''
        INSERT OR IGNORE INTO $dictionaryAlias.words (id, word, frequency_rank)
        SELECT id, word, frequency_rank FROM custom_words
      ''');
      await txn.execute('''
        INSERT OR IGNORE INTO $dictionaryAlias.sentences
          (id, word_id, position, text)
        SELECT id, word_id, position, text FROM custom_sentences
      ''');
      await txn.execute('''
        INSERT OR IGNORE INTO $dictionaryAlias.options
          (id, sentence_id, text, kind)
        SELECT id, sentence_id, text, kind FROM custom_options
      ''');
    });
    return missing;
  }

  Future<bool> _exists(String term) async {
    final rows = await _db.rawQuery(
      'SELECT 1 FROM $dictionaryAlias.words WHERE word = ? LIMIT 1',
      [term],
    );
    return rows.isNotEmpty;
  }

  Future<WordEntry> _generate(String term, {required String apiKey}) async {
    final client = _client(apiKey);
    try {
      final json = await client.completeJson(
        system: systemPrompt,
        prompt: userPromptFor([term]),
        // One word is five sentences with three options each — the generator's
        // measured average, with room to spare.
        maxTokens: 1600,
      );

      final outcome = BatchOutcome.parse(
        json,
        requestedRanks: {term: await _nextFrequencyRank()},
      );
      if (outcome.entries.isEmpty) {
        // The generator retries these across a long run; here there is a person
        // waiting, so report it and let them decide to try again.
        throw WordCreationException(
          'O DeepSeek respondeu algo que não dá para usar '
          '(${outcome.failures[term] ?? 'sem detalhes'}). Tente de novo.',
        );
      }
      return outcome.entries.single;
    } on DeepSeekException catch (error) {
      throw WordCreationException(_explain(error));
    } finally {
      client.close();
    }
  }

  /// Turns a transport failure into something worth reading. The status code is
  /// the only part of a DeepSeek error that reliably means anything.
  static String _explain(DeepSeekException error) => switch (error.statusCode) {
        401 || 403 => 'Sua chave do DeepSeek foi recusada. '
            'Confira em Configurações.',
        402 => 'A conta do DeepSeek está sem saldo.',
        429 => 'O DeepSeek está limitando as requisições. Tente daqui a pouco.',
        _ => 'Não deu para falar com o DeepSeek agora. Tente de novo.',
      };

  /// New words go to the end of the frequency list: the rank only orders which
  /// unseen word the daily plan introduces next, and a word nobody has met has
  /// no claim to jump the queue. The user adds it to today's session by hand
  /// anyway — that is why they came to this screen.
  Future<int> _nextFrequencyRank() async {
    final rank = Sqflite.firstIntValue(
      await _db.rawQuery(
        'SELECT MAX(frequency_rank) FROM $dictionaryAlias.words',
      ),
    );
    return (rank ?? 0) + 1;
  }

  /// Writes the word to the dictionary and to the copy that outlives it.
  ///
  /// Both in one transaction: a word in the dictionary but not in `custom_*`
  /// disappears at the next dictionary update, and one in `custom_*` but not in
  /// the dictionary is invisible until the next launch replays it.
  Future<void> _store(WordEntry entry) async {
    final wordId = stableId(entry.word);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Written as raw statements rather than through `batch.insert`, which does
    // not take a schema-qualified table name — the dictionary lives in an
    // attached schema, so every one of these needs the `dict.` prefix intact.
    await _db.transaction((txn) async {
      final batch = txn.batch();

      void pair(String sql, String customTable, String dictTable,
          List<Object?> arguments) {
        batch.rawInsert(sql.replaceFirst('%t', customTable), arguments);
        batch.rawInsert(sql.replaceFirst('%t', dictTable), arguments);
      }

      batch.rawInsert(
        'INSERT OR REPLACE INTO custom_words '
        '(id, word, frequency_rank, created_at) VALUES (?, ?, ?, ?)',
        [wordId, entry.word, entry.frequencyRank, now],
      );
      batch.rawInsert(
        'INSERT OR REPLACE INTO $dictionaryAlias.words '
        '(id, word, frequency_rank) VALUES (?, ?, ?)',
        [wordId, entry.word, entry.frequencyRank],
      );

      for (final (index, sentence) in entry.sentences.indexed) {
        final position = index + 1;
        final sentenceId = sentenceIdFor(entry.word, position);

        pair(
          'INSERT OR REPLACE INTO %t (id, word_id, position, text) '
          'VALUES (?, ?, ?, ?)',
          'custom_sentences',
          '$dictionaryAlias.sentences',
          [sentenceId, wordId, position, sentence.text],
        );

        for (final (kind, text) in [
          (0, sentence.correct),
          (1, sentence.near),
          (2, sentence.wrong),
        ]) {
          pair(
            'INSERT OR REPLACE INTO %t (id, sentence_id, text, kind) '
            'VALUES (?, ?, ?, ?)',
            'custom_options',
            '$dictionaryAlias.options',
            [optionIdFor(entry.word, position, kind), sentenceId, text, kind],
          );
        }
      }

      await batch.commit(noResult: true);
    });
  }
}

/// Lets a test hand in a client that never leaves the process.
typedef DeepSeekClientFactory = DeepSeekClient Function(String apiKey);
