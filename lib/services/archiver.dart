import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import 'analysis_cache.dart';

const _mesi = [
  'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno', 'Luglio',
  'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
];

const archiveRoot = 'Pictures/Archivio/';

/// Cartella di destinazione, es. "Pictures/Archivio/2024/2024-03 Marzo/".
/// L'ultima cartella contiene anno e mese, così ogni album ha un nome unico.
String archivePathFor(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  return '$archiveRoot${d.year}/${d.year}-$mm ${_mesi[d.month - 1]}/';
}

/// Normalizza un percorso relativo (con "/" finale) per i confronti.
String normalizeRelPath(String? p) {
  if (p == null || p.isEmpty) return '';
  return p.endsWith('/') ? p : '$p/';
}

/// Nome leggibile della cartella di provenienza ("DCIM/Camera/" -> "DCIM/Camera").
String folderLabel(String rel) {
  final r = normalizeRelPath(rel);
  return r.isEmpty ? '(sconosciuta)' : r.substring(0, r.length - 1);
}

class MoveItem {
  const MoveItem(this.id, this.from, this.to);
  final String id;
  final String from;
  final String to;
}

/// Calcola gli spostamenti necessari: salta le foto già al posto giusto.
List<MoveItem> planMoves(
  Iterable<({String id, String? relPath, DateTime taken})> photos, {
  Set<String>? onlyFromFolders,
}) {
  final out = <MoveItem>[];
  for (final p in photos) {
    final from = normalizeRelPath(p.relPath);
    final to = archivePathFor(p.taken);
    if (from == to) continue;
    if (onlyFromFolders != null && !onlyFromFolders.contains(from)) continue;
    out.add(MoveItem(p.id, from, to));
  }
  return out;
}

class ArchiveOutcome {
  const ArchiveOutcome(this.moved, this.failed, this.denied);
  final int moved;
  final int failed;
  final int denied;
}

class Archiver {
  static const _ch = MethodChannel('dgallerylab/archive');
  static const chunk = 300;

  static Future<int> sdkInt() async =>
      (await _ch.invokeMethod<int>('sdkInt')) ?? 0;

  static Future<bool> get supported async => await sdkInt() >= 30;

  /// Sposta a blocchi; per ogni blocco Android chiede una conferma
  /// (salvo che sia attiva "Gestione contenuti multimediali").
  static Future<ArchiveOutcome> run(
    List<MoveItem> moves, {
    required void Function(int done, int total) onProgress,
  }) async {
    var moved = 0, failed = 0, denied = 0, done = 0;
    for (var i = 0; i < moves.length; i += chunk) {
      final part = moves.sublist(i, (i + chunk).clamp(0, moves.length));
      final ok = await _ch.invokeMethod<bool>(
              'requestWrite', {'ids': part.map((m) => m.id).toList()}) ??
          false;
      if (!ok) {
        denied += part.length;
      } else {
        final r = await _ch.invokeMapMethod<String, dynamic>('move', {
          'items': [for (final m in part) {'id': m.id, 'path': m.to}],
        });
        moved += (r?['moved'] as int?) ?? 0;
        failed += (r?['failed'] as int?) ?? 0;
      }
      done += part.length;
      onProgress(done, moves.length);
    }
    await _refreshCache(moves.map((m) => m.id));
    return ArchiveOutcome(moved, failed, denied);
  }

  /// Dopo lo spostamento la data di modifica cambia: aggiorniamo l'analisi
  /// salvata così le foto non vengono rianalizzate.
  static Future<void> _refreshCache(Iterable<String> ids) async {
    try {
      final cache = await AnalysisCache.load();
      for (final id in ids) {
        final old = cache.entries[id];
        if (old == null) continue;
        final a = await AssetEntity.fromId(id);
        if (a == null) continue;
        cache.entries[id] =
            CachedEntry(a.modifiedDateSecond ?? 0, old.hash, old.quality);
      }
      await cache.save();
    } catch (_) {}
  }

  static Future<bool> canSkipConfirmations() => PhotoManager.canManageMedia();
  static Future<bool> askSkipConfirmations() =>
      PhotoManager.requestManageMedia();
}
