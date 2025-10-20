import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/producto.dart';
import 'package:shawarma_pos_nuevo/datos/catalogo_gastos.dart' as local;

class ProductoGastosService {
  final CollectionReference<Producto> _productosRef = FirebaseFirestore.instance
      .collection('productos')
      .withConverter<Producto>(
        fromFirestore: (snapshots, _) => Producto.fromFirestore(snapshots),
        toFirestore: (producto, _) => producto.toFirestore(),
      );

  /// Obtiene los productos de tipo 'gasto' una sola vez.
  Future<List<Producto>> getProductos() async {
    try {
      final snapshot =
          await _productosRef.where('tipo', isEqualTo: 'gasto').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (_) {
      // Fallback duro local: aplanamos productsByCategory
      final List<Producto> out = [];
      local.CatalogoGastos.productsByCategory.forEach((_, list) {
        out.addAll(list);
      });
      return out;
    }
  }

  /// Guarda un producto de gasto (lo crea si es nuevo, lo actualiza si ya existe).
  Future<void> guardarProducto(Producto producto) async {
    if (producto.id.isEmpty) {
      await _productosRef.add(producto);
    } else {
      await _productosRef.doc(producto.id).update(producto.toFirestore());
    }
  }

  /// Elimina un producto de gasto por su ID.
  Future<void> eliminarProducto(String productoId) async {
    await _productosRef.doc(productoId).delete();
  }

  /// Disminuye el stock de un producto de gasto cuando se realice una venta.
  Future<void> disminuirStock(String productoId, int cantidadVendida) async {
    final productoRef = _productosRef.doc(productoId);
    final productoSnapshot = await productoRef.get();

    if (productoSnapshot.exists) {
      // Asegúrate de convertir el snapshot a Producto
      final producto = Producto.fromFirestore(
          productoSnapshot as DocumentSnapshot<Map<String, dynamic>>);
      final stockActual = producto.stock;

      // Verificar que haya suficiente stock
      if (stockActual >= cantidadVendida) {
        final nuevoStock = stockActual - cantidadVendida;
        await productoRef.update({'stock': nuevoStock});

        // Alerta si el stock está por debajo del mínimo
        if (nuevoStock <= producto.stockMinimo) {
          // Lógica para alertar sobre el bajo stock (puedes registrar un log o enviar una notificación)
          print(
              '¡Alerta! Producto de gasto con ID: $productoId tiene stock bajo');
        }
      }
    }
  }
}
