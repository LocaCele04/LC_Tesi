import 'package:diario_pesca/database/database_helper.dart';
import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/territorio/categoria.dart';
import 'package:diario_pesca/models/territorio/coordinata.dart';
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
}