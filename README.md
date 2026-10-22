# D. Gallery Lab

App Android per mettere ordine nella galleria. Tutto avviene sul telefono, offline.

## Cosa fa (v0.1)
- **Duplicati**: trova copie della stessa foto (anche ricompresse o ridimensionate, es. da WhatsApp).
- **Scatti simili**: raggruppa raffiche scattate a pochi minuti di distanza e suggerisce la migliore (stella).
- **Foto venute male**: sfocate (sensibilità regolabile), troppo scure, bruciate.
- **Punteggio qualità 0-100** per ogni foto (nitidezza + esposizione).
- **Archivio Anno / Mese** con qualità media del mese e ordinamento "migliori prima".
- Eliminazione solo dopo conferma: su Android 11+ le foto vanno nel **cestino** (recuperabili ~30 giorni).

## Novità v0.3.1
- Nuova icona Dom Studio (con versione a un colore per le icone a tema di Android).

## Novità v0.3
- **Archivia in cartelle**: sposta davvero le foto in `Pictures/Archivio/<anno>/<anno>-<mese> <Nome>/` (Android 11+). Nulla viene cancellato; scegli da quali cartelle prendere le foto. Una conferma di sistema ogni 300 foto, oppure nessuna attivando "Gestione contenuti multimediali".

## Novità v0.2
- L'analisi viene salvata: alle aperture successive si ricarica subito e vengono analizzate solo le foto nuove o modificate.

## Limiti
- Il punteggio si basa su nitidezza ed esposizione, non su un'intelligenza artificiale "estetica".
- L'archiviazione in cartelle richiede Android 11 o successivo.
- La prima analisi, con molte migliaia di foto, richiede qualche minuto.
- Android chiede una conferma di sistema a ogni eliminazione.
