import 'package:sqflite/sqflite.dart';

import '../data/archivio_foto.dart';
import '../data/database_helper.dart';
import '../data/db_mappers.dart';
import '../models/catalogo/caratteristica.dart';
import '../models/catalogo/condizione.dart';
import '../models/catalogo/esca.dart';
import '../models/catalogo/specie.dart';
import '../models/catalogo/valore_condizione.dart';
import '../models/foto.dart';
import 'eccezioni.dart';

/// Anagrafiche personali del pescatore: specie, caratteristiche, esche e
/// condizioni registrabili nelle pescate (con i loro valori e i collegamenti
/// agli ambienti).
///
/// È l'unico componente che scrive le tabelle `Specie`, `Caratteristica`,
/// `Esca` (con le foto delle esche), `Condizione`, `ValoreCondizione` e
/// `Ambiente_Condizione`. Quando una pescata, una cattura o un
/// obiettivo vogliono creare al volo un'esca o una caratteristica, gli altri
/// repository chiamano i metodi `assicura...` passando la propria
/// transazione, così la creazione resta atomica con il resto del salvataggio.
/// Se il nome è già usato da un elemento con dati diversi, la creazione al
/// volo lancia [NomeDuplicatoException] invece di perdere quei dati.
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

  /// Caratteristica di [specieNome] con il nome indicato, senza distinzione
  /// di maiuscole e spazi; `null` se non esiste. Utile all'interfaccia per
  /// avvisare l'utente prima di creare un doppione.
  Future<Caratteristica?> getCaratteristicaPerNome({
    required String specieNome,
    required String nome,
  }) async {
    final db = await _dbHelper.database;
    final righe = await db.query(
      'Caratteristica',
      where: 'specie_nome = ? AND LOWER(TRIM(nome)) = LOWER(TRIM(?))',
      whereArgs: [specieNome, nome],
      limit: 1,
    );
    return righe.isEmpty ? null : DbMappers.caratteristicaFromMap(righe.first);
  }

  /// Inserisce o aggiorna una caratteristica. Il cambio di specie è bloccato
  /// se la caratteristica è già usata in catture, riepiloghi o obiettivi.
  Future<Caratteristica> salvaCaratteristica(Caratteristica c) async {
    final db = await _dbHelper.database;
    if (c.isNuovo) {
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

  /// Esca con il nome indicato (con le sue foto), senza distinzione di
  /// maiuscole e spazi; `null` se non esiste. Utile all'interfaccia per
  /// avvisare l'utente prima di creare un doppione.
  Future<Esca?> getEscaPerNome(String nome) async {
    final db = await _dbHelper.database;
    final righe = await db.query(
      'Esca',
      where: 'LOWER(TRIM(nome)) = LOWER(TRIM(?))',
      whereArgs: [nome],
      limit: 1,
    );
    if (righe.isEmpty) return null;
    final id = righe.first['id'] as int;
    final fotoMap = await caricaFotoPerEsche(db, [id]);
    return DbMappers.escaFromMap(righe.first, foto: fotoMap[id] ?? const []);
  }

  /// Inserisce o aggiorna atomicamente un'Esca insieme alle sue foto,
  /// rimuovendo dal disco eventuali file immagine scollegati.
  Future<Esca> salvaEsca(Esca esca) async {
    final db = await _dbHelper.database;
    final percorsiFotoDaRimuovere = <String>{};

    final risultato = await db.transaction((txn) async {
      final int escaId;
      if (esca.isNuovo) {
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
  // CONDIZIONI
  // ===========================================================================

  /// Elenco condizioni con i loro valori, nell'ordine del form.
  ///
  /// Con [ambienteNome] restituisce solo le condizioni collegate a
  /// quell'ambiente. Con [soloAttive] esclude condizioni e valori disattivati.
  Future<List<Condizione>> getCondizioni({
    String? ambienteNome,
    bool soloAttive = false,
  }) async {
    final db = await _dbHelper.database;

    final condizioni = <String>[];
    final argomenti = <Object?>[];
    if (ambienteNome != null) {
      condizioni.add(
        'id IN (SELECT condizione_id FROM Ambiente_Condizione WHERE ambiente_nome = ?)',
      );
      argomenti.add(ambienteNome);
    }
    if (soloAttive) condizioni.add('attiva = 1');

    final righe = await db.query(
      'Condizione',
      where: condizioni.isEmpty ? null : condizioni.join(' AND '),
      whereArgs: argomenti.isEmpty ? null : argomenti,
      orderBy: 'ordine ASC, nome ASC',
    );
    return _completaConValori(
      db,
      righe,
      includiValore: (v) => !soloAttive || v.attivo,
    );
  }

  /// Condizioni da mostrare nel form di una pescata: quelle attive collegate
  /// all'ambiente dello spot, più quelle che la pescata [pescataId] ha già
  /// compilato (anche se non più previste o disattivate), così nessun dato
  /// salvato sparisce dal form.
  ///
  /// Per ogni condizione restituisce i valori attivi più l'eventuale valore
  /// già scelto nella pescata.
  Future<List<Condizione>> getCondizioniPerForm({
    String? ambienteNome,
    int? pescataId,
  }) async {
    final db = await _dbHelper.database;

    final valoriUsati = <int>{};
    if (pescataId != null) {
      final righe = await db.query(
        'Pescata_Condizione',
        columns: ['valore_id'],
        where: 'pescata_id = ?',
        whereArgs: [pescataId],
      );
      valoriUsati.addAll(righe.map((r) => r['valore_id'] as int));
    }

    final righe = await db.rawQuery('''
      SELECT * FROM Condizione
      WHERE (attiva = 1 AND id IN (
               SELECT condizione_id FROM Ambiente_Condizione WHERE ambiente_nome = ?))
         OR id IN (SELECT condizione_id FROM Pescata_Condizione WHERE pescata_id = ?)
      ORDER BY ordine ASC, nome ASC
    ''', [ambienteNome, pescataId]);

    return _completaConValori(
      db,
      righe,
      includiValore: (v) => v.attivo || valoriUsati.contains(v.id),
    );
  }

  /// Inserisce o aggiorna una condizione insieme ai suoi valori.
  ///
  /// L'ordine dei valori nella lista diventa l'ordine della scala. I valori
  /// nuovi vengono inseriti, quelli esistenti aggiornati (nome, ordine,
  /// attivazione). Un valore esistente tolto dalla lista viene eliminato solo
  /// se nessuna pescata lo usa; altrimenti lancia [StateError]: un valore
  /// usato si disattiva (`attivo: false`) invece di eliminarlo.
  Future<Condizione> salvaCondizione(Condizione condizione) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      final int condizioneId;
      if (condizione.isNuovo) {
        condizioneId = await txn.insert(
          'Condizione',
          DbMappers.condizioneToMap(condizione),
        );
      } else {
        condizioneId = condizione.id!;
        await txn.update(
          'Condizione',
          DbMappers.condizioneToMap(condizione),
          where: 'id = ?',
          whereArgs: [condizioneId],
        );
      }

      // Valori esistenti tolti dalla lista: eliminabili solo se mai usati
      final idsMantenuti =
          condizione.valori.where((v) => !v.isNuovo).map((v) => v.id!).toSet();
      final esistenti = await txn.query(
        'ValoreCondizione',
        columns: ['id', 'nome'],
        where: 'condizione_id = ?',
        whereArgs: [condizioneId],
      );
      final daEliminare = esistenti
          .where((r) => !idsMantenuti.contains(r['id'] as int))
          .toList();
      if (daEliminare.isNotEmpty) {
        final ids = daEliminare.map((r) => r['id'] as int).toList();
        final segnaposto = List.filled(ids.length, '?').join(', ');
        final usati = await txn.rawQuery('''
          SELECT DISTINCT v.nome FROM ValoreCondizione v
          INNER JOIN Pescata_Condizione pc ON pc.valore_id = v.id
          WHERE v.id IN ($segnaposto)
        ''', ids);
        if (usati.isNotEmpty) {
          final nomi = usati.map((r) => r['nome']).join(', ');
          throw StateError(
            'I valori $nomi sono usati in alcune pescate: disattivali invece di eliminarli',
          );
        }
        await txn.delete(
          'ValoreCondizione',
          where: 'id IN ($segnaposto)',
          whereArgs: ids,
        );
      }

      // Inserimento o aggiornamento dei valori, con l'ordine della lista
      for (var i = 0; i < condizione.valori.length; i++) {
        final valore = condizione.valori[i];
        if (!valore.isNuovo &&
            valore.condizioneId != null &&
            valore.condizioneId != condizioneId) {
          throw ArgumentError(
            'Il valore "${valore.nome}" appartiene a un\'altra condizione',
          );
        }
        final allineato = valore.copyWith(condizioneId: condizioneId, ordine: i);
        if (allineato.isNuovo) {
          await txn.insert(
            'ValoreCondizione',
            DbMappers.valoreCondizioneToMap(allineato),
          );
        } else {
          await txn.update(
            'ValoreCondizione',
            DbMappers.valoreCondizioneToMap(allineato),
            where: 'id = ? AND condizione_id = ?',
            whereArgs: [allineato.id, condizioneId],
          );
        }
      }

      final righe = await txn.query(
        'Condizione',
        where: 'id = ?',
        whereArgs: [condizioneId],
      );
      return (await _completaConValori(txn, righe)).single;
    });
  }

  /// Elimina una condizione con i suoi valori e collegamenti. Bloccata
  /// (ON DELETE RESTRICT) se almeno un suo valore è usato in una pescata:
  /// in quel caso la condizione va disattivata.
  Future<void> eliminaCondizione(int id) async {
    final db = await _dbHelper.database;
    await db.delete('Condizione', where: 'id = ?', whereArgs: [id]);
  }

  /// Sostituisce l'insieme delle condizioni collegate all'ambiente [ambienteNome].
  Future<void> impostaCondizioniAmbiente(
    String ambienteNome,
    List<int> condizioneIds,
  ) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        'Ambiente_Condizione',
        where: 'ambiente_nome = ?',
        whereArgs: [ambienteNome],
      );
      for (final id in condizioneIds.toSet()) {
        await txn.insert('Ambiente_Condizione', {
          'ambiente_nome': ambienteNome,
          'condizione_id': id,
        });
      }
    });
  }

  /// Collega ad [aAmbiente] tutte le condizioni di [daAmbiente], mantenendo
  /// quelle che [aAmbiente] ha già (es. un nuovo ambiente "Laterale" che parte
  /// con le condizioni del "Torrente").
  Future<void> copiaCondizioniAmbiente({
    required String daAmbiente,
    required String aAmbiente,
  }) async {
    final db = await _dbHelper.database;
    await db.rawInsert('''
      INSERT OR IGNORE INTO Ambiente_Condizione (ambiente_nome, condizione_id)
      SELECT ?, condizione_id FROM Ambiente_Condizione WHERE ambiente_nome = ?
    ''', [aAmbiente, daAmbiente]);
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

  /// Restituisce il nome della specie [nome] come è salvato, creandola se
  /// non esiste, dentro la transazione [txn]: è il caso di una specie scritta
  /// al momento nel modulo di una pescata, che nasce solo se la pescata viene
  /// salvata. Se esiste già con maiuscole o spazi diversi viene riusata
  /// quella, senza creare un doppione.
  Future<String> assicuraSpecieSalvata(DatabaseExecutor txn, String nome) async {
    final esistente = await txn.query(
      'Specie',
      columns: ['nome'],
      where: 'LOWER(TRIM(nome)) = LOWER(TRIM(?))',
      whereArgs: [nome],
      limit: 1,
    );
    if (esistente.isNotEmpty) return esistente.first['nome'] as String;
    final pulito = nome.trim();
    await txn.insert('Specie', {'nome': pulito});
    return pulito;
  }

  /// Restituisce l'esca con il suo id, creandola se è nuova, dentro la
  /// transazione [txn].
  ///
  /// Se esiste già un'esca con lo stesso nome (senza distinzione di maiuscole
  /// e spazi) viene riusata quella, ma solo se così non si perde nulla: la
  /// nuova non deve avere una descrizione diversa né foto che l'esistente non
  /// ha. Altrimenti lancia [NomeDuplicatoException] e la transazione viene
  /// annullata.
  Future<Esca> assicuraEscaSalvata(DatabaseExecutor txn, Esca esca) async {
    if (!esca.isNuovo) return esca;

    final esistente = await txn.query(
      'Esca',
      where: 'LOWER(TRIM(nome)) = LOWER(TRIM(?))',
      whereArgs: [esca.nome],
      limit: 1,
    );
    if (esistente.isNotEmpty) {
      final idEsistente = esistente.first['id'] as int;
      final fotoMap = await caricaFotoPerEsche(txn, [idEsistente]);
      final escaEsistente = DbMappers.escaFromMap(
        esistente.first,
        foto: fotoMap[idEsistente] ?? const [],
      );

      final percorsiEsistenti =
          escaEsistente.foto.map((f) => f.percorso).toSet();
      final descrizioneDiversa = esca.descrizione != null &&
          esca.descrizione != escaEsistente.descrizione;
      final fotoNuove =
          esca.foto.any((f) => !percorsiEsistenti.contains(f.percorso));

      if (descrizioneDiversa || fotoNuove) {
        throw NomeDuplicatoException(
          tipo: 'Esca',
          nome: esca.nome,
          idEsistente: idEsistente,
        );
      }
      return escaEsistente;
    }

    final id = await txn.insert('Esca', DbMappers.escaToMap(esca));
    final fotoSalvate = await _inserisciFotoEsca(txn, id, esca.foto);
    return esca.copyWith(id: id, foto: fotoSalvate);
  }

  /// Restituisce la caratteristica con il suo id, creandola se è nuova,
  /// dentro la transazione [txn]. Una caratteristica nuova deve appartenere
  /// a [specieAttesa].
  ///
  /// Se per la stessa specie esiste già una caratteristica con lo stesso nome
  /// viene riusata quella, a meno che la nuova abbia una descrizione diversa:
  /// in quel caso lancia [NomeDuplicatoException].
  Future<Caratteristica> assicuraCaratteristicaSalvata(
    DatabaseExecutor txn,
    Caratteristica c, {
    required String specieAttesa,
  }) async {
    if (!c.isNuovo) return c;
    if (c.specieNome != specieAttesa) {
      throw ArgumentError(
        'La nuova caratteristica "${c.nome}" appartiene a ${c.specieNome}, non a $specieAttesa',
      );
    }

    final esistente = await txn.query(
      'Caratteristica',
      where: 'specie_nome = ? AND LOWER(TRIM(nome)) = LOWER(TRIM(?))',
      whereArgs: [c.specieNome, c.nome],
      limit: 1,
    );
    if (esistente.isNotEmpty) {
      final carattEsistente = DbMappers.caratteristicaFromMap(esistente.first);
      if (c.descrizione != null &&
          c.descrizione != carattEsistente.descrizione) {
        throw NomeDuplicatoException(
          tipo: 'Caratteristica',
          nome: c.nome,
          idEsistente: carattEsistente.id!,
        );
      }
      return carattEsistente;
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

  /// Aggiunge a ogni riga di `Condizione` i suoi valori (in ordine di scala),
  /// tenendo solo quelli per cui [includiValore] restituisce `true`.
  Future<List<Condizione>> _completaConValori(
    DatabaseExecutor db,
    List<Map<String, Object?>> righeCondizioni, {
    bool Function(ValoreCondizione)? includiValore,
  }) async {
    if (righeCondizioni.isEmpty) return [];

    final ids = righeCondizioni.map((r) => r['id'] as int).toList();
    final segnaposto = List.filled(ids.length, '?').join(', ');
    final righeValori = await db.query(
      'ValoreCondizione',
      where: 'condizione_id IN ($segnaposto)',
      whereArgs: ids,
      orderBy: 'ordine ASC, id ASC',
    );

    final valoriPerCondizione = <int, List<ValoreCondizione>>{};
    for (final r in righeValori) {
      final valore = DbMappers.valoreCondizioneFromMap(r);
      if (includiValore != null && !includiValore(valore)) continue;
      valoriPerCondizione.putIfAbsent(valore.condizioneId!, () => []).add(valore);
    }

    return righeCondizioni
        .map((r) => DbMappers.condizioneFromMap(
              r,
              valori: valoriPerCondizione[r['id'] as int] ?? const [],
            ))
        .toList();
  }

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
