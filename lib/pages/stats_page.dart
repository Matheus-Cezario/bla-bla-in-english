import 'package:bla_bla_in_english/constants.dart';
import 'package:bla_bla_in_english/models/answer_kind.dart';
import 'package:bla_bla_in_english/models/practice_stats.dart';
import 'package:bla_bla_in_english/models/word_status.dart';
import 'package:bla_bla_in_english/repositories/stats_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// How the user is doing, over the whole history rather than today.
///
/// Every coloured mark on this screen carries its own written label and count.
/// The app's palette is four pastels that sit close together — fine as a status
/// signal next to text, not enough on its own to tell four slices apart — so
/// nothing here is encoded by colour alone.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  PracticeStats? _stats;
  Object? _error;

  @override
  void initState() {
    super.initState();
    context.read<StatsRepository>().load().then((stats) {
      if (mounted) setState(() => _stats = stats);
    }).catchError((Object error) {
      if (mounted) setState(() => _error = error);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas'), centerTitle: true),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final error = _error;
    if (error != null) return _Hint(text: 'Não deu para ler seus dados.\n$error');

    final stats = _stats;
    if (stats == null) return const Center(child: CircularProgressIndicator());

    return StatsView(stats: stats);
  }
}

/// The screen's contents, split from the loading so it can be looked at — by a
/// test or by a person — without a database behind it.
class StatsView extends StatelessWidget {
  const StatsView({super.key, required this.stats});

  final PracticeStats stats;

  @override
  Widget build(BuildContext context) {
    if (!stats.hasHistory) {
      return const _Hint(
        text: 'Responda algumas palavras e volte aqui: é onde você vê o que '
            'já aprendeu e há quantos dias está firme.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        _StreakHero(stats: stats),
        const SizedBox(height: 28),
        _HeadlineRow(stats: stats),
        const SizedBox(height: 32),
        _Panel(
          title: 'Últimos ${StatsRepository.recentDayCount} dias',
          child: _ActivityChart(days: stats.recentDays),
        ),
        _Panel(
          title: 'Onde estão suas palavras',
          child: _VocabularyBreakdown(stats: stats),
        ),
        _Panel(
          title: 'Todas as suas respostas',
          child: _AnswerBreakdown(stats: stats),
        ),
      ],
    );
  }
}

/// The number the user opens this screen for.
class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.stats});

  final PracticeStats stats;

  @override
  Widget build(BuildContext context) {
    final streak = stats.currentStreak;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: optionBorderColor),
      ),
      child: Column(
        children: [
          Text(
            '$streak',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontSize: 52, fontWeight: FontWeight.bold),
          ),
          Text(
            streak == 1 ? 'dia seguido' : 'dias seguidos',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            streak == 0
                ? 'Responda uma palavra hoje para começar de novo.'
                : 'Sua melhor sequência: ${stats.bestStreak} '
                    '${stats.bestStreak == 1 ? 'dia' : 'dias'}.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Three plain numbers. They are single values, so they stay numbers instead of
/// becoming three tiny charts that say less.
class _HeadlineRow extends StatelessWidget {
  const _HeadlineRow({required this.stats});

  final PracticeStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StatTile(
            value: _formatNumber(stats.totalAnswers),
            label: 'respostas',
          ),
        ),
        Expanded(
          child: _StatTile(
            value: '${(stats.accuracy * 100).round()}%',
            label: 'de acerto',
          ),
        ),
        Expanded(
          child: _StatTile(
            value: _formatNumber(stats.daysPractised),
            label: stats.daysPractised == 1 ? 'dia praticado' : 'dias praticados',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
        ),
      ],
    );
  }
}

/// Answers per day. One series, so it needs no legend — the title names it —
/// and only today is labelled, rather than a number over every bar.
class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.days});

  final List<DailyCount> days;

  static const double _height = 120;

  @override
  Widget build(BuildContext context) {
    final busiest = days.fold(0, (top, day) => day.count > top ? day.count : top);
    final today = days.isEmpty ? null : days.last;
    final smallStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13);

    return Semantics(
      label: 'Respostas por dia nos últimos ${days.length} dias. '
          'Melhor dia: $busiest respostas.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            today == null || today.count == 0
                ? 'Nada respondido hoje ainda.'
                : '${_formatNumber(today.count)} '
                    '${today.count == 1 ? 'resposta' : 'respostas'} hoje.',
            style: smallStyle,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (index, day) in days.indexed) ...[
                  if (index > 0) const SizedBox(width: 2),
                  Expanded(
                    child: _Bar(
                      count: day.count,
                      busiest: busiest,
                      isToday: index == days.length - 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // The baseline is the only rule on the chart: with fourteen bars,
          // gridlines would out-ink the data.
          Container(height: 1, color: optionBorderColor),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(days.isEmpty ? '' : _formatDay(days.first.day),
                  style: smallStyle),
              Text('hoje', style: smallStyle),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.count,
    required this.busiest,
    required this.isToday,
  });

  final int count;
  final int busiest;
  final bool isToday;

  /// A quiet day still gets a visible stub: an empty column would read as
  /// missing data rather than as a day with nothing on it.
  static const double _stub = 3;

  @override
  Widget build(BuildContext context) {
    final full = busiest == 0
        ? _stub
        : (count / busiest) * _ActivityChart._height;
    final height = count == 0 ? _stub : full.clamp(6.0, _ActivityChart._height);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: count == 0 ? optionColor : primaryColor,
        // Rounded at the data end only — the other end is the baseline.
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        border: Border.all(
          color: isToday && count > 0 ? Colors.black87 : optionBorderColor,
          width: isToday && count > 0 ? 2 : 1,
        ),
      ),
    );
  }
}

