import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/pescate/pescata.dart';
import 'package:diario_pesca/ui/screens/elenco_pescate_screen.dart';
import 'package:diario_pesca/ui/state/pescate_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Elenco finto: la schermata viene provata senza database.
class _PescateFinte extends ElencoPescateNotifier {
  _PescateFinte(this.pescate);

  final List<Pescata> pescate;

  @override
  Future<List<Pescata>> build() async => pescate;
}

Widget _app(List<Pescata> pescate, {Map<int, int> totali = const {}, Set<int> senzaMeteo = const {}}) =>
    ProviderScope(
      overrides: [
        elencoPescateProvider.overrideWith(() => _PescateFinte(pescate)),
        totaliCattureProvider.overrideWith((ref) async => totali),
        pescateSenzaMeteoProvider.overrideWith((ref) async => senzaMeteo),
      ],
      retry: (tentativo, errore) => null,
      child: const MaterialApp(home: ElencoPescateScreen()),
    );

void main() {
  group('ElencoPescateScreen', () {
    testWidgets('mostra le pescate per mese con spot, totale e meteo mancante', (tester) async {
      await tester.pumpWidget(_app(
        [
          Pescata(id: 3, data: DateTime(2026, 11, 14), fasciaOraria: FasciaOraria.alba, spotNome: 'Valsecca'),
          Pescata(id: 2, data: DateTime(2026, 11, 7), fasciaOraria: FasciaOraria.sera, spotNome: 'Piazza3'),
          Pescata(id: 1, data: DateTime(2026, 10, 4), fasciaOraria: FasciaOraria.mattina),
        ],
        totali: {3: 7, 1: 1},
        senzaMeteo: {3},
      ));
      await tester.pumpAndSettle();

      expect(find.text('Novembre 2026'), findsOneWidget);
      expect(find.text('Ottobre 2026'), findsOneWidget);
      expect(find.text('sabato 14/11/2026 · Alba'), findsOneWidget);
      expect(find.text('Valsecca'), findsOneWidget);
      expect(find.text('Spot eliminato'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('catture'), findsNWidgets(2)); // 7 e 0
      expect(find.text('cattura'), findsOneWidget);
      // Solo la pescata del 14/11 ha il meteo da scaricare
      expect(find.byTooltip('Meteo da scaricare'), findsOneWidget);
    });

    testWidgets('senza pescate invita a registrarne una', (tester) async {
      await tester.pumpWidget(_app(const []));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nessuna pescata registrata.'), findsOneWidget);
      expect(find.text('Nuova pescata'), findsOneWidget);
    });
  });
}
