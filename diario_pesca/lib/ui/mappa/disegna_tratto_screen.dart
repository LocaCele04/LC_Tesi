import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../models/territorio/coordinata.dart';
import '../../services/posizione_service.dart';
import '../state/dipendenze.dart';
import '../state/mappa_state.dart';
import '../widgets/dialoghi.dart';
import 'colori_mappa.dart';
import 'strati_mappa.dart';
import 'tratto_in_modifica.dart';

/// Disegno del tratto di uno spot o di un divieto sulla mappa:
///
/// * tocco sulla mappa: aggiunge un punto in fondo;
/// * trascinare un punto: lo sposta;
/// * tocco sul "+" a metà di un segmento: inserisce un punto in mezzo;
/// * tenere premuto un punto: lo elimina;
/// * Annulla torna indietro di un'operazione.
///
/// Restituisce i punti con "Fatto", `null` se si esce senza confermare.
/// Sullo sfondo, più chiari, gli altri spot e i divieti, come riferimento.
class DisegnaTrattoScreen extends ConsumerStatefulWidget {
  const DisegnaTrattoScreen({
    super.key,
    required this.titolo,
    this.puntiIniziali = const [],
    this.divieto = false,
    this.escludiSpot,
    this.escludiDivieto,
    this.centro,
    this.zoom,
  });

  final String titolo;
  final List<Coordinata> puntiIniziali;

  /// Si sta disegnando un divieto (linea tratteggiata).
  final bool divieto;

  /// Spot o divieto che si sta modificando: non va mostrato anche sullo sfondo.
  final String? escludiSpot;
  final int? escludiDivieto;

  /// Inquadratura di partenza per un tratto nuovo (di solito quella della
  /// mappa da cui si arriva).
  final LatLng? centro;
  final double? zoom;

  @override
  ConsumerState<DisegnaTrattoScreen> createState() => _DisegnaTrattoScreenState();
}

class _DisegnaTrattoScreenState extends ConsumerState<DisegnaTrattoScreen> {
  late final TrattoInModifica _tratto = TrattoInModifica(widget.puntiIniziali);
  // Inquadratura di partenza, calcolata una volta: la mappa la usa solo
  // alla prima costruzione.
  late final _iniziale = widget.puntiIniziali.isNotEmpty ? inquadratura(widget.puntiIniziali) : null;
  final _controller = MapController();

  /// Punto che si sta trascinando: intanto la mappa non si muove.
  int? _trascinato;
  double _percorso = 0;
  bool _spostamentoIniziato = false;
  Coordinata? _posizione;
  bool _cercaPosizione = false;

  void _modifica(VoidCallback operazione) => setState(operazione);

  void _premi(int indice) => setState(() {
        _trascinato = indice;
        _percorso = 0;
        _spostamentoIniziato = false;
      });

  void _trascina(int indice, Offset spostamento) {
    if (_trascinato != indice) return;
    // Un piccolo movimento del dito mentre si tiene premuto non è un
    // trascinamento.
    _percorso += spostamento.distance;
    if (!_spostamentoIniziato && _percorso < 6) return;
    if (!_spostamentoIniziato) {
      _tratto.iniziaSpostamento();
      _spostamentoIniziato = true;
    }
    final camera = _controller.camera;
    final punto = _tratto.punti[indice];
    final schermo = camera.latLngToScreenOffset(latLng(punto)) + spostamento;
    final nuovo = camera.screenOffsetToLatLng(schermo);
    setState(() => _tratto.sposta(indice, nuovo.latitude, nuovo.longitude));
  }

  void _rilascia() => setState(() => _trascinato = null);

  void _rimuovi(int indice) {
    HapticFeedback.mediumImpact();
    setState(() {
      _trascinato = null;
      _tratto.rimuovi(indice);
    });
  }

  Future<void> _vaiAllaPosizione() async {
    final messaggi = ScaffoldMessenger.of(context);
    setState(() => _cercaPosizione = true);
    try {
      final posizione = await ref.read(posizioneServiceProvider).attuale();
      if (!mounted) return;
      setState(() => _posizione = posizione);
      final zoom = _controller.camera.zoom < 15 ? 15.0 : _controller.camera.zoom;
      _controller.move(latLng(posizione), zoom);
    } on PosizioneNonDisponibile catch (e) {
      messaggi..clearSnackBars()..showSnackBar(SnackBar(content: Text(e.messaggio)));
    } finally {
      if (mounted) setState(() => _cercaPosizione = false);
    }
  }

  Future<void> _esci() async {
    final navigatore = Navigator.of(context);
    final esci = await chiediConferma(
      context,
      titolo: 'Uscire senza salvare il tratto?',
      messaggio: 'Le modifiche fatte sulla mappa andranno perse.',
      conferma: 'Esci',
    );
    if (esci) navigatore.pop();
  }

