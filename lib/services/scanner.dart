import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:photo_manager/photo_manager.dart';

import '../analysis/grouping.dart';
import '../analysis/metrics.dart';

class AnalyzedPhoto {
  AnalyzedPhoto(this.asset, this.hash, this.quality);

  final AssetEntity asset;
  final int hash;
  final QualityReport quality;

  String get id => asset.id;
  DateTime get taken => asset.createDateTime;

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

  /// Analizza tutte le foto. [onProgress] riceve (fatte, totali).
  static Future<ScanResult> scan({
    required void Function(int done, int total) onProgress,
    bool Function()? isCancelled,
  }) async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) return ScanResult([], []);
    final all = paths.first;
    final total = await all.assetCountAsync;
    final photos = <AnalyzedPhoto>[];
    const pageSize = 100;
    var done = 0;

    for (var page = 0; page * pageSize < total; page++) {
      final assets = await all.getAssetListPaged(page: page, size: pageSize);
      for (final a in assets) {
        if (isCancelled?.call() ?? false) {
          return _finish(photos);
        }
        try {
          final bytes = await a.thumbnailDataWithSize(
            const ThumbnailSize.square(thumbSize),
            quality: 90,
          );
          if (bytes != null) {
            final gray = await _decodeGray(bytes);
            if (gray != null) {
              photos.add(AnalyzedPhoto(a, dHash(gray), analyzeQuality(gray)));
            }
          }
        } catch (_) {
          // Foto illeggibile: la saltiamo.
        }
        done++;
        if (done % 5 == 0 || done == total) onProgress(done, total);
      }
    }
    return _finish(photos);
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
