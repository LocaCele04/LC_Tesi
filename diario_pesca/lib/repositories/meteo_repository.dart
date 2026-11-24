import 'package:sqflite/sqflite.dart';

import '../data/database_helper.dart';
import '../data/db_mappers.dart';
import '../models/enums.dart';
import '../models/meteo/cella_meteo.dart';
import '../models/meteo/meteo_giorno.dart';
import '../models/meteo/meteo_ora.dart';
import '../models/meteo/meteo_pescata.dart';
import '../models/meteo/richiesta_meteo.dart';

/// Archivio dei dati meteo storici delle pescate (scaricati da Open-Meteo).
///
/// È l'unico componente che scrive `CellaMeteo`, `MeteoGiornaliero`,
/// `MeteoOrario` e `PescataMeteo`. Non scarica nulla: il
/// `MeteoService` chiede a questo repository cosa manca
/// ([getPescateDaScaricare], [getCellaPerPunto], [getDatiMancanti]),
/// interroga Open-Meteo e salva il risultato con [salvaDati].
///
/// Per ogni pescata servono i [giorniPrecedenti] giorni prima della pescata
/// più il giorno stesso (dati giornalieri) e le ore del giorno prima e del
/// giorno della pescata (dati orari).
///
/// Lo stato del meteo di una pescata non è salvato ma calcolato
/// ([getStatoMeteo]): `PescataMeteo` conserva la data e il punto usati per la
/// richiesta, e se la pescata cambia data o lo spot cambia il primo punto del
/// tratto, la pescata torna da scaricare.
class MeteoRepository {
  /// Giorni di storico giornaliero prima della data della pescata.
  static const int giorniPrecedenti = 30;

  final DatabaseHelper _dbHelper;

  MeteoRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  // ===========================================================================
  // INTERVALLI RICHIESTI
  // ===========================================================================

  /// Giorni (data locale) dei dati giornalieri per una pescata del giorno
  /// [data]: dal più vecchio al giorno della pescata compreso.
  static List<DateTime> giorniRichiesti(DateTime data) {
    final giorno = DateTime(data.year, data.month, data.day);
    return [
      for (var i = giorniPrecedenti; i >= 0; i--)
        DateTime(giorno.year, giorno.month, giorno.day - i),
    ];
  }

  /// Ore (in UTC) dei dati orari per una pescata del giorno [data]: dalla
  /// mezzanotte locale del giorno prima alla mezzanotte locale del giorno
  /// dopo, esclusa. Sono 48 ore, oppure 47 o 49 se nel mezzo cambia l'ora legale.
  static List<DateTime> oreRichieste(DateTime data) {
    final inizio = DateTime(data.year, data.month, data.day - 1).toUtc();
    final fine = DateTime(data.year, data.month, data.day + 1).toUtc();
    final ore = <DateTime>[];
    for (var ora = inizio; ora.isBefore(fine); ora = ora.add(const Duration(hours: 1))) {
      ore.add(ora);
    }
    return ore;
  }

  // ===========================================================================
  // COSA SCARICARE
  // ===========================================================================

  /// Pescate il cui meteo è da scaricare: lo spot ha almeno una coordinata e
  /// non esiste ancora una richiesta corrispondente alla data della pescata e
  /// al punto dello spot (la coordinata con ordine minimo del tratto).
  Future<List<RichiestaMeteo>> getPescateDaScaricare() async {
    final db = await _dbHelper.database;
    final righe = await db.rawQuery('''
      SELECT p.id, p.data, c.latitudine, c.longitudine
      FROM Pescata p
      INNER JOIN Coordinata c ON c.spot_nome = p.spot_nome
        AND c.ordine = (SELECT MIN(ordine) FROM Coordinata WHERE spot_nome = p.spot_nome)
      LEFT JOIN PescataMeteo pm ON pm.pescata_id = p.id
      WHERE pm.pescata_id IS NULL
         OR pm.data <> p.data
         OR pm.latitudine <> c.latitudine
         OR pm.longitudine <> c.longitudine
      ORDER BY p.data ASC, p.id ASC
    ''');
    return righe
        .map((r) => RichiestaMeteo(
              pescataId: r['id'] as int,
              data: DateTime.parse(r['data'] as String),
              latitudine: (r['latitudine'] as num).toDouble(),
              longitudine: (r['longitudine'] as num).toDouble(),
            ))
        .toList();
  }

