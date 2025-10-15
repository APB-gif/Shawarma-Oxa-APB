import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/producto.dart';

import 'package:flutter/material.dart';

class AlmacenService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Obtiene todos los productos en el almacén
  Future<List<Producto>> obtenerProductosDelAlmacen() async {
    try {
      final snapshot = await _db.collection('productos').get();
      return snapshot.docs.map((d) => Producto.fromFirestore(d)).toList();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return <Producto>[];
      rethrow;
    }
  }

  // Obtiene un solo producto del almacén por su ID
  Future<Producto?> obtenerProductoPorId(String productoId) async {
    final doc = await _db.collection('productos').doc(productoId).get();
    if (doc.exists) {
      return Producto.fromFirestore(doc);
    }
    return null;
  }

  // Actualiza el stock de un producto
  Future<void> actualizarStock(String productoId, int nuevoStock) async {
    final ref = _db.collection('productos').doc(productoId);
    await ref.update({'stock': nuevoStock});
  }

  // Verifica si el stock de un producto está por debajo del mínimo
  Future<bool> verificarStockMinimo(String productoId) async {
    final producto = await obtenerProductoPorId(productoId);
    if (producto != null) {
      return producto.stock < producto.stockMinimo;
    }
    return false;
  }

  /// Descuenta insumos del almacén según la receta del producto vendido
  Future<void> descontarInsumosPorVenta(
      String productoId, int cantidadVendida) async {
    // 1. Buscar la receta que contenga el productoId en el array 'productos'
    final recetaSnap = await _db
        .collection('recetas')
        .where('productos', arrayContains: productoId)
        .get();
    if (recetaSnap.docs.isEmpty) return;
    final recetaData = recetaSnap.docs.first.data();
    final insumos = recetaData['insumos'] as List<dynamic>? ?? [];

    // 2. Por cada insumo, descontar del stock
    for (final insumo in insumos) {
      final nombreInsumo = insumo['nombre'] as String;
      final cantidadPorUnidad = (insumo['cantidad'] as num).toDouble();
      final cantidadTotal = cantidadPorUnidad * cantidadVendida;
      // Buscar el insumo por nombre
      final insumoSnap = await _db
          .collection('insumos')
          .where('nombre', isEqualTo: nombreInsumo)
          .get();
      if (insumoSnap.docs.isEmpty) continue;
      final insumoRef = insumoSnap.docs.first.reference;

      await _db.runTransaction((transaction) async {
        final insumoSnapshot = await transaction.get(insumoRef);
        if (!insumoSnapshot.exists) return;
        final stockActual = (insumoSnapshot['stockActual'] as num).toDouble();
        final nuevoStock = stockActual - cantidadTotal;
        transaction.update(insumoRef, {'stockActual': nuevoStock});
      });
    }
  }
}
