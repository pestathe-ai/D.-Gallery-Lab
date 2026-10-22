import 'dart:io';

import 'package:d_gallery_lab/analysis/source.dart';
import 'package:d_gallery_lab/services/hidden_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('riconosce WhatsApp da cartella o nome (anche dopo l\'archiviazione)', () {
    expect(isWhatsApp('Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/', 'x.jpg'), isTrue);
    expect(isWhatsApp('Pictures/Archivio/2024/2024-03 Marzo/', 'IMG-20240301-WA0012.jpg'), isTrue);
    expect(isWhatsApp('DCIM/Camera/', 'IMG_20240301_101010.jpg'), isFalse);
  });

  test('immagini ricevute', () {
    expect(isReceived('Pictures/Telegram/', 'a.jpg'), isTrue);
    expect(isReceived('Download/', 'meme.png'), isTrue);
    expect(isReceived('Pictures/Archivio/2023/2023-01 Gennaio/', 'photo_2023-01-05_10-00-00.jpg'), isTrue);
    expect(isReceived('DCIM/Camera/', 'PXL_20240101.jpg'), isFalse);
  });

  test('probabile meme', () {
    expect(isProbableMeme(received: true, textChars: 60, width: 1080, height: 1080), isTrue);
    expect(isProbableMeme(received: true, textChars: 15, width: 720, height: 720), isTrue);
    expect(isProbableMeme(received: true, textChars: 15, width: 4000, height: 3000), isFalse);
    expect(isProbableMeme(received: false, textChars: 200, width: 720, height: 720), isFalse);
    expect(isProbableMeme(received: true, textChars: -1, width: 720, height: 720), isFalse);
  });

  test('file nascosti: trova, somma ed elimina (lascia .nomedia)', () async {
    final root = await Directory.systemTemp.createTemp('dgl');
    final thumbs = Directory('${root.path}/DCIM/.thumbnails')..createSync(recursive: true);
    File('${thumbs.path}/1.jpg').writeAsBytesSync(List.filled(100, 1));
    File('${thumbs.path}/2.jpg').writeAsBytesSync(List.filled(50, 1));
    File('${thumbs.path}/.nomedia').writeAsStringSync('');
    final c = hiddenCategories.firstWhere((c) => c.id == 'thumbs');
    final scan = await scanCategory(root, c);
    expect(scan.files.length, 2);
    expect(scan.bytes, 150);
    final (n, bytes) = await deleteFiles(scan.files);
    expect(n, 2);
    expect(bytes, 150);
    expect(File('${thumbs.path}/.nomedia').existsSync(), isTrue);
    expect((await scanCategory(root, c)).files, isEmpty);
    await root.delete(recursive: true);
  });

  test('dimensioni leggibili', () {
    expect(formatBytes(500), '500 B');
    expect(formatBytes(2048), '2 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
  });
}
