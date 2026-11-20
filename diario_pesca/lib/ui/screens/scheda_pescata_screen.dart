import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enums.dart';
import '../../models/meteo/meteo_giorno.dart';
import '../../models/meteo/meteo_pescata.dart';
import '../../models/pescate/pescata.dart';
import '../../services/meteo_service.dart';
import '../state/catalogo_state.dart';
import '../state/dipendenze.dart';
import '../state/pescate_state.dart';
import '../state/spot_state.dart';
import '../widgets/dialoghi.dart';
import '../widgets/etichette.dart';
import '../widgets/vista_asincrona.dart';
import 'elenco_pescate_screen.dart';
import 'registra_pescata_screen.dart';

/// Scheda di una pescata: spot, data e fascia, catture per specie con le
/// caratteristiche, condizioni, temperature, esche, meteo e note. Dalla
/// barra in alto la pescata si modifica o si elimina.
class SchedaPescataScreen extends ConsumerWidget {
  const SchedaPescataScreen({super.key, required this.id});

  final int id;

  Future<void> _modifica(BuildContext context, WidgetRef ref, Pescata pescata) async {
    // L'ambiente dello spot decide le condizioni del modulo.
    final spot = await ref.read(elencoSpotProvider.future);
    String? ambiente;
    for (final s in spot) {
      if (s.nome == pescata.spotNome) ambiente = s.ambiente;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegistraPescataScreen(apertura: (pescata: pescata, ambiente: ambiente)),
      ),
    );
  }

  Future<void> _elimina(BuildContext context, WidgetRef ref, Pescata pescata) async {
    final messaggi = ScaffoldMessenger.of(context);
    final navigatore = Navigator.of(context);
    final conferma = await chiediConferma(
      context,
      titolo: 'Eliminare la pescata?',
      messaggio: 'La pescata del ${formattaData(pescata.data)} verrà eliminata con le sue '
          'catture, condizioni e foto. L\'operazione non si può annullare.',
      conferma: 'Elimina',
    );
    if (!conferma) return;
    try {
      await ref.read(elencoPescateProvider.notifier).elimina(id);
      messaggi.showSnackBar(const SnackBar(content: Text('Pescata eliminata')));
      navigatore.pop();
    } catch (e) {
      messaggi.showSnackBar(SnackBar(content: Text('Eliminazione non riuscita: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dettaglio = ref.watch(dettaglioPescataProvider(id));
    final pescata = dettaglio.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pescata'),
        actions: [
          if (pescata != null) ...[
            IconButton(
              tooltip: 'Modifica',
              onPressed: () => _modifica(context, ref, pescata),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Elimina',
              onPressed: () => _elimina(context, ref, pescata),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ],
      ),
      body: VistaAsincrona<Pescata?>(
        valore: dettaglio,
        riprova: () => ref.invalidate(dettaglioPescataProvider(id)),
        dati: (pescata) => pescata == null
            ? const Center(child: Text('La pescata non esiste più.'))
            : _Contenuto(pescata: pescata),
      ),
    );
  }
}

class _Contenuto extends ConsumerWidget {
  const _Contenuto({required this.pescata});

  final Pescata pescata;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testo = Theme.of(context).textTheme;
    final totale = pescata.riepiloghiSpecie.fold<int>(0, (s, r) => s + r.quantita);
    final nomiCondizioni = ref.watch(nomiCondizioniProvider).value ?? const {};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(pescata.spotNome ?? 'Spot eliminato', style: testo.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '${formattaData(pescata.data)} · ${etichettaFascia(pescata.fasciaOraria)}',
          style: testo.titleMedium,
        ),
        const _Titolo('Catture'),
        if (pescata.riepiloghiSpecie.isEmpty)
          const Text('Nessuna cattura.')
        else ...[
          for (final r in pescata.riepiloghiSpecie)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${r.specieNome}: ${r.quantita}', style: testo.titleSmall),
                    if (r.dettagli.isNotEmpty)
                      TextSpan(
                        text: '  (${r.dettagli.map((d) => '${d.caratteristica.nome}: ${d.quantita}').join(', ')})',
                      ),
                  ],
                ),
              ),
            ),
          Text('Totale: $totale', style: testo.bodySmall),
        ],
        if (pescata.valoriCondizioni.isNotEmpty) ...[
          const _Titolo('Condizioni'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final v in pescata.valoriCondizioni)
                Chip(label: Text('${nomiCondizioni[v.condizioneId] ?? 'Condizione'}: ${v.nome}')),
            ],
          ),
        ],
        if (pescata.tempAcqua != null || pescata.tempAria != null) ...[
          const _Titolo('Temperature'),
          Text([
            if (pescata.tempAcqua != null) 'Acqua ${formattaNumero(pescata.tempAcqua!)} °C',
            if (pescata.tempAria != null) 'Aria ${formattaNumero(pescata.tempAria!)} °C',
          ].join(' · ')),
        ],
        if (pescata.esche.isNotEmpty) ...[
          const _Titolo('Esche'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [for (final e in pescata.esche) Chip(label: Text(e.nome))],
          ),
        ],
        const _Titolo('Meteo'),
        _Meteo(pescata: pescata),
        if (pescata.note != null) ...[
          const _Titolo('Note'),
          Text(pescata.note!),
        ],
      ],
    );
  }
}

