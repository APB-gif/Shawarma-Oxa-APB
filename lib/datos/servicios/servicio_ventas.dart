import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/orden.dart';

class ServicioVentas {
  final CollectionReference<Map<String, dynamic>> _ventasCollection =
      FirebaseFirestore.instance.collection('ventas');

  /// Guarda una venta en Firestore eliminando:
  /// - item.comentario
  /// - item.producto.descripcion
  /// - item.producto.imagenUrl
  /// - item.producto.categoriaNombre
  /// - item.producto.tipo
  /// Reactivado: se conserva item.producto.categoriaId (si existe)
  Future<void> registrarVenta(Orden nuevaOrden) async {
    try {
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(nuevaOrden.toJson());

      final items = (data['items'] as List?) ?? const [];
      for (final it in items) {
        if (it is Map<String, dynamic>) {
          // Fuera comentario
          it.remove('comentario');

          // Producto "lean"
          final prod = it['producto'];
          if (prod is Map<String, dynamic>) {
            prod.remove('descripcion');
            prod.remove('imagenUrl');
            prod.remove('categoriaNombre');
            prod.remove('tipo');
            // OJO: categoriaId se mantiene
          }
        }
      }

      await _ventasCollection.doc(nuevaOrden.id).set(data);

      if (kDebugMode) {
        print('Venta registrada (lean con categoriaId) en Firebase.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al registrar venta: $e');
      }
      rethrow;
    }
  }

  Future<void> eliminarVentasDeSesion(String cajaId) async {
    try {
      final query =
          await _ventasCollection.where('cajaId', isEqualTo: cajaId).get();
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (kDebugMode) {
        print('Ventas de la sesión $cajaId eliminadas.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al eliminar ventas de la sesión: $e');
      }
      rethrow;
    }
  }
}
