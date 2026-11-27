import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Piccole scelte dell'interfaccia da ricordare tra un avvio e l'altro:
/// la sezione aperta, la mappa di sfondo, la colorazione e l'inquadratura
/// della mappa.
///
/// Android può chiudere l'app quando resta a lungo in secondo piano; alla
/// riapertura l'app riparte da zero. Senza questa memoria tornerebbe sempre
/// alla prima sezione con la mappa nella vista predefinita.
///
/// Non sono dati del diario: stanno fuori dal database e non entrano nel
/// backup.
abstract interface class MemoriaUi {
  Object? leggi(String chiave);

  /// [valore] può essere `int`, `double`, `bool` o `String`.
  Future<void> scrivi(String chiave, Object valore);
}

/// Chiavi usate nella [MemoriaUi].
abstract final class ChiaviMemoria {
  static const sezione = 'home.sezione';
  static const sfondo = 'mappa.sfondo';
  static const colorazione = 'mappa.colorazione';
  static const latitudine = 'mappa.latitudine';
  static const longitudine = 'mappa.longitudine';
  static const zoom = 'mappa.zoom';
}

/// Memoria solo in RAM: si perde alla chiusura dell'app. È quella usata
/// nei test e finché `main` non la sostituisce con [MemoriaUiSulTelefono].
class MemoriaUiInRam implements MemoriaUi {
  MemoriaUiInRam([Map<String, Object>? iniziale]) : valori = {...?iniziale};

  final Map<String, Object> valori;

  @override
  Object? leggi(String chiave) => valori[chiave];

  @override
  Future<void> scrivi(String chiave, Object valore) async => valori[chiave] = valore;
}

/// Memoria salvata sul telefono con le preferenze di Android
/// (`shared_preferences`).
class MemoriaUiSulTelefono implements MemoriaUi {
  MemoriaUiSulTelefono(this._preferenze);

  final SharedPreferences _preferenze;

  /// Le preferenze si caricano prima di avviare l'interfaccia, così la
  /// prima schermata sa già quale sezione mostrare.
  static Future<MemoriaUiSulTelefono> carica() async =>
      MemoriaUiSulTelefono(await SharedPreferences.getInstance());

  @override
  Object? leggi(String chiave) => _preferenze.get(chiave);

  @override
  Future<void> scrivi(String chiave, Object valore) async {
    switch (valore) {
      case int v:
        await _preferenze.setInt(chiave, v);
      case double v:
        await _preferenze.setDouble(chiave, v);
      case bool v:
        await _preferenze.setBool(chiave, v);
      case String v:
        await _preferenze.setString(chiave, v);
      default:
        throw ArgumentError.value(valore, 'valore', 'tipo non supportato');
    }
  }
}

final memoriaUiProvider = Provider<MemoriaUi>((ref) => MemoriaUiInRam());

/// Valore di un enum salvato per nome; `null` se manca o non esiste più
/// (per esempio dopo aver rinominato un valore in un aggiornamento).
T? enumDaMemoria<T extends Enum>(MemoriaUi memoria, String chiave, List<T> valori) {
  final nome = memoria.leggi(chiave);
  for (final v in valori) {
    if (v.name == nome) return v;
  }
  return null;
}
