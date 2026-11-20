import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ui/screens/elenco_spot_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    ProviderScope(
      // Nessun nuovo tentativo automatico dopo un errore: un errore del
      // database non si risolve riprovando, il meteo gestisce già i propri
      // errori e l'utente ha il pulsante "Riprova" (vedi
      // docs/scelta_architetturale_gestione_dello_stato.md).
      retry: (tentativo, errore) => null,
      child: const DiarioPescaApp(),
    ),
  );
}

class DiarioPescaApp extends StatelessWidget {
  const DiarioPescaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diario di Pesca',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const ElencoSpotScreen(),
    );
  }
}
