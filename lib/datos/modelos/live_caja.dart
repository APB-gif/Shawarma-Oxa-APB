// lib/datos/modelos/live_caja.dart
import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0.0;
}

class LiveLineaPreview {
  final String nombre;
  final int cantidad;
  final double subtotal;
  final String categoria;

  LiveLineaPreview({
    required this.nombre,
    required this.cantidad,
    required this.subtotal,
    this.categoria = '',
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'cantidad': cantidad,
        'subtotal': subtotal,
        'categoria': categoria,
      };

  factory LiveLineaPreview.fromMap(Map<String, dynamic> m) => LiveLineaPreview(
        nombre: (m['nombre'] ?? '').toString(),
        cantidad: (m['cantidad'] as num?)?.toInt() ?? 0,
        subtotal: _asDouble(m['subtotal']),
        categoria: (m['categoria'] ?? '').toString(),
      );
}

class LiveVentaPreview {
  final String id;
  final double total;
  final Map<String, double> pagos;
  final int items;
  final DateTime fecha;
  final List<LiveLineaPreview> lineas;

  LiveVentaPreview({
    required this.id,
    required this.total,
    required this.pagos,
    required this.items,
    required this.fecha,
    this.lineas = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'total': total,
        'pagos': pagos,
        'items': items,
        // Enviamos DateTime directo para que Firestore lo guarde como Timestamp
        'fecha': fecha,
        'lineas': lineas.map((e) => e.toMap()).toList(),
      };

  factory LiveVentaPreview.fromMap(Map<String, dynamic> m) => LiveVentaPreview(
        id: (m['id'] ?? '').toString(),
        total: _asDouble(m['total']),
        pagos: {
          for (final e in Map<String, dynamic>.from(m['pagos'] ?? {}).entries)
            e.key: _asDouble(e.value),
        },
        items: (m['items'] as num?)?.toInt() ?? 0,
        fecha: _asDate(m['fecha']) ?? DateTime.now(),
        lineas: (m['lineas'] is List)
            ? (m['lineas'] as List)
                .map((e) => LiveLineaPreview.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList()
            : const [],
      );
}

class LiveCajaSnapshot {
  final String cajaId;
  final String usuarioId;
  final String usuarioNombre;
  final DateTime fechaApertura;
  final double montoInicial;
  final double totalVentas;
  final Map<String, double> totalesPorMetodo;
  final int ventasPendientes;
  final int ventasEliminadasPendientes;
  final DateTime lastUpdate;
  final List<LiveVentaPreview> recientes;
  final List<LiveVentaPreview> eliminadasRecientes;

  LiveCajaSnapshot({
    required this.cajaId,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.fechaApertura,
    required this.montoInicial,
    required this.totalVentas,
    required this.totalesPorMetodo,
    required this.ventasPendientes,
    required this.ventasEliminadasPendientes,
    required this.lastUpdate,
    required this.recientes,
    this.eliminadasRecientes = const [],
  });

  Map<String, dynamic> toMap() => {
        'cajaId': cajaId,
        'usuarioId': usuarioId,
        'usuarioNombre': usuarioNombre,
        // DateTime directo => Firestore Timestamp
        'fechaApertura': fechaApertura,
        'montoInicial': montoInicial,
        'totalVentas': totalVentas,
        'totalesPorMetodo': totalesPorMetodo,
        'ventasPendientes': ventasPendientes,
        'ventasEliminadasPendientes': ventasEliminadasPendientes,
        'lastUpdate': lastUpdate,
        'recientes': recientes.map((e) => e.toMap()).toList(),
        'eliminadasRecientes': eliminadasRecientes.map((e) => e.toMap()).toList(),
        'estado': 'abierta',
      };

  factory LiveCajaSnapshot.fromMap(Map<String, dynamic> m) => LiveCajaSnapshot(
        cajaId: (m['cajaId'] ?? '').toString(),
        usuarioId: (m['usuarioId'] ?? '').toString(),
        usuarioNombre: (m['usuarioNombre'] ?? '').toString(),
        fechaApertura: _asDate(m['fechaApertura']) ?? DateTime.now(),
        montoInicial: _asDouble(m['montoInicial']),
        totalVentas: _asDouble(m['totalVentas']),
        totalesPorMetodo: {
          for (final e in Map<String, dynamic>.from(m['totalesPorMetodo'] ?? {}).entries)
            e.key: _asDouble(e.value),
        },
        ventasPendientes: (m['ventasPendientes'] as num?)?.toInt() ?? 0,
        ventasEliminadasPendientes: (m['ventasEliminadasPendientes'] as num?)?.toInt() ?? 0,
        lastUpdate: _asDate(m['lastUpdate']) ?? DateTime.now(),
        recientes: (m['recientes'] is List)
            ? (m['recientes'] as List)
                .map((e) => LiveVentaPreview.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList()
            : const [],
        eliminadasRecientes: (m['eliminadasRecientes'] is List)
            ? (m['eliminadasRecientes'] as List)
                .map((e) => LiveVentaPreview.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList()
            : const [],
      );
}
