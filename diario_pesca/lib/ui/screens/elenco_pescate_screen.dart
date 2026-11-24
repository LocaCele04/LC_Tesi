import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pescate/pescata.dart';
import '../../services/meteo_service.dart';
import '../state/pescate_state.dart';
import '../widgets/etichette.dart';
import '../widgets/vista_asincrona.dart';
import 'backup_screen.dart';
import 'registra_pescata_screen.dart';
import 'scheda_pescata_screen.dart';

/// Elenco delle pescate dalla più recente, divise per mese (scheda
/// "Pescate" della schermata principale). Per ogni pescata: data, fascia,
/// spot, totale delle catture e, se manca, il meteo da scaricare.
/// Dal menu in alto si scarica il meteo di tutte le pescate che non l'hanno.
class ElencoPescateScreen extends ConsumerWidget {
  const ElencoPescateScreen({super.key});

  Future<void> _aggiornaMeteo(BuildContext context, WidgetRef ref) async {
    final messaggi = ScaffoldMessenger.of(context);
    try {
      final esito = await ref.read(aggiornamentoMeteoProvider.notifier).aggiorna();
      if (esito != null) {
        messaggi..clearSnackBars()..showSnackBar(SnackBar(content: Text(descriviEsitoMeteo(esito))));
      }
    } catch (e) {
      messaggi..clearSnackBars()..showSnackBar(SnackBar(content: Text('Meteo non scaricato: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elenco = ref.watch(elencoPescateProvider);
    final scaricando = ref.watch(aggiornamentoMeteoProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pescate'),
        actions: [
          if (scaricando)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Scarica il meteo mancante',
              onPressed: () => _aggiornaMeteo(context, ref),
              icon: const Icon(Icons.cloud_download_outlined),
            ),
          PopupMenuButton<String>(
            onSelected: (_) => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'backup', child: Text('Backup e ripristino')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const RegistraPescataScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nuova pescata'),
      ),
      body: VistaAsincrona<List<Pescata>>(
        valore: elenco,
        riprova: () => ref.invalidate(elencoPescateProvider),
        dati: (pescate) => RefreshIndicator(
          onRefresh: () => ref.refresh(elencoPescateProvider.future),
          child: pescate.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Nessuna pescata registrata.\nUsa "Nuova pescata" per la prima.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : _Elenco(pescate: pescate),
        ),
      ),
    );
  }
}

/// Frase per l'utente sull'esito di uno scaricamento del meteo.
String descriviEsitoMeteo(EsitoAggiornamentoMeteo esito) {
  if (esito.completate == 0 && esito.incomplete == 0 && esito.errori == 0) {
    return 'Il meteo delle pescate passate è già tutto scaricato.';
  }
  final parti = <String>[
    if (esito.completate > 0)
      esito.completate == 1 ? 'meteo scaricato per 1 pescata' : 'meteo scaricato per ${esito.completate} pescate',
    if (esito.incomplete > 0) '${esito.incomplete} ancora incomplete',
    if (esito.errori > 0) 'errori di rete: riprova più tardi',
  ];
  if (parti.isEmpty) return 'Nessun nuovo dato meteo.';
  final frase = parti.join(', ');
  return '${frase[0].toUpperCase()}${frase.substring(1)}.';
}

class _Elenco extends ConsumerWidget {
  const _Elenco({required this.pescate});

  final List<Pescata> pescate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Totali e meteo arrivano da query separate: finché non ci sono, le
    // righe si mostrano senza.
    final totali = ref.watch(totaliCattureProvider).value ?? const {};
    final senzaMeteo = ref.watch(pescateSenzaMeteoProvider).value ?? const {};

    final righe = <Widget>[];
    String? meseCorrente;
    for (final p in pescate) {
      final mese = formattaMese(p.data);
      if (mese != meseCorrente) {
        meseCorrente = mese;
        righe.add(_TitoloMese(mese));
      }
      righe.add(_RigaPescata(
        pescata: p,
        totale: totali[p.id] ?? 0,
        meteoDaScaricare: senzaMeteo.contains(p.id),
      ));
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 88),
      children: righe,
    );
  }
}

class _TitoloMese extends StatelessWidget {
  const _TitoloMese(this.mese);

  final String mese;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          mese,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
}

class _RigaPescata extends StatelessWidget {
  const _RigaPescata({
    required this.pescata,
    required this.totale,
    required this.meteoDaScaricare,
  });

  final Pescata pescata;
  final int totale;
  final bool meteoDaScaricare;

  @override
  Widget build(BuildContext context) {
    final colori = Theme.of(context).colorScheme;
    return ListTile(
      title: Text('${formattaData(pescata.data)} · ${etichettaFascia(pescata.fasciaOraria)}'),
      subtitle: Text(pescata.spotNome ?? 'Spot eliminato'),
      leading: meteoDaScaricare
          ? Tooltip(
              message: 'Meteo da scaricare',
              child: Icon(Icons.cloud_off_outlined, color: colori.outline),
            )
          // Meteo scaricato, oppure non disponibile (spot senza coordinate):
          // nessuna icona, solo lo spazio per allineare le righe.
          : const SizedBox(width: 24),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$totale', style: Theme.of(context).textTheme.titleMedium),
          Text(totale == 1 ? 'cattura' : 'catture', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SchedaPescataScreen(id: pescata.id!)),
      ),
    );
  }
}
