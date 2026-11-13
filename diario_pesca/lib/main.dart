import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'database/database_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializzazione per Web e Desktop
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MyApp());
}

class RisultatoTest {
  final String sezione;
  final String descrizione;
  final bool superato;
  final String dettaglio;

  const RisultatoTest({
    required this.sezione,
    required this.descrizione,
    required this.superato,
    required this.dettaglio,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const PaginaVerificaDatabase(),
    );
  }
}

class PaginaVerificaDatabase extends StatefulWidget {
  const PaginaVerificaDatabase({super.key});

  @override
  State<PaginaVerificaDatabase> createState() => _PaginaVerificaDatabaseState();
}

class _PaginaVerificaDatabaseState extends State<PaginaVerificaDatabase> {
  late Future<List<RisultatoTest>> _futureTest;
  bool _mostraSoloFalliti = false;

  @override
  void initState() {
    super.initState();
    _futureTest = _eseguiSuiteCompleta();
  }

  void _riavviaTest() {
    setState(() {
      _futureTest = _eseguiSuiteCompleta();
    });
  }

  /// Verifica che un'operazione valida venga eseguita senza eccezioni.
  Future<void> _verificaSuccesso(
    List<RisultatoTest> risultati,
    String sezione,
    String descrizione,
    Future<String> Function() azione,
  ) async {
    try {
      final info = await azione();
      risultati.add(
        RisultatoTest(
          sezione: sezione,
          descrizione: descrizione,
          superato: true,
          dettaglio: info,
        ),
      );
    } catch (e) {
      risultati.add(
        RisultatoTest(
          sezione: sezione,
          descrizione: descrizione,
          superato: false,
          dettaglio: 'Errore imprevisto: $e',
        ),
      );
    }
  }

  /// Verifica che il DB blocchi un'operazione non valida sollevando un'eccezione.
  Future<void> _verificaBloccoVincolo(
    List<RisultatoTest> risultati,
    String sezione,
    String descrizione,
    Future<void> Function() azioneInvalida,
  ) async {
    try {
      await azioneInvalida();
      risultati.add(
        RisultatoTest(
          sezione: sezione,
          descrizione: descrizione,
          superato: false,
          dettaglio: 'FALLITO: il database ha accettato un dato non valido.',
        ),
      );
    } on DatabaseException catch (e) {
      risultati.add(
        RisultatoTest(
          sezione: sezione,
          descrizione: descrizione,
          superato: true,
          dettaglio: 'Bloccato correttamente -> ${e.toString().split('\n').first}',
        ),
      );
    } catch (e) {
      risultati.add(
        RisultatoTest(
          sezione: sezione,
          descrizione: descrizione,
          superato: false,
          dettaglio: 'Eccezione non SQLite: $e',
        ),
      );
    }
  }

