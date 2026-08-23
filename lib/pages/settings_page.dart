import 'package:bla_bla_in_english/repositories/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// How many words the user wants to practise each day.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int? _wordsPerDay;

  @override
  void initState() {
    super.initState();
    context.read<SettingsRepository>().wordsPerDay().then((value) {
      if (mounted) setState(() => _wordsPerDay = value);
    });
  }

  Future<void> _save(int value) async {
    setState(() => _wordsPerDay = value);
    await context.read<SettingsRepository>().setWordsPerDay(value);
  }

  @override
  Widget build(BuildContext context) {
    final value = _wordsPerDay;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações'), centerTitle: true),
      body: value == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Palavras por dia',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cada palavra aparece com uma frase diferente por dia, '
                      'até completar as cinco frases dela.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        '$value',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontSize: 48),
                      ),
                    ),
                    Slider(
                      value: value.toDouble(),
                      min: SettingsRepository.minWordsPerDay.toDouble(),
                      max: SettingsRepository.maxWordsPerDay.toDouble(),
                      divisions: (SettingsRepository.maxWordsPerDay -
                              SettingsRepository.minWordsPerDay) ~/
                          5,
                      label: '$value',
                      onChanged: (v) => setState(() => _wordsPerDay = v.round()),
                      onChangeEnd: (v) => _save(v.round()),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'A mudança vale a partir da próxima sessão — a de hoje já '
                      'foi montada.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
