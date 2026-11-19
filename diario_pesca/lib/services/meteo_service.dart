import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/db_mappers.dart';
import '../models/enums.dart';
import '../models/meteo/cella_meteo.dart';
import '../models/meteo/meteo_giorno.dart';
import '../models/meteo/meteo_ora.dart';
import '../models/meteo/richiesta_meteo.dart';
import '../repositories/meteo_repository.dart';

/// Esito di un aggiornamento dello storico meteo ([MeteoService.aggiornaStorico]).
class EsitoAggiornamentoMeteo {
  /// Pescate i cui dati meteo sono ora completi.
  final int completate;

  /// Pescate rimaste da scaricare perché il servizio non ha restituito tutti
  /// i dati (es. giorni non ancora disponibili): verranno ritentate.
  final int incomplete;

  /// Gruppi di pescate non aggiornati per un errore di rete o del servizio.
  final int errori;

  /// Richieste HTTP effettuate.
  final int chiamate;

  const EsitoAggiornamentoMeteo({
    required this.completate,
    required this.incomplete,
    required this.errori,
    required this.chiamate,
  });

  @override
  String toString() =>
      'EsitoAggiornamentoMeteo(completate: $completate, incomplete: $incomplete, errori: $errori, chiamate: $chiamate)';
}

/// Previsioni per uno spot ([MeteoService.getPrevisioni]): non vengono salvate.
class PrevisioniMeteo {
  final CellaMeteo cella;
  final List<MeteoGiorno> giorni;
  final List<MeteoOra> ore;

  const PrevisioniMeteo({
    required this.cella,
    required this.giorni,
    required this.ore,
  });
}

/// Errore restituito da Open-Meteo o risposta non interpretabile.
class MeteoServiceException implements Exception {
  final String messaggio;
  const MeteoServiceException(this.messaggio);

  @override
  String toString() => 'MeteoServiceException: $messaggio';
}

/// Comunicazione con Open-Meteo (https://open-meteo.com), in due ruoli:
///
/// * [aggiornaStorico] scarica i dati meteo storici delle pescate da
///   scaricare e li salva tramite il [MeteoRepository] (REQ-FUN-17);
/// * [getPrevisioni] restituisce le previsioni per un punto, senza salvarle
///   (REQ-FUN-13).
///
/// I dati sono rilasciati con licenza CC BY 4.0: l'app deve mostrare
/// [attribuzione] dove li visualizza. Il piano gratuito è riservato all'uso
/// non commerciale.
class MeteoService {
  static const String attribuzione = 'Dati meteo: Open-Meteo.com (CC BY 4.0)';

  /// Giorni di ritardo con cui i dati arrivano nell'archivio storico: i
  /// giorni più recenti si chiedono all'API delle previsioni.
  static const int giorniRitardoArchivio = 5;

  static const String _hostArchivio = 'archive-api.open-meteo.com';
  static const String _pathArchivio = '/v1/archive';
  static const String _hostPrevisioni = 'api.open-meteo.com';
  static const String _pathPrevisioni = '/v1/forecast';

  final MeteoRepository _meteo;
  final http.Client _client;
  final DateTime Function() _adesso;

  MeteoService({
    MeteoRepository? meteo,
    http.Client? client,
    DateTime Function()? adesso,
  })  : _meteo = meteo ?? MeteoRepository(),
        _client = client ?? http.Client(),
        _adesso = adesso ?? DateTime.now;

  // ===========================================================================
  // STORICO DELLE PESCATE
  // ===========================================================================

