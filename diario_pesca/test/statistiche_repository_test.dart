import 'package:diario_pesca/database/database_helper.dart';
import 'package:diario_pesca/models/statistiche/caratteristica.dart';
import 'package:diario_pesca/models/statistiche/obiettivo.dart';
import 'package:diario_pesca/models/statistiche/riepilogo_caratteristica.dart';
import 'package:diario_pesca/models/statistiche/riepilogo_specie.dart';
import 'package:diario_pesca/models/statistiche/specie.dart';
import 'package:diario_pesca/repositories/statistiche_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late Database db;
  late StatisticheRepository statisticheRepo;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    db = await dbHelper.database;
    statisticheRepo = StatisticheRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('StatisticheRepository - Specie', () {
    test('inserisciSpecie, getSpecie (ordine e filtro) ed eliminaSpecie', () async {
      await statisticheRepo.inserisciSpecie(
        const Specie(nome: 'Trota', informazioni: 'Salmonide di torrente'),
      );
      await statisticheRepo.inserisciSpecie(
        const Specie(nome: 'Spigola'),
      );

      final tutte = await statisticheRepo.getSpecie();
      expect(tutte.map((s) => s.nome), ['Spigola', 'Trota']);
      expect(tutte[1].informazioni, 'Salmonide di torrente');

      // Filtro testuale case-insensitive
      final filtrate = await statisticheRepo.getSpecie(filtroNome: 'trot');
      expect(filtrate.length, 1);
      expect(filtrate.first.nome, 'Trota');

      await statisticheRepo.eliminaSpecie('Spigola');
      expect((await statisticheRepo.getSpecie()).map((s) => s.nome), ['Trota']);
    });

    test('aggiornaSpecie propaga la rinomina (CASCADE) ed eliminaSpecie è bloccata se usata in catture (RESTRICT)', () async {
      await statisticheRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      await statisticheRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Trota', nome: 'Livrea marmorata'),
      );
      await statisticheRepo.salvaObiettivo(
        const Obiettivo(specieNome: 'Trota', anno: 2026, quantita: 15),
      );

      final pescataId = await db.insert('Pescata', {
        'data': '2026-11-10',
        'fasciaOraria': 'alba',
        'meteo': 'velato',
      });
      final riepilogo = await statisticheRepo.salvaRiepilogoSpecie(
        RiepilogoSpecie(
          pescataId: pescataId,
          specieNome: 'Trota',
          quantita: 2,
        ),
      );

      // 1. Eliminazione bloccata finché esiste un riepilogo catture (ON DELETE RESTRICT)
      await expectLater(
        () => statisticheRepo.eliminaSpecie('Trota'),
        throwsA(isA<DatabaseException>()),
      );

      // 2. Rinomina con propagazione automatica su tutte le tabelle (ON UPDATE CASCADE)
      await statisticheRepo.aggiornaSpecie(
        nomeOriginale: 'Trota',
        specieAggiornata: const Specie(
          nome: 'Trota Fario',
          informazioni: 'Rinominata',
        ),
      );

      expect(
        (await statisticheRepo.getCaratteristiche(specieNome: 'Trota Fario')).length,
        1,
      );
      expect(
        (await statisticheRepo.getObiettivi(specieNome: 'Trota Fario')).length,
        1,
      );
      expect(
        (await statisticheRepo.getRiepiloghi(specieNome: 'Trota Fario')).length,
        1,
      );

      // 3. Rimossa la cattura, eliminaSpecie riesce e rimuove a cascata caratteristica e obiettivo
      await statisticheRepo.eliminaRiepilogoSpecie(riepilogo.id!);
      await statisticheRepo.eliminaSpecie('Trota Fario');

      expect(await statisticheRepo.getSpecie(), isEmpty);
      expect(await statisticheRepo.getCaratteristiche(), isEmpty);
      expect(await statisticheRepo.getObiettivi(), isEmpty);
    });
  });

  group('StatisticheRepository - Caratteristiche', () {
    test('salvaCaratteristica (insert/update), getCaratteristiche con filtri ed eliminaCaratteristica', () async {
      await statisticheRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      await statisticheRepo.inserisciSpecie(const Specie(nome: 'Spigola'));

      final marmorata = await statisticheRepo.salvaCaratteristica(
        const Caratteristica(
          specieNome: 'Trota',
          nome: 'Livrea marmorata',
          descrizione: 'Autoctona',
        ),
      );
      final trotaOver = await statisticheRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Trota', nome: 'Over 40cm'),
      );
      await statisticheRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Spigola', nome: 'Over 2 kg'),
      );

      expect(marmorata.id, isNotNull);

      // Aggiornamento
      await statisticheRepo.salvaCaratteristica(
        marmorata.copyWith(descrizione: 'Bacino padano'),
      );

      final perSpecie = await statisticheRepo.getCaratteristiche(specieNome: 'Trota');
      expect(perSpecie.map((c) => c.nome), ['Livrea marmorata', 'Over 40cm']);
      expect(perSpecie.first.descrizione, 'Bacino padano');

      final perNome = await statisticheRepo.getCaratteristiche(filtroNome: 'over');
      expect(perNome.length, 2);

      await statisticheRepo.eliminaCaratteristica(trotaOver.id!);
      expect((await statisticheRepo.getCaratteristiche(specieNome: 'Trota')).length, 1);
    });

    test('salvaCaratteristica blocca il cambio specie se già referenziata', () async {
      await statisticheRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      await statisticheRepo.inserisciSpecie(const Specie(nome: 'Spigola'));

      final marmorata = await statisticheRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Trota', nome: 'Livrea marmorata'),
      );
      await statisticheRepo.salvaObiettivo(
        Obiettivo(
          specieNome: 'Trota',
          anno: 2026,
          quantita: 5,
          caratteristica: marmorata,
        ),
      );

      await expectLater(
        () => statisticheRepo.salvaCaratteristica(
          marmorata.copyWith(specieNome: 'Spigola'),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('StatisticheRepository - Obiettivi', () {
    test('salvaObiettivo (insert/update anche con caratteristica al volo), getObiettivi con filtri ed eliminaObiettivo', () async {
      await statisticheRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      await statisticheRepo.inserisciSpecie(const Specie(nome: 'Spigola'));
      final marmorata = await statisticheRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Trota', nome: 'Livrea marmorata'),
      );

      final obGenericoTrota = await statisticheRepo.salvaObiettivo(
        const Obiettivo(
          specieNome: 'Trota',
          anno: 2026,
          quantita: 20,
        ),
      );
      final obSpecificoTrota = await statisticheRepo.salvaObiettivo(
        Obiettivo(
          specieNome: 'Trota',
          anno: 2026,
          quantita: 5,
          caratteristica: marmorata,
        ),
      );
      await statisticheRepo.salvaObiettivo(
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
      await statisticheRepo.salvaObiettivo(
        obGenericoTrota.copyWith(quantita: 25),
      );

      final solo2026 = await statisticheRepo.getObiettivi(anno: 2026);
      expect(solo2026.length, 2);

      final soloGenerici2026 = await statisticheRepo.getObiettivi(
        anno: 2026,
        soloGenerici: true,
      );
      expect(soloGenerici2026.length, 1);
      expect(soloGenerici2026.first.quantita, 25);

      final soloSpecifici = await statisticheRepo.getObiettivi(
        specieNome: 'Trota',
        caratteristicaId: marmorata.id,
        soloGenerici: false,
      );
      expect(soloSpecifici.length, 1);
      expect(soloSpecifici.first.id, obSpecificoTrota.id);
      expect(soloSpecifici.first.caratteristica?.nome, 'Livrea marmorata');

      await statisticheRepo.eliminaObiettivo(obSpecificoTrota.id!);
      expect((await statisticheRepo.getObiettivi(anno: 2026)).length, 1);
    });

    test('salvaObiettivo blocca caratteristica appartenente a specie diversa', () async {
      await statisticheRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      await statisticheRepo.inserisciSpecie(const Specie(nome: 'Spigola'));
      final carattSpigola = await statisticheRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Spigola', nome: 'Over 2 kg'),
      );

      expect(
        () => statisticheRepo.salvaObiettivo(
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

  group('StatisticheRepository - Riepiloghi Specie e Dettagli', () {
    test('salvaRiepilogoSpecie (insert/update transazionale) e getRiepiloghi con filtri', () async {
      await statisticheRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      final marmorata = await statisticheRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Trota', nome: 'Livrea marmorata'),
      );
      final ibrido = await statisticheRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Trota', nome: 'Ibrido'),
      );

      final pescata1Id = await db.insert('Pescata', {
        'data': '2026-11-10',
        'fasciaOraria': 'alba',
        'meteo': 'velato',
      });
      final pescata2Id = await db.insert('Pescata', {
        'data': '2026-11-12',
        'fasciaOraria': 'sera',
        'meteo': 'sereno',
      });

      // Inserimento iniziale con 2 dettagli per caratteristica
      final salvato = await statisticheRepo.salvaRiepilogoSpecie(
        RiepilogoSpecie(
          pescataId: pescata1Id,
          specieNome: 'Trota',
          quantita: 4,
          dettagli: [
            RiepilogoCaratteristica(
              riepilogoSpecieId: 0,
              caratteristica: marmorata,
              quantita: 2,
            ),
            RiepilogoCaratteristica(
              riepilogoSpecieId: 0,
              caratteristica: ibrido,
              quantita: 1,
            ),
          ],
        ),
      );

      expect(salvato.id, isNotNull);
      expect(salvato.dettagli.length, 2);
      expect(
        salvato.dettagli.every((d) => d.riepilogoSpecieId == salvato.id),
        isTrue,
      );

      // Secondo riepilogo su pescata 2
      await statisticheRepo.salvaRiepilogoSpecie(
        RiepilogoSpecie(
          pescataId: pescata2Id,
          specieNome: 'Trota',
          quantita: 2,
        ),
      );

      // Aggiornamento del primo riepilogo (cambio quantità e riduco a 1 dettaglio)
      await statisticheRepo.salvaRiepilogoSpecie(
        salvato.copyWith(
          quantita: 5,
          dettagli: [
            RiepilogoCaratteristica(
              riepilogoSpecieId: salvato.id!,
              caratteristica: marmorata,
              quantita: 3,
            ),
          ],
        ),
      );

      final perPescata1 = await statisticheRepo.getRiepiloghi(pescataId: pescata1Id);
      expect(perPescata1.length, 1);
      expect(perPescata1.first.quantita, 5);
      expect(perPescata1.first.dettagli.length, 1);
      expect(perPescata1.first.dettagli.single.quantita, 3);
      expect(perPescata1.first.dettagli.single.caratteristica.nome, 'Livrea marmorata');

      final perSpecie = await statisticheRepo.getRiepiloghi(specieNome: 'Trota');
      expect(perSpecie.length, 2);
    });

    test('salvaRiepilogoSpecie valida dettaglio <= totale, blocca altra specie ed eliminaRiepilogoSpecie', () async {
      await statisticheRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      await statisticheRepo.inserisciSpecie(const Specie(nome: 'Spigola'));
      final carattTrota = await statisticheRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Trota', nome: 'Livrea marmorata'),
      );
      final carattSpigola = await statisticheRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Spigola', nome: 'Over 2 kg'),
      );

      final pescataId = await db.insert('Pescata', {
        'data': '2026-11-13',
        'fasciaOraria': 'mattina',
        'meteo': 'sereno',
      });

      // Dettaglio superiore al totale -> ArgumentError
      expect(
        () => statisticheRepo.salvaRiepilogoSpecie(
          RiepilogoSpecie(
            pescataId: pescataId,
            specieNome: 'Trota',
            quantita: 2,
            dettagli: [
              RiepilogoCaratteristica(
                riepilogoSpecieId: 0,
                caratteristica: carattTrota,
                quantita: 3,
              ),
            ],
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Caratteristica di altra specie -> DatabaseException
      expect(
        () => statisticheRepo.salvaRiepilogoSpecie(
          RiepilogoSpecie(
            pescataId: pescataId,
            specieNome: 'Trota',
            quantita: 2,
            dettagli: [
              RiepilogoCaratteristica(
                riepilogoSpecieId: 0,
                caratteristica: carattSpigola,
                quantita: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );

      final valido = await statisticheRepo.salvaRiepilogoSpecie(
        RiepilogoSpecie(
          pescataId: pescataId,
          specieNome: 'Trota',
          quantita: 2,
        ),
      );

      await statisticheRepo.eliminaRiepilogoSpecie(valido.id!);
      expect(await statisticheRepo.getRiepiloghi(pescataId: pescataId), isEmpty);
    });
  });
}