  @override
  Widget build(BuildContext context) {
    final vista = ref.watch(vistaMappaProvider);
    final altriSpot = (ref.watch(spotSullaMappaProvider).value ?? const [])
        .where((s) => s.nome != widget.escludiSpot && s.coordinate.length >= 2);
    final divieti = (ref.watch(divietiProvider).value ?? const [])
        .where((d) => d.id != widget.escludiDivieto && d.coordinate.length >= 2);
    final punti = _tratto.punti;
    final colori = Theme.of(context).colorScheme;
    final coloreTratto = widget.divieto ? coloreDivieto : colori.primary;

    final lunghezza = _tratto.lunghezzaMetri;

    return PopScope(
      canPop: !_tratto.modificato,
      onPopInvokedWithResult: (fatto, _) {
        if (!fatto) _esci();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.titolo),
          actions: [
            IconButton(
              tooltip: 'Annulla l\'ultima modifica',
              onPressed: _tratto.puoAnnullare ? () => _modifica(_tratto.annulla) : null,
              icon: const Icon(Icons.undo),
            ),
            PopupMenuButton<String>(
              onSelected: (_) => _modifica(_tratto.svuota),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'svuota',
                  enabled: punti.isNotEmpty,
                  child: const Text('Togli tutti i punti'),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCameraFit: _iniziale?.adatta,
                initialCenter: _iniziale?.centro ?? widget.centro ?? centroPredefinito,
                initialZoom: _iniziale?.zoom ?? widget.zoom ?? zoomPredefinito,
                maxZoom: zoomMassimo,
                interactionOptions: InteractionOptions(
                  flags: _trascinato != null
                      ? InteractiveFlag.none
                      : InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (_, p) => _modifica(() => _tratto.aggiungi(p.latitude, p.longitude)),
              ),
              children: [
                stratoSfondo(vista.sfondo),
                PolylineLayer<Object>(
                  polylines: [
                    for (final d in divieti) lineaDivieto(d.coordinate, opacita: 0.5),
                    for (final s in altriSpot)
                      lineaSpot(s.coordinate, coloreSpot(s, vista.colorazione), opacita: 0.45, spessore: 4),
                  ],
                ),
                if (punti.length >= 2)
                  PolylineLayer<Object>(
                    polylines: [
                      widget.divieto
                          ? lineaDivieto(punti)
                          : lineaSpot(punti, coloreTratto, spessore: 6),
                    ],
                  ),
                if (_posizione != null) MarkerLayer(markers: [segnaPosizione(_posizione!)]),
                MarkerLayer(
                  markers: [
                    for (var i = 0; i + 1 < punti.length; i++)
                      Marker(
                        point: latLng(_tratto.puntoMedio(i)),
                        width: 30,
                        height: 30,
                        child: _Inserisci(onTap: () => _modifica(() => _tratto.inserisciInMezzo(i))),
                      ),
                    for (var i = 0; i < punti.length; i++)
                      Marker(
                        point: latLng(punti[i]),
                        width: 40,
                        height: 40,
                        child: _Maniglia(
                          numero: i + 1,
                          colore: coloreTratto,
                          attivo: _trascinato == i,
                          premi: () => _premi(i),
                          trascina: (d) => _trascina(i, d),
                          rilascia: _rilascia,
                          rimuovi: () => _rimuovi(i),
                        ),
                      ),
                  ],
                ),
                attribuzione(vista.sfondo),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 132,
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: 'La mia posizione',
                onPressed: _cercaPosizione ? null : _vaiAllaPosizione,
                child: _cercaPosizione
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 32,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              punti.isEmpty
                                  ? 'Tocca la mappa per mettere il primo punto'
                                  : '${punti.length == 1 ? '1 punto' : '${punti.length} punti'}'
                                      '${lunghezza == null ? '' : ' · ${lunghezza.round()} m'}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Trascina un punto per spostarlo, tienilo premuto per toglierlo, '
                              'tocca + per inserirne uno in mezzo.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(punti),
                        child: const Text('Fatto'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Punto del tratto, numerato. Il trascinamento si legge dagli eventi del
/// dito (`Listener`), che arrivano anche mentre la mappa è bloccata; il
/// `GestureDetector` riconosce la pressione lunga e "consuma" il tocco,
/// così toccare un punto non ne aggiunge uno nuovo sulla mappa.
class _Maniglia extends StatelessWidget {
  const _Maniglia({
    required this.numero,
    required this.colore,
    required this.attivo,
    required this.premi,
    required this.trascina,
    required this.rilascia,
    required this.rimuovi,
  });

  final int numero;
  final Color colore;
  final bool attivo;
  final VoidCallback premi;
  final ValueChanged<Offset> trascina;
  final VoidCallback rilascia;
  final VoidCallback rimuovi;

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => premi(),
        onPointerMove: (e) => trascina(e.delta),
        onPointerUp: (_) => rilascia(),
        onPointerCancel: (_) => rilascia(),
        child: GestureDetector(
          onTap: () {},
          onLongPress: rimuovi,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: attivo ? 36 : 28,
              height: attivo ? 36 : 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colore,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black45)],
              ),
              child: Text(
                '$numero',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      );
}

/// Pulsante "+" a metà di un segmento.
class _Inserisci extends StatelessWidget {
  const _Inserisci({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Center(
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black54),
            ),
            child: const Icon(Icons.add, size: 14, color: Colors.black87),
          ),
        ),
      );
}