class _Titolo extends StatelessWidget {
  const _Titolo(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(testo, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// Meteo della pescata: lo stato e, se scaricato, il giorno della pescata
/// e la pioggia dei giorni precedenti.
class _Meteo extends ConsumerWidget {
  const _Meteo({required this.pescata});

  final Pescata pescata;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return sezioneAsincrona<MeteoPescata>(
      ref.watch(meteoPescataProvider(pescata.id!)),
      (meteo) => switch (meteo.stato) {
        StatoMeteo.nonDisponibile => const Text(
            'Non disponibile: lo spot non ha coordinate. Aggiungi almeno un punto '
            'allo spot per avere il meteo.',
          ),
        StatoMeteo.daScaricare => _MeteoDaScaricare(pescata: pescata),
        StatoMeteo.scaricato => _MeteoScaricato(pescata: pescata, meteo: meteo),
      },
    );
  }
}

class _MeteoDaScaricare extends ConsumerWidget {
  const _MeteoDaScaricare({required this.pescata});

  final Pescata pescata;

  Future<void> _scarica(BuildContext context, WidgetRef ref) async {
    final messaggi = ScaffoldMessenger.of(context);
    try {
      final esito = await ref.read(aggiornamentoMeteoProvider.notifier).aggiorna();
      if (esito != null) messaggi.showSnackBar(SnackBar(content: Text(descriviEsitoMeteo(esito))));
    } catch (e) {
      messaggi.showSnackBar(SnackBar(content: Text('Meteo non scaricato: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oggi = ref.read(orologioProvider)();
    // Il meteo di una giornata si scarica solo quando è conclusa.
    final passata = pescata.data.isBefore(DateTime(oggi.year, oggi.month, oggi.day));
    final scaricando = ref.watch(aggiornamentoMeteoProvider).isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          passata
              ? 'Non ancora scaricato.'
              : 'Si potrà scaricare da domani, quando la giornata sarà conclusa.',
        ),
        if (passata) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: scaricando ? null : () => _scarica(context, ref),
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(scaricando ? 'Scaricamento…' : 'Scarica il meteo'),
          ),
        ],
      ],
    );
  }
}

class _MeteoScaricato extends ConsumerWidget {
  const _MeteoScaricato({required this.pescata, required this.meteo});

  final Pescata pescata;
  final MeteoPescata meteo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testo = Theme.of(context).textTheme;
    MeteoGiorno? giorno;
    for (final g in meteo.giorni) {
      if (g.data == pescata.data) giorno = g;
    }
    String pioggia(int giorni) {
      final valore = ref.watch(pioggiaCumulataProvider((pescataId: pescata.id!, giorni: giorni))).value;
      return valore == null ? '–' : '${formattaNumero(valore)} mm';
    }

    final righe = <(String, String)>[
      if (giorno?.tempMin != null && giorno?.tempMax != null)
        ('Temperatura', '${formattaNumero(giorno!.tempMin!)} / ${formattaNumero(giorno.tempMax!)} °C'),
      if (giorno?.pioggiaMm != null) ('Pioggia nel giorno', '${formattaNumero(giorno!.pioggiaMm!)} mm'),
      ('Pioggia nei 3 giorni prima', pioggia(3)),
      ('Pioggia nei 7 giorni prima', pioggia(7)),
      ('Pioggia nei 14 giorni prima', pioggia(14)),
      if (giorno?.ventoMax != null) ('Vento massimo', '${formattaNumero(giorno!.ventoMax!)} km/h'),
      if (giorno?.pressioneMedia != null)
        ('Pressione media', '${formattaNumero(giorno!.pressioneMedia!, decimali: 0)} hPa'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (etichetta, valore) in righe)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(child: Text(etichetta)),
                Text(valore, style: testo.titleSmall),
              ],
            ),
          ),
        if (meteo.cella != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Zona di circa 2 km, quota ${formattaNumero(meteo.cella!.elevazione, decimali: 0)} m.',
              style: testo.bodySmall,
            ),
          ),
        Text(MeteoService.attribuzione, style: testo.bodySmall),
      ],
    );
  }
}
