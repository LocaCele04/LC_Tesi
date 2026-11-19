import '../data/database_helper.dart';
import '../data/query_condivise.dart';
import '../models/pescate/riepilogo_specie.dart';

/// Statistiche e riepiloghi calcolati sullo storico: medie, conteggi,
/// confronti tra anni, progresso degli obiettivi.
///
/// È un servizio di sola lettura: interroga direttamente il livello dati con
/// query di aggregazione che attraversano più aggregati (pescate, spot,
/// specie, obiettivi) e non scrive mai nel database. I dati si modificano
/// solo tramite i repository.
class StatisticheService {
  final DatabaseHelper _dbHelper;

  StatisticheService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

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
}
