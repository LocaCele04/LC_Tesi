import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/models/catalogo/caratteristica.dart';
import 'package:diario_pesca/models/catalogo/esca.dart';
import 'package:diario_pesca/models/catalogo/specie.dart';
import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/territorio/categoria.dart';
import 'package:diario_pesca/models/territorio/spot.dart';
import 'package:diario_pesca/ui/state/catalogo_state.dart';
import 'package:diario_pesca/ui/state/dipendenze.dart';
import 'package:diario_pesca/ui/state/modulo_pescata_state.dart';
import 'package:diario_pesca/ui/state/pescate_state.dart';
import 'package:diario_pesca/ui/state/spot_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// "Oggi" per tutti i test.
final oggi = DateTime(2026, 2, 20, 12);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late ProviderContainer container;
  late Caratteristica over30;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    container = ProviderContainer.test(
      overrides: [
        databaseHelperProvider.overrideWith((ref) => dbHelper),
        orologioProvider.overrideWith((ref) => () => oggi),
      ],
      retry: (tentativo, errore) => null,
    );
    // Il modulo resta aperto per tutto il test (come la schermata).
    container.listen(moduloPescataProvider(null), (_, _) {});

    final territorio = container.read(territorioRepositoryProvider);
    await territorio.inserisciCategoria(const Categoria(nome: 'Valle'));
    await territorio.salvaSpotConCoordinate(
      const Spot(nome: 'Valbrina', ambiente: 'Torrente', categoriaNome: 'Valle'),
    );
    await territorio.salvaSpotConCoordinate(
      const Spot(nome: 'Piazza3', ambiente: 'Torrente', categoriaNome: 'Valle'),
    );
    await territorio.salvaSpotConCoordinate(
      const Spot(nome: 'Lago Smeraldo', ambiente: 'Lago', categoriaNome: 'Valle'),
    );
    final catalogo = container.read(catalogoRepositoryProvider);
    await catalogo.inserisciSpecie(const Specie(nome: 'Trota'));
    await catalogo.inserisciSpecie(const Specie(nome: 'Temolo'));
    over30 = await catalogo.salvaCaratteristica(
      const Caratteristica(specieNome: 'Trota', nome: 'Over 30'),
    );
    await catalogo.salvaEsca(const Esca(nome: 'Gomma verde 7 cm'));
  });

  tearDown(() async {
    await dbHelper.close();
  });

  BozzaPescata bozza() => container.read(moduloPescataProvider(null));
  ModuloPescataNotifier modulo() => container.read(moduloPescataProvider(null).notifier);

  group('Modulo pescata - Controlli', () {
    test('la bozza parte da oggi; senza spot e fascia oraria non si salva', () async {
      expect(bozza().data, DateTime(2026, 2, 20));
      expect(bozza().errori(oggi: oggi), ['Scegli lo spot.', 'Scegli la fascia oraria.']);

      await expectLater(modulo().salva(), throwsA(isA<BozzaNonValida>()));
      expect(await container.read(elencoPescateProvider.future), isEmpty);
    });

    test('segnala data futura, temperature non valide e catture incomplete', () {
      final m = modulo();
      m.impostaSpot('Valbrina', 'Torrente');
      m.impostaFascia(FasciaOraria.alba);
      m.impostaData(DateTime(2026, 2, 21));
      m.impostaTempAcqua('40');
      m.aggiungiCattura(); // senza specie e senza totale
      m.aggiungiCattura();
      m.aggiungiCattura();
      final righe = bozza().catture;
      m.impostaSpecie(righe[1].chiave, 'Trota');
      m.impostaTotale(righe[1].chiave, 2);
      m.impostaDettaglio(righe[1].chiave, over30, 3);
      m.impostaSpecie(righe[2].chiave, 'trota');
      m.impostaTotale(righe[2].chiave, 1);

      expect(bozza().errori(oggi: oggi), [
        'La data non può essere nel futuro.',
        'La temperatura dell\'acqua deve essere tra 0 e 35 °C.',
        'Scegli la specie della riga 1 delle catture.',
        'Indica quante catture di specie n. 1 (o togli la riga).',
        '"Over 30" (Trota): 3 è più del totale (2).',
        'trota compare due volte nelle catture.',
      ]);

      // Corretti i dati la bozza è valida; la virgola decimale è accettata
      m.impostaData(DateTime(2026, 2, 19));
      m.impostaTempAcqua('8,5');
      m.rimuoviCattura(righe[0].chiave);
      m.rimuoviCattura(righe[2].chiave);
      m.impostaTotale(righe[1].chiave, 7);
      expect(bozza().errori(oggi: oggi), isEmpty);
      expect(bozza().totaleCatture, 7);
      expect(bozza().inPescata().tempAcqua, 8.5);
    });
  });

  group('Modulo pescata - Compilazione', () {
    test('le condizioni dipendono dall\'ambiente: cambiandolo i valori scelti si tolgono', () async {
      final m = modulo();
      m.impostaSpot('Valbrina', 'Torrente');
      final condizioni = await container.read(condizioniPerFormProvider((ambiente: 'Torrente', pescataId: null)).future);
      expect(condizioni.map((c) => c.nome), containsAll(['Livello', 'Trasparenza', 'Fondo', 'Meteo']));
      final livello = condizioni.firstWhere((c) => c.nome == 'Livello');
      final morbida = livello.valori.firstWhere((v) => v.nome == 'Morbida');

      m.impostaValore(livello, morbida);
      expect(bozza().valori[livello.id]?.nome, 'Morbida');
      // Toccare di nuovo lo stesso valore lo toglie
      m.impostaValore(livello, morbida);
      expect(bozza().valori, isEmpty);

      m.impostaValore(livello, morbida);
      m.impostaSpot('Piazza3', 'Torrente');
      expect(bozza().valori, hasLength(1));
      m.impostaSpot('Lago Smeraldo', 'Lago');
      expect(bozza().valori, isEmpty);
      final delLago = await container.read(condizioniPerFormProvider((ambiente: 'Lago', pescataId: null)).future);
      expect(delLago.map((c) => c.nome), ['Meteo']);
    });

    test('esche: una nuova esca con il nome di una esistente seleziona quella', () async {
      final m = modulo();
      final catalogo = await container.read(escheProvider.future);

      final esistente = m.aggiungiEscaNuova('  gomma VERDE 7 cm ', catalogo);
      expect(esistente.id, isNotNull);
      final nuova = m.aggiungiEscaNuova('Streamer nero', catalogo);
      expect(nuova.isNuovo, isTrue);
      // La stessa esca nuova scritta due volte non si duplica
      m.aggiungiEscaNuova('streamer nero', catalogo);
      expect(bozza().esche.map((e) => e.nome), ['Gomma verde 7 cm', 'Streamer nero']);

      m.alternaEsca(esistente);
      expect(bozza().esche.map((e) => e.nome), ['Streamer nero']);
    });

    test('cambiando la specie di una riga le sue caratteristiche si tolgono', () {
      final m = modulo();
      m.aggiungiCattura();
      final chiave = bozza().catture.single.chiave;
      m.impostaSpecie(chiave, 'Trota');
      m.impostaTotale(chiave, 4);
      m.impostaDettaglio(chiave, over30, 2);
      expect(bozza().catture.single.dettagli, {over30: 2});

      m.impostaSpecie(chiave, 'Temolo');
      expect(bozza().catture.single.dettagli, isEmpty);
      expect(bozza().catture.single.totale, 4);
    });

    test('specie scritte al momento: esistenti, nuove e scartate solo con conferma', () async {
      final m = modulo();
      final catalogo = await container.read(specieProvider.future);
      m.aggiungiCattura();
      m.aggiungiCattura();
      final prima = bozza().catture[0].chiave;
      final seconda = bozza().catture[1].chiave;

      // Corrisponde a una del catalogo: nessuna specie nuova
      expect(m.aggiungiSpecieNuova(prima, ' TROTA ', catalogo), 'Trota');
      expect(bozza().nuoveSpecie, isEmpty);

      // Una nuova, poi riscritta in un'altra riga: non si duplica
      expect(m.aggiungiSpecieNuova(prima, 'Salmerino', catalogo), 'Salmerino');
      expect(m.aggiungiSpecieNuova(seconda, ' salmerino', catalogo), 'Salmerino');
      expect(bozza().nuoveSpecie, ['Salmerino']);
      // Usata da due righe: cambiarne una non la scarta
      expect(m.specieScartata(prima, altra: 'Trota'), isNull);
      m.impostaSpecie(prima, 'Trota');
      expect(bozza().nuoveSpecie, ['Salmerino']);

      // Ora la usa solo una riga: cambiarla o toglierla la scarterebbe
      expect(m.specieScartata(seconda, altra: 'Temolo'), 'Salmerino');
      expect(m.specieScartata(seconda), 'Salmerino');
      expect(m.specieScartata(seconda, altra: 'Salmerino'), isNull);
      expect(m.specieScartata(prima), isNull);
      m.rimuoviCattura(seconda);
      expect(bozza().nuoveSpecie, isEmpty);

      // Nulla è entrato nel catalogo: la specie nasce solo salvando
      expect(
        (await container.read(catalogoRepositoryProvider).getSpecie()).map((s) => s.nome),
        containsAll(['Trota', 'Temolo']),
      );
      expect(await container.read(catalogoRepositoryProvider).getSpecie(), hasLength(2));
    });
  });

  group('Modulo pescata - Modifiche non salvate', () {
    test('appena aperta non è modificata; una riga di cattura vuota non conta', () {
      final m = modulo();
      expect(m.modificato, isFalse);

      m.aggiungiCattura();
      expect(m.modificato, isFalse);
      final chiave = bozza().catture.single.chiave;
      m.impostaTotale(chiave, 3);
      expect(m.modificato, isTrue);
      m.impostaTotale(chiave, 0);
      expect(m.modificato, isFalse);

      m.impostaFascia(FasciaOraria.alba);
      expect(m.modificato, isTrue);
    });

    test('lo spot scelto all\'apertura non è una modifica', () {
      final m = modulo()
        ..impostaSpot('Valbrina', 'Torrente')
        ..fissaComeIniziale();
      expect(m.modificato, isFalse);
      m.impostaSpot('Piazza3', 'Torrente');
      expect(m.modificato, isTrue);
    });
  });

  group('Modulo pescata - Salvataggio', () {
    test('salva la pescata completa e aggiorna spot, pescate ed esche', () async {
      container.listen(elencoSpotProvider, (_, _) {});
      container.listen(elencoPescateProvider, (_, _) {});
      expect((await container.read(elencoSpotProvider.future)).every((s) => !s.battuto), isTrue);

      final m = modulo();
      m.impostaSpot('Valbrina', 'Torrente');
      m.impostaData(DateTime(2026, 2, 18));
      m.impostaFascia(FasciaOraria.mattina);
      final livello = (await container.read(condizioniPerFormProvider((ambiente: 'Torrente', pescataId: null)).future))
          .firstWhere((c) => c.nome == 'Livello');
      m.impostaValore(livello, livello.valori.firstWhere((v) => v.nome == 'Normale'));
      m.impostaTempAcqua('7');
      final catalogo = await container.read(escheProvider.future);
      m.aggiungiEscaNuova('Gomma verde 7 cm', catalogo);
      m.aggiungiEscaNuova('Streamer nero', catalogo);
      m.aggiungiCattura();
      m.aggiungiCattura();
      final righe = bozza().catture;
      m.impostaSpecie(righe[0].chiave, 'Trota');
      m.impostaTotale(righe[0].chiave, 7);
      m.impostaDettaglio(righe[0].chiave, over30, 5);
      m.impostaSpecie(righe[1].chiave, 'Temolo');
      m.impostaTotale(righe[1].chiave, 2);
      m.impostaNote('  Acqua bella dopo la pioggia  ');

      final salvata = await m.salva();
      expect(salvata.id, isNotNull);

      final completa = await container.read(pescateRepositoryProvider).getPescataCompleta(salvata.id!);
      expect(completa!.spotNome, 'Valbrina');
      expect(completa.data, DateTime(2026, 2, 18));
      expect(completa.fasciaOraria, FasciaOraria.mattina);
      expect(completa.tempAcqua, 7);
      expect(completa.note, 'Acqua bella dopo la pioggia');
      expect(completa.valoriCondizioni.single.nome, 'Normale');
      expect(completa.esche.map((e) => e.nome), containsAll(['Gomma verde 7 cm', 'Streamer nero']));
      final trota = completa.riepiloghiSpecie.firstWhere((r) => r.specieNome == 'Trota');
      expect(trota.quantita, 7);
      expect(trota.dettagli.single.quantita, 5);
      expect(completa.riepiloghiSpecie.firstWhere((r) => r.specieNome == 'Temolo').dettagli, isEmpty);

      // Gli altri dati dell'app sono già aggiornati
      expect(container.read(elencoPescateProvider).requireValue, hasLength(1));
      final spot = await container.read(elencoSpotProvider.future);
      expect(spot.firstWhere((s) => s.nome == 'Valbrina').battuto, isTrue);
      expect(
        (await container.read(escheProvider.future)).map((e) => e.nome),
        ['Gomma verde 7 cm', 'Streamer nero'],
      );
    });

    test('una specie nuova entra nel catalogo solo salvando la pescata', () async {
      container.listen(specieProvider, (_, _) {});
      final m = modulo();
      m.impostaSpot('Valbrina', 'Torrente');
      m.impostaData(DateTime(2026, 2, 18));
      m.impostaFascia(FasciaOraria.alba);
      m.aggiungiCattura();
      final chiave = bozza().catture.single.chiave;
      m.aggiungiSpecieNuova(chiave, '  Salmerino ', await container.read(specieProvider.future));
      m.impostaTotale(chiave, 1);
      expect(await container.read(catalogoRepositoryProvider).getSpecie(), hasLength(2));

      final salvata = await m.salva();
      final completa = await container.read(pescateRepositoryProvider).getPescataCompleta(salvata.id!);
      expect(completa!.riepiloghiSpecie.single.specieNome, 'Salmerino');
      // Il provider delle specie è già aggiornato
      expect(
        (await container.read(specieProvider.future)).map((s) => s.nome),
        containsAll(['Trota', 'Temolo', 'Salmerino']),
      );
    });
  });
}
