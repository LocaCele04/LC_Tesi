import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('diario_pesca.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        // Attiva l'integrità dei vincoli di Chiave Esterna (Foreign Key)
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Categoria
    await db.execute('''
      CREATE TABLE Categoria (
        nome TEXT PRIMARY KEY,
        note TEXT
      );
    ''');

    // 2. Spot
    await db.execute('''
      CREATE TABLE Spot (
        nome TEXT PRIMARY KEY,
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
        FOREIGN KEY (categoria_nome) REFERENCES Categoria (nome) ON DELETE RESTRICT ON UPDATE CASCADE
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
        FOREIGN KEY (spot_nome) REFERENCES Spot (nome) ON DELETE CASCADE ON UPDATE CASCADE
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
        FOREIGN KEY (spot_nome) REFERENCES Spot (nome) ON DELETE CASCADE ON UPDATE CASCADE
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
        FOREIGN KEY (spot_nome) REFERENCES Spot (nome) ON DELETE SET NULL ON UPDATE CASCADE
      );
    ''');

    // 6. Esca
    await db.execute('''
      CREATE TABLE Esca (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        descrizione TEXT
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
        nome TEXT PRIMARY KEY,
        informazioni TEXT
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
        FOREIGN KEY (esca_id) REFERENCES Esca (id) ON DELETE SET NULL
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
    await db.execute('''
      CREATE TABLE RiepilogoSpecie (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pescata_id INTEGER NOT NULL,
        specie_nome TEXT NOT NULL,
        quantita INTEGER NOT NULL,
        FOREIGN KEY (pescata_id) REFERENCES Pescata (id) ON DELETE CASCADE,
        FOREIGN KEY (specie_nome) REFERENCES Specie (nome) ON DELETE RESTRICT ON UPDATE CASCADE,
        UNIQUE (pescata_id, specie_nome)
    );
    ''');

    // 12. Caratteristica
    await db.execute('''
      CREATE TABLE Caratteristica (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        specie_nome TEXT NOT NULL,
        nome TEXT NOT NULL,
        descrizione TEXT,
        FOREIGN KEY (specie_nome) REFERENCES Specie (nome) ON DELETE CASCADE ON UPDATE CASCADE,
        UNIQUE (specie_nome, nome)
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
        FOREIGN KEY (caratteristica_id, specie_nome) REFERENCES Caratteristica (id, specie_nome) ON DELETE CASCADE ON UPDATE CASCADE
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
        FOREIGN KEY (caratteristica_id, specie_nome) REFERENCES Caratteristica (id, specie_nome) ON DELETE CASCADE ON UPDATE CASCADE
     );
    ''');
  }

  // Metodo di utility per chiudere la connessione
  Future close() async {
    final db = await instance.database;
    db.close();
    db = null;
  }
}