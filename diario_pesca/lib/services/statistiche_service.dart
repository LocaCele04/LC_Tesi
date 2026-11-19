import '../data/database_helper.dart';
import '../data/query_condivise.dart';
import '../models/enums.dart';
import '../models/pescate/riepilogo_specie.dart';
import '../repositories/meteo_repository.dart';

/// Statistiche e riepiloghi calcolati sullo storico: medie, conteggi,
/// confronti tra anni, progresso degli obiettivi.
///
/// È un servizio di sola lettura: interroga direttamente il livello dati con
/// query di aggregazione che attraversano più aggregati (pescate, spot,
/// specie, obiettivi) e non scrive mai nel database. I dati si modificano
/// solo tramite i repository.
class StatisticheService {
  final DatabaseHelper _dbHelper;
  final MeteoRepository _meteo;

  StatisticheService({DatabaseHelper? dbHelper, MeteoRepository? meteo})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _meteo = meteo ?? MeteoRepository(dbHelper: dbHelper);

  /// Riepiloghi specie (con dettagli per caratteristica) filtrabili per
  /// pescata e/o specie: ad esempio tutte le catture di trota registrate.
  Future<List<RiepilogoSpecie>> getRiepiloghi({
    int? pescataId,
    String? specieNome,
  }) async {
    final db = await _dbHelper.database;
    return QueryCondivise.riepiloghiConDettagli(
      db,
      pescataId: pescataId,
      specieNome: specieNome,
    );
  }

  /// Pioggia caduta (mm) nei [giorni] giorni precedenti la pescata
  /// [pescataId], escluso il giorno della pescata: per esempio 3 per i dati
  /// recenti, 14 per il recupero di un torrente, 30 per un fiume.
  ///
  /// Restituisce `null` se il meteo della pescata non è scaricato. [giorni]
  /// deve essere tra 1 e [MeteoRepository.giorniPrecedenti].
  Future<double?> getPioggiaCumulata(int pescataId, {required int giorni}) async {
    if (giorni < 1 || giorni > MeteoRepository.giorniPrecedenti) {
      throw ArgumentError.value(
        giorni,
        'giorni',
        'deve essere tra 1 e ${MeteoRepository.giorniPrecedenti}',
      );
    }
    if (await _meteo.getStatoMeteo(pescataId) != StatoMeteo.scaricato) {
      return null;
    }

    final db = await _dbHelper.database;
    final righe = await db.rawQuery('''
      SELECT SUM(mg.pioggia_mm) AS totale
      FROM PescataMeteo pm
      INNER JOIN MeteoGiornaliero mg ON mg.cella_id = pm.cella_id
      WHERE pm.pescata_id = ?
        AND mg.data >= date(pm.data, ?)
        AND mg.data < pm.data
    ''', [pescataId, '-$giorni days']);
    return (righe.single['totale'] as num?)?.toDouble();
  }
}
