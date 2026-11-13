import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
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
    return righe.map(_escaFromMap).toList();
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
      argomenti.add(_formatData(daData));
    }
    if (aData != null) {
      condizioni.add('data <= ?');
      argomenti.add(_formatData(aData));
    }

    final righe = await db.query(
      'Pianificazione',
      where: condizioni.isEmpty ? null : condizioni.join(' AND '),
      whereArgs: argomenti.isEmpty ? null : argomenti,
      orderBy: 'data ASC, id ASC',
    );
    return righe.map(_pianificazioneFromMap).toList();
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
      argomenti.add(_formatData(daData));
    }
    if (aData != null) {
      condizioni.add('data <= ?');
      argomenti.add(_formatData(aData));
    }

    final righe = await db.query(
      'Pescata',
      where: condizioni.isEmpty ? null : condizioni.join(' AND '),
      whereArgs: argomenti.isEmpty ? null : argomenti,
      orderBy: 'data DESC, id DESC',
      limit: limit,
    );
    return righe.map((r) => _pescataFromMap(r)).toList();
  }

  /// Elenco catture memorabili filtrabili per pescata, specie o esca, complete
  /// di caratteristiche e foto.
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
    final esche = righeEsche.map(_escaFromMap).toList();

    // 2. Foto della pescata
    final righeFoto = await db.query(
      'Foto',
      where: 'pescata_id = ?',
      whereArgs: [id],
      orderBy: 'id ASC',
    );
    final foto = righeFoto.map(_fotoFromMap).toList();

    // 3. Catture memorabili (riusa l'helper condiviso)
    final catture = await _queryCattureConDettagli(db, pescataId: id);

    // 4. Riepiloghi specie con dettagli per caratteristica
    final righeRiepiloghi = await db.query(
      'RiepilogoSpecie',
      where: 'pescata_id = ?',
      whereArgs: [id],
      orderBy: 'specie_nome ASC',
    );
    final riepiloghi = <RiepilogoSpecie>[];
    for (final rr in righeRiepiloghi) {
      final riepilogoId = rr['id'] as int;
      final righeDettagli = await db.query(
        'DettaglioRiepilogo',
        where: 'riepilogo_specie_id = ?',
        whereArgs: [riepilogoId],
      );
      riepiloghi.add(
        RiepilogoSpecie(
          id: riepilogoId,
          pescataId: rr['pescata_id'] as int,
          specieNome: rr['specie_nome'] as String,
          quantita: rr['quantita'] as int,
          dettagli: righeDettagli.map(_dettaglioFromMap).toList(),
        ),
      );
    }

    return _pescataFromMap(
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
      final id = await db.insert('Esca', _escaToMap(esca));
      return esca.copyWith(id: id);
    }
    await db.update(
      'Esca',
      _escaToMap(esca),
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
      final id = await db.insert('Pianificazione', _pianificazioneToMap(p));
      return p.copyWith(id: id);
    }
    await db.update(
      'Pianificazione',
      _pianificazioneToMap(p),
      where: 'id = ?',
      whereArgs: [p.id],
    );
    return p;
  }

  Future<void> eliminaPianificazione(int id) async {
    final db = await _dbHelper.database;
    await db.delete('Pianificazione', where: 'id = ?', whereArgs: [id]);
  }

  /// Inserisce o aggiorna una Pescata insieme alle esche usate e alle sue foto.
  Future<Pescata> salvaPescata(Pescata pescata) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      late final int pescataId;

      if (pescata.id == null) {
        pescataId = await txn.insert('Pescata', _pescataToMap(pescata));
      } else {
        pescataId = pescata.id!;
        await txn.update(
          'Pescata',
          _pescataToMap(pescata),
          where: 'id = ?',
          whereArgs: [pescataId],
        );
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
      }

      for (final esca in pescata.esche) {
        if (esca.id != null) {
          await txn.insert('Pescata_Esca', {
            'pescata_id': pescataId,
            'esca_id': esca.id,
          });
        }
      }

      final fotoSalvate = <Foto>[];
      for (final f in pescata.foto) {
        final fotoAllineata = Foto(
          percorso: f.percorso,
          percorsoThumbnail: f.percorsoThumbnail,
          pescataId: pescataId,
          catturaMemorabileId: null,
        );
        final fotoId = await txn.insert('Foto', _fotoToMap(fotoAllineata));
        fotoSalvate.add(fotoAllineata.copyWith(id: fotoId));
      }

      return pescata.copyWith(id: pescataId, foto: fotoSalvate);
    });
  }

  Future<void> eliminaPescata(int id) async {
    final db = await _dbHelper.database;
    await db.delete('Pescata', where: 'id = ?', whereArgs: [id]);
  }

  /// Inserisce o aggiorna una CatturaMemorabile con caratteristiche e foto.
  Future<CatturaMemorabile> salvaCatturaMemorabile(
    CatturaMemorabile cattura,
  ) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      late final int catturaId;

      if (cattura.id == null) {
        catturaId = await txn.insert(
          'CatturaMemorabile',
          _catturaToMap(cattura),
        );
      } else {
        catturaId = cattura.id!;
        await txn.update(
          'CatturaMemorabile',
          _catturaToMap(cattura),
          where: 'id = ?',
          whereArgs: [catturaId],
        );
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
      }

      for (final caratt in cattura.caratteristiche) {
        if (caratt.id != null) {
          await txn.insert('Cattura_Caratteristica', {
            'cattura_memorabile_id': catturaId,
            'caratteristica_id': caratt.id,
            'specie_nome': cattura.specieNome,
          });
        }
      }

      final fotoSalvate = <Foto>[];
      for (final f in cattura.foto) {
        final fotoAllineata = Foto(
          percorso: f.percorso,
          percorsoThumbnail: f.percorsoThumbnail,
          pescataId: null,
          catturaMemorabileId: catturaId,
        );
        final fotoId = await txn.insert('Foto', _fotoToMap(fotoAllineata));
        fotoSalvate.add(fotoAllineata.copyWith(id: fotoId));
      }

      return cattura.copyWith(id: catturaId, foto: fotoSalvate);
    });
  }

  Future<void> eliminaCatturaMemorabile(int id) async {
    final db = await _dbHelper.database;
    await db.delete('CatturaMemorabile', where: 'id = ?', whereArgs: [id]);
  }

  // ===========================================================================
  // HELPER PRIVATI E MAPPING
  // ===========================================================================

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
      condizioni.add('pescata_id = ?');
      argomenti.add(pescataId);
    }
    if (specieNome != null) {
      condizioni.add('specie_nome = ?');
      argomenti.add(specieNome);
    }
    if (escaId != null) {
      condizioni.add('esca_id = ?');
      argomenti.add(escaId);
    }

    final righeCatture = await db.query(
      'CatturaMemorabile',
      where: condizioni.isEmpty ? null : condizioni.join(' AND '),
      whereArgs: argomenti.isEmpty ? null : argomenti,
      orderBy: 'id DESC',
      limit: limit,
    );

    final catture = <CatturaMemorabile>[];
    for (final rc in righeCatture) {
      final catturaId = rc['id'] as int;

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
        _catturaFromMap(
          rc,
          caratteristiche: righeCaratt.map(_caratteristicaFromMap).toList(),
          foto: righeFoto.map(_fotoFromMap).toList(),
        ),
      );
    }
    return catture;
  }

  String _formatData(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final g = d.day.toString().padLeft(2, '0');
    return '$y-$m-$g';
  }

  Esca _escaFromMap(Map<String, Object?> map) => Esca(
        id: map['id'] as int?,
        nome: map['nome'] as String,
        descrizione: map['descrizione'] as String?,
      );

  Map<String, Object?> _escaToMap(Esca e) => {
        if (e.id != null) 'id': e.id,
        'nome': e.nome,
        'descrizione': e.descrizione,
      };

  Foto _fotoFromMap(Map<String, Object?> map) => Foto(
        id: map['id'] as int?,
        percorso: map['percorso'] as String,
        percorsoThumbnail: map['percorsoThumbnail'] as String,
        pescataId: map['pescata_id'] as int?,
        catturaMemorabileId: map['cattura_memorabile_id'] as int?,
      );

  Map<String, Object?> _fotoToMap(Foto f) => {
        if (f.id != null) 'id': f.id,
        'percorso': f.percorso,
        'percorsoThumbnail': f.percorsoThumbnail,
        'pescata_id': f.pescataId,
        'cattura_memorabile_id': f.catturaMemorabileId,
      };

  Pianificazione _pianificazioneFromMap(Map<String, Object?> map) =>
      Pianificazione(
        id: map['id'] as int?,
        data: DateTime.parse(map['data'] as String),
        fasciaOraria:
            FasciaOraria.values.byName(map['fasciaOraria'] as String),
        note: map['note'] as String?,
        spotNome: map['spot_nome'] as String?,
      );

  Map<String, Object?> _pianificazioneToMap(Pianificazione p) => {
        if (p.id != null) 'id': p.id,
        'data': _formatData(p.data),
        'fasciaOraria': p.fasciaOraria.name,
        'note': p.note,
        'spot_nome': p.spotNome,
      };

  Caratteristica _caratteristicaFromMap(Map<String, Object?> map) =>
      Caratteristica(
        id: map['id'] as int?,
        specieNome: map['specie_nome'] as String,
        nome: map['nome'] as String,
        descrizione: map['descrizione'] as String?,
      );

  RiepilogoCaratteristica _dettaglioFromMap(Map<String, Object?> map) =>
      RiepilogoCaratteristica(
        riepilogoSpecieId: map['riepilogo_specie_id'] as int,
        caratteristicaId: map['caratteristica_id'] as int,
        specieNome: map['specie_nome'] as String,
        quantita: map['quantita'] as int,
      );

  CatturaMemorabile _catturaFromMap(
    Map<String, Object?> map, {
    List<Caratteristica> caratteristiche = const [],
    List<Foto> foto = const [],
  }) =>
      CatturaMemorabile(
        id: map['id'] as int?,
        descrizione: map['descrizione'] as String?,
        pescataId: map['pescata_id'] as int,
        specieNome: map['specie_nome'] as String,
        escaId: map['esca_id'] as int?,
        caratteristiche: caratteristiche,
        foto: foto,
      );

  Map<String, Object?> _catturaToMap(CatturaMemorabile c) => {
        if (c.id != null) 'id': c.id,
        'descrizione': c.descrizione,
        'pescata_id': c.pescataId,
        'specie_nome': c.specieNome,
        'esca_id': c.escaId,
      };

  Pescata _pescataFromMap(
    Map<String, Object?> map, {
    List<Esca> esche = const [],
    List<Foto> foto = const [],
    List<CatturaMemorabile> cattureMemorabili = const [],
    List<RiepilogoSpecie> riepiloghiSpecie = const [],
  }) {
    final trasparenzaRaw = map['trasparenza'] as String?;
    final fondoRaw = map['fondo'] as String?;
    final livelloRaw = map['livello'] as String?;

    return Pescata(
      id: map['id'] as int?,
      data: DateTime.parse(map['data'] as String),
      fasciaOraria:
          FasciaOraria.values.byName(map['fasciaOraria'] as String),
      meteo: Meteo.values.byName(map['meteo'] as String),
      trasparenza: trasparenzaRaw != null
          ? Trasparenza.values.byName(trasparenzaRaw)
          : null,
      fondo: fondoRaw != null ? Fondo.values.byName(fondoRaw) : null,
      livello: livelloRaw != null ? Livello.values.byName(livelloRaw) : null,
      tempAcqua: (map['temp_acqua'] as num?)?.toDouble(),
      tempAria: (map['temp_aria'] as num?)?.toDouble(),
      note: map['note'] as String?,
      spotNome: map['spot_nome'] as String?,
      esche: esche,
      foto: foto,
      cattureMemorabili: cattureMemorabili,
      riepiloghiSpecie: riepiloghiSpecie,
    );
  }

  Map<String, Object?> _pescataToMap(Pescata p) => {
        if (p.id != null) 'id': p.id,
        'data': _formatData(p.data),
        'fasciaOraria': p.fasciaOraria.name,
        'meteo': p.meteo.name,
        'trasparenza': p.trasparenza?.name,
        'fondo': p.fondo?.name,
        'livello': p.livello?.name,
        'temp_acqua': p.tempAcqua,
        'temp_aria': p.tempAria,
        'note': p.note,
        'spot_nome': p.spotNome,
      };
}