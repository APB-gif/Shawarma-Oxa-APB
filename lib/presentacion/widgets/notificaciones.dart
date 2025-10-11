// lib/presentacion/widgets/notificaciones.dart
import 'package:flutter/material.dart';

// Esta función se podrá llamar desde cualquier parte de la app.
/// Usa siempre el contexto de una pantalla principal con Scaffold.
/// Si llamas desde un modal, pásale el contexto del Scaffold principal.
void mostrarNotificacionElegante(
  BuildContext scaffoldContext,
  String mensaje, {
  bool esError = false,
  required GlobalKey<ScaffoldMessengerState>
      messengerKey, // Parámetro opcional para notificaciones de error
}) {
  // Determinamos el color y el ícono según si es un mensaje de éxito o error.
  final theme = Theme.of(scaffoldContext);
  final Color colorFondo = esError
      ? theme.colorScheme.errorContainer
      : theme.colorScheme.primaryContainer; // Un color sutil del tema
  final Color colorContenido = esError
      ? theme.colorScheme.onErrorContainer
      : theme.colorScheme.onPrimaryContainer;
  final IconData icono =
      esError ? Icons.error_outline : Icons.check_circle_outline;

  // Usar messengerKey si está disponible y tiene un ScaffoldMessenger activo
  final messenger = messengerKey.currentState;
  final snackBar = SnackBar(
    backgroundColor: colorFondo,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.0),
    ),
    margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0,
        80.0), // margen inferior para no tapar la barra de navegación
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

  if (messenger != null) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(snackBar);
    return;
  }
  // Fallback: usar el contexto si no hay messengerKey
  if (ScaffoldMessenger.maybeOf(scaffoldContext) != null) {
    ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
    ScaffoldMessenger.of(scaffoldContext).showSnackBar(snackBar);
  }
}
