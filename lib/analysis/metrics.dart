import 'dart:math' as math;
import 'dart:typed_data';

/// Immagine in scala di grigi (0-255), riga per riga.
class GrayImage {
  GrayImage(this.width, this.height, this.pixels)
      : assert(pixels.length == width * height);

  final int width;
  final int height;
  final Uint8List pixels;

  int at(int x, int y) => pixels[y * width + x];

  /// Converte dati RGBA (4 byte per pixel) in grigio (luminanza Rec. 601).
  factory GrayImage.fromRgba(Uint8List rgba, int width, int height) {
    final out = Uint8List(width * height);
    for (var i = 0, p = 0; i < out.length; i++, p += 4) {
      out[i] = ((rgba[p] * 299 + rgba[p + 1] * 587 + rgba[p + 2] * 114) ~/ 1000)
          .clamp(0, 255);
    }
    return GrayImage(width, height, out);
  }

  /// Ridimensiona facendo la media delle aree (adatto a ridurre).
  GrayImage resize(int w, int h) {
    final out = Uint8List(w * h);
    for (var ty = 0; ty < h; ty++) {
      final y0 = ty * height ~/ h;
      final y1 = math.max(y0 + 1, (ty + 1) * height ~/ h);
      for (var tx = 0; tx < w; tx++) {
        final x0 = tx * width ~/ w;
        final x1 = math.max(x0 + 1, (tx + 1) * width ~/ w);
        var sum = 0;
        var n = 0;
        for (var y = y0; y < y1 && y < height; y++) {
          for (var x = x0; x < x1 && x < width; x++) {
            sum += pixels[y * width + x];
            n++;
          }
        }
        out[ty * w + tx] = n == 0 ? 0 : sum ~/ n;
      }
    }
    return GrayImage(w, h, out);
  }
}

/// Hash percettivo "a differenza" (dHash) a 64 bit.
/// Foto identiche o quasi danno hash uguali o con pochi bit diversi.
int dHash(GrayImage img) {
  final s = img.resize(9, 8);
  var hash = 0;
  var bit = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      if (s.at(x, y) > s.at(x + 1, y)) hash |= (1 << bit);
      bit++;
    }
  }
  return hash;
}

final Uint8List _popTable = () {
  final t = Uint8List(256);
  for (var i = 0; i < 256; i++) {
    var c = 0;
    var v = i;
    while (v != 0) {
      c += v & 1;
      v >>= 1;
    }
    t[i] = c;
  }
  return t;
}();

/// Numero di bit diversi tra due hash (0 = identici, 64 = opposti).
int hammingDistance(int a, int b) {
  var x = a ^ b;
  var c = 0;
  for (var i = 0; i < 8; i++) {
    c += _popTable[x & 0xff];
    x = x >>> 8;
  }
  return c;
}

/// Varianza del Laplaciano: alta = nitida, bassa = sfocata.
double laplacianVariance(GrayImage img) {
  final w = img.width, h = img.height;
  if (w < 3 || h < 3) return 0;
  var sum = 0.0, sumSq = 0.0;
  var n = 0;
  final p = img.pixels;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final v = p[i - w] + p[i + w] + p[i - 1] + p[i + 1] - 4 * p[i];
      sum += v;
      sumSq += v * v;
      n++;
    }
  }
  final mean = sum / n;
  return sumSq / n - mean * mean;
}

class QualityReport {
  const QualityReport({
    required this.sharpness,
    required this.brightness,
    required this.darkFraction,
    required this.brightFraction,
  });

  /// Varianza del Laplaciano sulla miniatura.
  final double sharpness;

  /// Luminosità media 0-255.
  final double brightness;

  /// Quota di pixel quasi neri / quasi bianchi.
  final double darkFraction;
  final double brightFraction;

  /// 0..1: quanto è nitida (scala logaritmica, ~1000 = pienamente nitida).
  double get sharpnessScore =>
      (math.log(sharpness + 1) / math.log(1001)).clamp(0.0, 1.0);

  /// 0..1: quanto è ben esposta.
  double get exposureScore {
    final centre = 1 - ((brightness - 125).abs() / 125).clamp(0.0, 1.0);
    final clip = (darkFraction + brightFraction).clamp(0.0, 1.0);
    return (centre * 0.6 + (1 - clip) * 0.4).clamp(0.0, 1.0);
  }

  /// Punteggio complessivo 0-100.
  int get score => ((sharpnessScore * 0.65 + exposureScore * 0.35) * 100).round();

  bool isBlurry(double threshold) => sharpness < threshold;
  bool get isDark => brightness < 45 || darkFraction > 0.6;
  bool get isOverexposed => brightness > 215 || brightFraction > 0.5;
}

QualityReport analyzeQuality(GrayImage img) {
  var sum = 0;
  var dark = 0, bright = 0;
  for (final v in img.pixels) {
    sum += v;
    if (v < 20) dark++;
    if (v > 240) bright++;
  }
  final n = img.pixels.length;
  return QualityReport(
    sharpness: laplacianVariance(img),
    brightness: sum / n,
    darkFraction: dark / n,
    brightFraction: bright / n,
  );
}
