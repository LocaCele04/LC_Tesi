import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enums.dart';
import '../../models/territorio/coordinata.dart';
import '../../models/territorio/divieto.dart';
import '../../models/territorio/spot.dart';
import '../../services/posizione_service.dart';
import '../screens/modulo_spot_screen.dart';
import '../screens/registra_pescata_screen.dart';
import '../state/dipendenze.dart';
import '../state/mappa_state.dart';
import '../state/spot_state.dart';
import '../widgets/etichette.dart';
import 'colori_mappa.dart';
import 'disegna_tratto_screen.dart';
import 'modulo_divieto_screen.dart';
import 'strati_mappa.dart';

/// Mappa degli spot e dei divieti (scheda "Mappa" della schermata
/// principale). Gli spot si colorano secondo la vista scelta e si filtrano;
/// i divieti sono sempre rosso scuro tratteggiati. Toccando una linea si
/// apre la sua scheda; con "Disegna" si crea uno spot o un divieto.
class MappaScreen extends ConsumerStatefulWidget {
  const MappaScreen({super.key});

  @override
  ConsumerState<MappaScreen> createState() => _MappaScreenState();
}

class _MappaScreenState extends ConsumerState<MappaScreen> {
  final _controller = MapController();
  final LayerHitNotifier<Object> _toccoSpot = ValueNotifier(null);
  final LayerHitNotifier<Object> _toccoDivieti = ValueNotifier(null);
  Coordinata? _posizione;
  bool _cercaPosizione = false;
  bool _legendaAperta = true;

  @override
  void dispose() {
    _toccoSpot.dispose();
    _toccoDivieti.dispose();
    super.dispose();
  }

  void _apriDaTocco(LayerHitNotifier<Object> notifier) {
    final valori = notifier.value?.hitValues ?? const [];
    if (valori.isEmpty) return;
    _apri(valori.first);
  }

  void _apri(Object elemento) {
    if (elemento is Spot) {
      showModalBottomSheet<void>(context: context, builder: (_) => _SchedaSpot(spot: elemento));
    } else if (elemento is Divieto) {
      showModalBottomSheet<void>(context: context, builder: (_) => _SchedaDivieto(divieto: elemento));
    }
  }

  Future<void> _vaiAllaPosizione() async {
    final messaggi = ScaffoldMessenger.of(context);
    setState(() => _cercaPosizione = true);
    try {
      final posizione = await ref.read(posizioneServiceProvider).attuale();
      if (!mounted) return;
      setState(() => _posizione = posizione);
      final zoom = _controller.camera.zoom < 14 ? 14.0 : _controller.camera.zoom;
      _controller.move(latLng(posizione), zoom);
    } on PosizioneNonDisponibile catch (e) {
      messaggi..clearSnackBars()..showSnackBar(SnackBar(content: Text(e.messaggio)));
    } finally {
      if (mounted) setState(() => _cercaPosizione = false);
    }
  }

