import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/models/catalogo/caratteristica.dart';
import 'package:diario_pesca/models/catalogo/specie.dart';
import 'package:diario_pesca/models/obiettivi/obiettivo.dart';
import 'package:diario_pesca/repositories/catalogo_repository.dart';
import 'package:diario_pesca/repositories/obiettivi_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late CatalogoRepository catalogoRepo;
  late ObiettiviRepository obiettiviRepo;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    catalogoRepo = CatalogoRepository(dbHelper: dbHelper);
    obiettiviRepo = ObiettiviRepository(dbHelper: dbHelper, catalogo: catalogoRepo);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('ObiettiviRepository', () {
    test('salvaObiettivo (insert/update anche con caratteristica al volo), getObiettivi con filtri ed eliminaObiettivo', () async {
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Spigola'));
      final marmorata = await catalogoRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Trota', nome: 'Livrea marmorata'),
      );

      final obGenericoTrota = await obiettiviRepo.salvaObiettivo(
        const Obiettivo(
          specieNome: 'Trota',
          anno: 2026,
          quantita: 20,
        ),
      );
      final obSpecificoTrota = await obiettiviRepo.salvaObiettivo(
        Obiettivo(
          specieNome: 'Trota',
          anno: 2026,
          quantita: 5,
          caratteristica: marmorata,
        ),
      );
      await obiettiviRepo.salvaObiettivo(
        const Obiettivo(
          specieNome: 'Spigola',
          anno: 2025,
          quantita: 10,
          caratteristica: Caratteristica(specieNome: 'Spigola', nome: 'Over 2 kg'),
        ),
      );

      expect(obGenericoTrota.id, isNotNull);
      expect(obSpecificoTrota.id, isNotNull);

      // Aggiornamento quantità
      await obiettiviRepo.salvaObiettivo(
        obGenericoTrota.copyWith(quantita: 25),
      );

      final solo2026 = await obiettiviRepo.getObiettivi(anno: 2026);
      expect(solo2026.length, 2);

      final soloGenerici2026 = await obiettiviRepo.getObiettivi(
        anno: 2026,
        soloGenerici: true,
      );
      expect(soloGenerici2026.length, 1);
      expect(soloGenerici2026.first.quantita, 25);

      final soloSpecifici = await obiettiviRepo.getObiettivi(
        specieNome: 'Trota',
        caratteristicaId: marmorata.id,
        soloGenerici: false,
      );
      expect(soloSpecifici.length, 1);
      expect(soloSpecifici.first.id, obSpecificoTrota.id);
      expect(soloSpecifici.first.caratteristica?.nome, 'Livrea marmorata');

      await obiettiviRepo.eliminaObiettivo(obSpecificoTrota.id!);
      expect((await obiettiviRepo.getObiettivi(anno: 2026)).length, 1);
    });

    test('salvaObiettivo blocca caratteristica appartenente a specie diversa', () async {
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Spigola'));
      final carattSpigola = await catalogoRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Spigola', nome: 'Over 2 kg'),
      );

      expect(
        () => obiettiviRepo.salvaObiettivo(
          Obiettivo(
            specieNome: 'Trota',
            anno: 2026,
            quantita: 3,
            caratteristica: carattSpigola,
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
