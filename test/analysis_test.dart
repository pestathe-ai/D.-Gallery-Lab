import 'dart:math' as math;
import 'dart:typed_data';

import 'package:d_gallery_lab/analysis/grouping.dart';
import 'package:d_gallery_lab/analysis/metrics.dart';
import 'package:flutter_test/flutter_test.dart';

GrayImage scene({int seed = 1, int shift = 0, int size = 128}) {
  final r = math.Random(seed);
  final px = Uint8List(size * size);
  // gradienti + forme casuali: un'immagine "naturale" con dettagli
  final rects = List.generate(12, (_) => [
        r.nextInt(size), r.nextInt(size), 10 + r.nextInt(40), 10 + r.nextInt(40),
        r.nextInt(256)
      ]);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      var v = (x + y) * 255 ~/ (2 * size);
      for (final q in rects) {
        if (x >= q[0] && x < q[0] + q[2] && y >= q[1] && y < q[1] + q[3]) {
          v = q[4];
        }
      }
      px[y * size + x] = (v + shift).clamp(0, 255);
    }
  }
  return GrayImage(size, size, px);
}

GrayImage blur(GrayImage img, int radius) {
  var cur = img;
  for (var k = 0; k < radius; k++) {
    final out = Uint8List(cur.pixels.length);
    for (var y = 0; y < cur.height; y++) {
      for (var x = 0; x < cur.width; x++) {
        var s = 0, n = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final xx = x + dx, yy = y + dy;
            if (xx < 0 || yy < 0 || xx >= cur.width || yy >= cur.height) continue;
            s += cur.at(xx, yy);
            n++;
          }
        }
        out[y * cur.width + x] = s ~/ n;
      }
    }
    cur = GrayImage(cur.width, cur.height, out);
  }
  return cur;
}

void main() {
  test('RGBA -> grigio', () {
    final g = GrayImage.fromRgba(
        Uint8List.fromList([255, 255, 255, 255, 0, 0, 0, 255]), 2, 1);
    expect(g.pixels, [255, 0]);
  });

  test('stessa foto: hash identico', () {
    expect(hammingDistance(dHash(scene()), dHash(scene())), 0);
  });

  test('foto un po\' più chiara: hash quasi uguale', () {
    expect(hammingDistance(dHash(scene()), dHash(scene(shift: 15))),
        lessThanOrEqualTo(4));
  });

  test('foto diverse: hash lontani', () {
    expect(hammingDistance(dHash(scene(seed: 1)), dHash(scene(seed: 99))),
        greaterThan(12));
  });

  test('hamming con bit alto', () {
    expect(hammingDistance(-1, 0), 64);
    expect(hammingDistance(1 << 63, 0), 1);
  });

  test('la foto sfocata ha nitidezza molto più bassa', () {
    final sharp = analyzeQuality(scene());
    final soft = analyzeQuality(blur(scene(), 4));
    expect(soft.sharpness, lessThan(sharp.sharpness / 3));
    expect(soft.score, lessThan(sharp.score));
  });

  test('scura e bruciata riconosciute', () {
    final dark = analyzeQuality(GrayImage(10, 10, Uint8List(100)));
    final white =
        analyzeQuality(GrayImage(10, 10, Uint8List(100)..fillRange(0, 100, 255)));
    expect(dark.isDark, isTrue);
    expect(white.isOverexposed, isTrue);
    expect(analyzeQuality(scene()).isDark, isFalse);
  });

  test('raggruppamento: duplicati, simili e migliore', () {
    const h1 = 0;
    const h2 = 0x00FF00FF00FF00FF;
    const h3 = 0x0F0F0F0F0F0F0F0F;
    PhotoInfo p(String id, int hash, int score, int t, {int w = 100}) =>
        PhotoInfo(
            id: id, hash: hash, score: score, width: w, height: 100, takenMs: t);
    final photos = [
      p('a', h1, 80, 0),
      p('a-copia', h1, 80, 5000000, w: 50), // copia più piccola, molto dopo
      p('b1', h2, 40, 0),
      p('b2', h2 ^ 0x1F, 90, 1000), // simile (5 bit), scattata subito dopo
      p('c', h3, 70, 0),
    ];
    final groups = groupPhotos(photos);
    final dup = groups.where((g) => g.kind == GroupKind.duplicate).toList();
    final sim = groups.where((g) => g.kind == GroupKind.similar).toList();
    expect(dup.length, 1);
    expect(dup.first.bestId, 'a');
    expect(dup.first.ids, ['a', 'a-copia']);
    expect(sim.length, 1);
    expect(sim.first.bestId, 'b2');
    expect(groups.any((g) => g.ids.contains('c')), isFalse);
  });
}
