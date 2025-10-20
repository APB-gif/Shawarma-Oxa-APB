import 'package:cloud_firestore/cloud_firestore.dart';

class Categoria {
  final String id;
  final String nombre;

  /// 'venta' o 'gasto'
  final String tipo;
  final int orden;

  /// Puede ser URL https o un asset local. No nulo.
  final String iconAssetPath;
  final int stockMinimo; // Nuevo campo para controlar stock

  const Categoria({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.orden = 99,
    this.iconAssetPath = 'assets/icons/default.svg',
    this.stockMinimo = 10, // valor por defecto para el mínimo de stock
  });

  /// Para clonar con cambios puntuales
  Categoria copyWith({
    String? id,
    String? nombre,
    String? tipo,
    int? orden,
    String? iconAssetPath,
  }) {
    return Categoria(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      orden: orden ?? this.orden,
      iconAssetPath: iconAssetPath ?? this.iconAssetPath,
    );
  }

  /// Firestore -> Modelo
  factory Categoria.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return Categoria(
      id: snapshot.id,
      nombre: (data['nombre'] ?? '') as String,
      tipo: (data['tipo'] ?? 'venta') as String,
      orden: _asInt(data['orden'], fallback: 99),
      iconAssetPath:
          (data['iconAssetPath'] ?? 'assets/icons/default.svg') as String,
    );
  }

  /// Modelo -> Firestore
  Map<String, dynamic> toFirestore() => {
        'nombre': nombre,
        'tipo': tipo,
        'orden': orden,
        'iconAssetPath': iconAssetPath,
      };

  /// Json (opcional, por si lo usas en cache local)
  factory Categoria.fromJson(Map<String, dynamic> json) => Categoria(
        id: (json['id'] ?? '') as String,
        nombre: (json['nombre'] ?? '') as String,
        tipo: (json['tipo'] ?? 'venta') as String,
        orden: _asInt(json['orden'], fallback: 99),
        iconAssetPath:
            (json['iconAssetPath'] ?? 'assets/icons/default.svg') as String,
      );

  get descripcion => null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipo,
        'orden': orden,
        'iconAssetPath': iconAssetPath,
      };
}

/// Convierte dinámicos a int de forma segura
int _asInt(dynamic v, {required int fallback}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return fallback;
}
