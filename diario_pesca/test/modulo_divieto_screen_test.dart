import 'package:diario_pesca/models/territorio/coordinata.dart';
import 'package:diario_pesca/models/territorio/divieto.dart';
import 'package:diario_pesca/ui/mappa/modulo_divieto_screen.dart';
import 'package:diario_pesca/ui/state/mappa_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// La schermata viene provata senza database: i divieti salvati ed
/// eliminati restano in questo notifier finto.
class _DivietiFinti extends DivietiNotifier {
  final salvati = <Divieto>[];
  final eliminati = <int>[];

  @override
  Future<List<Divieto>> build() async => const [];

  @override
  Future<Divieto> salva(Divieto divieto) async {
    salvati.add(divieto);
    return divieto.copyWith(id: divieto.id ?? 1);
  }

  @override
  Future<void> elimina(int id) async => eliminati.add(id);
}

const _punti = [
  Coordinata(ordine: 0, latitudine: 45.76, longitudine: 9.64),
  Coordinata(ordine: 1, latitudine: 45.77, longitudine: 9.65),
];

void main() {
  late _DivietiFinti divieti;

  // Il modulo si apre da una pagina con un pulsante, così salvando può
  // chiudersi e tornare indietro.
  Widget app(Divieto divieto) => ProviderScope(
        overrides: [divietiProvider.overrideWith(() => divieti = _DivietiFinti())],
        retry: (tentativo, errore) => null,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => ModuloDivietoScreen(divieto: divieto)),
                  ),
                  child: const Text('Apri'),
                ),
              ),
            ),
          ),
        ),
      );

  group('ModuloDivietoScreen', () {
    test('problemiDivieto chiede il nome e almeno un punto', () {
      expect(problemiDivieto('  ', const []), ['Scrivi il nome del divieto.', 'Disegna il divieto sulla mappa.']);
      expect(problemiDivieto('Divieto', _punti), isEmpty);
    });

    testWidgets('senza nome mostra cosa manca; con il nome salva il divieto disegnato', (tester) async {
      await tester.pumpWidget(app(const Divieto(nome: '', coordinate: _punti)));
      await tester.tap(find.text('Apri'));
      await tester.pumpAndSettle();
      expect(find.text('Nuovo divieto'), findsOneWidget);
      expect(find.text('2 punti · 1356 m'), findsOneWidget);
      expect(find.text('Modifica sulla mappa'), findsOneWidget);
      // Un divieto nuovo non si può eliminare
      expect(find.text('Elimina divieto'), findsNothing);

      await tester.tap(find.text('Salva divieto'));
      await tester.pumpAndSettle();
      expect(find.text('• Scrivi il nome del divieto.'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Divieto incubatoio');
      await tester.enterText(find.widgetWithText(TextField, 'Note'), 'Fino al terzo ponte');
      await tester.tap(find.text('Salva divieto'));
      await tester.pumpAndSettle();

      // Salvato e tornato alla pagina di partenza
      expect(find.text('Apri'), findsOneWidget);
      expect(divieti.salvati.single.nome, 'Divieto incubatoio');
      expect(divieti.salvati.single.note, 'Fino al terzo ponte');
      expect(divieti.salvati.single.coordinate, _punti);
    });

    testWidgets('un divieto esistente si elimina dopo la conferma', (tester) async {
      await tester.pumpWidget(app(const Divieto(id: 7, nome: 'Divieto', coordinate: _punti)));
      await tester.tap(find.text('Apri'));
      await tester.pumpAndSettle();
      expect(find.text('Modifica divieto'), findsOneWidget);

      await tester.tap(find.text('Elimina divieto'));
      await tester.pumpAndSettle();
      expect(find.text('Eliminare il divieto "Divieto"?'), findsOneWidget);
      await tester.tap(find.text('Elimina'));
      await tester.pumpAndSettle();

      expect(divieti.eliminati, [7]);
      expect(find.text('Apri'), findsOneWidget);
    });
  });
}
