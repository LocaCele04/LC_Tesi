import '../database/database_helper.dart';
import '../database/db_mappers.dart';
import '../models/statistiche/caratteristica.dart';
import '../models/statistiche/obiettivo.dart';
import '../models/statistiche/riepilogo_caratteristica.dart';
import '../models/statistiche/riepilogo_specie.dart';
import '../models/statistiche/specie.dart';

class StatisticheRepository {
  final DatabaseHelper _dbHelper;

  StatisticheRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  // ===========================================================================
  // LETTURA
  // ===========================================================================

  /// Elenco specie in ordine alfabetico, con filtro testuale opzionale sul nome.
  Future<List<Specie>> getSpecie({String? filtroNome}) async {
    final db = await _dbHelper.database;
    final hasFiltro = filtroNome != null && filtroNome.trim().isNotEmpty;

    final righe = await db.query(
      'Specie',
      where: hasFiltro ? 'LOWER(nome) LIKE LOWER(?)' : null,
      whereArgs: hasFiltro ? ['%${filtroNome.trim()}%'] : null,
      orderBy: 'nome ASC',
    );
    return righe.map(DbMappers.specieFromMap).toList();
  }

  /// Elenco caratteristiche filtrabili per specie e/o nome.
  Future<List<Caratteristica>> getCaratteristiche({
    String? specieNome,
    String? filtroNome,
  }) async {
    final db = await _dbHelper.database;

    final condizioni = <String>[];
    final argomenti = <Object?>[];

    if (specieNome != null) {
      condizioni.add('specie_nome = ?');
      argomenti.add(specieNome);
    }
    if (filtroNome != null && filtroNome.trim().isNotEmpty) {
      condizioni.add('LOWER(nome) LIKE LOWER(?)');
      argomenti.add('%${filtroNome.trim()}%');
    }

    final righe = await db.query(
      'Caratteristica',
      where: condizioni.isEmpty ? null : condizioni.join(' AND '),
      whereArgs: argomenti.isEmpty ? null : argomenti,
      orderBy: 'specie_nome ASC, nome ASC',
    );
    return righe.map(DbMappers.caratteristicaFromMap).toList();
  }

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

  /// Elenco riepiloghi specie filtrabili per pescata e/o specie, completi
  /// dei rispettivi dettagli per caratteristica (`DettaglioRiepilogo`).
  Future<List<RiepilogoSpecie>> getRiepiloghi({
    int? pescataId,
    String? specieNome,
  }) async {
    final db = await _dbHelper.database;
    return DbMappers.queryRiepiloghiConDettagli(
      db,
      pescataId: pescataId,
      specieNome: specieNome,
    );
  }

  // ===========================================================================
  // SCRITTURA ED ELIMINAZIONE
  // ===========================================================================

  Future<void> inserisciSpecie(Specie specie) async {
    final db = await _dbHelper.database;
    await db.insert('Specie', DbMappers.specieToMap(specie));
  }

  Future<void> aggiornaSpecie({
    required String nomeOriginale,
    required Specie specieAggiornata,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'Specie',
      DbMappers.specieToMap(specieAggiornata),
      where: 'nome = ?',
      whereArgs: [nomeOriginale],
    );
  }

  Future<void> eliminaSpecie(String nome) async {
    final db = await _dbHelper.database;
    await db.delete('Specie', where: 'nome = ?', whereArgs: [nome]);
  }

  Future<Caratteristica> salvaCaratteristica(Caratteristica c) async {
    final db = await _dbHelper.database;
    if (c.id == null) {
      final id =
          await db.insert('Caratteristica', DbMappers.caratteristicaToMap(c));
      return c.copyWith(id: id);
    }

    final esistente = await db.query(
      'Caratteristica',
      columns: ['specie_nome'],
      where: 'id = ?',
      whereArgs: [c.id],
      limit: 1,
    );
    if (esistente.isNotEmpty &&
        esistente.first['specie_nome'] != c.specieNome) {
      final usata = await db.rawQuery('''
        SELECT 1 FROM Cattura_Caratteristica WHERE caratteristica_id = ?
        UNION ALL
        SELECT 1 FROM DettaglioRiepilogo WHERE caratteristica_id = ?
        UNION ALL
        SELECT 1 FROM Obiettivo WHERE caratteristica_id = ?
        LIMIT 1
      ''', [c.id, c.id, c.id]);

      if (usata.isNotEmpty) {
        throw StateError(
          'Impossibile cambiare la specie di una caratteristica già usata in catture, riepiloghi o obiettivi',
        );
      }
    }

    await db.update(
      'Caratteristica',
      DbMappers.caratteristicaToMap(c),
      where: 'id = ?',
      whereArgs: [c.id],
    );
    return c;
  }

