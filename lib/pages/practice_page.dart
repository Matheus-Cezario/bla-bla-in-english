import 'package:bla_bla_in_english/components/option_tile.dart';
import 'package:bla_bla_in_english/components/sentence_text.dart';
import 'package:bla_bla_in_english/constants.dart';
import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:bla_bla_in_english/pages/settings_page.dart';
import 'package:bla_bla_in_english/pages/stats_page.dart';
import 'package:bla_bla_in_english/pages/word_search_page.dart';
import 'package:bla_bla_in_english/providers/session_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The app's home: today's session, one sentence at a time.
class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  @override
  void initState() {
    super.initState();
    // The provider talks to SQLite, so the first load cannot happen during
    // build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionProvider>().load();
    });
  }

  Future<void> _openWordSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WordSearchPage()),
    );
  }

  void _openStats() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const StatsPage()),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
    if (mounted) await context.read<SessionProvider>().refreshSettings();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    return Scaffold(
      appBar: AppBar(
        // Three actions leave a narrow phone short of room for the full
        // title, and a clipped name looks broken; scaling down does not.
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Blá Blá in English'),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _openWordSearch,
            icon: const Icon(Icons.search),
            tooltip: 'Buscar palavras',
          ),
          IconButton(
            onPressed: _openStats,
            icon: const Icon(Icons.insights),
            tooltip: 'Estatísticas',
          ),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
          ),
        ],
      ),
      body: SafeArea(child: _body(session)),
    );
  }

  Widget _body(SessionProvider session) => switch (session.state) {
        SessionState.loading =>
          const Center(child: CircularProgressIndicator()),
        SessionState.failed => _Message(
            title: 'Não deu para carregar o dicionário',
            detail: '${session.error}',
          ),
        SessionState.empty => const _Message(
            title: 'Nenhuma palavra disponível',
            detail: 'O dicionário está vazio. Gere o banco com '
                'tool/generate_dictionary.dart e reinstale o app.',
          ),
        SessionState.ready => session.current == null
            ? _Summary(session: session)
            : _Question(session: session),
      };
}

class _Question extends StatelessWidget {
  const _Question({required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    final item = session.current!;

    return Column(
      children: [
        _ProgressBar(session: session),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              children: [
                SentenceText(item: item),
                const SizedBox(height: 36),
                Text(
                  'O que significa "${item.word}" aqui?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                for (final option in item.options)
                  OptionTile(
                    option: option,
                    chosenKind: item.answeredKind,
                    onTap: () => session.answer(option.kind),
                  ),
              ],
            ),
          ),
        ),
        if (item.isAnswered)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: session.advance,
                child: Text(
                  session.answeredCount == session.total
                      ? 'Ver resultado'
                      : 'Próxima',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${session.currentNumber} de ${session.total}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: session.total == 0
                  ? 0
                  : session.answeredCount / session.total,
              minHeight: 8,
              backgroundColor: optionColor,
              valueColor: const AlwaysStoppedAnimation(primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.session});

  final SessionProvider session;

  /// Queues another day's worth of words. The dictionary can be out of words
  /// the user has not already seen today, and silently doing nothing would read
  /// as a broken button — so say it.
  Future<void> _extend(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await session.extendSession() > 0) return;

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Não há mais palavras novas para hoje. '
            'Use a busca para escolher uma palavra específica.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sessão de hoje concluída!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            _Tally(
              color: correctAnswerColor,
              label: 'Acertou',
              count: session.countOf(AnswerKind.correct),
            ),
            _Tally(
              color: nearAnswerColor,
              label: 'Quase',
              count: session.countOf(AnswerKind.near),
            ),
            _Tally(
              color: wrongAnswerColor,
              label: 'Errou',
              count: session.countOf(AnswerKind.wrong),
            ),
            const SizedBox(height: 28),
            Text(
              'As palavras que você errou voltam primeiro amanhã.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _extend(context),
              child: const Text('Praticar mais agora'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({
    required this.color,
    required this.label,
    required this.count,
  });

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 90, child: Text(label)),
          Text('$count', style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(detail, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