  Future<void> _disegna() async {
    final scelta = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: const Text('Nuovo spot'),
              subtitle: const Text('Disegna il tratto, poi compila i dati'),
              onTap: () => Navigator.of(context).pop(false),
            ),
            ListTile(
              leading: const Icon(Icons.block, color: coloreDivieto),
              title: const Text('Nuovo divieto'),
              subtitle: const Text('Un tratto dove non si può pescare'),
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (scelta == null || !mounted) return;
    final divieto = scelta;
    final navigatore = Navigator.of(context);
    final camera = _controller.camera;
    final punti = await navigatore.push<List<Coordinata>>(
      MaterialPageRoute(
        builder: (_) => DisegnaTrattoScreen(
          titolo: divieto ? 'Nuovo divieto' : 'Nuovo spot',
          divieto: divieto,
          centro: camera.center,
          zoom: camera.zoom,
        ),
      ),
    );
    if (punti == null || !mounted) return;
    await navigatore.push<void>(
      MaterialPageRoute(
        builder: (_) => divieto
            ? ModuloDivietoScreen(divieto: Divieto(nome: '', coordinate: punti))
            : ModuloSpotScreen(puntiIniziali: punti),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vista = ref.watch(vistaMappaProvider);
    final notifier = ref.read(vistaMappaProvider.notifier);
    // `.value` tiene i dati precedenti mentre si ricaricano: la mappa non
    // viene ricreata (e non perde l'inquadratura) dopo ogni salvataggio.
    final datiSpot = ref.watch(spotSullaMappaProvider);
    final datiDivieti = ref.watch(divietiProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mappa'),
        actions: [
          PopupMenuButton<Colorazione>(
            tooltip: 'Colora per',
            icon: const Icon(Icons.palette_outlined),
            initialValue: vista.colorazione,
            onSelected: notifier.impostaColorazione,
            itemBuilder: (_) => [
              for (final c in Colorazione.values)
                CheckedPopupMenuItem(value: c, checked: c == vista.colorazione, child: Text(c.etichetta)),
            ],
          ),
          IconButton(
            tooltip: 'Filtri',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _Filtri(),
            ),
            icon: Badge(
              isLabelVisible: vista.filtriAttivi,
              smallSize: 8,
              child: const Icon(Icons.filter_alt_outlined),
            ),
          ),
          PopupMenuButton<Sfondo>(
            tooltip: 'Mappa di sfondo',
            icon: const Icon(Icons.layers_outlined),
            initialValue: vista.sfondo,
            onSelected: notifier.impostaSfondo,
            itemBuilder: (_) => [
              for (final s in Sfondo.values)
                CheckedPopupMenuItem(value: s, checked: s == vista.sfondo, child: Text(s.etichetta)),
            ],
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: null,
            tooltip: 'La mia posizione',
            onPressed: _cercaPosizione ? null : _vaiAllaPosizione,
            child: _cercaPosizione
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: null,
            onPressed: _disegna,
            icon: const Icon(Icons.draw_outlined),
            label: const Text('Disegna'),
          ),
        ],
      ),
      body: switch ((datiSpot.value, datiDivieti.value)) {
        (final spot?, final divieti?) => _mappa(context, vista, spot, divieti),
        _ when datiSpot.hasError || datiDivieti.hasError => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Mappa non caricata: ${datiSpot.error ?? datiDivieti.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      ref.invalidate(elencoSpotProvider);
                      ref.invalidate(divietiProvider);
                    },
                    child: const Text('Riprova'),
                  ),
                ],
              ),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _mappa(BuildContext context, VistaMappa vista, List<Spot> tutti, List<Divieto> divieti) {
    final spot = tutti.where(vista.mostra).toList();
    final linee = spot.where((s) => s.coordinate.length >= 2);
    final puntiSingoli = spot.where((s) => s.coordinate.length == 1);
    final divietiVisibili = vista.mostraDivieti ? divieti : const <Divieto>[];
    final iniziale = inquadratura([
      for (final s in tutti) ...s.coordinate,
      for (final d in divieti) ...d.coordinate,
    ]);

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCameraFit: iniziale.adatta,
            initialCenter: iniziale.centro,
            initialZoom: iniziale.zoom,
            maxZoom: zoomMassimo,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            stratoSfondo(vista.sfondo),
            GestureDetector(
              onTap: () => _apriDaTocco(_toccoDivieti),
              child: PolylineLayer<Object>(
                hitNotifier: _toccoDivieti,
                polylines: [
                  for (final d in divietiVisibili)
                    if (d.coordinate.length >= 2) lineaDivieto(d.coordinate, valore: d),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _apriDaTocco(_toccoSpot),
              child: PolylineLayer<Object>(
                hitNotifier: _toccoSpot,
                polylines: [
                  for (final s in linee)
                    lineaSpot(s.coordinate, coloreSpot(s, vista.colorazione), valore: s),
                ],
              ),
            ),
            MarkerLayer(
              markers: [
                for (final d in divietiVisibili)
                  if (d.coordinate.length == 1)
                    Marker(
                      point: latLng(d.coordinate.single),
                      width: 22,
                      height: 22,
                      child: GestureDetector(
                        onTap: () => _apri(d),
                        child: const Segnaposto(colore: coloreDivieto, divieto: true),
                      ),
                    ),
                for (final s in puntiSingoli)
                  Marker(
                    point: latLng(s.coordinate.single),
                    width: 20,
                    height: 20,
                    child: GestureDetector(
                      onTap: () => _apri(s),
                      child: Segnaposto(colore: coloreSpot(s, vista.colorazione)),
                    ),
                  ),
                if (_posizione != null) segnaPosizione(_posizione!),
              ],
            ),
            attribuzione(vista.sfondo),
          ],
        ),
        Positioned(
          left: 12,
          top: 12,
          child: _Legenda(
            titolo: vista.colorazione.etichetta,
            voci: legenda(vista.colorazione, spot),
            divieti: divietiVisibili.isNotEmpty,
            aperta: _legendaAperta,
            alterna: () => setState(() => _legendaAperta = !_legendaAperta),
          ),
        ),
      ],
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({
    required this.titolo,
    required this.voci,
    required this.divieti,
    required this.aperta,
    required this.alterna,
  });

