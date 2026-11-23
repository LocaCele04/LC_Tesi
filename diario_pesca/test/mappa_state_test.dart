import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/pescate/pescata.dart';
import 'package:diario_pesca/models/territorio/categoria.dart';
import 'package:diario_pesca/models/territorio/coordinata.dart';
import 'package:diario_pesca/models/territorio/divieto.dart';
import 'package:diario_pesca/models/territorio/spot.dart';
import 'package:diario_pesca/ui/mappa/colori_mappa.dart';
import 'package:diario_pesca/ui/state/dipendenze.dart';
import 'package:diario_pesca/ui/state/mappa_state.dart';
import 'package:diario_pesca/ui/state/pescate_state.dart';
import 'package:diario_pesca/ui/state/spot_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late ProviderContainer container;

  const p1 = Coordinata(ordine: 0, latitudine: 45.76, longitudine: 9.64);
  const p2 = Coordinata(ordine: 1, latitudine: 45.77, longitudine: 9.65);

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    container = ProviderContainer.test(
      overrides: [databaseHelperProvider.overrideWith((ref) => dbHelper)],
      retry: (tentativo, errore) => null,
    );
    await container.read(territorioRepositoryProvider).inserisciCategoria(const Categoria(nome: 'Valle'));
    // La mappa resta aperta per tutto il test
    container.listen(spotSullaMappaProvider, (_, _) {});
    container.listen(divietiProvider, (_, _) {});
  });

  tearDown(() async {
    await dbHelper.close();
  });

  Spot spot(String nome, {String ambiente = 'Torrente', String categoria = 'Valle', List<Coordinata> punti = const []}) =>
      Spot(nome: nome, ambiente: ambiente, categoriaNome: categoria, coordinate: punti);

  group('Stato della mappa - Dati', () {
    test('gli spot sulla mappa hanno i loro punti e seguono salvataggi, pescate ed eliminazioni', () async {
      await container.read(elencoSpotProvider.notifier).salva(spot('Valsecca', punti: [p1, p2]));
      await container.read(elencoSpotProvider.notifier).salva(spot('Lenna'));

      var mappa = await container.read(spotSullaMappaProvider.future);
      expect(mappa.map((s) => s.nome), ['Lenna', 'Valsecca']);
      expect(mappa.last.coordinate.map((c) => c.latitudine), [45.76, 45.77]);
      expect(mappa.first.coordinate, isEmpty);
      expect(mappa.last.battuto, isFalse);

      // Una pescata rende lo spot battuto: il colore della mappa cambia da solo
      await container.read(elencoPescateProvider.notifier).salva(
            Pescata(data: DateTime(2026, 2, 10), fasciaOraria: FasciaOraria.alba, spotNome: 'Valsecca'),
          );
      mappa = await container.read(spotSullaMappaProvider.future);
      final valsecca = mappa.firstWhere((s) => s.nome == 'Valsecca');
      expect(coloreSpot(valsecca, Colorazione.stato), coloreBattuto);

      await container.read(elencoSpotProvider.notifier).elimina('Valsecca');
      mappa = await container.read(spotSullaMappaProvider.future);
      expect(mappa.map((s) => s.nome), ['Lenna']);
    });

    test('i divieti si salvano, si aggiornano e si eliminano; un errore lascia l\'elenco com\'era', () async {
      final divieti = container.read(divietiProvider.notifier);
      expect(await container.read(divietiProvider.future), isEmpty);

      final salvato = await divieti.salva(const Divieto(nome: 'Divieto incubatoio', coordinate: [p1, p2]));
      expect((await container.read(divietiProvider.future)).single.id, salvato.id);

      await divieti.salva(salvato.copyWith(nome: 'Divieto per frane'));
      expect((await container.read(divietiProvider.future)).single.nome, 'Divieto per frane');

      await expectLater(divieti.salva(const Divieto(nome: 'Senza punti')), throwsArgumentError);
      expect(container.read(divietiProvider).value, hasLength(1));

      await divieti.elimina(salvato.id!);
      expect(await container.read(divietiProvider.future), isEmpty);
      // I divieti non sono spot
      expect(await container.read(spotSullaMappaProvider.future), isEmpty);
    });
  });

  group('Stato della mappa - Vista', () {
    test('i filtri per stato, ambiente e categoria si combinano e si azzerano', () {
      final vista = container.read(vistaMappaProvider.notifier);
      final torrente = spot('A');
      final lago = spot('B', ambiente: 'Lago', categoria: 'Laghi');
      final battuto = Spot(nome: 'C', ambiente: 'Torrente', categoriaNome: 'Valle', battuto: true);

      VistaMappa v() => container.read(vistaMappaProvider);
      expect(v().filtriAttivi, isFalse);
      expect([torrente, lago, battuto].where(v().mostra), hasLength(3));

      vista.mostraAmbiente('LAGO', false);
      expect([torrente, lago, battuto].where(v().mostra).map((s) => s.nome), ['A', 'C']);
      vista.impostaStato(FiltroStato.battuti);
      expect([torrente, lago, battuto].where(v().mostra).map((s) => s.nome), ['C']);
      vista.impostaStato(FiltroStato.nonBattuti);
      vista.mostraCategoria('valle', false);
      expect([torrente, lago, battuto].where(v().mostra), isEmpty);
      vista.mostraAmbiente('Lago', true);
      expect([torrente, lago, battuto].where(v().mostra).map((s) => s.nome), ['B']);
      expect(v().filtriAttivi, isTrue);

      vista.impostaColorazione(Colorazione.categoria);
      vista.impostaSfondo(Sfondo.stradale);
      vista.impostaMostraDivieti(false);
      vista.azzeraFiltri();
      expect(v().filtriAttivi, isFalse);
      expect(v().mostraDivieti, isTrue);
      // Colorazione e sfondo restano
      expect(v().colorazione, Colorazione.categoria);
      expect(v().sfondo, Sfondo.stradale);
    });
  });
}
