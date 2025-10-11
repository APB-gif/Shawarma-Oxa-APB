import 'package:cloud_firestore/cloud_firestore.dart';

class Receta {
  final String id;
  final String nombre;
  final List<String> productos;
  final List<InsumoReceta> insumos;

  Receta({
    required this.id,
    required this.nombre,
    required this.productos,
    required this.insumos,
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'productos': productos,
        'insumos': insumos.map((e) => e.toMap()).toList(),
      };

  factory Receta.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Receta(
      id: doc.id,
      nombre: data['nombre'] ?? '',
      productos: (data['productos'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      insumos: (data['insumos'] as List<dynamic>? ?? [])
          .map((e) => InsumoReceta.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class InsumoReceta {
  final String nombre;
  final double cantidad;

  InsumoReceta({required this.nombre, required this.cantidad});

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'cantidad': cantidad,
      };

  factory InsumoReceta.fromMap(Map<String, dynamic> map) => InsumoReceta(
        nombre: map['nombre'] ?? '',
        cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0,
      );
}
