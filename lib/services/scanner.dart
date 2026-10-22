import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../analysis/grouping.dart';
import '../analysis/metrics.dart';
import '../analysis/source.dart';
import 'analysis_cache.dart';

class AnalyzedPhoto {
  AnalyzedPhoto(this.asset, this.hash, this.quality, [this.textChars = -1]);

  final AssetEntity asset;
  final int hash;
  final QualityReport quality;

  /// Caratteri di testo letti (-1 = non letti).
  int textChars;

  String get id => asset.id;
  DateTime get taken => asset.createDateTime;
  String? get folder => asset.relativePath;
  String get title => asset.title ?? '';

  bool get whatsapp => isWhatsApp(folder, title);
  bool get received => isReceived(folder, title);
  bool get screenshot => isScreenshot(folder, title);
  bool get probableMeme => isProbableMeme(
        received: received,
        textChars: textChars,
        width: asset.width,
        height: asset.height,
      );

  PhotoInfo toInfo() => PhotoInfo(
        id: asset.id,
        hash: hash,
        score: quality.score,
        width: asset.width,
        height: asset.height,
        takenMs: asset.createDateTime.millisecondsSinceEpoch,
      );
}

class ScanResult {
  ScanResult(this.photos, this.groups);

  final List<AnalyzedPhoto> photos;
  final List<PhotoGroup> groups;

  late final Map<String, AnalyzedPhoto> byId = {
    for (final p in photos) p.id: p,
  };
}

class Scanner {
  static const int thumbSize = 256;

  /// true = accesso completo o parziale concesso.
  static Future<bool> requestAccess() async {
    final ps = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      ),
    );
    return ps.hasAccess;
  }

  /// Analizza tutte le foto, riusando l'analisi salvata per quelle
  /// non modificate. [onProgress] riceve (fatte, totali).
  static Future<ScanResult> scan({
    required void Function(int done, int total, String phase) onProgress,
    bool Function()? isCancelled,
  }) async {
    const phase = 'Analisi delle immagini';
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) return ScanResult([], []);
    final all = paths.first;
    final total = await all.assetCountAsync;
    final old = await AnalysisCache.load();
    final fresh = AnalysisCache();
    final photos = <AnalyzedPhoto>[];
    const pageSize = 200;
    var done = 0;
    var newSinceSave = 0;

    Future<void> saveQuietly() async {
      try {
        // conserva anche le voci vecchie non ancora riviste (scansione interrotta)
        final merged = AnalysisCache({...old.entries, ...fresh.entries});
        await merged.save();
      } catch (_) {}
    }

    for (var page = 0; page * pageSize < total; page++) {
      final assets = await all.getAssetListPaged(page: page, size: pageSize);
      for (final a in assets) {
        if (isCancelled?.call() ?? false) {
          await saveQuietly();
          return _finish(photos);
        }
        final modified = a.modifiedDateSecond ?? 0;
        final hit = old.lookup(a.id, modified);
        if (hit != null) {
          fresh.entries[a.id] = hit;
          photos.add(AnalyzedPhoto(a, hit.hash, hit.quality, hit.textChars));
        } else {
          try {
            final bytes = await a.thumbnailDataWithSize(
              const ThumbnailSize.square(thumbSize),
              quality: 90,
            );
            if (bytes != null) {
              final gray = await _decodeGray(bytes);
              if (gray != null) {
                final p = AnalyzedPhoto(a, dHash(gray), analyzeQuality(gray));
                photos.add(p);
                fresh.entries[a.id] = CachedEntry(modified, p.hash, p.quality);
                newSinceSave++;
              }
            }
          } catch (_) {
            // Foto illeggibile: la saltiamo.
          }
          if (newSinceSave >= 300) {
            newSinceSave = 0;
            await saveQuietly();
          }
        }
        done++;
        if (done % 10 == 0 || done == total) onProgress(done, total, phase);
      }
    }
    // Scansione completa: si salvano solo le foto ancora presenti.
    try {
      await fresh.save();
    } catch (_) {}

    // Seconda fase: leggo il testo nelle immagini ricevute (per i meme).
    await _readText(photos, fresh, onProgress, isCancelled);
    return _finish(photos);
  }

  static Future<void> _readText(
    List<AnalyzedPhoto> photos,
    AnalysisCache cache,
    void Function(int done, int total, String phase) onProgress,
    bool Function()? isCancelled,
  ) async {
    final todo =
        photos.where((p) => p.received && p.textChars < 0).toList();
    if (todo.isEmpty) return;
    const phase = 'Cerco i meme';
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final tmp = File('${(await getTemporaryDirectory()).path}/ocr.jpg');
    var done = 0, sinceSave = 0;
    try {
      for (final p in todo) {
        if (isCancelled?.call() ?? false) break;
        try {
          final bytes = await p.asset.thumbnailDataWithSize(
              const ThumbnailSize(720, 720),
              quality: 90);
          if (bytes != null) {
            await tmp.writeAsBytes(bytes, flush: true);
            final r =
                await recognizer.processImage(InputImage.fromFilePath(tmp.path));
            p.textChars = r.text.replaceAll(RegExp(r'\s'), '').length;
            final e = cache.entries[p.id];
            if (e != null) cache.entries[p.id] = e.withText(p.textChars);
            sinceSave++;
          }
        } catch (_) {
          p.textChars = 0;
        }
        done++;
        if (done % 5 == 0 || done == todo.length) {
          onProgress(done, todo.length, phase);
        }
        if (sinceSave >= 100) {
          sinceSave = 0;
          try {
            await cache.save();
          } catch (_) {}
        }
      }
    } finally {
      await recognizer.close();
      try {
        await cache.save();
      } catch (_) {}
    }
  }

  static Future<ScanResult> _finish(List<AnalyzedPhoto> photos) async {
    final infos = photos.map((p) => p.toInfo()).toList();
    final groups = await Isolate.run(() => groupPhotos(infos));
    return ScanResult(photos, groups);
  }

  static Future<GrayImage?> _decodeGray(Uint8List encoded) async {
    final codec = await ui.instantiateImageCodec(encoded);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = img.width, h = img.height;
    img.dispose();
    codec.dispose();
    if (data == null) return null;
    return GrayImage.fromRgba(data.buffer.asUint8List(), w, h);
  }

  /// Sposta nel cestino (Android 11+, recuperabile ~30 giorni);
  /// sulle versioni più vecchie elimina definitivamente.
  /// Restituisce gli id effettivamente rimossi.
  static Future<Set<String>> remove(List<AssetEntity> assets) async {
    if (assets.isEmpty) return {};
    try {
      await PhotoManager.editor.android.moveToTrash(assets);
    } catch (_) {
      await PhotoManager.editor.deleteWithIds(assets.map((a) => a.id).toList());
    }
    final removed = <String>{};
    for (final a in assets) {
      final still = await AssetEntity.fromId(a.id);
      if (still == null || !(await still.exists)) removed.add(a.id);
    }
    return removed;
  }
}
