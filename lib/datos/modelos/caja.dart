// lib/datos/modelos/caja.dart
import 'package:cloud_firestore/cloud_firestore.dart';

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

class Caja {
  final String id;
  final DateTime fechaApertura;
  final DateTime? fechaCierre;
  final String usuarioAperturaId;
  final String usuarioAperturaNombre;
  final double montoInicial;
  final double totalVentas;

  // ✅ CAMPO AÑADIDO
  final double totalGastos;

  final Map<String, double> totalesPorMetodo;
  final double? cierreReal;
  final double? diferencia;
  final String estado;
  final List<Map<String, dynamic>> ventasEliminadas;

  Caja({
    required this.id,
    required this.fechaApertura,
    this.fechaCierre,
    required this.usuarioAperturaId,
    required this.usuarioAperturaNombre,
    required this.montoInicial,
    this.totalVentas = 0.0,
    this.totalGastos = 0.0,
    Map<String, double>? totalesPorMetodo,
    this.cierreReal,
    this.diferencia,
    required this.estado,
    this.ventasEliminadas = const [],
  }) : totalesPorMetodo = totalesPorMetodo ?? {};

  Caja copyWith({
    String? id,
    DateTime? fechaApertura,
    DateTime? fechaCierre,
    String? usuarioAperturaId,
    String? usuarioAperturaNombre,
    double? montoInicial,
    double? totalVentas,
    double? totalGastos,
    Map<String, double>? totalesPorMetodo,
    double? cierreReal,
    double? diferencia,
    String? estado,
    List<Map<String, dynamic>>? ventasEliminadas,
  }) {
    return Caja(
      id: id ?? this.id,
      fechaApertura: fechaApertura ?? this.fechaApertura,
      fechaCierre: fechaCierre ?? this.fechaCierre,
      usuarioAperturaId: usuarioAperturaId ?? this.usuarioAperturaId,
      usuarioAperturaNombre:
          usuarioAperturaNombre ?? this.usuarioAperturaNombre,
      montoInicial: montoInicial ?? this.montoInicial,
      totalVentas: totalVentas ?? this.totalVentas,
      totalGastos: totalGastos ?? this.totalGastos,
      totalesPorMetodo: totalesPorMetodo ?? this.totalesPorMetodo,
      cierreReal: cierreReal ?? this.cierreReal,
      diferencia: diferencia ?? this.diferencia,
      estado: estado ?? this.estado,
      ventasEliminadas: ventasEliminadas ?? this.ventasEliminadas,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fechaApertura': fechaApertura.toIso8601String(),
        'fechaCierre': fechaCierre?.toIso8601String(),
        'usuarioAperturaId': usuarioAperturaId,
        'usuarioAperturaNombre': usuarioAperturaNombre,
        'montoInicial': montoInicial,
        'totalVentas': totalVentas,
        'totalGastos': totalGastos,
        'totalesPorMetodo': totalesPorMetodo,
        'cierreReal': cierreReal,
        'diferencia': diferencia,
        'estado': estado,
        'ventasEliminadas': ventasEliminadas,
      };

  Map<String, dynamic> toFirestore() => {
        ...toJson(),
        'fechaApertura': Timestamp.fromDate(fechaApertura),
        'fechaCierre':
            fechaCierre != null ? Timestamp.fromDate(fechaCierre!) : null,
      };

  factory Caja.fromJson(Map<String, dynamic> json) => Caja(
        id: (json['id'] ?? '').toString(),
        fechaApertura: _asDate(json['fechaApertura']),
        fechaCierre:
            json['fechaCierre'] != null ? _asDate(json['fechaCierre']) : null,
        usuarioAperturaId: (json['usuarioAperturaId'] ?? '').toString(),
        usuarioAperturaNombre: (json['usuarioAperturaNombre'] ?? '').toString(),
        montoInicial: _asDouble(json['montoInicial']),
        totalVentas: _asDouble(json['totalVentas']),
        totalGastos: _asDouble(json['totalGastos']),
        totalesPorMetodo: _toStringDoubleMap(json['totalesPorMetodo']),
        cierreReal:
            json['cierreReal'] != null ? _asDouble(json['cierreReal']) : null,
        diferencia:
            json['diferencia'] != null ? _asDouble(json['diferencia']) : null,
        estado: (json['estado'] ?? '').toString(),
        ventasEliminadas: (json['ventasEliminadas'] is List)
            ? List<Map<String, dynamic>>.from(json['ventasEliminadas'] as List)
            : const [],
      );

  /// Usado en InformeService
  factory Caja.fromFirestore(Map<String, dynamic> data, String docId) {
    return Caja(
      id: docId,
      fechaApertura: _asDate(data['fechaApertura']),
      fechaCierre:
          data['fechaCierre'] != null ? _asDate(data['fechaCierre']) : null,
      usuarioAperturaId: (data['usuarioAperturaId'] ?? '').toString(),
      usuarioAperturaNombre: (data['usuarioAperturaNombre'] ?? '').toString(),
      montoInicial: _asDouble(data['montoInicial']),
      totalVentas: _asDouble(data['totalVentas']),
      totalGastos: _asDouble(data['totalGastos']),
      totalesPorMetodo: _toStringDoubleMap(data['totalesPorMetodo']),
      cierreReal:
          data['cierreReal'] != null ? _asDouble(data['cierreReal']) : null,
      diferencia:
          data['diferencia'] != null ? _asDouble(data['diferencia']) : null,
      estado: (data['estado'] ?? '').toString(),
      ventasEliminadas: (data['ventasEliminadas'] is List)
          ? List<Map<String, dynamic>>.from(data['ventasEliminadas'] as List)
          : const [],
    );
  }
}
