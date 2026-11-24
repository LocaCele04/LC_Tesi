import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/territorio/spot.dart';
import '../state/spot_state.dart';
import '../widgets/vista_asincrona.dart';
import 'modulo_spot_screen.dart';

/// Elenco degli spot (scheda "Spot" della schermata principale). Osserva
/// [elencoSpotProvider] e si ridisegna da sola quando gli spot cambiano;
/// toccando uno spot lo si modifica.
class ElencoSpotScreen extends ConsumerWidget {
  const ElencoSpotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elenco = ref.watch(elencoSpotProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Spot')),
      floatingActionButton: FloatingActionButton.extended(
        // Le schede della home restano tutte montate: senza tag diversi i
        // pulsanti si contendono l'animazione di passaggio tra le pagine.
        heroTag: null,
        onPressed: () => _nuovoSpot(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Nuovo spot'),
      ),
      body: VistaAsincrona<List<Spot>>(
        valore: elenco,
        riprova: () => ref.invalidate(elencoSpotProvider),
        dati: (spot) => RefreshIndicator(
          onRefresh: () => ref.refresh(elencoSpotProvider.future),
          child: spot.isEmpty
              ? ListView(
                  // Scorrevole anche se vuoto, per poter tirare e aggiornare.
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(32, 32, 32, 12),
                      child: Text(
                        'Nessuno spot salvato.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () => _nuovoSpot(context),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Aggiungi il primo spot'),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: spot.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _RigaSpot(spot: spot[i]),
                ),
        ),
      ),
    );
  }
}

void _nuovoSpot(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ModuloSpotScreen()),
    );

class _RigaSpot extends StatelessWidget {
  const _RigaSpot({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(spot.nome),
      subtitle: Text('${spot.ambiente} · ${spot.categoriaNome}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ModificaSpotScreen(nome: spot.nome)),
      ),
      trailing: spot.battuto
          ? const Tooltip(
              message: 'Battuto',
              child: Icon(Icons.check_circle_outline),
            )
          : null,
    );
  }
}
