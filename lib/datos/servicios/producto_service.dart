
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/producto.dart';

/// Servicio unificado para **productos** (ventas y gastos).
/// - `tipo` en cada producto define a dónde pertenece: 'venta' o 'gasto'.
class ProductoService {
  final _col = FirebaseFirestore.instance.collection('productos');

  /// Función para disminuir el stock después de una venta
  Future<void> disminuirStock(String productoId, int cantidadVendida) async {
    final productoRef = _col.doc(productoId);
    final productoSnapshot = await productoRef.get();

    if (productoSnapshot.exists) {
      final producto = Producto.fromFirestore(productoSnapshot);
      final stockActual = producto.stock;

      if (stockActual >= cantidadVendida) {
        final nuevoStock = stockActual - cantidadVendida;
        await productoRef.update({'stock': nuevoStock});
        // También verificamos si se ha alcanzado el mínimo de stock
        if (nuevoStock <= producto.stockMinimo) {
          // Lógica para alertar sobre el bajo stock
          // Por ejemplo, podemos registrar un log o enviar una notificación
          print('¡Alerta! Producto con ID: $productoId tiene stock bajo');
        }
      }
    }
  }

  /// Lee todos los productos. Filtra por [tipo] si se especifica.
  Future<List<Producto>> getProductos({String? tipo}) async {
    Query<Map<String, dynamic>> q = _col;
    if (tipo != null) {
      q = q.where('tipo', isEqualTo: tipo);
    }
    try {
      final snap = await q.get();
      return snap.docs.map((d) => Producto.fromFirestore(d)).toList();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return <Producto>[];
      rethrow;
    }
  }

  /// Crea o actualiza automáticamente.
  Future<void> guardarProducto(Producto p) async {
    if (p.id.isEmpty) {
      final ref = _col.doc();
      await ref.set(p.copyWith(id: ref.id).toFirestore());
    } else {
      await _col.doc(p.id).set(p.toFirestore(), SetOptions(merge: true));
    }
    if (kDebugMode) print('[ProductoService] guardado ${p.id}');
  }

  Future<void> addProducto(Producto p) async {
    if (p.id.isEmpty) {
      final auto = _col.doc();
      await auto.set(p.copyWith(id: auto.id).toFirestore());
    } else {
      await _col.doc(p.id).set(p.toFirestore());
    }
  }

  Future<void> updateProducto(Producto p) async {
    await _col.doc(p.id).update(p.toFirestore());
  }

  Future<void> deleteProducto(String id) async {
    await _col.doc(id).delete();
  }
}
