// lib/datos/servicios/informe_service.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '../modelos/caja.dart';
import '../modelos/venta.dart';

/// Modelo liviano para gastos (no dependemos del modelo Gasto)
class GastoResumen {
  final String id;
  final DateTime fecha;
  final double total;
  final Map<String, double> pagos;
  final String?
      label; // etiqueta resumida para mostrar en UI (p.ej. 'Pollo: Pechuga')

  GastoResumen({
    required this.id,
    required this.fecha,
    required this.total,
    required this.pagos,
    this.label,
  });
}

enum FiltroPeriodo { dia, semana, mes, rango }

class _CacheEntry {
  final List<Caja> cajas;
  final List<Venta> ventas;
  final List<GastoResumen> gastos;

  _CacheEntry(
      {required this.cajas, required this.ventas, required this.gastos});
}

/// ===== Helpers de casteo tolerante (int | double | String) =====
double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

Map<String, double> _asDoubleMap(dynamic m) {
  if (m == null) return <String, double>{};
  if (m is Map) {
    final out = <String, double>{};
    m.forEach((k, v) => out[k.toString()] = _asDouble(v));
    return out;
  }
  return <String, double>{};
}

class InformeService with ChangeNotifier {
  // ===== Estado y dependencias =====
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isFetching = false;
  bool _isLoading = false;
  String? _errorMessage;

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, DateTime> _cacheStamp = {};
  final Duration _ttl = const Duration(minutes: 5);

  List<Caja> _cajasCerradas = [];
  List<Caja> get cajasCerradas => _cajasCerradas;

  List<Venta> _ventasDelPeriodo = [];
  List<Venta> get ventasDelPeriodo => _ventasDelPeriodo;

  List<GastoResumen> _gastosDelPeriodo = [];
  List<GastoResumen> get gastosDelPeriodo => _gastosDelPeriodo;

  bool get isLoading => _isLoading;
  bool get isFetching => _isFetching;
  String? get errorMessage => _errorMessage;

  FiltroPeriodo _filtroActual = FiltroPeriodo.dia;
  FiltroPeriodo get filtroActual => _filtroActual;

  DateTime? _rangoInicio;
  DateTime? get rangoInicio => _rangoInicio;
  DateTime? _rangoFin;
  DateTime? get rangoFin => _rangoFin;

  InformeService() {
    fetchInformesCompletos(FiltroPeriodo.dia);
  }

  // ===== Resúmenes para la UI (VENTAS) =====
  double get resumenTotalVentas {
    return _ventasDelPeriodo.fold(0.0, (sum, venta) => sum + venta.total);
  }

  Map<String, double> get resumenTotalMetodosDePago {
    final Map<String, double> totales = {};
    for (var venta in _ventasDelPeriodo) {
      venta.pagos.forEach((metodo, monto) {
        totales.update(metodo, (valor) => valor + monto, ifAbsent: () => monto);
      });
    }
    return totales;
  }

  Map<String, int> get resumenProductos {
    final Map<String, int> conteo = {};
    for (var venta in _ventasDelPeriodo) {
      final itemsAgrupados =
          groupBy(venta.items, (VentaItem item) => item.producto.id);
      itemsAgrupados.forEach((_, itemsDelMismoProducto) {
        final nombreProducto = itemsDelMismoProducto.first.producto.nombre;
        final cantidadProducto = itemsDelMismoProducto.length;
        conteo.update(nombreProducto, (v) => v + cantidadProducto,
            ifAbsent: () => cantidadProducto);
      });
    }
    return conteo;
  }

  // ===== Resúmenes para la UI (GASTOS) =====
  double get resumenTotalGastos {
    return _gastosDelPeriodo.fold(0.0, (sum, g) => sum + g.total);
  }

  Map<String, double> get resumenMetodosDePagoGastos {
    final Map<String, double> totales = {};
    for (final g in _gastosDelPeriodo) {
      g.pagos.forEach((metodo, monto) {
        totales.update(metodo, (prev) => prev + monto, ifAbsent: () => monto);
      });
    }
    return totales;
  }

  // ===== Neto (Ventas - Gastos) =====
  double get netoTotal => resumenTotalVentas - resumenTotalGastos;

  Map<String, double> get netoPorMetodo {
    final v = resumenTotalMetodosDePago;
    final g = resumenMetodosDePagoGastos;
    final Set<String> keys = {...v.keys, ...g.keys};
    final Map<String, double> out = {};
    for (final k in keys) {
      out[k] = (v[k] ?? 0.0) - (g[k] ?? 0.0);
    }
    return out;
  }