  /// Scarica i dati meteo mancanti delle pescate da scaricare e collega ogni
  /// pescata alla sua cella quando i suoi dati sono completi.
  ///
  /// * Si considerano solo le pescate di giorni già conclusi (data prima di
  ///   oggi): per la giornata in corso i dati non sono ancora definitivi.
  /// * Le pescate sono raggruppate per punto e, nello stesso punto, per
  ///   intervalli di date sovrapposti: ogni gruppo richiede una o due
  ///   chiamate (archivio per le date più vecchie, previsioni per gli ultimi
  ///   [giorniRitardoArchivio] giorni) e solo i giorni e le ore mancanti.
  /// * Se la cella del punto è già nota e l'archivio contiene tutto, la
  ///   pescata viene collegata senza nessuna chiamata.
  /// * Un errore di rete o del servizio non interrompe l'aggiornamento: il
  ///   gruppo resta da scaricare e viene contato in [EsitoAggiornamentoMeteo.errori].
  Future<EsitoAggiornamentoMeteo> aggiornaStorico() async {
    final oggi = _giorno(_adesso());
    final richieste = (await _meteo.getPescateDaScaricare())
        .where((r) => _giorno(r.data).isBefore(oggi))
        .toList();

    var completate = 0;
    var incomplete = 0;
    var errori = 0;
    var chiamate = 0;

    for (final gruppo in _raggruppa(richieste)) {
      final primo = gruppo.first;
      try {
        var cella = await _meteo.getCellaPerPunto(primo.latitudine, primo.longitudine);

        // Giorni locali da scaricare: tutti se la cella non è nota,
        // altrimenti solo quelli che mancano in archivio.
        final giorniDaScaricare = <DateTime>{};
        final oreNecessarie = <int>{};
        for (final r in gruppo) {
          for (final o in MeteoRepository.oreRichieste(r.data)) {
            oreNecessarie.add(o.millisecondsSinceEpoch);
          }
          if (cella == null) {
            giorniDaScaricare.addAll(MeteoRepository.giorniRichiesti(r.data));
          } else {
            final mancanti = await _meteo.getDatiMancanti(cella.id!, r.data);
            giorniDaScaricare.addAll(mancanti.giorni);
            giorniDaScaricare.addAll(mancanti.ore.map((o) => _giorno(o.toLocal())));
          }
        }

        if (giorniDaScaricare.isNotEmpty) {
          final ordinati = giorniDaScaricare.toList()..sort();
          final soglia = oggi.subtract(const Duration(days: giorniRitardoArchivio));
          final daArchivio = ordinati.where((g) => !g.isAfter(soglia)).toList();
          final daPrevisioni = ordinati.where((g) => g.isAfter(soglia)).toList();

          for (final (giorni, fonte) in [
            (daArchivio, FonteMeteo.archivio),
            (daPrevisioni, FonteMeteo.previsione),
          ]) {
            if (giorni.isEmpty) continue;
            chiamate++;
            final risposta = await _scarica(
              latitudine: primo.latitudine,
              longitudine: primo.longitudine,
              da: giorni.first,
              a: giorni.last,
              fonte: fonte,
            );
            // La cella di un punto è quella della prima risposta: dati di
            // archivio e di previsione dello stesso punto restano insieme
            // anche se i due modelli usano griglie leggermente diverse.
            cella = await _meteo.salvaDati(
              cella: cella ?? risposta.cella,
              giorni: risposta.giorni,
              ore: risposta.ore
                  .where((o) => oreNecessarie.contains(o.dataOra.millisecondsSinceEpoch))
                  .toList(),
            );
          }
        }

        if (cella == null) {
          incomplete += gruppo.length;
          continue;
        }
        for (final r in gruppo) {
          final mancanti = await _meteo.getDatiMancanti(cella.id!, r.data);
          if (mancanti.giorni.isEmpty && mancanti.ore.isEmpty) {
            await _meteo.assegnaCella([r], cella.id!);
            completate++;
          } else {
            incomplete++;
          }
        }
      } on Exception {
        // Rete assente, servizio non disponibile o risposta non valida:
        // il gruppo resta da scaricare e sarà ritentato.
        errori++;
      }
    }

    return EsitoAggiornamentoMeteo(
      completate: completate,
      incomplete: incomplete,
      errori: errori,
      chiamate: chiamate,
    );
  }

  // ===========================================================================
  // PREVISIONI
  // ===========================================================================

  /// Previsioni giornaliere e orarie per il punto ([latitudine],
  /// [longitudine]) da oggi per [giorni] giorni (1–16). Non vengono salvate.
  /// Lancia un'eccezione se la rete o il servizio non sono disponibili.
  Future<PrevisioniMeteo> getPrevisioni(
    double latitudine,
    double longitudine, {
    int giorni = 7,
  }) async {
    if (giorni < 1 || giorni > 16) {
      throw ArgumentError.value(giorni, 'giorni', 'deve essere tra 1 e 16');
    }
    final risposta = await _richiedi(
      _hostPrevisioni,
      _pathPrevisioni,
      {
        'latitude': '$latitudine',
        'longitude': '$longitudine',
        'forecast_days': '$giorni',
        ..._parametriComuni,
      },
      FonteMeteo.previsione,
    );
    return PrevisioniMeteo(
      cella: risposta.cella,
      giorni: risposta.giorni,
      ore: risposta.ore,
    );
  }

