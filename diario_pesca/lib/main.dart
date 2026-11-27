import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'ui/screens/home_screen.dart';
import 'ui/state/memoria_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Sezione aperta e vista della mappa dell'ultimo utilizzo.
  final memoria = await MemoriaUiSulTelefono.carica();

  runApp(
    ProviderScope(
      overrides: [memoriaUiProvider.overrideWithValue(memoria)],
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
      // Interfaccia in italiano, anche per i componenti di Flutter
      // (calendario, pulsanti dei dialoghi, menu).
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
