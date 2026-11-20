import 'package:diario_pesca/data/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late Database db;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    db = await dbHelper.database;
  });

  tearDown(() async {
    await dbHelper.close();
  });

  /// Id di un valore di base e della sua condizione (es. Livello / Morbida).
  Future<({int valoreId, int condizioneId})> valore(
    String condizione,
    String nome,
  ) async {
    final righe = await db.rawQuery('''
      SELECT v.id, v.condizione_id FROM ValoreCondizione v
      INNER JOIN Condizione c ON c.id = v.condizione_id
      WHERE c.nome = ? AND v.nome = ?
    ''', [condizione, nome]);
    return (
      valoreId: righe.single['id'] as int,
      condizioneId: righe.single['condizione_id'] as int,
    );
  }

  /// Helper che popola un set completo e valido di dati su tutte le 24 tabelle.
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

    await db.insert('Ambiente', {'nome': 'Torrente di fondovalle'});

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
      'accessibilita': 'accessibile',
      'linkParcheggio': 'https://maps.example.com/parcheggio',
      'categoria_nome': 'Torrente',
    });
    await db.insert('Spot', {
      'nome': 'Scogliera Est',
      'ambiente': 'Mare',
      'accessibilita': 'inaccessibile',
      'categoria_nome': 'Foce',
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
      'temp_acqua': 11.5,
      'temp_aria': 8.0,
      'note': 'Attività sulle correntine',
      'spot_nome': 'Ponte Vecchio',
    });
    final morbida = await valore('Livello', 'Morbida');
    await db.insert('Pescata_Condizione', {
      'pescata_id': pescataId,
      'condizione_id': morbida.condizioneId,
      'valore_id': morbida.valoreId,
    });

    final cellaId = await db.insert('CellaMeteo', {
      'latitudine': 45.75,
      'longitudine': 9.625,
      'elevazione': 820.0,
    });
    await db.insert('MeteoGiornaliero', {
      'cella_id': cellaId,
      'data': '2026-11-10',
      'pioggia_mm': 2.4,
      'temp_min': 3.0,
      'temp_max': 11.0,
      'pressione_media': 1016.0,
      'vento_max': 14.0,
      'raffica_max': 30.0,
      'direzione_vento': 200,
    });
    await db.insert('MeteoOrario', {
      'cella_id': cellaId,
      'data_ora': '2026-11-10T05:00',
      'pioggia_mm': 0.0,
      'temperatura': 4.0,
      'pressione': 1015.0,
      'vento': 6.0,
      'raffica': 12.0,
      'direzione_vento': 190,
    });
    await db.insert('PescataMeteo', {
      'pescata_id': pescataId,
      'cella_id': cellaId,
      'data': '2026-11-10',
      'latitudine': 45.6495,
      'longitudine': 9.6012,
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
      'esca_id': null,
    });
    await db.insert('Foto', {
      'percorso': '/img/cattura_1.jpg',
      'percorsoThumbnail': '/img/thumb_cattura_1.jpg',
      'pescata_id': null,
      'cattura_memorabile_id': catturaId,
      'esca_id': null,
    });
    await db.insert('Foto', {
      'percorso': '/img/esca_1.jpg',
      'percorsoThumbnail': '/img/thumb_esca_1.jpg',
      'pescata_id': null,
      'cattura_memorabile_id': null,
      'esca_id': esca1Id,
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

    test('Esistono tutte le 24 tabelle', () async {
      const tabelleAttese = {
        'Categoria',
        'CellaMeteo',
        'MeteoGiornaliero',
        'MeteoOrario',
        'PescataMeteo',
        'Ambiente',
        'Condizione',
        'ValoreCondizione',
        'Ambiente_Condizione',
        'Pescata_Condizione',
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

    test('Esistono tutti i 19 indici idx_*', () async {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%';",
      );
      expect(rows.length, 19);
    });
  });

  // ===========================================================================
  // SEZIONE 2: INSERIMENTI VALIDI
  // ===========================================================================
  group('2. Inserimenti Validi', () {
    test('Inserimento completo su tutte le 24 tabelle senza errori', () async {
      final ids = await popolaDatiBase();
      expect(ids.pescataId, greaterThan(0));
      expect(ids.catturaId, greaterThan(0));
      expect(ids.riepilogoId, greaterThan(0));
    });
  });

  // ===========================================================================
  // SEZIONE 3: VINCOLI CHECK, NOT NULL E UNIQUE
  // ===========================================================================
  group('3. Vincoli CHECK, NOT NULL e UNIQUE', () {
    test('Categoria: nome con soli spazi rifiutato', () async {
      expect(
        () => db.insert('Categoria', {'nome': '   '}),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Ambiente: valori di base presenti, nome vuoto e duplicati senza distinzione di maiuscole rifiutati', () async {
      final base = await db.query('Ambiente', orderBy: 'nome ASC');
      expect(base.map((r) => r['nome']), ['Fiume', 'Lago', 'Mare', 'Torrente']);

      expect(
        () => db.insert('Ambiente', {'nome': '   '}),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.insert('Ambiente', {'nome': 'torrente'}),
        throwsA(isA<DatabaseException>()),
      );

      // Spot con ambiente inesistente rifiutato dalla FK
      await db.insert('Categoria', {'nome': 'Varie'});
      expect(
        () => db.insert('Spot', {
          'nome': 'Spot Strano',
          'ambiente': 'Palude',
          'categoria_nome': 'Varie',
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Un ambiente esistente è accettato anche con maiuscole diverse
      await db.insert('Spot', {
        'nome': 'Spot Minuscolo',
        'ambiente': 'lago',
        'categoria_nome': 'Varie',
      });
    });

    test('Spot: categoria_nome obbligatoria, lunghezzaMetri, voto, difficolta, battuto e accessibilita validati', () async {
      await db.insert('Categoria', {'nome': 'Lago'});

      expect(
        () => db.insert('Spot', {'nome': 'S0', 'ambiente': 'Lago'}),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.insert('Spot', {
          'nome': 'S1',
          'ambiente': 'Lago',
          'lunghezzaMetri': 0,
          'categoria_nome': 'Lago',
        }),
        throwsA(isA<DatabaseException>()),
      );
      // Il voto ammette valori decimali (es. 4.5) entro 0..10
      await db.insert('Spot', {
        'nome': 'SVotoDecimale',
        'ambiente': 'Lago',
        'voto': 4.5,
        'categoria_nome': 'Lago',
      });
      final votoLetto = await db.query('Spot',
          columns: ['voto'], where: 'nome = ?', whereArgs: ['SVotoDecimale']);
      expect(votoLetto.first['voto'], 4.5);
      await db.delete('Spot', where: 'nome = ?', whereArgs: ['SVotoDecimale']);

      expect(
        () => db.insert('Spot', {
          'nome': 'S2',
          'ambiente': 'Lago',
          'voto': 11,
          'categoria_nome': 'Lago',
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.insert('Spot', {
          'nome': 'S3',
          'ambiente': 'Lago',
          'difficolta': 'estrema',
          'categoria_nome': 'Lago',
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.insert('Spot', {
          'nome': 'S4',
          'ambiente': 'Lago',
          'battuto': 2,
          'categoria_nome': 'Lago',
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.insert('Spot', {
          'nome': 'S5',
          'ambiente': 'Lago',
          'accessibilita': 'privata',
          'categoria_nome': 'Lago',
        }),
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

    test('Pescata: temp_acqua fuori range o fasciaOraria non valida rifiutate', () async {
      expect(
        () => db.insert('Pescata', {
          'data': '2026-11-12',
          'fasciaOraria': 'sera',
          'temp_acqua': 40.0,
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => db.insert('Pescata', {
          'data': '2026-11-12',
          'fasciaOraria': 'mezzanotte',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Condizioni: valori di base, unicità senza maiuscole, FK composta e un valore per condizione', () async {
      final condizioni = await db.query('Condizione', orderBy: 'ordine ASC');
      expect(
        condizioni.map((r) => r['nome']),
        ['Livello', 'Trasparenza', 'Fondo', 'Meteo'],
      );
      final livelli = await db.rawQuery('''
        SELECT v.nome FROM ValoreCondizione v
        INNER JOIN Condizione c ON c.id = v.condizione_id
        WHERE c.nome = 'Livello' ORDER BY v.ordine
      ''');
      expect(
        livelli.map((r) => r['nome']),
        ['Secca', 'Magra', 'Normale', 'Morbida', 'Piena'],
      );
      final perLago = await db.rawQuery('''
        SELECT c.nome FROM Condizione c
        INNER JOIN Ambiente_Condizione ac ON ac.condizione_id = c.id
        WHERE ac.ambiente_nome = 'lago'
      ''');
      expect(perLago.map((r) => r['nome']), ['Meteo']);

      // Nomi unici senza distinzione di maiuscole
      expect(
        () => db.insert('Condizione', {'nome': 'livello'}),
        throwsA(isA<DatabaseException>()),
      );
      final livelloId = condizioni.first['id'] as int;
      expect(
        () => db.insert('ValoreCondizione', {
          'condizione_id': livelloId,
          'nome': 'MAGRA',
        }),
        throwsA(isA<DatabaseException>()),
      );
      // Lo stesso nome in condizioni diverse è ammesso (Normale: Livello e Fondo)
      final normali = await db.query(
        'ValoreCondizione',
        where: 'nome = ?',
        whereArgs: ['Normale'],
      );
      expect(normali.length, 2);

      final pescataId = await db.insert('Pescata', {
        'data': '2026-11-12',
        'fasciaOraria': 'alba',
      });
      final morbida = await valore('Livello', 'Morbida');
      final magra = await valore('Livello', 'Magra');
      final velata = await valore('Trasparenza', 'Velata');
      final scuro = await valore('Fondo', 'Scuro');

      await db.insert('Pescata_Condizione', {
        'pescata_id': pescataId,
        'condizione_id': morbida.condizioneId,
        'valore_id': morbida.valoreId,
      });
      // Secondo valore per la stessa condizione nella stessa pescata
      expect(
        () => db.insert('Pescata_Condizione', {
          'pescata_id': pescataId,
          'condizione_id': magra.condizioneId,
          'valore_id': magra.valoreId,
        }),
        throwsA(isA<DatabaseException>()),
      );
      // Valore che appartiene a un'altra condizione
      expect(
        () => db.insert('Pescata_Condizione', {
          'pescata_id': pescataId,
          'condizione_id': scuro.condizioneId,
          'valore_id': velata.valoreId,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Foto: vincolo XOR tra pescata_id, cattura_memorabile_id ed esca_id', () async {
      final ids = await popolaDatiBase();

      // Tutti null
      expect(
        () => db.insert('Foto', {
          'percorso': '/a.jpg',
          'percorsoThumbnail': '/ta.jpg',
          'pescata_id': null,
          'cattura_memorabile_id': null,
          'esca_id': null,
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Due genitori valorizzati (pescata + cattura)
      expect(
        () => db.insert('Foto', {
          'percorso': '/b.jpg',
          'percorsoThumbnail': '/tb.jpg',
          'pescata_id': ids.pescataId,
          'cattura_memorabile_id': ids.catturaId,
          'esca_id': null,
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Due genitori valorizzati (pescata + esca)
      expect(
        () => db.insert('Foto', {
          'percorso': '/c.jpg',
          'percorsoThumbnail': '/tc.jpg',
          'pescata_id': ids.pescataId,
          'cattura_memorabile_id': null,
          'esca_id': ids.esca1Id,
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Due genitori valorizzati (cattura + esca)
      expect(
        () => db.insert('Foto', {
          'percorso': '/d.jpg',
          'percorsoThumbnail': '/td.jpg',
          'pescata_id': null,
          'cattura_memorabile_id': ids.catturaId,
          'esca_id': ids.esca1Id,
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Tutti e tre valorizzati
      expect(
        () => db.insert('Foto', {
          'percorso': '/e.jpg',
          'percorsoThumbnail': '/te.jpg',
          'pescata_id': ids.pescataId,
          'cattura_memorabile_id': ids.catturaId,
          'esca_id': ids.esca1Id,
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

    test('Ambiente: ON DELETE RESTRICT se usato da uno spot, ON UPDATE CASCADE sulla rinomina', () async {
      await db.insert('Categoria', {'nome': 'Varie'});
      await db.insert('Ambiente', {'nome': 'Canale'});
      await db.insert('Spot', {
        'nome': 'Canale Vecchio',
        'ambiente': 'Canale',
        'categoria_nome': 'Varie',
      });

      expect(
        () => db.delete('Ambiente', where: 'nome = ?', whereArgs: ['Canale']),
        throwsA(isA<DatabaseException>()),
      );

      await db.update(
        'Ambiente',
        {'nome': 'Roggia'},
        where: 'nome = ?',
        whereArgs: ['Canale'],
      );
      final spot = await db.query('Spot', where: 'nome = ?', whereArgs: ['Canale Vecchio']);
      expect(spot.first['ambiente'], 'Roggia');

      // Ambiente non usato: eliminabile
      await db.delete('Ambiente', where: 'nome = ?', whereArgs: ['Mare']);
      final mare = await db.query('Ambiente', where: 'nome = ?', whereArgs: ['Mare']);
      expect(mare, isEmpty);
    });

    test('Condizioni: RESTRICT sui valori usati, CASCADE su condizioni non usate, ambienti e pescate', () async {
      final pescataId = await db.insert('Pescata', {
        'data': '2026-11-12',
        'fasciaOraria': 'alba',
      });
      final morbida = await valore('Livello', 'Morbida');
      await db.insert('Pescata_Condizione', {
        'pescata_id': pescataId,
        'condizione_id': morbida.condizioneId,
        'valore_id': morbida.valoreId,
      });

      // Valore usato: non eliminabile, né direttamente né con la sua condizione
      await expectLater(
        () => db.delete('ValoreCondizione', where: 'id = ?', whereArgs: [morbida.valoreId]),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        () => db.delete('Condizione', where: 'id = ?', whereArgs: [morbida.condizioneId]),
        throwsA(isA<DatabaseException>()),
      );

      // Condizione mai usata: eliminata con valori e collegamenti
      final fondoId = (await valore('Fondo', 'Scuro')).condizioneId;
      await db.delete('Condizione', where: 'id = ?', whereArgs: [fondoId]);
      expect(
        await db.query('ValoreCondizione', where: 'condizione_id = ?', whereArgs: [fondoId]),
        isEmpty,
      );
      expect(
        await db.query('Ambiente_Condizione', where: 'condizione_id = ?', whereArgs: [fondoId]),
        isEmpty,
      );

      // Rinomina dell'ambiente propagata ai collegamenti (Livello, Trasparenza, Meteo)
      await db.update(
        'Ambiente',
        {'nome': 'Torrente alpino'},
        where: 'nome = ?',
        whereArgs: ['Torrente'],
      );
      final collegamenti = await db.query(
        'Ambiente_Condizione',
        where: 'ambiente_nome = ?',
        whereArgs: ['Torrente alpino'],
      );
      expect(collegamenti.length, 3);

      // Eliminata la pescata spariscono le sue righe e il valore torna eliminabile
      await db.delete('Pescata', where: 'id = ?', whereArgs: [pescataId]);
      expect(await db.query('Pescata_Condizione'), isEmpty);
      await db.delete('ValoreCondizione', where: 'id = ?', whereArgs: [morbida.valoreId]);
    });

    test('Meteo: vincoli sui dati, una riga per cella e giorno/ora, cascate su pescata e cella', () async {
      final cellaId = await db.insert('CellaMeteo', {
        'latitudine': 45.75,
        'longitudine': 9.625,
        'elevazione': 820.0,
      });
      // Stessa cella alla stessa quota due volte, oppure senza quota
      for (final riga in [
        {'latitudine': 45.75, 'longitudine': 9.625, 'elevazione': 820.0},
        {'latitudine': 45.75, 'longitudine': 9.625},
      ]) {
        await expectLater(
          () => db.insert('CellaMeteo', riga),
          throwsA(isA<DatabaseException>()),
        );
      }
      // Stessa cella della griglia a un'altra quota: è una cella distinta
      await db.insert('CellaMeteo', {
        'latitudine': 45.75,
        'longitudine': 9.625,
        'elevazione': 1100.0,
      });

      await db.insert('MeteoGiornaliero', {
        'cella_id': cellaId,
        'data': '2026-11-10',
      });
      // Stesso giorno due volte, data non valida, pioggia negativa
      for (final riga in [
        {'cella_id': cellaId, 'data': '2026-11-10'},
        {'cella_id': cellaId, 'data': '2026-02-30'},
        {'cella_id': cellaId, 'data': '2026-11-12', 'pioggia_mm': -1.0},
      ]) {
        await expectLater(
          () => db.insert('MeteoGiornaliero', riga),
          throwsA(isA<DatabaseException>()),
        );
      }
      // Ora in formato errato e direzione del vento fuori intervallo
      for (final riga in [
        {'cella_id': cellaId, 'data_ora': '2026-11-10 05:00'},
        {'cella_id': cellaId, 'data_ora': '2026-11-10T05:00', 'direzione_vento': 400},
      ]) {
        await expectLater(
          () => db.insert('MeteoOrario', riga),
          throwsA(isA<DatabaseException>()),
        );
      }
      await db.insert('MeteoOrario', {
        'cella_id': cellaId,
        'data_ora': '2026-11-10T05:00',
      });

      final pescataId = await db.insert('Pescata', {
        'data': '2026-11-10',
        'fasciaOraria': 'alba',
      });
      await db.insert('PescataMeteo', {
        'pescata_id': pescataId,
        'cella_id': cellaId,
        'data': '2026-11-10',
        'latitudine': 45.76,
        'longitudine': 9.64,
      });

      // Eliminata la pescata sparisce il collegamento, l'archivio resta
      await db.delete('Pescata', where: 'id = ?', whereArgs: [pescataId]);
      expect(await db.query('PescataMeteo'), isEmpty);
      expect(await db.query('MeteoGiornaliero'), hasLength(1));

      // Eliminata la cella sparisce il suo archivio
      await db.delete('CellaMeteo', where: 'id = ?', whereArgs: [cellaId]);
      expect(await db.query('MeteoGiornaliero'), isEmpty);
      expect(await db.query('MeteoOrario'), isEmpty);
    });

    test('ON DELETE SET NULL + CASCADE su Esca, Spot e Pescata', () async {
      final ids = await popolaDatiBase();

      // Eliminazione Esca: SET NULL su CatturaMemorabile, CASCADE su Pescata_Esca e Foto dell'esca
      await db.delete('Esca', where: 'id = ?', whereArgs: [ids.esca1Id]);
      final cattura = await db.query('CatturaMemorabile', where: 'id = ?', whereArgs: [ids.catturaId]);
      final ponteEsca = await db.query('Pescata_Esca', where: 'esca_id = ?', whereArgs: [ids.esca1Id]);
      final fotoEsca = await db.query('Foto', where: 'esca_id = ?', whereArgs: [ids.esca1Id]);
      expect(cattura.first['esca_id'], isNull);
      expect(ponteEsca, isEmpty);
      expect(fotoEsca, isEmpty);

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