import 'producto.dart';

class Almacen {
  final String id;
  final String nombre;
  final List<Producto> productos;
  final double stockTotal;
  final double stockMinimo;

  const Almacen({
    required this.id,
    required this.nombre,
    required this.productos,
    required this.stockTotal,
    required this.stockMinimo,
  });

  // Helper para calcular el stock total (a partir de los productos en el almacén)
  double calcularStockTotal() {
    double total = 0.0;
    for (var producto in productos) {
      total += producto.precio;  // Aquí se debería ajustar con la cantidad real de cada producto.
    }
    return total;
  }

  // Detecta si el stock ha llegado al mínimo
  bool necesitaReabastecer() {
    return stockTotal <= stockMinimo;
  }

  // Construcción desde mapa (Firestore)
  factory Almacen.fromMap(Map<String, dynamic> map) {
    return Almacen(
      id: (map['id'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      productos: (map['productos'] as List).map((e) => Producto.fromMap(e)).toList(),
      stockTotal: (map['stockTotal'] ?? 0.0).toDouble(),
      stockMinimo: (map['stockMinimo'] ?? 0.0).toDouble(),
    );
  }

  // Convertir el objeto a mapa para Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'productos': productos.map((e) => e.toMap()).toList(),
      'stockTotal': stockTotal,
      'stockMinimo': stockMinimo,
    };
  }
}
