import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../analysis/metrics.dart';

/// Risultato salvato per una foto: valido finché la foto non viene modificata.
class CachedEntry {
  const CachedEntry(this.modified, this.hash, this.quality,
      [this.textChars = -1]);

  final int modified;
  final int hash;
  final QualityReport quality;

  /// Caratteri di testo letti nell'immagine (-1 = non ancora letti).
  final int textChars;

  CachedEntry withText(int chars) =>
      CachedEntry(modified, hash, quality, chars);

  List<Object> toJson() => [
        modified,
        hash.toString(), // stringa: 64 bit esatti
        quality.sharpness,
        quality.brightness,
        quality.darkFraction,
        quality.brightFraction,
        textChars,
      ];

  static CachedEntry? fromJson(Object? o) {
    if (o is! List || o.length < 6) return null;
    final hash = int.tryParse(o[1].toString());
    if (hash == null) return null;
    return CachedEntry(
      (o[0] as num).toInt(),
      hash,
      QualityReport(
        sharpness: (o[2] as num).toDouble(),
        brightness: (o[3] as num).toDouble(),
        darkFraction: (o[4] as num).toDouble(),
        brightFraction: (o[5] as num).toDouble(),
      ),
      o.length > 6 ? (o[6] as num).toInt() : -1,
    );
  }
}

class AnalysisCache {
  AnalysisCache([Map<String, CachedEntry>? entries]) : entries = entries ?? {};

  /// Cambia questo numero se cambia il modo di calcolare hash o qualità.
  static const int formatVersion = 1;

  final Map<String, CachedEntry> entries;

  CachedEntry? lookup(String id, int modified) {
    final e = entries[id];
    return (e != null && e.modified == modified) ? e : null;
  }

  String encode() => jsonEncode({
        'v': formatVersion,
        'items': {for (final e in entries.entries) e.key: e.value.toJson()},
      });

  static AnalysisCache decode(String text) {
    try {
      final m = jsonDecode(text);
      if (m is! Map || m['v'] != formatVersion) return AnalysisCache();
      final items = m['items'];
      if (items is! Map) return AnalysisCache();
      final out = <String, CachedEntry>{};
      items.forEach((k, v) {
        final e = CachedEntry.fromJson(v);
        if (e != null) out[k.toString()] = e;
      });
      return AnalysisCache(out);
    } catch (_) {
      return AnalysisCache();
    }
  }

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/analisi_v$formatVersion.json');
  }

  static Future<bool> exists() async => (await _file()).exists();

  static Future<AnalysisCache> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return AnalysisCache();
      return decode(await f.readAsString());
    } catch (_) {
      return AnalysisCache();
    }
  }

  Future<void> save() async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(encode(), flush: true);
    await tmp.rename(f.path);
  }
}
