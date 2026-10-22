import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../services/scanner.dart';
import 'app_state.dart';

Color scoreColor(int score) {
  if (score >= 70) return const Color(0xFF2E9E6A);
  if (score >= 45) return const Color(0xFFD99A1E);
  return const Color(0xFFD2453A);
}

class ScoreBadge extends StatelessWidget {
  const ScoreBadge(this.score, {super.key});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scoreColor(score),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$score',
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Miniatura con punteggio, stella "migliore" e spunta di selezione.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.photo,
    this.selected = false,
    this.best = false,
    this.onTap,
    this.onLongPress,
    this.size = 200,
  });

  final AnalyzedPhoto photo;
  final bool selected;
  final bool best;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final int size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AssetEntityImage(
              photo.asset,
              isOriginal: false,
              thumbnailSize: ThumbnailSize.square(size),
              fit: BoxFit.cover,
            ),
            if (selected)
              Container(color: Colors.black.withValues(alpha: 0.45)),
            Positioned(left: 4, bottom: 4, child: ScoreBadge(photo.quality.score)),
            if (best)
              Positioned(
                left: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      color: cs.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.star, size: 14, color: Colors.white),
                ),
              ),
            if (selected)
              const Positioned(
                right: 4,
                top: 4,
                child: Icon(Icons.delete_outline, color: Colors.white, size: 22),
              ),
            if (selected)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.error, width: 3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Barra in basso con il pulsante di eliminazione.
class DeleteBar extends StatelessWidget {
  const DeleteBar({super.key, required this.count, required this.onDelete});
  final int count;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: count == 0 ? null : onDelete,
          icon: const Icon(Icons.delete_sweep_outlined),
          label: Text(count == 0
              ? 'Nessuna foto selezionata'
              : 'Sposta nel cestino ($count)'),
        ),
      ),
    );
  }
}

/// Chiede conferma ed elimina. Restituisce true se qualcosa è stato rimosso.
Future<bool> confirmAndRemove(
    BuildContext context, AppState state, Set<String> ids) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Spostare ${ids.length} foto nel cestino?'),
      content: const Text(
          'Su Android 11 e successivi restano recuperabili dal cestino della '
          'Galleria per circa 30 giorni. Android ti chiederà un\'ulteriore '
          'conferma.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annulla')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sposta')),
      ],
    ),
  );
  if (ok != true) return false;
  final n = await state.remove(ids);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(n == 0
          ? 'Nessuna foto rimossa'
          : '$n foto spostate nel cestino'),
    ));
  }
  return n > 0;
}

/// Visualizzatore a schermo intero con i dettagli dell'analisi.
class PhotoViewer extends StatelessWidget {
  const PhotoViewer({super.key, required this.photo});
  final AnalyzedPhoto photo;

  static Future<void> open(BuildContext context, AnalyzedPhoto p) =>
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => PhotoViewer(photo: p)));

  @override
  Widget build(BuildContext context) {
    final q = photo.quality;
    final d = photo.taken;
    String two(int v) => v.toString().padLeft(2, '0');
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${two(d.day)}/${two(d.month)}/${d.year}  '
            '${two(d.hour)}:${two(d.minute)}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Center(
                child: AssetEntityImage(
                  photo.asset,
                  isOriginal: false,
                  thumbnailSize: const ThumbnailSize(1600, 1600),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF151515),
            child: SafeArea(
              top: false,
              child: Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _info('Punteggio', '${q.score}/100'),
                  _info('Nitidezza', q.sharpness.toStringAsFixed(0)),
                  _info('Luminosità', q.brightness.toStringAsFixed(0)),
                  _info('Risoluzione', '${photo.asset.width}×${photo.asset.height}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ],
      );
}
