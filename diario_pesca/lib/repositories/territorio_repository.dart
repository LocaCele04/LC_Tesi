import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../data/database_helper.dart';
import '../data/db_mappers.dart';
import '../data/query_condivise.dart';
import '../models/catalogo/condizione.dart';
import '../models/enums.dart';
import '../models/territorio/ambiente.dart';
import '../models/territorio/categoria.dart';
import '../models/territorio/coordinata.dart';
import '../models/territorio/spot.dart';

class TerritorioRepository {
  final DatabaseHelper _dbHelper;

  TerritorioRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  // ===========================================================================
  // LETTURA
  // ===========================================================================

  Future<List<Categoria>> getCategorie() async {
    final db = await _dbHelper.database;
    final righe = await db.query('Categoria', orderBy: 'nome ASC');
    return righe.map(DbMappers.categoriaFromMap).toList();
  }

  /// Elenco degli ambienti (di base e aggiunti dall'utente), in ordine
  /// alfabetico senza distinzione tra maiuscole e minuscole.
  Future<List<Ambiente>> getAmbienti() async {
    final db = await _dbHelper.database;
    final righe = await db.query('Ambiente', orderBy: 'nome ASC');
    return righe.map(DbMappers.ambienteFromMap).toList();
  }

  /// Elenco spot con filtri opzionali combinabili (senza caricare le coordinate).
  Future<List<Spot>> getSpots({
    String? categoriaNome,
    String? ambiente,
    double? votoMinimo,
    double? lunghezzaMassima,
    Difficolta? difficolta,
    bool? battuto,
    Accessibilita? accessibilita,
  }) async {
    final db = await _dbHelper.database;

    final condizioni = <String>[];
    final argomenti = <Object?>[];

    if (categoriaNome != null) {
      condizioni.add('categoria_nome = ?');
      argomenti.add(categoriaNome);
    }
    if (ambiente != null) {
      condizioni.add('LOWER(ambiente) = LOWER(?)');
      argomenti.add(ambiente.trim());
    }
    if (votoMinimo != null) {
      condizioni.add('voto >= ?');
      argomenti.add(votoMinimo);
    }
    if (lunghezzaMassima != null) {
      condizioni.add('lunghezzaMetri <= ?');
      argomenti.add(lunghezzaMassima);
    }
    if (difficolta != null) {
      condizioni.add('difficolta = ?');
      argomenti.add(difficolta.name);
    }
    if (battuto != null) {
      condizioni.add('battuto = ?');
      argomenti.add(battuto ? 1 : 0);
    }
    if (accessibilita != null) {
      condizioni.add('accessibilita = ?');
      argomenti.add(accessibilita.name);
    }

    final righe = await db.query(
      'Spot',
      where: condizioni.isEmpty ? null : condizioni.join(' AND '),
      whereArgs: argomenti.isEmpty ? null : argomenti,
      orderBy: 'nome ASC',
    );
    return righe.map((r) => DbMappers.spotFromMap(r)).toList();
  }

  /// Dettaglio singolo spot completo delle sue coordinate ordinate.
  Future<Spot?> getSpotConCoordinate(String nome) async {
    final db = await _dbHelper.database;
    final righeSpot = await db.query(
      'Spot',
      where: 'nome = ?',
      whereArgs: [nome],
      limit: 1,
    );
    if (righeSpot.isEmpty) return null;

    final righeCoord = await db.query(
      'Coordinata',
      where: 'spot_nome = ?',
      whereArgs: [nome],
      orderBy: 'ordine ASC',
    );

    return DbMappers.spotFromMap(
      righeSpot.first,
      coordinate: righeCoord.map(DbMappers.coordinataFromMap).toList(),
    );
  }

  /// Carica tutte le coordinate di tutti gli spot in una sola query,
  /// raggruppate per `spotNome` e ordinate per `ordine ASC` (per la mappa).
  Future< Map<String, List<Coordinata>> > getTutteLeCoordinate() async {
    final db = await _dbHelper.database;
    final righe = await db.query(
      'Coordinata',
      orderBy: 'spot_nome ASC, ordine ASC',
    );

    final mappa = <String, List<Coordinata>>{};
    for (final riga in righe) {
      final coord = DbMappers.coordinataFromMap(riga);
      final spotNome = coord.spotNome;
      if (spotNome != null) {
        mappa.putIfAbsent(spotNome, () => []).add(coord);
      }
    }
    return mappa;
  }

