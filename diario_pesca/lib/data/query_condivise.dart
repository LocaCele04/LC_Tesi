import 'package:sqflite/sqflite.dart';

import '../models/catalogo/caratteristica.dart';
import '../models/pescate/riepilogo_specie.dart';
import 'db_mappers.dart';

/// Query usate da più componenti, scritte in un solo punto per evitare copie
/// che nel tempo potrebbero divergere. Ricevono un [DatabaseExecutor], quindi
/// funzionano sia sul database sia dentro una transazione.
class QueryCondivise {
  QueryCondivise._();

  /// Allinea `Spot.battuto` alla presenza reale di pescate nello spot:
  /// 1 se ne esiste almeno una, 0 altrimenti. Va chiamata ogni volta che una
  /// pescata viene creata, spostata su un altro spot o eliminata, e quando
  /// uno spot viene salvato.
  static Future<void> aggiornaStatoBattutoSpot(
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

  /// Riepiloghi specie filtrabili per pescata e/o specie, completi dei
  /// dettagli per caratteristica (`DettaglioRiepilogo`). Sola lettura.
  static Future<List<RiepilogoSpecie>> riepiloghiConDettagli(
    DatabaseExecutor db, {
    int? pescataId,
    String? specieNome,
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

    final righeRiepilogo = await db.query(
      'RiepilogoSpecie',
      where: condizioni.isEmpty ? null : condizioni.join(' AND '),
      whereArgs: argomenti.isEmpty ? null : argomenti,
      orderBy: 'specie_nome ASC',
    );

    final risultati = <RiepilogoSpecie>[];
    for (final riga in righeRiepilogo) {
      final riepilogoId = riga['id'] as int;
      final righeDettagli = await db.rawQuery('''
        SELECT dr.riepilogo_specie_id, dr.quantita,
               c.id AS c_id, c.specie_nome AS c_specie_nome,
               c.nome AS c_nome, c.descrizione AS c_descrizione
        FROM DettaglioRiepilogo dr
        INNER JOIN Caratteristica c ON c.id = dr.caratteristica_id
        WHERE dr.riepilogo_specie_id = ?
        ORDER BY c.nome ASC
      ''', [riepilogoId]);

      final dettagli = righeDettagli.map((rd) {
        final caratt = Caratteristica(
          id: rd['c_id'] as int,
          specieNome: rd['c_specie_nome'] as String,
          nome: rd['c_nome'] as String,
          descrizione: rd['c_descrizione'] as String?,
        );
        return DbMappers.riepilogoCaratteristicaFromMap(
          rd,
          caratteristica: caratt,
        );
      }).toList();

      risultati.add(
        DbMappers.riepilogoSpecieFromMap(riga, dettagli: dettagli),
      );
    }
    return risultati;
  }
}
