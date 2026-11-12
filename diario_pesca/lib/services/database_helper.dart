import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const String _nomeFile = 'diario_pesca.db';

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_nomeFile);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onConfigure: onConfigure,
      onCreate: onCreate,
    );
  }

  // Pubblici e statici perché i test li riusano su un database in memoria.
  /// Attiva i vincoli di chiave esterna (in SQLite sono spenti di default).
  static Future<void> onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  /// Crea lo schema. Nei CHECK un valore NULL passa sempre: i campi
  /// facoltativi restano facoltativi.
  static Future<void> onCreate(Database db, int version) async {
    // 1. Categoria
    await db.execute('''
      CREATE TABLE Categoria (
        nome TEXT NOT NULL PRIMARY KEY,
        note TEXT,
        CHECK (length(trim(nome)) > 0)
      );
    ''');

    // 2. Spot
    await db.execute('''
      CREATE TABLE Spot (
        nome TEXT NOT NULL PRIMARY KEY,
        ambiente TEXT NOT NULL,
        lunghezzaMetri REAL,
        voto INTEGER,
        difficolta TEXT,
        esposizioneSole TEXT,
        noteOstacoli TEXT,
        note TEXT,
        battuto INTEGER NOT NULL DEFAULT 0,
        linkParcheggio TEXT,
        categoria_nome TEXT,
        FOREIGN KEY (categoria_nome) REFERENCES Categoria (nome) ON DELETE RESTRICT ON UPDATE CASCADE,
        CHECK (length(trim(nome)) > 0),
        CHECK (length(trim(ambiente)) > 0),
        CHECK (lunghezzaMetri > 0),
        CHECK (voto BETWEEN 0 AND 10),
        CHECK (difficolta IN ('bassa', 'media', 'alta')),
        CHECK (battuto IN (0, 1))
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
        CHECK (fasciaOraria IN ('mattina', 'pomeriggio', 'sera', 'notte'))
    );
''');

    // 5. Pescata
    await db.execute('''
      CREATE TABLE Pescata (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        fasciaOraria TEXT NOT NULL,
        meteo TEXT NOT NULL,
        trasparenza TEXT,
        fondo TEXT,
        livello TEXT,
        temp_acqua REAL,
        temp_aria REAL,
        note TEXT,
        spot_nome TEXT,
        FOREIGN KEY (spot_nome) REFERENCES Spot (nome) ON DELETE SET NULL ON UPDATE CASCADE,
        CHECK (data GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(data, '+0 days') IS data),
        CHECK (fasciaOraria IN ('alba','mattina', 'pomeriggio', 'tramonto', 'sera', 'notte')),
        CHECK (meteo IN ('sereno', 'coperto', 'velato', 'variabile', 'plumbeo', 'pioggia', 'ventoso')),
        CHECK (trasparenza IN ('sporca', 'velata', 'chiara')),
        CHECK (fondo IN ('scuro', 'normale', 'pulito')),
        CHECK (livello IN ('secca', 'magra', 'normale', 'morbida', 'piena')),
        CHECK (temp_acqua BETWEEN 0 AND 35),
        CHECK (temp_aria BETWEEN -30 AND 45)
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

    // 10. Foto (con vincolo CHECK XOR per esclusività tra Pescata e CatturaMemorabile)
    await db.execute('''
      CREATE TABLE Foto (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        percorso TEXT NOT NULL,
        percorsoThumbnail TEXT NOT NULL,
        pescata_id INTEGER,
        cattura_memorabile_id INTEGER,
        FOREIGN KEY (pescata_id) REFERENCES Pescata (id) ON DELETE CASCADE,
        FOREIGN KEY (cattura_memorabile_id) REFERENCES CatturaMemorabile (id) ON DELETE CASCADE,
        CHECK (
          (pescata_id IS NOT NULL AND cattura_memorabile_id IS NULL) OR
          (pescata_id IS NULL AND cattura_memorabile_id IS NOT NULL)
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
    await db.execute('CREATE INDEX idx_pescata_data ON Pescata (data);');
    await db.execute('CREATE INDEX idx_pescata_spot ON Pescata (spot_nome);');
    await db.execute('CREATE INDEX idx_pianificazione_spot ON Pianificazione (spot_nome);');
    await db.execute('CREATE INDEX idx_pescata_esca_esca ON Pescata_Esca (esca_id);');
    await db.execute('CREATE INDEX idx_cattura_pescata ON CatturaMemorabile (pescata_id);');
    await db.execute('CREATE INDEX idx_cattura_specie ON CatturaMemorabile (specie_nome);');
    await db.execute('CREATE INDEX idx_cattura_esca ON CatturaMemorabile (esca_id);');
    await db.execute('CREATE INDEX idx_foto_pescata ON Foto (pescata_id);');
    await db.execute('CREATE INDEX idx_foto_cattura ON Foto (cattura_memorabile_id);');
    await db.execute('CREATE INDEX idx_riepilogo_specie ON RiepilogoSpecie (specie_nome);');
    await db.execute('CREATE INDEX idx_cattcar_caratteristica ON Cattura_Caratteristica (caratteristica_id);');
    await db.execute('CREATE INDEX idx_dettaglio_caratteristica ON DettaglioRiepilogo (caratteristica_id);');
    await db.execute('CREATE INDEX idx_obiettivo_anno ON Obiettivo (anno);');
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
  /// apertura viene ricreato con lo schema aggiornato.
  Future<void> resetPerSviluppo() async {
    await close();
    final path = join(await getDatabasesPath(), _nomeFile);
    await deleteDatabase(path);
  }
}