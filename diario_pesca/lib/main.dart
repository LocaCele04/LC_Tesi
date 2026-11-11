import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'services/database_helper.dart';
import 'models/nota.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurazione del database per Web e Desktop (Windows/Mac/Linux)
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

  Future<List<Nota>> _caricaDatiTest() async {
    await DatabaseHelper.instance.insertNota(
      Nota(testo: 'Test SQLite riuscito!'),
    );
    return await DatabaseHelper.instance.getNote();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Test Database SQLite')),
        body: Center(
          child: FutureBuilder<List<Nota>>(
            future: _caricaDatiTest(),
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
                return const Text('Nessun dato trovato.');
              }

              final note = snapshot.data!;
              return ListView.builder(
                itemCount: note.length,
                itemBuilder: (context, index) {
                  final item = note[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${item.id}')),
                    title: Text(item.testo),
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