import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/territorio/spot.dart';
import '../state/spot_state.dart';
import '../widgets/vista_asincrona.dart';

/// Elenco degli spot. Prima schermata realizzata con Riverpod: osserva
/// [elencoSpotProvider] e si ridisegna da sola quando gli spot cambiano.
class ElencoSpotScreen extends ConsumerWidget {
  const ElencoSpotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elenco = ref.watch(elencoSpotProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Spot')),
      body: VistaAsincrona<List<Spot>>(
        valore: elenco,
        riprova: () => ref.invalidate(elencoSpotProvider),
        dati: (spot) => RefreshIndicator(
          onRefresh: () => ref.refresh(elencoSpotProvider.future),
          child: spot.isEmpty
              ? ListView(
                  // Scorrevole anche se vuoto, per poter tirare e aggiornare.
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Nessuno spot salvato.',
                        textAlign: TextAlign.center,
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

class _RigaSpot extends StatelessWidget {
  const _RigaSpot({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(spot.nome),
      subtitle: Text('${spot.ambiente} · ${spot.categoriaNome}'),
      trailing: spot.battuto
          ? const Tooltip(
              message: 'Battuto',
              child: Icon(Icons.check_circle_outline),
            )
          : null,
    );
  }
}
