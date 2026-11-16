import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../database/db_mappers.dart';
import '../models/battute/cattura_memorabile.dart';
import '../models/battute/esca.dart';
import '../models/battute/foto.dart';
import '../models/battute/pescata.dart';
import '../models/battute/pianificazione.dart';
import '../models/enums.dart';
import '../models/statistiche/caratteristica.dart';
import '../models/statistiche/riepilogo_caratteristica.dart';
import '../models/statistiche/riepilogo_specie.dart';

class BattuteRepository {
  final DatabaseHelper _dbHelper;

  BattuteRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  // ===========================================================================
  // LETTURA
  // ===========================================================================

  /// Elenco esche in ordine alfabetico, con filtro testuale opzionale sul nome.
  Future<List<Esca>> getEsche({String? filtroNome}) async {
    final db = await _dbHelper.database;
    final hasFiltro = filtroNome != null && filtroNome.trim().isNotEmpty;

    final righe = await db.query(
      'Esca',
      where: hasFiltro ? 'LOWER(nome) LIKE LOWER(?)' : null,
      whereArgs: hasFiltro ? ['%${filtroNome.trim()}%'] : null,
      orderBy: 'nome ASC',
    );
    return righe.map(DbMappers.escaFromMap).toList();
  }

  /// Elenco uscite pianificate con filtri opzionali (es. prossime uscite con `daData`).
  Future<List<Pianificazione>> getPianificazioni({
    String? spotNome,
    FasciaOraria? fasciaOraria,
    DateTime? daData,
    DateTime? aData,
  }) async {
    final db = await _dbHelper.database;

    final condizioni = <String>[];
    final argomenti = <Object?>[];

    if (spotNome != null) {
      condizioni.add('spot_nome = ?');
      argomenti.add(spotNome);
    }
    if (fasciaOraria != null) {
      condizioni.add('fasciaOraria = ?');
      argomenti.add(fasciaOraria.name);
    }
    if (daData != null) {
      condizioni.add('data >= ?');
      argomenti.add(DbMappers.formatData(daData));
    }
    if (aData != null) {
      condizioni.add('data <= ?');
      argomenti.add(DbMappers.formatData(aData));
    }

    final righe = await db.query(
      'Pianificazione',
      where: condizioni.isEmpty ? null : condizioni.join(' AND '),
      whereArgs: argomenti.isEmpty ? null : argomenti,
      orderBy: 'data ASC, id ASC',
    );
    return righe.map(DbMappers.pianificazioneFromMap).toList();
  }

  /// Elenco pescate con filtri ambientali e temporali combinabili (senza figli).
  /// Utile per lista generale, ultime N pescate (`limit`), storico spot e filtri.
  Future<List<Pescata>> getPescate({
    String? spotNome,
    Meteo? meteo,
    FasciaOraria? fasciaOraria,
    Trasparenza? trasparenza,
    Livello? livello,
    DateTime? daData,
    DateTime? aData,
    int? limit,
  }) async {
    final db = await _dbHelper.database;

    final condizioni = <String>[];
    final argomenti = <Object?>[];

    if (spotNome != null) {
      condizioni.add('spot_nome = ?');
      argomenti.add(spotNome);
    }
    if (meteo != null) {
      condizioni.add('meteo = ?');
      argomenti.add(meteo.name);
    }
    if (fasciaOraria != null) {
      condizioni.add('fasciaOraria = ?');
      argomenti.add(fasciaOraria.name);
    }
    if (trasparenza != null) {
      condizioni.add('trasparenza = ?');
      argomenti.add(trasparenza.name);
    }
    if (livello != null) {
      condizioni.add('livello = ?');
      argomenti.add(livello.name);
    }
    if (daData != null) {
      condizioni.add('data >= ?');
      argomenti.add(DbMappers.formatData(daData));
    }
    if (aData != null) {
      condizioni.add('data <= ?');
      argomenti.add(DbMappers.formatData(aData));
    }

    final righe = await db.query(
      'Pescata',
      where: condizioni.isEmpty ? null : condizioni.join(' AND '),
      whereArgs: argomenti.isEmpty ? null : argomenti,
      orderBy: 'data DESC, id DESC',
      limit: limit,
    );
    return righe.map((r) => DbMappers.pescataFromMap(r)).toList();
  }

