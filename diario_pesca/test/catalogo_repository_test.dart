import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/models/catalogo/caratteristica.dart';
import 'package:diario_pesca/models/catalogo/esca.dart';
import 'package:diario_pesca/models/catalogo/specie.dart';
import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/foto.dart';
import 'package:diario_pesca/models/obiettivi/obiettivo.dart';
import 'package:diario_pesca/models/pescate/pescata.dart';
import 'package:diario_pesca/models/pescate/riepilogo_specie.dart';
import 'package:diario_pesca/repositories/catalogo_repository.dart';
import 'package:diario_pesca/repositories/obiettivi_repository.dart';
import 'package:diario_pesca/repositories/pescate_repository.dart';
import 'package:diario_pesca/services/statistiche_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late Database db;
  late CatalogoRepository catalogoRepo;
  late ObiettiviRepository obiettiviRepo;
  late PescateRepository pescateRepo;
  late StatisticheService statistiche;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    db = await dbHelper.database;
    catalogoRepo = CatalogoRepository(dbHelper: dbHelper);
    obiettiviRepo = ObiettiviRepository(dbHelper: dbHelper, catalogo: catalogoRepo);
    pescateRepo = PescateRepository(dbHelper: dbHelper, catalogo: catalogoRepo);
    statistiche = StatisticheService(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  Future<void> inserisciSpotDiProva(String nome) async {
    await db.insert(
      'Categoria',
      {'nome': 'Generica'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert('Spot', {
      'nome': nome,
      'ambiente': 'Torrente',
      'categoria_nome': 'Generica',
    });
  }

  group('CatalogoRepository - Specie', () {
    test('inserisciSpecie, getSpecie (ordine e filtro) ed eliminaSpecie', () async {
      await catalogoRepo.inserisciSpecie(
        const Specie(nome: 'Trota', informazioni: 'Salmonide di torrente'),
      );
      await catalogoRepo.inserisciSpecie(
        const Specie(nome: 'Spigola'),
      );

      final tutte = await catalogoRepo.getSpecie();
      expect(tutte.map((s) => s.nome), ['Spigola', 'Trota']);
      expect(tutte[1].informazioni, 'Salmonide di torrente');

      // Filtro testuale case-insensitive
      final filtrate = await catalogoRepo.getSpecie(filtroNome: 'trot');
      expect(filtrate.length, 1);
      expect(filtrate.first.nome, 'Trota');

      await catalogoRepo.eliminaSpecie('Spigola');
      expect((await catalogoRepo.getSpecie()).map((s) => s.nome), ['Trota']);
    });

    test('aggiornaSpecie propaga la rinomina (CASCADE) ed eliminaSpecie è bloccata se usata nelle pescate (RESTRICT)', () async {
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      await catalogoRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Trota', nome: 'Livrea marmorata'),
      );
      await obiettiviRepo.salvaObiettivo(
        const Obiettivo(specieNome: 'Trota', anno: 2026, quantita: 15),
      );

      await inserisciSpotDiProva('Ponte Vecchio');
      final pescata = await pescateRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 10),
          fasciaOraria: FasciaOraria.alba,
          meteo: Meteo.velato,
          spotNome: 'Ponte Vecchio',
          riepiloghiSpecie: const [
            RiepilogoSpecie(specieNome: 'Trota', quantita: 2),
          ],
        ),
      );

      // 1. Eliminazione bloccata finché esiste un riepilogo catture (ON DELETE RESTRICT)
      await expectLater(
        () => catalogoRepo.eliminaSpecie('Trota'),
        throwsA(isA<DatabaseException>()),
      );

      // 2. Rinomina con propagazione automatica su tutte le tabelle (ON UPDATE CASCADE)
      await catalogoRepo.aggiornaSpecie(
        nomeOriginale: 'Trota',
        specieAggiornata: const Specie(
          nome: 'Trota Fario',
          informazioni: 'Rinominata',
        ),
      );

      expect(
        (await catalogoRepo.getCaratteristiche(specieNome: 'Trota Fario')).length,
        1,
      );
      expect(
        (await obiettiviRepo.getObiettivi(specieNome: 'Trota Fario')).length,
        1,
      );
      expect(
        (await statistiche.getRiepiloghi(specieNome: 'Trota Fario')).length,
        1,
      );

      // 3. Eliminata la pescata, eliminaSpecie riesce e rimuove a cascata caratteristica e obiettivo
      await pescateRepo.eliminaPescata(pescata.id!);
      await catalogoRepo.eliminaSpecie('Trota Fario');

      expect(await catalogoRepo.getSpecie(), isEmpty);
      expect(await catalogoRepo.getCaratteristiche(), isEmpty);
      expect(await obiettiviRepo.getObiettivi(), isEmpty);
    });
  });

  group('CatalogoRepository - Caratteristiche', () {
    test('salvaCaratteristica (insert/update), getCaratteristiche con filtri ed eliminaCaratteristica', () async {
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Spigola'));

      final marmorata = await catalogoRepo.salvaCaratteristica(
        const Caratteristica(
          specieNome: 'Trota',
          nome: 'Livrea marmorata',
          descrizione: 'Autoctona',
        ),
      );
      final trotaOver = await catalogoRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Trota', nome: 'Over 40cm'),
      );
      await catalogoRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Spigola', nome: 'Over 2 kg'),
      );

      expect(marmorata.id, isNotNull);

      // Aggiornamento
      await catalogoRepo.salvaCaratteristica(
        marmorata.copyWith(descrizione: 'Bacino padano'),
      );

      final perSpecie = await catalogoRepo.getCaratteristiche(specieNome: 'Trota');
      expect(perSpecie.map((c) => c.nome), ['Livrea marmorata', 'Over 40cm']);
      expect(perSpecie.first.descrizione, 'Bacino padano');

      final perNome = await catalogoRepo.getCaratteristiche(filtroNome: 'over');
      expect(perNome.length, 2);

      await catalogoRepo.eliminaCaratteristica(trotaOver.id!);
      expect((await catalogoRepo.getCaratteristiche(specieNome: 'Trota')).length, 1);
    });

    test('salvaCaratteristica blocca il cambio specie se già referenziata', () async {
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Spigola'));

      final marmorata = await catalogoRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Trota', nome: 'Livrea marmorata'),
      );
      await obiettiviRepo.salvaObiettivo(
        Obiettivo(
          specieNome: 'Trota',
          anno: 2026,
          quantita: 5,
          caratteristica: marmorata,
        ),
      );

      await expectLater(
        () => catalogoRepo.salvaCaratteristica(
          marmorata.copyWith(specieNome: 'Spigola'),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('CatalogoRepository - Esche', () {
    test('salvaEsca (insert/update con 0, 1 o più foto), getEsche (ordine e filtro) ed eliminaEsca', () async {
      final minnow = await catalogoRepo.salvaEsca(
        const Esca(
          nome: 'Minnow 7cm',
          descrizione: 'Livrea vairone',
          foto: [
            Foto(
              percorso: '/img/esca1_a.jpg',
              percorsoThumbnail: '/img/thumb_esca1_a.jpg',
              escaId: 0,
            ),
            Foto(
              percorso: '/img/esca1_b.jpg',
              percorsoThumbnail: '/img/thumb_esca1_b.jpg',
              escaId: 0,
            ),
          ],
        ),
      );
      final cucchiaino = await catalogoRepo.salvaEsca(
        const Esca(nome: 'Cucchiaino #2'),
      );

      expect(minnow.id, isNotNull);
      expect(minnow.foto.length, 2);
      expect(
        minnow.foto.every(
          (f) =>
              f.id != null &&
              f.escaId == minnow.id &&
              f.pescataId == null &&
              f.catturaMemorabileId == null,
        ),
        isTrue,
      );
      expect(cucchiaino.id, isNotNull);
      expect(cucchiaino.foto, isEmpty);

      // Aggiornamento descrizione e riduzione a 1 foto
      await catalogoRepo.salvaEsca(
        minnow.copyWith(
          descrizione: 'Affondante 8g',
          foto: [minnow.foto.first],
        ),
      );

      final tutte = await catalogoRepo.getEsche();
      expect(tutte.map((e) => e.nome), ['Cucchiaino #2', 'Minnow 7cm']);
      expect(tutte[0].foto, isEmpty);
      expect(tutte[1].descrizione, 'Affondante 8g');
      expect(tutte[1].foto.length, 1);
      expect(tutte[1].foto.single.percorso, '/img/esca1_a.jpg');

      // Filtro testuale case-insensitive
      final filtrate = await catalogoRepo.getEsche(filtroNome: 'minnow');
      expect(filtrate.length, 1);
      expect(filtrate.first.id, minnow.id);
      expect(filtrate.first.foto.length, 1);

      // Eliminazione esca senza foto ed esca con foto
      await catalogoRepo.eliminaEsca(cucchiaino.id!);
      expect((await catalogoRepo.getEsche()).length, 1);

      await catalogoRepo.eliminaEsca(minnow.id!);
      expect(await catalogoRepo.getEsche(), isEmpty);
      expect(await db.query('Foto'), isEmpty);
    });
  });
}