  final String titolo;
  final List<VoceLegenda> voci;
  final bool divieti;
  final bool aperta;
  final VoidCallback alterna;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    return Card(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 200,
          maxHeight: MediaQuery.sizeOf(context).height * 0.4,
        ),
        child: InkWell(
          onTap: alterna,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(titolo, style: testo.labelLarge),
                    Icon(aperta ? Icons.expand_less : Icons.expand_more, size: 18),
                  ],
                ),
                if (aperta)
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final v in voci) _riga(v.colore, v.etichetta, testo),
                          if (divieti) _riga(coloreDivieto, 'divieto', testo, tratteggio: true),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _riga(Color colore, String etichetta, TextTheme testo, {bool tratteggio = false}) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 6,
              decoration: BoxDecoration(
                color: tratteggio ? null : colore,
                border: Border.all(color: tratteggio ? colore : Colors.black54, width: tratteggio ? 2 : 1),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(etichetta, style: testo.bodySmall)),
          ],
        ),
      );
}

/// Filtri della mappa, in un pannello dal basso.
class _Filtri extends ConsumerWidget {
  const _Filtri();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vista = ref.watch(vistaMappaProvider);
    final notifier = ref.read(vistaMappaProvider.notifier);
    final ambienti = ref.watch(ambientiProvider).value ?? const [];
    final categorie = ref.watch(categorieProvider).value ?? const [];
    final testo = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scorrimento) => ListView(
        controller: scorrimento,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Expanded(child: Text('Filtri', style: testo.titleLarge)),
              TextButton(
                onPressed: vista.filtriAttivi ? notifier.azzeraFiltri : null,
                child: const Text('Mostra tutto'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Spot', style: testo.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in FiltroStato.values)
                ChoiceChip(
                  label: Text(f.etichetta),
                  selected: vista.stato == f,
                  onSelected: (_) => notifier.impostaStato(f),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostra i divieti'),
            value: vista.mostraDivieti,
            onChanged: notifier.impostaMostraDivieti,
          ),
          const SizedBox(height: 16),
          Text('Ambienti', style: testo.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in ambienti)
                FilterChip(
                  label: Text(a.nome),
                  selected: !vista.ambientiNascosti.contains(a.nome.toLowerCase()),
                  onSelected: (visibile) => notifier.mostraAmbiente(a.nome, visibile),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Categorie', style: testo.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categorie)
                FilterChip(
                  label: Text(c.nome),
                  selected: !vista.categorieNascoste.contains(c.nome.toLowerCase()),
                  onSelected: (visibile) => notifier.mostraCategoria(c.nome, visibile),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Scheda di uno spot toccato sulla mappa.
class _SchedaSpot extends StatelessWidget {
  const _SchedaSpot({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final navigatore = Navigator.of(context);
    final righe = <String>[
      '${spot.categoriaNome} · ${spot.ambiente}',
      spot.battuto ? 'Ci hai pescato' : 'Mai pescato',
      if (spot.voto != null) 'Voto ${formattaNumero(spot.voto!)}',
      if (spot.lunghezzaMetri != null) 'Lunghezza ${spot.lunghezzaMetri!.round()} m',
      if (spot.accessibilita == Accessibilita.inaccessibile) 'Al momento non accessibile',
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(spot.nome, style: testo.titleLarge),
            const SizedBox(height: 8),
            for (final r in righe)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(r)),
            if (spot.note != null && spot.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(spot.note!, maxLines: 4, overflow: TextOverflow.ellipsis, style: testo.bodySmall),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    navigatore.pop();
                    navigatore.push(MaterialPageRoute<void>(
                      builder: (_) => RegistraPescataScreen(
                        spotIniziale: (nome: spot.nome, ambiente: spot.ambiente),
                      ),
                    ));
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Registra pescata qui'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    navigatore.pop();
                    navigatore.push(MaterialPageRoute<void>(
                      builder: (_) => ModificaSpotScreen(nome: spot.nome),
                    ));
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifica'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Scheda di un divieto toccato sulla mappa.
class _SchedaDivieto extends StatelessWidget {
  const _SchedaDivieto({required this.divieto});

  final Divieto divieto;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final navigatore = Navigator.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.block, color: coloreDivieto),
                const SizedBox(width: 8),
                Expanded(child: Text(divieto.nome, style: testo.titleLarge)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Divieto di pesca'),
            if (divieto.note != null) ...[
              const SizedBox(height: 12),
              Text(divieto.note!),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                navigatore.pop();
                navigatore.push(MaterialPageRoute<void>(
                  builder: (_) => ModuloDivietoScreen(divieto: divieto),
                ));
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifica'),
            ),
          ],
        ),
      ),
    );
  }
}
