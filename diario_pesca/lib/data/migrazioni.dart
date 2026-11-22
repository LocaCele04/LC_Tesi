import 'package:sqflite/sqflite.dart';

/// Un passaggio di aggiornamento dello schema: porta un database dalla
/// versione precedente a quella sotto cui è registrato in [migrazioni].
///
/// Viene eseguito dentro la transazione dell'aggiornamento, con le chiavi
/// esterne spente; al termine `DatabaseHelper.aggiornaSchema` controlla che
/// nessuna riga le violi.
typedef Migrazione = Future<void> Function(DatabaseExecutor db);

/// Passaggi di aggiornamento, indicizzati per **versione di arrivo**: il
/// passaggio `2` porta un database dalla versione 1 alla 2, e così via.
/// Ogni volta che si alza `DatabaseHelper.versioneSchema` qui va aggiunto il
/// passaggio corrispondente, che fa sul database esistente le stesse
/// modifiche fatte in `DatabaseHelper.onCreate`.
///
/// La versione 1 è lo schema di partenza: non ha un passaggio.
///
/// Esempio, aggiungere una colonna:
///
/// ```dart
/// const migrazioni = <int, Migrazione>{
///   2: _versione2,
/// };
///
/// /// Versione 2: lo spot ricorda se il primo punto viene dal GPS.
/// Future<void> _versione2(DatabaseExecutor db) async {
///   await db.execute(
///     'ALTER TABLE Spot ADD COLUMN posizioneDaGps INTEGER NOT NULL DEFAULT 0 '
///     'CHECK (posizioneDaGps IN (0, 1))',
///   );
/// }
/// ```
const Map<int, Migrazione> migrazioni = {};

/// Ricostruisce la tabella [tabella] con la nuova definizione [creaTabella]
/// (lo stesso `CREATE TABLE <tabella> (...)` scritto in `onCreate`),
/// copiando le [colonne] indicate, che devono esistere in entrambe le
/// versioni. Serve per le modifiche che SQLite non sa fare con `ALTER TABLE`:
/// togliere o rinominare una colonna con vincoli, cambiare un CHECK, una
/// chiave esterna o un NOT NULL.
///
/// È la procedura raccomandata da SQLite (crea la nuova tabella, copia i
/// dati, elimina la vecchia, rinomina la nuova), sicura solo con le chiavi
/// esterne spente, come durante le migrazioni: altrimenti eliminare la
/// tabella vecchia farebbe partire le azioni a cascata sulle tabelle figlie.
/// Gli [indici] della tabella vanno ricreati: eliminando la tabella vecchia
/// spariscono anche i suoi.
Future<void> ricostruisciTabella(
  DatabaseExecutor db, {
  required String tabella,
  required String creaTabella,
  required List<String> colonne,
  List<String> indici = const [],
}) async {
  final temporanea = '${tabella}_nuova';
  final intestazione = RegExp('CREATE\\s+TABLE\\s+$tabella\\b');
  if (!intestazione.hasMatch(creaTabella)) {
    throw ArgumentError.value(creaTabella, 'creaTabella', 'non crea la tabella $tabella');
  }
  final elenco = colonne.join(', ');
  await db.execute(creaTabella.replaceFirst(intestazione, 'CREATE TABLE $temporanea'));
  await db.execute('INSERT INTO $temporanea ($elenco) SELECT $elenco FROM $tabella');
  await db.execute('DROP TABLE $tabella');
  await db.execute('ALTER TABLE $temporanea RENAME TO $tabella');
  for (final indice in indici) {
    await db.execute(indice);
  }
}
