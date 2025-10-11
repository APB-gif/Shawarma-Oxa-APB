// lib/datos/modelos/venta.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/producto.dart';

/// ===== Helpers locales (tolerantes de tipos) =====
double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

DateTime _asDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

Map<String, double> _toStringDoubleMap(dynamic raw) {
  final out = <String, double>{};
  if (raw is Map) {
    raw.forEach((k, v) => out[k.toString()] = _asDouble(v));
  }
  return out;
}

/// ==================================================

class VentaItem {
  final Producto producto;
  final String uniqueId;
  double precioEditable;
  String comentario;

  VentaItem({
    required this.producto,
    required this.uniqueId,
    required this.precioEditable,
    this.comentario = '',
  });

  factory VentaItem.fromMap(Map<String, dynamic> map) {
    final prodRaw = map['producto'];
    final prodMap = (prodRaw is Map) ? Map<String, dynamic>.from(prodRaw) : <String, dynamic>{};
    return VentaItem(
      producto: Producto.fromMap(prodMap),
      uniqueId: (map['uniqueId'] ?? '').toString(),
      precioEditable: _asDouble(map['precioEditable']),
      comentario: (map['comentario'] ?? '').toString(),
    );
  }

  /// Si [leanProducto] es true, enviará el producto "ligero" SIN precio de catálogo.
  Map<String, dynamic> toMap({bool leanProducto = false}) {
    return {
      'producto': leanProducto
          ? producto.toMap(lean: true, includePrecio: false)
          : producto.toMap(lean: false),
      'uniqueId': uniqueId,
      'precioEditable': precioEditable,
      'comentario': comentario,
    };
  }
}

class Venta {
  final String id;
  final String cajaId;
  final DateTime fecha;
  final List<VentaItem> items;
  final double total;
  final Map<String, double> pagos;
  final String usuarioId;
  final String usuarioNombre;

  Venta({
    required this.id,
    required this.cajaId,
    required this.fecha,
    required this.items,
    required this.total,
    required this.pagos,
    required this.usuarioId,
    required this.usuarioNombre,
  });

  factory Venta.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    final rawItems = (data['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<dynamic>()
        .map((e) => VentaItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return Venta(
      id: doc.id,
      cajaId: (data['cajaId'] ?? '').toString(),
      fecha: _asDate(data['fecha']),
      items: items,
      total: _asDouble(data['total']),
      pagos: _toStringDoubleMap(data['pagos']),
      usuarioId: (data['usuarioId'] ?? '').toString(),
      usuarioNombre: (data['usuarioNombre'] ?? '').toString(),
    );
  }

  Venta copyWith({
    String? id,
    String? cajaId,
    DateTime? fecha,
    List<VentaItem>? items,
    double? total,
    Map<String, double>? pagos,
    String? usuarioId,
    String? usuarioNombre,
  }) {
    return Venta(
      id: id ?? this.id,
      cajaId: cajaId ?? this.cajaId,
      fecha: fecha ?? this.fecha,
      items: items ?? this.items,
      total: total ?? this.total,
      pagos: pagos ?? this.pagos,
      usuarioId: usuarioId ?? this.usuarioId,
      usuarioNombre: usuarioNombre ?? this.usuarioNombre,
    );
  }

  /// Para Firebase (cierre de caja, etc.).
  Map<String, dynamic> toFirestore() => {
        'cajaId': cajaId,
        'fecha': Timestamp.fromDate(fecha),
        'items': items.map((i) => i.toMap(leanProducto: true)).toList(),
        'total': total,
        'pagos': pagos,
        'usuarioId': usuarioId,
        'usuarioNombre': usuarioNombre,
      };

  /// Para persistencia local (SharedPreferences/JSON).
  Map<String, dynamic> toJson() => {
        'id': id,
        'cajaId': cajaId,
        'fecha': fecha.toIso8601String(),
        'items': items.map((i) => i.toMap(leanProducto: false)).toList(),
        'total': total,
        'pagos': pagos,
        'usuarioId': usuarioId,
        'usuarioNombre': usuarioNombre,
      };

  factory Venta.fromJson(Map<String, dynamic> json) => Venta(
        id: (json['id'] ?? '').toString(),
        cajaId: (json['cajaId'] ?? '').toString(),
        fecha: _asDate(json['fecha']),
        items: ((json['items'] as List?) ?? const [])
            .map((e) => VentaItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        total: _asDouble(json['total']),
        pagos: _toStringDoubleMap(json['pagos']),
        usuarioId: (json['usuarioId'] ?? '').toString(),
        usuarioNombre: (json['usuarioNombre'] ?? '').toString(),
      );
}
