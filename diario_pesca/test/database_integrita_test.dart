import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../lib/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    // Crea un database in memoria isolato e pulito prima di ogni singolo test
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: DatabaseHelper.onConfigure,
      onCreate: DatabaseHelper.onCreate,
      singleInstance: false,
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper che popola un set completo e valido di dati su tutte le 15 tabelle.
  Future<
      ({
        int pescataId,
        int esca1Id,
        int catturaId,
        int riepilogoId,
        int carattTrotaId,
        int carattSpigolaId,
        int obiettivoSpecificoId,
      })> popolaDatiBase() async {
    await db.insert('Categoria', {
      'nome': 'Torrente',
      'note': 'Acque correnti montane',
    });
    await db.insert('Categoria', {
      'nome': 'Foce',
      'note': null,
    });

    await db.insert('Spot', {
      'nome': 'Ponte Vecchio',
      'ambiente': 'Torrente di fondovalle',
      'lunghezzaMetri': 350.5,
      'voto': 9,
      'difficolta': 'media',
      'esposizioneSole': 'Mattino',
      'noteOstacoli': 'Massi affioranti',
      'note': 'Ottimo dopo pioggia',
      'battuto': 1,
      'linkParcheggio': 'https://maps.example.com/parcheggio',
      'categoria_nome': 'Torrente',
    });
    await db.insert('Spot', {
      'nome': 'Scogliera Est',
      'ambiente': 'Mare',
      'categoria_nome': null,
    });

    await db.insert('Coordinata', {
      'spot_nome': 'Ponte Vecchio',
      'ordine': 0,
      'latitudine': 45.6495,
      'longitudine': 9.6012,
    });
    await db.insert('Coordinata', {
      'spot_nome': 'Ponte Vecchio',
      'ordine': 1,
      'latitudine': 45.6510,
      'longitudine': 9.6030,
    });

    await db.insert('Pianificazione', {
      'data': '2026-11-20',
      'fasciaOraria': 'alba',
      'note': 'Uscita esplorativa',
      'spot_nome': 'Ponte Vecchio',
    });

    final pescataId = await db.insert('Pescata', {
      'data': '2026-11-12',
      'fasciaOraria': 'alba',
      'meteo': 'velato',
      'trasparenza': 'velata',
      'fondo': 'normale',
      'livello': 'morbida',
      'temp_acqua': 11.5,
      'temp_aria': 8.0,
      'note': 'Attività sulle correntine',
      'spot_nome': 'Ponte Vecchio',
    });

    final esca1Id = await db.insert('Esca', {
      'nome': 'Minnow 7cm',
      'descrizione': 'Affondante livrea vairone',
    });
    final esca2Id = await db.insert('Esca', {
      'nome': 'Cucchiaino rotante #2',
      'descrizione': null,
    });

    await db.insert('Pescata_Esca', {
      'pescata_id': pescataId,
      'esca_id': esca1Id,
    });
    await db.insert('Pescata_Esca', {
      'pescata_id': pescataId,
      'esca_id': esca2Id,
    });

    await db.insert('Specie', {
      'nome': 'Trota',
      'informazioni': 'Salmonide autoctono',
    });
    await db.insert('Specie', {
      'nome': 'Spigola',
      'informazioni': 'Predatore costiero',
    });

    final catturaId = await db.insert('CatturaMemorabile', {
      'descrizione': 'Esemplare over 45cm rilasciato',
      'pescata_id': pescataId,
      'specie_nome': 'Trota',
      'esca_id': esca1Id,
    });

    await db.insert('Foto', {
      'percorso': '/img/pescata_1.jpg',
      'percorsoThumbnail': '/img/thumb_pescata_1.jpg',
      'pescata_id': pescataId,
      'cattura_memorabile_id': null,
    });
    await db.insert('Foto', {
      'percorso': '/img/cattura_1.jpg',
      'percorsoThumbnail': '/img/thumb_cattura_1.jpg',
      'pescata_id': null,
      'cattura_memorabile_id': catturaId,
    });

    final riepilogoId = await db.insert('RiepilogoSpecie', {
      'pescata_id': pescataId,
      'specie_nome': 'Trota',
      'quantita': 4,
    });

    final carattTrotaId = await db.insert('Caratteristica', {
      'specie_nome': 'Trota',
      'nome': 'Livrea marmorata',
      'descrizione': 'Trota autoctona tipica del bacino padano',
    });
    final carattSpigolaId = await db.insert('Caratteristica', {
      'specie_nome': 'Spigola',
      'nome': 'Over 2 kg',
      'descrizione': 'Esemplare di taglia',
    });

    await db.insert('Cattura_Caratteristica', {
      'cattura_memorabile_id': catturaId,
      'caratteristica_id': carattTrotaId,
      'specie_nome': 'Trota',
    });

    final obiettivoSpecificoId = await db.insert('Obiettivo', {
      'specie_nome': 'Trota',
      'anno': 2026,
      'quantita': 10,
      'caratteristica_id': carattTrotaId,
    });
    await db.insert('Obiettivo', {
      'specie_nome': 'Spigola',
      'anno': 2026,
      'quantita': 15,
      'caratteristica_id': null,
    });

    await db.insert('DettaglioRiepilogo', {
      'riepilogo_specie_id': riepilogoId,
      'caratteristica_id': carattTrotaId,
      'specie_nome': 'Trota',
      'quantita': 2,
    });

    return (
      pescataId: pescataId,
      esca1Id: esca1Id,
      catturaId: catturaId,
      riepilogoId: riepilogoId,
      carattTrotaId: carattTrotaId,
      carattSpigolaId: carattSpigolaId,
      obiettivoSpecificoId: obiettivoSpecificoId,
    );
  }

  // ===========================================================================
  // SEZIONE 1: SCHEMA, PRAGMA E INDICI
  // ===========================================================================
  group('1. Schema, PRAGMA e Indici', () {
    test('PRAGMA foreign_keys è attivo', () async {
      final res = await db.rawQuery('PRAGMA foreign_keys;');
      expect(res.first['foreign_keys'], 1);
    });

    test('Esistono tutte le 15 tabelle', () async {
      const tabelleAttese = {
        'Categoria',
        'Spot',
        'Coordinata',
        'Pianificazione',
        'Pescata',
        'Esca',
        'Pescata_Esca',
        'Specie',
        'CatturaMemorabile',
        'Foto',
        'RiepilogoSpecie',
        'Caratteristica',
        'Cattura_Caratteristica',
        'Obiettivo',
        'DettaglioRiepilogo',
      };
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata';",
      );
      final presenti = rows.map((r) => r['name'] as String).toSet();
      expect(presenti, containsAll(tabelleAttese));
      expect(presenti.length, tabelleAttese.length);
    });

    test('Esistono tutti i 14 indici idx_*', () async {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%';",
      );
      expect(rows.length, 14);
    });
  });

  // ===========================================================================
  // SEZIONE 2: INSERIMENTI VALIDI
  // ===========================================================================
  group('2. Inserimenti Validi', () {
    test('Inserimento completo su tutte le 15 tabelle senza errori', () async {
      final ids = await popolaDatiBase();
      expect(ids.pescataId, greaterThan(0));
      expect(ids.catturaId, greaterThan(0));
      expect(ids.riepilogoId, greaterThan(0));
    });
  });

  // ===========================================================================
  // SEZIONE 3: VINCOLI CHECK E UNIQUE
  // ===========================================================================
  group('3. Vincoli CHECK e UNIQUE', () {
    test('Categoria: nome con soli spazi rifiutato', () async {
      expect(
        () => db.insert('Categoria', {'nome': '   '}),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Spot: lunghezzaMetri <= 0, voto > 10, difficolta o battuto errati rifiutati', () async {
      expect(
        () => db.insert('Spot', {'nome': 'S1', 'ambiente': 'Lago', 'lunghezzaMetri': 0}),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.insert('Spot', {'nome': 'S2', 'ambiente': 'Lago', 'voto': 11}),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.insert('Spot', {'nome': 'S3', 'ambiente': 'Lago', 'difficolta': 'estrema'}),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.insert('Spot', {'nome': 'S4', 'ambiente': 'Lago', 'battuto': 2}),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Coordinata: latitudine fuori range rifiutata', () async {
      await popolaDatiBase();
      expect(
        () => db.insert('Coordinata', {
          'spot_nome': 'Ponte Vecchio',
          'ordine': 2,
          'latitudine': 95.0,
          'longitudine': 10.0,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Pianificazione: data inesistente o fasciaOraria non valida rifiutate', () async {
      expect(
        () => db.insert('Pianificazione', {'data': '2026-02-30', 'fasciaOraria': 'mattina'}),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.insert('Pianificazione', {'data': '2026-11-25', 'fasciaOraria': 'mezzogiorno'}),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Pescata: temp_acqua fuori range o meteo non valido rifiutati', () async {
      expect(
        () => db.insert('Pescata', {
          'data': '2026-11-12',
          'fasciaOraria': 'sera',
          'meteo': 'sereno',
          'temp_acqua': 40.0,
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.insert('Pescata', {
          'data': '2026-11-12',
          'fasciaOraria': 'sera',
          'meteo': 'neve',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Foto: vincolo XOR tra pescata_id e cattura_memorabile_id', () async {
      final ids = await popolaDatiBase();
      expect(
        () => db.insert('Foto', {
          'percorso': '/a.jpg',
          'percorsoThumbnail': '/ta.jpg',
          'pescata_id': null,
          'cattura_memorabile_id': null,
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.insert('Foto', {
          'percorso': '/b.jpg',
          'percorsoThumbnail': '/tb.jpg',
          'pescata_id': ids.pescataId,
          'cattura_memorabile_id': ids.catturaId,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('RiepilogoSpecie UNIQUE e Obiettivo CHECK anno', () async {
      final ids = await popolaDatiBase();
      expect(
        () => db.insert('RiepilogoSpecie', {
          'pescata_id': ids.pescataId,
          'specie_nome': 'Trota',
          'quantita': 1,
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.insert('Obiettivo', {
          'specie_nome': 'Trota',
          'anno': 1999,
          'quantita': 5,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ===========================================================================
  // SEZIONE 4: CONTROLLO INCROCIATO SPECIE (FK COMPOSTE)
  // ===========================================================================
  group('4. Integrità Incrociata tra Specie', () {
    test('Blocca associazione di caratteristiche appartenenti ad altra specie', () async {
      final ids = await popolaDatiBase();

      expect(
        () => db.insert('Cattura_Caratteristica', {
          'cattura_memorabile_id': ids.catturaId,
          'caratteristica_id': ids.carattSpigolaId,
          'specie_nome': 'Trota',
        }),
        throwsA(isA<DatabaseException>()),
      );

      expect(
        () => db.insert('DettaglioRiepilogo', {
          'riepilogo_specie_id': ids.riepilogoId,
          'caratteristica_id': ids.carattSpigolaId,
          'specie_nome': 'Trota',
          'quantita': 1,
        }),
        throwsA(isA<DatabaseException>()),
      );

      expect(
        () => db.insert('Obiettivo', {
          'specie_nome': 'Trota',
          'anno': 2026,
          'quantita': 3,
          'caratteristica_id': ids.carattSpigolaId,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  // ===========================================================================
  // SEZIONE 5: AZIONI REFERENZIALI
  // ===========================================================================
  group('5. Azioni Referenziali (CASCADE / RESTRICT / SET NULL)', () {
    test('ON DELETE RESTRICT blocca eliminazione Categoria e Specie in uso', () async {
      await popolaDatiBase();

      expect(
        () => db.delete('Categoria', where: 'nome = ?', whereArgs: ['Torrente']),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.delete('Specie', where: 'nome = ?', whereArgs: ['Trota']),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('ON UPDATE CASCADE propaga rinomina Categoria e Specie', () async {
      final ids = await popolaDatiBase();

      await db.update(
        'Categoria',
        {'nome': 'Torrente Alpino'},
        where: 'nome = ?',
        whereArgs: ['Torrente'],
      );
      final spot = await db.query('Spot', where: 'nome = ?', whereArgs: ['Ponte Vecchio']);
      expect(spot.first['categoria_nome'], 'Torrente Alpino');

      await db.update(
        'Specie',
        {'nome': 'Trota Fario'},
        where: 'nome = ?',
        whereArgs: ['Trota'],
      );
      final cc = await db.query('Cattura_Caratteristica');
      final dr = await db.query('DettaglioRiepilogo');
      final ob = await db.query('Obiettivo', where: 'id = ?', whereArgs: [ids.obiettivoSpecificoId]);
      expect(cc.first['specie_nome'], 'Trota Fario');
      expect(dr.first['specie_nome'], 'Trota Fario');
      expect(ob.first['specie_nome'], 'Trota Fario');
    });

    test('ON DELETE SET NULL + CASCADE su Esca, Spot e Pescata', () async {
      final ids = await popolaDatiBase();

      // Eliminazione Esca
      await db.delete('Esca', where: 'id = ?', whereArgs: [ids.esca1Id]);
      final cattura = await db.query('CatturaMemorabile', where: 'id = ?', whereArgs: [ids.catturaId]);
      final ponteEsca = await db.query('Pescata_Esca', where: 'esca_id = ?', whereArgs: [ids.esca1Id]);
      expect(cattura.first['esca_id'], isNull);
      expect(ponteEsca, isEmpty);

      // Eliminazione Spot
      await db.delete('Spot', where: 'nome = ?', whereArgs: ['Ponte Vecchio']);
      expect(await db.query('Coordinata'), isEmpty);
      expect(await db.query('Pianificazione'), isEmpty);
      final pescata = await db.query('Pescata', where: 'id = ?', whereArgs: [ids.pescataId]);
      expect(pescata.first['spot_nome'], isNull);

      // Eliminazione Pescata
      await db.delete('Pescata', where: 'id = ?', whereArgs: [ids.pescataId]);
      for (final tabella in [
        'Pescata_Esca',
        'CatturaMemorabile',
        'Cattura_Caratteristica',
        'Foto',
        'RiepilogoSpecie',
        'DettaglioRiepilogo',
      ]) {
        expect(await db.query(tabella), isEmpty, reason: 'Tabella $tabella non svuotata');
      }
      expect((await db.query('Specie')).length, 2);
      expect((await db.query('Obiettivo')).length, 2);
    });
  });
}