/// How far through the dictionary the user is, then how the words they have met
/// are actually going.
class _VocabularyBreakdown extends StatelessWidget {
  const _VocabularyBreakdown({required this.stats});

  final PracticeStats stats;

  @override
  Widget build(BuildContext context) {
    final practised = stats.practisedWords;
    final smallStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13);

    final segments = [
      _Segment(
        color: correctAnswerColor,
        label: 'Você acertou por último',
        value: stats.countOfStatus(WordStatus.learned),
      ),
      _Segment(
        color: nearAnswerColor,
        label: 'Ficou no quase',
        value: stats.countOfStatus(WordStatus.near),
      ),
      _Segment(
        color: wrongAnswerColor,
        label: 'Você errou por último',
        value: stats.countOfStatus(WordStatus.wrong),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_formatNumber(practised)} de '
          '${_formatNumber(stats.dictionaryWords)} palavras do dicionário.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: stats.dictionaryWords == 0
                ? 0
                : practised / stats.dictionaryWords,
            minHeight: 10,
            backgroundColor: optionColor,
            valueColor: const AlwaysStoppedAnimation(primaryColor),
          ),
        ),
        const SizedBox(height: 20),
        Text('Das que você já praticou:', style: smallStyle),
        const SizedBox(height: 10),
        // Deliberately over the practised words, not the whole dictionary:
        // against five thousand untouched words the three real slices would be
        // a hairline apiece.
        _SegmentedBar(segments: segments, total: practised),
        const SizedBox(height: 14),
        for (final segment in segments)
          _LegendRow(segment: segment, total: practised),
      ],
    );
  }
}

/// The answer history, which is a different question from where the words stand
/// now: this one never forgets a wrong answer the user later fixed.
class _AnswerBreakdown extends StatelessWidget {
  const _AnswerBreakdown({required this.stats});

  final PracticeStats stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.totalAnswers;

    return Column(
      children: [
        for (final segment in [
          _Segment(
            color: correctAnswerColor,
            label: 'Acertou',
            value: stats.countOfKind(AnswerKind.correct),
          ),
          _Segment(
            color: nearAnswerColor,
            label: 'Quase',
            value: stats.countOfKind(AnswerKind.near),
          ),
          _Segment(
            color: wrongAnswerColor,
            label: 'Errou',
            value: stats.countOfKind(AnswerKind.wrong),
          ),
        ])
          _ProportionRow(segment: segment, total: total),
      ],
    );
  }
}

/// One slice of a breakdown: a colour that only ever appears next to its own
/// label and count.
class _Segment {
  const _Segment({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;
}

class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({required this.segments, required this.total});

  final List<_Segment> segments;
  final int total;

  @override
  Widget build(BuildContext context) {
    final filled = [
      for (final segment in segments)
        if (segment.value > 0) segment,
    ];

    if (total == 0 || filled.isEmpty) {
      return Container(
        height: 14,
        decoration: BoxDecoration(
          color: optionColor,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: optionBorderColor),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        height: 14,
        child: Row(
          // Without this the segments centre themselves at zero height: a
          // ColoredBox with no child has nothing to give it one.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, segment) in filled.indexed) ...[
              // A 2px gap in the surface colour, so two neighbouring pastels
              // never melt into one another.
              if (index > 0) const SizedBox(width: 2),
              Expanded(
                flex: segment.value,
                child: ColoredBox(color: segment.color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.segment, required this.total});

  final _Segment segment;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          _Swatch(color: segment.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              segment.label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 14),
            ),
          ),
          Text(
            '${_formatNumber(segment.value)}  ·  ${_percent(segment.value, total)}',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ProportionRow extends StatelessWidget {
  const _ProportionRow({required this.segment, required this.total});

  final _Segment segment;
  final int total;

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : segment.value / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Swatch(color: segment.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  segment.label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 14),
                ),
              ),
              Text(
                '${_formatNumber(segment.value)}  ·  '
                '${_percent(segment.value, total)}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 10,
              backgroundColor: optionColor,
              valueColor: AlwaysStoppedAnimation(segment.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: optionBorderColor),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          child,
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

String _percent(int value, int total) =>
    total == 0 ? '0%' : '${(value / total * 100).round()}%';

String _formatDay(DateTime day) =>
    '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';

/// Thousands separated the way pt-BR writes them, without pulling in `intl`
/// for a single call site.
String _formatNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
