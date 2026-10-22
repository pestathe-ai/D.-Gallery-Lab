/// Riconosce da dove arriva un'immagine guardando cartella e nome del file.
/// (Il nome resta uguale anche dopo l'archiviazione in cartelle.)
library;

final _waName = RegExp(r'-WA\d{3,}', caseSensitive: false);

bool isWhatsApp(String? relPath, String? title) {
  final p = (relPath ?? '').toLowerCase();
  return p.contains('whatsapp') || _waName.hasMatch(title ?? '');
}

const _receivedHints = [
  'whatsapp', 'telegram', 'download', 'instagram', 'facebook', 'messenger',
  'snapchat', 'signal', 'reddit', 'twitter', 'tiktok', 'pinterest', 'viber',
];

final _telegramName = RegExp(r'^(photo|image)_\d{4}-\d{2}-\d{2}', caseSensitive: false);

/// Immagine ricevuta o scaricata (non scattata con la fotocamera).
bool isReceived(String? relPath, String? title) {
  if (isWhatsApp(relPath, title)) return true;
  final p = (relPath ?? '').toLowerCase();
  if (_receivedHints.any(p.contains)) return true;
  return _telegramName.hasMatch(title ?? '');
}

bool isScreenshot(String? relPath, String? title) {
  final p = '${relPath ?? ''}/${title ?? ''}'.toLowerCase();
  return p.contains('screenshot') || p.contains('screen_shot');
}

/// Probabile meme: immagine ricevuta con parecchio testo sopra.
/// [textChars] = caratteri letti dal riconoscimento del testo (-1 = non letto).
bool isProbableMeme({
  required bool received,
  required int textChars,
  required int width,
  required int height,
}) {
  if (!received || textChars < 0) return false;
  if (textChars >= 30) return true;
  // poco testo ma immagine piccola, tipica dei meme ricompressi
  return textChars >= 12 && width * height <= 1200 * 1200;
}
