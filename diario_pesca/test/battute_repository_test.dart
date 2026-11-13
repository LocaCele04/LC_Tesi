import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../lib/database/database_helper.dart';
import '../lib/models/battute/cattura_memorabile.dart';
import '../lib/models/battute/esca.dart';
import '../lib/models/battute/foto.dart';
import '../lib/models/battute/pescata.dart';
import '../lib/models/battute/pianificazione.dart';
import '../lib/models/enums.dart';
import '../lib/models/statistiche/caratteristica.dart';
import '../lib/repositories/battute_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late BattuteRepository battuteRepo;

  setUp(() async {
    await DatabaseHelper.instance.resetPerSviluppo();
    db = await DatabaseHelper.instance.database;
    battuteRepo = BattuteRepository();
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
  });

  group('BattuteRepository - Esche', () {
    test('salvaEsca (insert/update), getEsche (ordine e filtro) ed eliminaEsca', () async {
      final minnow = await battuteRepo.salvaEsca(
        const Esca(nome: 'Minnow 7cm', descrizione: 'Livrea vairone'),
      );
      final cucchiaino = await battuteRepo.salvaEsca(
        const Esca(nome: 'Cucchiaino #2'),
      );

      expect(minnow.id, isNotNull);
      expect(cucchiaino.id, isNotNull);

      // Aggiornamento
      await battuteRepo.salvaEsca(
        minnow.copyWith(descrizione: 'Affondante 8g'),
      );

      final tutte = await battuteRepo.getEsche();
      expect(tutte.map((e) => e.nome), ['Cucchiaino #2', 'Minnow 7cm']);
      expect(tutte[1].descrizione, 'Affondante 8g');

      // Filtro testuale case-insensitive
      final filtrate = await battuteRepo.getEsche(filtroNome: 'minnow');
      expect(filtrate.length, 1);
      expect(filtrate.first.id, minnow.id);

      // Eliminazione
      await battuteRepo.eliminaEsca(cucchiaino.id!);
      expect((await battuteRepo.getEsche()).length, 1);
    });
  });

  group('BattuteRepository - Pianificazioni', () {
    test('salvaPianificazione, getPianificazioni con filtri ed eliminaPianificazione', () async {
      await db.insert('Spot', {'nome': 'Ponte Vecchio', 'ambiente': 'Torrente'});
      await db.insert('Spot', {'nome': 'Foce Nord', 'ambiente': 'Mare'});

      final p1 = await battuteRepo.salvaPianificazione(
        Pianificazione(
          data: DateTime(2026, 11, 15),
          fasciaOraria: FasciaOraria.alba,
          spotNome: 'Ponte Vecchio',
          note: 'Uscita mattutina',
        ),
      );
      final p2 = await battuteRepo.salvaPianificazione(
        Pianificazione(
          data: DateTime(2026, 11, 22),
          fasciaOraria: FasciaOraria.tramonto,
          spotNome: 'Foce Nord',
        ),
      );

      expect(p1.id, isNotNull);
      expect(p2.id, isNotNull);

      // Aggiornamento
      await battuteRepo.salvaPianificazione(
        p1.copyWith(fasciaOraria: FasciaOraria.mattina),
      );

      final perSpot = await battuteRepo.getPianificazioni(spotNome: 'Ponte Vecchio');
      expect(perSpot.length, 1);
      expect(perSpot.first.fasciaOraria, FasciaOraria.mattina);

      final perData = await battuteRepo.getPianificazioni(
        daData: DateTime(2026, 11, 20),
        aData: DateTime(2026, 11, 30),
      );
      expect(perData.map((p) => p.spotNome), ['Foce Nord']);

      await battuteRepo.eliminaPianificazione(p2.id!);
      expect((await battuteRepo.getPianificazioni()).length, 1);
    });
  });

  group('BattuteRepository - Pescate', () {
    test('salvaPescata (insert/update con esche e foto) e getPescate con filtri combinati', () async {
      await db.insert('Spot', {'nome': 'Ponte Vecchio', 'ambiente': 'Torrente'});
      final esca1 = await battuteRepo.salvaEsca(const Esca(nome: 'Minnow'));
      final esca2 = await battuteRepo.salvaEsca(const Esca(nome: 'Ondulante'));

      // Prima pescata con esche e foto
      final salvata = await battuteRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 10),
          fasciaOraria: FasciaOraria.alba,
          meteo: Meteo.velato,
          trasparenza: Trasparenza.velata,
          fondo: Fondo.normale,
          livello: Livello.morbida,
          tempAcqua: 11.5,
          tempAria: 8.0,
          spotNome: 'Ponte Vecchio',
          esche: [esca1, esca2],
          foto: const [
            Foto(
              percorso: '/img/p1.jpg',
              percorsoThumbnail: '/img/thumb_p1.jpg',
              pescataId: 0,
            ),
          ],
        ),
      );

      expect(salvata.id, isNotNull);
      expect(salvata.foto.single.id, isNotNull);
      expect(salvata.foto.single.pescataId, salvata.id);

      // Seconda pescata con parametri diversi
      await battuteRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 12),
          fasciaOraria: FasciaOraria.sera,
          meteo: Meteo.sereno,
          trasparenza: Trasparenza.chiara,
          livello: Livello.magra,
          spotNome: 'Ponte Vecchio',
        ),
      );

      // Aggiornamento prima pescata (riduco a 1 esca e cambio meteo)
      await battuteRepo.salvaPescata(
        salvata.copyWith(
          meteo: Meteo.coperto,
          esche: [esca1],
        ),
      );

      final filtrate = await battuteRepo.getPescate(
        spotNome: 'Ponte Vecchio',
        meteo: Meteo.coperto,
        fasciaOraria: FasciaOraria.alba,
        trasparenza: Trasparenza.velata,
        livello: Livello.morbida,
      );
      expect(filtrate.length, 1);
      expect(filtrate.first.id, salvata.id);

      final ultimeUna = await battuteRepo.getPescate(limit: 1);
      expect(ultimeUna.length, 1);
      expect(ultimeUna.first.data, DateTime(2026, 11, 12));
    });

    test('eliminaPescata rimuove i figli collegati ma preserva Spot ed Esche', () async {
      await db.insert('Spot', {'nome': 'Ponte Vecchio', 'ambiente': 'Torrente'});
      await db.insert('Specie', {'nome': 'Trota'});
      final esca = await battuteRepo.salvaEsca(const Esca(nome: 'Minnow'));

      final pescata = await battuteRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 10),
          fasciaOraria: FasciaOraria.mattina,
          meteo: Meteo.sereno,
          spotNome: 'Ponte Vecchio',
          esche: [esca],
          foto: const [
            Foto(
              percorso: '/img/p.jpg',
              percorsoThumbnail: '/img/tp.jpg',
              pescataId: 0,
            ),
          ],
        ),
      );

      await battuteRepo.salvaCatturaMemorabile(
        CatturaMemorabile(
          pescataId: pescata.id!,
          specieNome: 'Trota',
          escaId: esca.id,
        ),
      );

      await battuteRepo.eliminaPescata(pescata.id!);

      expect(await battuteRepo.getPescataCompleta(pescata.id!), isNull);
      expect(await battuteRepo.getCattureMemorabili(), isEmpty);
      expect(
        await db.query('Spot', where: 'nome = ?', whereArgs: ['Ponte Vecchio']),
        isNotEmpty,
      );
      expect((await battuteRepo.getEsche()).length, 1);
    });
  });

  group('BattuteRepository - Catture Memorabili e Dettaglio Completo', () {
    test('salvaCatturaMemorabile, getCattureMemorabili con filtri ed eliminaCatturaMemorabile', () async {
      await db.insert('Specie', {'nome': 'Trota'});
      await db.insert('Specie', {'nome': 'Spigola'});
      final carattId = await db.insert('Caratteristica', {
        'specie_nome': 'Trota',
        'nome': 'Livrea marmorata',
      });
      final marmorata = Caratteristica(
        id: carattId,
        specieNome: 'Trota',
        nome: 'Livrea marmorata',
      );
      final esca = await battuteRepo.salvaEsca(const Esca(nome: 'Minnow 7cm'));

      final pescata = await battuteRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 11),
          fasciaOraria: FasciaOraria.tramonto,
          meteo: Meteo.variabile,
        ),
      );

      final catturaTrota = await battuteRepo.salvaCatturaMemorabile(
        CatturaMemorabile(
          descrizione: 'Bellissima marmorata',
          pescataId: pescata.id!,
          specieNome: 'Trota',
          escaId: esca.id,
          caratteristiche: [marmorata],
          foto: const [
            Foto(
              percorso: '/img/c1.jpg',
              percorsoThumbnail: '/img/tc1.jpg',
              catturaMemorabileId: 0,
            ),
          ],
        ),
      );

      final catturaSpigola = await battuteRepo.salvaCatturaMemorabile(
        CatturaMemorabile(
          pescataId: pescata.id!,
          specieNome: 'Spigola',
        ),
      );

      expect(catturaTrota.id, isNotNull);
      expect(catturaTrota.foto.single.catturaMemorabileId, catturaTrota.id);

      final soloTrote = await battuteRepo.getCattureMemorabili(
        specieNome: 'Trota',
        escaId: esca.id,
      );
      expect(soloTrote.length, 1);
      expect(soloTrote.first.caratteristiche.map((c) => c.nome), ['Livrea marmorata']);
      expect(soloTrote.first.foto.length, 1);

      await battuteRepo.eliminaCatturaMemorabile(catturaSpigola.id!);
      expect((await battuteRepo.getCattureMemorabili()).length, 1);
    });

    test('getPescataCompleta ricostruisce esche, foto, catture e riepiloghi specie', () async {
      await db.insert('Spot', {'nome': 'Ponte Vecchio', 'ambiente': 'Torrente'});
      await db.insert('Specie', {'nome': 'Trota'});
      final carattId = await db.insert('Caratteristica', {
        'specie_nome': 'Trota',
        'nome': 'Livrea marmorata',
      });
      final marmorata = Caratteristica(
        id: carattId,
        specieNome: 'Trota',
        nome: 'Livrea marmorata',
      );
      final esca = await battuteRepo.salvaEsca(const Esca(nome: 'Minnow 7cm'));

      // 1. Salva pescata con esca e foto
      final pescata = await battuteRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 13),
          fasciaOraria: FasciaOraria.alba,
          meteo: Meteo.velato,
          spotNome: 'Ponte Vecchio',
          esche: [esca],
          foto: const [
            Foto(
              percorso: '/img/pescata.jpg',
              percorsoThumbnail: '/img/thumb_pescata.jpg',
              pescataId: 0,
            ),
          ],
        ),
      );

      // 2. Aggiunge cattura memorabile con caratteristica e foto
      await battuteRepo.salvaCatturaMemorabile(
        CatturaMemorabile(
          descrizione: 'Over 45cm',
          pescataId: pescata.id!,
          specieNome: 'Trota',
          escaId: esca.id,
          caratteristiche: [marmorata],
          foto: const [
            Foto(
              percorso: '/img/cattura.jpg',
              percorsoThumbnail: '/img/thumb_cattura.jpg',
              catturaMemorabileId: 0,
            ),
          ],
        ),
      );

      // 3. Aggiunge riepilogo specie e dettaglio direttamente su DB
      final riepilogoId = await db.insert('RiepilogoSpecie', {
        'pescata_id': pescata.id!,
        'specie_nome': 'Trota',
        'quantita': 3,
      });
      await db.insert('DettaglioRiepilogo', {
        'riepilogo_specie_id': riepilogoId,
        'caratteristica_id': carattId,
        'specie_nome': 'Trota',
        'quantita': 1,
      });

      final completa = await battuteRepo.getPescataCompleta(pescata.id!);

      expect(completa, isNotNull);
      expect(completa!.spotNome, 'Ponte Vecchio');
      expect(completa.esche.map((e) => e.nome), ['Minnow 7cm']);
      expect(completa.foto.map((f) => f.percorso), ['/img/pescata.jpg']);
      expect(completa.cattureMemorabili.length, 1);
      expect(
        completa.cattureMemorabili.first.caratteristiche.map((c) => c.nome),
        ['Livrea marmorata'],
      );
      expect(
        completa.cattureMemorabili.first.foto.map((f) => f.percorso),
        ['/img/cattura.jpg'],
      );
      expect(completa.riepiloghiSpecie.length, 1);
      expect(completa.riepiloghiSpecie.first.quantita, 3);
      expect(completa.riepiloghiSpecie.first.dettagli.single.quantita, 1);
    });

    test('salvaCatturaMemorabile blocca caratteristiche appartenenti a specie diversa', () async {
      await db.insert('Specie', {'nome': 'Trota'});
      await db.insert('Specie', {'nome': 'Spigola'});
      final carattSpigolaId = await db.insert('Caratteristica', {
        'specie_nome': 'Spigola',
        'nome': 'Over 2 kg',
      });
      final carattSpigola = Caratteristica(
        id: carattSpigolaId,
        specieNome: 'Spigola',
        nome: 'Over 2 kg',
      );

      final pescata = await battuteRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 13),
          fasciaOraria: FasciaOraria.notte,
          meteo: Meteo.sereno,
        ),
      );

      expect(
        () => battuteRepo.salvaCatturaMemorabile(
          CatturaMemorabile(
            pescataId: pescata.id!,
            specieNome: 'Trota',
            caratteristiche: [carattSpigola],
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}