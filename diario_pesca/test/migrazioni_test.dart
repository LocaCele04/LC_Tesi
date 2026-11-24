import 'dart:io';

import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/data/migrazioni.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'supporto/fotografia_schema.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Le migrazioni si provano su file veri: un database in memoria sparisce
  // quando si chiude, e non si potrebbe riaprirlo con una versione nuova.
  late Directory cartella;
  late String percorso;

  setUp(() {
    cartella = Directory.systemTemp.createTempSync('diario_pesca_migrazioni_');
    percorso = p.join(cartella.path, 'diario_pesca.db');
  });

  tearDown(() {
    try {
      cartella.deleteSync(recursive: true);
    } on FileSystemException {
      // Su Windows un file ancora aperto non si cancella: è una cartella
      // temporanea, la ripulirà il sistema.
    }
  });

  Future<Map<String, Object?>> databaseNuovo() async {
    final db = await DatabaseHelper.apri(inMemoryDatabasePath, singleInstance: false);
    try {
      return await descriviDatabase(db);
    } finally {
      await db.close();
    }
  }

  group('Migrazioni - Schema attuale', () {
    test('onCreate crea esattamente lo schema della fotografia della versione attuale', () async {
      const versione = DatabaseHelper.versioneSchema;
      final file = fileFotografia(versione);
      if (!file.existsSync()) {
        // Prima esecuzione dopo aver alzato la versione: si scatta la
        // fotografia, che va controllata e aggiunta al repository.
        final db = await DatabaseHelper.apri(inMemoryDatabasePath, singleInstance: false);
        await salvaFotografia(db, versione);
        await db.close();
        fail('Creata ${file.path}: controllala, aggiungila al repository e rilancia i test.');
      }

      await creaDaFotografia(percorso, versione);
      final fotografato = await databaseFactory.openDatabase(
        percorso,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      final daFotografia = await descriviDatabase(fotografato);
      await fotografato.close();

      expect(
        await databaseNuovo(),
        daFotografia,
        reason: 'onCreate è cambiato rispetto alla versione $versione: alza '
            'DatabaseHelper.versioneSchema e aggiungi la migrazione in migrazioni.dart',
      );
    });

    test('ogni versione precedente, aggiornata, diventa uguale a un database nuovo', () async {
      final nuovo = await databaseNuovo();
      final precedenti = versioniFotografate().where((v) => v < DatabaseHelper.versioneSchema);
      // Con la sola versione 1 non c'è ancora nulla da aggiornare.
      for (final versione in precedenti) {
        final file = p.join(cartella.path, 'v$versione.db');
        await creaDaFotografia(file, versione);
        final db = await DatabaseHelper.apri(file, singleInstance: false);
        expect(await db.getVersion(), DatabaseHelper.versioneSchema);
        expect(await descriviDatabase(db), nuovo, reason: 'aggiornamento dalla versione $versione');
        await db.close();
      }
    });

    test('le versioni dei passaggi vanno da 2 alla versione attuale, senza buchi', () {
      expect(
        migrazioni.keys.toList()..sort(),
        [for (var v = 2; v <= DatabaseHelper.versioneSchema; v++) v],
      );
    });
  });

  group('Migrazioni - Meccanismo', () {
    /// Database installato con la versione 1 (dalla sua fotografia) con uno spot, due coordinate, una pescata e
    /// una pianificazione: le tabelle figlie di Spot, con azioni CASCADE e
    /// SET NULL che una ricostruzione sbagliata farebbe partire.
    Future<void> creaVersione1ConDati() async {
      await creaDaFotografia(percorso, 1);
      final db = await databaseFactory.openDatabase(
        percorso,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await db.insert('Categoria', {'nome': 'Valle'});
      await db.insert('Spot', {'nome': 'Valbrina', 'ambiente': 'Torrente', 'categoria_nome': 'Valle'});
      for (var i = 0; i < 2; i++) {
        await db.insert('Coordinata', {
          'spot_nome': 'Valbrina',
          'ordine': i,
          'latitudine': 45.76 + i / 1000,
          'longitudine': 9.64,
        });
      }
      await db.insert('Pescata', {'data': '2026-02-10', 'fasciaOraria': 'alba', 'spot_nome': 'Valbrina'});
      await db.insert('Pianificazione', {'data': '2026-03-01', 'fasciaOraria': 'alba', 'spot_nome': 'Valbrina'});
      await db.close();
    }

    Future<Database> apriAllaVersione(int versione, Map<int, Migrazione> passaggi) =>
        DatabaseHelper.apri(percorso, singleInstance: false, versione: versione, passaggi: passaggi);

    Future<int> conta(Database db, String tabella) async =>
        (await db.rawQuery('SELECT COUNT(*) AS n FROM $tabella')).single['n'] as int;

    test('ricostruire una tabella non tocca le tabelle figlie e mantiene le chiavi esterne', () async {
      await creaVersione1ConDati();

      // Versione 2 finta: Spot riceve un CHECK in più sul nome.
      final db = await apriAllaVersione(2, {
        2: (db) async {
          final sql = (await db.rawQuery("SELECT sql FROM sqlite_master WHERE name = 'Spot'")).single['sql'] as String;
          final colonne = [
            for (final c in await db.rawQuery('PRAGMA table_info(Spot)')) c['name'] as String,
          ];
          await ricostruisciTabella(
            db,
            tabella: 'Spot',
            creaTabella: sql.replaceFirst(RegExp(r'\)\s*$'), ', CHECK (length(nome) <= 60))'),
            colonne: colonne,
            indici: const [
              'CREATE INDEX idx_spot_categoria ON Spot (categoria_nome)',
              'CREATE INDEX idx_spot_ambiente ON Spot (ambiente)',
            ],
          );
        },
      });

      expect(await db.getVersion(), 2);
      // Le azioni a cascata non sono partite: figlie intatte
      expect(await conta(db, 'Coordinata'), 2);
      expect(await conta(db, 'Pianificazione'), 1);
      expect((await db.query('Pescata')).single['spot_nome'], 'Valbrina');
      // Indici ricreati, chiavi esterne di nuovo attive
      final indici = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'Spot'");
      expect(indici.map((r) => r['name']), containsAll(['idx_spot_categoria', 'idx_spot_ambiente']));
      expect((await db.rawQuery('PRAGMA foreign_keys')).first['foreign_keys'], 1);
      // Il nuovo vincolo vale
      await expectLater(
        db.insert('Spot', {'nome': 'x' * 61, 'ambiente': 'Torrente', 'categoria_nome': 'Valle'}),
        throwsA(isA<DatabaseException>()),
      );
      // Le tabelle figlie puntano alla tabella nuova: le azioni ora funzionano
      await db.delete('Spot', where: 'nome = ?', whereArgs: ['Valbrina']);
      expect(await conta(db, 'Coordinata'), 0);
      expect(await conta(db, 'Pianificazione'), 0);
      expect((await db.query('Pescata')).single['spot_nome'], isNull);
      await db.close();
    });

    test('un passaggio che fallisce annulla tutto l\'aggiornamento', () async {
      await creaVersione1ConDati();

      await expectLater(
        apriAllaVersione(2, {
          2: (db) async {
            await db.execute('ALTER TABLE Spot ADD COLUMN prova INTEGER');
            throw StateError('passaggio guasto');
          },
        }),
        throwsA(isA<StateError>()),
      );

      final db = await apriAllaVersione(1, const {});
      expect(await db.getVersion(), 1);
      final colonne = (await db.rawQuery('PRAGMA table_info(Spot)')).map((c) => c['name']);
      expect(colonne, isNot(contains('prova')));
      expect(await conta(db, 'Coordinata'), 2);
      await db.close();
    });

    test('un passaggio che lascia righe senza padre viene annullato', () async {
      await creaVersione1ConDati();

      // Con le chiavi esterne spente il DELETE riesce, ma lascia lo spot
      // senza categoria: il controllo finale lo scopre.
      await expectLater(
        apriAllaVersione(2, {2: (db) => db.execute('DELETE FROM Categoria')}),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('chiavi esterne'))),
      );

      final db = await apriAllaVersione(1, const {});
      expect(await conta(db, 'Categoria'), 1);
      await db.close();
    });

    test('un passaggio mancante blocca l\'aggiornamento', () async {
      await creaVersione1ConDati();

      await expectLater(
        apriAllaVersione(3, {2: (db) async {}}),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('versione 3'))),
      );

      final db = await apriAllaVersione(1, const {});
      expect(await db.getVersion(), 1);
      await db.close();
    });

    test('un database più recente dell\'app non viene aperto né modificato', () async {
      await creaVersione1ConDati();
      final futuro = await apriAllaVersione(2, {2: (db) async {}});
      await futuro.close();

      await expectLater(apriAllaVersione(1, const {}), throwsA(isA<StateError>()));

      final db = await apriAllaVersione(2, const {});
      expect(await db.getVersion(), 2);
      expect(await conta(db, 'Spot'), 1);
      await db.close();
    });
  });
}
