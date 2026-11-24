import 'dart:convert';

import 'package:http/http.dart' as http;

// Risposta finta di Open-Meteo, condivisa dai test del servizio meteo e
// dello stato delle pescate.

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