  /// Cella già associata in passato al punto ([latitudine], [longitudine]),
  /// se esiste. Permette di riusare l'archivio senza interrogare Open-Meteo
  /// solo per sapere in quale cella cade il punto.
  Future<CellaMeteo?> getCellaPerPunto(double latitudine, double longitudine) async {
    final db = await _dbHelper.database;
    final righe = await db.rawQuery('''
      SELECT c.* FROM CellaMeteo c
      INNER JOIN PescataMeteo pm ON pm.cella_id = c.id
      WHERE pm.latitudine = ? AND pm.longitudine = ?
      LIMIT 1
    ''', [latitudine, longitudine]);
    return righe.isEmpty ? null : DbMappers.cellaMeteoFromMap(righe.first);
  }

  /// Giorni (dati giornalieri) e ore (dati orari, in UTC) che mancano
  /// nell'archivio della cella [cellaId] per una pescata del giorno [data].
  /// Se entrambi gli elenchi sono vuoti basta [assegnaCella], senza scaricare.
  Future<({List<DateTime> giorni, List<DateTime> ore})> getDatiMancanti(
    int cellaId,
    DateTime data,
  ) async {
    final db = await _dbHelper.database;

    final giorni = giorniRichiesti(data);
    final righeGiorni = await db.query(
      'MeteoGiornaliero',
      columns: ['data'],
      where: 'cella_id = ? AND data BETWEEN ? AND ?',
      whereArgs: [
        cellaId,
        DbMappers.formatData(giorni.first),
        DbMappers.formatData(giorni.last),
      ],
    );
    final giorniPresenti = righeGiorni.map((r) => r['data'] as String).toSet();

    final ore = oreRichieste(data);
    final righeOre = await db.query(
      'MeteoOrario',
      columns: ['data_ora'],
      where: 'cella_id = ? AND data_ora BETWEEN ? AND ?',
      whereArgs: [
        cellaId,
        DbMappers.formatDataOra(ore.first),
        DbMappers.formatDataOra(ore.last),
      ],
    );
    final orePresenti = righeOre.map((r) => r['data_ora'] as String).toSet();

    return (
      giorni: giorni
          .where((g) => !giorniPresenti.contains(DbMappers.formatData(g)))
          .toList(),
      ore: ore
          .where((o) => !orePresenti.contains(DbMappers.formatDataOra(o)))
          .toList(),
    );
  }

  // ===========================================================================
  // SALVATAGGIO
  // ===========================================================================

  /// Salva in un'unica transazione i dati scaricati per una cella e collega
  /// a quella cella le pescate di [richieste].
  ///
  /// La cella viene creata se non esiste (stesse coordinate di griglia e
  /// stessa quota). Un dato già presente per lo stesso giorno o la stessa
  /// ora viene sostituito da quello nuovo.
  Future<CellaMeteo> salvaDati({
    required CellaMeteo cella,
    List<MeteoGiorno> giorni = const [],
    List<MeteoOra> ore = const [],
    List<RichiestaMeteo> richieste = const [],
  }) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      final cellaSalvata = await _assicuraCella(txn, cella);
      final cellaId = cellaSalvata.id!;

      for (final g in giorni) {
        await txn.insert(
          'MeteoGiornaliero',
          DbMappers.meteoGiornoToMap(g, cellaId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final o in ore) {
        await txn.insert(
          'MeteoOrario',
          DbMappers.meteoOraToMap(o, cellaId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await _collegaPescate(txn, richieste, cellaId);
      return cellaSalvata;
    });
  }

  /// Collega le pescate di [richieste] alla cella [cellaId] senza salvare
  /// dati: da usare quando l'archivio della cella contiene già tutto
  /// ([getDatiMancanti] restituisce elenchi vuoti).
  Future<void> assegnaCella(List<RichiestaMeteo> richieste, int cellaId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) => _collegaPescate(txn, richieste, cellaId));
  }

  // ===========================================================================
  // LETTURA
  // ===========================================================================

  /// Stato del meteo della pescata [pescataId] (vedi [StatoMeteo]).
  Future<StatoMeteo> getStatoMeteo(int pescataId) async {
    final db = await _dbHelper.database;
    return _calcolaStato(db, pescataId);
  }

