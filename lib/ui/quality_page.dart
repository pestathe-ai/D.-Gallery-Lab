import 'package:flutter/material.dart';

import '../services/scanner.dart';
import 'app_state.dart';
import 'widgets.dart';

enum QualityIssue { blurry, dark, overexposed }

/// Foto sfocate, troppo scure o bruciate.
class QualityPage extends StatefulWidget {
  const QualityPage({super.key, required this.state, this.initial = 0});
  final AppState state;
  final int initial;

  @override
  State<QualityPage> createState() => _QualityPageState();
}

class _QualityPageState extends State<QualityPage> {
  final Set<String> selected = {};

  List<AnalyzedPhoto> _list(QualityIssue i) => switch (i) {
        QualityIssue.blurry => widget.state.blurry,
        QualityIssue.dark => widget.state.dark,
        QualityIssue.overexposed => widget.state.overexposed,
      };

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initial,
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          selected.removeWhere((id) => widget.state.photo(id) == null);
          return Scaffold(
            appBar: AppBar(
              title: const Text('Foto venute male'),
              bottom: TabBar(tabs: [
                Tab(text: 'Sfocate (${widget.state.blurry.length})'),
                Tab(text: 'Scure (${widget.state.dark.length})'),
                Tab(text: 'Bruciate (${widget.state.overexposed.length})'),
              ]),
            ),
            bottomNavigationBar: DeleteBar(
              count: selected.length,
              onDelete: () =>
                  confirmAndRemove(context, widget.state, {...selected}),
            ),
            body: TabBarView(
              children: [
                for (final issue in QualityIssue.values) _tab(context, issue),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tab(BuildContext context, QualityIssue issue) {
    final list = _list(issue);
    final allSel = list.isNotEmpty && list.every((p) => selected.contains(p.id));
    return Column(
      children: [
        if (issue == QualityIssue.blurry)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Text('Sensibilità'),
                Expanded(
                  child: Slider(
                    min: 10,
                    max: 300,
                    divisions: 29,
                    value: widget.state.blurThreshold,
                    label: widget.state.blurThreshold.round().toString(),
                    onChanged: widget.state.setBlurThreshold,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  issue == QualityIssue.blurry
                      ? 'Dalla più sfocata. Tieni premuto per ingrandire.'
                      : 'Tieni premuto una foto per ingrandirla.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: list.isEmpty
                    ? null
                    : () => setState(() {
                          final ids = list.map((p) => p.id);
                          allSel
                              ? selected.removeAll(ids)
                              : selected.addAll(ids);
                        }),
                child: Text(allSel ? 'Deseleziona' : 'Seleziona tutte'),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Nessuna foto in questa categoria 🎉'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return PhotoThumb(
                      photo: p,
                      selected: selected.contains(p.id),
                      onTap: () => setState(() {
                        if (!selected.remove(p.id)) selected.add(p.id);
                      }),
                      onLongPress: () => PhotoViewer.open(context, p),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
