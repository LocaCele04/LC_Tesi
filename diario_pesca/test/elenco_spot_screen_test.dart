import 'dart:async';

import 'package:diario_pesca/models/territorio/spot.dart';
import 'package:diario_pesca/ui/screens/elenco_spot_screen.dart';
import 'package:diario_pesca/ui/state/spot_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Elenco finto: la schermata viene provata senza database, sostituendo
/// solo il provider che osserva.
class _ElencoFinto extends ElencoSpotNotifier {
  _ElencoFinto(this._carica);

  final Future<List<Spot>> Function() _carica;

  @override
  Future<List<Spot>> build() => _carica();
}

Widget _app(Future<List<Spot>> Function() carica) => ProviderScope(
      overrides: [elencoSpotProvider.overrideWith(() => _ElencoFinto(carica))],
      retry: (tentativo, errore) => null,
      child: const MaterialApp(home: ElencoSpotScreen()),
    );

void main() {
  group('ElencoSpotScreen', () {
    testWidgets('mostra gli spot con ambiente, categoria e stato battuto', (tester) async {
      await tester.pumpWidget(_app(() async => const [
            Spot(nome: 'Abetina', ambiente: 'Torrente', categoriaNome: 'Val Sorbina', battuto: true),
            Spot(nome: 'Valbrina', ambiente: 'Torrente', categoriaNome: 'Borgo di Cima'),
          ]));
      await tester.pumpAndSettle();

      expect(find.text('Abetina'), findsOneWidget);
      expect(find.text('Torrente · Borgo di Cima'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('durante il caricamento mostra l\'indicatore', (tester) async {
      final inAttesa = Completer<List<Spot>>();
      await tester.pumpWidget(_app(() => inAttesa.future));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      inAttesa.complete(const []);
      await tester.pumpAndSettle();
      expect(find.text('Nessuno spot salvato.'), findsOneWidget);
    });

    testWidgets('in caso di errore mostra il messaggio e "Riprova" ricarica', (tester) async {
      var tentativi = 0;
      await tester.pumpWidget(_app(() async {
        tentativi++;
        if (tentativi == 1) throw Exception('Database non leggibile');
        return const [Spot(nome: 'Valbrina', ambiente: 'Torrente', categoriaNome: 'Valle')];
      }));
      await tester.pumpAndSettle();

      expect(find.text('Non è stato possibile caricare i dati.'), findsOneWidget);
      expect(tentativi, 1);

      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      expect(tentativi, 2);
      expect(find.text('Valbrina'), findsOneWidget);
    });
  });
}
