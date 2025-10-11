import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo unificado para productos de **ventas** y **gastos**.
/// - Campo clave: [tipo] => 'venta' | 'gasto'
class Producto {
  final String id;
  final String nombre;
  final double precio;
  final String categoriaId;
  final String categoriaNombre;
  final String tipo; // 'venta' o 'gasto'
  final String? imagenUrl; // asset o downloadURL de Firebase Storage
  final int orden; // 👈 NUEVO: para ordenar dentro de la categoría
  final int stock; // NUEVO: cantidad en stock
  final int stockMinimo; // NUEVO: cantidad mínima de stock

  const Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.categoriaId,
    required this.categoriaNombre,
    this.tipo = 'venta',
    this.imagenUrl,
    this.orden = 999, // 👈 default alto = va al final si no está definido
    this.stock = 0, // NUEVO: valor predeterminado de 0
    this.stockMinimo = 5, // NUEVO: valor predeterminado de 5
  });

  /// Helpers robustos
  static double _asDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  static int _asInt(dynamic v, {int fallback = 999}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final n = int.tryParse(v);
      if (n != null) return n;
    }
    return fallback;
  }

  /// Construye desde un mapa (Firestore/JSON).
  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: (map['id'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      precio: _asDouble(map['precio']),
      categoriaId: (map['categoriaId'] ?? '').toString(),
      categoriaNombre: (map['categoriaNombre'] ?? '').toString(),
      tipo: (map['tipo'] ?? 'venta').toString(),
      imagenUrl: map['imagenUrl']?.toString(),
      orden: _asInt(map['orden'], fallback: 999), // 👈 lee 'orden' si existe
      stock: _asInt(map['stock'], fallback: 0), // NUEVO: lee 'stock'
      stockMinimo: _asInt(map['stockMinimo'], fallback: 5), // NUEVO: lee 'stockMinimo'
    );
  }

  /// Construye desde un DocumentSnapshot de Firestore.
  factory Producto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Producto.fromMap(<String, dynamic>{'id': doc.id, ...data});
  }

  /// Exporta a mapa (útil para cache/local).
  Map<String, dynamic> toMap({bool lean = false, bool includePrecio = true}) {
    final base = <String, dynamic> {
      'id': id,
      'nombre': nombre,
      'categoriaId': categoriaId,
      'categoriaNombre': categoriaNombre,
      'tipo': tipo,
      'orden': orden, // 👈 incluye orden
      'stock': stock, // NUEVO: incluye stock
      'stockMinimo': stockMinimo, // NUEVO: incluye stockMinimo
    };

    if (!lean) {
      base['imagenUrl'] = imagenUrl;
      base['precio'] = precio;
    } else {
      if (includePrecio) base['precio'] = precio;
    }
    return base;
  }

  /// Para guardar en Firestore.
  Map<String, dynamic> toFirestore() => <String, dynamic> {
        'nombre': nombre,
        'precio': precio,
        'categoriaId': categoriaId,
        'categoriaNombre': categoriaNombre,
        'tipo': tipo,
        'imagenUrl': imagenUrl,
        'orden': orden, // 👈 guarda orden
        'stock': stock, // NUEVO: guarda stock
        'stockMinimo': stockMinimo, // NUEVO: guarda stockMinimo
      };

  Producto copyWith({
    String? id,
    String? nombre,
    double? precio,
    String? categoriaId,
    String? categoriaNombre,
    String? tipo,
    String? imagenUrl,
    int? orden, // 👈 en copyWith
    int? stock, // NUEVO: en copyWith
    int? stockMinimo, // NUEVO: en copyWith
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      precio: precio ?? this.precio,
      categoriaId: categoriaId ?? this.categoriaId,
      categoriaNombre: categoriaNombre ?? this.categoriaNombre,
      tipo: tipo ?? this.tipo,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      orden: orden ?? this.orden,
      stock: stock ?? this.stock, // NUEVO: stock
      stockMinimo: stockMinimo ?? this.stockMinimo, // NUEVO: stockMinimo
    );
  }

  // Método para disminuir el stock
  Future<void> disminuirStock(int cantidad) async {
    if (stock < cantidad) {
      throw Exception("No hay suficiente stock para realizar esta venta");
    }
    // Actualizar en Firestore
    final ref = FirebaseFirestore.instance.collection('productos').doc(id);
    await ref.update({'stock': stock - cantidad});
  }
}
