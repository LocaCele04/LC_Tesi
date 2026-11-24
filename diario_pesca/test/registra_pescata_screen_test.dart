import 'package:diario_pesca/models/catalogo/esca.dart';
import 'package:diario_pesca/models/catalogo/specie.dart';
import 'package:diario_pesca/models/territorio/spot.dart';
import 'package:diario_pesca/ui/screens/registra_pescata_screen.dart';
import 'package:diario_pesca/ui/state/catalogo_state.dart';
import 'package:diario_pesca/ui/state/dipendenze.dart';
import 'package:diario_pesca/ui/state/spot_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// La schermata viene provata senza database: spot, specie ed esche sono
/// dati preparati nel test.
class _SpotFinti extends ElencoSpotNotifier {
  @override
  Future<List<Spot>> build() async => const [
        Spot(nome: 'Valbrina', ambiente: 'Torrente', categoriaNome: 'Valle'),
      ];
}

class _SpecieFinte extends SpecieNotifier {
  @override
  Future<List<Specie>> build() async => const [Specie(nome: 'Trota')];
}

Widget _app() => ProviderScope(
      overrides: [
        elencoSpotProvider.overrideWith(_SpotFinti.new),
        specieProvider.overrideWith(_SpecieFinte.new),
        escheProvider.overrideWith((ref) async => const [Esca(id: 1, nome: 'Gomma verde')]),
        orologioProvider.overrideWith((ref) => () => DateTime(2026, 2, 20, 12)),
      ],
      retry: (tentativo, errore) => null,
      child: const MaterialApp(home: RegistraPescataScreen()),
    );

/// Lista principale del modulo (la prima tra quelle scorrevoli: dentro ci
/// sono anche l'elenco delle esche e i campi di testo).
final _lista = find.byType(Scrollable).first;

/// Scorre il modulo finché [cercato] è sullo schermo, spostando direttamente
/// la lista principale. Non si usa `scrollUntilVisible`: trascina dal centro
/// della lista, e se lì capita un elemento scorrevole interno (l'elenco
/// delle esche, un campo di testo) è quello a ricevere il trascinamento,
/// la lista non si muove e l'elemento cercato non viene mai trovato.
/// Il `pumpAndSettle` finale disegna il fotogramma, così un tocco subito
/// dopo cade sull'elemento.
Future<void> _scorriFino(WidgetTester tester, Finder cercato) async {
  final posizione = tester.state<ScrollableState>(_lista).position;
  while (cercato.evaluate().isEmpty && posizione.pixels < posizione.maxScrollExtent) {
    final prossima = posizione.pixels + 300;
    posizione.jumpTo(prossima > posizione.maxScrollExtent ? posizione.maxScrollExtent : prossima);
    await tester.pump();
  }
  await tester.ensureVisible(cercato);
  await tester.pumpAndSettle();
}

void main() {
  group('RegistraPescataScreen', () {
    testWidgets('salvando il modulo vuoto mostra cosa manca', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Scegli lo spot per vedere le condizioni del suo ambiente.'), findsOneWidget);

      await _scorriFino(tester, find.text('Salva pescata'));
      await tester.tap(find.text('Salva pescata'));
      // Fotogrammi espliciti invece di pumpAndSettle: se qualcosa restasse
      // ad animarsi all'infinito, il test lo segnala con un messaggio chiaro
      // invece di scadere.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'l\'indicatore di salvataggio deve fermarsi prima del dialogo',
      );
      expect(find.text('Controlla i dati'), findsOneWidget);
      expect(find.text('• Scegli lo spot.'), findsOneWidget);
      expect(find.text('• Scegli la fascia oraria.'), findsOneWidget);
    });

    testWidgets('fascia oraria, esche e catture si compilano e il totale si aggiorna', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Alba'));
      await tester.pump();
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Alba')).selected, isTrue);

      await _scorriFino(tester, find.text('Gomma verde'));
      expect(find.text('0 selezionate su 1'), findsOneWidget);
      await tester.tap(find.text('Gomma verde'));
      await tester.pump();
      expect(find.text('1 selezionate su 1'), findsOneWidget);

      await _scorriFino(tester, find.text('Aggiungi specie'));
      await tester.tap(find.text('Aggiungi specie'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Totale catture'), '3');
      await tester.pump();

      await _scorriFino(tester, find.text('Totale pescata: 3 catture'));
      expect(find.text('Totale pescata: 3 catture'), findsOneWidget);
    });

    testWidgets('togliere un\'esca nuova chiede conferma prima di scartarla', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await _scorriFino(tester, find.text('Nuova esca'));
      await tester.tap(find.text('Nuova esca'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Nome dell\'esca'), 'Streamer nero');
      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();
      // L'esca nuova è selezionata e compare in cima, segnata come nuova
      expect(find.text('Streamer nero'), findsOneWidget);
      expect(find.text('nuova'), findsOneWidget);
      expect(find.text('1 selezionate su 2'), findsOneWidget);

      // Annullando, resta selezionata
      await tester.tap(find.text('Streamer nero'));
      await tester.pumpAndSettle();
      expect(find.text('Scartare l\'esca "Streamer nero"?'), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(find.text('1 selezionate su 2'), findsOneWidget);

      // Confermando, viene scartata
      await tester.tap(find.text('Streamer nero'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scarta'));
      await tester.pumpAndSettle();
      expect(find.text('Streamer nero'), findsNothing);
      expect(find.text('0 selezionate su 1'), findsOneWidget);

      // Un'esca del catalogo si toglie senza domande
      await tester.tap(find.text('Gomma verde'));
      await tester.pump();
      await tester.tap(find.text('Gomma verde'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('0 selezionate su 1'), findsOneWidget);
    });
  });
}
