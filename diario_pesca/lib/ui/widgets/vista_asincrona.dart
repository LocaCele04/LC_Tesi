import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mostra un dato asincrono nei suoi tre stati: caricamento (indicatore),
/// errore (messaggio e pulsante *Riprova*) e dati (costruiti da [dati]).
///
/// Durante un aggiornamento restano visibili i dati precedenti, così la
/// schermata non lampeggia ogni volta che si salva qualcosa.
class VistaAsincrona<T> extends StatelessWidget {
  const VistaAsincrona({
    super.key,
    required this.valore,
    required this.dati,
    required this.riprova,
  });

  final AsyncValue<T> valore;
  final Widget Function(T dati) dati;
  final VoidCallback riprova;

  @override
  Widget build(BuildContext context) {
    return valore.when(
      data: dati,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (errore, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              const Text(
                'Non è stato possibile caricare i dati.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '$errore',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: riprova,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Versione compatta di [VistaAsincrona] per una sezione dentro un modulo:
/// una barra durante il caricamento e un messaggio in caso di errore.
Widget sezioneAsincrona<T>(AsyncValue<T> valore, Widget Function(T dati) dati) => valore.when(
      data: dati,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Dati non disponibili: $e'),
    );
