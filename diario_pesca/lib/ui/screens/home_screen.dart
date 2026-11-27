import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mappa/mappa_screen.dart';
import '../state/memoria_ui.dart';
import 'elenco_pescate_screen.dart';
import 'elenco_spot_screen.dart';

/// Schermata principale: le sezioni dell'app (Pescate, Spot, Mappa) con la
/// barra di navigazione in basso. Le sezioni restano in memoria passando
/// dall'una all'altra, così non perdono la posizione nell'elenco o
/// l'inquadratura della mappa. La mappa viene creata solo la prima volta
/// che si apre la sua sezione, così non scarica tessere se non serve.
///
/// La sezione aperta si ricorda anche dopo la chiusura dell'app (vedi
/// [MemoriaUi]): riaprendola si torna lì, per esempio sulla mappa.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _numeroSezioni = 3;
  static const _sezioneMappa = 2;

  int _sezione = 0;
  bool _mappaAperta = false;

  @override
  void initState() {
    super.initState();
    final salvata = ref.read(memoriaUiProvider).leggi(ChiaviMemoria.sezione);
    if (salvata is int && salvata >= 0 && salvata < _numeroSezioni) {
      _sezione = salvata;
      _mappaAperta = salvata == _sezioneMappa;
    }
  }

  void _apriSezione(int i) {
    setState(() {
      _sezione = i;
      if (i == _sezioneMappa) _mappaAperta = true;
    });
    ref.read(memoriaUiProvider).scrivi(ChiaviMemoria.sezione, i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _sezione,
        children: [
          const ElencoPescateScreen(),
          const ElencoSpotScreen(),
          if (_mappaAperta) const MappaScreen() else const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _sezione,
        onDestinationSelected: _apriSezione,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Pescate',
          ),
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: 'Spot',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mappa',
          ),
        ],
      ),
    );
  }
}
