import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shawarma_pos_nuevo/datos/modelos/caja.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/gasto.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/venta.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/live_caja.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/almacen_service.dart';
// Asegúrate de importar el servicio de productos

class CajaService with ChangeNotifier {
  // ===== Claves de sesión local =====
  static const _localCajaKey = 'active_caja_session';
  static const _localVentasKey = 'active_ventas_session';
  static const _localGastosKey = 'active_gastos_session';
  static const _localVentasEliminadasKey = 'deleted_ventas_session';

  // Baseline (opcional para trazabilidad)
  static const _localBaselineTotalKey = 'active_baseline_total';
  static const _localBaselineTotalsKey = 'active_baseline_totals';

  // 👉 NUEVO: flag de adopción local
  static const _localAdoptadaFlagKey = 'active_caja_adoptada';

  // 👉 NUEVO: estado de adopción (solo local, por dispositivo)
  bool _adoptadaLocalmente = false;
  bool get adoptadaLocalmente => _adoptadaLocalmente;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===== Utilidades para dinero exacto (centavos) =====
  int _toCents(num v) => (v * 100).round();
  double _fromCents(int c) => c / 100.0;
  double _norm(double v) => _fromCents(_toCents(v));

  // Fecha segura desde dynamic
  DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Caja? _cajaActiva;
  Caja? get cajaActiva => _cajaActiva;
  bool get hayCajaActiva => _cajaActiva != null;

  List<Venta> _ventasLocales = [];
  List<Venta> get ventasLocales => _ventasLocales;

  List<Gasto> _gastosLocales = [];
  List<Gasto> get gastosLocales => _gastosLocales;

  List<Venta> _ventasEliminadas = [];
  List<Venta> get ventasEliminadas => _ventasEliminadas;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // Trazabilidad si se adoptó
  double _baselineTotalVentas = 0.0;
  Map<String, double> _baselineTotalesPorMetodo = {};

  // ===== Conectividad =====
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  // ===== Live mirror =====
  DocumentReference<Map<String, dynamic>>? _liveRef;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cmdSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _liveDocSub;
  Timer? _liveDebounce;
  final bool _liveEnabled = true;

  // Suspender push/write cuando devolvemos la caja
  bool _suspendLive = false;

  // Instancia del servicio de productos

  CajaService() {
    cargarSesionLocal();
  }

  Future<void> init() async {
    _connSub = Connectivity().onConnectivityChanged.listen((_) {});
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _cmdSub?.cancel();
    _liveDocSub?.cancel();
    _liveDebounce?.cancel();
    super.dispose();
  }

