import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/territorio/ambiente.dart';
import 'package:diario_pesca/models/territorio/categoria.dart';
import 'package:diario_pesca/models/territorio/coordinata.dart';
import 'package:diario_pesca/models/territorio/divieto.dart';
import 'package:diario_pesca/models/territorio/spot.dart';
import 'package:diario_pesca/repositories/territorio_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late TerritorioRepository repo;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    repo = TerritorioRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('TerritorioRepository - Ambienti', () {
    test('getAmbienti restituisce gli ambienti di base e quelli aggiunti, in ordine alfabetico', () async {
      final base = await repo.getAmbienti();
      expect(base.map((a) => a.nome), ['Fiume', 'Lago', 'Mare', 'Torrente']);

      await repo.inserisciAmbiente(const Ambiente(nome: '  Canale  '));
      final dopo = await repo.getAmbienti();
      expect(dopo.map((a) => a.nome), ['Canale', 'Fiume', 'Lago', 'Mare', 'Torrente']);

      // Duplicato con maiuscole diverse rifiutato
      expect(
        () => repo.inserisciAmbiente(const Ambiente(nome: 'LAGO')),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('aggiornaAmbiente propaga la rinomina agli spot ed eliminaAmbiente è bloccata se in uso', () async {
      await repo.inserisciCategoria(const Categoria(nome: 'Pianura'));
      await repo.inserisciAmbiente(const Ambiente(nome: 'Canale'));
      await repo.salvaSpotConCoordinate(
        const Spot(nome: 'Canale Vecchio', ambiente: 'Canale', categoriaNome: 'Pianura'),
      );

      await repo.aggiornaAmbiente(
        nomeOriginale: 'Canale',
        ambienteAggiornato: const Ambiente(nome: 'Roggia'),
      );
      final spot = await repo.getSpotConCoordinate('Canale Vecchio');
      expect(spot!.ambiente, 'Roggia');

      await expectLater(
        () => repo.eliminaAmbiente('Roggia'),
        throwsA(isA<DatabaseException>()),
      );

      await repo.eliminaSpot('Canale Vecchio');
      await repo.eliminaAmbiente('Roggia');
      expect(
        (await repo.getAmbienti()).map((a) => a.nome),
        isNot(contains('Roggia')),
      );
    });
  });

  group('TerritorioRepository - Categorie', () {
    test('inserisciCategoria e getCategorie ordinano alfabeticamente', () async {
      await repo.inserisciCategoria(
        const Categoria(nome: 'Torrente', note: 'Acque correnti montane'),
      );
      await repo.inserisciCategoria(
        const Categoria(nome: 'Lago Alpino'),
      );

      final categorie = await repo.getCategorie();

      expect(categorie.length, 2);
      expect(categorie[0].nome, 'Lago Alpino');
      expect(categorie[0].note, isNull);
      expect(categorie[1].nome, 'Torrente');
      expect(categorie[1].note, 'Acque correnti montane');
    });

    test('aggiornaCategoria propaga la rinomina agli spot (ON UPDATE CASCADE)', () async {
      await repo.inserisciCategoria(const Categoria(nome: 'Torrente'));
      await repo.salvaSpotConCoordinate(
        const Spot(
          nome: 'Ponte Vecchio',
          ambiente: 'Torrente',
          categoriaNome: 'Torrente',
        ),
      );

      await repo.aggiornaCategoria(
        nomeOriginale: 'Torrente',
        categoriaAggiornata: const Categoria(
          nome: 'Torrente Alpino',
          note: 'Rinominata',
        ),
      );

      final spotAggiornati = await repo.getSpots(categoriaNome: 'Torrente Alpino');
      expect(spotAggiornati.length, 1);
      expect(spotAggiornati.first.nome, 'Ponte Vecchio');
    });

    test('eliminaCategoria viene bloccata se usata da uno spot (ON DELETE RESTRICT) e spostaSpot la libera', () async {
      await repo.inserisciCategoria(const Categoria(nome: 'Torrente'));
      await repo.inserisciCategoria(const Categoria(nome: 'Fiume'));
      await repo.salvaSpotConCoordinate(
        const Spot(
          nome: 'Ponte Vecchio',
          ambiente: 'Torrente',
          categoriaNome: 'Torrente',
        ),
      );

      await expectLater(
        () => repo.eliminaCategoria('Torrente'),
        throwsA(isA<DatabaseException>()),
      );

      final spostati = await repo.spostaSpot(
        daCategoria: 'Torrente',
        aCategoria: 'Fiume',
      );
      expect(spostati, 1);

      await repo.eliminaCategoria('Torrente');
      expect((await repo.getSpots(categoriaNome: 'Fiume')).length, 1);
    });
  });

  group('TerritorioRepository - Spot e Coordinate', () {
    test('salvaSpotConCoordinate calcola lunghezza dalle coordinate e sincronizza battuto', () async {
      await repo.inserisciCategoria(const Categoria(nome: 'Torrente'));
      await repo.salvaSpotConCoordinate(
        const Spot(
          nome: 'Ponte Vecchio',
          ambiente: 'Torrente',
          voto: 9,
          difficolta: Difficolta.media,
          battuto: true,
          coordinate: [
            Coordinata(
              spotNome: 'Ponte Vecchio',
              ordine: 0,
              latitudine: 45.6495,
              longitudine: 9.6012,
            ),
            Coordinata(
              spotNome: 'Ponte Vecchio',
              ordine: 1,
              latitudine: 45.6510,
              longitudine: 9.6030,
            ),
            Coordinata(
              spotNome: 'Ponte Vecchio',
              ordine: 2,
              latitudine: 45.6525,
              longitudine: 9.6045,
            ),
          ],
          categoriaNome: 'Torrente',
        ),
      );

      final spot = await repo.getSpotConCoordinate('Ponte Vecchio');

      expect(spot, isNotNull);
      expect(spot!.coordinate.length, 3);
      expect(spot.lunghezzaMetri, isNotNull);
      expect(spot.lunghezzaMetri!, greaterThan(400));
      // Nessuna pescata registrata: battuto deve allinearsi a false
      expect(spot.battuto, isFalse);
    });

    test('getSpots filtra per categoria, ambiente, votoMinimo, lunghezzaMassima e accessibilita', () async {
      await repo.inserisciCategoria(const Categoria(nome: 'Torrente'));
      await repo.inserisciCategoria(const Categoria(nome: 'Lago'));

      await repo.salvaSpotConCoordinate(
        const Spot(
          nome: 'Spot A',
          ambiente: 'Torrente',
          lunghezzaMetri: 300.0,
          voto: 9,
          accessibilita: Accessibilita.accessibile,
          categoriaNome: 'Torrente',
        ),
      );
      await repo.salvaSpotConCoordinate(
        const Spot(
          nome: 'Spot B',
          ambiente: 'Torrente',
          lunghezzaMetri: 150.0,
          voto: 5,
          accessibilita: Accessibilita.inaccessibile,
          categoriaNome: 'Torrente',
        ),
      );
      await repo.salvaSpotConCoordinate(
        const Spot(
          nome: 'Spot C',
          ambiente: 'Lago',
          lunghezzaMetri: 1200.0,
          voto: 8,
          accessibilita: Accessibilita.accessibile,
          categoriaNome: 'Lago',
        ),
      );

      final perCategoria = await repo.getSpots(categoriaNome: 'Torrente');
      final perAmbienteEVoto = await repo.getSpots(
        ambiente: 'torrente',
        votoMinimo: 8,
      );
      final entro500m = await repo.getSpots(lunghezzaMassima: 500.0);
      final inaccessibili = await repo.getSpots(
        accessibilita: Accessibilita.inaccessibile,
      );

      expect(perCategoria.length, 2);
      expect(perAmbienteEVoto.map((s) => s.nome), ['Spot A']);
      expect(entro500m.map((s) => s.nome), ['Spot A', 'Spot B']);
      expect(inaccessibili.map((s) => s.nome), ['Spot B']);
    });

    test('salvaSpotConCoordinate aggiorna uno spot esistente, ricalcola lunghezza e getTutteLeCoordinate raggruppa per spot', () async {
      await repo.inserisciCategoria(const Categoria(nome: 'Torrente'));
      await repo.salvaSpotConCoordinate(
        const Spot(
          nome: 'Risorgiva Sud',
          ambiente: 'Torrente',
          voto: 5,
          coordinate: [
            Coordinata(spotNome: 'Risorgiva Sud', ordine: 0, latitudine: 45.6, longitudine: 9.6),
          ],
          categoriaNome: 'Torrente',
        ),
      );

      final iniziale = await repo.getSpotConCoordinate('Risorgiva Sud');
      await repo.salvaSpotConCoordinate(
        iniziale!.copyWith(
          voto: 8,
          note: 'Ottimo spot',
          coordinate: const [
            Coordinata(spotNome: 'Risorgiva Sud', ordine: 0, latitudine: 45.6, longitudine: 9.6),
            Coordinata(spotNome: 'Risorgiva Sud', ordine: 1, latitudine: 45.602, longitudine: 9.602),
          ],
        ),
        nomeOriginale: 'Risorgiva Sud',
      );

      final aggiornato = await repo.getSpotConCoordinate('Risorgiva Sud');
      expect(aggiornato!.voto, 8);
      expect(aggiornato.note, 'Ottimo spot');
      expect(aggiornato.coordinate.length, 2);
      expect(aggiornato.lunghezzaMetri, isNotNull);

      final mappaCoord = await repo.getTutteLeCoordinate();
      expect(mappaCoord.keys, ['Risorgiva Sud']);
      expect(mappaCoord['Risorgiva Sud']!.map((c) => c.ordine), [0, 1]);
    });

    test('eliminaSpot rimuove lo spot e libera la categoria', () async {
      await repo.inserisciCategoria(const Categoria(nome: 'Lago'));
      await repo.salvaSpotConCoordinate(
        const Spot(nome: 'Lago Nero', ambiente: 'Lago', categoriaNome: 'Lago'),
      );

      await repo.eliminaSpot('Lago Nero');
      expect(await repo.getSpotConCoordinate('Lago Nero'), isNull);

      await repo.eliminaCategoria('Lago');
      expect(await repo.getCategorie(), isEmpty);
    });
  });

  group('TerritorioRepository - Condizioni al cambio di ambiente', () {
    test('getCondizioniNonPreviste segnala le condizioni usate dalle pescate dello spot e non previste dal nuovo ambiente', () async {
      final db = await dbHelper.database;
      await repo.inserisciCategoria(const Categoria(nome: 'Valle'));
      await repo.salvaSpotConCoordinate(
        const Spot(nome: 'Valsecca', ambiente: 'Torrente', categoriaNome: 'Valle'),
      );

      Future<Map<String, Object?>> valore(String condizione, String nome) async {
        final righe = await db.rawQuery('''
          SELECT v.id, v.condizione_id FROM ValoreCondizione v
          INNER JOIN Condizione c ON c.id = v.condizione_id
          WHERE c.nome = ? AND v.nome = ?
        ''', [condizione, nome]);
        return righe.single;
      }

      final pescataId = await db.insert('Pescata', {
        'data': '2026-11-10',
        'fasciaOraria': 'alba',
        'spot_nome': 'Valsecca',
      });
      for (final v in [await valore('Livello', 'Magra'), await valore('Meteo', 'Sereno')]) {
        await db.insert('Pescata_Condizione', {
          'pescata_id': pescataId,
          'condizione_id': v['condizione_id'],
          'valore_id': v['id'],
        });
      }

      // Il Lago prevede solo il Meteo: il Livello resterebbe "non previsto"
      final perLago = await repo.getCondizioniNonPreviste(
        spotNome: 'Valsecca',
        ambienteNome: 'Lago',
      );
      expect(perLago.map((c) => c.nome), ['Livello']);

      // Il Fiume prevede entrambe le condizioni usate
      expect(
        await repo.getCondizioniNonPreviste(spotNome: 'Valsecca', ambienteNome: 'Fiume'),
        isEmpty,
      );

      // Cambiare l'ambiente non tocca i valori già salvati
      final spot = await repo.getSpotConCoordinate('Valsecca');
      await repo.salvaSpotConCoordinate(
        spot!.copyWith(ambiente: 'Lago'),
        nomeOriginale: 'Valsecca',
      );
      expect(await db.query('Pescata_Condizione'), hasLength(2));
    });
  });

  group('TerritorioRepository - Divieti', () {
    const p1 = Coordinata(ordine: 7, latitudine: 46.01, longitudine: 9.70);
    const p2 = Coordinata(ordine: 3, latitudine: 46.02, longitudine: 9.71);
    const p3 = Coordinata(ordine: 0, latitudine: 46.03, longitudine: 9.72);

    test('salvaDivieto assegna l\'id, numera i punti nell\'ordine della lista e pulisce nome e note', () async {
      final salvato = await repo.salvaDivieto(
        const Divieto(nome: '  Divieto incubatoio ', note: '   ', coordinate: [p1, p2]),
      );
      expect(salvato.id, isNotNull);
      expect(salvato.nome, 'Divieto incubatoio');
      expect(salvato.note, isNull);
      expect(salvato.coordinate.map((c) => c.ordine), [0, 1]);

      final letto = await repo.getDivieto(salvato.id!);
      expect(letto, salvato);
      expect(letto!.coordinate.map((c) => c.latitudine), [46.01, 46.02]);
      // Un divieto non è uno spot
      expect(await repo.getSpots(), isEmpty);
      expect(await repo.getTutteLeCoordinate(), isEmpty);
    });

    test('aggiornare un divieto sostituisce nome, note e tutti i punti', () async {
      final salvato = await repo.salvaDivieto(const Divieto(nome: 'Divieto', coordinate: [p1, p2]));
      final aggiornato = await repo.salvaDivieto(
        salvato.copyWith(nome: 'Divieto per frane', note: 'Fino al ponte', coordinate: [p3]),
      );
      expect(aggiornato.id, salvato.id);

      final letto = await repo.getDivieto(salvato.id!);
      expect(letto!.nome, 'Divieto per frane');
      expect(letto.note, 'Fino al ponte');
      expect(letto.coordinate, [p3.copyWith(ordine: 0)]);
    });

    test('getDivieti restituisce tutti i divieti con i loro punti, anche con lo stesso nome', () async {
      final a = await repo.salvaDivieto(const Divieto(nome: 'Divieto', coordinate: [p1, p2]));
      final b = await repo.salvaDivieto(const Divieto(nome: 'divieto', coordinate: [p3]));
      final c = await repo.salvaDivieto(const Divieto(nome: 'Ansa', coordinate: [p2, p3]));

      final divieti = await repo.getDivieti();
      // Per nome senza distinzione di maiuscole, poi per id
      expect(divieti.map((d) => d.id), [c.id, a.id, b.id]);
      expect(divieti.map((d) => d.coordinate.length), [2, 2, 1]);
      expect(divieti[1].coordinate.first.latitudine, 46.01);
    });

    test('un divieto senza punti o inesistente viene rifiutato, eliminarlo toglie anche i punti', () async {
      expect(() => repo.salvaDivieto(const Divieto(nome: 'Vuoto')), throwsArgumentError);
      expect(
        () => repo.salvaDivieto(const Divieto(id: 999, nome: 'Fantasma', coordinate: [p1])),
        throwsArgumentError,
      );
      expect(await repo.getDivieti(), isEmpty);

      final salvato = await repo.salvaDivieto(const Divieto(nome: 'Divieto', coordinate: [p1, p2]));
      await repo.eliminaDivieto(salvato.id!);
      expect(await repo.getDivieto(salvato.id!), isNull);
      final db = await dbHelper.database;
      expect(await db.query('CoordinataDivieto'), isEmpty);
    });
  });
}
