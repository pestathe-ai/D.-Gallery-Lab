import 'package:flutter/material.dart';

import '../services/scanner.dart';
import 'app_state.dart';
import 'widgets.dart';

const _mesi = [
  'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno', 'Luglio',
  'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
];

/// Archivio ordinato per Anno / Mese.
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key, required this.state});
  final AppState state;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  bool bestFirst = false;
  int? year;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final all = widget.state.photos;
        final years = {for (final p in all) p.taken.year}.toList()
          ..sort((a, b) => b.compareTo(a));
        final shown = year == null
            ? all
            : all.where((p) => p.taken.year == year).toList();

        final months = <int, List<AnalyzedPhoto>>{};
        for (final p in shown) {
          months.putIfAbsent(p.taken.year * 100 + p.taken.month, () => []).add(p);
        }
        final keys = months.keys.toList()..sort((a, b) => b.compareTo(a));
        for (final k in keys) {
          months[k]!.sort(bestFirst
              ? (a, b) => b.quality.score.compareTo(a.quality.score)
              : (a, b) => b.taken.compareTo(a.taken));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Archivio'),
            actions: [
              IconButton(
                tooltip: bestFirst ? 'Ordina per data' : 'Migliori prima',
                icon: Icon(bestFirst ? Icons.schedule : Icons.auto_awesome),
                onPressed: () => setState(() => bestFirst = !bestFirst),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    children: [
                      _chip('Tutti', year == null, () => setState(() => year = null)),
                      for (final y in years)
                        _chip('$y', year == y, () => setState(() => year = y)),
                    ],
                  ),
                ),
              ),
              for (final k in keys) ...[
                SliverToBoxAdapter(child: _header(context, k, months[k]!)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4),
                    itemCount: months[k]!.length,
                    itemBuilder: (_, i) {
                      final p = months[k]![i];
                      return PhotoThumb(
                        photo: p,
                        size: 160,
                        onTap: () => PhotoViewer.open(context, p),
                      );
                    },
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: sel, onSelected: (_) => onTap()),
      );

  Widget _header(BuildContext context, int key, List<AnalyzedPhoto> list) {
    final avg = list.fold<int>(0, (s, p) => s + p.quality.score) ~/ list.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text('${_mesi[key % 100 - 1]} ${key ~/ 100}',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Text('${list.length} foto  ', style: Theme.of(context).textTheme.bodySmall),
          ScoreBadge(avg),
        ],
      ),
    );
  }
}
