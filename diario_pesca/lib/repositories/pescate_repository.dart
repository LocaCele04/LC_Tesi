import 'package:sqflite/sqflite.dart';

import '../data/archivio_foto.dart';
import '../data/database_helper.dart';
import '../data/db_mappers.dart';
import '../data/query_condivise.dart';
import '../models/catalogo/caratteristica.dart';
import '../models/catalogo/esca.dart';
import '../models/catalogo/valore_condizione.dart';
import '../models/enums.dart';
import '../models/foto.dart';
import '../models/pescate/cattura_memorabile.dart';
import '../models/pescate/pescata.dart';
import '../models/pescate/pianificazione.dart';
import '../models/pescate/riepilogo_caratteristica.dart';
import '../models/pescate/riepilogo_specie.dart';
import 'catalogo_repository.dart';

/// Pescate con tutto ciò che contengono (riepiloghi specie con dettagli,
/// catture memorabili, foto, legami con le esche) e pianificazioni.
///
/// È l'unico componente che scrive le tabelle `Pescata`, `Pescata_Condizione`,
/// `Pescata_Esca`, `RiepilogoSpecie`, `DettaglioRiepilogo`, `CatturaMemorabile`,
/// `Cattura_Caratteristica`, `Pianificazione` e le foto di pescate e catture.
/// Esche e caratteristiche nuove vengono create tramite il
/// [CatalogoRepository] dentro la stessa transazione.
class PescateRepository {
  final DatabaseHelper _dbHelper;
  final CatalogoRepository _catalogo;
  final ArchivioFoto _archivioFoto;

