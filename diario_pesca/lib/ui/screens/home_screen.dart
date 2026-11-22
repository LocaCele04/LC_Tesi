import 'package:flutter/material.dart';

import 'elenco_pescate_screen.dart';
import 'elenco_spot_screen.dart';

/// Schermata principale: le due sezioni dell'app, Pescate e Spot, con la
/// barra di navigazione in basso. Le sezioni restano in memoria passando
/// dall'una all'altra, così non perdono la posizione nell'elenco.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _sezione = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _sezione,
        children: const [ElencoPescateScreen(), ElencoSpotScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _sezione,
        onDestinationSelected: (i) => setState(() => _sezione = i),
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
        ],
      ),
    );
  }
}
