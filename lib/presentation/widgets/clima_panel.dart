import 'package:flutter/material.dart';
import 'package:weathwear/core/theme/app_theme.dart';
import 'package:weathwear/core/utils/formato_fecha.dart';
import 'package:weathwear/data/models/clima_model.dart';
import 'package:weathwear/presentation/widgets/weather_icon.dart';

/// Bloque superior de Hoy. [compacto] = true cuando el panel de recomendación
/// está abierto: ícono y temperatura pasan a una fila y desaparece la fecha.
class ClimaPanel extends StatelessWidget {
  const ClimaPanel({super.key, required this.clima, required this.compacto});

  final ClimaModel clima;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: compacto
            ? _Compacto(key: const ValueKey('compacto'), clima: clima)
            : _Completo(key: const ValueKey('completo'), clima: clima),
      ),
    );
  }
}

class _Completo extends StatelessWidget {
  const _Completo({super.key, required this.clima});
  final ClimaModel clima;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        _Caja(
          child: Text(
            etiquetaCabecera(DateTime.now()),
            style: text.headlineMedium,
          ),
        ),
        const SizedBox(height: 16),
        _Caja(
          height: 200,
          width: double.infinity,
          child: WeatherIcon(condicion: clima.condicion, size: 140),
        ),
        const SizedBox(height: 12),
        _Caja(
          child: Text(
            '${clima.temperatura.toStringAsFixed(1)}°C',
            style: text.displayMedium,
          ),
        ),
        const SizedBox(height: 8),
        _Caja(
          child: Text(
            clima.condicion,
            key: const Key('clima_condicion'),
            style: text.bodyMedium,
          ),
        ),
        const SizedBox(height: 24),
        _FilaDatos(clima: clima),
      ],
    );
  }
}

class _Compacto extends StatelessWidget {
  const _Compacto({super.key, required this.clima});
  final ClimaModel clima;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        SizedBox(
          height: 110,
          child: Row(
            children: [
              Expanded(
                child: _Caja(
                  height: double.infinity,
                  child: WeatherIcon(condicion: clima.condicion, size: 72),
                ),
              ),
              const SizedBox(width: 12),
              // Temperatura y estado del día comparten caja
              Expanded(
                child: _Caja(
                  height: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${clima.temperatura.toStringAsFixed(1)}°C',
                        style: text.headlineMedium,
                      ),
                      Text(
                        clima.condicion,
                        key: const Key('clima_condicion'),
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _FilaDatos(clima: clima),
      ],
    );
  }
}

/// Sensación / humedad / viento. Los campos nullable vienen vacíos en filas
/// anteriores a la migración v3.
class _FilaDatos extends StatelessWidget {
  const _FilaDatos({required this.clima});
  final ClimaModel clima;

  @override
  Widget build(BuildContext context) {
    final sensacion = clima.sensacionTermica;
    final viento = clima.vientoKmh;
    return Row(
      children: [
        Expanded(
          child: _DatoChip(
            label: 'Sensación',
            valor: sensacion == null
                ? '--'
                : '${sensacion.toStringAsFixed(1)}°C',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DatoChip(
            label: 'Humedad',
            valor: '${clima.humedad.toStringAsFixed(0)}%',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DatoChip(
            label: 'Viento',
            valor: viento == null ? '--' : '${viento.toStringAsFixed(0)} km/h',
          ),
        ),
      ],
    );
  }
}

class _DatoChip extends StatelessWidget {
  const _DatoChip({required this.label, required this.valor});
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Caja(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: text.bodySmall),
          const SizedBox(height: 4),
          Text(valor, style: text.titleSmall),
        ],
      ),
    );
  }
}

/// Caja redondeada con el color de panel del tema.
class _Caja extends StatelessWidget {
  const _Caja({
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.wColors.panel,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}
