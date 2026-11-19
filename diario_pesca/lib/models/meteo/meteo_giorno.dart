import '../enums.dart';

/// Dati meteo giornalieri di una cella. Valori assenti nel servizio sono
/// `null`. Unità: mm, °C, hPa (al livello del mare), km/h, gradi (0–360).
class MeteoGiorno {
  final int? cellaId;
  final DateTime data;
  final double? pioggiaMm;
  final double? tempMin;
  final double? tempMax;
  final double? pressioneMedia;
  final double? ventoMax;
  final double? rafficaMax;
  final int? direzioneVento;
  final FonteMeteo fonte;

  const MeteoGiorno({
    this.cellaId,
    required this.data,
    this.pioggiaMm,
    this.tempMin,
    this.tempMax,
    this.pressioneMedia,
    this.ventoMax,
    this.rafficaMax,
    this.direzioneVento,
    required this.fonte,
  });

  MeteoGiorno copyWith({
    int? cellaId,
    DateTime? data,
    double? pioggiaMm,
    double? tempMin,
    double? tempMax,
    double? pressioneMedia,
    double? ventoMax,
    double? rafficaMax,
    int? direzioneVento,
    FonteMeteo? fonte,
  }) {
    return MeteoGiorno(
      cellaId: cellaId ?? this.cellaId,
      data: data ?? this.data,
      pioggiaMm: pioggiaMm ?? this.pioggiaMm,
      tempMin: tempMin ?? this.tempMin,
      tempMax: tempMax ?? this.tempMax,
      pressioneMedia: pressioneMedia ?? this.pressioneMedia,
      ventoMax: ventoMax ?? this.ventoMax,
      rafficaMax: rafficaMax ?? this.rafficaMax,
      direzioneVento: direzioneVento ?? this.direzioneVento,
      fonte: fonte ?? this.fonte,
    );
  }

  @override
  String toString() =>
      'MeteoGiorno(cellaId: $cellaId, data: $data, pioggiaMm: $pioggiaMm, fonte: $fonte)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeteoGiorno &&
          other.cellaId == cellaId &&
          other.data == data &&
          other.pioggiaMm == pioggiaMm &&
          other.tempMin == tempMin &&
          other.tempMax == tempMax &&
          other.pressioneMedia == pressioneMedia &&
          other.ventoMax == ventoMax &&
          other.rafficaMax == rafficaMax &&
          other.direzioneVento == direzioneVento &&
          other.fonte == fonte;

  @override
  int get hashCode => Object.hash(
        cellaId,
        data,
        pioggiaMm,
        tempMin,
        tempMax,
        pressioneMedia,
        ventoMax,
        rafficaMax,
        direzioneVento,
        fonte,
      );
}
