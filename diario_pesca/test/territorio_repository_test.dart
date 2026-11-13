import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../lib/database/database_helper.dart';
import '../lib/models/enums.dart';
import '../lib/models/territorio/categoria.dart';
import '../lib/models/territorio/coordinata.dart';
import '../lib/models/territorio/spot.dart';
import '../lib/repositories/territorio_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late TerritorioRepository repo;

  setUp(() async {
    await DatabaseHelper.instance.resetPerSviluppo();
    repo = TerritorioRepository();
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
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

    test('eliminaCategoria viene bloccata se usata da uno spot (ON DELETE RESTRICT)', () async {
      await repo.inserisciCategoria(const Categoria(nome: 'Torrente'));
      await repo.salvaSpotConCoordinate(
        const Spot(
          nome: 'Ponte Vecchio',
          ambiente: 'Torrente',
          categoriaNome: 'Torrente',
        ),
      );

      expect(
        () => repo.eliminaCategoria('Torrente'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('TerritorioRepository - Spot e Coordinate', () {
    test('salvaSpotConCoordinate calcola automaticamente la lunghezza dalle coordinate', () async {
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
        ),
      );

      final spot = await repo.getSpotConCoordinate('Ponte Vecchio');

      expect(spot, isNotNull);
      expect(spot!.coordinate.length, 3);
      expect(spot.lunghezzaMetri, isNotNull);
      expect(spot.lunghezzaMetri!, greaterThan(400));
    });

    test('getSpots filtra per categoria, ambiente, votoMinimo e lunghezzaMassima', () async {
      await repo.inserisciCategoria(const Categoria(nome: 'Torrente'));
      await repo.inserisciCategoria(const Categoria(nome: 'Lago'));

      await repo.salvaSpotConCoordinate(
        const Spot(
          nome: 'Spot A',
          ambiente: 'Torrente',
          lunghezzaMetri: 300.0,
          voto: 9,
          categoriaNome: 'Torrente',
        ),
      );
      await repo.salvaSpotConCoordinate(
        const Spot(
          nome: 'Spot B',
          ambiente: 'Torrente',
          lunghezzaMetri: 150.0,
          voto: 5,
          categoriaNome: 'Torrente',
        ),
      );
      await repo.salvaSpotConCoordinate(
        const Spot(
          nome: 'Spot C',
          ambiente: 'Lago',
          lunghezzaMetri: 1200.0,
          voto: 8,
          categoriaNome: 'Lago',
        ),
      );

      final perCategoria = await repo.getSpots(categoriaNome: 'Torrente');
      final perAmbienteEVoto = await repo.getSpots(
        ambiente: 'torrente',
        votoMinimo: 8,
      );
      final entro500m = await repo.getSpots(lunghezzaMassima: 500.0);

      expect(perCategoria.length, 2);
      expect(perAmbienteEVoto.map((s) => s.nome), ['Spot A']);
      expect(entro500m.map((s) => s.nome), ['Spot A', 'Spot B']);
    });

    test('salvaSpotConCoordinate aggiorna uno spot esistente e sincronizza le coordinate', () async {
      await repo.salvaSpotConCoordinate(
        const Spot(
          nome: 'Risorgiva Sud',
          ambiente: 'Torrente',
          voto: 5,
          coordinate: [
            Coordinata(spotNome: 'Risorgiva Sud', ordine: 0, latitudine: 45.6, longitudine: 9.6),
          ],
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