  Future<void> eliminaCaratteristica(int id) async {
    final db = await _dbHelper.database;
    await db.delete('Caratteristica', where: 'id = ?', whereArgs: [id]);
  }

  Future<Obiettivo> salvaObiettivo(Obiettivo obiettivo) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      Caratteristica? carattAllineata = obiettivo.caratteristica;

      if (carattAllineata != null && carattAllineata.id == null) {
        if (carattAllineata.specieNome != obiettivo.specieNome) {
          throw ArgumentError(
            'La nuova caratteristica "${carattAllineata.nome}" appartiene a ${carattAllineata.specieNome}, non a ${obiettivo.specieNome}',
          );
        }
        final carattId = await txn.insert(
          'Caratteristica',
          DbMappers.caratteristicaToMap(carattAllineata),
        );
        carattAllineata = carattAllineata.copyWith(id: carattId);
      }

      final obiettivoAllineato =
          obiettivo.copyWith(caratteristica: carattAllineata);

      if (obiettivoAllineato.id == null) {
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

  /// Inserisce o aggiorna in transazione un `RiepilogoSpecie` insieme ai suoi
  /// `DettaglioRiepilogo` per caratteristica.
  Future<RiepilogoSpecie> salvaRiepilogoSpecie(
    RiepilogoSpecie riepilogo,
  ) async {
    if (riepilogo.pescataId == null) {
      throw ArgumentError(
        'pescataId è obbligatorio per salvare un RiepilogoSpecie singolarmente',
      );
    }
    if (riepilogo.quantita < 0) {
      throw ArgumentError(
        'La quantità totale per ${riepilogo.specieNome} non può essere negativa',
      );
    }
    for (final d in riepilogo.dettagli) {
      if (d.quantita < 0) {
        throw ArgumentError('La quantità del dettaglio non può essere negativa');
      }
      if (d.quantita > riepilogo.quantita) {
        throw ArgumentError(
          'Il dettaglio (${d.quantita}) non può superare il totale (${riepilogo.quantita}) per ${riepilogo.specieNome}',
        );
      }
    }

    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      late final int riepilogoId;

      if (riepilogo.id == null) {
        riepilogoId = await txn.insert(
          'RiepilogoSpecie',
          DbMappers.riepilogoSpecieToMap(riepilogo),
        );
      } else {
        riepilogoId = riepilogo.id!;
        await txn.delete(
          'DettaglioRiepilogo',
          where: 'riepilogo_specie_id = ?',
          whereArgs: [riepilogoId],
        );
        await txn.update(
          'RiepilogoSpecie',
          DbMappers.riepilogoSpecieToMap(riepilogo),
          where: 'id = ?',
          whereArgs: [riepilogoId],
        );
      }

      final dettagliSalvati = <RiepilogoCaratteristica>[];
      for (final d in riepilogo.dettagli) {
        var carattAllineata = d.caratteristica;
        if (carattAllineata.id == null) {
          if (carattAllineata.specieNome != riepilogo.specieNome) {
            throw ArgumentError(
              'La nuova caratteristica "${carattAllineata.nome}" appartiene a ${carattAllineata.specieNome}, non a ${riepilogo.specieNome}',
            );
          }
          final carattId = await txn.insert(
            'Caratteristica',
            DbMappers.caratteristicaToMap(carattAllineata),
          );
          carattAllineata = carattAllineata.copyWith(id: carattId);
        }

        final allineato = d.copyWith(
          riepilogoSpecieId: riepilogoId,
          caratteristica: carattAllineata,
        );
        await txn.insert(
          'DettaglioRiepilogo',
          DbMappers.riepilogoCaratteristicaToMap(
            allineato,
            specieNome: riepilogo.specieNome,
          ),
        );
        dettagliSalvati.add(allineato);
      }

      return riepilogo.copyWith(id: riepilogoId, dettagli: dettagliSalvati);
    });
  }

  Future<void> eliminaRiepilogoSpecie(int id) async {
    final db = await _dbHelper.database;
    await db.delete('RiepilogoSpecie', where: 'id = ?', whereArgs: [id]);
  }
}