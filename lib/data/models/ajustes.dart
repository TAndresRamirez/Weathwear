import 'package:flutter/material.dart' show ThemeMode;

enum FormatoFecha { diaMesAnio, mesDiaAnio }

enum VistaInicial { hoy1, hoy2 }

enum UnidadTemperatura { celsius, fahrenheit }

enum UnidadViento { kmh, mph }

/// Preferencias del usuario. Inmutable; se modifica con [copyWith].
class Ajustes {
  final ThemeMode tema;
  final bool usarGps;
  final FormatoFecha formatoFecha;
  final VistaInicial vistaInicial;
  final UnidadTemperatura unidadTemperatura;
  final UnidadViento unidadViento;

  const Ajustes({
    this.tema = ThemeMode.system,
    this.usarGps = true,
    this.formatoFecha = FormatoFecha.diaMesAnio,
    this.vistaInicial = VistaInicial.hoy1,
    this.unidadTemperatura = UnidadTemperatura.celsius,
    this.unidadViento = UnidadViento.kmh,
  });

  Ajustes copyWith({
    ThemeMode? tema,
    bool? usarGps,
    FormatoFecha? formatoFecha,
    VistaInicial? vistaInicial,
    UnidadTemperatura? unidadTemperatura,
    UnidadViento? unidadViento,
  }) => Ajustes(
    tema: tema ?? this.tema,
    usarGps: usarGps ?? this.usarGps,
    formatoFecha: formatoFecha ?? this.formatoFecha,
    vistaInicial: vistaInicial ?? this.vistaInicial,
    unidadTemperatura: unidadTemperatura ?? this.unidadTemperatura,
    unidadViento: unidadViento ?? this.unidadViento,
  );

  Map<String, Object?> toJson() => {
    'tema': tema.name,
    'usarGps': usarGps,
    'formatoFecha': formatoFecha.name,
    'vistaInicial': vistaInicial.name,
    'unidadTemperatura': unidadTemperatura.name,
    'unidadViento': unidadViento.name,
  };

  /// Tolerante: una clave ausente o con un valor desconocido (por ejemplo,
  /// de una versión futura de la app) cae al valor por defecto.
  factory Ajustes.fromJson(Map<String, dynamic> json) {
    const d = Ajustes();
    T porNombre<T extends Enum>(List<T> valores, String clave, T porDefecto) =>
        valores.asNameMap()[json[clave]] ?? porDefecto;

    return Ajustes(
      tema: porNombre(ThemeMode.values, 'tema', d.tema),
      usarGps: json['usarGps'] is bool ? json['usarGps'] as bool : d.usarGps,
      formatoFecha: porNombre(
        FormatoFecha.values,
        'formatoFecha',
        d.formatoFecha,
      ),
      vistaInicial: porNombre(
        VistaInicial.values,
        'vistaInicial',
        d.vistaInicial,
      ),
      unidadTemperatura: porNombre(
        UnidadTemperatura.values,
        'unidadTemperatura',
        d.unidadTemperatura,
      ),
      unidadViento: porNombre(
        UnidadViento.values,
        'unidadViento',
        d.unidadViento,
      ),
    );
  }
}
