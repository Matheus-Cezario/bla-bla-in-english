import 'dart:async';

import 'package:bla_bla_in_english/constants.dart';
import 'package:bla_bla_in_english/models/word_search_result.dart';
import 'package:bla_bla_in_english/models/word_status.dart';
import 'package:bla_bla_in_english/providers/session_provider.dart';
import 'package:bla_bla_in_english/repositories/session_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Browses the dictionary and drops the chosen words into today's session.
///
/// The point is control: the daily plan plays the odds, this screen is how the
/// user practises the word they ran into an hour ago. It opens on the whole
/// dictionary, most common first, so there is something to pick even when they
/// do not have a particular word in mind.
class WordSearchPage extends StatefulWidget {
  const WordSearchPage({super.key});

  @override
  State<WordSearchPage> createState() => _WordSearchPageState();
}

class _WordSearchPageState extends State<WordSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// Selected words, keyed by id so the choice survives a new search, and
  /// ordered so the session queues them the way they were picked.
  final Map<int, String> _selected = <int, String>{};

  List<WordSearchResult> _results = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _adding = false;

  /// False once a page comes back short, which is how the end of the list
  /// announces itself.
  bool _hasMore = true;

  Timer? _debounce;

  /// Guards against a slow query overwriting the results of a later one.
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _search(_controller.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    // Repaints the clear button straight away; the search itself waits.
    setState(() {});
    _debounce?.cancel();
    // Long enough to skip the keystrokes in the middle of a word, short enough
    // that the list still feels attached to the keyboard.
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(value));
  }

  void _onScroll() {
    if (_loading || _loadingMore || !_hasMore) return;
    // Fetch before the user actually reaches the bottom, so the next page is
    // usually already there by the time they get to it.
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  /// Loads the first page for [query], replacing whatever is on screen.
  Future<void> _search(String query) async {
    final token = ++_searchToken;
    if (_scroll.hasClients) _scroll.jumpTo(0);

    setState(() {
      _loading = true;
      // A page still in flight belongs to the previous query; forgetting to
      // clear this would leave the list unable to grow ever again.
      _loadingMore = false;
      _hasMore = true;
    });

    final results = await context.read<SessionRepository>().searchWords(query);
    if (!mounted || token != _searchToken) return;

    setState(() {
      _results = results;
      _loading = false;
      _hasMore = results.length == SessionRepository.searchPageSize;
    });
  }

  Future<void> _loadMore() async {
    final token = _searchToken;
    setState(() => _loadingMore = true);

    final next = await context.read<SessionRepository>().searchWords(
          _controller.text,
          offset: _results.length,
        );
    if (!mounted || token != _searchToken) return;

    setState(() {
      _results = [..._results, ...next];
      _loadingMore = false;
      _hasMore = next.length == SessionRepository.searchPageSize;
    });
  }

  void _toggle(WordSearchResult result) {
    setState(() {
      if (_selected.containsKey(result.wordId)) {
        _selected.remove(result.wordId);
      } else {
        _selected[result.wordId] = result.word;
      }
    });
  }

  Future<void> _addSelected() async {
    if (_selected.isEmpty || _adding) return;

    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final added =
        await context.read<SessionProvider>().addWords(_selected.keys.toList());

    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          added == 0
              ? 'Essas palavras já estavam na sessão de hoje.'
              : added == 1
                  ? '1 palavra adicionada à sessão de hoje.'
                  : '$added palavras adicionadas à sessão de hoje.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searching = _controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar palavras'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: _search,
                decoration: InputDecoration(
                  hintText: 'Buscar palavra',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Limpar',
                          onPressed: () {
                            _controller.clear();
                            _search('');
                          },
                        ),
                  filled: true,
                  fillColor: optionColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: optionBorderColor),
                  ),
                ),
              ),
            ),
            if (!searching && !_loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Todo o dicionário, do mais comum ao mais raro.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 13),
                  ),
                ),
              ),
            Expanded(child: _resultsView(context)),
            _SelectionBar(
              selected: _selected,
              busy: _adding,
              onRemove: (id) => setState(() => _selected.remove(id)),
              onConfirm: _addSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultsView(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_results.isEmpty) {
      return const _Hint(text: 'Nenhuma palavra encontrada no dicionário.');
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // One extra row while more pages are coming, which is both the spinner
      // and the thing the scroll listener is reaching for.
      itemCount: _results.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == _results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final result = _results[index];
        return _ResultTile(
          result: result,
          selected: _selected.containsKey(result.wordId),
          onTap: result.inTodaySession ? null : () => _toggle(result),
        );
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.result,
    required this.selected,
    required this.onTap,
  });

  final WordSearchResult result;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: _statusColor(result.status),
          shape: BoxShape.circle,
          border: Border.all(color: optionBorderColor),
        ),
      ),
      title: Text(result.word, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: Text(
        _statusLabel(result.status),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
      ),
      trailing: result.inTodaySession
          ? Text(
              'já na sessão',
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
            )
          : Checkbox(
              value: selected,
              activeColor: primaryColor,
              checkColor: Colors.black,
              onChanged: (_) => onTap?.call(),
            ),
    );
  }
}

/// The chosen words plus the button that queues them, pinned under the list so
/// a long selection never scrolls the action off screen.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selected,
    required this.busy,
    required this.onRemove,
    required this.onConfirm,
  });

  final Map<int, String> selected;
  final bool busy;
  final void Function(int wordId) onRemove;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: optionBorderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selected.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final entry in selected.entries)
                  Chip(
                    label: Text(entry.value),
                    // Chips read their label style from `labelLarge`, which the
                    // app theme leaves at the Material default — without this
                    // the chips are the one place not set in Poppins.
                    labelStyle: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 14),
                    backgroundColor: optionColor,
                    side: const BorderSide(color: optionBorderColor),
                    onDeleted: busy ? null : () => onRemove(entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: selected.isEmpty || busy ? null : onConfirm,
            child: Text(
              selected.isEmpty
                  ? 'Adicionar à sessão de hoje'
                  : 'Adicionar ${selected.length} à sessão de hoje',
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

String _statusLabel(WordStatus status) => switch (status) {
      WordStatus.wrong => 'Você errou da última vez',
      WordStatus.near => 'Você quase acertou',
      WordStatus.fresh => 'Nunca praticada',
      WordStatus.learned => 'Você acertou da última vez',
    };

Color _statusColor(WordStatus status) => switch (status) {
      WordStatus.wrong => wrongAnswerColor,
      WordStatus.near => nearAnswerColor,
      WordStatus.fresh => optionColor,
      WordStatus.learned => correctAnswerColor,
    };