  // ====== Sesión Local ======
  Future<void> cargarSesionLocal() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _adoptadaLocalmente =
        prefs.getBool(_localAdoptadaFlagKey) ?? false; // NUEVO
    final cajaJson = prefs.getString(_localCajaKey);
    if (cajaJson != null) {
      _cajaActiva = Caja.fromJson(jsonDecode(cajaJson));

      final ventasJson = prefs.getStringList(_localVentasKey) ?? [];
      _ventasLocales =
          ventasJson.map((v) => Venta.fromJson(jsonDecode(v))).toList();

      final gastosJson = prefs.getStringList(_localGastosKey) ?? [];
      _gastosLocales =
          gastosJson.map((g) => Gasto.fromJson(jsonDecode(g))).toList();

      final ventasEliminadasJson =
          prefs.getStringList(_localVentasEliminadasKey) ?? [];
      _ventasEliminadas = ventasEliminadasJson
          .map((v) => Venta.fromJson(jsonDecode(v)))
          .toList();

      // Baseline persistido
      _baselineTotalVentas = prefs.getDouble(_localBaselineTotalKey) ?? 0.0;
      final basTotals = prefs.getString(_localBaselineTotalsKey);
      if (basTotals != null) {
        final Map<String, dynamic> m = jsonDecode(basTotals);
        _baselineTotalesPorMetodo = {
          for (final e in m.entries) e.key: (e.value as num).toDouble(),
        };
      } else {
        _baselineTotalesPorMetodo = {};
      }

      // Si había caja activa, decide si levantar live según login (modo invitado = sin live)
      final signedIn = FirebaseAuth.instance.currentUser != null;
      if (_liveEnabled && _cajaActiva != null && signedIn) {
        _suspendLive = false;
        _liveRef = _db.collection('cajas_live').doc(_cajaActiva!.id);
        _listenLive();
        _scheduleLivePush();
      } else {
        _suspendLive = true; // invitado/offline: no empujar a Firestore
        _liveRef = null;
      }
    } else {
      _cajaActiva = null;
      _ventasLocales = [];
      _gastosLocales = [];
      _ventasEliminadas = [];
      _baselineTotalVentas = 0.0;
      _baselineTotalesPorMetodo = {};
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _guardarSesionLocal() async {
    final prefs = await SharedPreferences.getInstance();
    if (_cajaActiva != null) {
      await prefs.setString(_localCajaKey, jsonEncode(_cajaActiva!.toJson()));
      await prefs.setBool(_localAdoptadaFlagKey, _adoptadaLocalmente); // NUEVO

      await prefs.setStringList(
        _localVentasKey,
        _ventasLocales.map((v) => jsonEncode(v.toJson())).toList(),
      );
      await prefs.setStringList(
        _localGastosKey,
        _gastosLocales.map((g) => jsonEncode(g.toJson())).toList(),
      );
      await prefs.setStringList(
        _localVentasEliminadasKey,
        _ventasEliminadas.map((v) => jsonEncode(v.toJson())).toList(),
      );

      await prefs.setDouble(_localBaselineTotalKey, _baselineTotalVentas);
      await prefs.setString(
          _localBaselineTotalsKey, jsonEncode(_baselineTotalesPorMetodo));
    } else {
      await prefs.remove(_localCajaKey);
      await prefs.remove(_localVentasKey);
      await prefs.remove(_localGastosKey);
      await prefs.remove(_localVentasEliminadasKey);
      await prefs.remove(_localBaselineTotalKey);
      await prefs.remove(_localBaselineTotalsKey);
      await prefs.remove(_localAdoptadaFlagKey); // NUEVO
    }
    notifyListeners();
  }

  // ====== Helpers live mirror ======
  void _scheduleLivePush() {
    if (_suspendLive || !_liveEnabled || _cajaActiva == null) return;
    _liveDebounce?.cancel();
    _liveDebounce = Timer(const Duration(milliseconds: 800), _pushLiveNow);
  }

  Future<void> _pushLiveNow() async {
    if (_suspendLive || !_liveEnabled || _cajaActiva == null) return;

    String _cat(dynamic p) {
      try {
        final cn = (p.categoriaNombre as String?)?.trim();
        if (cn != null && cn.isNotEmpty) return cn;
      } catch (_) {}
      try {
        final cid = (p.categoriaId as String?)?.trim();
        if (cid != null && cid.isNotEmpty) return cid;
      } catch (_) {}
      return '';
    }

    List<LiveLineaPreview> buildLineas(Venta v) {
      final Map<String, Map<String, dynamic>> acc = {};
      for (final it in v.items) {
        final key = it.producto.id;
        final nombre = it.producto.nombre;
        final categoria = _cat(it.producto);
        final cents = _toCents(it.precioEditable);

        final a = acc.putIfAbsent(
            key,
            () => {
                  'nombre': nombre,
                  'categoria': categoria,
                  'cantidad': 0,
                  'cents': 0,
                });

        a['cantidad'] = (a['cantidad'] as int) + 1;
        a['cents'] = (a['cents'] as int) + cents;

        if ((a['categoria'] as String).isEmpty && categoria.isNotEmpty) {
          a['categoria'] = categoria;
        }
      }

      return acc.values.map((a) {
        return LiveLineaPreview(
          nombre: a['nombre'] as String,
          cantidad: a['cantidad'] as int,
          subtotal: _fromCents(a['cents'] as int),
          categoria: (a['categoria'] as String?) ?? '',
        );
      }).toList();
    }

    try {
      _liveRef ??= _db.collection('cajas_live').doc(_cajaActiva!.id);

      final ventasOrdenadas = List<Venta>.from(_ventasLocales)
        ..sort((a, b) => b.fecha.compareTo(a.fecha));
      final top = ventasOrdenadas.take(12).map((v) {
        return LiveVentaPreview(
          id: v.id,
          total: _norm(v.total),
          pagos: {for (final e in v.pagos.entries) e.key: _norm(e.value)},
          items: v.items.length,
          fecha: v.fecha,
          lineas: buildLineas(v),
        );
      }).toList();

      final eliminadasOrdenadas = List<Venta>.from(_ventasEliminadas)
        ..sort((a, b) => b.fecha.compareTo(a.fecha));
      final topEliminadas = eliminadasOrdenadas.take(12).map((v) {
        return LiveVentaPreview(
          id: v.id,
          total: _norm(v.total),
          pagos: {for (final e in v.pagos.entries) e.key: _norm(e.value)},
          items: v.items.length,
          fecha: v.fecha,
          lineas: buildLineas(v),
        );
      }).toList();

      final snap = LiveCajaSnapshot(
        cajaId: _cajaActiva!.id,
        usuarioId: _cajaActiva!.usuarioAperturaId,
        usuarioNombre: _cajaActiva!.usuarioAperturaNombre,
        fechaApertura: _cajaActiva!.fechaApertura,
        montoInicial: _norm(_cajaActiva!.montoInicial),
        totalVentas: _norm(_cajaActiva!.totalVentas),
        totalesPorMetodo: {
          for (final e in _cajaActiva!.totalesPorMetodo.entries)
            e.key: _norm(e.value),
        },
        ventasPendientes: _ventasLocales.length,
        ventasEliminadasPendientes: _ventasEliminadas.length,
        lastUpdate: DateTime.now(),
        recientes: top,
        eliminadasRecientes: topEliminadas,
      );

      await _liveRef!.set(snap.toMap(), SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[live push] $e');
    }
  }

  Future<void> _deleteAllDocsIn(
      CollectionReference<Map<String, dynamic>> col) async {
    try {
      final qs = await col.get();
      if (qs.docs.isEmpty) return;
      const chunk = 400; // bajo el límite de 500
      for (var i = 0; i < qs.docs.length; i += chunk) {
        final batch = _db.batch();
        for (final d in qs.docs.skip(i).take(chunk)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    } catch (_) {}
  }

  Future<void> _deleteLiveMirror() async {
    // Evita recreación mientras limpiamos
    _suspendLive = true;
    _liveDebounce?.cancel();
    _cmdSub?.cancel();
    _cmdSub = null;
    _liveDocSub?.cancel();
    _liveDocSub = null;

    final ref = _liveRef;
    if (ref == null) return;

    // Borrar subcolecciones con tolerancia a errores
    try {
      await _deleteAllDocsIn(ref.collection('commands'));
    } catch (e) {
      if (kDebugMode) debugPrint('[del commands] $e');
    }
    try {
      await _deleteAllDocsIn(ref.collection('ventas_buffer'));
    } catch (e) {
      if (kDebugMode) debugPrint('[del ventas_buffer] $e');
    }
    try {
      await _deleteAllDocsIn(ref.collection('ventas_eliminadas_buffer'));
    } catch (e) {
      if (kDebugMode) debugPrint('[del ventas_eliminadas_buffer] $e');
    }

    // Borrar doc padre pase lo que pase
    try {
      await ref.delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[live doc delete] $e');
    }

    _liveRef = null;
  }

  void _listenLive() {
    if (_liveRef == null) return;

    // Escucha de commands
    _cmdSub?.cancel();
    final q = _liveRef!
        .collection('commands')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false);

    try {
      _cmdSub = q.snapshots().listen((qs) async {
        for (final doc in qs.docs) {
          final data = doc.data();
          final type = (data['type'] ?? '').toString();
          try {
            if (_cajaActiva == null) throw 'no_active_caja';

            if (type == 'DELETE_VENTA') {
              final ventaId = (data['ventaId'] ?? '').toString();
              final v = _ventasLocales.firstWhere(
                (x) => x.id == ventaId,
                orElse: () => throw 'venta_not_found',
              );
              await registrarVentaEliminada(v);
              await eliminarVentaLocal(v);
            } else if (type == 'EDITAR_PAGO') {
              final ventaId = (data['ventaId'] ?? '').toString();
              final pagos = Map<String, dynamic>.from(data['pagos'] ?? {});
              final pagosDouble = {
                for (final e in pagos.entries)
                  e.key: _norm((e.value as num).toDouble())
              };
              final idx = _ventasLocales.indexWhere((x) => x.id == ventaId);
              if (idx == -1) throw 'venta_not_found';
              final anterior = _ventasLocales[idx];

              await eliminarVentaLocal(anterior);

              final editada = anterior.copyWith(
                pagos: pagosDouble,
                total: pagosDouble.values.fold<double>(0.0, (s, m) => s + m),
              );
              await agregarVentaLocal(editada);
            } else if (type == 'CLOSE_NOW') {
              await _aplicarCierreRemoto(data);
            } else if (type == 'REFRESH_FROM_BUFFERS') {
              await _reloadBuffersFromLive();
            }

            await doc.reference.update({
              'status': 'applied',
              'appliedAt': FieldValue.serverTimestamp(),
            });

            _scheduleLivePush();
          } catch (e) {
            await doc.reference.update({
              'status': 'error',
              'error': e.toString(),
              'appliedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }, onError: (e, st) {
        if (kDebugMode) debugPrint('[commands listen] $e');
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[commands subscribe] $e');
    }

    // Escucha del documento en vivo
    try {
      _liveDocSub?.cancel();
      _liveDocSub = _liveRef!.snapshots().listen((doc) async {
        if (_cajaActiva == null) return;
        if (!doc.exists) {
          await descartarCajaLocal(skipLiveDelete: true);
          return;
        }
        final estado = (doc.data()?['estado'] ?? 'abierta').toString();
        if (estado == 'cerrada') {
          await descartarCajaLocal(skipLiveDelete: true);
        }
      }, onError: (e, st) {
        if (kDebugMode) debugPrint('[live doc listen] $e');
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[live doc subscribe] $e');
    }
  }

  Future<void> _aplicarCierreRemoto(Map<String, dynamic> data) async {
    // Limpia sólo la sesión local, no borres el documento live (lo borrará quien mandó).
    await descartarCajaLocal(skipLiveDelete: true);
  }

  Future<void> pushLiveNow() => _pushLiveNow();

  // ====== Abrir Caja ======
  Future<void> abrirCaja({
    required double montoInicial,
    required String usuarioId,
    required String usuarioNombre,
    DateTime? fechaSeleccionada,
  }) async {
    final authUser = FirebaseAuth.instance.currentUser;
    final effectiveUid = authUser?.uid ?? 'invitado';
    final effectiveNombre =
        authUser?.displayName ?? authUser?.email ?? usuarioNombre;

    final fechaDeApertura = fechaSeleccionada ?? DateTime.now();
    _cajaActiva = Caja(
      id: fechaDeApertura.millisecondsSinceEpoch.toString(),
      fechaApertura: fechaDeApertura,
      usuarioAperturaId: effectiveUid,
      usuarioAperturaNombre: effectiveNombre,
      montoInicial: _norm(montoInicial),
      estado: 'abierta',
      totalVentas: 0.0,
      totalGastos: 0.0,
      totalesPorMetodo: <String, double>{},
    );

    _ventasLocales = [];
    _gastosLocales = [];
    _ventasEliminadas = [];
    _baselineTotalVentas = 0.0;
    _baselineTotalesPorMetodo = {};
    _adoptadaLocalmente =
        false; // caja abierta en este dispositivo, no adoptada
    await _guardarSesionLocal();

    // Si no hay login, entramos en modo invitado: no crear ni empujar live.
    final signedIn = authUser != null;
    _suspendLive = !signedIn;

    if (_liveEnabled && signedIn) {
      _liveRef = _db.collection('cajas_live').doc(_cajaActiva!.id);
      await _liveRef!.set({
        'cajaId': _cajaActiva!.id,
        'usuarioId': effectiveUid,
        'usuarioNombre': effectiveNombre,
        'fechaApertura': _cajaActiva!.fechaApertura,
        'estado': 'abierta',
        'createdAt': FieldValue.serverTimestamp(),
        'operadoresActivos': FieldValue.arrayUnion([effectiveUid]),
      }, SetOptions(merge: true));

      _listenLive();
      _scheduleLivePush();
    } else {
      _liveRef = null;
    }
  }

  // ===== Helpers espejo de historial completo en buffers =====
  Future<void> _mirrorVentaToBuffer(Venta v) async {
    if (_suspendLive || _liveRef == null) return;
    try {
      await _liveRef!
          .collection('ventas_buffer')
          .doc(v.id.toString())
          .set(v.toJson(), SetOptions(merge: true));
      await _liveRef!.set({'lastUpdate': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[buffer venta set] $e');
    }
  }

  Future<void> _deleteVentaFromBuffer(String ventaId) async {
    if (_suspendLive || _liveRef == null) return;
    try {
      await _liveRef!.collection('ventas_buffer').doc(ventaId).delete();
      await _liveRef!.set({'lastUpdate': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _mirrorVentaEliminadaToBuffer(Venta v) async {
    if (_suspendLive || _liveRef == null) return;
    try {
      final map = v.toJson();
      map['eliminada'] = true;
      await _liveRef!
          .collection('ventas_eliminadas_buffer')
          .doc(v.id.toString())
          .set(map, SetOptions(merge: true));
      await _liveRef!.set({'lastUpdate': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[buffer venta eliminada set] $e');
    }
  }

  void _recalcularTotalesDesdeVentas() {
    if (_cajaActiva == null) return;
    double total = 0.0;
    final Map<String, double> porMetodo = {};

    for (final v in _ventasLocales) {
      total += v.total;
      v.pagos.forEach((metodo, monto) {
        porMetodo[metodo] = _norm((porMetodo[metodo] ?? 0.0) + monto);
      });
    }

    _cajaActiva = _cajaActiva!.copyWith(
      totalVentas: _norm(total),
      totalesPorMetodo: {
        for (final e in porMetodo.entries) e.key: _norm(e.value)
      },
    );
  }

  /// Recarga listas locales desde los buffers (usado al devolver la caja).
  Future<void> _reloadBuffersFromLive() async {
    if (_cajaActiva == null || _liveRef == null) return;
    try {
      final ventasSnap = await _liveRef!.collection('ventas_buffer').get();
      final eliminadasSnap =
          await _liveRef!.collection('ventas_eliminadas_buffer').get();

      _ventasLocales = ventasSnap.docs
          .map((d) => Venta.fromJson(Map<String, dynamic>.from(d.data())))
          .toList();

      _ventasEliminadas = eliminadasSnap.docs
          .map((d) => Venta.fromJson(Map<String, dynamic>.from(d.data())))
          .toList();

      _recalcularTotalesDesdeVentas();
      await _guardarSesionLocal();
      _scheduleLivePush();
    } catch (e) {
      if (kDebugMode) debugPrint('[reload buffers] $e');
    }
  }

  /// Continuar/adoptar una caja remota con historial
  Future<void> continuarCajaDesdeLive({
    required String cajaId,
    required DateTime fechaApertura,
    required double montoInicial,
    required double totalVentas,
    required Map<String, double> totalesPorMetodo,
    required String usuarioOriginalId,
    required String usuarioOriginalNombre,
    bool cambiarOperadorAlActual = true,
  }) async {
    final authUser = FirebaseAuth.instance.currentUser;
    final newUid = (cambiarOperadorAlActual && authUser != null)
        ? authUser.uid
        : usuarioOriginalId;
    final newNombre = (cambiarOperadorAlActual && authUser != null)
        ? (authUser.displayName ?? authUser.email ?? 'Admin')
        : usuarioOriginalNombre;

    // Construye caja local
    _cajaActiva = Caja(
      id: cajaId,
      fechaApertura: fechaApertura,
      usuarioAperturaId: newUid,
      usuarioAperturaNombre: newNombre,
      montoInicial: _norm(montoInicial),
      estado: 'abierta',
      totalVentas: 0.0,
      totalGastos: 0.0,
      totalesPorMetodo: <String, double>{},
    );

    _ventasLocales = [];
    _gastosLocales = [];
    _ventasEliminadas = [];
    _baselineTotalVentas = 0.0;
    _baselineTotalesPorMetodo = {};
    _adoptadaLocalmente = true; // esta sesión es adoptada/continuada desde live
    await _guardarSesionLocal();

    // Tomar historial completo desde buffers
    _liveRef = _db.collection('cajas_live').doc(_cajaActiva!.id);
    try {
      final ventasSnap = await _liveRef!.collection('ventas_buffer').get();
      final eliminadasSnap =
          await _liveRef!.collection('ventas_eliminadas_buffer').get();

      _ventasLocales = ventasSnap.docs
          .map((d) => Venta.fromJson(Map<String, dynamic>.from(d.data())))
          .toList();

      _ventasEliminadas = eliminadasSnap.docs
          .map((d) => Venta.fromJson(Map<String, dynamic>.from(d.data())))
          .toList();

      _recalcularTotalesDesdeVentas();
      await _guardarSesionLocal();
    } catch (e) {
      if (kDebugMode) debugPrint('[adopt read buffers] $e');
      _cajaActiva = _cajaActiva!.copyWith(
        totalVentas: _norm(totalVentas),
        totalesPorMetodo: {
          for (final e in totalesPorMetodo.entries) e.key: _norm(e.value)
        },
      );
      await _guardarSesionLocal();
    }

    if (_liveEnabled) {
      await _liveRef!.set({
        'cajaId': _cajaActiva!.id,
        'usuarioId': newUid,
        'usuarioNombre': newNombre,
        'fechaApertura': fechaApertura,
        'estado': 'abierta',
        'adoptadaPor': cambiarOperadorAlActual ? newUid : FieldValue.delete(),
        'lastUpdate': FieldValue.serverTimestamp(),
        'operadoresActivos': FieldValue.arrayUnion([newUid, usuarioOriginalId]),
      }, SetOptions(merge: true));

      _listenLive();
      _scheduleLivePush();
    }
  }

  Future<void> ensureCajaAbierta({
    required String usuarioId,
    required String usuarioNombre,
    double montoInicial = 0,
  }) async {
    if (_cajaActiva == null) {
      await abrirCaja(
        montoInicial: montoInicial,
        usuarioId: usuarioId,
        usuarioNombre: usuarioNombre,
      );
    }
  }

  Future<void> descartarCajaLocal({bool skipLiveDelete = false}) async {
    if (!skipLiveDelete) {
      await _deleteLiveMirror();
    } else {
      // Detener listeners y limpiar ref
      _cmdSub?.cancel();
      _cmdSub = null;
      _liveDocSub?.cancel();
      _liveDocSub = null;
      _liveRef = null;
    }
    _cajaActiva = null;
    _ventasLocales = [];
    _gastosLocales = [];
    _ventasEliminadas = [];
    _baselineTotalVentas = 0.0;
    _baselineTotalesPorMetodo = {};
    _adoptadaLocalmente = false;
    await _guardarSesionLocal();
  }

  Future<void> actualizarUsuarioSesion(
      String usuarioId, String usuarioNombre) async {
    if (_cajaActiva == null) return;

    // Detecta si veníamos en modo invitado/offline (sin live o suspendido)
    final veniaInvitado = _cajaActiva!.usuarioAperturaId == 'invitado' ||
        _suspendLive ||
        _liveRef == null;

    // Actualiza la caja local con el nuevo usuario
    _cajaActiva = _cajaActiva!.copyWith(
      usuarioAperturaId: usuarioId,
      usuarioAperturaNombre: usuarioNombre,
    );
    await _guardarSesionLocal();

    // Si hay login válido, auto-levantar el live y sincronizar estado
    if (_liveEnabled && usuarioId != 'invitado') {
      _suspendLive = false; // reanudar pushes
      _liveRef ??= _db.collection('cajas_live').doc(_cajaActiva!.id);

      // Crea/actualiza el documento live con el estado actual de la caja
      await _liveRef!.set({
        'cajaId': _cajaActiva!.id,
        'usuarioId': usuarioId,
        'usuarioNombre': usuarioNombre,
        'fechaApertura': _cajaActiva!.fechaApertura,
        'montoInicial': _norm(_cajaActiva!.montoInicial),
        'totalVentas': _norm(_cajaActiva!.totalVentas),
        'totalesPorMetodo': {
          for (final e in _cajaActiva!.totalesPorMetodo.entries)
            e.key: _norm(e.value),
        },
        'estado': 'abierta',
        'lastUpdate': FieldValue.serverTimestamp(),
        'operadoresActivos': FieldValue.arrayUnion([usuarioId]),
      }, SetOptions(merge: true));

      // (Opcional) limpiar un posible "invitado" de la lista
      try {
        await _liveRef!.update({
          'operadoresActivos': FieldValue.arrayRemove(['invitado']),
        });
      } catch (_) {}

      // Arranca listeners si no estaban activos
      _listenLive();

      // Si veníamos offline, sube TODO el historial local a los buffers
      if (veniaInvitado) {
        for (final v in _ventasLocales) {
          await _mirrorVentaToBuffer(v);
        }
        for (final v in _ventasEliminadas) {
          await _mirrorVentaEliminadaToBuffer(v);
        }
      }

      // Publica el snapshot live con recientes/contadores
      _scheduleLivePush();
      await _pushLiveNow();
    } else {
      // Si sigue invitado, mantener suspendido
      _suspendLive = true;
    }
  }

  // ===== Ventas locales =====
  Future<void> agregarVentaLocal(Venta venta) async {
    if (_cajaActiva == null) return;

    _ventasLocales.add(venta);

    final nuevosTotales =
        Map<String, double>.from(_cajaActiva!.totalesPorMetodo);
    venta.pagos.forEach((metodo, monto) {
      final prevC = _toCents(nuevosTotales[metodo] ?? 0.0);
      final newC = prevC + _toCents(monto);
      nuevosTotales[metodo] = _fromCents(newC);
    });
    final tvC = _toCents(_cajaActiva!.totalVentas) + _toCents(venta.total);

    _cajaActiva = _cajaActiva!.copyWith(
      totalVentas: _fromCents(tvC),
      totalesPorMetodo: nuevosTotales,
    );

    await _guardarSesionLocal();
    _scheduleLivePush();

    // espejo en buffers
    await _mirrorVentaToBuffer(venta);
  }

  Future<void> registrarVentaEliminada(Venta venta) async {
    if (_cajaActiva == null) return;
    _ventasEliminadas.add(venta);
    await _guardarSesionLocal();
    _scheduleLivePush();
    await _pushLiveNow();

    // espejo: mover a eliminadas y sacar de ventas si existía
    await _mirrorVentaEliminadaToBuffer(venta);
    await _deleteVentaFromBuffer(venta.id.toString());
  }

  Future<void> eliminarVentaLocal(Venta ventaParaEliminar) async {
    if (_cajaActiva == null) return;

    _ventasLocales.removeWhere((v) => v.id == ventaParaEliminar.id);

    final nuevosTotales =
        Map<String, double>.from(_cajaActiva!.totalesPorMetodo);
    ventaParaEliminar.pagos.forEach((metodo, monto) {
      final prevC = _toCents(nuevosTotales[metodo] ?? 0.0);
      final newC = prevC - _toCents(monto);
      nuevosTotales[metodo] = _fromCents(newC);
    });
    final tvC =
        _toCents(_cajaActiva!.totalVentas) - _toCents(ventaParaEliminar.total);

    _cajaActiva = _cajaActiva!.copyWith(
      totalVentas: _fromCents(tvC),
      totalesPorMetodo: nuevosTotales,
    );

    await _guardarSesionLocal();
    _scheduleLivePush();

    // quitar del buffer
    await _deleteVentaFromBuffer(ventaParaEliminar.id.toString());
  }

  // ===== Gastos =====
  Future<void> agregarGastoLocal(Gasto gasto) async {
    if (_cajaActiva == null) return;
    _gastosLocales.add(gasto);
    await _guardarSesionLocal();
    _scheduleLivePush();
  }

  Future<void> eliminarGastoLocal(Gasto gastoParaEliminar) async {
    if (_cajaActiva == null) return;
    _gastosLocales.removeWhere((g) => g.id == gastoParaEliminar.id);
    await _guardarSesionLocal();
    _scheduleLivePush();
  }

  Future<void> actualizarMontoInicial(double nuevoMonto) async {
    if (_cajaActiva == null) {
      throw Exception('No hay una caja activa para actualizar.');
    }
    _cajaActiva = _cajaActiva!.copyWith(montoInicial: _norm(nuevoMonto));
    await _guardarSesionLocal();
    _scheduleLivePush();
  }

  Future<void> syncPendientes() async {
    if (kDebugMode) {}
  }

  // === Venta "lean" para subir al cerrar caja
  Map<String, dynamic> _ventaToFirestoreLean(
    Venta venta,
    String cajaId, {
    required String createdBy,
  }) {
    return {
      'cajaId': cajaId,
      'createdBy': createdBy,
      'fecha': venta.fecha,
      'items': venta.items.map((item) {
        final p = item.producto;
        final prodMap = <String, dynamic>{
          'id': p.id,
          'nombre': p.nombre,
          'precio': _norm(p.precio),
        };
        final categoriaId = p.categoriaId;
        if (categoriaId.trim().isNotEmpty) {
          prodMap['categoriaId'] = categoriaId;
        }
        return {
          'uniqueId': item.uniqueId,
          'precioEditable': _norm(item.precioEditable),
          'producto': prodMap,
        };
      }).toList(),
      'pagos': {for (final e in venta.pagos.entries) e.key: _norm(e.value)},
      'total': _norm(venta.total),
      'usuarioId': venta.usuarioId,
      'usuarioNombre': venta.usuarioNombre,
    };
  }

  Map<String, dynamic> _ventaEliminadaToFirestore(
    Venta venta,
    String cajaId, {
    required String createdBy,
  }) {
    final lean = _ventaToFirestoreLean(venta, cajaId, createdBy: createdBy);
    return {...lean, 'eliminada': true};
  }

  // ====== Cerrar Caja (sube todo a Firestore desde este dispositivo) ======
  Future<void> cerrarCaja({
    required double montoContado,
    DateTime? fechaCierreSeleccionada,
  }) async {
    if (_cajaActiva == null) throw Exception('No hay caja activa.');
    // Congelar cualquier push/listener para que no se recree el doc
    _suspendLive = true;
    _liveDebounce?.cancel();
    _cmdSub?.cancel();
    _cmdSub = null;
    _liveDocSub?.cancel();
    _liveDocSub = null;

    final user = FirebaseAuth.instance.currentUser;
    final createdBy = user?.uid ?? _cajaActiva!.usuarioAperturaId;

    final cajaDocRef = _db.collection('cajas').doc(_cajaActiva!.id);
    final fechaDeCierre = fechaCierreSeleccionada ?? DateTime.now();

    final montoInicialN = _norm(_cajaActiva!.montoInicial);
    final totalVentasN = _norm(_cajaActiva!.totalVentas);
    final totalesPorMetodoN = {
      for (final e in _cajaActiva!.totalesPorMetodo.entries)
        e.key: _norm(e.value),
    };

    final miC = _toCents(montoInicialN);
    final tvC = _toCents(totalVentasN);
    final esperadoC = miC + tvC;
    final contadoC = _toCents(montoContado);
    final diferenciaC = contadoC - esperadoC;

    final cierreRealExacto = _fromCents(contadoC);
    final diferenciaExacta = _fromCents(diferenciaC);

    final Map<String, dynamic> cajaFirestore = {
      'id': _cajaActiva!.id,
      'estado': 'cerrada',
      'fechaApertura': _cajaActiva!.fechaApertura,
      'fechaCierre': fechaDeCierre,
      'usuarioAperturaId': _cajaActiva!.usuarioAperturaId,
      'usuarioAperturaNombre': _cajaActiva!.usuarioAperturaNombre,
      'montoInicial': _fromCents(miC),
      'totalVentas': _fromCents(tvC),
      'totalesPorMetodo': totalesPorMetodoN,
      'cierreReal': cierreRealExacto,
      'diferencia': diferenciaExacta,
      'adoptadaDesdeLive': _adoptadaLocalmente, // 👈 corregido
      'baselineTotalVentas': _baselineTotalVentas,
      'baselineTotalesPorMetodo': _baselineTotalesPorMetodo,
    };

    try {
      final batch = _db.batch();

      batch.set(cajaDocRef, cajaFirestore);

      // Subimos todas las ventas locales
      for (var venta in _ventasLocales) {
        final ventaDocRef = _db.collection('ventas').doc(venta.id.toString());
        final ventaMap =
            _ventaToFirestoreLean(venta, cajaDocRef.id, createdBy: createdBy);
        batch.set(ventaDocRef, ventaMap, SetOptions(merge: true));
      }

      for (var gasto in _gastosLocales) {
        final gastoDocRef = _db.collection('gastos').doc();
        final gastoConCajaId = gasto.copyWith(cajaId: cajaDocRef.id);
        batch.set(gastoDocRef, gastoConCajaId.toFirestore());
      }

      if (_ventasEliminadas.isNotEmpty) {
        final sub = cajaDocRef.collection('ventasEliminadas');
        double totalEliminado = 0.0;
        for (var venta in _ventasEliminadas) {
          final docId = venta.id.toString();
          final docRef = (docId.isNotEmpty) ? sub.doc(docId) : sub.doc();
          final map = _ventaEliminadaToFirestore(
            venta,
            cajaDocRef.id,
            createdBy: createdBy,
          );
          totalEliminado += _norm(venta.total);
          batch.set(docRef, map, SetOptions(merge: true));
        }
        batch.set(
          cajaDocRef,
          {
            'conteoVentasEliminadas': _ventasEliminadas.length,
            'totalEliminado': _norm(totalEliminado),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      // Aplicar (si existen) gastos de insumos de apertura, pero permitir cerrar aun si no existen.
      final almacenService = AlmacenService();
      final aperturaGastos = _gastosLocales
          .where((g) => (g.tipo ?? '') == 'insumos_apertura')
          .toList();

      // Aplicar descuentos por ventas (recetas por producto)
      for (var venta in _ventasLocales) {
        for (var item in venta.items) {
          try {
            await almacenService.descontarInsumosPorVenta(item.producto.id, 1);
          } catch (e) {
            debugPrint(
                'Error al descontar insumos de ${item.producto.nombre}: $e');
          }
        }
      }

  // Aplicar descuentos por los insumos registrados en el/los gastos de apertura (si hay)
  for (final g in aperturaGastos) {
        try {
          // Expandir items que sean recetas: si el item.id corresponde a un documento en 'recetas',
          // tomar sus insumos y multiplicar por item.cantidad
          final List<GastoItem> expanded = [];
          for (final it in g.items) {
            final id = it.id.toString();
            if (id.trim().isEmpty) {
              expanded.add(it);
              continue;
            }

            // Intentar leer receta por id
            try {
              final recetaDoc = await FirebaseFirestore.instance
                  .collection('recetas')
                  .doc(id)
                  .get();
              if (recetaDoc.exists) {
                final data = recetaDoc.data()!;
                final insumos = List<dynamic>.from(data['insumos'] ?? []);
                // Determinar si la receta tiene un rendimiento en 'potes' (p.ej. cuántos potes rinde la receta)
                final potesPorReceta = (data['potesPorReceta'] ??
                    data['rinde'] ??
                    data['porciones'] ??
                    data['rendimiento']) as num?;
                final double potesRinde =
                    (potesPorReceta != null) ? potesPorReceta.toDouble() : 0.0;

                // Si la receta define un rendimiento en potes (>0), entonces interpretamos
                // que `it.cantidad` (la cantidad reportada en el gasto) está en potes y
                // descontamos solo recetas enteras: recetasAplicar = floor(totalPotesUsados / potesPorReceta).
                if (potesRinde > 0) {
                  final totalPotesUsados = it.cantidad;
                  final recetasAplicar =
                      (totalPotesUsados / potesRinde).floor();
                  if (recetasAplicar > 0) {
                    for (final ins in insumos) {
                      final nombre = (ins['nombre'] ?? '').toString();
                      final cantidadPorUnidad =
                          (ins['cantidad'] as num?)?.toDouble() ?? 0.0;
                      final totalQty = (cantidadPorUnidad > 0)
                          ? (cantidadPorUnidad * recetasAplicar)
                          : 0.0;
                      if (totalQty > 0) {
                        expanded.add(GastoItem(
                            id: nombre,
                            nombre: nombre,
                            precio: 0.0,
                            cantidad: totalQty));
                      }
                    }
                  } else {
                    // No hay recetas completas para aplicar (queda en parcial), no descontamos ahora.
                  }
                } else {
                  // Comportamiento por defecto: aplicar la receta proporcionalmente a it.cantidad
                  for (final ins in insumos) {
                    final nombre = (ins['nombre'] ?? '').toString();
                    final cantidadPorUnidad =
                        (ins['cantidad'] as num?)?.toDouble() ?? 0.0;
                    final totalQty = (cantidadPorUnidad > 0)
                        ? (cantidadPorUnidad * it.cantidad)
                        : it.cantidad;
                    if (totalQty > 0) {
                      expanded.add(GastoItem(
                          id: nombre,
                          nombre: nombre,
                          precio: 0.0,
                          cantidad: totalQty));
                    }
                  }
                }
                continue; // procesado
              }
            } catch (_) {}

            // Si no es receta, agregar directo
            expanded.add(it);
          }

          if (expanded.isNotEmpty) {
            await almacenService.descontarInsumosPorGasto(expanded);
          }
        } catch (e) {
          debugPrint('Error al aplicar gasto de apertura al almacén: $e');
        }
      }

      // Avisar y limpiar live (best-effort, sin bloquear el borrado)
      if (_liveRef != null) {
        final me = FirebaseAuth.instance.currentUser?.uid;
        // 1) Marcar cerrada manteniendo al operador para pasar reglas de borrado de subcolecciones
        try {
          await _liveRef!.set({
            'estado': 'cerrada',
            'closedAt': FieldValue.serverTimestamp(),
            'closedBy': createdBy,
            'lastUpdate': FieldValue.serverTimestamp(),
            if (me != null) 'operadoresActivos': FieldValue.arrayUnion([me]),
          }, SetOptions(merge: true));
        } catch (e) {
          if (kDebugMode) debugPrint('[live mark closed] $e');
        }
        // 2) Intentar mandar comando; si falla por reglas, continuamos
        try {
          await _liveRef!.collection('commands').add({
            'type': 'CLOSE_NOW',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'issuedBy': createdBy,
            'source': 'auto_on_close',
          });
        } catch (e) {
          if (kDebugMode) debugPrint('[live command skipped] $e');
        }
        // 3) Siempre intentar limpiar el mirror
        await Future.delayed(const Duration(milliseconds: 1200));
        await _deleteLiveMirror();
      }
    } finally {
      await descartarCajaLocal(skipLiveDelete: true);
    }
  }

  /// Envía un comando de cierre remoto a la caja en vivo (sin subir caja).
  Future<void> comandarCierreRemoto({
    required String cajaId,
    required String adminUid,
    String? adminNombre,
    double? montoContado,
    DateTime? fechaCierre,
    required String motivo,
  }) async {
    final ref = _db.collection('cajas_live').doc(cajaId);
    final cmdRef = ref.collection('commands').doc();

    await ref.set({
      'estado': 'cerrando',
      'shutdownIssuedBy': adminUid,
      'shutdownMotivo': motivo,
      'lastUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await cmdRef.set({
      'type': 'CLOSE_NOW',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'issuedBy': adminUid,
      'issuedByNombre': adminNombre,
      'motivo': motivo,
      if (montoContado != null) 'montoContado': _norm(montoContado),
      if (fechaCierre != null) 'fechaCierre': fechaCierre,
    });
  }

  /// NUEVO: Cerrar AHORA (admin) GUARDANDO LA CAJA Y LAS VENTAS desde buffers
  /// y eliminando luego `cajas_live/{cajaId}`.
  Future<void> adminCerrarYGuardarCajaDesdeLive({
    required String cajaId,
    required String adminUid,
    String? adminNombre,
    double? montoContado,
    DateTime? fechaCierre,
    String motivo = 'Cierre remoto por admin',
  }) async {
    final ref = _db.collection('cajas_live').doc(cajaId);

    final liveDoc = await ref.get();
    if (!liveDoc.exists) {
      throw Exception('La caja en vivo no existe.');
    }
    final ld = liveDoc.data()!;

    // Datos base de la caja (del operador original)
    final originalUid = (ld['usuarioId'] ?? '').toString();
    final originalNombre = (ld['usuarioNombre'] ?? 'Operador').toString();
    final fechaApertura = _asDate(ld['fechaApertura']) ?? DateTime.now();
    final montoInicial = (ld['montoInicial'] is num)
        ? (ld['montoInicial'] as num).toDouble()
        : 0.0;

    // Cargar ventas desde buffers
    final ventasSnap = await ref.collection('ventas_buffer').get();
    final eliminadasSnap =
        await ref.collection('ventas_eliminadas_buffer').get();

    final ventas = ventasSnap.docs
        .map((d) => Venta.fromJson(Map<String, dynamic>.from(d.data())))
        .toList();

    final ventasEliminadas = eliminadasSnap.docs
        .map((d) => Venta.fromJson(Map<String, dynamic>.from(d.data())))
        .toList();

    // Recalcular totales por método y total ventas
    double totalVentas = 0.0;
    final Map<String, double> totalesPorMetodo = {};
    for (final v in ventas) {
      totalVentas += v.total;
      v.pagos.forEach((metodo, monto) {
        totalesPorMetodo[metodo] =
            _norm((totalesPorMetodo[metodo] ?? 0.0) + monto);
      });
    }

    // Fallback si no hubo buffers (toma del snapshot en vivo)
    if (ventas.isEmpty) {
      totalVentas = (ld['totalVentas'] is num)
          ? (ld['totalVentas'] as num).toDouble()
          : 0.0;
      final tmp = Map<String, dynamic>.from(ld['totalesPorMetodo'] ?? {});
      tmp.forEach((k, v) {
        totalesPorMetodo[k] =
            (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
      });
    }

    // Calcular cierre
    final miC = _toCents(_norm(montoInicial));
    final tvC = _toCents(_norm(totalVentas));
    final esperadoC = miC + tvC;
    final contadoC = _toCents(montoContado ?? _fromCents(esperadoC));
    final diferenciaC = contadoC - esperadoC;

    final fechaDeCierre = fechaCierre ?? DateTime.now();

    // Subir a /cajas y /ventas
    final cajaDocRef = _db.collection('cajas').doc(cajaId);
    final batch = _db.batch();

    // Documento de la caja
    batch.set(cajaDocRef, {
      'id': cajaId,
      'estado': 'cerrada',
      'fechaApertura': fechaApertura,
      'fechaCierre': fechaDeCierre,
      'usuarioAperturaId': originalUid,
      'usuarioAperturaNombre': originalNombre,
      'montoInicial': _fromCents(miC),
      'totalVentas': _fromCents(tvC),
      'totalesPorMetodo': {
        for (final e in totalesPorMetodo.entries) e.key: _norm(e.value)
      },
      'cierreReal': _fromCents(contadoC),
      'diferencia': _fromCents(diferenciaC),
      'cerradaRemotamentePor': adminUid,
      'cerradaRemotamenteNombre': adminNombre,
      'adoptadaDesdeLive': true,
    });

    // Ventas normales (desde buffer)
    for (final v in ventas) {
      final ventaDocRef = _db.collection('ventas').doc(v.id.toString());
      batch.set(
        ventaDocRef,
        _ventaToFirestoreLean(v, cajaId, createdBy: adminUid),
        SetOptions(merge: true),
      );
    }

    // Ventas eliminadas (subcolección en caja)
    if (ventasEliminadas.isNotEmpty) {
      final sub = cajaDocRef.collection('ventasEliminadas');
      double totalEliminado = 0.0;
      for (final v in ventasEliminadas) {
        final docId = v.id.toString();
        final docRef = (docId.isNotEmpty) ? sub.doc(docId) : sub.doc();
        batch.set(
          docRef,
          _ventaEliminadaToFirestore(v, cajaId, createdBy: adminUid),
          SetOptions(merge: true),
        );
        totalEliminado += _norm(v.total);
      }
      batch.set(
        cajaDocRef,
        {
          'conteoVentasEliminadas': ventasEliminadas.length,
          'totalEliminado': _norm(totalEliminado),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    // Señal de cierre a dispositivos y limpieza del live
    try {
      await ref.set({
        'estado': 'cerrada',
        'closedAt': FieldValue.serverTimestamp(),
        'closedBy': adminUid,
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await ref.collection('commands').add({
        'type': 'CLOSE_NOW',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'issuedBy': adminUid,
        'issuedByNombre': adminNombre,
        'motivo': motivo,
      });

      await Future.delayed(const Duration(milliseconds: 1200));

      await _deleteAllDocsIn(ref.collection('commands'));
      await _deleteAllDocsIn(ref.collection('ventas_buffer'));
      await _deleteAllDocsIn(ref.collection('ventas_eliminadas_buffer'));
      await ref.delete();
    } catch (e) {
      if (kDebugMode) debugPrint('[admin close save+delete live] $e');
    }
  }

  /// Devolver caja al trabajador
  Future<void> devolverCajaAlTrabajador() async {
    if (_cajaActiva == null) return;
    if (_liveRef == null)
      _liveRef = _db.collection('cajas_live').doc(_cajaActiva!.id);

    final adminUid = FirebaseAuth.instance.currentUser?.uid;

    // Pausar pushes y escuchar
    _suspendLive = true;
    _cmdSub?.cancel();
    _cmdSub = null;
    _liveDocSub?.cancel();
    _liveDocSub = null;

    try {
      // Orden para refrescar buffers en otros dispositivos
      await _liveRef!.collection('commands').add({
        'type': 'REFRESH_FROM_BUFFERS',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'issuedBy': adminUid,
      });

      // Asegurar operador original
      String? originalUid;
      try {
        final doc = await _liveRef!.get();
        originalUid = (doc.data()?['usuarioId'] ?? '') as String?;
      } catch (_) {}

      // Quitar admin de operadores y limpiar adoptadaPor
      await _liveRef!.set({
        'adoptadaPor': FieldValue.delete(),
        'estado': 'abierta',
        'lastUpdate': FieldValue.serverTimestamp(),
        if (adminUid != null)
          'operadoresActivos': FieldValue.arrayRemove([adminUid]),
        if (originalUid != null && originalUid.isNotEmpty)
          'operadoresActivos': FieldValue.arrayUnion([originalUid]),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[devolver caja] $e');
    } finally {
      // Limpiar mi sesión local (no borrar doc live)
      await descartarCajaLocal(skipLiveDelete: true);
      _suspendLive = false;
    }
  }
}
