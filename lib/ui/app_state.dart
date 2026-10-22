import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../analysis/grouping.dart';
import '../services/analysis_cache.dart';
import '../services/scanner.dart';

enum ScanStatus { idle, noPermission, scanning, done }

class AppState extends ChangeNotifier {
  ScanStatus status = ScanStatus.idle;
  int done = 0;
  int total = 0;
  String phase = '';
  ScanResult? result;
  bool _cancel = false;

  /// Soglia di nitidezza sotto cui una foto è "sfocata" (regolabile).
  double blurThreshold = 60;

  final Set<String> removed = {};

  List<AnalyzedPhoto> get photos => (result?.photos ?? const <AnalyzedPhoto>[])
      .where((p) => !removed.contains(p.id))
      .toList();

  AnalyzedPhoto? photo(String id) =>
      removed.contains(id) ? null : result?.byId[id];

  /// Gruppi aggiornati togliendo le foto già eliminate.
  List<PhotoGroup> groups(GroupKind kind) {
    final out = <PhotoGroup>[];
    for (final g in result?.groups ?? const <PhotoGroup>[]) {
      if (g.kind != kind) continue;
      final ids = g.ids.where((id) => !removed.contains(id)).toList();
      if (ids.length < 2) continue;
      out.add(PhotoGroup(g.kind, ids, ids.first));
    }
    return out;
  }

  int extraCopies(GroupKind kind) =>
      groups(kind).fold(0, (s, g) => s + g.ids.length - 1);

  List<AnalyzedPhoto> get blurry =>
      photos.where((p) => p.quality.isBlurry(blurThreshold)).toList()
        ..sort((a, b) => a.quality.sharpness.compareTo(b.quality.sharpness));
  List<AnalyzedPhoto> get dark =>
      photos.where((p) => p.quality.isDark).toList()
        ..sort((a, b) => a.quality.brightness.compareTo(b.quality.brightness));
  List<AnalyzedPhoto> get overexposed =>
      photos.where((p) => p.quality.isOverexposed).toList()
        ..sort((a, b) => b.quality.brightness.compareTo(a.quality.brightness));

  List<AnalyzedPhoto> get memes =>
      photos.where((p) => p.probableMeme).toList()
        ..sort((a, b) => b.textChars.compareTo(a.textChars));

  int get receivedToRead =>
      photos.where((p) => p.received && p.textChars < 0).length;

  /// Duplicati in cui almeno una copia viene da WhatsApp.
  /// Prima l'originale: fuori da WhatsApp e con più pixel.
  List<PhotoGroup> get whatsappGroups {
    final out = <PhotoGroup>[];
    for (final g in groups(GroupKind.duplicate)) {
      final ps = [for (final id in g.ids) result!.byId[id]!];
      if (!ps.any((p) => p.whatsapp)) continue;
      ps.sort((a, b) {
        if (a.whatsapp != b.whatsapp) return a.whatsapp ? 1 : -1;
        final pa = a.asset.width * a.asset.height;
        final pb = b.asset.width * b.asset.height;
        if (pa != pb) return pb.compareTo(pa);
        return a.taken.compareTo(b.taken);
      });
      out.add(PhotoGroup(g.kind, [for (final p in ps) p.id], ps.first.id));
    }
    return out;
  }

  void setBlurThreshold(double v) {
    blurThreshold = v;
    notifyListeners();
  }

  Future<void> scan() async {
    if (status == ScanStatus.scanning) return;
    if (!await Scanner.requestAccess()) {
      status = ScanStatus.noPermission;
      notifyListeners();
      return;
    }
    _cancel = false;
    status = ScanStatus.scanning;
    done = 0;
    total = 0;
    removed.clear();
    notifyListeners();
    result = await Scanner.scan(
      onProgress: (d, t, ph) {
        done = d;
        total = t;
        phase = ph;
        notifyListeners();
      },
      isCancelled: () => _cancel,
    );
    status = ScanStatus.done;
    notifyListeners();
  }

  /// All'avvio: se c'è un'analisi salvata, la ricarica subito.
  Future<void> resumeIfSaved() async {
    if (await AnalysisCache.exists()) await scan();
  }

  void cancel() => _cancel = true;

  /// Restituisce quante foto sono state davvero rimosse.
  Future<int> remove(Iterable<String> ids) async {
    final assets = <AssetEntity>[
      for (final id in ids)
        if (photo(id) != null) photo(id)!.asset,
    ];
    final gone = await Scanner.remove(assets);
    removed.addAll(gone);
    notifyListeners();
    return gone.length;
  }

  Future<void> openSettings() => PhotoManager.openSetting();
}
