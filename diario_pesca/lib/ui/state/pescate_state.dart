import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/meteo/meteo_pescata.dart';
import '../../models/pescate/pescata.dart';
import '../../services/meteo_service.dart';
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
  /// lo spot diventa *battuto*, un'esca scritta al momento entra nel catalogo,
  /// e se cambiano data o spot cambia anche il meteo della pescata.
  Future<Pescata> salva(Pescata pescata) async {
    final salvata = await ref.read(pescateRepositoryProvider).salvaPescata(pescata);
    _datiCambiati();
    await future;
    return salvata;
  }

  /// Elimina la pescata [id]; lo spot può tornare *non battuto*.
  Future<void> elimina(int id) async {
    await ref.read(pescateRepositoryProvider).eliminaPescata(id);
    _datiCambiati();
    await future;
  }

  void _datiCambiati() {
    ref.invalidate(elencoSpotProvider);
    ref.invalidate(dettaglioSpotProvider);
    ref.invalidate(escheProvider);
    ref.invalidate(specieProvider);
    ref.invalidate(dettaglioPescataProvider);
    ref.invalidate(meteoPescataProvider);
    ref.invalidate(pioggiaCumulataProvider);
    ref.invalidateSelf();
  }
}

/// Totale delle catture di ogni pescata, per id (le pescate senza catture
/// non ci sono). Dipende dall'elenco: si ricalcola da solo quando l'elenco
/// viene ricaricato dopo un salvataggio o un'eliminazione.
final totaliCattureProvider = FutureProvider<Map<int, int>>((ref) async {
  await ref.watch(elencoPescateProvider.future);
  return ref.watch(pescateRepositoryProvider).getTotaliCatture();
});

/// Id delle pescate il cui meteo è ancora da scaricare. Si ricalcola con
/// l'elenco e dopo ogni aggiornamento del meteo.
final pescateSenzaMeteoProvider = FutureProvider<Set<int>>((ref) async {
  await ref.watch(elencoPescateProvider.future);
  final richieste = await ref.watch(meteoRepositoryProvider).getPescateDaScaricare();
  return {for (final r in richieste) r.pescataId};
});

/// Pescata completa (condizioni, esche, foto, catture), `null` se non esiste.
final dettaglioPescataProvider = FutureProvider.autoDispose.family<Pescata?, int>(
  (ref, id) => ref.watch(pescateRepositoryProvider).getPescataCompleta(id),
);

/// Dati meteo di una pescata con il loro stato (da scaricare, scaricato,
/// non disponibile).
final meteoPescataProvider = FutureProvider.autoDispose.family<MeteoPescata, int>(
  (ref, id) => ref.watch(meteoRepositoryProvider).getMeteoPescata(id),
);

/// Pioggia caduta nei `giorni` giorni prima della pescata, `null` se il
/// meteo non è scaricato.
final pioggiaCumulataProvider =
    FutureProvider.autoDispose.family<double?, ({int pescataId, int giorni})>(
  (ref, richiesta) => ref
      .watch(statisticheServiceProvider)
      .getPioggiaCumulata(richiesta.pescataId, giorni: richiesta.giorni),
);

/// Scaricamento del meteo storico delle pescate. Lo stato è l'esito
/// dell'ultimo aggiornamento (`null` se non ne è ancora stato fatto uno):
/// mentre scarica è in caricamento, così l'interfaccia può mostrarlo.
final aggiornamentoMeteoProvider =
    AsyncNotifierProvider<AggiornamentoMeteoNotifier, EsitoAggiornamentoMeteo?>(
  AggiornamentoMeteoNotifier.new,
);

class AggiornamentoMeteoNotifier extends AsyncNotifier<EsitoAggiornamentoMeteo?> {
  bool _inCorso = false;

  // Valore sincrono: all'apertura non c'è nulla da caricare.
  @override
  FutureOr<EsitoAggiornamentoMeteo?> build() => null;

  /// Scarica il meteo di tutte le pescate passate che non l'hanno ancora e
  /// restituisce l'esito; un errore imprevisto viene rilanciato. Non fa nulla
  /// (e restituisce `null`) se un aggiornamento è già in corso.
  Future<EsitoAggiornamentoMeteo?> aggiorna() async {
    if (_inCorso) return null;
    _inCorso = true;
    state = const AsyncLoading<EsitoAggiornamentoMeteo?>();
    try {
      final esito = await AsyncValue.guard(
        () => ref.read(meteoServiceProvider).aggiornaStorico(),
      );
      ref.invalidate(pescateSenzaMeteoProvider);
      ref.invalidate(meteoPescataProvider);
      ref.invalidate(pioggiaCumulataProvider);
      state = esito;
      return esito.requireValue;
    } finally {
      _inCorso = false;
    }
  }
}
