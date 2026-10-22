import 'package:flutter/material.dart';

import '../services/archiver.dart';
import 'app_state.dart';

/// Sposta davvero le foto in Pictures/Archivio/Anno/Anno-Mese Nome.
class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key, required this.state});
  final AppState state;

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  bool? supported;
  bool skipConfirm = false;
  final Set<String> folders = {};
  bool running = false;
  int done = 0, total = 0;
  ArchiveOutcome? outcome;

  List<MoveItem> _plan({Set<String>? only}) => planMoves(
        widget.state.photos.map((p) => (
              id: p.id,
              relPath: p.asset.relativePath,
              taken: p.taken,
            )),
        onlyFromFolders: only,
      );

  @override
  void initState() {
    super.initState();
    folders.addAll(_plan().map((m) => m.from));
    _check();
  }

  Future<void> _check() async {
    final s = await Archiver.supported;
    final c = s ? await Archiver.canSkipConfirmations() : false;
    if (mounted) setState(() {
      supported = s;
      skipConfirm = c;
    });
  }

  Future<void> _start(List<MoveItem> moves) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Archiviare ${moves.length} foto?'),
        content: const Text(
            'Le foto verranno spostate in Pictures/Archivio, divise per anno '
            'e mese. Non viene cancellato nulla e restano visibili in '
            'Galleria. Android ti chiederà di confermare.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Archivia')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      running = true;
      done = 0;
      total = moves.length;
      outcome = null;
    });
    ArchiveOutcome? r;
    try {
      r = await Archiver.run(moves, onProgress: (d, t) {
        if (mounted) setState(() => done = d);
      });
    } catch (e) {
      r = ArchiveOutcome(0, moves.length, 0);
    }
    if (!mounted) return;
    setState(() {
      running = false;
      outcome = r;
    });
    await widget.state.scan(); // ricarica (veloce, usa l'analisi salvata)
    if (mounted) {
      setState(() {
        folders
          ..clear()
          ..addAll(_plan().map((m) => m.from));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final all = _plan();
    final byFolder = <String, int>{};
    for (final m in all) {
      byFolder[m.from] = (byFolder[m.from] ?? 0) + 1;
    }
    final keys = byFolder.keys.toList()
      ..sort((a, b) => byFolder[b]!.compareTo(byFolder[a]!));
    final moves = _plan(only: folders);

    return Scaffold(
      appBar: AppBar(title: const Text('Archivia in cartelle')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: (supported == true && !running && moves.isNotEmpty)
                ? () => _start(moves)
                : null,
            icon: const Icon(Icons.drive_file_move_outline),
            label: Text(running
                ? 'Archiviazione… $done/$total'
                : 'Archivia ${moves.length} foto'),
          ),
        ),
      ),
      body: supported == null
          ? const Center(child: CircularProgressIndicator())
          : supported == false
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Lo spostamento in cartelle richiede Android 11 o '
                      'successivo.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Dove finiranno', style: t.titleSmall),
                            const SizedBox(height: 6),
                            Text(archivePathFor(DateTime(2024, 3)),
                                style: const TextStyle(fontFamily: 'monospace')),
                            const SizedBox(height: 8),
                            Text(
                              'In Galleria vedrai un album per ogni mese '
                              '("2024-03 Marzo"). La vista "Foto" resta uguale. '
                              'Nell\'app Amazon Photos attiva il salvataggio '
                              'automatico della cartella "Archivio".',
                              style: t.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (running) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                          value: total == 0 ? null : done / total),
                    ],
                    if (outcome != null) ...[
                      const SizedBox(height: 8),
                      Card(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '✅ ${outcome!.moved} foto archiviate'
                            '${outcome!.failed > 0 ? '\n⚠️ ${outcome!.failed} non spostate' : ''}'
                            '${outcome!.denied > 0 ? '\n✋ ${outcome!.denied} saltate (conferma negata)' : ''}',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Evita conferme ripetute'),
                      subtitle: const Text(
                          'Apre le impostazioni: attiva "Gestione contenuti '
                          'multimediali" per D. Gallery Lab.'),
                      value: skipConfirm,
                      onChanged: skipConfirm
                          ? null
                          : (_) async {
                              await Archiver.askSkipConfirmations();
                              await Future<void>.delayed(
                                  const Duration(seconds: 1));
                              _check();
                            },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      all.isEmpty
                          ? 'Tutte le foto sono già archiviate 🎉'
                          : 'Da quali cartelle prendere le foto',
                      style: t.titleSmall,
                    ),
                    for (final k in keys)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: folders.contains(k),
                        onChanged: running
                            ? null
                            : (v) => setState(() =>
                                v == true ? folders.add(k) : folders.remove(k)),
                        title: Text(folderLabel(k),
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text('${byFolder[k]} foto'),
                      ),
                  ],
                ),
    );
  }
}
