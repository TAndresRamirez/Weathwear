String _dos(int n) => n.toString().padLeft(2, '0');

String formatearFecha(DateTime d) =>
    '${_dos(d.day)}/${_dos(d.month)}/${d.year}';

String formatearHora(DateTime d) => '${_dos(d.hour)}:${_dos(d.minute)}';

String formatearFechaHora(DateTime d) =>
    '${formatearFecha(d)} ${formatearHora(d)}';

/// "Hoy", "Ayer" o dd/MM/yyyy. [hoy] es inyectable para tests.
String etiquetaDia(DateTime fecha, {DateTime? hoy}) {
  final ref = hoy ?? DateTime.now();
  // En UTC para que el cambio de horario de verano no altere el conteo de días
  final dia = DateTime.utc(fecha.year, fecha.month, fecha.day);
  final hoyDia = DateTime.utc(ref.year, ref.month, ref.day);
  final diff = hoyDia.difference(dia).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  return formatearFecha(fecha);
}