  /// Meteo completo della pescata [pescataId]: stato, cella, giorni
  /// (dal più vecchio al giorno della pescata) e ore (in UTC, in ordine).
  /// Se lo stato non è [StatoMeteo.scaricato] restituisce solo lo stato.
  Future<MeteoPescata> getMeteoPescata(int pescataId) async {
    final db = await _dbHelper.database;
    final stato = await _calcolaStato(db, pescataId);
    if (stato != StatoMeteo.scaricato) return MeteoPescata(stato: stato);

    final righe = await db.rawQuery('''
      SELECT pm.data AS pm_data, c.*
      FROM PescataMeteo pm
      INNER JOIN CellaMeteo c ON c.id = pm.cella_id
      WHERE pm.pescata_id = ?
    ''', [pescataId]);
    final riga = righe.single;
    final cella = DbMappers.cellaMeteoFromMap(riga);
    final data = DateTime.parse(riga['pm_data'] as String);

    final giorni = giorniRichiesti(data);
    final righeGiorni = await db.query(
      'MeteoGiornaliero',
      where: 'cella_id = ? AND data BETWEEN ? AND ?',
      whereArgs: [
        cella.id,
        DbMappers.formatData(giorni.first),
        DbMappers.formatData(giorni.last),
      ],
      orderBy: 'data ASC',
    );

    final ore = oreRichieste(data);
    final righeOre = await db.query(
      'MeteoOrario',
      where: 'cella_id = ? AND data_ora BETWEEN ? AND ?',
      whereArgs: [
        cella.id,
        DbMappers.formatDataOra(ore.first),
        DbMappers.formatDataOra(ore.last),
      ],
      orderBy: 'data_ora ASC',
    );

    return MeteoPescata(
      stato: stato,
      cella: cella,
      giorni: righeGiorni.map(DbMappers.meteoGiornoFromMap).toList(),
      ore: righeOre.map(DbMappers.meteoOraFromMap).toList(),
    );
  }

  // ===========================================================================
  // HELPER PRIVATI
  // ===========================================================================

  Future<StatoMeteo> _calcolaStato(DatabaseExecutor db, int pescataId) async {
    final righe = await db.rawQuery('''
      SELECT p.data,
             c.latitudine AS lat_spot, c.longitudine AS lon_spot,
             pm.data AS pm_data, pm.latitudine AS pm_lat, pm.longitudine AS pm_lon
      FROM Pescata p
      LEFT JOIN Coordinata c ON c.spot_nome = p.spot_nome
        AND c.ordine = (SELECT MIN(ordine) FROM Coordinata WHERE spot_nome = p.spot_nome)
      LEFT JOIN PescataMeteo pm ON pm.pescata_id = p.id
      WHERE p.id = ?
    ''', [pescataId]);
    if (righe.isEmpty) {
      throw ArgumentError('Pescata $pescataId inesistente');
    }
    final r = righe.single;
    final haPunto = r['lat_spot'] != null;
    final haRichiesta = r['pm_data'] != null;

    if (haRichiesta && r['pm_data'] == r['data']) {
      // Spot eliminato dopo lo scaricamento: i dati restano validi.
      if (!haPunto) return StatoMeteo.scaricato;
      if (r['pm_lat'] == r['lat_spot'] && r['pm_lon'] == r['lon_spot']) {
        return StatoMeteo.scaricato;
      }
    }
    return haPunto ? StatoMeteo.daScaricare : StatoMeteo.nonDisponibile;
  }

  Future<CellaMeteo> _assicuraCella(DatabaseExecutor txn, CellaMeteo cella) async {
    final esistente = await txn.query(
      'CellaMeteo',
      where: 'latitudine = ? AND longitudine = ? AND elevazione = ?',
      whereArgs: [cella.latitudine, cella.longitudine, cella.elevazione],
      limit: 1,
    );
    if (esistente.isNotEmpty) {
      return DbMappers.cellaMeteoFromMap(esistente.first);
    }
    final nuova = CellaMeteo(
      latitudine: cella.latitudine,
      longitudine: cella.longitudine,
      elevazione: cella.elevazione,
    );
    final id = await txn.insert('CellaMeteo', DbMappers.cellaMeteoToMap(nuova));
    return nuova.copyWith(id: id);
  }

  Future<void> _collegaPescate(
    DatabaseExecutor txn,
    List<RichiestaMeteo> richieste,
    int cellaId,
  ) async {
    for (final r in richieste) {
      await txn.insert(
        'PescataMeteo',
        {
          'pescata_id': r.pescataId,
          'cella_id': cellaId,
          'data': DbMappers.formatData(r.data),
          'latitudine': r.latitudine,
          'longitudine': r.longitudine,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
