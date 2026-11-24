import 'package:flutter/material.dart';

import 'elenco_pescate_screen.dart';
import '../mappa/mappa_screen.dart';
import 'elenco_spot_screen.dart';

/// Schermata principale: le sezioni dell'app (Pescate, Spot, Mappa) con la
/// barra di navigazione in basso. Le sezioni restano in memoria passando
/// dall'una all'altra, così non perdono la posizione nell'elenco o
/// l'inquadratura della mappa. La mappa viene creata solo la prima volta
/// che si apre la sua sezione, così non scarica tessere se non serve.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _sezione = 0;
  bool _mappaAperta = false;

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
        onDestinationSelected: (i) => setState(() {
          _sezione = i;
          if (i == 2) _mappaAperta = true;
        }),
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
