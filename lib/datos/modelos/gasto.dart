
// lib/datos/modelos/gasto.dart
import 'dart:convert';

class GastoItem {
  final String id;          // opcional: sku o uuid de item
  final String nombre;
  final double precio;      // precio unitario
  final double cantidad;    // cantidad
  final String? categoriaId;

  const GastoItem({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.cantidad,
    this.categoriaId,
  });

  double get subtotal => (precio * cantidad);

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'precio': precio,
        'cantidad': cantidad,
        if (categoriaId != null && categoriaId!.trim().isNotEmpty) 'categoriaId': categoriaId,
      };

  factory GastoItem.fromJson(Map<String, dynamic> json) => GastoItem(
        id: json['id']?.toString() ?? '',
        nombre: json['nombre']?.toString() ?? '',
        precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
        cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0.0,
        categoriaId: json['categoriaId']?.toString(),
      );
}

class Gasto {
  final String? id;
  final String? cajaId; // para compatibilidad si luego quieres asociarlo a una caja
  final String? tipo; // p.ej. 'insumos_apertura'
  final DateTime fecha;
  final String proveedor;
  final String descripcion;
  final List<GastoItem> items;
  final Map<String, double> pagos; // método -> monto
  final double total;
  final String usuarioId;
  final String usuarioNombre;

  const Gasto({
    this.id,
    this.cajaId,
    this.tipo,
    required this.fecha,
    required this.proveedor,
    required this.descripcion,
    required this.items,
    required this.pagos,
    required this.total,
    required this.usuarioId,
    required this.usuarioNombre,
  });

  Gasto copyWith({
    String? id,
    String? cajaId,
    String? tipo,
    DateTime? fecha,
    String? proveedor,
    String? descripcion,
    List<GastoItem>? items,
    Map<String, double>? pagos,
    double? total,
    String? usuarioId,
    String? usuarioNombre,
  }) =>
      Gasto(
        id: id ?? this.id,
        cajaId: cajaId ?? this.cajaId,
        tipo: tipo ?? this.tipo,
        fecha: fecha ?? this.fecha,
        proveedor: proveedor ?? this.proveedor,
        descripcion: descripcion ?? this.descripcion,
        items: items ?? this.items,
        pagos: pagos ?? this.pagos,
        total: total ?? this.total,
        usuarioId: usuarioId ?? this.usuarioId,
        usuarioNombre: usuarioNombre ?? this.usuarioNombre,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cajaId': cajaId,
    'tipo': tipo,
        'fecha': fecha.toIso8601String(),
        'proveedor': proveedor,
        'descripcion': descripcion,
        'items': items.map((e) => e.toJson()).toList(),
        'pagos': pagos,
        'total': total,
        'usuarioId': usuarioId,
        'usuarioNombre': usuarioNombre,
      };

  factory Gasto.fromJson(Map<String, dynamic> json) => Gasto(
        id: json['id']?.toString(),
        cajaId: json['cajaId']?.toString(),
    tipo: json['tipo']?.toString(),
        fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(),
        proveedor: json['proveedor']?.toString() ?? '',
        descripcion: json['descripcion']?.toString() ?? '',
        items: (json['items'] as List? ?? []).map((e) => GastoItem.fromJson(Map<String, dynamic>.from(e))).toList(),
        pagos: Map<String, double>.from((json['pagos'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))),
        total: (json['total'] as num?)?.toDouble() ?? 0.0,
        usuarioId: json['usuarioId']?.toString() ?? '',
        usuarioNombre: json['usuarioNombre']?.toString() ?? '',
      );

  // ===== Persistencia Firebase (normaliza a 2 decimales) =====
  int _toCents(num v) => (v * 100).round();
  double _fromCents(int c) => c / 100.0;

  Map<String, dynamic> toFirestore() {
    final itemsNorm = items
        .map((e) => {
              'id': e.id,
              'nombre': e.nombre,
              'precio': _fromCents(_toCents(e.precio)),
              'cantidad': _fromCents(_toCents(e.cantidad)),
              if (e.categoriaId != null && e.categoriaId!.trim().isNotEmpty) 'categoriaId': e.categoriaId,
            })
        .toList();

    final pagosNorm = {for (final e in pagos.entries) e.key: _fromCents(_toCents(e.value))};

    return {
      if (id != null) 'id': id,
      if (cajaId != null) 'cajaId': cajaId,
      if (tipo != null) 'tipo': tipo,
      'fecha': fecha,
      'proveedor': proveedor,
      'descripcion': descripcion,
      'items': itemsNorm,
      'pagos': pagosNorm,
      'total': _fromCents(_toCents(total)),
      'usuarioId': usuarioId,
      'usuarioNombre': usuarioNombre,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  static Gasto fromFirestore(String id, Map<String, dynamic> data) {
    return Gasto.fromJson({'id': id, ...data, 'fecha': (data['fecha'] is DateTime) ? (data['fecha'] as DateTime).toIso8601String() : data['fecha']});
  }
}

String encodeGastos(List<Gasto> list) => jsonEncode(list.map((e) => e.toJson()).toList());

List<Gasto> decodeGastos(String jsonStr) => (jsonDecode(jsonStr) as List).map((e) => Gasto.fromJson(Map<String, dynamic>.from(e))).toList();
