import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/territorio/ambiente.dart';
import '../../models/territorio/categoria.dart';
import '../../models/territorio/spot.dart';
import 'dipendenze.dart';
import 'pescate_state.dart';

// Stato dell'interfaccia per gli spot. È l'esempio di riferimento per le
// altre aree (pescate, catalogo, obiettivi), che seguono lo stesso schema:
//
// * **letture**: un provider asincrono che carica i dati dal repository;
//   le schermate lo osservano e mostrano caricamento, errore o dati;
// * **scritture**: metodi del notifier che chiamano il repository e poi
//   invalidano i provider i cui dati sono cambiati, che si ricaricano da
//   soli. Un errore di scrittura viene rilanciato a chi ha chiamato il
//   metodo (di solito un modulo, che mostra il messaggio) e lo stato
//   già caricato resta com'era.

/// Elenco di tutti gli spot in ordine alfabetico, senza coordinate.
final elencoSpotProvider = AsyncNotifierProvider<ElencoSpotNotifier, List<Spot>>(
  ElencoSpotNotifier.new,
);

class ElencoSpotNotifier extends AsyncNotifier<List<Spot>> {
  @override
  Future<List<Spot>> build() => ref.watch(territorioRepositoryProvider).getSpots();

  /// Inserisce uno spot nuovo ([nomeOriginale] nullo) o aggiorna quello che
  /// si chiamava [nomeOriginale], con le sue coordinate. Al termine elenco e
  /// dettagli sono già aggiornati.
  Future<void> salva(Spot spot, {String? nomeOriginale}) async {
    await ref
        .read(territorioRepositoryProvider)
        .salvaSpotConCoordinate(spot, nomeOriginale: nomeOriginale);
    await _ricarica();
  }

  /// Elimina lo spot [nome]. Le sue pescate restano, senza spot.
  Future<void> elimina(String nome) async {
    await ref.read(territorioRepositoryProvider).eliminaSpot(nome);
    await _ricarica();
  }

  /// Invalida i provider che dipendono dagli spot e attende il nuovo elenco.
  /// Anche le pescate si ricaricano: rinominare o eliminare uno spot cambia
  /// le pescate collegate.
  Future<void> _ricarica() async {
    ref.invalidate(dettaglioSpotProvider);
    ref.invalidate(elencoPescateProvider);
    ref.invalidateSelf();
    await future;
  }
}

/// Dettaglio di uno spot con le coordinate ordinate, `null` se non esiste.
/// Viene eliminato quando nessuna schermata lo usa più (`autoDispose`).
final dettaglioSpotProvider = FutureProvider.autoDispose.family<Spot?, String>(
  (ref, nome) => ref.watch(territorioRepositoryProvider).getSpotConCoordinate(nome),
);

/// Categorie e ambienti per i filtri e per il modulo dello spot.
final categorieProvider = FutureProvider<List<Categoria>>(
  (ref) => ref.watch(territorioRepositoryProvider).getCategorie(),
);

final ambientiProvider = FutureProvider<List<Ambiente>>(
  (ref) => ref.watch(territorioRepositoryProvider).getAmbienti(),
);
