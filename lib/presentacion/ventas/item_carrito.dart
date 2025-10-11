// lib/presentacion/ventas/item_carrito.dart

import 'package:shawarma_pos_nuevo/datos/modelos/producto.dart';

class ItemCarrito {
  final Producto producto;
  final String uniqueId;
  final String categoryName;
  String comentario;
  double precioEditable;

  ItemCarrito({
    required this.producto,
    required this.uniqueId,
    required this.categoryName,
    this.comentario = '',
  }) : precioEditable = producto.precio;
}