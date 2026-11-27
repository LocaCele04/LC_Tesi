import 'package:diario_pesca/ui/mappa/colori_mappa.dart';
import 'package:diario_pesca/ui/state/mappa_state.dart';
import 'package:diario_pesca/ui/state/memoria_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer contenitore(MemoriaUi memoria) =>
      ProviderContainer.test(overrides: [memoriaUiProvider.overrideWithValue(memoria)]);

  group('Memoria dell\'interfaccia - Vista della mappa', () {
    test('senza scelte salvate: OpenStreetMap e colorazione per voto', () {
      final vista = contenitore(MemoriaUiInRam()).read(vistaMappaProvider);

      expect(vista.sfondo, Sfondo.stradale);
      expect(Sfondo.values.first, Sfondo.stradale);
      expect(vista.colorazione, Colorazione.voto);
    });

    test('sfondo e colorazione scelti si salvano e si ritrovano al prossimo avvio', () {
      final memoria = MemoriaUiInRam();
      contenitore(memoria).read(vistaMappaProvider.notifier)
        ..impostaSfondo(Sfondo.topografica)
        ..impostaColorazione(Colorazione.ambiente);

      expect(memoria.valori, {
        ChiaviMemoria.sfondo: 'topografica',
        ChiaviMemoria.colorazione: 'ambiente',
      });

      // Un nuovo avvio: nuovo contenitore, stessa memoria.
      final riaperta = contenitore(memoria).read(vistaMappaProvider);
      expect(riaperta.sfondo, Sfondo.topografica);
      expect(riaperta.colorazione, Colorazione.ambiente);
    });

    test('un valore salvato che non esiste più viene ignorato', () {
      final memoria = MemoriaUiInRam({
        ChiaviMemoria.sfondo: 'satellite',
        ChiaviMemoria.colorazione: 42,
      });

      final vista = contenitore(memoria).read(vistaMappaProvider);

      expect(vista.sfondo, Sfondo.stradale);
      expect(vista.colorazione, Colorazione.voto);
    });
  });

  group('Memoria dell\'interfaccia - Valori', () {
    test('scrive e rilegge numeri e testi', () async {
      final memoria = MemoriaUiInRam();
      await memoria.scrivi(ChiaviMemoria.sezione, 2);
      await memoria.scrivi(ChiaviMemoria.zoom, 13.5);

      expect(memoria.leggi(ChiaviMemoria.sezione), 2);
      expect(memoria.leggi(ChiaviMemoria.zoom), 13.5);
      expect(memoria.leggi(ChiaviMemoria.latitudine), isNull);
      expect(enumDaMemoria(MemoriaUiInRam({'x': 'voto'}), 'x', Colorazione.values), Colorazione.voto);
    });
  });
}
