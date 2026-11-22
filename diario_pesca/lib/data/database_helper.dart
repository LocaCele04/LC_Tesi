import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'migrazioni.dart';

/// Per copiare il database dal telefono al PC e aprirlo con DBeaver usare
/// `scriptCopiaDB.bat` nella cartella `diario_pesca`: chiude l'app, estrae il
/// file con adb e lo copia accanto allo script.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static const String _nomeFile = 'diario_pesca.db';

  final bool _inMemory;
  Database? _database;

  DatabaseHelper._init() : _inMemory = false;

  /// Istanza isolata in RAM per i test automatici.
  DatabaseHelper.inMemory() : _inMemory = true;

  /// Istanza che avvolge un Database già aperto dall'esterno.
  DatabaseHelper.fromDatabase(Database db)
      : _inMemory = true,
        _database = db;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_nomeFile);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (_inMemory) return apri(inMemoryDatabasePath, singleInstance: false);
    return apri(join(await getDatabasesPath(), filePath));
  }

  /// Versione attuale dello schema. Va alzata di 1 a ogni modifica di
  /// [onCreate], aggiungendo in `migrazioni.dart` il passaggio che porta un
  /// database della versione precedente a quella nuova (vedi
  /// `docs/scelta_architetturale_migrazioni_del_database.md`).
  static const int versioneSchema = 1;

  /// Apre (o crea) il database in [percorso] e lo porta alla [versione]:
  /// un database nuovo viene creato da [onCreate], uno di una versione
  /// precedente viene aggiornato con i [passaggi] mancanti.
  ///
  /// [versione] e [passaggi] si cambiano solo nei test delle migrazioni.
  static Future<Database> apri(
    String percorso, {
    bool singleInstance = true,
    int versione = versioneSchema,
    Map<int, Migrazione> passaggi = migrazioni,
  }) {
    return openDatabase(
      percorso,
      version: versione,
      singleInstance: singleInstance,
      onConfigure: onConfigure,
      onCreate: onCreate,
      onUpgrade: (db, da, a) => aggiornaSchema(db, da, a, passaggi: passaggi),
      onDowngrade: onDowngrade,
      onOpen: onOpen,
    );
  }

  // Pubblici e statici perché i test li riusano.

  /// Prima di creare o aggiornare lo schema le chiavi esterne restano
  /// spente. Creazione e aggiornamento avvengono in una transazione, dove
  /// SQLite non permette di cambiare `foreign_keys`; ricostruire una tabella
  /// con le chiavi esterne attive farebbe partire le azioni a cascata
  /// (cancellare la tabella vecchia cancellerebbe, per esempio, le coordinate
  /// di tutti gli spot). Le chiavi esterne si accendono in [onOpen].
  static Future<void> onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF;');
  }

  /// Attiva i vincoli di chiave esterna (in SQLite sono spenti di default),
  /// dopo che creazione o aggiornamento dello schema sono terminati.
  static Future<void> onOpen(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  /// Applica in ordine i passaggi da [da] + 1 fino ad [a] e controlla che
  /// alla fine nessuna riga violi le chiavi esterne (durante i passaggi sono
  /// spente). Un errore annulla l'intero aggiornamento: sqflite esegue
  /// `onUpgrade` in una transazione, quindi il database resta alla versione
  /// [da] con i dati intatti.
  static Future<void> aggiornaSchema(
    DatabaseExecutor db,
    int da,
    int a, {
    Map<int, Migrazione> passaggi = migrazioni,
  }) async {
    for (var versione = da + 1; versione <= a; versione++) {
      final passaggio = passaggi[versione];
      if (passaggio == null) {
        throw StateError('Manca la migrazione alla versione $versione dello schema.');
      }
      await passaggio(db);
    }
    final violazioni = await db.rawQuery('PRAGMA foreign_key_check;');
    if (violazioni.isNotEmpty) {
      throw StateError(
        'Dopo l\'aggiornamento alla versione $a, ${violazioni.length} righe '
        'violano le chiavi esterne: $violazioni',
      );
    }
  }

  /// Un database più recente dell'app (per esempio dopo aver reinstallato
  /// una versione vecchia) non viene toccato: l'apertura fallisce.
  static Future<void> onDowngrade(Database db, int da, int a) async {
    throw StateError(
      'Il database è alla versione $da dello schema, più recente di quella '
      'di questa app ($a): installa la versione più recente dell\'app.',
    );
  }

  /// Ambienti presenti alla prima apertura; l'utente può aggiungerne altri.
  static const List<String> ambientiDiBase = ['Torrente', 'Fiume', 'Lago', 'Mare'];

  /// Condizioni presenti alla prima apertura, con i valori nell'ordine della
  /// loro scala. L'utente può modificarle, disattivarle o aggiungerne altre.
  static const Map<String, List<String>> condizioniDiBase = {
    'Livello': ['Secca', 'Magra', 'Normale', 'Morbida', 'Piena'],
    'Trasparenza': ['Sporca', 'Velata', 'Chiara'],
    'Fondo': ['Scuro', 'Normale', 'Pulito'],
    'Meteo': [
      'Sereno',
      'Velato',
      'Variabile',
      'Coperto',
      'Plumbeo',
      'Pioggia',
      'Ventoso',
    ],
  };

  /// Ambienti a cui sono collegate le condizioni di base.
  static const Map<String, List<String>> ambientiCondizioniDiBase = {
    'Livello': ['Torrente', 'Fiume'],
    'Trasparenza': ['Torrente', 'Fiume'],
    'Fondo': ['Torrente', 'Fiume'],
    'Meteo': ambientiDiBase,
  };

  /// Crea lo schema completo dell'ultima versione ([versioneSchema]) su un
  /// database nuovo. Nei CHECK un valore NULL passa sempre: i campi
  /// facoltativi restano facoltativi.
  ///
  /// Ogni modifica a questo metodo richiede una migrazione (vedi
  /// [versioneSchema]); il test `migrazioni_test.dart` fallisce se lo schema
  /// cambia senza.
  static Future<void> onCreate(Database db, int version) async {
    // 1. Categoria
    await db.execute('''
      CREATE TABLE Categoria (
        nome TEXT NOT NULL PRIMARY KEY,
        note TEXT,
        CHECK (length(trim(nome)) > 0)
      );
    ''');

    // 1-bis. Ambiente (tabella di dominio estendibile dall'utente)
    // COLLATE NOCASE: 'Torrente' e 'torrente' sono lo stesso ambiente, così
    // non si creano duplicati che differiscono solo per maiuscole/minuscole.
    await db.execute('''
      CREATE TABLE Ambiente (
        nome TEXT NOT NULL PRIMARY KEY COLLATE NOCASE,
        CHECK (length(trim(nome)) > 0)
      );
    ''');
    for (final nome in ambientiDiBase) {
      await db.insert('Ambiente', {'nome': nome});
    }

    // 1-ter. Condizioni personalizzabili (es. Livello, Trasparenza, Meteo)
    // e loro valori ammessi. `ordine` dà la posizione nel form (condizioni)
    // e nella scala (valori: Secca < Magra < ... < Piena).
    // UNIQUE (id, condizione_id) serve alla FK composta di Pescata_Condizione.
    await db.execute('''
      CREATE TABLE Condizione (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL COLLATE NOCASE UNIQUE,
        ordine INTEGER NOT NULL DEFAULT 0,
        attiva INTEGER NOT NULL DEFAULT 1,
        CHECK (length(trim(nome)) > 0),
        CHECK (attiva IN (0, 1))
      );
    ''');
    await db.execute('''
      CREATE TABLE ValoreCondizione (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        condizione_id INTEGER NOT NULL,
        nome TEXT NOT NULL COLLATE NOCASE,
        ordine INTEGER NOT NULL DEFAULT 0,
        attivo INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (condizione_id) REFERENCES Condizione (id) ON DELETE CASCADE,
        UNIQUE (condizione_id, nome),
        UNIQUE (id, condizione_id),
        CHECK (length(trim(nome)) > 0),
        CHECK (attivo IN (0, 1))
      );
    ''');
    // Quali condizioni proporre nel form per ogni ambiente (guida per
    // l'interfaccia, non vincolo sui dati delle pescate).
    await db.execute('''
      CREATE TABLE Ambiente_Condizione (
        ambiente_nome TEXT NOT NULL COLLATE NOCASE,
        condizione_id INTEGER NOT NULL,
        PRIMARY KEY (ambiente_nome, condizione_id),
        FOREIGN KEY (ambiente_nome) REFERENCES Ambiente (nome) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (condizione_id) REFERENCES Condizione (id) ON DELETE CASCADE
      );
    ''');
    await _inserisciCondizioniDiBase(db);

    // 2. Spot
    await db.execute('''
      CREATE TABLE Spot (
        nome TEXT NOT NULL PRIMARY KEY,
        ambiente TEXT NOT NULL COLLATE NOCASE,
        lunghezzaMetri REAL,
        voto REAL,
        difficolta TEXT,
        noteOstacoli TEXT,
        note TEXT,
        battuto INTEGER NOT NULL DEFAULT 0,
        accessibilita TEXT NOT NULL DEFAULT 'accessibile',
        linkParcheggio TEXT,
        categoria_nome TEXT NOT NULL,
        FOREIGN KEY (categoria_nome) REFERENCES Categoria (nome) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (ambiente) REFERENCES Ambiente (nome) ON DELETE RESTRICT ON UPDATE CASCADE,
        CHECK (length(trim(nome)) > 0),
        CHECK (length(trim(ambiente)) > 0),
        CHECK (lunghezzaMetri > 0),
        CHECK (voto BETWEEN 0 AND 10),
        CHECK (difficolta IN ('bassa', 'media', 'alta')),
        CHECK (battuto IN (0, 1)),
        CHECK (accessibilita IN ('accessibile', 'inaccessibile'))
      );
    ''');

    // 3. Coordinata (Chiave primaria composta: spot_nome, ordine)
    await db.execute('''
      CREATE TABLE Coordinata (
        spot_nome TEXT NOT NULL,
        ordine INTEGER NOT NULL,
        latitudine REAL NOT NULL,
        longitudine REAL NOT NULL,
        PRIMARY KEY (spot_nome, ordine),
        FOREIGN KEY (spot_nome) REFERENCES Spot (nome) ON DELETE CASCADE ON UPDATE CASCADE,
        CHECK (ordine >= 0),
        CHECK (latitudine BETWEEN -90 AND 90),
        CHECK (longitudine BETWEEN -180 AND 180)
      );
    ''');

    // 4. Pianificazione
    await db.execute('''
    CREATE TABLE Pianificazione (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        fasciaOraria TEXT NOT NULL,
        note TEXT,
        spot_nome TEXT,
        FOREIGN KEY (spot_nome) REFERENCES Spot (nome) ON DELETE CASCADE ON UPDATE CASCADE,
        CHECK (data GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(data, '+0 days') IS data),
        CHECK (fasciaOraria IN ('alba','mattina', 'pomeriggio', 'tramonto', 'sera', 'notte'))
    );
''');

    // 5. Pescata
    await db.execute('''
      CREATE TABLE Pescata (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        fasciaOraria TEXT NOT NULL,
        temp_acqua REAL,
        note TEXT,
        spot_nome TEXT,
        FOREIGN KEY (spot_nome) REFERENCES Spot (nome) ON DELETE SET NULL ON UPDATE CASCADE,
        CHECK (data GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(data, '+0 days') IS data),
        CHECK (fasciaOraria IN ('alba','mattina', 'pomeriggio', 'tramonto', 'sera', 'notte')),
        CHECK (temp_acqua BETWEEN 0 AND 35)
      );
    ''');

    // 5-bis. Pescata_Condizione: valore scelto per ogni condizione in una
    // pescata (al massimo uno per condizione). La FK composta garantisce che
    // il valore appartenga alla condizione indicata; RESTRICT impedisce di
    // eliminare un valore già usato (va disattivato).
    await db.execute('''
      CREATE TABLE Pescata_Condizione (
        pescata_id INTEGER NOT NULL,
        condizione_id INTEGER NOT NULL,
        valore_id INTEGER NOT NULL,
        PRIMARY KEY (pescata_id, condizione_id),
        FOREIGN KEY (pescata_id) REFERENCES Pescata (id) ON DELETE CASCADE,
        FOREIGN KEY (valore_id, condizione_id) REFERENCES ValoreCondizione (id, condizione_id) ON DELETE RESTRICT
      );
    ''');

    // 5-ter. Archivio meteo (dati scaricati da Open-Meteo).
    // I dati sono organizzati per cella della griglia del modello meteo
    // (~2 km) e per giorno/ora: spot vicini e pescate ravvicinate
    // condividono le stesse righe invece di duplicarle. La quota fa parte
    // della cella perché Open-Meteo corregge le temperature in base alla
    // quota del punto richiesto: due spot nella stessa cella della griglia
    // ma a quote diverse hanno temperature diverse.
    await db.execute('''
      CREATE TABLE CellaMeteo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitudine REAL NOT NULL,
        longitudine REAL NOT NULL,
        elevazione REAL NOT NULL,
        UNIQUE (latitudine, longitudine, elevazione),
        CHECK (latitudine BETWEEN -90 AND 90),
        CHECK (longitudine BETWEEN -180 AND 180)
      );
    ''');
    await db.execute('''
      CREATE TABLE MeteoGiornaliero (
        cella_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        pioggia_mm REAL,
        temp_min REAL,
        temp_max REAL,
        pressione_media REAL,
        vento_max REAL,
        raffica_max REAL,
        direzione_vento INTEGER,
        PRIMARY KEY (cella_id, data),
        FOREIGN KEY (cella_id) REFERENCES CellaMeteo (id) ON DELETE CASCADE,
        CHECK (data GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(data, '+0 days') IS data),
        CHECK (pioggia_mm >= 0),
        CHECK (direzione_vento BETWEEN 0 AND 360)
      );
    ''');
    // `data_ora` è in UTC: in ora locale il cambio dell'ora legale
    // produrrebbe ore ripetute o mancanti.
    await db.execute('''
      CREATE TABLE MeteoOrario (
        cella_id INTEGER NOT NULL,
        data_ora TEXT NOT NULL,
        pioggia_mm REAL,
        temperatura REAL,
        pressione REAL,
        vento REAL,
        raffica REAL,
        direzione_vento INTEGER,
        PRIMARY KEY (cella_id, data_ora),
        FOREIGN KEY (cella_id) REFERENCES CellaMeteo (id) ON DELETE CASCADE,
        CHECK (data_ora GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-2][0-9]:00'),
        CHECK (pioggia_mm >= 0),
        CHECK (direzione_vento BETWEEN 0 AND 360)
      );
    ''');
    // Per ogni pescata scaricata: la cella usata e i dati della richiesta
    // (data della pescata e punto dello spot). Se la pescata cambia data o
    // lo spot cambia il punto di riferimento, la riga non corrisponde più e
    // la pescata torna "da scaricare" (lo stato è calcolato, non salvato).
    await db.execute('''
      CREATE TABLE PescataMeteo (
        pescata_id INTEGER PRIMARY KEY,
        cella_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        latitudine REAL NOT NULL,
        longitudine REAL NOT NULL,
        FOREIGN KEY (pescata_id) REFERENCES Pescata (id) ON DELETE CASCADE,
        FOREIGN KEY (cella_id) REFERENCES CellaMeteo (id) ON DELETE CASCADE,
        CHECK (data GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(data, '+0 days') IS data)
      );
    ''');

    // 6. Esca
    await db.execute('''
      CREATE TABLE Esca (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        descrizione TEXT,
        CHECK (length(trim(nome)) > 0)
      );
    ''');

    // 7. Pescata_Esca (Relazione N:M)
    await db.execute('''
      CREATE TABLE Pescata_Esca (
        pescata_id INTEGER NOT NULL,
        esca_id INTEGER NOT NULL,
        PRIMARY KEY (pescata_id, esca_id),
        FOREIGN KEY (pescata_id) REFERENCES Pescata (id) ON DELETE CASCADE,
        FOREIGN KEY (esca_id) REFERENCES Esca (id) ON DELETE CASCADE
      );
    ''');

    // 8. Specie
    await db.execute('''
      CREATE TABLE Specie (
        nome TEXT NOT NULL PRIMARY KEY,
        informazioni TEXT,
        CHECK (length(trim(nome)) > 0)
      );
    ''');

    // 9. CatturaMemorabile
    await db.execute('''
      CREATE TABLE CatturaMemorabile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descrizione TEXT,
        pescata_id INTEGER NOT NULL,
        specie_nome TEXT NOT NULL,
        esca_id INTEGER,
        FOREIGN KEY (pescata_id) REFERENCES Pescata (id) ON DELETE CASCADE,
        FOREIGN KEY (specie_nome) REFERENCES Specie (nome) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (esca_id) REFERENCES Esca (id) ON DELETE SET NULL,
        UNIQUE (id, specie_nome)
      );
    ''');

    // 10. Foto (con vincolo CHECK XOR: appartiene a una sola tra Pescata, CatturaMemorabile ed Esca)
    await db.execute('''
      CREATE TABLE Foto (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        percorso TEXT NOT NULL,
        percorsoThumbnail TEXT NOT NULL,
        pescata_id INTEGER,
        esca_id INTEGER,
        cattura_memorabile_id INTEGER,
        FOREIGN KEY (pescata_id) REFERENCES Pescata (id) ON DELETE CASCADE,
        FOREIGN KEY (cattura_memorabile_id) REFERENCES CatturaMemorabile (id) ON DELETE CASCADE,
        FOREIGN KEY (esca_id) REFERENCES Esca(id) ON DELETE CASCADE,
        CHECK (
          (pescata_id IS NOT NULL AND cattura_memorabile_id IS NULL AND esca_id IS NULL) OR
          (pescata_id IS NULL AND cattura_memorabile_id IS NOT NULL AND esca_id IS NULL) OR
          (pescata_id IS NULL AND cattura_memorabile_id IS NULL AND esca_id IS NOT NULL)
        )
      );
    ''');

    // 11. RiepilogoSpecie
    /**primo unique serve per evitare di avere riepiloghi della stessa specie nella stessa pescata
       secondo unique serve per controllo incrociato (spiegato sotto) */
    await db.execute('''
      CREATE TABLE RiepilogoSpecie (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pescata_id INTEGER NOT NULL,
        specie_nome TEXT NOT NULL,
        quantita INTEGER NOT NULL,
        FOREIGN KEY (pescata_id) REFERENCES Pescata (id) ON DELETE CASCADE,
        FOREIGN KEY (specie_nome) REFERENCES Specie (nome) ON DELETE RESTRICT ON UPDATE CASCADE,
        UNIQUE (pescata_id, specie_nome),   
        UNIQUE (id, specie_nome),
        CHECK (quantita >= 0)
      );
    ''');

    //unique serve per avere un controllo incrociato nelle tabelle di intermezzo come cattura_caratteristica che hanno bisogno
    //anche della specie altrimenti sarebbe possibile assegnare una caratteristica ad una cattura che non potrebbe averla perchè
    //di specie diversa
    /**Per standard SQL (e in SQLite in particolare), una FOREIGN KEY su due colonne può puntare solo a una coppia di colonne 
    dichiarata esplicitamente come PRIMARY KEY o UNIQUE nella tabella di destinazione. */
    // 12. Caratteristica
    await db.execute('''
      CREATE TABLE Caratteristica (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        specie_nome TEXT NOT NULL,
        nome TEXT NOT NULL,
        descrizione TEXT,
        FOREIGN KEY (specie_nome) REFERENCES Specie (nome) ON DELETE CASCADE ON UPDATE CASCADE,
        UNIQUE (specie_nome, nome),
        UNIQUE (id, specie_nome),
        CHECK (length(trim(nome)) > 0)
      );
    ''');

    // 13. Cattura_Caratteristica (Relazione N:M)
    await db.execute('''
      CREATE TABLE Cattura_Caratteristica (
        cattura_memorabile_id INTEGER NOT NULL,
        caratteristica_id INTEGER NOT NULL,
        specie_nome TEXT NOT NULL,
        PRIMARY KEY (cattura_memorabile_id, caratteristica_id),
        FOREIGN KEY (cattura_memorabile_id, specie_nome) REFERENCES CatturaMemorabile (id, specie_nome) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (caratteristica_id, specie_nome) REFERENCES Caratteristica (id, specie_nome) ON DELETE CASCADE ON UPDATE CASCADE
      );
    ''');

    // 14. Obiettivo
    await db.execute('''
      CREATE TABLE Obiettivo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        specie_nome TEXT NOT NULL,
        anno INTEGER NOT NULL,
        quantita INTEGER NOT NULL,
        caratteristica_id INTEGER,
        FOREIGN KEY (specie_nome) REFERENCES Specie (nome) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (caratteristica_id, specie_nome) REFERENCES Caratteristica (id, specie_nome) ON DELETE CASCADE ON UPDATE CASCADE,
        CHECK (anno BETWEEN 2000 AND 2100),
        CHECK (quantita > 0)
      );
    ''');

    // 15. DettaglioRiepilogo (Relazione N:M)
    await db.execute('''
      CREATE TABLE DettaglioRiepilogo (
        riepilogo_specie_id INTEGER NOT NULL,
        caratteristica_id INTEGER NOT NULL,
        specie_nome TEXT NOT NULL,
        quantita INTEGER NOT NULL,
        PRIMARY KEY (riepilogo_specie_id, caratteristica_id),
        FOREIGN KEY (riepilogo_specie_id, specie_nome) REFERENCES RiepilogoSpecie (id, specie_nome) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (caratteristica_id, specie_nome) REFERENCES Caratteristica (id, specie_nome) ON DELETE CASCADE ON UPDATE CASCADE,
        CHECK (quantita >= 0)
      );
    ''');

    // Indici sulle colonne usate nei filtri e nelle eliminazioni a cascata
    await db.execute('CREATE INDEX idx_spot_categoria ON Spot (categoria_nome);');
    await db.execute('CREATE INDEX idx_spot_ambiente ON Spot (ambiente);');
    await db.execute('CREATE INDEX idx_pescata_data ON Pescata (data);');
    await db.execute('CREATE INDEX idx_pescata_spot ON Pescata (spot_nome);');
    await db.execute('CREATE INDEX idx_pianificazione_spot ON Pianificazione (spot_nome);');
    await db.execute('CREATE INDEX idx_pescata_esca_esca ON Pescata_Esca (esca_id);');
    await db.execute('CREATE INDEX idx_cattura_pescata ON CatturaMemorabile (pescata_id);');
    await db.execute('CREATE INDEX idx_cattura_specie ON CatturaMemorabile (specie_nome);');
    await db.execute('CREATE INDEX idx_cattura_esca ON CatturaMemorabile (esca_id);');
    await db.execute('CREATE INDEX idx_foto_pescata ON Foto (pescata_id);');
    await db.execute('CREATE INDEX idx_foto_esca ON Foto(esca_id);');
    await db.execute('CREATE INDEX idx_foto_cattura ON Foto (cattura_memorabile_id);');
    await db.execute('CREATE INDEX idx_riepilogo_specie ON RiepilogoSpecie (specie_nome);');
    await db.execute('CREATE INDEX idx_cattcar_caratteristica ON Cattura_Caratteristica (caratteristica_id);');
    await db.execute('CREATE INDEX idx_dettaglio_caratteristica ON DettaglioRiepilogo (caratteristica_id);');
    await db.execute('CREATE INDEX idx_obiettivo_anno ON Obiettivo (anno);');
    await db.execute('CREATE INDEX idx_ambcond_condizione ON Ambiente_Condizione (condizione_id);');
    await db.execute('CREATE INDEX idx_pescond_valore ON Pescata_Condizione (valore_id, condizione_id);');
    await db.execute('CREATE INDEX idx_pescatameteo_cella ON PescataMeteo (cella_id);');
  }

  /// Inserisce le condizioni di base con i loro valori e i collegamenti agli
  /// ambienti di base.
  static Future<void> _inserisciCondizioniDiBase(Database db) async {
    var ordineCondizione = 0;
    for (final voce in condizioniDiBase.entries) {
      final condizioneId = await db.insert('Condizione', {
        'nome': voce.key,
        'ordine': ordineCondizione++,
      });
      for (var i = 0; i < voce.value.length; i++) {
        await db.insert('ValoreCondizione', {
          'condizione_id': condizioneId,
          'nome': voce.value[i],
          'ordine': i,
        });
      }
      for (final ambiente in ambientiCondizioniDiBase[voce.key] ?? const <String>[]) {
        await db.insert('Ambiente_Condizione', {
          'ambiente_nome': ambiente,
          'condizione_id': condizioneId,
        });
      }
    }
  }

  /// Chiude la connessione e azzera il riferimento.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// SOLO SVILUPPO: cancella il file del database, così alla prossima
  /// apertura viene ricreato da zero. Con le migrazioni non serve più per
  /// aggiornare lo schema.
  Future<void> resetPerSviluppo() async {
    await close();
    if (!_inMemory) {
      final path = join(await getDatabasesPath(), _nomeFile);
      await deleteDatabase(path);
    }
  }
}