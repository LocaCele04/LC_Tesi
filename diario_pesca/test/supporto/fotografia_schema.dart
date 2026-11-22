import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fotografie dello schema per i test delle migrazioni.
///
/// Una fotografia (`test/schemi/schema_vN.json`) contiene le istruzioni
/// `CREATE` di tabelle e indici della versione N, nell'ordine di creazione,
/// e i dati presenti in un database appena creato (ambienti e condizioni di
/// base). Con una fotografia si ricrea un database "installato con la
/// versione N", su cui provare le migrazioni verso le versioni successive.

/// File della fotografia della versione [versione].
File fileFotografia(int versione) => File('test/schemi/schema_v$versione.json');

/// Versioni di cui esiste una fotografia, in ordine crescente.
List<int> versioniFotografate() {
  final cartella = Directory('test/schemi');
  if (!cartella.existsSync()) return const [];
  final versioni = <int>[];
  for (final file in cartella.listSync().whereType<File>()) {
    final m = RegExp(r'schema_v(\d+)\.json$').firstMatch(file.path);
    if (m != null) versioni.add(int.parse(m.group(1)!));
  }
  return versioni..sort();
}

Future<List<Map<String, Object?>>> _oggetti(DatabaseExecutor db) => db.rawQuery(
      "SELECT type, name, sql FROM sqlite_master "
      "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY rowid",
    );

/// Scrive la fotografia di [db], che deve essere alla versione [versione].
Future<void> salvaFotografia(DatabaseExecutor db, int versione) async {
  final oggetti = await _oggetti(db);
  final dati = <String, List<Map<String, Object?>>>{};
  for (final o in oggetti.where((o) => o['type'] == 'table')) {
    final righe = await db.rawQuery('SELECT * FROM "${o['name']}" ORDER BY rowid');
    if (righe.isNotEmpty) dati[o['name'] as String] = righe;
  }
  final file = fileFotografia(versione);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'versione': versione,
    'schema': [
      for (final o in oggetti) {'tipo': o['type'], 'nome': o['name'], 'sql': o['sql']},
    ],
    'dati': dati,
  }));
}

/// Crea in [percorso] un database identico a uno appena installato con la
/// versione [versione], a partire dalla sua fotografia, e lo chiude.
Future<void> creaDaFotografia(String percorso, int versione) async {
  final json = jsonDecode(fileFotografia(versione).readAsStringSync()) as Map<String, Object?>;
  // Senza callback: nessuno schema viene creato, chiavi esterne spente.
  final db = await databaseFactory.openDatabase(
    percorso,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  await db.transaction((txn) async {
    for (final o in (json['schema'] as List).cast<Map<String, Object?>>()) {
      await txn.execute(o['sql'] as String);
    }
    for (final voce in (json['dati'] as Map<String, Object?>).entries) {
      for (final riga in (voce.value as List).cast<Map<String, Object?>>()) {
        await txn.insert(voce.key, riga);
      }
    }
  });
  await db.setVersion(versione);
  await db.close();
}

/// Uno spazio o più (anche a capo) diventano uno solo, e niente spazi
/// accanto a parentesi e virgole; via le virgolette (SQLite le aggiunge
/// al nome di una tabella rinominata); tutto minuscolo.
String _normalizza(String sql) => sql
    .replaceAll('"', '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'\s*([(),])\s*'), r'$1')
    .trim()
    .toLowerCase();

/// Descrizione confrontabile di un database: per ogni tabella e indice la
/// sua istruzione `CREATE` normalizzata, e il contenuto di tutte le tabelle.
/// Due database con la stessa descrizione hanno lo stesso schema (colonne,
/// tipi, vincoli, chiavi esterne, indici) e gli stessi dati.
Future<Map<String, Object?>> descriviDatabase(DatabaseExecutor db) async {
  final oggetti = await _oggetti(db);
  final schema = <String, String>{
    for (final o in oggetti) '${o['type']} ${o['name']}': _normalizza(o['sql'] as String),
  };
  final dati = <String, Object?>{};
  for (final o in oggetti.where((o) => o['type'] == 'table')) {
    final colonne = await db.rawQuery('PRAGMA table_info("${o['name']}")');
    final ordine = [for (var i = 1; i <= colonne.length; i++) i].join(', ');
    // Ordinate per contenuto, non per rowid: una tabella ricostruita può
    // riassegnarlo.
    final righe = await db.rawQuery('SELECT * FROM "${o['name']}" ORDER BY $ordine');
    dati[o['name'] as String] = righe;
  }
  return {'schema': schema, 'dati': dati};
}
