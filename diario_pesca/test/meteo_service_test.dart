import 'dart:convert';

import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/pescate/pescata.dart';
import 'package:diario_pesca/models/territorio/categoria.dart';
import 'package:diario_pesca/models/territorio/coordinata.dart';
import 'package:diario_pesca/models/territorio/spot.dart';
import 'package:diario_pesca/repositories/meteo_repository.dart';
import 'package:diario_pesca/repositories/pescate_repository.dart';
import 'package:diario_pesca/repositories/territorio_repository.dart';
import 'package:diario_pesca/services/meteo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// "Oggi" per tutti i test: un giorno d'inverno, lontano dal cambio
/// dell'ora legale.
final oggi = DateTime(2026, 2, 20, 12);

/// Scarto orario che Open-Meteo restituisce per Europe/Rome in inverno.
const scartoSecondi = 3600;

/// Risposta finta nel formato di Open-Meteo con `timeformat=unixtime`:
/// giorni e ore dell'intervallo richiesto, pioggia 1 mm al giorno,
/// pressione 1015 hPa. I giorni dopo [disponibileFinoA] hanno valori nulli,
/// come succede per le date non coperte dal modello. La cella è sempre la
/// stessa; la quota è quella del punto richiesto ([quota]), come fa
/// Open-Meteo, che corregge le temperature in base alla quota.
http.Response rispostaOpenMeteo(
  http.Request richiesta, {
  DateTime? disponibileFinoA,
  double Function(double latitudine)? quota,
}) {
  final p = richiesta.url.queryParameters;
  final DateTime da;
  final DateTime a;
  if (p.containsKey('start_date')) {
    da = DateTime.parse(p['start_date']!);
    a = DateTime.parse(p['end_date']!);
  } else {
    da = DateTime(oggi.year, oggi.month, oggi.day);
    a = da.add(Duration(days: int.parse(p['forecast_days']!) - 1));
  }
  bool disponibile(DateTime giornoUtc) =>
      disponibileFinoA == null ||
      !DateTime(giornoUtc.year, giornoUtc.month, giornoUtc.day).isAfter(disponibileFinoA);

  final giorni = <int>[];
  final pioggia = <double?>[];
  final tMin = <double?>[];
  final tMax = <double?>[];
  for (var g = DateTime.utc(da.year, da.month, da.day);
      !g.isAfter(DateTime.utc(a.year, a.month, a.day));
      g = g.add(const Duration(days: 1))) {
    giorni.add(g.millisecondsSinceEpoch ~/ 1000 - scartoSecondi);
    final ok = disponibile(g);
    pioggia.add(ok ? 1.0 : null);
    tMin.add(ok ? 2.0 : null);
    tMax.add(ok ? 9.0 : null);
  }

  final ore = <int>[];
  final pressione = <double?>[];
  final temperatura = <double?>[];
  final inizio = DateTime.utc(da.year, da.month, da.day)
      .subtract(const Duration(seconds: scartoSecondi));
  final fine = DateTime.utc(a.year, a.month, a.day + 1)
      .subtract(const Duration(seconds: scartoSecondi));
  for (var o = inizio; o.isBefore(fine); o = o.add(const Duration(hours: 1))) {
    ore.add(o.millisecondsSinceEpoch ~/ 1000);
    final ok = disponibile(o.add(const Duration(seconds: scartoSecondi)));
    pressione.add(ok ? 1015.0 : null);
    temperatura.add(ok ? 5.0 : null);
  }

  return http.Response(
    jsonEncode({
      'latitude': 45.75,
      'longitude': 9.625,
      'elevation': quota?.call(double.parse(p['latitude']!)) ?? 820.0,
      'utc_offset_seconds': scartoSecondi,
      'timezone': 'Europe/Rome',
      'daily': {
        'time': giorni,
        'precipitation_sum': pioggia,
        'temperature_2m_min': tMin,
        'temperature_2m_max': tMax,
        'wind_speed_10m_max': [for (final _ in giorni) 12.0],
        'wind_gusts_10m_max': [for (final _ in giorni) 25.0],
        'wind_direction_10m_dominant': [for (final _ in giorni) 180],
      },
      'hourly': {
        'time': ore,
        'precipitation': [for (final _ in ore) 0.0],
        'temperature_2m': temperatura,
        'pressure_msl': pressione,
        'wind_speed_10m': [for (final _ in ore) 6.0],
        'wind_gusts_10m': [for (final _ in ore) 11.0],
        'wind_direction_10m': [for (final _ in ore) 170],
      },
    }),
    200,
  );
}

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
  late List<http.Request> chiamate;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    db = await dbHelper.database;
    territorioRepo = TerritorioRepository(dbHelper: dbHelper);
    pescateRepo = PescateRepository(dbHelper: dbHelper);
    meteoRepo = MeteoRepository(dbHelper: dbHelper);
    chiamate = [];
    await territorioRepo.inserisciCategoria(const Categoria(nome: 'Valle'));
    await territorioRepo.salvaSpotConCoordinate(
      const Spot(
        nome: 'Valsecca',
        ambiente: 'Torrente',
        categoriaNome: 'Valle',
        coordinate: [
          Coordinata(ordine: 0, latitudine: 45.7612, longitudine: 9.6401),
          Coordinata(ordine: 1, latitudine: 45.7650, longitudine: 9.6450),
        ],
      ),
    );
  });

  tearDown(() async {
    await dbHelper.close();
  });

  MeteoService servizio({
    http.Response Function(http.Request)? risposta,
  }) =>
      MeteoService(
        meteo: meteoRepo,
        adesso: () => oggi,
        client: MockClient((richiesta) async {
          chiamate.add(richiesta);
          return (risposta ?? rispostaOpenMeteo)(richiesta);
        }),
      );

  Future<Pescata> salvaPescata(DateTime data) => pescateRepo.salvaPescata(
        Pescata(data: data, fasciaOraria: FasciaOraria.alba, spotNome: 'Valsecca'),
      );

  group('MeteoService - Storico delle pescate', () {
    test('una pescata si scarica dall\'archivio delle previsioni con una sola chiamata e viene collegata alla cella', () async {
      final data = DateTime(2026, 1, 10);
      final pescata = await salvaPescata(data);

      final esito = await servizio().aggiornaStorico();
      expect(esito.completate, 1);
      expect(esito.incomplete, 0);
      expect(esito.errori, 0);
      expect(esito.chiamate, 1);

      final url = chiamate.single.url;
      expect(url.host, 'historical-forecast-api.open-meteo.com');
      expect(url.path, '/v1/forecast');
      // Modello scelto da Open-Meteo (ICON-D2 a 2 km sulle Alpi)
      expect(url.queryParameters.containsKey('models'), isFalse);
      expect(url.queryParameters['latitude'], '45.7612');
      expect(url.queryParameters['longitude'], '9.6401');
      // 30 giorni prima e il giorno stesso, più un giorno di margine per lato
      expect(url.queryParameters['start_date'], '2025-12-10');
      expect(url.queryParameters['end_date'], '2026-01-11');
      expect(url.queryParameters['timezone'], 'Europe/Rome');
      expect(url.queryParameters['timeformat'], 'unixtime');
      expect(url.queryParameters['daily'], contains('precipitation_sum'));
      expect(url.queryParameters['hourly'], contains('pressure_msl'));

      final meteo = await meteoRepo.getMeteoPescata(pescata.id!);
      expect(meteo.stato, StatoMeteo.scaricato);
      expect(meteo.cella?.latitudine, 45.75);
      expect(meteo.cella?.elevazione, 820);
      expect(meteo.giorni.length, 31);
      expect(meteo.giorni.first.data, DateTime(2025, 12, 11));
      expect(meteo.giorni.last.data, data);
      expect(meteo.giorni.first.pioggiaMm, 1);
      expect(meteo.giorni.first.pressioneMedia, 1015);
      expect(meteo.giorni.first.direzioneVento, 180);
      expect(meteo.ore.length, MeteoRepository.oreRichieste(data).length);
      // Nell'archivio orario si salvano solo le ore che servono
      expect(await db.query('MeteoOrario'), hasLength(meteo.ore.length));
    });

    test('una pescata di ieri si scarica subito con una chiamata; i dati di oggi non si salvano', () async {
      final pescata = await salvaPescata(DateTime(2026, 2, 19));

      final esito = await servizio().aggiornaStorico();
      expect(esito.completate, 1);
      expect(esito.chiamate, 1);
      // Il giorno di margine arriva a oggi, che però non è ancora concluso
      expect(chiamate.single.url.queryParameters['end_date'], '2026-02-20');

      final meteo = await meteoRepo.getMeteoPescata(pescata.id!);
      expect(meteo.stato, StatoMeteo.scaricato);
      expect(meteo.giorni.last.data, DateTime(2026, 2, 19));
      expect(await db.query('MeteoGiornaliero', where: "data >= '2026-02-20'"), isEmpty);
    });

    test('spot nella stessa cella della griglia ma a quote diverse hanno celle distinte', () async {
      await territorioRepo.salvaSpotConCoordinate(
        const Spot(
          nome: 'Valsecca alta',
          ambiente: 'Torrente',
          categoriaNome: 'Valle',
          coordinate: [Coordinata(ordine: 0, latitudine: 45.7701, longitudine: 9.6420)],
        ),
      );
      final bassa = await salvaPescata(DateTime(2026, 1, 10));
      final alta = await pescateRepo.salvaPescata(
        Pescata(data: DateTime(2026, 1, 10), fasciaOraria: FasciaOraria.alba, spotNome: 'Valsecca alta'),
      );

      final esito = await servizio(
        risposta: (r) => rispostaOpenMeteo(r, quota: (lat) => lat > 45.765 ? 1180.0 : 820.0),
      ).aggiornaStorico();
      expect(esito.completate, 2);
      expect(esito.chiamate, 2);

      final meteoBassa = await meteoRepo.getMeteoPescata(bassa.id!);
      final meteoAlta = await meteoRepo.getMeteoPescata(alta.id!);
      expect(meteoBassa.cella?.latitudine, meteoAlta.cella?.latitudine);
      expect(meteoBassa.cella?.elevazione, 820);
      expect(meteoAlta.cella?.elevazione, 1180);
      expect(meteoAlta.cella?.id, isNot(meteoBassa.cella?.id));
      expect(await db.query('CellaMeteo'), hasLength(2));
    });

    test('pescate nello stesso punto riusano l\'archivio: nessuna chiamata o solo i giorni mancanti', () async {
      await salvaPescata(DateTime(2026, 1, 10));
      await servizio().aggiornaStorico();
      chiamate.clear();

      // Stesso spot e stesso giorno: tutto già in archivio
      final stessoGiorno = await salvaPescata(DateTime(2026, 1, 10));
      var esito = await servizio().aggiornaStorico();
      expect(esito.chiamate, 0);
      expect(esito.completate, 1);
      expect(await meteoRepo.getStatoMeteo(stessoGiorno.id!), StatoMeteo.scaricato);

      // Giorno dopo: mancano solo le ore dell'11 gennaio
      final giornoDopo = await salvaPescata(DateTime(2026, 1, 11));
      esito = await servizio().aggiornaStorico();
      expect(esito.chiamate, 1);
      expect(esito.completate, 1);
      expect(chiamate.single.url.queryParameters['start_date'], '2026-01-10');
      expect(chiamate.single.url.queryParameters['end_date'], '2026-01-12');
      expect(await meteoRepo.getStatoMeteo(giornoDopo.id!), StatoMeteo.scaricato);
      expect(await db.query('CellaMeteo'), hasLength(1));
    });

    test('le pescate della giornata in corso non vengono scaricate', () async {
      final pescata = await salvaPescata(DateTime(2026, 2, 20));

      final esito = await servizio().aggiornaStorico();
      expect(esito.chiamate, 0);
      expect(esito.completate, 0);
      expect(chiamate, isEmpty);
      expect(await meteoRepo.getStatoMeteo(pescata.id!), StatoMeteo.daScaricare);
    });

    test('senza rete o con un errore del servizio la pescata resta da scaricare', () async {
      final pescata = await salvaPescata(DateTime(2026, 1, 10));

      final senzaRete = await servizio(
        risposta: (_) => throw http.ClientException('Nessuna connessione'),
      ).aggiornaStorico();
      expect(senzaRete.errori, 1);
      expect(senzaRete.completate, 0);
      expect(await meteoRepo.getStatoMeteo(pescata.id!), StatoMeteo.daScaricare);

      final erroreServizio = await servizio(
        risposta: (_) => http.Response(
          jsonEncode({'error': true, 'reason': 'Parametro non valido'}),
          400,
        ),
      ).aggiornaStorico();
      expect(erroreServizio.errori, 1);

      final rispostaRotta = await servizio(
        risposta: (_) => http.Response(jsonEncode({'latitude': 'x'}), 200),
      ).aggiornaStorico();
      expect(rispostaRotta.errori, 1);

      expect(await meteoRepo.getStatoMeteo(pescata.id!), StatoMeteo.daScaricare);
      expect(await db.query('MeteoGiornaliero'), isEmpty);
    });

    test('se il servizio non restituisce tutti i giorni la pescata resta incompleta e si completa al tentativo successivo', () async {
      final data = DateTime(2026, 1, 10);
      final pescata = await salvaPescata(data);

      final primo = await servizio(
        risposta: (r) => rispostaOpenMeteo(r, disponibileFinoA: DateTime(2026, 1, 9)),
      ).aggiornaStorico();
      expect(primo.incomplete, 1);
      expect(primo.completate, 0);
      expect(await meteoRepo.getStatoMeteo(pescata.id!), StatoMeteo.daScaricare);

      chiamate.clear();
      final secondo = await servizio().aggiornaStorico();
      expect(secondo.completate, 1);
      // La cella non è ancora collegata a nessuna pescata, quindi si
      // richiedono di nuovo tutti i giorni: quelli già presenti si riscrivono.
      expect(secondo.chiamate, 1);
      expect(await meteoRepo.getStatoMeteo(pescata.id!), StatoMeteo.scaricato);
    });
  });

  group('MeteoService - Previsioni', () {
    test('getPrevisioni restituisce le previsioni dei prossimi giorni senza salvarle', () async {
      final previsioni = await servizio().getPrevisioni(45.7612, 9.6401, giorni: 3);

      final url = chiamate.single.url;
      expect(url.host, 'api.open-meteo.com');
      expect(url.queryParameters['forecast_days'], '3');
      expect(url.queryParameters.containsKey('start_date'), isFalse);

      expect(previsioni.cella.latitudine, 45.75);
      expect(previsioni.giorni.length, 3);
      expect(previsioni.giorni.first.data, DateTime(2026, 2, 20));
      expect(previsioni.ore.length, 72);
      expect(await db.query('MeteoGiornaliero'), isEmpty);

      await expectLater(
        () => servizio().getPrevisioni(45.7612, 9.6401, giorni: 0),
        throwsArgumentError,
      );
    });
  });
}
