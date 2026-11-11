import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'services/database_helper.dart';

typedef SpecieData = List<Map<String, Object?>>;

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<SpecieData> _caricaSpecieTest() async {
    final db = await DatabaseHelper.instance.database;

    // Inseriamo una specie di prova
    await db.insert(
      'Specie',
      {
        'nome': 'Spigola',
        'informazioni': 'Predatore molto diffuso sia in mare che in acque salmastre.',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // Leggiamo la lista delle specie presenti nel DB
    return await db.query('Specie');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Diario di Pesca - Test Schema DB')),
        body: Center(
          child: FutureBuilder<SpecieData>(
            future: _caricaSpecieTest(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Errore DB: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('Nessuna specie trovata nel database.');
              }

              final specieList = snapshot.data!;
              return ListView.builder(
                itemCount: specieList.length,
                itemBuilder: (context, index) {
                  final specie = specieList[index];
                  return ListTile(
                    leading: const Icon(Icons.set_meal, color: Colors.blue),
                    title: Text(
                      specie['nome'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(specie['informazioni'] as String? ?? ''),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}