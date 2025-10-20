import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/orden.dart';

class ServicioOrden {
  // Esta es la clave donde se guardarán todas las ventas completadas.
  // Es la misma clave que nuestro 'ServicioVentas' buscará.
  static const _key = 'ordenes_guardadas';

  Future<void> save(Orden orden) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Cargar la lista de ventas que ya existía
      final List<String> ventasGuardadasJson = prefs.getStringList(_key) ?? [];

      // 2. Convertir la nueva orden a texto JSON y añadirla a la lista
      ventasGuardadasJson.add(jsonEncode(orden.toJson()));

      // 3. Guardar la lista actualizada de vuelta en la memoria del teléfono
      await prefs.setStringList(_key, ventasGuardadasJson);

      print('Orden #${orden.id} guardada exitosamente en SharedPreferences.');
    } catch (e) {
      print('Error al guardar la orden: $e');
      // Aquí podrías manejar el error, quizás mostrar una notificación al usuario.
    }
  }
}
