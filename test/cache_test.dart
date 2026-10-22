import 'package:d_gallery_lab/analysis/metrics.dart';
import 'package:d_gallery_lab/services/analysis_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const q = QualityReport(
      sharpness: 123.5, brightness: 98.2, darkFraction: 0.1, brightFraction: 0.02);

  test('salva e ricarica senza perdere i 64 bit dell\'hash', () {
    final c = AnalysisCache({
      'a': const CachedEntry(1700000000, -8070450532247928832, q),
      'b': const CachedEntry(5, 0x7FFFFFFFFFFFFFFF, q),
    });
    final back = AnalysisCache.decode(c.encode());
    expect(back.entries.length, 2);
    expect(back.lookup('a', 1700000000)!.hash, -8070450532247928832);
    expect(back.lookup('b', 5)!.hash, 0x7FFFFFFFFFFFFFFF);
    expect(back.lookup('a', 1700000000)!.quality.score, q.score);
  });

  test('foto modificata: analisi da rifare', () {
    final c = AnalysisCache({'a': const CachedEntry(10, 1, q)});
    expect(c.lookup('a', 11), isNull);
    expect(c.lookup('x', 10), isNull);
  });

  test('file rovinato o di un\'altra versione: si riparte da zero', () {
    expect(AnalysisCache.decode('{rotto').entries, isEmpty);
    expect(AnalysisCache.decode('{"v":999,"items":{}}').entries, isEmpty);
  });
}
