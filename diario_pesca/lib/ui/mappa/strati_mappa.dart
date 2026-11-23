import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/territorio/coordinata.dart';
import '../state/mappa_state.dart';
import 'colori_mappa.dart';

// Pezzi comuni alla mappa degli spot e alla schermata di disegno.

/// Identifica l'app presso i server delle tessere, come chiede la politica
/// d'uso di OpenStreetMap.
const _pacchettoApp = 'com.example.diario_pesca';

/// Centro della mappa quando non c'è ancora nessuno spot (valli bergamasche).
final centroPredefinito = LatLng(45.85, 9.72);
const zoomPredefinito = 10.0;
const zoomMassimo = 19.0;

LatLng latLng(Coordinata c) => LatLng(c.latitudine, c.longitudine);

/// Tessere della mappa di sfondo. Le tessere scaricate restano in una cache
/// sul telefono (cache integrata di flutter_map, attiva di default): le
/// zone già viste si vedono anche senza rete.
Widget stratoSfondo(Sfondo sfondo) => switch (sfondo) {
      Sfondo.topografica => TileLayer(
          urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: _pacchettoApp,
          maxNativeZoom: 17,
          maxZoom: zoomMassimo,
        ),
      Sfondo.stradale => TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: _pacchettoApp,
          maxNativeZoom: 19,
          maxZoom: zoomMassimo,
        ),
    };

/// Crediti richiesti dalle licenze dei dati e dello stile della mappa.
Widget attribuzione(Sfondo sfondo) => RichAttributionWidget(
      attributions: [
        const TextSourceAttribution('Dati © contributori di OpenStreetMap'),
        if (sfondo == Sfondo.topografica) ...[
          const TextSourceAttribution('Rilievi: SRTM'),
          const TextSourceAttribution('Stile © OpenTopoMap (CC-BY-SA)'),
        ],
      ],
    );

/// Linea di un divieto: rosso scuro tratteggiato.
Polyline<Object> lineaDivieto(List<Coordinata> punti, {Object? valore, double opacita = 1}) => Polyline<Object>(
      points: [for (final p in punti) latLng(p)],
      color: coloreDivieto.withValues(alpha: opacita),
      strokeWidth: 4,
      pattern: StrokePattern.dashed(segments: const [12, 8]),
      hitValue: valore,
    );

/// Linea di uno spot: colore della vista con un bordo scuro, così anche le
/// linee chiare (bianche, gialle) si vedono sulla mappa.
Polyline<Object> lineaSpot(
  List<Coordinata> punti,
  Color colore, {
  Object? valore,
  double opacita = 1,
  double spessore = 5,
}) =>
    Polyline<Object>(
      points: [for (final p in punti) latLng(p)],
      color: colore.withValues(alpha: opacita),
      strokeWidth: spessore,
      borderStrokeWidth: 1.5,
      borderColor: Colors.black.withValues(alpha: 0.6 * opacita),
      hitValue: valore,
    );

/// Segnaposto di uno spot (o di un divieto) con un solo punto.
class Segnaposto extends StatelessWidget {
  const Segnaposto({super.key, required this.colore, this.divieto = false});

  final Color colore;
  final bool divieto;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: colore,
          shape: divieto ? BoxShape.rectangle : BoxShape.circle,
          border: Border.all(color: Colors.black54, width: 1.5),
        ),
        child: divieto
            ? const Icon(Icons.block, size: 14, color: Colors.white)
            : const SizedBox.expand(),
      );
}

/// Punto blu della posizione del telefono.
Marker segnaPosizione(Coordinata posizione) => Marker(
      point: latLng(posizione),
      width: 22,
      height: 22,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF2962FF),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
        ),
      ),
    );

/// Inquadratura iniziale: tutti i [punti] se ce ne sono almeno due
/// diversi, altrimenti il punto o il centro predefinito.
({CameraFit? adatta, LatLng centro, double zoom}) inquadratura(List<Coordinata> punti) {
  if (punti.isEmpty) return (adatta: null, centro: centroPredefinito, zoom: zoomPredefinito);
  final primo = latLng(punti.first);
  final tuttiUguali = punti.every(
    (p) => p.latitudine == punti.first.latitudine && p.longitudine == punti.first.longitudine,
  );
  if (tuttiUguali) return (adatta: null, centro: primo, zoom: 15);
  return (
    adatta: CameraFit.coordinates(
      coordinates: [for (final p in punti) latLng(p)],
      padding: const EdgeInsets.all(48),
      maxZoom: 16,
    ),
    centro: primo,
    zoom: zoomPredefinito,
  );
}
