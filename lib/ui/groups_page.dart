import 'package:flutter/material.dart';

import '../analysis/grouping.dart';
import 'app_state.dart';
import 'widgets.dart';

/// Gruppi di duplicati o di foto simili, con la migliore già scelta.
class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key, required this.state, required this.kind});
  final AppState state;
  final GroupKind kind;

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final Set<String> selected = {};

  @override
  void initState() {
    super.initState();
    _selectAllButBest();
  }

  void _selectAllButBest() {
    selected
      ..clear()
      ..addAll([
        for (final g in widget.state.groups(widget.kind)) ...g.ids.skip(1),
      ]);
  }

  @override
  Widget build(BuildContext context) {
    final isDup = widget.kind == GroupKind.duplicate;
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final groups = widget.state.groups(widget.kind);
        selected.removeWhere((id) => widget.state.photo(id) == null);
        return Scaffold(
          appBar: AppBar(
            title: Text(isDup ? 'Duplicati' : 'Foto simili'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) => setState(() {
                  if (v == 'auto') _selectAllButBest();
                  if (v == 'none') selected.clear();
                }),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'auto', child: Text('Tieni solo le migliori')),
                  PopupMenuItem(value: 'none', child: Text('Deseleziona tutto')),
                ],
              ),
            ],
          ),
          bottomNavigationBar: groups.isEmpty
              ? null
              : DeleteBar(
                  count: selected.length,
                  onDelete: () =>
                      confirmAndRemove(context, widget.state, {...selected}),
                ),
          body: groups.isEmpty
              ? const _Empty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: groups.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                        child: Text(
                          '${groups.length} gruppi. La stella indica lo scatto '
                          'migliore. Tocca una foto per tenerla o scartarla, '
                          'tieni premuto per ingrandirla.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }
                    return _groupCard(context, groups[i - 1]);
                  },
                ),
        );
      },
    );
  }

  Widget _groupCard(BuildContext context, PhotoGroup g) {
    final photos = [for (final id in g.ids) widget.state.photo(id)!];
    final d = photos.first.taken;
    final keep = g.ids.where((id) => !selected.contains(id)).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${photos.length} foto · ${d.day}/${d.month}/${d.year}',
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (keep == 0)
                  Text('Le scarti tutte!',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, j) {
                  final p = photos[j];
                  return SizedBox(
                    width: 110,
                    child: PhotoThumb(
                      photo: p,
                      best: j == 0,
                      selected: selected.contains(p.id),
                      onTap: () => setState(() {
                        if (!selected.remove(p.id)) selected.add(p.id);
                      }),
                      onLongPress: () => PhotoViewer.open(context, p),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Niente da sistemare qui 🎉', textAlign: TextAlign.center),
        ),
      );
}
