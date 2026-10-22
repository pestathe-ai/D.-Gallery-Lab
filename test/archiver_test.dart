import 'package:d_gallery_lab/services/archiver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('percorso con anno e mese nell\'ultima cartella', () {
    expect(archivePathFor(DateTime(2024, 3, 15)),
        'Pictures/Archivio/2024/2024-03 Marzo/');
    expect(archivePathFor(DateTime(2025, 12, 1)),
        'Pictures/Archivio/2025/2025-12 Dicembre/');
  });

  test('pianificazione: salta le foto già al posto giusto', () {
    final moves = planMoves([
      (id: '1', relPath: 'DCIM/Camera/', taken: DateTime(2024, 3, 1)),
      (id: '2', relPath: 'Pictures/Archivio/2024/2024-03 Marzo', taken: DateTime(2024, 3, 2)),
      (id: '3', relPath: 'Pictures/WhatsApp Images/', taken: DateTime(2023, 1, 5)),
    ]);
    expect(moves.map((m) => m.id), ['1', '3']);
    expect(moves.last.to, 'Pictures/Archivio/2023/2023-01 Gennaio/');
  });

  test('pianificazione: solo dalle cartelle scelte', () {
    final moves = planMoves([
      (id: '1', relPath: 'DCIM/Camera/', taken: DateTime(2024, 3, 1)),
      (id: '3', relPath: 'Pictures/WhatsApp Images/', taken: DateTime(2023, 1, 5)),
    ], onlyFromFolders: {'DCIM/Camera/'});
    expect(moves.map((m) => m.id), ['1']);
    expect(folderLabel('DCIM/Camera/'), 'DCIM/Camera');
  });
}
