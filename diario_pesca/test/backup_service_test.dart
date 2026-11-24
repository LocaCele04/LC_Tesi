import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/models/territorio/coordinata.dart';
import 'package:diario_pesca/models/territorio/divieto.dart';
import 'package:diario_pesca/repositories/territorio_repository.dart';
import 'package:diario_pesca/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'supporto/fotografia_schema.dart';

/// Solo dati di fantasia.
Divieto _divieto(String nome) => Divieto(
      nome: nome,
      coordinate: const [
        Coordinata(ordine: 0, latitudine: 44.1, longitudine: 8.1),
        Coordinata(ordine: 1, latitudine: 44.2, longitudine: 8.2),
      ],
    );

/// Archivio ZIP costruito a mano, per i file non validi.
Uint8List _zip(Map<String, List<int>> file) {
  final archivio = Archive();
  for (final MapEntry(key: nome, value: dati) in file.entries) {
    archivio.addFile(ArchiveFile(nome, dati.length, dati));
  }
  return ZipEncoder().encodeBytes(archivio);
}

List<int> _manifesto({
  String formato = BackupService.formato,
  int versioneFormato = BackupService.versioneFormato,
  int versioneSchema = DatabaseHelper.versioneSchema,
}) =>
    utf8.encode(jsonEncode({
      'formato': formato,
      'versioneFormato': versioneFormato,
      'creatoIl': '2026-11-20T08:15:00.000',
      'versioneSchema': versioneSchema,
    }));

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Il ripristino sostituisce il file del database: servono file veri.
  late Directory cartella;
  late DatabaseHelper dbHelper;
  late TerritorioRepository territorio;
  late BackupService servizio;
  final oggi = DateTime(2026, 11, 24, 10, 50);

  setUp(() {
    cartella = Directory.systemTemp.createTempSync('diario_pesca_backup_test_');
    dbHelper = DatabaseHelper.file(p.join(cartella.path, 'diario_pesca.db'));
    territorio = TerritorioRepository(dbHelper: dbHelper);
    servizio = BackupService(dbHelper: dbHelper, orologio: () => oggi);
  });

  tearDown(() async {
    await dbHelper.close();
    try {
      cartella.deleteSync(recursive: true);
    } on FileSystemException {
      // Su Windows un file ancora aperto non si cancella.
    }
  });

  /// Un database SQLite in un file, con la versione dello schema indicata.
  Future<Uint8List> databaseVersione(int versione, {bool daFotografia = true}) async {
    final percorso = p.join(cartella.path, 'altro_$versione.db');
    if (File(percorso).existsSync()) File(percorso).deleteSync();
    if (daFotografia) {
      await creaDaFotografia(percorso, versione);
    } else {
      final db = await databaseFactory.openDatabase(percorso, options: OpenDatabaseOptions(singleInstance: false));
      await db.setVersion(versione);
      await db.close();
    }
    return File(percorso).readAsBytes();
  }

  Future<void> siAspettaNonValido(Uint8List byte, String testo) async {
    await expectLater(
      servizio.leggi(byte),
      throwsA(isA<BackupNonValido>().having((e) => e.messaggio, 'messaggio', contains(testo))),
    );
  }

  group('BackupService - Creazione e lettura', () {
    test('nome del file con data e ora', () {
      expect(servizio.nomeFile(), 'diario_pesca_backup_2026-11-24_1050.zip');
    });

    test('il backup letto riporta data, versione dello schema e contenuto', () async {
      await territorio.salvaDivieto(_divieto('Divieto vasca'));
      await territorio.salvaDivieto(_divieto('Divieto per piene'));

      final contenuto = await servizio.leggi(await servizio.crea());

      expect(contenuto.creatoIl, oggi);
      expect(contenuto.versioneSchema, DatabaseHelper.versioneSchema);
      expect(contenuto.divieti, 2);
      expect(contenuto.spot, 0);
      expect(contenuto.pescate, 0);
      expect(contenuto.catture, 0);
      expect(contenuto.foto, isEmpty);
    });

    test('senza VACUUM INTO (SQLite vecchio) la copia del file è un backup valido', () async {
      servizio = BackupService(dbHelper: dbHelper, orologio: () => oggi, usaVacuumInto: false);
      await territorio.salvaDivieto(_divieto('Divieto vasca'));

      final contenuto = await servizio.leggi(await servizio.crea());

      expect(contenuto.divieti, 1);
    });

    test('anche da un database in memoria (VACUUM INTO non ha bisogno del file)', () async {
      final inMemoria = DatabaseHelper.inMemory();
      addTearDown(inMemoria.close);
      await TerritorioRepository(dbHelper: inMemoria).salvaDivieto(_divieto('Divieto vasca'));

      final byte = await BackupService(dbHelper: inMemoria).crea();

      expect((await servizio.leggi(byte)).divieti, 1);
    });
  });

  group('BackupService - Ripristino', () {
    test('sostituisce tutti i dati con quelli del backup', () async {
      await territorio.salvaDivieto(_divieto('Divieto vasca'));
      final contenuto = await servizio.leggi(await servizio.crea());

      final dopo = await territorio.getDivieti();
      await territorio.eliminaDivieto(dopo.single.id!);
      await territorio.salvaDivieto(_divieto('Divieto per piene'));

      await servizio.ripristina(contenuto);

      final ripristinati = await territorio.getDivieti();
      expect(ripristinati.map((d) => d.nome), ['Divieto vasca']);
      expect(ripristinati.single.coordinate, hasLength(2));
      // Il database riaperto ha le chiavi esterne attive.
      final db = await dbHelper.database;
      expect(Sqflite.firstIntValue(await db.rawQuery('PRAGMA foreign_keys;')), 1);
    });

    test('un backup della versione 1 dello schema viene aggiornato con le migrazioni', () async {
      final byte = _zip({
        'manifesto.json': _manifesto(versioneSchema: 1),
        'diario_pesca.db': await databaseVersione(1),
      });

      final contenuto = await servizio.leggi(byte);
      expect(contenuto.versioneSchema, 1);
      expect(contenuto.divieti, 0);

      await servizio.ripristina(contenuto);

      final db = await dbHelper.database;
      expect(Sqflite.firstIntValue(await db.rawQuery('PRAGMA user_version;')), DatabaseHelper.versioneSchema);
      expect(await territorio.getDivieti(), isEmpty);
      await territorio.salvaDivieto(_divieto('Divieto vasca'));
      expect(await territorio.getDivieti(), hasLength(1));
    });

    test('se il database del backup non si apre, i dati attuali restano', () async {
      await territorio.salvaDivieto(_divieto('Divieto vasca'));
      // Un database di una versione più recente dell'app: l'apertura fallisce.
      final contenuto = ContenutoBackup(
        creatoIl: oggi,
        versioneSchema: 99,
        spot: 0,
        divieti: 0,
        pescate: 0,
        catture: 0,
        database: await databaseVersione(99, daFotografia: false),
      );

      await expectLater(servizio.ripristina(contenuto), throwsA(anything));

      expect((await territorio.getDivieti()).map((d) => d.nome), ['Divieto vasca']);
      expect(File('${await dbHelper.percorsoFile()}.prima_del_ripristino').existsSync(), isFalse);
    });

    test('le foto vengono salvate nel backup e ripristinate al loro posto', () async {
      final foto = Directory(p.join(cartella.path, 'foto'))..createSync();
      File(p.join(foto.path, 'pescate', '1.jpg'))
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      servizio = BackupService(dbHelper: dbHelper, orologio: () => oggi, cartellaFoto: () async => foto);

      final contenuto = await servizio.leggi(await servizio.crea());
      expect(contenuto.foto.keys, ['pescate/1.jpg']);

      // Dopo il backup: una foto cambiata e una nuova.
      File(p.join(foto.path, 'pescate', '1.jpg')).writeAsBytesSync([9]);
      File(p.join(foto.path, 'nuova.jpg')).writeAsBytesSync([7]);

      await servizio.ripristina(contenuto);

      final presenti = foto
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => p.relative(f.path, from: foto.path).replaceAll(r'\', '/'))
          .toList();
      expect(presenti, ['pescate/1.jpg']);
      expect(File(p.join(foto.path, 'pescate', '1.jpg')).readAsBytesSync(), [1, 2, 3]);
    });
  });

  group('BackupService - File non validi', () {
    test('un file che non è uno ZIP', () async {
      await siAspettaNonValido(Uint8List.fromList(utf8.encode('non sono uno zip')), 'non è un backup');
    });

    test('uno ZIP senza manifesto o senza database', () async {
      await siAspettaNonValido(
        _zip({'diario_pesca.db': await databaseVersione(DatabaseHelper.versioneSchema)}),
        'non è un backup',
      );
      await siAspettaNonValido(_zip({'manifesto.json': _manifesto()}), 'non è un backup');
    });

    test('un manifesto di un altro formato', () async {
      await siAspettaNonValido(
        _zip({
          'manifesto.json': _manifesto(formato: 'altro-formato'),
          'diario_pesca.db': await databaseVersione(DatabaseHelper.versioneSchema),
        }),
        'non è un backup',
      );
    });

    test('un backup di una versione più recente del formato o dello schema', () async {
      await siAspettaNonValido(
        _zip({
          'manifesto.json': _manifesto(versioneFormato: BackupService.versioneFormato + 1),
          'diario_pesca.db': await databaseVersione(DatabaseHelper.versioneSchema),
        }),
        'versione più recente',
      );
      await siAspettaNonValido(
        _zip({
          'manifesto.json': _manifesto(),
          'diario_pesca.db': await databaseVersione(DatabaseHelper.versioneSchema + 1, daFotografia: false),
        }),
        'versione più recente',
      );
    });

    test('un database danneggiato', () async {
      final buono = await databaseVersione(DatabaseHelper.versioneSchema);
      // Intestazione SQLite intatta, resto del file sovrascritto.
      final rovinato = Uint8List.fromList(buono)..fillRange(100, buono.length, 0x5A);
      await siAspettaNonValido(
        _zip({'manifesto.json': _manifesto(), 'diario_pesca.db': rovinato}),
        'danneggiato',
      );
    });

    test('una foto con un percorso che esce dalla cartella', () async {
      await siAspettaNonValido(
        _zip({
          'manifesto.json': _manifesto(),
          'diario_pesca.db': await databaseVersione(DatabaseHelper.versioneSchema),
          'foto/../../fuori.jpg': [1],
        }),
        'non è un backup',
      );
    });
  });
}