  /// Elenco catture memorabili filtrabili per pescata, specie o esca, complete
  /// di esca, caratteristiche e foto.
  Future<List<CatturaMemorabile>> getCattureMemorabili({
    int? pescataId,
    String? specieNome,
    int? escaId,
    int? limit,
  }) async {
    final db = await _dbHelper.database;
    return _queryCattureConDettagli(
      db,
      pescataId: pescataId,
      specieNome: specieNome,
      escaId: escaId,
      limit: limit,
    );
  }

  /// Dettaglio completo di una pescata con esche, foto, catture e riepiloghi.
  Future<Pescata?> getPescataCompleta(int id) async {
    final db = await _dbHelper.database;
    final righePescata = await db.query(
      'Pescata',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (righePescata.isEmpty) return null;

    // 1. Esche usate
    final righeEsche = await db.rawQuery('''
      SELECT e.* FROM Esca e
      INNER JOIN Pescata_Esca pe ON pe.esca_id = e.id
      WHERE pe.pescata_id = ?
      ORDER BY e.nome ASC
    ''', [id]);
    final esche = righeEsche.map(DbMappers.escaFromMap).toList();

    // 2. Foto della pescata
    final righeFoto = await db.query(
      'Foto',
      where: 'pescata_id = ?',
      whereArgs: [id],
      orderBy: 'id ASC',
    );
    final foto = righeFoto.map(DbMappers.fotoFromMap).toList();

    // 3. Catture memorabili
    final catture = await _queryCattureConDettagli(db, pescataId: id);

    // 4. Riepiloghi specie con dettagli per caratteristica (query condivisa)
    final riepiloghi = await DbMappers.queryRiepiloghiConDettagli(
      db,
      pescataId: id,
    );

    return DbMappers.pescataFromMap(
      righePescata.first,
      esche: esche,
      foto: foto,
      cattureMemorabili: catture,
      riepiloghiSpecie: riepiloghi,
    );
  }

  // ===========================================================================
  // SCRITTURA ED ELIMINAZIONE
  // ===========================================================================

  Future<Esca> salvaEsca(Esca esca) async {
    final db = await _dbHelper.database;
    if (esca.id == null) {
      final id = await db.insert('Esca', DbMappers.escaToMap(esca));
      return esca.copyWith(id: id);
    }
    await db.update(
      'Esca',
      DbMappers.escaToMap(esca),
      where: 'id = ?',
      whereArgs: [esca.id],
    );
    return esca;
  }

  Future<void> eliminaEsca(int id) async {
    final db = await _dbHelper.database;
    await db.delete('Esca', where: 'id = ?', whereArgs: [id]);
  }

  Future<Pianificazione> salvaPianificazione(Pianificazione p) async {
    final db = await _dbHelper.database;
    if (p.id == null) {
      final id =
          await db.insert('Pianificazione', DbMappers.pianificazioneToMap(p));
      return p.copyWith(id: id);
    }
    await db.update(
      'Pianificazione',
      DbMappers.pianificazioneToMap(p),
      where: 'id = ?',
      whereArgs: [p.id],
    );
    return p;
  }

  Future<void> eliminaPianificazione(int id) async {
    final db = await _dbHelper.database;
    await db.delete('Pianificazione', where: 'id = ?', whereArgs: [id]);
  }

  /// Inserisce o aggiorna atomicamente una Pescata insieme a esche, foto,
  /// riepiloghi specie con dettagli e catture memorabili, aggiornando
  /// anche lo stato `battuto` dello spot.
  Future<Pescata> salvaPescata(Pescata pescata) async {
    for (final r in pescata.riepiloghiSpecie) {
      _validaRiepilogoSpecie(r);
    }

    final db = await _dbHelper.database;
    final percorsiFotoDaRimuovere = <String>{};

    final risultato = await db.transaction((txn) async {
      late final int pescataId;
      String? vecchioSpotNome;

      if (pescata.id == null) {
        pescataId = await txn.insert('Pescata', DbMappers.pescataToMap(pescata));
      } else {
        pescataId = pescata.id!;

        final prevPescata = await txn.query(
          'Pescata',
          columns: ['spot_nome'],
          where: 'id = ?',
          whereArgs: [pescataId],
          limit: 1,
        );
        if (prevPescata.isNotEmpty) {
          vecchioSpotNome = prevPescata.first['spot_nome'] as String?;
        }

        final vecchieFoto = await txn.rawQuery('''
          SELECT percorso, percorsoThumbnail FROM Foto
          WHERE pescata_id = ?
             OR cattura_memorabile_id IN (
               SELECT id FROM CatturaMemorabile WHERE pescata_id = ?
             )
        ''', [pescataId, pescataId]);
        for (final f in vecchieFoto) {
          percorsiFotoDaRimuovere.add(f['percorso'] as String);
          percorsiFotoDaRimuovere.add(f['percorsoThumbnail'] as String);
        }

        await txn.delete(
          'Pescata_Esca',
          where: 'pescata_id = ?',
          whereArgs: [pescataId],
        );
        await txn.delete(
          'Foto',
          where: 'pescata_id = ?',
          whereArgs: [pescataId],
        );
        await txn.delete(
          'RiepilogoSpecie',
          where: 'pescata_id = ?',
          whereArgs: [pescataId],
        );
        await txn.delete(
          'CatturaMemorabile',
          where: 'pescata_id = ?',
          whereArgs: [pescataId],
        );

        await txn.update(
          'Pescata',
          DbMappers.pescataToMap(pescata),
          where: 'id = ?',
          whereArgs: [pescataId],
        );
      }

      // 1. Esche (salva al volo se id == null)
      final escheSalvate = <Esca>[];
      for (final esca in pescata.esche) {
        final escaAllineata = await _assicuraEscaSalvata(txn, esca);
        await txn.insert('Pescata_Esca', {
          'pescata_id': pescataId,
          'esca_id': escaAllineata.id!,
        });
        escheSalvate.add(escaAllineata);
      }

      // 2. Foto della pescata
      final fotoSalvate = <Foto>[];
      for (final f in pescata.foto) {
        final fotoAllineata = Foto(
          percorso: f.percorso,
          percorsoThumbnail: f.percorsoThumbnail,
          pescataId: pescataId,
          catturaMemorabileId: null,
        );
        final fotoId = await txn.insert('Foto', DbMappers.fotoToMap(fotoAllineata));
        fotoSalvate.add(fotoAllineata.copyWith(id: fotoId));
        percorsiFotoDaRimuovere.remove(f.percorso);
        percorsiFotoDaRimuovere.remove(f.percorsoThumbnail);
      }

      // 3. Riepiloghi specie con dettagli per caratteristica
      final riepiloghiSalvati = <RiepilogoSpecie>[];
      for (final r in pescata.riepiloghiSpecie) {
        final riepilogoAllineato = r.copyWith(pescataId: pescataId);
        final riepilogoId = await txn.insert(
          'RiepilogoSpecie',
          DbMappers.riepilogoSpecieToMap(riepilogoAllineato),
        );

        final dettagliSalvati = <RiepilogoCaratteristica>[];
        for (final d in r.dettagli) {
          final carattAllineata = await _assicuraCaratteristicaSalvata(
            txn,
            d.caratteristica,
            specieAttesa: r.specieNome,
          );
          final dettaglioAllineato = d.copyWith(
            riepilogoSpecieId: riepilogoId,
            caratteristica: carattAllineata,
          );
          await txn.insert(
            'DettaglioRiepilogo',
            DbMappers.riepilogoCaratteristicaToMap(
              dettaglioAllineato,
              specieNome: r.specieNome,
            ),
          );
          dettagliSalvati.add(dettaglioAllineato);
        }

        riepiloghiSalvati.add(
          riepilogoAllineato.copyWith(id: riepilogoId, dettagli: dettagliSalvati),
        );
      }

      // 4. Catture memorabili con caratteristiche e foto
      final cattureSalvate = <CatturaMemorabile>[];
      for (final c in pescata.cattureMemorabili) {
        final salvata = await _inserisciCatturaInTransazione(
          txn,
          c.copyWith(pescataId: pescataId),
          percorsiFotoDaRimuovere,
        );
        cattureSalvate.add(salvata);
      }

      // 5. Sincronizza stato battuto dello spot (vecchio e nuovo)
      if (vecchioSpotNome != null && vecchioSpotNome != pescata.spotNome) {
        await _aggiornaStatoBattutoSpot(txn, vecchioSpotNome);
      }
      await _aggiornaStatoBattutoSpot(txn, pescata.spotNome);

      return pescata.copyWith(
        id: pescataId,
        esche: escheSalvate,
        foto: fotoSalvate,
        riepiloghiSpecie: riepiloghiSalvati,
        cattureMemorabili: cattureSalvate,
      );
    });

    await _eliminaFileSuDisco(percorsiFotoDaRimuovere);
    return risultato;
  }

  Future<void> eliminaPescata(int id) async {
    final db = await _dbHelper.database;
    final percorsiFotoDaRimuovere = <String>[];

    await db.transaction((txn) async {
      final rows = await txn.query(
        'Pescata',
        columns: ['spot_nome'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final spotNome = rows.first['spot_nome'] as String?;

      final fotoRows = await txn.rawQuery('''
        SELECT percorso, percorsoThumbnail FROM Foto
        WHERE pescata_id = ?
           OR cattura_memorabile_id IN (
             SELECT id FROM CatturaMemorabile WHERE pescata_id = ?
           )
      ''', [id, id]);
      for (final f in fotoRows) {
        percorsiFotoDaRimuovere.add(f['percorso'] as String);
        percorsiFotoDaRimuovere.add(f['percorsoThumbnail'] as String);
      }

      await txn.delete('Pescata', where: 'id = ?', whereArgs: [id]);
      await _aggiornaStatoBattutoSpot(txn, spotNome);
    });

    await _eliminaFileSuDisco(percorsiFotoDaRimuovere);
  }

  /// Inserisce o aggiorna una CatturaMemorabile con caratteristiche e foto.
  Future<CatturaMemorabile> salvaCatturaMemorabile(
    CatturaMemorabile cattura,
  ) async {
    if (cattura.pescataId == null) {
      throw ArgumentError(
        'pescataId è obbligatorio per salvare una CatturaMemorabile singolarmente',
      );
    }

    final db = await _dbHelper.database;
    final percorsiFotoDaRimuovere = <String>{};

    final risultato = await db.transaction((txn) async {
      if (cattura.id == null) {
        return await _inserisciCatturaInTransazione(
          txn,
          cattura,
          percorsiFotoDaRimuovere,
        );
      }

      final catturaId = cattura.id!;

      final vecchieFoto = await txn.query(
        'Foto',
        columns: ['percorso', 'percorsoThumbnail'],
        where: 'cattura_memorabile_id = ?',
        whereArgs: [catturaId],
      );
      for (final f in vecchieFoto) {
        percorsiFotoDaRimuovere.add(f['percorso'] as String);
        percorsiFotoDaRimuovere.add(f['percorsoThumbnail'] as String);
      }

      // PRIMA elimina i figli, POI aggiorna il padre (evita errori FK composta al cambio specie)
      await txn.delete(
        'Cattura_Caratteristica',
        where: 'cattura_memorabile_id = ?',
        whereArgs: [catturaId],
      );
      await txn.delete(
        'Foto',
        where: 'cattura_memorabile_id = ?',
        whereArgs: [catturaId],
      );

      final escaRisolta = cattura.esca != null
          ? await _assicuraEscaSalvata(txn, cattura.esca!)
          : null;
      final catturaAllineata = cattura.copyWith(esca: escaRisolta);

      await txn.update(
        'CatturaMemorabile',
        DbMappers.catturaToMap(catturaAllineata),
        where: 'id = ?',
        whereArgs: [catturaId],
      );

      return await _salvaFigliCattura(
        txn,
        catturaAllineata,
        percorsiFotoDaRimuovere,
      );
    });

    await _eliminaFileSuDisco(percorsiFotoDaRimuovere);
    return risultato;
  }

  Future<void> eliminaCatturaMemorabile(int id) async {
    final db = await _dbHelper.database;
    final percorsiFotoDaRimuovere = <String>[];

    await db.transaction((txn) async {
      final fotoRows = await txn.query(
        'Foto',
        columns: ['percorso', 'percorsoThumbnail'],
        where: 'cattura_memorabile_id = ?',
        whereArgs: [id],
      );
      for (final f in fotoRows) {
        percorsiFotoDaRimuovere.add(f['percorso'] as String);
        percorsiFotoDaRimuovere.add(f['percorsoThumbnail'] as String);
      }

      await txn.delete('CatturaMemorabile', where: 'id = ?', whereArgs: [id]);
    });

    await _eliminaFileSuDisco(percorsiFotoDaRimuovere);
  }

  // ===========================================================================
  // HELPER PRIVATI
  // ===========================================================================

  void _validaRiepilogoSpecie(RiepilogoSpecie r) {
    if (r.quantita < 0) {
      throw ArgumentError(
        'La quantità totale per ${r.specieNome} non può essere negativa',
      );
    }
    for (final d in r.dettagli) {
      if (d.quantita < 0) {
        throw ArgumentError('La quantità del dettaglio non può essere negativa');
      }
      if (d.quantita > r.quantita) {
        throw ArgumentError(
          'Il dettaglio (${d.quantita}) non può superare il totale (${r.quantita}) per ${r.specieNome}',
        );
      }
    }
  }

  Future<Esca> _assicuraEscaSalvata(Transaction txn, Esca esca) async {
    if (esca.id != null) return esca;
    final id = await txn.insert('Esca', DbMappers.escaToMap(esca));
    return esca.copyWith(id: id);
  }

  Future<Caratteristica> _assicuraCaratteristicaSalvata(
    Transaction txn,
    Caratteristica c, {
    required String specieAttesa,
  }) async {
    if (c.id != null) return c;
    if (c.specieNome != specieAttesa) {
      throw ArgumentError(
        'La nuova caratteristica "${c.nome}" appartiene a ${c.specieNome}, non a $specieAttesa',
      );
    }
    final id = await txn.insert(
      'Caratteristica',
      DbMappers.caratteristicaToMap(c),
    );
    return c.copyWith(id: id);
  }

  Future<CatturaMemorabile> _inserisciCatturaInTransazione(
    Transaction txn,
    CatturaMemorabile cattura,
    Set<String> percorsiFotoDaRimuovere,
  ) async {
    final escaRisolta = cattura.esca != null
        ? await _assicuraEscaSalvata(txn, cattura.esca!)
        : null;

    final catturaDaInserire = cattura.copyWith(esca: escaRisolta);
    final catturaId = await txn.insert(
      'CatturaMemorabile',
      DbMappers.catturaToMap(catturaDaInserire),
    );

    return await _salvaFigliCattura(
      txn,
      catturaDaInserire.copyWith(id: catturaId),
      percorsiFotoDaRimuovere,
    );
  }

  Future<CatturaMemorabile> _salvaFigliCattura(
    Transaction txn,
    CatturaMemorabile cattura,
    Set<String> percorsiFotoDaRimuovere,
  ) async {
    final catturaId = cattura.id!;
    final carattSalvate = <Caratteristica>[];

    for (final caratt in cattura.caratteristiche) {
      final carattAllineata = await _assicuraCaratteristicaSalvata(
        txn,
        caratt,
        specieAttesa: cattura.specieNome,
      );
      await txn.insert('Cattura_Caratteristica', {
        'cattura_memorabile_id': catturaId,
        'caratteristica_id': carattAllineata.id!,
        'specie_nome': cattura.specieNome,
      });
      carattSalvate.add(carattAllineata);
    }

    final fotoSalvate = <Foto>[];
    for (final f in cattura.foto) {
      final fotoAllineata = Foto(
        percorso: f.percorso,
        percorsoThumbnail: f.percorsoThumbnail,
        pescataId: null,
        catturaMemorabileId: catturaId,
      );
      final fotoId = await txn.insert('Foto', DbMappers.fotoToMap(fotoAllineata));
      fotoSalvate.add(fotoAllineata.copyWith(id: fotoId));
      percorsiFotoDaRimuovere.remove(f.percorso);
      percorsiFotoDaRimuovere.remove(f.percorsoThumbnail);
    }

    return cattura.copyWith(
      caratteristiche: carattSalvate,
      foto: fotoSalvate,
    );
  }

  Future<void> _aggiornaStatoBattutoSpot(
    DatabaseExecutor db,
    String? spotNome,
  ) async {
    if (spotNome == null) return;
    await db.rawUpdate('''
      UPDATE Spot
      SET battuto = CASE
        WHEN EXISTS (SELECT 1 FROM Pescata WHERE spot_nome = ?) THEN 1
        ELSE 0
      END
      WHERE nome = ?
    ''', [spotNome, spotNome]);
  }

  Future<void> _eliminaFileSuDisco(Iterable<String> percorsi) async {
    for (final path in percorsi) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } on FileSystemException {
        // Ignora file già assenti o percorsi virtuali nei test
      }
    }
  }

  Future<List<CatturaMemorabile>> _queryCattureConDettagli(
    DatabaseExecutor db, {
    int? pescataId,
    String? specieNome,
    int? escaId,
    int? limit,
  }) async {
    final condizioni = <String>[];
    final argomenti = <Object?>[];

    if (pescataId != null) {
      condizioni.add('cm.pescata_id = ?');
      argomenti.add(pescataId);
    }
    if (specieNome != null) {
      condizioni.add('cm.specie_nome = ?');
      argomenti.add(specieNome);
    }
    if (escaId != null) {
      condizioni.add('cm.esca_id = ?');
      argomenti.add(escaId);
    }

    final whereSql =
        condizioni.isEmpty ? '' : 'WHERE ${condizioni.join(' AND ')}';
    final limitSql = limit != null ? 'LIMIT ?' : '';
    if (limit != null) argomenti.add(limit);

    final righeCatture = await db.rawQuery('''
      SELECT cm.*,
             e.id AS e_id, e.nome AS e_nome, e.descrizione AS e_descrizione
      FROM CatturaMemorabile cm
      LEFT JOIN Esca e ON e.id = cm.esca_id
      $whereSql
      ORDER BY cm.id DESC
      $limitSql
    ''', argomenti);

    final catture = <CatturaMemorabile>[];
    for (final rc in righeCatture) {
      final catturaId = rc['id'] as int;

      final esca = rc['e_id'] != null
          ? Esca(
              id: rc['e_id'] as int,
              nome: rc['e_nome'] as String,
              descrizione: rc['e_descrizione'] as String?,
            )
          : null;

      final righeCaratt = await db.rawQuery('''
        SELECT c.* FROM Caratteristica c
        INNER JOIN Cattura_Caratteristica cc ON cc.caratteristica_id = c.id
        WHERE cc.cattura_memorabile_id = ?
        ORDER BY c.nome ASC
      ''', [catturaId]);

      final righeFoto = await db.query(
        'Foto',
        where: 'cattura_memorabile_id = ?',
        whereArgs: [catturaId],
        orderBy: 'id ASC',
      );

      catture.add(
        DbMappers.catturaFromMap(
          rc,
          esca: esca,
          caratteristiche:
              righeCaratt.map(DbMappers.caratteristicaFromMap).toList(),
          foto: righeFoto.map(DbMappers.fotoFromMap).toList(),
        ),
      );
    }
    return catture;
  }
}