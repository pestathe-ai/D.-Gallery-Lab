import 'dart:io';

import 'package:flutter/services.dart';

/// Una categoria di file nascosti che si possono eliminare.
class HiddenCategory {
  const HiddenCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.folders,
    this.warning,
  });

  final String id;
  final String title;
  final String description;

  /// Cartelle relative alla memoria del telefono.
  final List<String> folders;

  /// Avviso mostrato prima di eliminare (se c'è un effetto collaterale).
  final String? warning;
}

const _wa = 'Android/media/com.whatsapp/WhatsApp/Media';
const _waOld = 'WhatsApp/Media';
const _wab = 'Android/media/com.whatsapp.w4b/WhatsApp Business/Media';

const hiddenCategories = [
  HiddenCategory(
    id: 'thumbs',
    title: 'Miniature della Galleria',
    description: 'Anteprime piccolissime che la Galleria ricrea da sola quando '
        'servono. Molte appartengono a foto già cancellate.',
    folders: ['DCIM/.thumbnails', 'Pictures/.thumbnails', 'Movies/.thumbnails'],
  ),
  HiddenCategory(
    id: 'wa_sent',
    title: 'Copie delle foto inviate su WhatsApp',
    description: 'Quando invii una foto, WhatsApp ne salva una copia '
        'ricompressa. L\'originale resta nella tua Galleria.',
    folders: [
      '$_wa/WhatsApp Images/Sent',
      '$_waOld/WhatsApp Images/Sent',
      '$_wab/WhatsApp Business Images/Sent',
    ],
    warning: 'Nelle chat, su questo telefono, le foto che hai inviato non si '
        'potranno più aprire. Gli originali nella Galleria non vengono toccati.',
  ),
  HiddenCategory(
    id: 'wa_status',
    title: 'Stati WhatsApp già visti',
    description: 'Copie temporanee degli stati dei tuoi contatti.',
    folders: [
      '$_wa/.Statuses',
      '$_waOld/.Statuses',
      '$_wab/.Statuses',
    ],
  ),
];

class CategoryScan {
  CategoryScan(this.category, this.files, this.bytes);
  final HiddenCategory category;
  final List<File> files;
  final int bytes;
}

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  if (b < 1024 * 1024 * 1024) {
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

/// Elenca i file di una categoria sotto [root] (la memoria del telefono).
Future<CategoryScan> scanCategory(Directory root, HiddenCategory c) async {
  final files = <File>[];
  var bytes = 0;
  for (final rel in c.folders) {
    final dir = Directory('${root.path}/$rel');
    if (!await dir.exists()) continue;
    try {
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        if (e.path.endsWith('/.nomedia')) continue; // lasciamo i marcatori
        try {
          bytes += await e.length();
          files.add(e);
        } catch (_) {}
      }
    } catch (_) {}
  }
  return CategoryScan(c, files, bytes);
}

/// Elimina i file; restituisce (eliminati, byte liberati).
Future<(int, int)> deleteFiles(List<File> files) async {
  var n = 0, bytes = 0;
  for (final f in files) {
    try {
      final len = await f.length();
      await f.delete();
      n++;
      bytes += len;
    } catch (_) {}
  }
  return (n, bytes);
}

class AllFilesAccess {
  static const _ch = MethodChannel('dgallerylab/archive');

  static Future<bool> granted() async =>
      (await _ch.invokeMethod<bool>('hasAllFiles')) ?? false;

  static Future<void> request() => _ch.invokeMethod('requestAllFiles');

  static Future<Directory?> storageRoot() async {
    final p = await _ch.invokeMethod<String>('storageRoot');
    return p == null ? null : Directory(p);
  }
}
