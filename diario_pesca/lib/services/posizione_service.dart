import 'package:geolocator/geolocator.dart';

import '../models/territorio/coordinata.dart';

/// La posizione non è disponibile: localizzazione spenta, permesso negato
/// o nessun segnale entro il tempo massimo. [messaggio] è per l'utente.
class PosizioneNonDisponibile implements Exception {
  const PosizioneNonDisponibile(this.messaggio);
  final String messaggio;

  @override
  String toString() => messaggio;
}

/// Posizione attuale del telefono, per centrare la mappa. Il permesso viene
/// chiesto solo la prima volta che serve.
class PosizioneService {
  const PosizioneService();

  Future<Coordinata> attuale() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const PosizioneNonDisponibile('La localizzazione del telefono è spenta.');
    }
    var permesso = await Geolocator.checkPermission();
    if (permesso == LocationPermission.denied) {
      permesso = await Geolocator.requestPermission();
    }
    if (permesso == LocationPermission.denied) {
      throw const PosizioneNonDisponibile('Permesso di posizione non concesso.');
    }
    if (permesso == LocationPermission.deniedForever) {
      throw const PosizioneNonDisponibile(
        'Permesso di posizione negato: si può concedere dalle impostazioni dell\'app.',
      );
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return Coordinata(ordine: 0, latitudine: p.latitude, longitudine: p.longitude);
    } catch (_) {
      throw const PosizioneNonDisponibile('Posizione non trovata: riprova all\'aperto.');
    }
  }
}