  /// Chiude il client HTTP. Da chiamare quando il servizio non serve più.
  void chiudi() => _client.close();

  // ===========================================================================
  // HELPER PRIVATI
  // ===========================================================================

  static const Map<String, String> _parametriComuni = {
    'daily': 'precipitation_sum,temperature_2m_min,temperature_2m_max,'
        'wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant',
    'hourly': 'precipitation,temperature_2m,pressure_msl,'
        'wind_speed_10m,wind_gusts_10m,wind_direction_10m',
    'timezone': 'Europe/Rome',
    // Istanti in secondi UTC: corretti anche a cavallo del cambio dell'ora
    // legale, che con il formato ISO verrebbe ignorato.
    'timeformat': 'unixtime',
  };

  Future<_RispostaMeteo> _scarica({
    required double latitudine,
    required double longitudine,
    required DateTime da,
    required DateTime a,
    required FonteMeteo fonte,
  }) {
    // Un giorno di margine per lato: Open-Meteo calcola i confini delle ore
    // con lo scarto orario del momento della richiesta, quindi a cavallo del
    // cambio dell'ora legale la prima o l'ultima ora necessaria potrebbe
    // restare fuori. I giorni in più sono semplicemente archiviati.
    final archivio = fonte == FonteMeteo.archivio;
    return _richiedi(
      archivio ? _hostArchivio : _hostPrevisioni,
      archivio ? _pathArchivio : _pathPrevisioni,
      {
        'latitude': '$latitudine',
        'longitude': '$longitudine',
        'start_date': DbMappers.formatData(da.subtract(const Duration(days: 1))),
        'end_date': DbMappers.formatData(a.add(const Duration(days: 1))),
        ..._parametriComuni,
      },
      fonte,
    );
  }

  Future<_RispostaMeteo> _richiedi(
    String host,
    String path,
    Map<String, String> parametri,
    FonteMeteo fonte,
  ) async {
    final risposta = await _client.get(Uri.https(host, path, parametri));
    final Object? corpo;
    try {
      corpo = jsonDecode(risposta.body);
    } on FormatException {
      throw MeteoServiceException('Risposta non valida (HTTP ${risposta.statusCode})');
    }
    if (risposta.statusCode != 200 || corpo is! Map<String, dynamic>) {
      final motivo = corpo is Map<String, dynamic> ? corpo['reason'] : null;
      throw MeteoServiceException(
        'Errore HTTP ${risposta.statusCode}${motivo != null ? ': $motivo' : ''}',
      );
    }
    try {
      return _interpreta(corpo, fonte);
    } on TypeError {
      throw const MeteoServiceException('Formato della risposta non previsto');
    }
  }

