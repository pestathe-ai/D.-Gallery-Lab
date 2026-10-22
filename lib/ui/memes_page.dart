import 'package:flutter/material.dart';

import 'app_state.dart';
import 'widgets.dart';

/// Immagini ricevute con molto testo: probabili meme da rivedere.
class MemesPage extends StatefulWidget {
  const MemesPage({super.key, required this.state});
  final AppState state;

  @override
  State<MemesPage> createState() => _MemesPageState();
}

class _MemesPageState extends State<MemesPage> {
  final Set<String> selected = {};

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final list = widget.state.memes;
        selected.removeWhere((id) => widget.state.photo(id) == null);
        final allSel =
            list.isNotEmpty && list.every((p) => selected.contains(p.id));
        return Scaffold(
          appBar: AppBar(title: Text('Probabili meme (${list.length})')),
          bottomNavigationBar: DeleteBar(
            count: selected.length,
            onDelete: () =>
                confirmAndRemove(context, widget.state, {...selected}),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Immagini ricevute (WhatsApp, Telegram, download…) con '
                        'molto testo sopra. Controlla prima di eliminare: '
                        'potrebbero esserci anche documenti o ricevute.',
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
                    ? const Center(child: Text('Nessun meme trovato 🎉'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6),
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
          ),
        );
      },
    );
  }
}