  Future<List<RisultatoTest>> _eseguiSuiteCompleta() async {
    final risultati = <RisultatoTest>[];

    // Ricrea il database da zero per avere test deterministici e ripetibili
    await DatabaseHelper.instance.resetPerSviluppo();
    final db = await DatabaseHelper.instance.database;

    // =========================================================================
    // SEZIONE 1: CONFIGURAZIONE, TABELLE E INDICI
    // =========================================================================
    const sec1 = '1. Schema, PRAGMA e Indici';

    await _verificaSuccesso(
      risultati,
      sec1,
      'PRAGMA foreign_keys attivo',
      () async {
        final res = await db.rawQuery('PRAGMA foreign_keys;');
        final attivo = res.first['foreign_keys'] == 1;
        if (!attivo) throw Exception('foreign_keys è disattivato (0)');
        return 'foreign_keys = 1';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec1,
      'Esistenza di tutte le 15 tabelle',
      () async {
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
        final mancanti = tabelleAttese.difference(presenti);
        if (mancanti.isNotEmpty) {
          throw Exception('Tabelle mancanti: $mancanti');
        }
        return 'Tutte e ${tabelleAttese.length} le tabelle sono presenti';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec1,
      'Esistenza di tutti i 14 indici',
      () async {
        final rows = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%';",
        );
        if (rows.length != 14) {
          throw Exception('Trovati ${rows.length} indici invece di 14');
        }
        return 'Tutti i 14 indici idx_* sono presenti';
      },
    );

    // =========================================================================
    // SEZIONE 2: INSERIMENTI VALIDI SU TUTTE LE 15 TABELLE
    // =========================================================================
    const sec2 = '2. Inserimenti Validi (15 Tabelle)';

    late int pianificazioneId;
    late int pescataId;
    late int esca1Id;
    late int esca2Id;
    late int catturaId;
    late int fotoPescataId;
    late int fotoCatturaId;
    late int riepilogoId;
    late int carattTrotaId;
    late int carattSpigolaId;
    late int obiettivoSpecificoId;
    late int obiettivoGenericoId;

    await _verificaSuccesso(
      risultati,
      sec2,
      '[1/15] Inserimento in Categoria',
      () async {
        await db.insert('Categoria', {
          'nome': 'Torrente',
          'note': 'Acque correnti montane',
        });
        await db.insert('Categoria', {
          'nome': 'Foce',
          'note': null, // Campo facoltativo
        });
        return 'Inserite categorie "Torrente" e "Foce"';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec2,
      '[2/15] Inserimento in Spot',
      () async {
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
          'categoria_nome': null, // FK facoltativa
        });
        return 'Inseriti spot "Ponte Vecchio" e "Scogliera Est"';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec2,
      '[3/15] Inserimento in Coordinata (PK composta)',
      () async {
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
        return 'Inserite 2 coordinate ordinate per "Ponte Vecchio"';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec2,
      '[4/15] Inserimento in Pianificazione (fasciaOraria unificata)',
      () async {
        pianificazioneId = await db.insert('Pianificazione', {
          'data': '2026-11-20',
          'fasciaOraria': 'alba',
          'note': 'Uscita esplorativa',
          'spot_nome': 'Ponte Vecchio',
        });
        return 'Inserita pianificazione ID=$pianificazioneId (fasciaOraria: alba)';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec2,
      '[5/15] Inserimento in Pescata',
      () async {
        pescataId = await db.insert('Pescata', {
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
        return 'Inserita pescata ID=$pescataId';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec2,
      '[6/15] Inserimento in Esca',
      () async {
        esca1Id = await db.insert('Esca', {
          'nome': 'Minnow 7cm',
          'descrizione': 'Affondante livrea vairone',
        });
        esca2Id = await db.insert('Esca', {
          'nome': 'Cucchiaino rotante #2',
          'descrizione': null,
        });
        return 'Inserite esche ID=$esca1Id e ID=$esca2Id';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec2,
      '[7/15] Inserimento in Pescata_Esca (N:M)',
      () async {
        await db.insert('Pescata_Esca', {
          'pescata_id': pescataId,
          'esca_id': esca1Id,
        });
        await db.insert('Pescata_Esca', {
          'pescata_id': pescataId,
          'esca_id': esca2Id,
        });
        return 'Associate 2 esche alla pescata ID=$pescataId';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec2,
      '[8/15] Inserimento in Specie',
      () async {
        await db.insert('Specie', {
          'nome': 'Trota',
          'informazioni': 'Salmonide autoctono',
        });
        await db.insert('Specie', {
          'nome': 'Spigola',
          'informazioni': 'Predatore costiero',
        });
        return 'Inserite specie "Trota" e "Spigola"';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec2,
      '[9/15] Inserimento in CatturaMemorabile',
      () async {
        catturaId = await db.insert('CatturaMemorabile', {
          'descrizione': 'Esemplare over 45cm rilasciato',
          'pescata_id': pescataId,
          'specie_nome': 'Trota',
          'esca_id': esca1Id,
        });
        return 'Inserita cattura memorabile ID=$catturaId';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec2,
      '[10/15] Inserimento in Foto (vincolo XOR)',
      () async {
        fotoPescataId = await db.insert('Foto', {
          'percorso': '/img/pescata_1.jpg',
          'percorsoThumbnail': '/img/thumb_pescata_1.jpg',
          'pescata_id': pescataId,
          'cattura_memorabile_id': null,
        });
        fotoCatturaId = await db.insert('Foto', {
          'percorso': '/img/cattura_1.jpg',
          'percorsoThumbnail': '/img/thumb_cattura_1.jpg',
          'pescata_id': null,
          'cattura_memorabile_id': catturaId,
        });
        return 'Inserite foto pescata (ID=$fotoPescataId) e cattura (ID=$fotoCatturaId)';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec2,
      '[11/15] Inserimento in RiepilogoSpecie',
      () async {
        riepilogoId = await db.insert('RiepilogoSpecie', {
          'pescata_id': pescataId,
          'specie_nome': 'Trota',
          'quantita': 4,
        });
        return 'Inserito riepilogo ID=$riepilogoId (4 Trota)';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec2,
      '[12/15] Inserimento in Caratteristica',
      () async {
        carattTrotaId = await db.insert('Caratteristica', {
          'specie_nome': 'Trota',
          'nome': 'Livrea marmorata',
          'descrizione': 'Trota autoctona tipica del bacino padano, si può ibridare con la fario atlantica (alloctona)',
        });
        carattSpigolaId = await db.insert('Caratteristica', {
          'specie_nome': 'Spigola',
          'nome': 'Over 2 kg',
          'descrizione': 'Esemplare di taglia',
        });
        return 'Inserite caratteristiche ID=$carattTrotaId (Trota) e ID=$carattSpigolaId (Spigola)';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec2,
      '[13/15] Inserimento in Cattura_Caratteristica (FK composta)',
      () async {
        await db.insert('Cattura_Caratteristica', {
          'cattura_memorabile_id': catturaId,
          'caratteristica_id': carattTrotaId,
          'specie_nome': 'Trota',
        });
        return 'Associata caratteristica Trota alla cattura Trota';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec2,
      '[14/15] Inserimento in Obiettivo (con e senza caratteristica)',
      () async {
        obiettivoSpecificoId = await db.insert('Obiettivo', {
          'specie_nome': 'Trota',
          'anno': 2026,
          'quantita': 10,
          'caratteristica_id': carattTrotaId,
        });
        obiettivoGenericoId = await db.insert('Obiettivo', {
          'specie_nome': 'Spigola',
          'anno': 2026,
          'quantita': 15,
          'caratteristica_id': null,
        });
        return 'Inseriti obiettivi ID=$obiettivoSpecificoId e ID=$obiettivoGenericoId';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec2,
      '[15/15] Inserimento in DettaglioRiepilogo (FK composta)',
      () async {
        await db.insert('DettaglioRiepilogo', {
          'riepilogo_specie_id': riepilogoId,
          'caratteristica_id': carattTrotaId,
          'specie_nome': 'Trota',
          'quantita': 2,
        });
        return 'Inserito dettaglio riepilogo (2 Trota con livrea marmorata)';
      },
    );

    // =========================================================================
    // SEZIONE 3: VERIFICA VINCOLI CHECK E UNIQUE
    // =========================================================================
    const sec3 = '3. Vincoli CHECK e UNIQUE';

    await _verificaBloccoVincolo(
      risultati,
      sec3,
      'Categoria: nome con soli spazi rifiutato',
      () => db.insert('Categoria', {'nome': '   '}),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec3,
      'Spot: lunghezzaMetri <= 0 rifiutata',
      () => db.insert('Spot', {
        'nome': 'Spot Invalido 1',
        'ambiente': 'Lago',
        'lunghezzaMetri': 0,
      }),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec3,
      'Spot: voto fuori range (11) rifiutato',
      () => db.insert('Spot', {
        'nome': 'Spot Invalido 2',
        'ambiente': 'Lago',
        'voto': 11,
      }),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec3,
      'Spot: difficolta non ammessa ("estrema") rifiutata',
      () => db.insert('Spot', {
        'nome': 'Spot Invalido 3',
        'ambiente': 'Lago',
        'difficolta': 'estrema',
      }),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec3,
      'Spot: battuto diverso da 0/1 (2) rifiutato',
      () => db.insert('Spot', {
        'nome': 'Spot Invalido 4',
        'ambiente': 'Lago',
        'battuto': 2,
      }),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec3,
      'Coordinata: latitudine fuori range (95.0) rifiutata',
      () => db.insert('Coordinata', {
        'spot_nome': 'Ponte Vecchio',
        'ordine': 2,
        'latitudine': 95.0,
        'longitudine': 10.0,
      }),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec3,
      'Pianificazione: data calendario inesistente ("2026-02-30") rifiutata',
      () => db.insert('Pianificazione', {
        'data': '2026-02-30',
        'fasciaOraria': 'mattina',
        'spot_nome': 'Ponte Vecchio',
      }),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec3,
      'Pianificazione: fasciaOraria non ammessa ("mezzogiorno") rifiutata',
      () => db.insert('Pianificazione', {
        'data': '2026-11-25',
        'fasciaOraria': 'mezzogiorno',
        'spot_nome': 'Ponte Vecchio',
      }),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec3,
      'Pescata: temp_acqua fuori range (40.0°C) rifiutata',
      () => db.insert('Pescata', {
        'data': '2026-11-12',
        'fasciaOraria': 'sera',
        'meteo': 'sereno',
        'temp_acqua': 40.0,
      }),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec3,
      'Pescata: meteo non valido ("neve") rifiutato',
      () => db.insert('Pescata', {
        'data': '2026-11-12',
        'fasciaOraria': 'sera',
        'meteo': 'neve',
      }),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec3,
      'Foto XOR: entrambi pescata_id e cattura_memorabile_id NULL rifiutati',
      () => db.insert('Foto', {
        'percorso': '/img/err1.jpg',
        'percorsoThumbnail': '/img/thumb_err1.jpg',
        'pescata_id': null,
        'cattura_memorabile_id': null,
      }),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec3,
      'Foto XOR: entrambi pescata_id e cattura_memorabile_id valorizzati rifiutati',
      () => db.insert('Foto', {
        'percorso': '/img/err2.jpg',
        'percorsoThumbnail': '/img/thumb_err2.jpg',
        'pescata_id': pescataId,
        'cattura_memorabile_id': catturaId,
      }),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec3,
      'RiepilogoSpecie UNIQUE: doppia riga stessa specie nella stessa pescata rifiutata',
      () => db.insert('RiepilogoSpecie', {
        'pescata_id': pescataId,
        'specie_nome': 'Trota',
        'quantita': 1,
      }),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec3,
      'Obiettivo CHECK: anno fuori intervallo (1999) rifiutato',
      () => db.insert('Obiettivo', {
        'specie_nome': 'Trota',
        'anno': 1999,
        'quantita': 5,
      }),
    );

    // =========================================================================
    // SEZIONE 4: CONTROLLO INCROCIATO SPECIE (CHIAVI ESTERNE COMPOSTE)
    // =========================================================================
    const sec4 = '4. Integrità Incrociata tra Specie';

    await _verificaBloccoVincolo(
      risultati,
      sec4,
      'Cattura_Caratteristica: caratteristica di Spigola su cattura di Trota rifiutata',
      () => db.insert('Cattura_Caratteristica', {
        'cattura_memorabile_id': catturaId, // è una Trota
        'caratteristica_id': carattSpigolaId, // è della Spigola
        'specie_nome': 'Trota',
      }),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec4,
      'DettaglioRiepilogo: caratteristica di Spigola su riepilogo di Trota rifiutata',
      () => db.insert('DettaglioRiepilogo', {
        'riepilogo_specie_id': riepilogoId, // è Trota
        'caratteristica_id': carattSpigolaId, // è Spigola
        'specie_nome': 'Trota',
        'quantita': 1,
      }),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec4,
      'Obiettivo: caratteristica di Spigola su obiettivo di Trota rifiutata',
      () => db.insert('Obiettivo', {
        'specie_nome': 'Trota',
        'anno': 2026,
        'quantita': 3,
        'caratteristica_id': carattSpigolaId,
      }),
    );

    // =========================================================================
    // SEZIONE 5: AZIONI REFERENZIALI (RESTRICT, UPDATE CASCADE, SET NULL, CASCADE)
    // =========================================================================
    const sec5 = '5. Azioni Referenziali (CASCADE / RESTRICT / SET NULL)';

    await _verificaBloccoVincolo(
      risultati,
      sec5,
      'ON DELETE RESTRICT: eliminazione Categoria usata da Spot bloccata',
      () => db.delete('Categoria', where: 'nome = ?', whereArgs: ['Torrente']),
    );

    await _verificaBloccoVincolo(
      risultati,
      sec5,
      'ON DELETE RESTRICT: eliminazione Specie usata da Cattura/Riepilogo bloccata',
      () => db.delete('Specie', where: 'nome = ?', whereArgs: ['Trota']),
    );

    await _verificaSuccesso(
      risultati,
      sec5,
      'ON UPDATE CASCADE: rinomina Categoria ("Torrente" -> "Torrente Alpino")',
      () async {
        await db.update(
          'Categoria',
          {'nome': 'Torrente Alpino'},
          where: 'nome = ?',
          whereArgs: ['Torrente'],
        );
        final spot = await db.query(
          'Spot',
          where: 'nome = ?',
          whereArgs: ['Ponte Vecchio'],
        );
        if (spot.first['categoria_nome'] != 'Torrente Alpino') {
          throw Exception('Spot.categoria_nome non aggiornato');
        }
        return 'Spot.categoria_nome aggiornato automaticamente a "Torrente Alpino"';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec5,
      'ON UPDATE CASCADE: rinomina Specie ("Trota" -> "Trota Fario") su tutte le tabelle',
      () async {
        await db.update(
          'Specie',
          {'nome': 'Trota Fario'},
          where: 'nome = ?',
          whereArgs: ['Trota'],
        );
        final cc = await db.query('Cattura_Caratteristica');
        final dr = await db.query('DettaglioRiepilogo');
        final ob = await db.query(
          'Obiettivo',
          where: 'id = ?',
          whereArgs: [obiettivoSpecificoId],
        );
        if (cc.first['specie_nome'] != 'Trota Fario' ||
            dr.first['specie_nome'] != 'Trota Fario' ||
            ob.first['specie_nome'] != 'Trota Fario') {
          throw Exception('Propagazione UPDATE CASCADE incompleta sulle chiavi composte');
        }
        return 'Propagato con successo su Caratteristica, Cattura, Riepilogo, Dettaglio e Obiettivo';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec5,
      'ON DELETE SET NULL + CASCADE: eliminazione Esca',
      () async {
        await db.delete('Esca', where: 'id = ?', whereArgs: [esca1Id]);
        final cattura = await db.query(
          'CatturaMemorabile',
          where: 'id = ?',
          whereArgs: [catturaId],
        );
        final ponteEsca = await db.query(
          'Pescata_Esca',
          where: 'esca_id = ?',
          whereArgs: [esca1Id],
        );
        if (cattura.first['esca_id'] != null) {
          throw Exception('CatturaMemorabile.esca_id non è diventato NULL');
        }
        if (ponteEsca.isNotEmpty) {
          throw Exception('Pescata_Esca non eliminata in cascata');
        }
        return 'CatturaMemorabile.esca_id = NULL e Pescata_Esca eliminata';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec5,
      'ON DELETE SET NULL + CASCADE: eliminazione Spot ("Ponte Vecchio")',
      () async {
        await db.delete('Spot', where: 'nome = ?', whereArgs: ['Ponte Vecchio']);
        final coord = await db.query('Coordinata');
        final pianif = await db.query('Pianificazione');
        final pescata = await db.query(
          'Pescata',
          where: 'id = ?',
          whereArgs: [pescataId],
        );
        if (coord.isNotEmpty || pianif.isNotEmpty) {
          throw Exception('Coordinata o Pianificazione non eliminate in cascata');
        }
        if (pescata.isEmpty || pescata.first['spot_nome'] != null) {
          throw Exception('Pescata persa o spot_nome non impostato a NULL');
        }
        return 'Coordinate e Pianificazione eliminate; Pescata mantenuta con spot_nome = NULL';
      },
    );

    await _verificaSuccesso(
      risultati,
      sec5,
      'ON DELETE CASCADE: eliminazione Pescata pulisce tutti i figli collegati',
      () async {
        await db.delete('Pescata', where: 'id = ?', whereArgs: [pescataId]);
        final tabelleFiglie = [
          'Pescata_Esca',
          'CatturaMemorabile',
          'Cattura_Caratteristica',
          'Foto',
          'RiepilogoSpecie',
          'DettaglioRiepilogo',
        ];
        for (final tabella in tabelleFiglie) {
          final righe = await db.query(tabella);
          if (righe.isNotEmpty) {
            throw Exception('Tabella $tabella contiene ancora ${righe.length} righe');
          }
        }
        // Verifica che i dati anagrafici indipendenti siano rimasti integri
        final specieRimaste = await db.query('Specie');
        final obiettiviRimasti = await db.query('Obiettivo');
        if (specieRimaste.length != 2 || obiettiviRimasti.length != 2) {
          throw Exception('Specie o Obiettivo eliminati erroneamente');
        }
        return 'Tutti i figli della pescata eliminati; Specie e Obiettivi intatti';
      },
    );

    return risultati;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifica Integrità Database Pesca'),
        actions: [
          IconButton(
            tooltip: _mostraSoloFalliti ? 'Mostra tutti' : 'Mostra solo falliti',
            icon: Icon(
              _mostraSoloFalliti ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            onPressed: () {
              setState(() {
                _mostraSoloFalliti = !_mostraSoloFalliti;
              });
            },
          ),
          IconButton(
            tooltip: 'Riesegui tutti i test',
            icon: const Icon(Icons.refresh),
            onPressed: _riavviaTest,
          ),
        ],
      ),
      body: FutureBuilder<List<RisultatoTest>>(
        future: _futureTest,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Esecuzione test su 15 tabelle e vincoli...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Errore fatale durante i test:\n${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            );
          }

          final tutti = snapshot.data ?? [];
          final superati = tutti.where((t) => t.superato).length;
          final falliti = tutti.length - superati;
          final visibili = _mostraSoloFalliti
              ? tutti.where((t) => !t.superato).toList()
              : tutti;

          return Column(
            children: [
              // Banner riepilogativo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: falliti == 0
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: Row(
                  children: [
                    Icon(
                      falliti == 0 ? Icons.verified : Icons.error_outline,
                      color: falliti == 0 ? Colors.green.shade700 : Colors.red.shade700,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            falliti == 0
                                ? 'TUTTI I TEST SUPERATI ($superati/${tutti.length})'
                                : 'ATTENZIONE: $falliti TEST FALLITI su ${tutti.length}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: falliti == 0
                                  ? Colors.green.shade900
                                  : Colors.red.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Verifica schema, CHECK, UNIQUE, FK composte e azioni CASCADE/RESTRICT',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Lista dettagliata dei test
              Expanded(
                child: visibili.isEmpty
                    ? const Center(child: Text('Nessun test fallito.'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: visibili.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = visibili[index];
                          final mostraIntestazione = index == 0 ||
                              visibili[index - 1].sezione != item.sezione;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (mostraIntestazione)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                                  color: Colors.grey.shade100,
                                  child: Text(
                                    item.sezione,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal.shade900,
                                    ),
                                  ),
                                ),
                              ListTile(
                                leading: Icon(
                                  item.superato
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: item.superato ? Colors.green : Colors.red,
                                ),
                                title: Text(
                                  item.descrizione,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    item.dettaglio,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: item.superato
                                          ? Colors.grey.shade700
                                          : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}