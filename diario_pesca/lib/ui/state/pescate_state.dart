import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pescate/pescata.dart';
import 'catalogo_state.dart';
import 'dipendenze.dart';
import 'spot_state.dart';

/// Elenco delle pescate (dalla più recente) con le operazioni di modifica.
/// Segue lo schema di `spot_state.dart`.
final elencoPescateProvider = AsyncNotifierProvider<ElencoPescateNotifier, List<Pescata>>(
  ElencoPescateNotifier.new,
);

class ElencoPescateNotifier extends AsyncNotifier<List<Pescata>> {
  @override
  Future<List<Pescata>> build() => ref.watch(pescateRepositoryProvider).getPescate();

  /// Salva (inserisce o aggiorna) una pescata con condizioni, esche e
  /// catture e restituisce la pescata salvata, con gli id assegnati.
  ///
  /// Salvare una pescata cambia anche altri dati, che vengono ricaricati:
  /// lo spot diventa *battuto* e un'esca scritta al momento entra nel catalogo.
  Future<Pescata> salva(Pescata pescata) async {
    final salvata = await ref.read(pescateRepositoryProvider).salvaPescata(pescata);
    ref.invalidate(elencoSpotProvider);
    ref.invalidate(dettaglioSpotProvider);
    ref.invalidate(escheProvider);
    ref.invalidateSelf();
    await future;
    return salvata;
  }

  /// Elimina la pescata [id]; lo spot può tornare *non battuto*.
  Future<void> elimina(int id) async {
    await ref.read(pescateRepositoryProvider).eliminaPescata(id);
    ref.invalidate(elencoSpotProvider);
    ref.invalidate(dettaglioSpotProvider);
    ref.invalidateSelf();
    await future;
  }
}