  /// Converte la risposta JSON di Open-Meteo nei modelli dell'app.
  /// Giorni e ore senza nessun valore vengono scartati: restano mancanti e
  /// verranno richiesti di nuovo in seguito.
  _RispostaMeteo _interpreta(Map<String, dynamic> json, FonteMeteo fonte) {
    final lat = json['latitude'];
    final lon = json['longitude'];
    if (lat is! num || lon is! num) {
      throw const MeteoServiceException('Coordinate della cella assenti');
    }
    final cella = CellaMeteo(
      latitudine: lat.toDouble(),
      longitudine: lon.toDouble(),
      elevazione: (json['elevation'] as num?)?.toDouble(),
    );
    final scarto = Duration(seconds: (json['utc_offset_seconds'] as num?)?.toInt() ?? 0);

    // --- Ore (istanti UTC) ---
    final ore = <MeteoOra>[];
    final pressioniPerGiorno = <DateTime, List<double>>{};
    final orario = json['hourly'];
    if (orario is Map<String, dynamic>) {
      final tempi = (orario['time'] as List?) ?? const [];
      for (var i = 0; i < tempi.length; i++) {
        final istante = DateTime.fromMillisecondsSinceEpoch(
          (tempi[i] as num).toInt() * 1000,
          isUtc: true,
        );
        final ora = MeteoOra(
          dataOra: istante,
          pioggiaMm: _valore(orario, 'precipitation', i),
          temperatura: _valore(orario, 'temperature_2m', i),
          pressione: _valore(orario, 'pressure_msl', i),
          vento: _valore(orario, 'wind_speed_10m', i),
          raffica: _valore(orario, 'wind_gusts_10m', i),
          direzioneVento: _valore(orario, 'wind_direction_10m', i)?.round(),
          fonte: fonte,
        );
        if (ora.pressione != null) {
          final locale = istante.add(scarto);
          pressioniPerGiorno
              .putIfAbsent(DateTime(locale.year, locale.month, locale.day), () => [])
              .add(ora.pressione!);
        }
        if (_haValori([
          ora.pioggiaMm,
          ora.temperatura,
          ora.pressione,
          ora.vento,
          ora.raffica,
        ])) {
          ore.add(ora);
        }
      }
    }

    // --- Giorni (data locale) ---
    final giorni = <MeteoGiorno>[];
    final giornaliero = json['daily'];
    if (giornaliero is Map<String, dynamic>) {
      final tempi = (giornaliero['time'] as List?) ?? const [];
      for (var i = 0; i < tempi.length; i++) {
        final locale = DateTime.fromMillisecondsSinceEpoch(
          (tempi[i] as num).toInt() * 1000,
          isUtc: true,
        ).add(scarto);
        final data = DateTime(locale.year, locale.month, locale.day);
        final pressioni = pressioniPerGiorno[data];
        final giorno = MeteoGiorno(
          data: data,
          pioggiaMm: _valore(giornaliero, 'precipitation_sum', i),
          tempMin: _valore(giornaliero, 'temperature_2m_min', i),
          tempMax: _valore(giornaliero, 'temperature_2m_max', i),
          pressioneMedia: pressioni == null || pressioni.isEmpty
              ? null
              : pressioni.reduce((a, b) => a + b) / pressioni.length,
          ventoMax: _valore(giornaliero, 'wind_speed_10m_max', i),
          rafficaMax: _valore(giornaliero, 'wind_gusts_10m_max', i),
          direzioneVento: _valore(giornaliero, 'wind_direction_10m_dominant', i)?.round(),
          fonte: fonte,
        );
        if (_haValori([giorno.pioggiaMm, giorno.tempMin, giorno.tempMax])) {
          giorni.add(giorno);
        }
      }
    }

    return _RispostaMeteo(cella: cella, giorni: giorni, ore: ore);
  }

  static double? _valore(Map<String, dynamic> blocco, String variabile, int i) {
    final valori = blocco[variabile];
    if (valori is! List || i >= valori.length) return null;
    return (valori[i] as num?)?.toDouble();
  }

  static bool _haValori(List<double?> valori) => valori.any((v) => v != null);

  /// Raggruppa le richieste per punto e, nello stesso punto, in intervalli
  /// di date che si sovrappongono (30 giorni prima di ogni pescata).
  static List<List<RichiestaMeteo>> _raggruppa(List<RichiestaMeteo> richieste) {
    final perPunto = <(double, double), List<RichiestaMeteo>>{};
    for (final r in richieste) {
      perPunto.putIfAbsent((r.latitudine, r.longitudine), () => []).add(r);
    }

    final gruppi = <List<RichiestaMeteo>>[];
    for (final lista in perPunto.values) {
      lista.sort((a, b) => a.data.compareTo(b.data));
      var corrente = <RichiestaMeteo>[];
      DateTime? fineCorrente;
      for (final r in lista) {
        final inizio = MeteoRepository.giorniRichiesti(r.data).first;
        if (fineCorrente != null && inizio.isAfter(fineCorrente)) {
          gruppi.add(corrente);
          corrente = [];
        }
        corrente.add(r);
        fineCorrente = _giorno(r.data);
      }
      if (corrente.isNotEmpty) gruppi.add(corrente);
    }
    return gruppi;
  }

  static DateTime _giorno(DateTime d) => DateTime(d.year, d.month, d.day);
}

class _RispostaMeteo {
  final CellaMeteo cella;
  final List<MeteoGiorno> giorni;
  final List<MeteoOra> ore;

  const _RispostaMeteo({
    required this.cella,
    required this.giorni,
    required this.ore,
  });
}
