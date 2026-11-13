import 'dart:math';

import '../database/database_helper.dart';
import '../models/enums.dart';
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
    return righe.map(_categoriaFromMap).toList();
  }

  /// Elenco spot con filtri opzionali combinabili (senza caricare le coordinate).
  Future<List<Spot>> getSpots({
    String? categoriaNome,
    String? ambiente,
    int? votoMinimo,
    double? lunghezzaMassima,
    Difficolta? difficolta,
    bool? battuto,
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

    final righe = await db.query(
      'Spot',
      where: condizioni.isEmpty ? null : condizioni.join(' AND '),
      whereArgs: argomenti.isEmpty ? null : argomenti,
      orderBy: 'nome ASC',
    );
    return righe.map((r) => _spotFromMap(r)).toList();
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

    return _spotFromMap(
      righeSpot.first,
      coordinate: righeCoord.map(_coordinataFromMap).toList(),
    );
  }

  // ===========================================================================
  // SCRITTURA ED ELIMINAZIONE
  // ===========================================================================

  Future<void> inserisciCategoria(Categoria categoria) async {
    final db = await _dbHelper.database;
    await db.insert('Categoria', _categoriaToMap(categoria));
  }

  Future<void> aggiornaCategoria({
    required String nomeOriginale,
    required Categoria categoriaAggiornata,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'Categoria',
      _categoriaToMap(categoriaAggiornata),
      where: 'nome = ?',
      whereArgs: [nomeOriginale],
    );
  }

  Future<void> eliminaCategoria(String nome) async {
    final db = await _dbHelper.database;
    await db.delete('Categoria', where: 'nome = ?', whereArgs: [nome]);
  }

  /// Inserisce (se [nomeOriginale] è null) o aggiorna uno Spot e le sue coordinate.
  /// Se `lunghezzaMetri` non è stata impostata manualmente e ci sono almeno
  /// 2 coordinate, la calcola automaticamente in metri.
  Future<void> salvaSpotConCoordinate(
    Spot spot, {
    String? nomeOriginale,
  }) async {
    final db = await _dbHelper.database;

    final lunghezzaEffettiva =
        spot.lunghezzaMetri ?? calcolaLunghezzaMetri(spot.coordinate);
    final spotDaSalvare = spot.copyWith(lunghezzaMetri: lunghezzaEffettiva);

    await db.transaction((txn) async {
      if (nomeOriginale == null) {
        await txn.insert('Spot', _spotToMap(spotDaSalvare));
      } else {
        await txn.update(
          'Spot',
          _spotToMap(spotDaSalvare),
          where: 'nome = ?',
          whereArgs: [nomeOriginale],
        );
        await txn.delete(
          'Coordinata',
          where: 'spot_nome = ?',
          whereArgs: [spotDaSalvare.nome],
        );
      }

      for (var i = 0; i < spotDaSalvare.coordinate.length; i++) {
        final coord = spotDaSalvare.coordinate[i].copyWith(
          spotNome: spotDaSalvare.nome,
          ordine: i,
        );
        await txn.insert('Coordinata', _coordinataToMap(coord));
      }
    });
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

  // ===========================================================================
  // MAPPING PRIVATO
  // ===========================================================================

  Categoria _categoriaFromMap(Map<String, Object?> map) => Categoria(
        nome: map['nome'] as String,
        note: map['note'] as String?,
      );

  Map<String, Object?> _categoriaToMap(Categoria c) => {
        'nome': c.nome,
        'note': c.note,
      };

  Coordinata _coordinataFromMap(Map<String, Object?> map) => Coordinata(
        spotNome: map['spot_nome'] as String,
        ordine: map['ordine'] as int,
        latitudine: (map['latitudine'] as num).toDouble(),
        longitudine: (map['longitudine'] as num).toDouble(),
      );

  Map<String, Object?> _coordinataToMap(Coordinata c) => {
        'spot_nome': c.spotNome,
        'ordine': c.ordine,
        'latitudine': c.latitudine,
        'longitudine': c.longitudine,
      };

  Spot _spotFromMap(
    Map<String, Object?> map, {
    List<Coordinata> coordinate = const [],
  }) {
    final difficoltaRaw = map['difficolta'] as String?;
    return Spot(
      nome: map['nome'] as String,
      ambiente: map['ambiente'] as String,
      lunghezzaMetri: (map['lunghezzaMetri'] as num?)?.toDouble(),
      voto: map['voto'] as int?,
      difficolta: difficoltaRaw != null
          ? Difficolta.values.byName(difficoltaRaw)
          : null,
      esposizioneSole: map['esposizioneSole'] as String?,
      noteOstacoli: map['noteOstacoli'] as String?,
      note: map['note'] as String?,
      battuto: (map['battuto'] as int) == 1,
      linkParcheggio: map['linkParcheggio'] as String?,
      categoriaNome: map['categoria_nome'] as String?,
      coordinate: coordinate,
    );
  }

  Map<String, Object?> _spotToMap(Spot s) => {
        'nome': s.nome,
        'ambiente': s.ambiente,
        'lunghezzaMetri': s.lunghezzaMetri,
        'voto': s.voto,
        'difficolta': s.difficolta?.name,
        'esposizioneSole': s.esposizioneSole,
        'noteOstacoli': s.noteOstacoli,
        'note': s.note,
        'battuto': s.battuto ? 1 : 0,
        'linkParcheggio': s.linkParcheggio,
        'categoria_nome': s.categoriaNome,
      };
}