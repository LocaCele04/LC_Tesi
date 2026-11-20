import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/catalogo/caratteristica.dart';
import '../../models/catalogo/condizione.dart';
import '../../models/catalogo/esca.dart';
import '../../models/catalogo/specie.dart';
import 'dipendenze.dart';

// Dati del catalogo usati dai moduli (esche, specie, caratteristiche,
// condizioni). Sono letture: chi modifica il catalogo invalida il provider
// corrispondente.

/// Tutte le esche in ordine alfabetico.
final escheProvider = FutureProvider<List<Esca>>(
  (ref) => ref.watch(catalogoRepositoryProvider).getEsche(),
);

/// Tutte le specie in ordine alfabetico, con l'aggiunta di una specie nuova
/// direttamente dal modulo della pescata.
final specieProvider = AsyncNotifierProvider<SpecieNotifier, List<Specie>>(
  SpecieNotifier.new,
);

class SpecieNotifier extends AsyncNotifier<List<Specie>> {
  @override
  Future<List<Specie>> build() => ref.watch(catalogoRepositoryProvider).getSpecie();

  /// Aggiunge la specie [nome] al catalogo e restituisce il nome salvato.
  Future<String> aggiungi(String nome) async {
    final pulito = nome.trim();
    await ref.read(catalogoRepositoryProvider).inserisciSpecie(Specie(nome: pulito));
    ref.invalidateSelf();
    await future;
    return pulito;
  }
}

/// Caratteristiche di una specie (es. "Over 30" per la trota).
final caratteristicheProvider = FutureProvider.family<List<Caratteristica>, String>(
  (ref, specieNome) =>
      ref.watch(catalogoRepositoryProvider).getCaratteristiche(specieNome: specieNome),
);

/// Condizioni da compilare nel modulo di una pescata in uno spot di
/// `ambiente`, con i loro valori attivi. Per una pescata già salvata
/// (`pescataId`) ci sono anche le condizioni e i valori che usa, se nel
/// frattempo sono stati disattivati o scollegati dall'ambiente.
final condizioniPerFormProvider = FutureProvider.autoDispose
    .family<List<Condizione>, ({String ambiente, int? pescataId})>(
  (ref, richiesta) => ref.watch(catalogoRepositoryProvider).getCondizioniPerForm(
        ambienteNome: richiesta.ambiente,
        pescataId: richiesta.pescataId,
      ),
);

/// Nome di ogni condizione, per id: serve a mostrare "Livello: Morbida"
/// partendo dal solo valore salvato nella pescata.
final nomiCondizioniProvider = FutureProvider<Map<int, String>>((ref) async {
  final condizioni = await ref.watch(catalogoRepositoryProvider).getCondizioni();
  return {for (final c in condizioni) c.id!: c.nome};
});