  PescateRepository({
    DatabaseHelper? dbHelper,
    CatalogoRepository? catalogo,
    ArchivioFoto archivioFoto = const ArchivioFoto(),
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _catalogo = catalogo ??
            CatalogoRepository(dbHelper: dbHelper, archivioFoto: archivioFoto),
        _archivioFoto = archivioFoto;

  // ===========================================================================
  // LETTURA
  // ===========================================================================

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

  /// Elenco pescate con filtri combinabili (senza figli). Utile per lista
  /// generale, ultime N pescate (`limit`), storico spot e filtri.
  ///
  /// [valoriCondizioni] restituisce solo le pescate che hanno **tutti** i
  /// valori indicati (es. Livello = Morbida e Trasparenza = Velata).
  Future<List<Pescata>> getPescate({
    String? spotNome,
    FasciaOraria? fasciaOraria,
    List<int> valoriCondizioni = const [],
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
    if (fasciaOraria != null) {
      condizioni.add('fasciaOraria = ?');
      argomenti.add(fasciaOraria.name);
    }
    for (final valoreId in valoriCondizioni.toSet()) {
      condizioni.add(
        'EXISTS (SELECT 1 FROM Pescata_Condizione pc '
        'WHERE pc.pescata_id = Pescata.id AND pc.valore_id = ?)',
      );
      argomenti.add(valoreId);
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

  /// Numero totale di catture (somma dei riepiloghi di tutte le specie) per
  /// ogni pescata che ne ha almeno una, per id della pescata. Serve agli
  /// elenchi, che non caricano i riepiloghi di ogni pescata.
  Future<Map<int, int>> getTotaliCatture() async {
    final db = await _dbHelper.database;
    final righe = await db.rawQuery('''
      SELECT pescata_id, SUM(quantita) AS totale
      FROM RiepilogoSpecie
      GROUP BY pescata_id
      HAVING SUM(quantita) > 0
    ''');
    return {
      for (final r in righe) r['pescata_id'] as int: (r['totale'] as num).toInt(),
    };
  }

  /// Elenco catture memorabili filtrabili per pescata, specie o esca, complete
  /// di esca (con relative foto), caratteristiche e foto.
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

    // 1. Esche usate (con relative foto)
    final righeEsche = await db.rawQuery('''
      SELECT e.* FROM Esca e
      INNER JOIN Pescata_Esca pe ON pe.esca_id = e.id
      WHERE pe.pescata_id = ?
      ORDER BY e.nome ASC
    ''', [id]);
    final escaIds = righeEsche.map((r) => r['id'] as int).toList();
    final fotoPerEsca = await _catalogo.caricaFotoPerEsche(db, escaIds);
    final esche = righeEsche.map((r) {
      final escaId = r['id'] as int;
      return DbMappers.escaFromMap(
        r,
        foto: fotoPerEsca[escaId] ?? const [],
      );
    }).toList();

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
    final riepiloghi = await QueryCondivise.riepiloghiConDettagli(
      db,
      pescataId: id,
    );

    // 5. Valori delle condizioni, nell'ordine delle condizioni nel form
    final righeCondizioni = await db.rawQuery('''
      SELECT v.* FROM ValoreCondizione v
      INNER JOIN Pescata_Condizione pc ON pc.valore_id = v.id
      INNER JOIN Condizione c ON c.id = pc.condizione_id
      WHERE pc.pescata_id = ?
      ORDER BY c.ordine ASC, c.nome ASC
    ''', [id]);
    final valoriCondizioni =
        righeCondizioni.map(DbMappers.valoreCondizioneFromMap).toList();

    return DbMappers.pescataFromMap(
      righePescata.first,
      esche: esche,
      foto: foto,
      cattureMemorabili: catture,
      riepiloghiSpecie: riepiloghi,
      valoriCondizioni: valoriCondizioni,
    );
  }

  // ===========================================================================
  // SCRITTURA ED ELIMINAZIONE
  // ===========================================================================

  Future<Pianificazione> salvaPianificazione(Pianificazione p) async {
    final db = await _dbHelper.database;
    if (p.isNuovo) {
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

  /// Inserisce o aggiorna atomicamente una Pescata insieme ai valori delle
  /// condizioni, esche, foto, riepiloghi specie con dettagli e catture
  /// memorabili, aggiornando
  /// anche lo stato `battuto` dello spot.
  ///
  /// Lo spot è obbligatorio. Nel database `spot_nome` resta nullable solo per
  /// permettere `ON DELETE SET NULL`: quando uno spot viene eliminato le sue
  /// pescate restano nello storico senza spot. Per questo l'unico caso
  /// ammesso senza spot è l'aggiornamento di una pescata che lo ha già perso.
  Future<Pescata> salvaPescata(Pescata pescata) async {
    final spotIndicato =
        pescata.spotNome != null && pescata.spotNome!.trim().isNotEmpty;
    if (pescata.isNuovo && !spotIndicato) {
      throw ArgumentError('Lo spot è obbligatorio per registrare una pescata');
    }
    for (final r in pescata.riepiloghiSpecie) {
      _validaRiepilogoSpecie(r);
    }
    _validaValoriCondizioni(pescata.valoriCondizioni);

    final db = await _dbHelper.database;
    final percorsiFotoDaRimuovere = <String>{};

    final risultato = await db.transaction((txn) async {
      late final int pescataId;
      String? vecchioSpotNome;

      if (pescata.isNuovo) {
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
        if (!spotIndicato && vecchioSpotNome != null) {
          throw ArgumentError(
            'Non è possibile rimuovere lo spot da una pescata che ne ha uno',
          );
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
          'Pescata_Condizione',
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

      // 0. Valori delle condizioni (al massimo uno per condizione)
      for (final v in pescata.valoriCondizioni) {
        await txn.insert('Pescata_Condizione', {
          'pescata_id': pescataId,
          'condizione_id': v.condizioneId,
          'valore_id': v.id,
        });
      }

      // 1. Esche (salva al volo se id == null)
      final escheSalvate = <Esca>[];
      for (final esca in pescata.esche) {
        final escaAllineata = await _catalogo.assicuraEscaSalvata(txn, esca);
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
          escaId: null,
        );
        final fotoId =
            await txn.insert('Foto', DbMappers.fotoToMap(fotoAllineata));
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
          final carattAllineata = await _catalogo.assicuraCaratteristicaSalvata(
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
        await QueryCondivise.aggiornaStatoBattutoSpot(txn, vecchioSpotNome);
      }
      await QueryCondivise.aggiornaStatoBattutoSpot(txn, pescata.spotNome);

      return pescata.copyWith(
        id: pescataId,
        esche: escheSalvate,
        foto: fotoSalvate,
        riepiloghiSpecie: riepiloghiSalvati,
        cattureMemorabili: cattureSalvate,
      );
    });

    await _archivioFoto.eliminaFile(percorsiFotoDaRimuovere);
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
      await QueryCondivise.aggiornaStatoBattutoSpot(txn, spotNome);
    });

    await _archivioFoto.eliminaFile(percorsiFotoDaRimuovere);
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
      if (cattura.isNuovo) {
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
          ? await _catalogo.assicuraEscaSalvata(txn, cattura.esca!)
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

    await _archivioFoto.eliminaFile(percorsiFotoDaRimuovere);
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

    await _archivioFoto.eliminaFile(percorsiFotoDaRimuovere);
  }

  // ===========================================================================
  // HELPER PRIVATI
  // ===========================================================================

  /// I valori delle condizioni devono essere già salvati (si scelgono da un
  /// elenco, non si creano dalla pescata) e al massimo uno per condizione.
  void _validaValoriCondizioni(List<ValoreCondizione> valori) {
    final condizioniViste = <int>{};
    for (final v in valori) {
      if (v.isNuovo || v.condizioneId == null) {
        throw ArgumentError(
          'Il valore "${v.nome}" non è salvato: i valori delle condizioni si scelgono tra quelli esistenti',
        );
      }
      if (!condizioniViste.add(v.condizioneId!)) {
        throw ArgumentError(
          'Una pescata può avere un solo valore per ogni condizione',
        );
      }
    }
  }

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

  Future<CatturaMemorabile> _inserisciCatturaInTransazione(
    Transaction txn,
    CatturaMemorabile cattura,
    Set<String> percorsiFotoDaRimuovere,
  ) async {
    final escaRisolta = cattura.esca != null
        ? await _catalogo.assicuraEscaSalvata(txn, cattura.esca!)
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
      final carattAllineata = await _catalogo.assicuraCaratteristicaSalvata(
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
        escaId: null,
      );
      final fotoId =
          await txn.insert('Foto', DbMappers.fotoToMap(fotoAllineata));
      fotoSalvate.add(fotoAllineata.copyWith(id: fotoId));
      percorsiFotoDaRimuovere.remove(f.percorso);
      percorsiFotoDaRimuovere.remove(f.percorsoThumbnail);
    }

    return cattura.copyWith(
      caratteristiche: carattSalvate,
      foto: fotoSalvate,
    );
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

    final escaIds = righeCatture
        .map((rc) => rc['e_id'] as int?)
        .whereType<int>()
        .toSet()
        .toList();
    final fotoPerEsca = await _catalogo.caricaFotoPerEsche(db, escaIds);

    final catture = <CatturaMemorabile>[];
    for (final rc in righeCatture) {
      final catturaId = rc['id'] as int;
      final joinedEscaId = rc['e_id'] as int?;

      final esca = joinedEscaId != null
          ? Esca(
              id: joinedEscaId,
              nome: rc['e_nome'] as String,
              descrizione: rc['e_descrizione'] as String?,
              foto: fotoPerEsca[joinedEscaId] ?? const [],
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