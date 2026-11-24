import 'dart:typed_data';

import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/services/backup_service.dart';
import 'package:diario_pesca/ui/screens/backup_screen.dart';
import 'package:diario_pesca/ui/state/dipendenze.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _oggi = DateTime(2026, 11, 24, 10, 50);

/// Contenuto di fantasia di un backup già controllato.
final _contenuto = ContenutoBackup(
  creatoIl: DateTime(2026, 11, 20, 8, 15),
  versioneSchema: DatabaseHelper.versioneSchema,
  spot: 12,
  divieti: 3,
  pescate: 40,
  catture: 95,
  database: Uint8List(0),
);

/// Servizio finto: la schermata si prova senza file né database.
class _ServizioFinto extends BackupService {
  _ServizioFinto({this.problema, this.erroreRipristino}) : super(dbHelper: DatabaseHelper.inMemory());

  final BackupNonValido? problema;
  final Object? erroreRipristino;
  int ripristini = 0;

  @override
  String nomeFile() => 'diario_pesca_backup_2026-11-24_1050.zip';

  @override
  Future<Uint8List> crea() async => Uint8List.fromList([1, 2, 3]);

  @override
  Future<ContenutoBackup> leggi(Uint8List byte) async {
    if (problema != null) throw problema!;
    return _contenuto;
  }

  @override
  Future<void> ripristina(ContenutoBackup contenuto) async {
    ripristini++;
    if (erroreRipristino != null) throw erroreRipristino!;
  }
}

void main() {
  late List<String> salvati;

  Future<void> apri(
    WidgetTester tester,
    _ServizioFinto servizio, {
    bool salvataggioAnnullato = false,
  }) async {
    tester.view
      ..physicalSize = const Size(900, 1800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    salvati = [];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        backupServiceProvider.overrideWithValue(servizio),
        orologioProvider.overrideWithValue(() => _oggi),
      ],
      retry: (tentativo, errore) => null,
      child: MaterialApp(
        home: BackupScreen(
          salvaFile: (nome, byte) async {
            if (salvataggioAnnullato) return false;
            salvati.add(nome);
            return true;
          },
          scegliFile: () async => Uint8List.fromList([4, 5, 6]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('BackupScreen - Backup', () {
    testWidgets('crea il backup, lo fa salvare e mostra data e ora', (tester) async {
      await apri(tester, _ServizioFinto());

      await tester.tap(find.text('Crea backup'));
      await tester.pumpAndSettle();

      expect(salvati, ['diario_pesca_backup_2026-11-24_1050.zip']);
      expect(find.text('Backup salvato il 24/11/2026 alle 10:50.'), findsOneWidget);
    });

    testWidgets('se l\'utente annulla il salvataggio non dice che è salvato', (tester) async {
      await apri(tester, _ServizioFinto(), salvataggioAnnullato: true);

      await tester.tap(find.text('Crea backup'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Backup salvato'), findsNothing);
    });
  });

  group('BackupScreen - Ripristino', () {
    testWidgets('mostra il riepilogo e ripristina solo dopo la conferma', (tester) async {
      final servizio = _ServizioFinto();
      await apri(tester, servizio);

      await tester.tap(find.text('Scegli un backup'));
      await tester.pumpAndSettle();

      expect(find.text('Backup del 20/11/2026 alle 08:15'), findsOneWidget);
      expect(find.text('12 spot, 3 divieti'), findsOneWidget);
      expect(find.text('40 pescate, 95 catture'), findsOneWidget);

      await tester.tap(find.text('Ripristina'));
      await tester.pumpAndSettle();
      expect(find.text('Sostituire tutti i dati?'), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(servizio.ripristini, 0);

      await tester.tap(find.text('Ripristina'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sostituisci'));
      await tester.pumpAndSettle();

      expect(servizio.ripristini, 1);
      expect(find.text('Ripristino completato'), findsOneWidget);
      expect(find.text('Fine'), findsOneWidget);
      // Dopo il ripristino non si può ripartire da qui.
      expect(find.text('Ripristina'), findsNothing);
    });

    testWidgets('un file non valido mostra il problema in parole', (tester) async {
      await apri(
        tester,
        _ServizioFinto(problema: const BackupNonValido('Il file scelto non è un backup del Diario di pesca.')),
      );

      await tester.tap(find.text('Scegli un backup'));
      await tester.pumpAndSettle();

      expect(find.text('Il file scelto non è un backup del Diario di pesca.'), findsOneWidget);
      expect(find.text('Ripristina'), findsNothing);
    });

    testWidgets('un ripristino fallito dice che i dati sono rimasti quelli di prima', (tester) async {
      await apri(tester, _ServizioFinto(erroreRipristino: StateError('apertura fallita')));

      await tester.tap(find.text('Scegli un backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ripristina'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sostituisci'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ripristino non riuscito'), findsOneWidget);
      expect(find.text('I dati dell\'app sono rimasti quelli di prima.'), findsOneWidget);
      expect(find.text('Ripristino completato'), findsNothing);
    });
  });
}
