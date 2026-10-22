import 'metrics.dart';

/// Dati minimi di una foto analizzata (solo tipi semplici: passa tra isolate).
class PhotoInfo {
  const PhotoInfo({
    required this.id,
    required this.hash,
    required this.score,
    required this.width,
    required this.height,
    required this.takenMs,
  });

  final String id;
  final int hash;
  final int score;
  final int width;
  final int height;
  final int takenMs;

  int get pixels => width * height;
}

enum GroupKind { duplicate, similar }

class PhotoGroup {
  PhotoGroup(this.kind, this.ids, this.bestId);

  final GroupKind kind;

  /// Ordinati dal migliore al peggiore.
  final List<String> ids;
  final String bestId;
}

class _UnionFind {
  _UnionFind(int n) : parent = List<int>.generate(n, (i) => i);
  final List<int> parent;

  int find(int i) {
    while (parent[i] != i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  }

  void union(int a, int b) {
    final ra = find(a), rb = find(b);
    if (ra != rb) parent[rb] = ra;
  }
}

/// Confronto: prima il punteggio, poi la risoluzione, poi la più vecchia
/// (di solito l'originale, le copie arrivano dopo).
int comparePhotos(PhotoInfo a, PhotoInfo b) {
  if (a.score != b.score) return b.score.compareTo(a.score);
  if (a.pixels != b.pixels) return b.pixels.compareTo(a.pixels);
  return a.takenMs.compareTo(b.takenMs);
}

/// Raggruppa le foto.
/// - duplicati: distanza hash <= [duplicateMax] (ovunque nella galleria);
/// - simili: distanza <= [similarMax] e scattate entro [similarWindowMs].
List<PhotoGroup> groupPhotos(
  List<PhotoInfo> photos, {
  int duplicateMax = 2,
  int similarMax = 10,
  int similarWindowMs = 10 * 60 * 1000,
}) {
  final n = photos.length;
  final dup = _UnionFind(n);
  final sim = _UnionFind(n);

  for (var i = 0; i < n; i++) {
    final a = photos[i];
    for (var j = i + 1; j < n; j++) {
      final b = photos[j];
      final d = hammingDistance(a.hash, b.hash);
      if (d <= duplicateMax) {
        dup.union(i, j);
      } else if (d <= similarMax &&
          (a.takenMs - b.takenMs).abs() <= similarWindowMs) {
        sim.union(i, j);
      }
    }
  }

  final result = <PhotoGroup>[];
  final inDuplicate = <int>{};

  Map<int, List<int>> collect(_UnionFind uf, Set<int> skip) {
    final m = <int, List<int>>{};
    for (var i = 0; i < n; i++) {
      if (skip.contains(i)) continue;
      m.putIfAbsent(uf.find(i), () => []).add(i);
    }
    m.removeWhere((_, v) => v.length < 2);
    return m;
  }

  for (final members in collect(dup, const {}).values) {
    inDuplicate.addAll(members);
    final list = members.map((i) => photos[i]).toList()..sort(comparePhotos);
    result.add(PhotoGroup(
        GroupKind.duplicate, list.map((p) => p.id).toList(), list.first.id));
  }

  // Le foto già in un gruppo di duplicati: nei simili resta solo la migliore.
  final dupLosers = <int>{};
  for (final g in result) {
    for (final id in g.ids.skip(1)) {
      dupLosers.add(photos.indexWhere((p) => p.id == id));
    }
  }
  // Fonde i simili passando per i duplicati
  for (final members in collect(dup, const {}).values) {
    for (final m in members.skip(1)) {
      sim.union(members.first, m);
    }
  }
  for (final members in collect(sim, dupLosers).values) {
    final list = members.map((i) => photos[i]).toList()..sort(comparePhotos);
    result.add(PhotoGroup(
        GroupKind.similar, list.map((p) => p.id).toList(), list.first.id));
  }

  result.sort((a, b) => b.ids.length.compareTo(a.ids.length));
  return result;
}