  // ===== Precarga silenciosa =====
  Future<void> precacheBasico() async {
    for (final p in [
      FiltroPeriodo.dia,
      FiltroPeriodo.semana,
      FiltroPeriodo.mes
    ]) {
      final range = _getDateRange(p);
      final key = _getCacheKey(p, start: range['start'], end: range['end']);
      if (_isCacheValid(key)) continue;
      try {
        final entry = await _cargarPeriodo(
          start: range['start']!,
          endInclusive: range['end']!,
          forceRefresh: false,
        );
        _cache[key] = entry;
        _cacheStamp[key] = DateTime.now();
      } catch (_) {}
    }
  }

  bool _isCacheValid(String key) {
    final t = _cacheStamp[key];
    if (t == null) return false;
    return DateTime.now().difference(t) < _ttl && _cache.containsKey(key);
  }

  // ===== Carga visible para la UI =====
  Future<void> fetchInformesCompletos(
    FiltroPeriodo periodo, {
    bool forceRefresh = false,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    if (_isFetching) return;

    _errorMessage = null;
    _filtroActual = periodo;

    final dateRange =
        _getDateRange(periodo, customStart: customStart, customEnd: customEnd);
    _rangoInicio = dateRange['start'];
    _rangoFin = dateRange['end'];

    final cacheKey = _getCacheKey(periodo, start: _rangoInicio, end: _rangoFin);
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      final hit = _cache[cacheKey]!;
      _cajasCerradas = hit.cajas;
      _ventasDelPeriodo = hit.ventas;
      _gastosDelPeriodo = hit.gastos;
      _isFetching = false;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isFetching = true;
    _isLoading = true;
    notifyListeners();

    try {
      final entry = await _cargarPeriodo(
        start: _rangoInicio!,
        endInclusive: _rangoFin!,
        forceRefresh: forceRefresh,
      );

      _cajasCerradas = entry.cajas;
      _ventasDelPeriodo = entry.ventas;
      _gastosDelPeriodo = entry.gastos;

      _cache[cacheKey] = entry;
      _cacheStamp[cacheKey] = DateTime.now();
    } catch (e) {
      _errorMessage = "Error al buscar en Firebase: $e";
      _cajasCerradas = [];
      _ventasDelPeriodo = [];
      _gastosDelPeriodo = [];
    } finally {
      _isFetching = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===== Carga por período (cache/server) =====
  Future<_CacheEntry> _cargarPeriodo({
    required DateTime start,
    required DateTime endInclusive,
    required bool forceRefresh,
  }) async {
    // --- VENTAS ---
    final ventasQuery = _db
        .collection('ventas')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(endInclusive))
        .orderBy('fecha', descending: true);

    QuerySnapshot<Map<String, dynamic>> ventasSnap =
        await ventasQuery.get(const GetOptions(source: Source.cache));
    if (ventasSnap.docs.isEmpty || forceRefresh) {
      ventasSnap =
          await ventasQuery.get(const GetOptions(source: Source.server));
    }

    final ventasResult =
        ventasSnap.docs.map((doc) => Venta.fromFirestore(doc)).toList();

    // --- GASTOS (robusto) ---
    final gastosQuery = _db
        .collection('gastos')
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(endInclusive))
        .orderBy('fecha', descending: true);

    QuerySnapshot<Map<String, dynamic>> gastosSnap =
        await gastosQuery.get(const GetOptions(source: Source.cache));
    if (gastosSnap.docs.isEmpty || forceRefresh) {
      gastosSnap =
          await gastosQuery.get(const GetOptions(source: Source.server));
    }

    final gastosResult = gastosSnap.docs.map((doc) {
      final data = doc.data();

      // fecha
      DateTime fecha;
      final f = data['fecha'];
      if (f is Timestamp) {
        fecha = f.toDate();
      } else if (f is DateTime) {
        fecha = f;
      } else if (f is String) {
        fecha = DateTime.tryParse(f) ?? DateTime.now();
      } else {
        fecha = DateTime.now();
      }

      // total (tolerante)
      final double total = _asDouble(data['total'] ?? data['monto']);

      // pagos (tolerante)
      final Map<String, double> pagos = _asDoubleMap(data['pagos']);
      if (pagos.isEmpty) {
        final pm = data['paymentMethod']?.toString();
        if (pm != null && pm.isNotEmpty) {
          pagos[pm] = total;
        } else {
          pagos['Otros'] = total;
        }
      }

      // label: preferir 'Categoria: Nombre' del primer item si existe;
      // si no hay items con info, usar descripcion; si tampoco, 'Gasto'
      String? label;
      try {
        final itemsRaw = data['items'];
        if (itemsRaw is List && itemsRaw.isNotEmpty) {
          final first = itemsRaw.first;
          if (first is Map) {
            // Usar solo el nombre del producto (no la categoría)
            final nombre = (first['nombre'] ?? first['nombreProducto'] ?? '')
                .toString()
                .trim();
            if (nombre.isNotEmpty) {
              label = nombre;
            }
          }
        }
      } catch (_) {
        // ignore
      }

      if (label == null || label.isEmpty) {
        final desc = data['descripcion']?.toString();
        if (desc != null && desc.trim().isNotEmpty) {
          label = desc.trim();
        }
      }

      if (label == null || label.isEmpty) label = 'Gasto';

      return GastoResumen(
          id: doc.id, fecha: fecha, total: total, pagos: pagos, label: label);
    }).toList();

    // --- CAJAS (normalizamos números antes de usar el modelo) ---
    // Empezamos con las cajas referenciadas por ventas (si las hay)
    final Set<String> cajaIds =
        ventasResult.map((v) => v.cajaId).where((id) => id.isNotEmpty).toSet();

    // Además, buscar cajas que hayan sido cerradas dentro del rango
    // (esto incluye cajas vacías que se cerraron sin ventas)
    try {
      final cajasClosedQuery = _db
          .collection('cajas')
          .where('fechaCierre',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('fechaCierre',
              isLessThanOrEqualTo: Timestamp.fromDate(endInclusive));

      QuerySnapshot<Map<String, dynamic>> cajasClosedSnap =
          await cajasClosedQuery.get(const GetOptions(source: Source.cache));
      if (cajasClosedSnap.docs.isEmpty || forceRefresh) {
        cajasClosedSnap =
            await cajasClosedQuery.get(const GetOptions(source: Source.server));
      }

      for (final doc in cajasClosedSnap.docs) {
        if (doc.id.isNotEmpty) cajaIds.add(doc.id);
      }
    } catch (_) {
      // Si la consulta por fecha falla por esquemas antiguos, no interrumpimos
    }

    final List<Caja> cajasResult = [];
    if (cajaIds.isNotEmpty) {
      final ids = cajaIds.toList();
      for (var i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);

        var cajasSnap = await _db
            .collection('cajas')
            .where(FieldPath.documentId, whereIn: chunk)
            .get(const GetOptions(source: Source.cache));
        if (cajasSnap.docs.length != chunk.length || forceRefresh) {
          cajasSnap = await _db
              .collection('cajas')
              .where(FieldPath.documentId, whereIn: chunk)
              .get(const GetOptions(source: Source.server));
        }

        for (final doc in cajasSnap.docs) {
          final raw = doc.data();
          try {
            // intento directo (para docs “nuevos” ya en double)
            cajasResult.add(Caja.fromFirestore(raw, doc.id));
          } catch (_) {
            // normalizamos numéricos que puedan venir como int
            final fixed = Map<String, dynamic>.from(raw);
            fixed['montoInicial'] = _asDouble(raw['montoInicial']);
            fixed['totalVentas'] = _asDouble(raw['totalVentas']);
            if (raw['cierreReal'] != null)
              fixed['cierreReal'] = _asDouble(raw['cierreReal']);
            if (raw['diferencia'] != null)
              fixed['diferencia'] = _asDouble(raw['diferencia']);
            fixed['totalesPorMetodo'] = _asDoubleMap(raw['totalesPorMetodo']);
            cajasResult.add(Caja.fromFirestore(fixed, doc.id));
          }
        }
      }
    }

    return _CacheEntry(
        cajas: cajasResult, ventas: ventasResult, gastos: gastosResult);
  }

  // ===== Operaciones de borrado =====
  Future<String?> deleteVenta(String ventaId) async {
    try {
      await _db.collection('ventas').doc(ventaId).delete();
      _ventasDelPeriodo.removeWhere((venta) => venta.id == ventaId);
      _cache.clear();
      _cacheStamp.clear();
      notifyListeners();
      return null;
    } on FirebaseException catch (e) {
      return 'Error de Firebase: ${e.message}';
    } catch (e) {
      return 'Ocurrió un error inesperado: $e';
    }
  }

  Future<String?> deleteCaja(String cajaId) async {
    try {
      WriteBatch batch = _db.batch();
      final ventasQuery = await _db
          .collection('ventas')
          .where('cajaId', isEqualTo: cajaId)
          .get();

      final ventasAEliminarIds = <String>[];
      for (var doc in ventasQuery.docs) {
        batch.delete(doc.reference);
        ventasAEliminarIds.add(doc.id);
      }

      final cajaRef = _db.collection('cajas').doc(cajaId);
      batch.delete(cajaRef);
      await batch.commit();

      _cajasCerradas.removeWhere((caja) => caja.id == cajaId);
      _ventasDelPeriodo
          .removeWhere((venta) => ventasAEliminarIds.contains(venta.id));
      _cache.clear();
      _cacheStamp.clear();

      notifyListeners();
      return null;
    } on FirebaseException catch (e) {
      return 'Error de Firebase: ${e.message}';
    } catch (e) {
      return 'Ocurrió un error inesperado: $e';
    }
  }

  Future<String?> deleteGasto(String gastoId) async {
    try {
      await _db.collection('gastos').doc(gastoId).delete();
      _gastosDelPeriodo.removeWhere((gasto) => gasto.id == gastoId);
      _cache.clear();
      _cacheStamp.clear();
      notifyListeners();
      return null;
    } on FirebaseException catch (e) {
      return 'Error de Firebase: ${e.message}';
    } catch (e) {
      return 'Ocurrió un error inesperado: $e';
    }
  }

  /// Actualiza un gasto (solo método de pago y monto) y sincroniza estado local/cache.
  Future<String?> updateGasto(
    String gastoId, {
    required String metodo,
    required double monto,
  }) async {
    try {
      final ref = _db.collection('gastos').doc(gastoId);
      // Compatibilidad con distintos esquemas: total/monto, pagos y paymentMethod
      final dataUpdate = <String, dynamic>{
        'total': monto,
        'monto': monto,
        'pagos': {metodo: monto},
        'paymentMethod': metodo,
      };
      await ref.update(dataUpdate);

      // Actualiza estado local
      final idx = _gastosDelPeriodo.indexWhere((g) => g.id == gastoId);
      if (idx != -1) {
        final old = _gastosDelPeriodo[idx];
        _gastosDelPeriodo[idx] = GastoResumen(
          id: old.id,
          fecha: old.fecha,
          total: monto,
          pagos: {metodo: monto},
          label: old.label,
        );
      }

      // Invalida cache y notifica
      _cache.clear();
      _cacheStamp.clear();
      notifyListeners();
      return null;
    } on FirebaseException catch (e) {
      return 'Error de Firebase: ${e.message}';
    } catch (e) {
      return 'Ocurrió un error inesperado: $e';
    }
  }

  // ===== Utilidades de cache/fechas =====
  String _getCacheKey(FiltroPeriodo periodo, {DateTime? start, DateTime? end}) {
    switch (periodo) {
      case FiltroPeriodo.dia:
        return 'dia_${DateTime.now().toIso8601String().substring(0, 10)}';
      case FiltroPeriodo.semana:
        return 'semana_${start!.toIso8601String().substring(0, 10)}';
      case FiltroPeriodo.mes:
        return 'mes_${start!.year}-${start.month}';
      case FiltroPeriodo.rango:
        final startStr = start!.toIso8601String().substring(0, 10);
        final endStr = end!.toIso8601String().substring(0, 10);
        return 'rango_${startStr}_$endStr';
    }
  }

  Map<String, DateTime> _getDateRange(
    FiltroPeriodo periodo, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final now = DateTime.now();
    late DateTime start;
    late DateTime end;

    switch (periodo) {
      case FiltroPeriodo.dia:
        // Incluye todo el día local
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;

      case FiltroPeriodo.semana:
        // Lunes a domingo, todo el día
        final hoy0 = DateTime(now.year, now.month, now.day);
        final daysToSubtract = hoy0.weekday - 1; // 1=lun..7=dom
        start = DateTime(
            hoy0.subtract(Duration(days: daysToSubtract)).year,
            hoy0.subtract(Duration(days: daysToSubtract)).month,
            hoy0.subtract(Duration(days: daysToSubtract)).day,
            0,
            0,
            0);
        final daysToAdd = 7 - hoy0.weekday;
        final endDay = hoy0.add(Duration(days: daysToAdd));
        end = DateTime(endDay.year, endDay.month, endDay.day, 23, 59, 59, 999);
        break;

      case FiltroPeriodo.mes:
        start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final nextMonth = (now.month < 12)
            ? DateTime(now.year, now.month + 1, 1)
            : DateTime(now.year + 1, 1, 1);
        end = nextMonth.subtract(const Duration(milliseconds: 1));
        break;

      case FiltroPeriodo.rango:
        final s = customStart ?? now;
        final e = customEnd ?? now;
        start = DateTime(s.year, s.month, s.day, 0, 0, 0);
        end = DateTime(e.year, e.month, e.day, 23, 59, 59, 999);
        break;
    }
    return {'start': start, 'end': end};
  }
}
