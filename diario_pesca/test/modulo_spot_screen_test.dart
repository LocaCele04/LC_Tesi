import 'package:diario_pesca/models/territorio/ambiente.dart';
import 'package:diario_pesca/models/territorio/categoria.dart';
import 'package:diario_pesca/models/territorio/spot.dart';
import 'package:diario_pesca/ui/screens/modulo_spot_screen.dart';
import 'package:diario_pesca/ui/state/spot_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// La schermata viene provata senza database: spot, categorie e ambienti
/// sono dati preparati nel test.
class _SpotFinti extends ElencoSpotNotifier {
  @override
  Future<List<Spot>> build() async => const [];
}

class _CategorieFinte extends CategorieNotifier {
  @override
  Future<List<Categoria>> build() async => const [Categoria(nome: 'Valle')];
}

Widget _app() => ProviderScope(
      overrides: [
        elencoSpotProvider.overrideWith(_SpotFinti.new),
        categorieProvider.overrideWith(_CategorieFinte.new),
        ambientiProvider.overrideWith((ref) async => const [Ambiente(nome: 'Torrente')]),
      ],
      retry: (tentativo, errore) => null,
      child: const MaterialApp(home: ModuloSpotScreen()),
    );

/// Lista principale del modulo (la prima tra quelle scorrevoli).
final _lista = find.byType(Scrollable).first;

/// Scorre fino a [cercato] e disegna il fotogramma, così il tocco successivo
/// cade sull'elemento.
Future<void> _scorriFino(WidgetTester tester, Finder cercato) async {
  await tester.scrollUntilVisible(cercato, 300, scrollable: _lista);
  await tester.pumpAndSettle();
}

void main() {
  group('ModuloSpotScreen', () {
    testWidgets('salvando il modulo vuoto mostra cosa manca', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Nuovo spot'), findsOneWidget);
      // Uno spot nuovo non si può eliminare
      expect(find.text('Elimina spot'), findsNothing);

      await _scorriFino(tester, find.text('Salva spot'));
      await tester.tap(find.text('Salva spot'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Controlla i dati'), findsOneWidget);
      expect(find.text('• Scrivi il nome dello spot.'), findsOneWidget);
      expect(find.text('• Scegli la categoria.'), findsOneWidget);
      expect(find.text('• Scegli l\'ambiente.'), findsOneWidget);
    });

    testWidgets('un punto incollato si aggiunge; un testo non valido mostra l\'errore', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final campo = find.widgetWithText(TextField, 'Nuovo punto');
      await _scorriFino(tester, campo);
      // Il testo si scrive direttamente nel campo: toccando il pulsante il
      // campo perde il fuoco, e una seconda digitazione simulata potrebbe
      // non arrivarci.
      Future<void> incolla(String testo) async {
        tester.widget<TextField>(campo).controller!.text = testo;
        await tester.tap(find.byTooltip('Aggiungi punto'));
        await tester.pumpAndSettle();
      }

      await incolla('ciao');
      expect(find.text('Punto non riconosciuto: incolla due coordinate.'), findsOneWidget);

      await incolla('45.7612, 9.6401');
      expect(find.text('Punto non riconosciuto: incolla due coordinate.'), findsNothing);
      expect(find.text('45.76120, 9.64010'), findsOneWidget);
      expect(find.text('Punto per il meteo'), findsOneWidget);
    });
  });
}
