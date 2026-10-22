import 'package:flutter/material.dart';

import '../analysis/grouping.dart';
import 'app_state.dart';
import 'groups_page.dart';
import 'quality_page.dart';
import 'timeline_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('D. Gallery Lab',
                style: TextStyle(fontWeight: FontWeight.w700)),
            actions: [
              if (state.status == ScanStatus.done)
                IconButton(
                  tooltip: 'Analizza di nuovo',
                  icon: const Icon(Icons.refresh),
                  onPressed: state.scan,
                ),
            ],
          ),
          body: switch (state.status) {
            ScanStatus.idle => _Intro(state: state),
            ScanStatus.noPermission => _NoPermission(state: state),
            ScanStatus.scanning => _Progress(state: state),
            ScanStatus.done => _Dashboard(state: state),
          },
        );
      },
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.auto_awesome_mosaic_outlined, size: 72, color: cs.primary),
        const SizedBox(height: 20),
        Text('Metti ordine nella galleria',
            style: t.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'Trova duplicati, scatti simili e foto venute male, ti suggerisce '
          'lo scatto migliore e ordina tutto per anno e mese. L\'analisi '
          'avviene solo sul telefono: nessuna foto viene inviata online.',
          style: t.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: state.scan,
          icon: const Icon(Icons.search),
          label: const Text('Analizza galleria'),
        ),
      ],
    );
  }
}

class _NoPermission extends StatelessWidget {
  const _NoPermission({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Serve il permesso di accedere alle foto per analizzarle.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                  onPressed: state.openSettings,
                  child: const Text('Apri impostazioni')),
              TextButton(onPressed: state.scan, child: const Text('Riprova')),
            ],
          ),
        ),
      );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final frac = state.total == 0 ? null : state.done / state.total;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Analisi in corso…',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: frac, minHeight: 8,
                borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 12),
            Text(state.total == 0
                ? 'Preparo l\'elenco delle foto'
                : '${state.done} di ${state.total} foto'),
            const SizedBox(height: 8),
            const Text('Le foto già analizzate vengono saltate.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            TextButton(onPressed: state.cancel, child: const Text('Interrompi')),
          ],
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.state});
  final AppState state;

  void _go(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final photos = state.photos;
    final avg = photos.isEmpty
        ? 0
        : photos.fold<int>(0, (s, p) => s + p.quality.score) ~/ photos.length;
    final dupGroups = state.groups(GroupKind.duplicate);
    final simGroups = state.groups(GroupKind.similar);
    final bad = {
      ...state.blurry.map((p) => p.id),
      ...state.dark.map((p) => p.id),
      ...state.overexposed.map((p) => p.id),
    }.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${photos.length} foto analizzate',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${state.extraCopies(GroupKind.duplicate) + state.extraCopies(GroupKind.similar) + bad} '
                        'possibili scarti',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text('$avg',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const Text('qualità media',
                        style: TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _Tile(
          icon: Icons.copy_all_outlined,
          title: 'Duplicati',
          subtitle: '${dupGroups.length} gruppi · '
              '${state.extraCopies(GroupKind.duplicate)} copie in più',
          onTap: () =>
              _go(context, GroupsPage(state: state, kind: GroupKind.duplicate)),
        ),
        _Tile(
          icon: Icons.burst_mode_outlined,
          title: 'Scatti simili',
          subtitle: '${simGroups.length} raffiche · scelgo il migliore',
          onTap: () =>
              _go(context, GroupsPage(state: state, kind: GroupKind.similar)),
        ),
        _Tile(
          icon: Icons.blur_on,
          title: 'Sfocate',
          subtitle: '${state.blurry.length} foto',
          onTap: () => _go(context, QualityPage(state: state)),
        ),
        _Tile(
          icon: Icons.brightness_3_outlined,
          title: 'Troppo scure',
          subtitle: '${state.dark.length} foto',
          onTap: () => _go(context, QualityPage(state: state, initial: 1)),
        ),
        _Tile(
          icon: Icons.wb_sunny_outlined,
          title: 'Bruciate',
          subtitle: '${state.overexposed.length} foto',
          onTap: () => _go(context, QualityPage(state: state, initial: 2)),
        ),
        _Tile(
          icon: Icons.calendar_month_outlined,
          title: 'Archivio Anno / Mese',
          subtitle: 'Sfoglia per periodo, migliori in evidenza',
          onTap: () => _go(context, TimelinePage(state: state)),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
