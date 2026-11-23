import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/pescate/pescata.dart';
import 'package:diario_pesca/models/territorio/categoria.dart';
import 'package:diario_pesca/models/territorio/coordinata.dart';
import 'package:diario_pesca/models/territorio/spot.dart';
import 'package:diario_pesca/ui/state/dipendenze.dart';
import 'package:diario_pesca/ui/state/modulo_spot_state.dart';
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

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    container = ProviderContainer.test(
      overrides: [databaseHelperProvider.overrideWith((ref) => dbHelper)],
      retry: (tentativo, errore) => null,
    );
    final territorio = container.read(territorioRepositoryProvider);
    await territorio.inserisciCategoria(const Categoria(nome: 'Borgo di Cima'));
    await territorio.salvaSpotConCoordinate(
      const Spot(
        nome: 'Valbrina',
        ambiente: 'Torrente',
        categoriaNome: 'Borgo di Cima',
        coordinate: [Coordinata(ordine: 0, latitudine: 45.7612, longitudine: 9.6401)],
      ),
    );
    // L'elenco si apre dopo aver preparato i dati, che sono stati scritti
    // direttamente con il repository e non attraverso i provider.
    container.listen(elencoSpotProvider, (_, _) {});
  });

  tearDown(() async {
    await dbHelper.close();
  });

  /// Apre il modulo (come la schermata) per uno spot nuovo o da modificare.
  ModuloSpotNotifier apri([Spot? spot]) {
    container.listen(moduloSpotProvider(spot), (_, _) {});
    return container.read(moduloSpotProvider(spot).notifier);
  }

  BozzaSpot bozza([Spot? spot]) => container.read(moduloSpotProvider(spot));

  group('Modulo spot - Lettura dei punti', () {
    test('leggiCoordinata riconosce i formati copiati da Google Maps', () {
      (double, double)? lettura(String testo) {
        final c = leggiCoordinata(testo);
        return c == null ? null : (c.latitudine, c.longitudine);
      }

      expect(lettura('45.7612, 9.6401'), (45.7612, 9.6401));
      expect(lettura('  45.7612 9.6401 '), (45.7612, 9.6401));
      expect(lettura('45,7612; 9,6401'), (45.7612, 9.6401));
      expect(lettura('45,7612, 9,6401'), (45.7612, 9.6401));
      expect(
        lettura('https://www.google.com/maps/place/x/@44.1231234,8.7651234,732m/data=!3m1!1e3!4m4!3m3!8m2!3d44.123456!4d8.765432'),
        (44.123456, 8.765432),
      );
      expect(lettura('https://www.google.com/maps/@44.5551234,8.4441234,17z'), (44.5551234, 8.4441234));
      final gms = leggiCoordinata('44°07\'24.4"N 8°45\'55.6"E')!;
      expect(gms.latitudine, closeTo(44.12344, 0.00001));
      expect(gms.longitudine, closeTo(8.76544, 0.00001));

      expect(lettura('ciao'), isNull);
      expect(lettura('45.76'), isNull);
      expect(lettura('95.1, 9.6'), isNull);
      expect(lettura('https://maps.app.goo.gl/AbCdEfGh1234567'), isNull);
    });
  });

  group('Modulo spot - Compilazione', () {
    test('segnala nome mancante o già usato, categoria, ambiente, voto e lunghezza', () async {
      final m = apri();
      final nomi = (await container.read(elencoSpotProvider.future)).map((s) => s.nome);
      expect(bozza().errori(nomi), [
        'Scrivi il nome dello spot.',
        'Scegli la categoria.',
        'Scegli l\'ambiente.',
      ]);

      m.impostaNome(' valbrina ');
      m.impostaCategoria('Borgo di Cima');
      m.impostaAmbiente('Torrente');
      m.impostaVoto('11');
      m.impostaLunghezza('-3');
      expect(bozza().errori(nomi), [
        'Esiste già uno spot chiamato "valbrina".',
        'Il voto deve essere un numero tra 0 e 10.',
        'La lunghezza deve essere un numero di metri maggiore di 0.',
      ]);
      await expectLater(m.salva(), throwsA(isA<BozzaNonValida>()));

      m.impostaNome('Valbrina alta');
      m.impostaVoto('7,5');
      m.impostaLunghezza('800');
      expect(bozza().errori(nomi), isEmpty);
      expect(bozza().inSpot().voto, 7.5);
      expect(bozza().inSpot().lunghezzaMetri, 800);
    });

    test('i punti si aggiungono, spostano e tolgono; con due punti la lunghezza si calcola', () {
      final m = apri();
      m.impostaLunghezza('500');
      expect(m.aggiungiPunto('non è un punto'), isFalse);
      expect(m.aggiungiPunto('45.7612, 9.6401'), isTrue);
      expect(m.aggiungiPunto('45.7650, 9.6450'), isTrue);
      expect(m.aggiungiPunto('45.7700, 9.6500'), isTrue);

      m.spostaPunto(2, -1);
      expect(bozza().coordinate.map((c) => c.latitudine), [45.7612, 45.7700, 45.7650]);
      m.rimuoviPunto(0);
      expect(bozza().coordinate.map((c) => c.latitudine), [45.7700, 45.7650]);

      // Con due punti conta la lunghezza calcolata, non quella scritta
      expect(bozza().lunghezzaCalcolata, greaterThan(0));
      m.impostaNome('Prova');
      m.impostaCategoria('Borgo di Cima');
      m.impostaAmbiente('Torrente');
      final spot = bozza().inSpot();
      expect(spot.lunghezzaMetri, isNull);
      expect(spot.coordinate.map((c) => c.ordine), [0, 1]);
    });

    test('la difficoltà si sceglie e si toglie toccandola di nuovo', () {
      final m = apri();
      m.impostaDifficolta(Difficolta.alta);
      expect(bozza().difficolta, Difficolta.alta);
      m.impostaDifficolta(Difficolta.alta);
      expect(bozza().difficolta, isNull);
    });
  });

  group('Modulo spot - Salvataggio', () {
    test('uno spot nuovo con una categoria nuova si salva con i suoi punti', () async {
      container.listen(categorieProvider, (_, _) {});
      final catalogo = await container.read(categorieProvider.future);

      final m = apri();
      m.impostaNome('Abetina');
      final categoria = m.aggiungiCategoriaNuova('  Val Sorbina ', catalogo);
      expect(categoria, 'Val Sorbina');
      expect(bozza().categoriaNome, 'Val Sorbina');
      expect(bozza().nuovaCategoria, 'Val Sorbina');
      // La categoria nasce solo salvando lo spot
      expect(
        (await container.read(territorioRepositoryProvider).getCategorie()).map((c) => c.nome),
        ['Borgo di Cima'],
      );
      m.impostaAmbiente('Torrente');
      m.impostaAccessibile(false);
      m.impostaNote('  Bella pozza sotto il ponte ');
      m.aggiungiPunto('44.5551, 8.4441');
      m.aggiungiPunto('44.5562, 8.4452');
      final salvato = await m.salva();
      expect(salvato.nome, 'Abetina');

      expect(
        (await container.read(elencoSpotProvider.future)).map((s) => s.nome),
        ['Abetina', 'Valbrina'],
      );
      final dettaglio = await container.read(dettaglioSpotProvider('Abetina').future);
      expect(dettaglio!.coordinate, hasLength(2));
      expect(dettaglio.lunghezzaMetri, greaterThan(0));
      expect(dettaglio.accessibilita, Accessibilita.inaccessibile);
      expect(dettaglio.note, 'Bella pozza sotto il ponte');
      expect(dettaglio.categoriaNome, 'Val Sorbina');
      // Dopo il salvataggio la categoria è nel catalogo (e nel provider)
      expect(
        (await container.read(categorieProvider.future)).map((c) => c.nome),
        containsAll(['Borgo di Cima', 'Val Sorbina']),
      );
    });

    test('una categoria scritta al momento: esistente, scartata o abbandonata', () async {
      final catalogo = await container.read(territorioRepositoryProvider).getCategorie();
      final m = apri();

      // Corrisponde a una esistente (maiuscole e spazi non contano): nessuna nuova
      expect(m.aggiungiCategoriaNuova(' borgo DI cima', catalogo), 'Borgo di Cima');
      expect(bozza().nuovaCategoria, isNull);
      expect(m.categoriaScartata('Borgo di Cima'), isNull);

      // Una nuova: sceglierne un'altra la scarterebbe, quindi va confermato
      m.aggiungiCategoriaNuova('Val Sorbina', catalogo);
      expect(m.categoriaScartata('Val Sorbina'), isNull);
      expect(m.categoriaScartata('Borgo di Cima'), 'Val Sorbina');
      m.impostaCategoria('Borgo di Cima');
      expect(bozza().nuovaCategoria, isNull);
      expect(bozza().categoriaNome, 'Borgo di Cima');

      // Un modulo abbandonato non lascia nulla nel catalogo
      m.aggiungiCategoriaNuova('Val Torba', catalogo);
      container.invalidate(moduloSpotProvider(null));
      expect(
        (await container.read(territorioRepositoryProvider).getCategorie()).map((c) => c.nome),
        ['Borgo di Cima'],
      );
    });

    test('rinominare e cambiare ambiente: le condizioni usate si possono collegare', () async {
      // Una pescata a Valbrina con Livello = Morbida
      final catalogo = container.read(catalogoRepositoryProvider);
      final livello = (await catalogo.getCondizioni(ambienteNome: 'Torrente'))
          .firstWhere((c) => c.nome == 'Livello');
      await container.read(pescateRepositoryProvider).salvaPescata(
            Pescata(
              data: DateTime(2026, 3, 1),
              fasciaOraria: FasciaOraria.alba,
              spotNome: 'Valbrina',
              valoriCondizioni: [livello.valori.firstWhere((v) => v.nome == 'Morbida')],
            ),
          );

      final spot = await container.read(dettaglioSpotProvider('Valbrina').future);
      final m = apri(spot);
      expect(bozza(spot).nome, 'Valbrina');
      expect(await m.condizioniDaCollegare(), isEmpty);

      m.impostaNome('Valbrina alta');
      m.impostaAmbiente('Lago');
      final daCollegare = await m.condizioniDaCollegare();
      // Il meteo è già previsto per il lago: manca solo il livello
      expect(daCollegare.map((c) => c.nome), ['Livello']);

      await m.salva(collega: daCollegare);

      final delLago = await catalogo.getCondizioni(ambienteNome: 'Lago');
      expect(delLago.map((c) => c.nome), containsAll(['Livello', 'Meteo']));
      final pescate = await container.read(pescateRepositoryProvider).getPescate();
      expect(pescate.single.spotNome, 'Valbrina alta');
      final rinominato = await container.read(dettaglioSpotProvider('Valbrina alta').future);
      expect(rinominato!.ambiente, 'Lago');
      expect(rinominato.coordinate.single.latitudine, 45.7612);
      expect(rinominato.battuto, isTrue);
    });

    test('eliminare uno spot lo toglie dall\'elenco e lascia le pescate senza spot', () async {
      await container.read(pescateRepositoryProvider).salvaPescata(
            Pescata(data: DateTime(2026, 3, 1), fasciaOraria: FasciaOraria.alba, spotNome: 'Valbrina'),
          );
      final spot = await container.read(dettaglioSpotProvider('Valbrina').future);
      await apri(spot).elimina();

      expect(await container.read(elencoSpotProvider.future), isEmpty);
      final pescate = await container.read(pescateRepositoryProvider).getPescate();
      expect(pescate.single.spotNome, isNull);
    });
  });
}
