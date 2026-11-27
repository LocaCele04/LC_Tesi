import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/territorio/divieto.dart';
import '../../models/territorio/spot.dart';
import '../mappa/colori_mappa.dart';
import 'dipendenze.dart';
import 'memoria_ui.dart';
import 'spot_state.dart';

// Stato della mappa: cosa disegnare (spot con i loro punti, divieti) e
// come (colorazione, filtri, mappa di sfondo).

/// Tutti gli spot con le loro coordinate, per la mappa. Dipende
/// dall'elenco degli spot, che si ricarica dopo ogni salvataggio o
/// eliminazione di uno spot e dopo ogni pescata (lo stato *battuto*
/// cambia): la mappa segue da sola.
final spotSullaMappaProvider = FutureProvider<List<Spot>>((ref) async {
  final spot = await ref.watch(elencoSpotProvider.future);
  final coordinate = await ref.watch(territorioRepositoryProvider).getTutteLeCoordinate();
  return [
    for (final s in spot) s.copyWith(coordinate: coordinate[s.nome] ?? const []),
  ];
});

/// Divieti con i loro punti e le operazioni di modifica.
final divietiProvider = AsyncNotifierProvider<DivietiNotifier, List<Divieto>>(
  DivietiNotifier.new,
);

class DivietiNotifier extends AsyncNotifier<List<Divieto>> {
  @override
  Future<List<Divieto>> build() => ref.watch(territorioRepositoryProvider).getDivieti();

  /// Inserisce o aggiorna un divieto e restituisce quello salvato.
  /// Un errore (es. nessun punto) viene rilanciato e l'elenco resta com'era.
  Future<Divieto> salva(Divieto divieto) async {
    final salvato = await ref.read(territorioRepositoryProvider).salvaDivieto(divieto);
    ref.invalidateSelf();
    await future;
    return salvato;
  }

  Future<void> elimina(int id) async {
    await ref.read(territorioRepositoryProvider).eliminaDivieto(id);
    ref.invalidateSelf();
    await future;
  }
}

/// Mappa di sfondo. La prima è quella predefinita.
enum Sfondo {
  stradale('Stradale (OpenStreetMap)'),
  topografica('Topografica (OpenTopoMap)');

  const Sfondo(this.etichetta);
  final String etichetta;
}

/// Quali spot mostrare in base allo stato *battuto*.
enum FiltroStato {
  tutti('Tutti'),
  battuti('Solo quelli dove ho pescato'),
  nonBattuti('Solo quelli mai pescati');

  const FiltroStato(this.etichetta);
  final String etichetta;
}

/// Come si presenta la mappa: colorazione, sfondo e filtri. Ambienti e
/// categorie si filtrano per *esclusione* (insiemi vuoti = tutti visibili),
/// così un ambiente o una categoria creati dopo sono visibili senza
/// doverli attivare.
class VistaMappa {
  const VistaMappa({
    this.colorazione = Colorazione.voto,
    this.sfondo = Sfondo.stradale,
    this.stato = FiltroStato.tutti,
    this.ambientiNascosti = const {},
    this.categorieNascoste = const {},
    this.mostraDivieti = true,
  });

  final Colorazione colorazione;
  final Sfondo sfondo;
  final FiltroStato stato;

  /// Nomi in minuscolo.
  final Set<String> ambientiNascosti;
  final Set<String> categorieNascoste;
  final bool mostraDivieti;

  /// `true` se qualche filtro nasconde degli spot o i divieti.
  bool get filtriAttivi =>
      stato != FiltroStato.tutti ||
      ambientiNascosti.isNotEmpty ||
      categorieNascoste.isNotEmpty ||
      !mostraDivieti;

  bool mostra(Spot spot) {
    if (stato == FiltroStato.battuti && !spot.battuto) return false;
    if (stato == FiltroStato.nonBattuti && spot.battuto) return false;
    if (ambientiNascosti.contains(spot.ambiente.toLowerCase())) return false;
    if (categorieNascoste.contains(spot.categoriaNome.toLowerCase())) return false;
    return true;
  }

  VistaMappa copyWith({
    Colorazione? colorazione,
    Sfondo? sfondo,
    FiltroStato? stato,
    Set<String>? ambientiNascosti,
    Set<String>? categorieNascoste,
    bool? mostraDivieti,
  }) {
    return VistaMappa(
      colorazione: colorazione ?? this.colorazione,
      sfondo: sfondo ?? this.sfondo,
      stato: stato ?? this.stato,
      ambientiNascosti: ambientiNascosti ?? this.ambientiNascosti,
      categorieNascoste: categorieNascoste ?? this.categorieNascoste,
      mostraDivieti: mostraDivieti ?? this.mostraDivieti,
    );
  }
}

/// Vista della mappa scelta dall'utente. Sfondo e colorazione si ricordano
/// anche dopo la chiusura dell'app (vedi [MemoriaUi]); i filtri valgono
/// finché l'app è aperta.
final vistaMappaProvider = NotifierProvider<VistaMappaNotifier, VistaMappa>(
  VistaMappaNotifier.new,
);

class VistaMappaNotifier extends Notifier<VistaMappa> {
  MemoriaUi get _memoria => ref.read(memoriaUiProvider);

  @override
  VistaMappa build() {
    final memoria = ref.read(memoriaUiProvider);
    return VistaMappa(
      colorazione: enumDaMemoria(memoria, ChiaviMemoria.colorazione, Colorazione.values) ?? Colorazione.voto,
      sfondo: enumDaMemoria(memoria, ChiaviMemoria.sfondo, Sfondo.values) ?? Sfondo.stradale,
    );
  }

  void impostaColorazione(Colorazione c) {
    state = state.copyWith(colorazione: c);
    _memoria.scrivi(ChiaviMemoria.colorazione, c.name);
  }

  void impostaSfondo(Sfondo s) {
    state = state.copyWith(sfondo: s);
    _memoria.scrivi(ChiaviMemoria.sfondo, s.name);
  }

  void impostaStato(FiltroStato f) => state = state.copyWith(stato: f);

  void impostaMostraDivieti(bool mostra) => state = state.copyWith(mostraDivieti: mostra);

  void mostraAmbiente(String ambiente, bool visibile) => state = state.copyWith(
        ambientiNascosti: _alterna(state.ambientiNascosti, ambiente, visibile),
      );

  void mostraCategoria(String categoria, bool visibile) => state = state.copyWith(
        categorieNascoste: _alterna(state.categorieNascoste, categoria, visibile),
      );

  /// Toglie tutti i filtri; colorazione e sfondo restano.
  void azzeraFiltri() => state = VistaMappa(colorazione: state.colorazione, sfondo: state.sfondo);

  static Set<String> _alterna(Set<String> nascosti, String nome, bool visibile) {
    final chiave = nome.toLowerCase();
    return visibile ? ({...nascosti}..remove(chiave)) : {...nascosti, chiave};
  }
}
