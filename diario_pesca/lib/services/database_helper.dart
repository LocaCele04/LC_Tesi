import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/nota.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('test_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // openDatabase crea fisicamente il file se non esiste sul dispositivo
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // Creazione della tabella di prova
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE note (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        testo TEXT NOT NULL
      )
    ''');
  }

  // Inserisce una nota
  Future<int> insertNota(Nota nota) async {
    final db = await instance.database;
    return await db.insert('note', nota.toMap());
  }

  // Legge tutte le note
  Future<List<Nota>> getNote() async {
    final db = await instance.database;
    final result = await db.query('note');
    return result.map((json) => Nota.fromMap(json)).toList();
  }
}