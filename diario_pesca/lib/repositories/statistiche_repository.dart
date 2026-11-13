import '../database/database_helper.dart';
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
    return righe.map(_specieFromMap).toList();
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
    return righe.map(_caratteristicaFromMap).toList();
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
      condizioni.add('anno = ?');
      argomenti.add(anno);
    }
    if (specieNome != null) {
      condizioni.add('specie_nome = ?');
      argomenti.add(specieNome);
    }
    if (caratteristicaId != null) {
      condizioni.add('caratteristica_id = ?');
      argomenti.add(caratteristicaId);
    }
    if (soloGenerici != null) {
      condizioni.add(
        soloGenerici
            ? 'caratteristica_id IS NULL'
            : 'caratteristica_id IS NOT NULL',
      );
    }

    final righe = await db.query(
      'Obiettivo',
      where: condizioni.isEmpty ? null : condizioni.join(' AND '),
      whereArgs: argomenti.isEmpty ? null : argomenti,
      orderBy: 'anno DESC, specie_nome ASC, id ASC',
    );
    return righe.map(_obiettivoFromMap).toList();
  }

  /// Elenco riepiloghi specie filtrabili per pescata e/o specie, completi
  /// dei rispettivi dettagli per caratteristica (`DettaglioRiepilogo`).
  Future<List<RiepilogoSpecie>> getRiepiloghi({
    int? pescataId,
    String? specieNome,
  }) async {
    final db = await _dbHelper.database;

    final condizioni = <String>[];
    final argomenti = <Object?>[];

    if (pescataId != null) {
      condizioni.add('pescata_id = ?');
      argomenti.add(pescataId);
    }
    if (specieNome != null) {
      condizioni.add('specie_nome = ?');
      argomenti.add(specieNome);
    }

    final righeRiepilogo = await db.query(
      'RiepilogoSpecie',
      where: condizioni.isEmpty ? null : condizioni.join(' AND '),
      whereArgs: argomenti.isEmpty ? null : argomenti,
      orderBy: 'specie_nome ASC',
    );

    final risultati = <RiepilogoSpecie>[];
    for (final riga in righeRiepilogo) {
      final riepilogoId = riga['id'] as int;
      final righeDettagli = await db.query(
        'DettaglioRiepilogo',
        where: 'riepilogo_specie_id = ?',
        whereArgs: [riepilogoId],
      );
      risultati.add(
        _riepilogoSpecieFromMap(
          riga,
          dettagli:
              righeDettagli.map(_riepilogoCaratteristicaFromMap).toList(),
        ),
      );
    }
    return risultati;
  }

  // ===========================================================================
  // SCRITTURA ED ELIMINAZIONE
  // ===========================================================================

  Future<void> inserisciSpecie(Specie specie) async {
    final db = await _dbHelper.database;
    await db.insert('Specie', _specieToMap(specie));
  }

  Future<void> aggiornaSpecie({
    required String nomeOriginale,
    required Specie specieAggiornata,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'Specie',
      _specieToMap(specieAggiornata),
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
      final id = await db.insert('Caratteristica', _caratteristicaToMap(c));
      return c.copyWith(id: id);
    }
    await db.update(
      'Caratteristica',
      _caratteristicaToMap(c),
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
    if (obiettivo.id == null) {
      final id = await db.insert('Obiettivo', _obiettivoToMap(obiettivo));
      return obiettivo.copyWith(id: id);
    }
    await db.update(
      'Obiettivo',
      _obiettivoToMap(obiettivo),
      where: 'id = ?',
      whereArgs: [obiettivo.id],
    );
    return obiettivo;
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
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      late final int riepilogoId;

      if (riepilogo.id == null) {
        riepilogoId = await txn.insert(
          'RiepilogoSpecie',
          _riepilogoSpecieToMap(riepilogo),
        );
      } else {
        riepilogoId = riepilogo.id!;
        await txn.update(
          'RiepilogoSpecie',
          _riepilogoSpecieToMap(riepilogo),
          where: 'id = ?',
          whereArgs: [riepilogoId],
        );
        await txn.delete(
          'DettaglioRiepilogo',
          where: 'riepilogo_specie_id = ?',
          whereArgs: [riepilogoId],
        );
      }

      final dettagliSalvati = <RiepilogoCaratteristica>[];
      for (final d in riepilogo.dettagli) {
        final allineato = d.copyWith(
          riepilogoSpecieId: riepilogoId,
          specieNome: riepilogo.specieNome,
        );
        await txn.insert(
          'DettaglioRiepilogo',
          _riepilogoCaratteristicaToMap(allineato),
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

  // ===========================================================================
  // MAPPING PRIVATO
  // ===========================================================================

  Specie _specieFromMap(Map<String, Object?> map) => Specie(
        nome: map['nome'] as String,
        informazioni: map['informazioni'] as String?,
      );

  Map<String, Object?> _specieToMap(Specie s) => {
        'nome': s.nome,
        'informazioni': s.informazioni,
      };

  Caratteristica _caratteristicaFromMap(Map<String, Object?> map) =>
      Caratteristica(
        id: map['id'] as int?,
        specieNome: map['specie_nome'] as String,
        nome: map['nome'] as String,
        descrizione: map['descrizione'] as String?,
      );

  Map<String, Object?> _caratteristicaToMap(Caratteristica c) => {
        if (c.id != null) 'id': c.id,
        'specie_nome': c.specieNome,
        'nome': c.nome,
        'descrizione': c.descrizione,
      };

  Obiettivo _obiettivoFromMap(Map<String, Object?> map) => Obiettivo(
        id: map['id'] as int?,
        specieNome: map['specie_nome'] as String,
        anno: map['anno'] as int,
        quantita: map['quantita'] as int,
        caratteristicaId: map['caratteristica_id'] as int?,
      );

  Map<String, Object?> _obiettivoToMap(Obiettivo o) => {
        if (o.id != null) 'id': o.id,
        'specie_nome': o.specieNome,
        'anno': o.anno,
        'quantita': o.quantita,
        'caratteristica_id': o.caratteristicaId,
      };

  RiepilogoCaratteristica _riepilogoCaratteristicaFromMap(
    Map<String, Object?> map,
  ) =>
      RiepilogoCaratteristica(
        riepilogoSpecieId: map['riepilogo_specie_id'] as int,
        caratteristicaId: map['caratteristica_id'] as int,
        specieNome: map['specie_nome'] as String,
        quantita: map['quantita'] as int,
      );

  Map<String, Object?> _riepilogoCaratteristicaToMap(
    RiepilogoCaratteristica d,
  ) =>
      {
        'riepilogo_specie_id': d.riepilogoSpecieId,
        'caratteristica_id': d.caratteristicaId,
        'specie_nome': d.specieNome,
        'quantita': d.quantita,
      };

  RiepilogoSpecie _riepilogoSpecieFromMap(
    Map<String, Object?> map, {
    List<RiepilogoCaratteristica> dettagli = const [],
  }) =>
      RiepilogoSpecie(
        id: map['id'] as int?,
        pescataId: map['pescata_id'] as int,
        specieNome: map['specie_nome'] as String,
        quantita: map['quantita'] as int,
        dettagli: dettagli,
      );

  Map<String, Object?> _riepilogoSpecieToMap(RiepilogoSpecie r) => {
        if (r.id != null) 'id': r.id,
        'pescata_id': r.pescataId,
        'specie_nome': r.specieNome,
        'quantita': r.quantita,
      };
}