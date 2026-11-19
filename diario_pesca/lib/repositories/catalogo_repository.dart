import 'package:sqflite/sqflite.dart';

import '../data/archivio_foto.dart';
import '../data/database_helper.dart';
import '../data/db_mappers.dart';
import '../models/catalogo/caratteristica.dart';
import '../models/catalogo/esca.dart';
import '../models/catalogo/specie.dart';
import '../models/foto.dart';

/// Anagrafiche personali del pescatore: specie, caratteristiche ed esche.
///
/// È l'unico componente che scrive le tabelle `Specie`, `Caratteristica` ed
/// `Esca` (con le foto delle esche). Quando una pescata, una cattura o un
/// obiettivo vogliono creare al volo un'esca o una caratteristica, gli altri
/// repository chiamano i metodi `assicura...` passando la propria
/// transazione, così la creazione resta atomica con il resto del salvataggio.
class CatalogoRepository {
  final DatabaseHelper _dbHelper;
  final ArchivioFoto _archivioFoto;

  CatalogoRepository({
    DatabaseHelper? dbHelper,
    ArchivioFoto archivioFoto = const ArchivioFoto(),
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _archivioFoto = archivioFoto;

  // ===========================================================================
  // SPECIE
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

  Future<void> inserisciSpecie(Specie specie) async {
    final db = await _dbHelper.database;
    await db.insert('Specie', DbMappers.specieToMap(specie));
  }

  /// Rinomina o aggiorna una specie; il nuovo nome si propaga a tutte le
  /// tabelle collegate (ON UPDATE CASCADE).
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

  /// Bloccata (ON DELETE RESTRICT) se la specie è usata in riepiloghi o
  /// catture memorabili; altrimenti elimina a cascata caratteristiche e obiettivi.
  Future<void> eliminaSpecie(String nome) async {
    final db = await _dbHelper.database;
    await db.delete('Specie', where: 'nome = ?', whereArgs: [nome]);
  }

  // ===========================================================================
  // CARATTERISTICHE
  // ===========================================================================

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

  /// Inserisce o aggiorna una caratteristica. Il cambio di specie è bloccato
  /// se la caratteristica è già usata in catture, riepiloghi o obiettivi.
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

  // ===========================================================================
  // ESCHE
  // ===========================================================================

  /// Elenco esche in ordine alfabetico con relative foto e filtro opzionale sul nome.
  Future<List<Esca>> getEsche({String? filtroNome}) async {
    final db = await _dbHelper.database;
    final hasFiltro = filtroNome != null && filtroNome.trim().isNotEmpty;

    final righe = await db.query(
      'Esca',
      where: hasFiltro ? 'LOWER(nome) LIKE LOWER(?)' : null,
      whereArgs: hasFiltro ? ['%${filtroNome.trim()}%'] : null,
      orderBy: 'nome ASC',
    );
    if (righe.isEmpty) return [];

    final escaIds = righe.map((r) => r['id'] as int).toList();
    final fotoPerEsca = await caricaFotoPerEsche(db, escaIds);

    return righe.map((r) {
      final id = r['id'] as int;
      return DbMappers.escaFromMap(
        r,
        foto: fotoPerEsca[id] ?? const [],
      );
    }).toList();
  }

  /// Inserisce o aggiorna atomicamente un'Esca insieme alle sue foto,
  /// rimuovendo dal disco eventuali file immagine scollegati.
  Future<Esca> salvaEsca(Esca esca) async {
    final db = await _dbHelper.database;
    final percorsiFotoDaRimuovere = <String>{};

    final risultato = await db.transaction((txn) async {
      final int escaId;
      if (esca.id == null) {
        escaId = await txn.insert('Esca', DbMappers.escaToMap(esca));
      } else {
        escaId = esca.id!;

        final vecchieFoto = await txn.query(
          'Foto',
          columns: ['percorso', 'percorsoThumbnail'],
          where: 'esca_id = ?',
          whereArgs: [escaId],
        );
        for (final f in vecchieFoto) {
          percorsiFotoDaRimuovere.add(f['percorso'] as String);
          percorsiFotoDaRimuovere.add(f['percorsoThumbnail'] as String);
        }

        await txn.delete(
          'Foto',
          where: 'esca_id = ?',
          whereArgs: [escaId],
        );

        await txn.update(
          'Esca',
          DbMappers.escaToMap(esca),
          where: 'id = ?',
          whereArgs: [escaId],
        );
      }

      final fotoSalvate = await _inserisciFotoEsca(txn, escaId, esca.foto);
      for (final f in fotoSalvate) {
        percorsiFotoDaRimuovere.remove(f.percorso);
        percorsiFotoDaRimuovere.remove(f.percorsoThumbnail);
      }

      return esca.copyWith(id: escaId, foto: fotoSalvate);
    });

    await _archivioFoto.eliminaFile(percorsiFotoDaRimuovere);
    return risultato;
  }

  /// Elimina l'esca e le sue foto (anche dal disco). Nelle pescate sparisce
  /// il legame, nelle catture memorabili il riferimento diventa NULL.
  Future<void> eliminaEsca(int id) async {
    final db = await _dbHelper.database;
    final percorsiFotoDaRimuovere = <String>[];

    await db.transaction((txn) async {
      final fotoRows = await txn.query(
        'Foto',
        columns: ['percorso', 'percorsoThumbnail'],
        where: 'esca_id = ?',
        whereArgs: [id],
      );
      for (final f in fotoRows) {
        percorsiFotoDaRimuovere.add(f['percorso'] as String);
        percorsiFotoDaRimuovere.add(f['percorsoThumbnail'] as String);
      }

      await txn.delete('Esca', where: 'id = ?', whereArgs: [id]);
    });

    await _archivioFoto.eliminaFile(percorsiFotoDaRimuovere);
  }

  // ===========================================================================
  // OPERAZIONI PER GLI ALTRI REPOSITORY (dentro una transazione esistente)
  // ===========================================================================

  /// Foto di più esche, raggruppate per id esca.
  Future<Map<int, List<Foto>>> caricaFotoPerEsche(
    DatabaseExecutor db,
    List<int> escaIds,
  ) async {
    if (escaIds.isEmpty) return {};

    final placeholders = List.filled(escaIds.length, '?').join(', ');
    final rows = await db.query(
      'Foto',
      where: 'esca_id IN ($placeholders)',
      whereArgs: escaIds,
      orderBy: 'id ASC',
    );

    final mappa = <int, List<Foto>>{};
    for (final r in rows) {
      final foto = DbMappers.fotoFromMap(r);
      mappa.putIfAbsent(foto.escaId!, () => []).add(foto);
    }
    return mappa;
  }

  /// Restituisce l'esca con il suo id. Se è nuova (`id == null`) cerca
  /// un'esca con lo stesso nome (senza distinzione di maiuscole) e, se non
  /// esiste, la crea insieme alle sue foto nella transazione [txn].
  Future<Esca> assicuraEscaSalvata(DatabaseExecutor txn, Esca esca) async {
    if (esca.id != null) return esca;

    final esistente = await txn.query(
      'Esca',
      columns: ['id'],
      where: 'LOWER(TRIM(nome)) = LOWER(TRIM(?))',
      whereArgs: [esca.nome],
      limit: 1,
    );
    if (esistente.isNotEmpty) {
      final idEsistente = esistente.first['id'] as int;
      final fotoMap = await caricaFotoPerEsche(txn, [idEsistente]);
      return esca.copyWith(
        id: idEsistente,
        foto: fotoMap[idEsistente] ?? const [],
      );
    }

    final id = await txn.insert('Esca', DbMappers.escaToMap(esca));
    final fotoSalvate = await _inserisciFotoEsca(txn, id, esca.foto);
    return esca.copyWith(id: id, foto: fotoSalvate);
  }

  /// Restituisce la caratteristica con il suo id. Se è nuova (`id == null`)
  /// verifica che appartenga a [specieAttesa], cerca una caratteristica con
  /// lo stesso nome per quella specie e, se non esiste, la crea in [txn].
  Future<Caratteristica> assicuraCaratteristicaSalvata(
    DatabaseExecutor txn,
    Caratteristica c, {
    required String specieAttesa,
  }) async {
    if (c.id != null) return c;
    if (c.specieNome != specieAttesa) {
      throw ArgumentError(
        'La nuova caratteristica "${c.nome}" appartiene a ${c.specieNome}, non a $specieAttesa',
      );
    }

    final esistente = await txn.query(
      'Caratteristica',
      columns: ['id'],
      where: 'specie_nome = ? AND LOWER(TRIM(nome)) = LOWER(TRIM(?))',
      whereArgs: [c.specieNome, c.nome],
      limit: 1,
    );
    if (esistente.isNotEmpty) {
      return c.copyWith(id: esistente.first['id'] as int);
    }

    final id = await txn.insert(
      'Caratteristica',
      DbMappers.caratteristicaToMap(c),
    );
    return c.copyWith(id: id);
  }

  // ===========================================================================
  // HELPER PRIVATI
  // ===========================================================================

  Future<List<Foto>> _inserisciFotoEsca(
    DatabaseExecutor txn,
    int escaId,
    List<Foto> foto,
  ) async {
    final fotoSalvate = <Foto>[];
    for (final f in foto) {
      final fotoAllineata = Foto(
        percorso: f.percorso,
        percorsoThumbnail: f.percorsoThumbnail,
        escaId: escaId,
      );
      final fotoId =
          await txn.insert('Foto', DbMappers.fotoToMap(fotoAllineata));
      fotoSalvate.add(fotoAllineata.copyWith(id: fotoId));
    }
    return fotoSalvate;
  }
}