  // ===========================================================================
  // SCRITTURA ED ELIMINAZIONE
  // ===========================================================================

  Future<void> inserisciCategoria(Categoria categoria) async {
    final db = await _dbHelper.database;
    await db.insert('Categoria', DbMappers.categoriaToMap(categoria));
  }

  Future<void> aggiornaCategoria({
    required String nomeOriginale,
    required Categoria categoriaAggiornata,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'Categoria',
      DbMappers.categoriaToMap(categoriaAggiornata),
      where: 'nome = ?',
      whereArgs: [nomeOriginale],
    );
  }

  Future<void> eliminaCategoria(String nome) async {
    final db = await _dbHelper.database;
    await db.delete('Categoria', where: 'nome = ?', whereArgs: [nome]);
  }

  /// Aggiunge un nuovo ambiente. Un nome già presente, anche con maiuscole
  /// diverse, viene rifiutato dal database (PRIMARY KEY COLLATE NOCASE).
  Future<void> inserisciAmbiente(Ambiente ambiente) async {
    final db = await _dbHelper.database;
    await db.insert(
      'Ambiente',
      DbMappers.ambienteToMap(ambiente.copyWith(nome: ambiente.nome.trim())),
    );
  }

  /// Rinomina un ambiente; il nuovo nome si propaga agli spot (ON UPDATE CASCADE).
  Future<void> aggiornaAmbiente({
    required String nomeOriginale,
    required Ambiente ambienteAggiornato,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'Ambiente',
      DbMappers.ambienteToMap(
        ambienteAggiornato.copyWith(nome: ambienteAggiornato.nome.trim()),
      ),
      where: 'nome = ?',
      whereArgs: [nomeOriginale],
    );
  }

  /// Elimina un ambiente. Bloccata (ON DELETE RESTRICT) se è usato da almeno uno spot.
  Future<void> eliminaAmbiente(String nome) async {
    final db = await _dbHelper.database;
    await db.delete('Ambiente', where: 'nome = ?', whereArgs: [nome]);
  }

  /// Sposta tutti gli spot (oppure solo `spotNome` se specificato) da una
  /// categoria a un'altra. Utile prima di eliminare una categoria.
  Future<int> spostaSpot({
    required String daCategoria,
    required String aCategoria,
    String? spotNome,
  }) async {
    final db = await _dbHelper.database;
    if (spotNome != null) {
      return await db.update(
        'Spot',
        {'categoria_nome': aCategoria},
        where: 'nome = ? AND categoria_nome = ?',
        whereArgs: [spotNome, daCategoria],
      );
    }
    return await db.update(
      'Spot',
      {'categoria_nome': aCategoria},
      where: 'categoria_nome = ?',
      whereArgs: [daCategoria],
    );
  }

  /// Inserisce (se [nomeOriginale] è null) o aggiorna uno Spot e le sue coordinate.
  /// Ricalcola automaticamente `lunghezzaMetri` ogni volta che ci sono almeno
  /// 2 coordinate e allinea `battuto` alla presenza reale di pescate.
  Future<void> salvaSpotConCoordinate(
    Spot spot, {
    String? nomeOriginale,
  }) async {
    final db = await _dbHelper.database;

    final lunghezzaEffettiva = spot.coordinate.length >= 2
        ? calcolaLunghezzaMetri(spot.coordinate)
        : spot.lunghezzaMetri;
    final spotDaSalvare = spot.copyWith(lunghezzaMetri: lunghezzaEffettiva);

    await db.transaction((txn) async {
      // Una categoria scritta al momento nel modulo dello spot nasce qui,
      // con lo spot; se esiste già (anche con maiuscole diverse) si usa quella.
      final categoria = await _assicuraCategoria(txn, spotDaSalvare.categoriaNome);
      final salvato = spotDaSalvare.copyWith(categoriaNome: categoria);

      if (nomeOriginale == null) {
        await txn.insert('Spot', DbMappers.spotToMap(salvato));
      } else {
        await txn.update(
          'Spot',
          DbMappers.spotToMap(salvato),
          where: 'nome = ?',
          whereArgs: [nomeOriginale],
        );
        await txn.delete(
          'Coordinata',
          where: 'spot_nome = ?',
          whereArgs: [salvato.nome],
        );
      }

      for (var i = 0; i < salvato.coordinate.length; i++) {
        final coord = salvato.coordinate[i].copyWith(
          spotNome: salvato.nome,
          ordine: i,
        );
        await txn.insert('Coordinata', DbMappers.coordinataToMap(coord));
      }

      await QueryCondivise.aggiornaStatoBattutoSpot(txn, salvato.nome);
    });
  }

