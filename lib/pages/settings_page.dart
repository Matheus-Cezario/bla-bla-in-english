import 'package:bla_bla_in_english/constants.dart';
import 'package:bla_bla_in_english/providers/session_provider.dart';
import 'package:bla_bla_in_english/repositories/backup_repository.dart';
import 'package:bla_bla_in_english/repositories/settings_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

/// How many words the user wants to practise each day, and where their progress
/// is kept safe.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int? _wordsPerDay;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadWordsPerDay();
  }

  Future<void> _loadWordsPerDay() async {
    final value = await context.read<SettingsRepository>().wordsPerDay();
    if (mounted) setState(() => _wordsPerDay = value);
  }

  Future<void> _save(int value) async {
    setState(() => _wordsPerDay = value);
    await context.read<SettingsRepository>().setWordsPerDay(value);
  }

  void _tell(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Copies the progress database out and hands it to the share sheet, so the
  /// user can drop it in Drive, e-mail it to themselves, or park it anywhere
  /// that is not this phone's app storage.
  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      final file = await context.read<BackupRepository>().export();
      if (!mounted) return;

      // iPads need to know where the sheet is popping out of; harmless
      // elsewhere.
      final box = context.findRenderObject() as RenderBox?;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          fileNameOverrides: [p.basename(file.path)],
          subject: 'Backup do Blá Blá in English',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      _tell('Não deu para gerar o backup: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar backup?'),
        content: const Text(
          'Todo o progresso atual deste aparelho será substituído pelo que '
          'estiver no arquivo. Isso não tem como voltar atrás.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Escolher arquivo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      // Read before the picker: it can sit open for a minute, and this page may
      // be gone by the time it returns.
      final backups = context.read<BackupRepository>();
      final picked = await FilePicker.pickFile(
        dialogTitle: 'Escolha o arquivo de backup',
      );
      if (picked == null) return;

      final summary = await backups.restore(await picked.readAsBytes());
      if (!mounted) return;

      // The restore replaced the settings table too, and the session on screen
      // belongs to the progress that was just thrown away.
      await _loadWordsPerDay();
      if (mounted) await context.read<SessionProvider>().load();

      _tell('Progresso restaurado: ${summary.answers} respostas em '
          '${summary.words} palavras.');
    } on BackupFormatException catch (error) {
      _tell(error.message);
    } catch (error) {
      _tell('Não deu para restaurar: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _wordsPerDay;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações'), centerTitle: true),
      body: value == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
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
                  const SizedBox(height: 36),
                  const Divider(color: optionBorderColor),
                  const SizedBox(height: 24),
                  _BackupSection(
                    busy: _busy,
                    onExport: _exportBackup,
                    onRestore: _restoreBackup,
                  ),
                ],
              ),
            ),
    );
  }
}

class _BackupSection extends StatelessWidget {
  const _BackupSection({
    required this.busy,
    required this.onExport,
    required this.onRestore,
  });

  final bool busy;
  final VoidCallback onExport;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Backup do progresso',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Desinstalar o app apaga tudo o que você praticou — é o Android que '
          'faz isso, e nada dentro do app consegue impedir. Guarde um arquivo '
          'de backup fora do celular e você nunca mais perde nada.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: busy ? null : onExport,
          icon: const Icon(Icons.save_alt),
          label: const Text('Salvar backup'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : onRestore,
          icon: const Icon(Icons.restore),
          label: const Text('Restaurar backup'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            side: const BorderSide(color: optionBorderColor),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}
