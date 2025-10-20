// lib/datos/servicios/servicio_lista_compras.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CompraItem {
  final String id;
  final String nombre;
  final double cantidad; // para futuro (kg, unidades, etc.)
  final String? unidad;
  final double precioEstimado;
  final String? categoriaId;
  final String? productoId; // para reconstruir Producto al comprar
  final bool comprado;
  final DateTime createdAt;

  CompraItem({
    required this.id,
    required this.nombre,
    required this.cantidad,
    required this.unidad,
    required this.precioEstimado,
    required this.categoriaId,
    required this.productoId,
    required this.comprado,
    required this.createdAt,
  });

  CompraItem copyWith({
    String? id,
    String? nombre,
    double? cantidad,
    String? unidad,
    double? precioEstimado,
    String? categoriaId,
    String? productoId,
    bool? comprado,
    DateTime? createdAt,
  }) {
    return CompraItem(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      cantidad: cantidad ?? this.cantidad,
      unidad: unidad ?? this.unidad,
      precioEstimado: precioEstimado ?? this.precioEstimado,
      categoriaId: categoriaId ?? this.categoriaId,
      productoId: productoId ?? this.productoId,
      comprado: comprado ?? this.comprado,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory CompraItem.fromMap(Map<String, dynamic> map) {
    return CompraItem(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 1.0,
      unidad: map['unidad'] as String?,
      precioEstimado: (map['precioEstimado'] as num?)?.toDouble() ?? 0.0,
      categoriaId: map['categoriaId'] as String?,
      productoId: map['productoId'] as String?,
      comprado: (map['comprado'] as bool?) ?? false,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'cantidad': cantidad,
      'unidad': unidad,
      'precioEstimado': precioEstimado,
      'categoriaId': categoriaId,
      'productoId': productoId,
      'comprado': comprado,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class ServicioListaCompras {
  static const _kStoreKey = 'lista_compras_hoy';
  static const _kDateKey = 'lista_compras_fecha';

  DateTime _today = _dateOnly(DateTime.now());
  List<CompraItem> _items = [];

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _normText(String s) => s.trim().toLowerCase();

  static String _keyFor({
    String? productoId,
    required String nombre,
  }) {
    // Preferimos productoId. Si no existe, usamos nombre normalizado.
    if (productoId != null && productoId.trim().isNotEmpty)
      return 'p:$productoId';
    return 'n:${_normText(nombre)}';
    // Nota: si quieres considerar categoría, concatenar ':c:$categoriaId'
  }

  Future<void> _ensureToday(SharedPreferences prefs) async {
    final storedDateStr = prefs.getString(_kDateKey);
    final todayStr = _fmtDate(_today);
    if (storedDateStr != todayStr) {
      // Día nuevo -> limpiar
      await prefs.setStringList(_kStoreKey, []);
      await prefs.setString(_kDateKey, todayStr);
      _items = [];
    }
  }

  Future<void> cargarHoy() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureToday(prefs);
    final raw = prefs.getStringList(_kStoreKey) ?? [];
    _items = raw.map((s) => CompraItem.fromMap(jsonDecode(s))).toList();
    // Sanea duplicados (pudo quedar de sesiones previas)
    _dedupeInMemory();
    await _persist(prefs);
  }

  List<CompraItem> obtenerListaHoy() => List.unmodifiable(_items);

  Future<void> _persist(SharedPreferences prefs) async {
    await prefs.setStringList(
        _kStoreKey, _items.map((e) => jsonEncode(e.toMap())).toList());
    await prefs.setString(_kDateKey, _fmtDate(_today));
  }

  void _dedupeInMemory() {
    final Map<String, CompraItem> merged = {};
    for (final it in _items) {
      final key = _keyFor(productoId: it.productoId, nombre: it.nombre);
      if (!merged.containsKey(key)) {
        merged[key] = it;
      } else {
        final prev = merged[key]!;
        // Regla: sumar cantidades, mantener el precio más reciente, y si alguno no comprado -> no comprado.
        merged[key] = prev.copyWith(
          cantidad: prev.cantidad + it.cantidad,
          precioEstimado: it.precioEstimado, // preferimos el último
          comprado: prev.comprado && it.comprado,
        );
      }
    }
    _items = merged.values.toList();
  }

  Future<void> agregarItem({
    required String nombre,
    required double cantidad,
    String? unidad,
    required double precioEstimado,
    String? categoriaId,
    String? productoId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureToday(prefs);

    final key = _keyFor(productoId: productoId, nombre: nombre);
    final idx = _items.indexWhere(
        (e) => _keyFor(productoId: e.productoId, nombre: e.nombre) == key);

    if (idx >= 0) {
      // ✅ Ya existe: fusionamos (evita duplicados)
      final prev = _items[idx];
      _items[idx] = prev.copyWith(
        cantidad: prev.cantidad + cantidad,
        precioEstimado: precioEstimado, // actualiza al último
        comprado: false, // volver a pendiente si se re-agrega
      );
    } else {
      // Nuevo
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final item = CompraItem(
        id: id,
        nombre: nombre,
        cantidad: cantidad,
        unidad: unidad,
        precioEstimado: precioEstimado,
        categoriaId: categoriaId,
        productoId: productoId,
        comprado: false,
        createdAt: DateTime.now(),
      );
      _items.add(item);
    }
    await _persist(prefs);
  }

  Future<void> eliminarItem(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureToday(prefs);
    _items.removeWhere((e) => e.id == id);
    await _persist(prefs);
  }

  Future<void> limpiarHoy() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureToday(prefs);
    _items.clear();
    await _persist(prefs);
  }

  Future<void> marcarComprado(String id, {bool comprado = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureToday(prefs);
    final i = _items.indexWhere((e) => e.id == id);
    if (i != -1) {
      _items[i] = _items[i].copyWith(comprado: comprado);
      await _persist(prefs);
    }
  }

  Future<void> marcarCompradoPorIds(Iterable<String> ids,
      {bool comprado = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureToday(prefs);
    final setIds = ids.toSet();
    _items = _items
        .map((e) => setIds.contains(e.id) ? e.copyWith(comprado: comprado) : e)
        .toList();
    await _persist(prefs);
  }
}