  Future<String> _assicuraCategoria(DatabaseExecutor txn, String nome) async {
    final esistente = await txn.query(
      'Categoria',
      columns: ['nome'],
      where: 'LOWER(TRIM(nome)) = LOWER(TRIM(?))',
      whereArgs: [nome],
      limit: 1,
    );
    if (esistente.isNotEmpty) return esistente.first['nome'] as String;
    final pulito = nome.trim();
    await txn.insert('Categoria', {'nome': pulito});
    return pulito;
  }

  /// Condizioni compilate in almeno una pescata dello spot [spotNome] ma non
  /// collegate all'ambiente [ambienteNome]. Da usare prima di cambiare
  /// l'ambiente di uno spot, per proporre all'utente di collegarle anche al
  /// nuovo ambiente. Le condizioni sono restituite senza valori.
  ///
  /// Cambiare ambiente non cancella mai i valori già salvati nelle pescate:
  /// questo controllo serve solo a mantenere coerente il form.
  Future<List<Condizione>> getCondizioniNonPreviste({
    required String spotNome,
    required String ambienteNome,
  }) async {
    final db = await _dbHelper.database;
    final righe = await db.rawQuery('''
      SELECT DISTINCT c.* FROM Condizione c
      INNER JOIN Pescata_Condizione pc ON pc.condizione_id = c.id
      INNER JOIN Pescata p ON p.id = pc.pescata_id
      WHERE p.spot_nome = ?
        AND c.id NOT IN (
          SELECT condizione_id FROM Ambiente_Condizione WHERE ambiente_nome = ?)
      ORDER BY c.ordine ASC, c.nome ASC
    ''', [spotNome, ambienteNome]);
    return righe.map((r) => DbMappers.condizioneFromMap(r)).toList();
  }

  Future<void> eliminaSpot(String nome) async {
    final db = await _dbHelper.database;
    await db.delete('Spot', where: 'nome = ?', whereArgs: [nome]);
  }

  // ===========================================================================
  // CALCOLO DISTANZA GEODETICA (FORMULA DI HAVERSINE)
  // ===========================================================================

  /// Calcola la lunghezza totale in metri lungo la spezzata delle coordinate.
  /// Restituisce `null` se ci sono meno di 2 punti o se la distanza è 0.
  static double? calcolaLunghezzaMetri(List<Coordinata> coordinate) {
    if (coordinate.length < 2) return null;

    const raggioTerraMetri = 6371000.0;
    var totale = 0.0;

    for (var i = 0; i < coordinate.length - 1; i++) {
      final p1 = coordinate[i];
      final p2 = coordinate[i + 1];

      final dLat = _gradiInRadianti(p2.latitudine - p1.latitudine);
      final dLon = _gradiInRadianti(p2.longitudine - p1.longitudine);
      final lat1 = _gradiInRadianti(p1.latitudine);
      final lat2 = _gradiInRadianti(p2.latitudine);

      final a = sin(dLat / 2) * sin(dLat / 2) +
          cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
      final c = 2 * atan2(sqrt(a), sqrt(1 - a));

      totale += raggioTerraMetri * c;
    }

    if (totale <= 0) return null;
    return double.parse(totale.toStringAsFixed(1));
  }

  static double _gradiInRadianti(double gradi) => gradi * pi / 180.0;
}