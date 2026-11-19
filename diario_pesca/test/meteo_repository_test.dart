import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/meteo/cella_meteo.dart';
import 'package:diario_pesca/models/meteo/meteo_giorno.dart';
import 'package:diario_pesca/models/meteo/meteo_ora.dart';
import 'package:diario_pesca/models/pescate/pescata.dart';
import 'package:diario_pesca/models/territorio/categoria.dart';
import 'package:diario_pesca/models/territorio/coordinata.dart';
import 'package:diario_pesca/models/territorio/spot.dart';
import 'package:diario_pesca/repositories/meteo_repository.dart';
import 'package:diario_pesca/repositories/pescate_repository.dart';
import 'package:diario_pesca/repositories/territorio_repository.dart';
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
  late TerritorioRepository territorioRepo;
  late PescateRepository pescateRepo;
  late MeteoRepository meteoRepo;
  late StatisticheService statistiche;

  const cellaBrembo = CellaMeteo(latitudine: 45.75, longitudine: 9.625, elevazione: 820);

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    db = await dbHelper.database;
    territorioRepo = TerritorioRepository(dbHelper: dbHelper);
    pescateRepo = PescateRepository(dbHelper: dbHelper);
    meteoRepo = MeteoRepository(dbHelper: dbHelper);
    statistiche = StatisticheService(dbHelper: dbHelper, meteo: meteoRepo);
    await territorioRepo.inserisciCategoria(const Categoria(nome: 'Valle'));
  });

  tearDown(() async {
    await dbHelper.close();
  });

  Future<void> salvaSpot(String nome, List<(double, double)> punti, {String? nomeOriginale}) =>
      territorioRepo.salvaSpotConCoordinate(
        Spot(
          nome: nome,
          ambiente: 'Torrente',
          categoriaNome: 'Valle',
          coordinate: [
            for (var i = 0; i < punti.length; i++)
              Coordinata(ordine: i, latitudine: punti[i].$1, longitudine: punti[i].$2),
          ],
        ),
        nomeOriginale: nomeOriginale,
      );

  Future<Pescata> salvaPescata(String spot, DateTime data) => pescateRepo.salvaPescata(
        Pescata(data: data, fasciaOraria: FasciaOraria.alba, spotNome: spot),
      );

  /// Giorni fittizi per una pescata del giorno [data]; la pioggia del giorno
  /// i-esimo (0 = il più vecchio) vale [pioggia] (i).
  List<MeteoGiorno> giorniFinti(
    DateTime data, {
    FonteMeteo fonte = FonteMeteo.archivio,
    double Function(int i)? pioggia,
  }) {
    final giorni = MeteoRepository.giorniRichiesti(data);
    return [
      for (var i = 0; i < giorni.length; i++)
        MeteoGiorno(
          data: giorni[i],
          pioggiaMm: pioggia?.call(i) ?? 0,
          tempMin: 2,
          tempMax: 10,
          pressioneMedia: 1015,
          ventoMax: 12,
          rafficaMax: 25,
          direzioneVento: 180,
          fonte: fonte,
        ),
    ];
  }

  List<MeteoOra> oreFinte(DateTime data, {FonteMeteo fonte = FonteMeteo.archivio}) => [
        for (final ora in MeteoRepository.oreRichieste(data))
          MeteoOra(dataOra: ora, pioggiaMm: 0, temperatura: 6, pressione: 1014, fonte: fonte),
      ];

  group('MeteoRepository - Intervalli e pescate da scaricare', () {
    test('giorniRichiesti e oreRichieste coprono 30 giorni + il giorno della pescata e 2 giorni orari', () {
      final data = DateTime(2026, 3, 15);
      final giorni = MeteoRepository.giorniRichiesti(data);
      expect(giorni.length, 31);
      expect(giorni.first, DateTime(2026, 2, 13));
      expect(giorni.last, data);

      final ore = MeteoRepository.oreRichieste(data);
      expect(ore.first, DateTime(2026, 3, 14).toUtc());
      expect(ore.every((o) => o.isUtc), isTrue);
      expect(ore.last.add(const Duration(hours: 1)), DateTime(2026, 3, 16).toUtc());
    });

    test('una pescata è da scaricare solo se lo spot ha coordinate; si usa il primo punto del tratto', () async {
      await salvaSpot('Valsecca', [(45.7612, 9.6401), (45.7650, 9.6450)]);
      await salvaSpot('Senza punti', []);
      final conPunti = await salvaPescata('Valsecca', DateTime(2026, 3, 15));
      final senzaPunti = await salvaPescata('Senza punti', DateTime(2026, 3, 16));

      final richieste = await meteoRepo.getPescateDaScaricare();
      expect(richieste.single.pescataId, conPunti.id);
      expect(richieste.single.data, DateTime(2026, 3, 15));
      expect(richieste.single.latitudine, 45.7612);
      expect(richieste.single.longitudine, 9.6401);

      expect(await meteoRepo.getStatoMeteo(conPunti.id!), StatoMeteo.daScaricare);
      expect(await meteoRepo.getStatoMeteo(senzaPunti.id!), StatoMeteo.nonDisponibile);
      expect(
        (await meteoRepo.getMeteoPescata(senzaPunti.id!)).stato,
        StatoMeteo.nonDisponibile,
      );
    });
  });

  group('MeteoRepository - Salvataggio e lettura', () {
    test('salvaDati archivia i dati, collega la pescata e getMeteoPescata li restituisce in ordine', () async {
      await salvaSpot('Valsecca', [(45.7612, 9.6401), (45.7650, 9.6450)]);
      final data = DateTime(2026, 3, 15);
      final pescata = await salvaPescata('Valsecca', data);
      final richieste = await meteoRepo.getPescateDaScaricare();

      final cella = await meteoRepo.salvaDati(
        cella: cellaBrembo,
        giorni: giorniFinti(data),
        ore: oreFinte(data),
        richieste: richieste,
      );
      expect(cella.id, isNotNull);

      expect(await meteoRepo.getStatoMeteo(pescata.id!), StatoMeteo.scaricato);
      expect(await meteoRepo.getPescateDaScaricare(), isEmpty);
      final mancanti = await meteoRepo.getDatiMancanti(cella.id!, data);
      expect(mancanti.giorni, isEmpty);
      expect(mancanti.ore, isEmpty);

      final meteo = await meteoRepo.getMeteoPescata(pescata.id!);
      expect(meteo.stato, StatoMeteo.scaricato);
      expect(meteo.cella?.elevazione, 820);
      expect(meteo.giorni.length, 31);
      expect(meteo.giorni.first.data, DateTime(2026, 2, 13));
      expect(meteo.giorni.last.data, data);
      expect(meteo.ore.length, MeteoRepository.oreRichieste(data).length);
      expect(meteo.ore.first.dataOra, DateTime(2026, 3, 14).toUtc());
      expect(meteo.ore.first.dataOra.isUtc, isTrue);
    });

    test('una pescata vicina riusa la cella e l\'archivio: mancano solo i giorni nuovi', () async {
      await salvaSpot('Valsecca', [(45.7612, 9.6401)]);
      final prima = DateTime(2026, 3, 15);
      await salvaPescata('Valsecca', prima);
      final cella = await meteoRepo.salvaDati(
        cella: cellaBrembo,
        giorni: giorniFinti(prima),
        ore: oreFinte(prima),
        richieste: await meteoRepo.getPescateDaScaricare(),
      );

      // Seconda pescata nello stesso spot due giorni dopo
      final dopo = DateTime(2026, 3, 17);
      final seconda = await salvaPescata('Valsecca', dopo);
      final richiesta = (await meteoRepo.getPescateDaScaricare()).single;
      expect(richiesta.pescataId, seconda.id);

      final cellaNota = await meteoRepo.getCellaPerPunto(
        richiesta.latitudine,
        richiesta.longitudine,
      );
      expect(cellaNota?.id, cella.id);

      final mancanti = await meteoRepo.getDatiMancanti(cella.id!, dopo);
      expect(mancanti.giorni, [DateTime(2026, 3, 16), DateTime(2026, 3, 17)]);
      // Il 16 e il 17 non hanno ancora dati orari
      expect(mancanti.ore.first, DateTime(2026, 3, 16).toUtc());

      // Senza scaricare nulla la pescata resta da scaricare; assegnando la
      // cella dopo aver completato i dati diventa scaricata
      await meteoRepo.salvaDati(
        cella: cellaBrembo,
        giorni: giorniFinti(dopo).where((g) => !g.data.isBefore(DateTime(2026, 3, 16))).toList(),
        ore: oreFinte(dopo),
      );
      expect((await meteoRepo.getDatiMancanti(cella.id!, dopo)).giorni, isEmpty);
      await meteoRepo.assegnaCella([richiesta], cella.id!);
      expect(await meteoRepo.getStatoMeteo(seconda.id!), StatoMeteo.scaricato);
      expect(await db.query('CellaMeteo'), hasLength(1));
    });

    test('un dato d\'archivio non viene sovrascritto da una previsione, il contrario sì', () async {
      final data = DateTime(2026, 3, 15);
      final cella = await meteoRepo.salvaDati(
        cella: cellaBrembo,
        giorni: [
          MeteoGiorno(data: data, pioggiaMm: 5, fonte: FonteMeteo.previsione),
          MeteoGiorno(data: DateTime(2026, 3, 14), pioggiaMm: 8, fonte: FonteMeteo.archivio),
        ],
      );
      await meteoRepo.salvaDati(
        cella: cellaBrembo,
        giorni: [
          MeteoGiorno(data: data, pioggiaMm: 7, fonte: FonteMeteo.archivio),
          MeteoGiorno(data: DateTime(2026, 3, 14), pioggiaMm: 1, fonte: FonteMeteo.previsione),
        ],
      );

      final righe = await db.query(
        'MeteoGiornaliero',
        where: 'cella_id = ?',
        whereArgs: [cella.id],
        orderBy: 'data ASC',
      );
      expect(righe.map((r) => r['pioggia_mm']), [8.0, 7.0]);
      expect(righe.map((r) => r['fonte']), ['archivio', 'archivio']);
    });
  });

  group('MeteoRepository - Stato calcolato', () {
    test('cambio di data o del primo punto: torna da scaricare; rinomina o eliminazione dello spot: resta scaricato', () async {
      await salvaSpot('Valsecca', [(45.7612, 9.6401), (45.7650, 9.6450)]);
      final data = DateTime(2026, 3, 15);
      final pescata = await salvaPescata('Valsecca', data);
      Future<void> scarica() async {
        await meteoRepo.salvaDati(
          cella: cellaBrembo,
          giorni: giorniFinti(data),
          ore: oreFinte(data),
          richieste: await meteoRepo.getPescateDaScaricare(),
        );
      }
      await scarica();

      // Modifica che non tocca data né primo punto (aggiungo un punto in fondo)
      await salvaSpot(
        'Valsecca',
        [(45.7612, 9.6401), (45.7650, 9.6450), (45.7700, 9.6500)],
        nomeOriginale: 'Valsecca',
      );
      expect(await meteoRepo.getStatoMeteo(pescata.id!), StatoMeteo.scaricato);

      // Cambio del primo punto del tratto
      await salvaSpot('Valsecca', [(45.7000, 9.6000)], nomeOriginale: 'Valsecca');
      expect(await meteoRepo.getStatoMeteo(pescata.id!), StatoMeteo.daScaricare);
      await scarica();
      expect(await meteoRepo.getStatoMeteo(pescata.id!), StatoMeteo.scaricato);

      // Cambio della data della pescata
      final completa = await pescateRepo.getPescataCompleta(pescata.id!);
      await pescateRepo.salvaPescata(completa!.copyWith(data: DateTime(2026, 3, 16)));
      expect(await meteoRepo.getStatoMeteo(pescata.id!), StatoMeteo.daScaricare);
      await pescateRepo.salvaPescata(completa.copyWith(data: data));
      expect(await meteoRepo.getStatoMeteo(pescata.id!), StatoMeteo.scaricato);

      // Rinomina dello spot
      final spot = await territorioRepo.getSpotConCoordinate('Valsecca');
      await territorioRepo.salvaSpotConCoordinate(
        spot!.copyWith(nome: 'Valsecca alta'),
        nomeOriginale: 'Valsecca',
      );
      expect(await meteoRepo.getStatoMeteo(pescata.id!), StatoMeteo.scaricato);

      // Eliminazione dello spot: la pescata conserva il suo meteo
      await territorioRepo.eliminaSpot('Valsecca alta');
      expect(await meteoRepo.getStatoMeteo(pescata.id!), StatoMeteo.scaricato);
      expect((await meteoRepo.getMeteoPescata(pescata.id!)).giorni.length, 31);

      // Eliminazione della pescata: sparisce il collegamento, l'archivio resta
      await pescateRepo.eliminaPescata(pescata.id!);
      expect(await db.query('PescataMeteo'), isEmpty);
      expect(await db.query('MeteoGiornaliero'), isNotEmpty);
    });
  });

  group('StatisticheService - Pioggia cumulata', () {
    test('getPioggiaCumulata somma la pioggia dei giorni precedenti, escluso il giorno della pescata', () async {
      await salvaSpot('Valsecca', [(45.7612, 9.6401)]);
      final data = DateTime(2026, 3, 15);
      final pescata = await salvaPescata('Valsecca', data);
      expect(await statistiche.getPioggiaCumulata(pescata.id!, giorni: 3), isNull);

      // 1 mm al giorno, ma 20 mm nel giorno stesso della pescata (indice 30)
      await meteoRepo.salvaDati(
        cella: cellaBrembo,
        giorni: giorniFinti(data, pioggia: (i) => i == 30 ? 20 : 1),
        ore: oreFinte(data),
        richieste: await meteoRepo.getPescateDaScaricare(),
      );

      expect(await statistiche.getPioggiaCumulata(pescata.id!, giorni: 3), 3);
      expect(await statistiche.getPioggiaCumulata(pescata.id!, giorni: 14), 14);
      expect(await statistiche.getPioggiaCumulata(pescata.id!, giorni: 30), 30);
      await expectLater(
        () => statistiche.getPioggiaCumulata(pescata.id!, giorni: 45),
        throwsArgumentError,
      );
    });
  });
}
