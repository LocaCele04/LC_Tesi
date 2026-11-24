import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/models/catalogo/caratteristica.dart';
import 'package:diario_pesca/models/catalogo/condizione.dart';
import 'package:diario_pesca/models/catalogo/esca.dart';
import 'package:diario_pesca/models/catalogo/specie.dart';
import 'package:diario_pesca/models/catalogo/valore_condizione.dart';
import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/foto.dart';
import 'package:diario_pesca/models/obiettivi/obiettivo.dart';
import 'package:diario_pesca/models/pescate/pescata.dart';
import 'package:diario_pesca/models/pescate/riepilogo_specie.dart';
import 'package:diario_pesca/repositories/catalogo_repository.dart';
import 'package:diario_pesca/repositories/eccezioni.dart';
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

      await inserisciSpotDiProva('Ponte Ruga');
      final pescata = await pescateRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 10),
          fasciaOraria: FasciaOraria.alba,
          spotNome: 'Ponte Ruga',
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
            ),
            Foto(
              percorso: '/img/esca1_b.jpg',
              percorsoThumbnail: '/img/thumb_esca1_b.jpg',
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

  group('CatalogoRepository - Creazione al volo con nome già esistente', () {
    test('un\'esca nuova con nome esistente viene riusata solo se non si perdono dati', () async {
      final minnow = await catalogoRepo.salvaEsca(
        const Esca(
          nome: 'Minnow 7cm',
          descrizione: 'Affondante',
          foto: [
            Foto(percorso: '/img/minnow.jpg', percorsoThumbnail: '/img/t_minnow.jpg'),
          ],
        ),
      );

      // Ricerca per nome senza distinzione di maiuscole e spazi
      final trovata = await catalogoRepo.getEscaPerNome('  minnow 7CM ');
      expect(trovata?.id, minnow.id);
      expect(trovata?.foto.length, 1);
      expect(await catalogoRepo.getEscaPerNome('Jerk'), isNull);

      await inserisciSpotDiProva('Ponte Ruga');
      Pescata conEsca(Esca esca) => Pescata(
            data: DateTime(2026, 11, 14),
            fasciaOraria: FasciaOraria.alba,
            spotNome: 'Ponte Ruga',
            esche: [esca],
          );

      // Solo il nome: nessun dato da perdere, viene riusata l'esca esistente
      final pescata = await pescateRepo.salvaPescata(
        conEsca(const Esca(nome: 'MINNOW 7cm')),
      );
      expect(pescata.esche.single.isNuovo, isFalse);
      expect(pescata.esche.single.id, minnow.id);
      expect(pescata.esche.single.descrizione, 'Affondante');
      expect((await catalogoRepo.getEsche()).length, 1);

      // Foto nuove o descrizione diversa: salvataggio annullato con avviso
      await expectLater(
        () => pescateRepo.salvaPescata(conEsca(const Esca(
          nome: 'Minnow 7cm',
          foto: [
            Foto(percorso: '/img/altra.jpg', percorsoThumbnail: '/img/t_altra.jpg'),
          ],
        ))),
        throwsA(
          isA<NomeDuplicatoException>()
              .having((e) => e.idEsistente, 'idEsistente', minnow.id)
              .having((e) => e.tipo, 'tipo', 'Esca'),
        ),
      );
      await expectLater(
        () => pescateRepo.salvaPescata(conEsca(
          const Esca(nome: 'Minnow 7cm', descrizione: 'Galleggiante'),
        )),
        throwsA(isA<NomeDuplicatoException>()),
      );

      // Le transazioni annullate non lasciano pescate né esche in più
      expect((await pescateRepo.getPescate()).length, 1);
      expect((await catalogoRepo.getEsche()).length, 1);
    });

    test('una caratteristica nuova con nome esistente viene riusata solo se la descrizione non cambia', () async {
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Spigola'));
      final over40 = await catalogoRepo.salvaCaratteristica(
        const Caratteristica(
          specieNome: 'Trota',
          nome: 'Over 40',
          descrizione: 'Oltre 40 cm',
        ),
      );

      final trovata = await catalogoRepo.getCaratteristicaPerNome(
        specieNome: 'Trota',
        nome: 'over 40',
      );
      expect(trovata?.id, over40.id);
      expect(
        await catalogoRepo.getCaratteristicaPerNome(
          specieNome: 'Spigola',
          nome: 'Over 40',
        ),
        isNull,
      );

      // Stesso nome senza descrizione: riusata
      final obiettivo = await obiettiviRepo.salvaObiettivo(
        const Obiettivo(
          specieNome: 'Trota',
          anno: 2026,
          quantita: 3,
          caratteristica: Caratteristica(specieNome: 'Trota', nome: 'OVER 40'),
        ),
      );
      expect(obiettivo.caratteristica?.id, over40.id);
      expect(obiettivo.caratteristica?.descrizione, 'Oltre 40 cm');

      // Stesso nome con descrizione diversa: salvataggio annullato
      await expectLater(
        () => obiettiviRepo.salvaObiettivo(
          const Obiettivo(
            specieNome: 'Trota',
            anno: 2026,
            quantita: 5,
            caratteristica: Caratteristica(
              specieNome: 'Trota',
              nome: 'Over 40',
              descrizione: 'Oltre 45 cm',
            ),
          ),
        ),
        throwsA(
          isA<NomeDuplicatoException>()
              .having((e) => e.tipo, 'tipo', 'Caratteristica'),
        ),
      );
      expect((await obiettiviRepo.getObiettivi()).length, 1);
      expect((await catalogoRepo.getCaratteristiche(specieNome: 'Trota')).length, 1);
    });
  });

  group('CatalogoRepository - Condizioni', () {
    test('getCondizioni restituisce le condizioni di base, filtrabili per ambiente e per stato', () async {
      final tutte = await catalogoRepo.getCondizioni();
      expect(tutte.map((c) => c.nome), ['Livello', 'Trasparenza', 'Fondo', 'Meteo']);
      expect(
        tutte.first.valori.map((v) => v.nome),
        ['Secca', 'Magra', 'Normale', 'Morbida', 'Piena'],
      );
      expect(tutte.every((c) => !c.isNuovo && c.attiva), isTrue);

      expect(
        (await catalogoRepo.getCondizioni(ambienteNome: 'Lago')).map((c) => c.nome),
        ['Meteo'],
      );
      expect((await catalogoRepo.getCondizioni(ambienteNome: 'Torrente')).length, 4);

      // Nuova condizione per il mare, collegata al Mare insieme al Meteo
      final statoMare = await catalogoRepo.salvaCondizione(
        const Condizione(
          nome: 'Stato del mare',
          ordine: 4,
          valori: [
            ValoreCondizione(nome: 'Calmo'),
            ValoreCondizione(nome: 'Poco mosso'),
            ValoreCondizione(nome: 'Mosso'),
          ],
        ),
      );
      expect(statoMare.id, isNotNull);
      expect(statoMare.valori.map((v) => v.ordine), [0, 1, 2]);
      expect(statoMare.valori.every((v) => v.condizioneId == statoMare.id), isTrue);

      final meteo = tutte.firstWhere((c) => c.nome == 'Meteo');
      await catalogoRepo.impostaCondizioniAmbiente('Mare', [meteo.id!, statoMare.id!]);
      expect(
        (await catalogoRepo.getCondizioni(ambienteNome: 'Mare')).map((c) => c.nome),
        ['Meteo', 'Stato del mare'],
      );

      // Condizione disattivata: esclusa con soloAttive
      await catalogoRepo.salvaCondizione(statoMare.copyWith(attiva: false));
      expect(
        (await catalogoRepo.getCondizioni(ambienteNome: 'Mare', soloAttive: true))
            .map((c) => c.nome),
        ['Meteo'],
      );
    });

    test('salvaCondizione rinomina, aggiunge ed elimina valori; un valore usato si può solo disattivare', () async {
      await inserisciSpotDiProva('Ponte Ruga');
      final condizioni = await catalogoRepo.getCondizioni();
      final livello = condizioni.firstWhere((c) => c.nome == 'Livello');
      final fondo = condizioni.firstWhere((c) => c.nome == 'Fondo');
      final morbida = livello.valori.firstWhere((v) => v.nome == 'Morbida');

      final pescata = await pescateRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 10),
          fasciaOraria: FasciaOraria.alba,
          spotNome: 'Ponte Ruga',
          valoriCondizioni: [morbida],
        ),
      );

      // Rinomino "Secca", tolgo "Magra" (mai usata) e aggiungo un valore in fondo
      final valori = livello.valori
          .where((v) => v.nome != 'Magra')
          .map((v) => v.nome == 'Secca' ? v.copyWith(nome: 'Asciutta') : v)
          .toList();
      final aggiornato = await catalogoRepo.salvaCondizione(
        livello.copyWith(valori: [...valori, const ValoreCondizione(nome: 'Piena eccezionale')]),
      );
      expect(
        aggiornato.valori.map((v) => v.nome),
        ['Asciutta', 'Normale', 'Morbida', 'Piena', 'Piena eccezionale'],
      );
      expect(aggiornato.valori.map((v) => v.ordine), [0, 1, 2, 3, 4]);

      // Togliere un valore usato: rifiutato, nulla cambia
      await expectLater(
        () => catalogoRepo.salvaCondizione(
          aggiornato.copyWith(
            valori: aggiornato.valori.where((v) => v.nome != 'Morbida').toList(),
          ),
        ),
        throwsStateError,
      );
      final dopoRifiuto = (await catalogoRepo.getCondizioni())
          .firstWhere((c) => c.nome == 'Livello');
      expect(dopoRifiuto.valori.length, 5);

      // Disattivarlo invece è ammesso: sparisce dai valori attivi, non dalla pescata
      await catalogoRepo.salvaCondizione(
        dopoRifiuto.copyWith(
          valori: dopoRifiuto.valori
              .map((v) => v.nome == 'Morbida' ? v.copyWith(attivo: false) : v)
              .toList(),
        ),
      );
      final soloAttive = (await catalogoRepo.getCondizioni(soloAttive: true))
          .firstWhere((c) => c.nome == 'Livello');
      expect(soloAttive.valori.map((v) => v.nome), isNot(contains('Morbida')));
      final completa = await pescateRepo.getPescataCompleta(pescata.id!);
      expect(completa!.valoriCondizioni.single.nome, 'Morbida');

      // Eliminazione: bloccata per una condizione usata, ammessa per una mai usata
      await expectLater(
        () => catalogoRepo.eliminaCondizione(livello.id!),
        throwsA(isA<DatabaseException>()),
      );
      await catalogoRepo.eliminaCondizione(fondo.id!);
      expect(
        (await catalogoRepo.getCondizioni()).map((c) => c.nome),
        ['Livello', 'Trasparenza', 'Meteo'],
      );
    });

    test('copiaCondizioniAmbiente e getCondizioniPerForm mostrano anche i dati già salvati', () async {
      await db.insert('Ambiente', {'nome': 'Laterale'});
      await catalogoRepo.copiaCondizioniAmbiente(
        daAmbiente: 'Torrente',
        aAmbiente: 'Laterale',
      );
      expect(
        (await catalogoRepo.getCondizioni(ambienteNome: 'Laterale')).map((c) => c.nome),
        ['Livello', 'Trasparenza', 'Fondo', 'Meteo'],
      );

      await inserisciSpotDiProva('Ponte Ruga');
      final condizioni = await catalogoRepo.getCondizioni();
      Condizione cond(String nome) => condizioni.firstWhere((c) => c.nome == nome);
      final scuro = cond('Fondo').valori.firstWhere((v) => v.nome == 'Scuro');
      final sereno = cond('Meteo').valori.firstWhere((v) => v.nome == 'Sereno');

      final pescata = await pescateRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 10),
          fasciaOraria: FasciaOraria.alba,
          spotNome: 'Ponte Ruga',
          valoriCondizioni: [scuro, sereno],
        ),
      );

      // Il Torrente non prevede più il Fondo e il valore "Sereno" viene disattivato
      await catalogoRepo.impostaCondizioniAmbiente('Torrente', [
        cond('Livello').id!,
        cond('Trasparenza').id!,
        cond('Meteo').id!,
      ]);
      await catalogoRepo.salvaCondizione(
        cond('Meteo').copyWith(
          valori: cond('Meteo')
              .valori
              .map((v) => v.nome == 'Sereno' ? v.copyWith(attivo: false) : v)
              .toList(),
        ),
      );

      // Form di una pescata nuova: solo condizioni previste e valori attivi
      final formNuova = await catalogoRepo.getCondizioniPerForm(ambienteNome: 'Torrente');
      expect(formNuova.map((c) => c.nome), ['Livello', 'Trasparenza', 'Meteo']);
      expect(
        formNuova.last.valori.map((v) => v.nome),
        isNot(contains('Sereno')),
      );

      // Form della pescata salvata: compaiono anche Fondo e "Sereno"
      final formEsistente = await catalogoRepo.getCondizioniPerForm(
        ambienteNome: 'Torrente',
        pescataId: pescata.id,
      );
      expect(
        formEsistente.map((c) => c.nome),
        ['Livello', 'Trasparenza', 'Fondo', 'Meteo'],
      );
      expect(
        formEsistente.firstWhere((c) => c.nome == 'Meteo').valori.map((v) => v.nome),
        contains('Sereno'),
      );
    });
  });
}
