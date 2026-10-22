import 'dart:io';

import 'package:flutter/material.dart';

import '../services/archiver.dart';
import '../services/hidden_cleaner.dart';

/// Pulizia dei file nascosti: miniature, copie WhatsApp inviate, stati visti.
class HiddenPage extends StatefulWidget {
  const HiddenPage({super.key});

  @override
  State<HiddenPage> createState() => _HiddenPageState();
}

class _HiddenPageState extends State<HiddenPage> with WidgetsBindingObserver {
  bool? supported;
  bool granted = false;
  bool scanning = false;
  bool deleting = false;
  List<CategoryScan> scans = [];
  final Set<String> chosen = {'thumbs', 'wa_status'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Al ritorno dalle impostazioni ricontrollo il permesso.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final sup = await Archiver.supported;
    final ok = sup && await AllFilesAccess.granted();
    if (!mounted) return;
    setState(() {
      supported = sup;
      granted = ok;
    });
    if (ok && scans.isEmpty && !scanning) await _scan();
  }

  Future<void> _scan() async {
    setState(() => scanning = true);
    final root = await AllFilesAccess.storageRoot();
    final out = <CategoryScan>[];
    if (root != null) {
      for (final c in hiddenCategories) {
        out.add(await scanCategory(root, c));
      }
    }
    if (!mounted) return;
    setState(() {
      scans = out;
      scanning = false;
    });
  }

  Future<void> _delete() async {
    final sel = scans.where((s) => chosen.contains(s.category.id)).toList();
    final files = <File>[for (final s in sel) ...s.files];
    final total = sel.fold<int>(0, (a, s) => a + s.bytes);
    final warnings = [
      for (final s in sel)
        if (s.category.warning != null) s.category.warning!,
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Eliminare ${files.length} file (${formatBytes(total)})?'),
        content: Text([
          'Questi file non passano dal cestino: vengono eliminati subito.',
          ...warnings,
        ].join('\n\n')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annulla')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(c).colorScheme.error),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => deleting = true);
    final (n, bytes) = await deleteFiles(files);
    if (!mounted) return;
    setState(() => deleting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$n file eliminati, ${formatBytes(bytes)} liberati')));
    await _scan();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final selBytes = scans
        .where((s) => chosen.contains(s.category.id))
        .fold<int>(0, (a, s) => a + s.bytes);
    final selCount = scans
        .where((s) => chosen.contains(s.category.id))
        .fold<int>(0, (a, s) => a + s.files.length);

    Widget body;
    if (supported == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (supported == false) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Questa pulizia richiede Android 11 o successivo.',
              textAlign: TextAlign.center),
        ),
      );
    } else if (!granted) {
      body = ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.folder_special_outlined, size: 56),
          const SizedBox(height: 16),
          Text('Serve un permesso in più', style: t.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text(
            'I file nascosti non sono visibili alla Galleria. Per trovarli, '
            'D. Gallery Lab ha bisogno dell\'"Accesso a tutti i file". '
            'Lo usa solo in questa schermata e solo per le cartelle elencate.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: AllFilesAccess.request,
            child: const Text('Apri impostazioni'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nella schermata che si apre attiva l\'interruttore, poi torna qui.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      );
    } else if (scanning) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final s in scans)
            Card(
              child: CheckboxListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                value: chosen.contains(s.category.id),
                onChanged: s.files.isEmpty || deleting
                    ? null
                    : (v) => setState(() => v == true
                        ? chosen.add(s.category.id)
                        : chosen.remove(s.category.id)),
                title: Text(s.category.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      s.files.isEmpty
                          ? 'Niente da pulire'
                          : '${s.files.length} file · ${formatBytes(s.bytes)}',
                      style: t.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(s.category.description),
                    if (s.category.warning != null) ...[
                      const SizedBox(height: 4),
                      Text('⚠️ ${s.category.warning}',
                          style: t.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('File nascosti'),
        actions: [
          if (granted)
            IconButton(
                tooltip: 'Ricalcola',
                onPressed: scanning ? null : _scan,
                icon: const Icon(Icons.refresh)),
        ],
      ),
      bottomNavigationBar: !granted
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: (selCount == 0 || deleting || scanning)
                      ? null
                      : _delete,
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: Text(deleting
                      ? 'Elimino…'
                      : selCount == 0
                          ? 'Niente selezionato'
                          : 'Elimina $selCount file (${formatBytes(selBytes)})'),
                ),
              ),
            ),
      body: body,
    );
  }
}
