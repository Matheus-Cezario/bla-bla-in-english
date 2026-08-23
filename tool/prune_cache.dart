/// Removes cache entries whose word is not in the vocabulary list.
///
///   dart run tool/prune_cache.dart --words tool/words_vocabulary.txt
///   dart run tool/prune_cache.dart --words tool/words_vocabulary.txt --apply
///
/// Without `--apply` it only reports, because this deletes generated content
/// that cost money to produce. The original file is copied to `<cache>.bak`
/// before anything is written.
///
/// Filtering the word list only changes what is still to be generated; entries
/// already in the cache for words the filter would now reject are still there,
/// and would still become dictionary entries the learner gets drilled on.
library;

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final cachePath = _flag(args, 'cache') ?? 'tool/.dictionary_cache.jsonl';
  final wordsPath = _flag(args, 'words') ?? 'tool/words_vocabulary.txt';
  final apply = args.contains('--apply');

  final keep = _readWords(wordsPath);
  final cache = File(cachePath);
  if (!cache.existsSync()) {
    stderr.writeln('Cache not found: $cachePath');
    exit(66);
  }

  final lines = cache.readAsLinesSync();
  final kept = <String>[];
  final dropped = <String>[];

  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    String? word;
    try {
      word = (jsonDecode(line) as Map<String, Object?>)['word'] as String?;
    } catch (_) {
      // Unreadable lines are dropped either way; the generator skips them too.
    }
    if (word != null && keep.contains(word)) {
      kept.add(line);
    } else {
      dropped.add(word ?? '<unreadable line>');
    }
  }

  stdout.writeln('Cache : $cachePath  (${lines.length} lines)');
  stdout.writeln('Words : $wordsPath  (${keep.length} words)');
  stdout.writeln('Keep  : ${kept.length}');
  stdout.writeln('Drop  : ${dropped.length}');
  if (dropped.isNotEmpty) {
    stdout.writeln('  ${dropped.take(25).join(', ')}'
        '${dropped.length > 25 ? ', ...' : ''}');
  }

  if (!apply) {
    stdout.writeln('\nNothing written. Re-run with --apply to prune.');
    return;
  }
  if (dropped.isEmpty) return;

  cache.copySync('$cachePath.bak');
  cache.writeAsStringSync('${kept.join('\n')}\n');
  stdout.writeln('\nPruned. Backup at $cachePath.bak');
}

Set<String> _readWords(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Word list not found: $path');
    exit(66);
  }
  return {
    for (final line in const LineSplitter().convert(file.readAsStringSync()))
      if (line.trim().isNotEmpty && !line.startsWith('#')) line.trim(),
  };
}

String? _flag(List<String> args, String name) {
  final index = args.indexOf('--$name');
  return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
}
