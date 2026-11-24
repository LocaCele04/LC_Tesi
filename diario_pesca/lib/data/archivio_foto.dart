import 'dart:io';

/// Accesso ai file immagine sul file system del dispositivo.
///
/// È la seconda sorgente dati dell'app, accanto al database SQLite: il
/// database conserva solo i percorsi delle foto (REQ-DES-03), i file veri
/// stanno sul disco. I repository usano questa classe per cancellare i file
/// rimasti senza riferimento dopo una modifica o un'eliminazione, sempre
/// dopo il commit della transazione, così un errore nel database non fa
/// perdere foto ancora referenziate.
///
/// Acquisizione, compressione, generazione delle anteprime e risoluzione dei
/// percorsi relativi alla cartella documenti dell'app spettano al futuro
/// `FotoService` (livello servizi), che userà questa classe per scrivere.
class ArchivioFoto {
  const ArchivioFoto();

  /// Elimina i file indicati. File già assenti o percorsi non validi
  /// (es. percorsi fittizi nei test) vengono ignorati.
  Future<void> eliminaFile(Iterable<String> percorsi) async {
    for (final percorso in percorsi) {
      try {
        final file = File(percorso);
        if (await file.exists()) {
          await file.delete();
        }
      } on FileSystemException {
        // File già rimosso o non accessibile: nulla da fare.
      }
    }
  }
}
