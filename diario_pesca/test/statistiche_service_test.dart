import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/models/catalogo/caratteristica.dart';
import 'package:diario_pesca/models/catalogo/specie.dart';
import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/pescate/pescata.dart';
import 'package:diario_pesca/models/pescate/riepilogo_caratteristica.dart';
import 'package:diario_pesca/models/pescate/riepilogo_specie.dart';
import 'package:diario_pesca/repositories/catalogo_repository.dart';
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
  late PescateRepository pescateRepo;
  late StatisticheService statistiche;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    db = await dbHelper.database;
    catalogoRepo = CatalogoRepository(dbHelper: dbHelper);
    pescateRepo = PescateRepository(dbHelper: dbHelper, catalogo: catalogoRepo);
    statistiche = StatisticheService(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('StatisticheService - Riepiloghi', () {
    test('getRiepiloghi filtra per pescata e per specie, con i dettagli per caratteristica', () async {
      await db.insert('Categoria', {'nome': 'Generica'});
      await db.insert('Spot', {
        'nome': 'Ponte Vecchio',
        'ambiente': 'Torrente',
        'categoria_nome': 'Generica',
      });
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Cavedano'));
      final marmorata = await catalogoRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Trota', nome: 'Livrea marmorata'),
      );

      final pescata1 = await pescateRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 10),
          fasciaOraria: FasciaOraria.alba,
          spotNome: 'Ponte Vecchio',
          riepiloghiSpecie: [
            RiepilogoSpecie(
              specieNome: 'Trota',
              quantita: 5,
              dettagli: [
                RiepilogoCaratteristica(caratteristica: marmorata, quantita: 3),
              ],
            ),
            const RiepilogoSpecie(specieNome: 'Cavedano', quantita: 1),
          ],
        ),
      );
      await pescateRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 12),
          fasciaOraria: FasciaOraria.sera,
          spotNome: 'Ponte Vecchio',
          riepiloghiSpecie: const [
            RiepilogoSpecie(specieNome: 'Trota', quantita: 2),
          ],
        ),
      );

      final perPescata1 = await statistiche.getRiepiloghi(pescataId: pescata1.id);
      expect(perPescata1.map((r) => r.specieNome), ['Cavedano', 'Trota']);
      final trota = perPescata1.firstWhere((r) => r.specieNome == 'Trota');
      expect(trota.quantita, 5);
      expect(trota.dettagli.single.quantita, 3);
      expect(trota.dettagli.single.caratteristica.nome, 'Livrea marmorata');

      final perSpecie = await statistiche.getRiepiloghi(specieNome: 'Trota');
      expect(perSpecie.length, 2);
      expect(perSpecie.fold<int>(0, (somma, r) => somma + r.quantita), 7);

      expect(await statistiche.getRiepiloghi(specieNome: 'Luccio'), isEmpty);
    });
  });
}
