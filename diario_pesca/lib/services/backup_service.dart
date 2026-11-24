import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../data/database_helper.dart';

/// Il file scelto non si può ripristinare. [messaggio] è già in parole per
/// l'utente.
class BackupNonValido implements Exception {
  const BackupNonValido(this.messaggio);

  final String messaggio;

  @override
  String toString() => messaggio;
}

/// Contenuto di un backup già controllato da [BackupService.leggi]: i dati
/// per il riepilogo da mostrare prima del ripristino e i file da ripristinare.
class ContenutoBackup {
  const ContenutoBackup({
    required this.creatoIl,
    required this.versioneSchema,
    required this.spot,
    required this.divieti,
    required this.pescate,
    required this.catture,
    required this.database,
    this.foto = const {},
  });

  final DateTime creatoIl;

  /// Versione dello schema del database nel backup; se è precedente a quella
  /// dell'app, il ripristino applica le migrazioni.
  final int versioneSchema;

  final int spot;
  final int divieti;
  final int pescate;

  /// Somma dei pesci catturati in tutte le pescate.
  final int catture;

  /// File del database SQLite.
  final Uint8List database;

  /// File delle foto, per percorso relativo alla cartella delle foto.
  final Map<String, Uint8List> foto;
}

/// Backup e ripristino di tutti i dati dell'app (REQ-FUN-14, REQ-FUN-15).
///
/// Il backup è un archivio ZIP con tre parti:
/// * `manifesto.json`: formato, versione del formato, data di creazione e
///   versione dello schema del database;
/// * `diario_pesca.db`: una copia coerente del database SQLite, fatta con
///   `VACUUM INTO` mentre l'app è aperta;
/// * `foto/…`: i file delle foto, con lo stesso percorso relativo che il
///   database registra (REQ-DES-03).
///
/// Il servizio produce e legge solo byte: dove salvare il file e da dove
/// sceglierlo lo decide l'interfaccia (la finestra di sistema di Android, che
/// permette di salvarlo anche su Google Drive). Vedi
/// `docs/scelta_architetturale_backup_e_ripristino.md`.
class BackupService {
  BackupService({
    required this.dbHelper,
    this.cartellaFoto = _nessunaCartellaFoto,
    this.orologio = DateTime.now,
    this.usaVacuumInto = true,
  });

  final DatabaseHelper dbHelper;

  /// Cartella delle foto dell'app, `null` finché le foto non sono gestite
  /// (arriverà con `FotoService`).
  final Future<Directory?> Function() cartellaFoto;

  final DateTime Function() orologio;

  /// `false` solo nei test, per provare la copia di riserva usata sui
  /// telefoni con una versione di SQLite precedente alla 3.27.
  final bool usaVacuumInto;

  static const String formato = 'diario-pesca-backup';
  static const int versioneFormato = 1;

  static const String _manifesto = 'manifesto.json';
  static const String _database = 'diario_pesca.db';
  static const String _prefissoFoto = 'foto/';

  static const _nonEUnBackup = BackupNonValido('Il file scelto non è un backup del Diario di pesca.');
  static const _piuRecente = BackupNonValido(
    'Il backup è stato creato da una versione più recente dell\'app: '
    'aggiorna l\'app prima di ripristinarlo.',
  );

  static Future<Directory?> _nessunaCartellaFoto() async => null;

  /// Nome proposto per il file, per esempio
  /// `diario_pesca_backup_2026-11-24_1050.zip`.
  String nomeFile() {
    final adesso = orologio();
    String due(int n) => n.toString().padLeft(2, '0');
    return 'diario_pesca_backup_${adesso.year}-${due(adesso.month)}-${due(adesso.day)}'
        '_${due(adesso.hour)}${due(adesso.minute)}.zip';
  }

