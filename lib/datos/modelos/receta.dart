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
  final String?
      id; // id del documento en la colección 'insumos' (opcional, backward-compatible)
  final String nombre;
  final double cantidad;
  InsumoReceta({this.id, required this.nombre, required this.cantidad});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nombre': nombre,
        // Guardar cantidad con 2 decimales para consistencia en Firestore
        'cantidad': double.parse(cantidad.toStringAsFixed(2)),
      };

  factory InsumoReceta.fromMap(Map<String, dynamic> map) => InsumoReceta(
        id: map['id']?.toString(),
        nombre: map['nombre'] ?? '',
        cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0,
      );
}
