// lib/presentacion/widgets/notificaciones.dart
import 'package:flutter/material.dart';
import 'package:shawarma_pos_nuevo/main.dart';

// Esta función se podrá llamar desde cualquier parte de la app.
/// Usa siempre el contexto de una pantalla principal con Scaffold.
/// Si llamas desde un modal, pásale el contexto del Scaffold principal.
void mostrarNotificacionElegante(
  BuildContext scaffoldContext,
  String mensaje, {
  bool esError = false,
  required GlobalKey<ScaffoldMessengerState> messengerKey,
}) {
  // Preferimos derivar el tema desde un contexto SEGURO asociado al ScaffoldMessenger global.
  // Evita mirar ancestros desde un BuildContext potencialmente desactivado.
  final ctxForTheme = messengerKey.currentContext; // puede ser null si aún no montó

  // Paleta por defecto si no hay contexto seguro disponible.
  Color bgDefault(bool error) => error ? const Color(0xFFFFEAEA) : const Color(0xFFE7F0FF);
  Color fgDefault(bool error) => error ? const Color(0xFF8B0000) : const Color(0xFF003366);

  late final Color colorFondo;
  late final Color colorContenido;
  final IconData icono = esError ? Icons.error_outline : Icons.check_circle_outline;

  if (ctxForTheme != null) {
    final theme = Theme.of(ctxForTheme);
    colorFondo = esError ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer;
    colorContenido = esError ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer;
  } else {
    // Sin tema disponible, usar colores neutros y legibles.
    colorFondo = bgDefault(esError);
    colorContenido = fgDefault(esError);
  }

  final snackBar = SnackBar(
    backgroundColor: colorFondo,
    behavior: SnackBarBehavior.fixed,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
    dismissDirection: DismissDirection.down,
    elevation: 4.0,
    content: Row(
      children: [
        Icon(icono, color: colorContenido),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            mensaje,
            style: TextStyle(
              color: colorContenido,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ],
    ),
  );

  // Intentar con el messenger provisto; si no existe, usar el messenger global de la app.
  final messenger = messengerKey.currentState ?? scaffoldMessengerKey.currentState;
  if (messenger != null) {
    try {
      messenger.hideCurrentSnackBar();
    } catch (_) {}
    messenger.showSnackBar(snackBar);
    return;
  }

  // Si no hay ningún messenger disponible aún (muy temprano en el ciclo de vida),
  // evita hacer lookup de ancestros con el contexto recibido. Mejor no mostrar que crashear.
  // Opcional: podríamos reintentar en el próximo frame.
}