  /// Crea il backup e ne restituisce i byte, pronti da salvare in un file.
  Future<Uint8List> crea() async {
    final temporanea = await Directory.systemTemp.createTemp('diario_pesca_backup_');
    try {
      final copia = p.join(temporanea.path, _database);
      final versioneSchema = await _copiaDatabase(copia);
      final datiDatabase = await File(copia).readAsBytes();

      final manifesto = utf8.encode(jsonEncode({
        'formato': formato,
        'versioneFormato': versioneFormato,
        'creatoIl': orologio().toIso8601String(),
        'versioneSchema': versioneSchema,
      }));

      final archivio = Archive()
        ..addFile(ArchiveFile(_manifesto, manifesto.length, manifesto))
        ..addFile(ArchiveFile(_database, datiDatabase.length, datiDatabase));

      final cartella = await cartellaFoto();
      if (cartella != null && await cartella.exists()) {
        await for (final elemento in cartella.list(recursive: true)) {
          if (elemento is! File) continue;
          final relativo = p.relative(elemento.path, from: cartella.path).replaceAll(r'\', '/');
          final dati = await elemento.readAsBytes();
          archivio.addFile(ArchiveFile('$_prefissoFoto$relativo', dati.length, dati));
        }
      }

      return ZipEncoder().encodeBytes(archivio);
    } finally {
      await _elimina(temporanea);
    }
  }

  /// Copia il database aperto nel file [destinazione] e restituisce la
  /// versione del suo schema.
  ///
  /// `VACUUM INTO` (SQLite 3.27 e successive, Android 11 e successivi) scrive
  /// una copia coerente e compatta anche con il database aperto. Sulle
  /// versioni precedenti si copia il file, dopo aver riversato nel database
  /// le modifiche ancora nel file WAL: durante il backup l'app non scrive.
  Future<int> _copiaDatabase(String destinazione) async {
    final db = await dbHelper.database;
    final versione = Sqflite.firstIntValue(await db.rawQuery('PRAGMA user_version;')) ?? 0;

    if (usaVacuumInto) {
      try {
        await db.execute("VACUUM INTO '${destinazione.replaceAll("'", "''")}';");
        return versione;
      } on DatabaseException {
        final parziale = File(destinazione);
        if (await parziale.exists()) await parziale.delete();
      }
    }
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
    await File(await dbHelper.percorsoFile()).copy(destinazione);
    return versione;
  }

  /// Controlla il file scelto dall'utente senza toccare i dati dell'app.
  /// Lancia [BackupNonValido] se non è un backup, se è danneggiato o se viene
  /// da una versione dell'app più recente di questa.
  Future<ContenutoBackup> leggi(Uint8List byte) async {
    final Archive archivio;
    try {
      archivio = ZipDecoder().decodeBytes(byte);
    } catch (_) {
      throw _nonEUnBackup;
    }

    final fileManifesto = archivio.findFile(_manifesto);
    final fileDatabase = archivio.findFile(_database);
    if (fileManifesto == null || fileDatabase == null) throw _nonEUnBackup;

    final Map<String, Object?> manifesto;
    try {
      manifesto = jsonDecode(utf8.decode(_contenuto(fileManifesto))) as Map<String, Object?>;
    } catch (_) {
      throw _nonEUnBackup;
    }
    final versioneDelFormato = manifesto['versioneFormato'];
    final creatoIl = DateTime.tryParse(manifesto['creatoIl'] as String? ?? '');
    if (manifesto['formato'] != formato || versioneDelFormato is! int || creatoIl == null) {
      throw _nonEUnBackup;
    }
    if (versioneDelFormato > versioneFormato) throw _piuRecente;

    final foto = <String, Uint8List>{};
    for (final elemento in archivio.files) {
      if (!elemento.isFile || !elemento.name.startsWith(_prefissoFoto)) continue;
      final relativo = elemento.name.substring(_prefissoFoto.length);
      if (!_percorsoSicuro(relativo)) throw _nonEUnBackup;
      foto[relativo] = _contenuto(elemento);
    }

    final database = _contenuto(fileDatabase);
    final riepilogo = await _esaminaDatabase(database);

    return ContenutoBackup(
      creatoIl: creatoIl,
      versioneSchema: riepilogo.versione,
      spot: riepilogo.spot,
      divieti: riepilogo.divieti,
      pescate: riepilogo.pescate,
      catture: riepilogo.catture,
      database: database,
      foto: foto,
    );
  }

  /// Apre una copia temporanea del database del backup per controllarne
  /// l'integrità e contare cosa contiene.
  Future<({int versione, int spot, int divieti, int pescate, int catture})> _esaminaDatabase(
    Uint8List database,
  ) async {
    const intestazioneSqlite = 'SQLite format 3\u0000';
    if (database.length < 100 ||
        String.fromCharCodes(database.sublist(0, intestazioneSqlite.length)) != intestazioneSqlite) {
      throw _nonEUnBackup;
    }

    const danneggiato = BackupNonValido('Il database del backup è danneggiato: non si può ripristinare.');
    final temporanea = await Directory.systemTemp.createTemp('diario_pesca_verifica_');
    Database? db;
    try {
      final percorso = p.join(temporanea.path, _database);
      await File(percorso).writeAsBytes(database, flush: true);
      // Senza `version`: nessuna creazione o migrazione, solo lettura.
      db = await openDatabase(percorso, singleInstance: false);

      final integrita = await db.rawQuery('PRAGMA integrity_check;');
      if (integrita.length != 1 || integrita.single.values.first != 'ok') throw danneggiato;

      Future<int> conta(String sql) async => Sqflite.firstIntValue(await db!.rawQuery(sql)) ?? 0;
      final versione = await conta('PRAGMA user_version;');
      if (versione < 1) throw _nonEUnBackup;
      // Prima di contare: lo schema di una versione futura può essere diverso.
      if (versione > DatabaseHelper.versioneSchema) throw _piuRecente;
      return (
        versione: versione,
        spot: await conta('SELECT COUNT(*) FROM Spot;'),
        divieti: versione >= 2 ? await conta('SELECT COUNT(*) FROM Divieto;') : 0,
        pescate: await conta('SELECT COUNT(*) FROM Pescata;'),
        catture: await conta('SELECT COALESCE(SUM(quantita), 0) FROM RiepilogoSpecie;'),
      );
    } on BackupNonValido {
      rethrow;
    } on DatabaseException {
      throw danneggiato;
    } finally {
      await db?.close();
      await _elimina(temporanea);
    }
  }

  /// Sostituisce tutti i dati dell'app con quelli del backup. Se il database
  /// del backup non si apre, i dati attuali restano come erano (vedi
  /// [DatabaseHelper.sostituisciCon]).
  Future<void> ripristina(ContenutoBackup contenuto) async {
    final temporanea = await Directory.systemTemp.createTemp('diario_pesca_ripristino_');
    try {
      final percorso = p.join(temporanea.path, _database);
      await File(percorso).writeAsBytes(contenuto.database, flush: true);
      await dbHelper.sostituisciCon(percorso);

      final cartella = await cartellaFoto();
      if (cartella != null) {
        if (await cartella.exists()) await cartella.delete(recursive: true);
        await cartella.create(recursive: true);
        for (final MapEntry(key: relativo, value: dati) in contenuto.foto.entries) {
          final file = File(p.joinAll([cartella.path, ...relativo.split('/')]));
          await file.parent.create(recursive: true);
          await file.writeAsBytes(dati, flush: true);
        }
      }
    } finally {
      await _elimina(temporanea);
    }
  }

  /// Un percorso dentro l'archivio non deve poter uscire dalla cartella delle
  /// foto (`../`) né essere assoluto.
  static bool _percorsoSicuro(String relativo) {
    if (relativo.isEmpty || relativo.startsWith('/') || relativo.contains(r'\') || relativo.contains(':')) {
      return false;
    }
    return relativo.split('/').every((parte) => parte.isNotEmpty && parte != '.' && parte != '..');
  }

  static Uint8List _contenuto(ArchiveFile file) {
    final Object? contenuto = file.content;
    if (contenuto is Uint8List) return contenuto;
    if (contenuto is List<int>) return Uint8List.fromList(contenuto);
    throw _nonEUnBackup;
  }

  static Future<void> _elimina(Directory cartella) async {
    try {
      if (await cartella.exists()) await cartella.delete(recursive: true);
    } on FileSystemException {
      // Cartella temporanea: se ora non si cancella, la ripulirà il sistema.
    }
  }
}
