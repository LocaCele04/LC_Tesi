import '../data/database_helper.dart';
import '../data/db_mappers.dart';
import '../models/catalogo/caratteristica.dart';
import '../models/obiettivi/obiettivo.dart';
import 'catalogo_repository.dart';

/// Obiettivi annuali del pescatore (quantità per specie, eventualmente
/// limitata a una caratteristica). Il calcolo del progresso è una statistica
/// e spetta allo `StatisticheService`.
class ObiettiviRepository {
  final DatabaseHelper _dbHelper;
  final CatalogoRepository _catalogo;

  ObiettiviRepository({
    DatabaseHelper? dbHelper,
    CatalogoRepository? catalogo,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _catalogo = catalogo ?? CatalogoRepository(dbHelper: dbHelper);

  /// Elenco obiettivi filtrabili per anno, specie, caratteristica o tipologia
  /// (`soloGenerici: true` per obiettivi sull'intera specie, `false` per quelli
  /// legati a una caratteristica specifica).
  Future<List<Obiettivo>> getObiettivi({
    int? anno,
    String? specieNome,
    int? caratteristicaId,
    bool? soloGenerici,
  }) async {
    final db = await _dbHelper.database;

    final condizioni = <String>[];
    final argomenti = <Object?>[];

    if (anno != null) {
      condizioni.add('o.anno = ?');
      argomenti.add(anno);
    }
    if (specieNome != null) {
      condizioni.add('o.specie_nome = ?');
      argomenti.add(specieNome);
    }
    if (caratteristicaId != null) {
      condizioni.add('o.caratteristica_id = ?');
      argomenti.add(caratteristicaId);
    }
    if (soloGenerici != null) {
      condizioni.add(
        soloGenerici
            ? 'o.caratteristica_id IS NULL'
            : 'o.caratteristica_id IS NOT NULL',
      );
    }

    final whereSql =
        condizioni.isEmpty ? '' : 'WHERE ${condizioni.join(' AND ')}';

    final righe = await db.rawQuery('''
      SELECT o.*,
             c.id AS c_id, c.specie_nome AS c_specie_nome,
             c.nome AS c_nome, c.descrizione AS c_descrizione
      FROM Obiettivo o
      LEFT JOIN Caratteristica c ON c.id = o.caratteristica_id
      $whereSql
      ORDER BY o.anno DESC, o.specie_nome ASC, o.id ASC
    ''', argomenti);

    return righe.map((riga) {
      final caratt = riga['c_id'] != null
          ? Caratteristica(
              id: riga['c_id'] as int,
              specieNome: riga['c_specie_nome'] as String,
              nome: riga['c_nome'] as String,
              descrizione: riga['c_descrizione'] as String?,
            )
          : null;
      return DbMappers.obiettivoFromMap(riga, caratteristica: caratt);
    }).toList();
  }

  /// Inserisce o aggiorna un obiettivo. Una caratteristica nuova
  /// (`id == null`) viene creata nella stessa transazione tramite il
  /// [CatalogoRepository]; deve appartenere alla specie dell'obiettivo.
  Future<Obiettivo> salvaObiettivo(Obiettivo obiettivo) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      final caratteristica = obiettivo.caratteristica;
      final carattAllineata = caratteristica != null
          ? await _catalogo.assicuraCaratteristicaSalvata(
              txn,
              caratteristica,
              specieAttesa: obiettivo.specieNome,
            )
          : null;

      final obiettivoAllineato =
          obiettivo.copyWith(caratteristica: carattAllineata);

      if (obiettivoAllineato.isNuovo) {
        final id = await txn.insert(
          'Obiettivo',
          DbMappers.obiettivoToMap(obiettivoAllineato),
        );
        return obiettivoAllineato.copyWith(id: id);
      }

      await txn.update(
        'Obiettivo',
        DbMappers.obiettivoToMap(obiettivoAllineato),
        where: 'id = ?',
        whereArgs: [obiettivoAllineato.id],
      );
      return obiettivoAllineato;
    });
  }

  Future<void> eliminaObiettivo(int id) async {
    final db = await _dbHelper.database;
    await db.delete('Obiettivo', where: 'id = ?', whereArgs: [id]);
  }
}
