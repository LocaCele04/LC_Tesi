import '../enums.dart';

/// Dati meteo orari di una cella. [dataOra] è in UTC (per mostrarla usare
/// `toLocal()`): così il cambio dell'ora legale non crea ore mancanti o
/// ripetute. Valori assenti nel servizio sono `null`. Unità: mm, °C, hPa
/// (al livello del mare), km/h, gradi (0–360).
class MeteoOra {
  final int? cellaId;
  final DateTime dataOra;
  final double? pioggiaMm;
  final double? temperatura;
  final double? pressione;
  final double? vento;
  final double? raffica;
  final int? direzioneVento;
  final FonteMeteo fonte;

  const MeteoOra({
    this.cellaId,
    required this.dataOra,
    this.pioggiaMm,
    this.temperatura,
    this.pressione,
    this.vento,
    this.raffica,
    this.direzioneVento,
    required this.fonte,
  });

  MeteoOra copyWith({
    int? cellaId,
    DateTime? dataOra,
    double? pioggiaMm,
    double? temperatura,
    double? pressione,
    double? vento,
    double? raffica,
    int? direzioneVento,
    FonteMeteo? fonte,
  }) {
    return MeteoOra(
      cellaId: cellaId ?? this.cellaId,
      dataOra: dataOra ?? this.dataOra,
      pioggiaMm: pioggiaMm ?? this.pioggiaMm,
      temperatura: temperatura ?? this.temperatura,
      pressione: pressione ?? this.pressione,
      vento: vento ?? this.vento,
      raffica: raffica ?? this.raffica,
      direzioneVento: direzioneVento ?? this.direzioneVento,
      fonte: fonte ?? this.fonte,
    );
  }

  @override
  String toString() =>
      'MeteoOra(cellaId: $cellaId, dataOra: $dataOra, pioggiaMm: $pioggiaMm, fonte: $fonte)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeteoOra &&
          other.cellaId == cellaId &&
          other.dataOra == dataOra &&
          other.pioggiaMm == pioggiaMm &&
          other.temperatura == temperatura &&
          other.pressione == pressione &&
          other.vento == vento &&
          other.raffica == raffica &&
          other.direzioneVento == direzioneVento &&
          other.fonte == fonte;

  @override
  int get hashCode => Object.hash(
        cellaId,
        dataOra,
        pioggiaMm,
        temperatura,
        pressione,
        vento,
        raffica,
        direzioneVento,
        fonte,
      );
}
