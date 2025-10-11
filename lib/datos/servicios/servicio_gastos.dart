// lib/datos/servicios/servicio_gastos.dart
//
// OFFLINE solo para ADMIN (real u "admin local" con PIN).
// - Admin puede registrar gastos sin internet → se encolan y se sincronizan al volver la red.
// - Trabajador o invitado sin internet → bloqueado.
// - Cache local por usuario.
// Requiere: connectivity_plus, shared_preferences, firebase_auth,
//           core/net/connectivity_utils.dart, core/offline/offline_pending.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:shawarma_pos_nuevo/datos/modelos/gasto.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/app_user.dart';
import 'package:shawarma_pos_nuevo/core/net/connectivity_utils.dart' show hasInternet;
import 'package:shawarma_pos_nuevo/core/offline/offline_pending.dart' as off;

const _kOfflineMode = 'offline_mode';
const _kOfflineRole = 'offline_role';
const _kOfflineUserName = 'offline_user_name';

class ServicioGastos with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  AppUser? _me;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  List<Gasto> _gastos = [];
  List<Gasto> get gastos => List.unmodifiable(_gastos);

  String get _cacheKey => 'cache_gastos_registrados_v3_${_uid ?? "anon"}';

  ServicioGastos() {
    _cargarCache();
    _cargarUsuarioActual();
  }

  Future<void> _cargarUsuarioActual() async {
    final uid = _uid;
    if (uid == null) {
      _me = null;
      return;
    }
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        _me = AppUser.fromFirestore(doc.data() as Map<String, dynamic>, uid);
      }
    } catch (_) {
      _me = null;
    }
  }

  Future<bool> _isOfflineAdmin() async {
    final p = await SharedPreferences.getInstance();
    final offline = p.getBool(_kOfflineMode) ?? false;
    final role = p.getString(_kOfflineRole);
    return offline && role == 'admin';
  }

  Future<String?> _offlineDisplayName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kOfflineUserName);
  }

  Future<void> _cargarCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_cacheKey);
    if (jsonStr != null) {
      try {
        _gastos = decodeGastos(jsonStr);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, encodeGastos(_gastos));
  }

  // ------- Registrar Gasto (online/offline admin) --------
  Future<String> registrarGasto({
    required String proveedor,
    String descripcion = '',
    required List<GastoItem> items,
    required Map<String, double> pagos,
    required String usuarioId,
    required String usuarioNombre,
    DateTime? fecha,
  }) async {
    final f = fecha ?? DateTime.now();
    final total = items.fold<double>(0.0, (a, it) => a + it.subtotal);

    final gasto = Gasto(
      id: null,
      cajaId: null,
      fecha: f,
      proveedor: proveedor,
      descripcion: descripcion,
      items: items,
      pagos: pagos,
      total: total,
      usuarioId: usuarioId,
      usuarioNombre: usuarioNombre,
    );

    _isSaving = true;
    notifyListeners();

    try {
      // Estado de red + rol
      final online = await hasInternet();
      _isOnline = online;

      bool esAdmin = (_me?.rol == 'administrador');
      if (!esAdmin && !online) {
        esAdmin = await _isOfflineAdmin(); // admin local con PIN
        if (esAdmin && usuarioNombre == 'Usuario') {
          final n = await _offlineDisplayName();
          // no cambiamos el nombre pasado por parámetro si ya venía personalizado
          if (n != null && n.trim().isNotEmpty) {
            // no hacemos copy del modelo porque sólo subimos map en offline
          }
        }
      }

      if (online) {
        // ONLINE directo
        final doc = _db.collection('gastos').doc();
        final data = gasto.copyWith(id: doc.id).toFirestore();
        await doc.set({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
        final saved = gasto.copyWith(id: doc.id);
        _gastos.insert(0, saved);
        await _saveCache();
        return doc.id;
      }

      // OFFLINE: solo admins (admin real logueado o admin local)
      if (!esAdmin) {
        throw Exception('Sin conexión. Solo un administrador puede registrar gastos en modo offline.');
      }

      // Creamos id temporal y mapa simple (solo primitivas) para guardar en cola
      final tempId = 'tmp_${DateTime.now().microsecondsSinceEpoch}';
      final mapOffline = <String, dynamic>{
        'id': tempId,
        'cajaId': gasto.cajaId,
        'fecha': gasto.fecha.toIso8601String(),
        'proveedor': gasto.proveedor,
        'descripcion': gasto.descripcion,
        'items': gasto.items.map((it) => {
              'id': it.id,
              'nombre': it.nombre,
              'precio': it.precio,
              'cantidad': it.cantidad,
              if (it.categoriaId != null) 'categoriaId': it.categoriaId,
            }).toList(),
        'pagos': gasto.pagos,
        'total': gasto.total,
        'usuarioId': gasto.usuarioId.isEmpty ? 'admin_local' : gasto.usuarioId,
        'usuarioNombre': gasto.usuarioNombre,
      };

      await off.addGastoPendiente(mapOffline);

      // UI optimista con id temporal
      final temp = gasto.copyWith(id: tempId);
      _gastos.insert(0, temp);
      await _saveCache();
      return tempId;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Sincroniza lo pendiente (solo admins) cuando regresa internet.
  Future<void> syncPendientes() async {
    // Si hay usuario online, refrescamos su perfil
    if (_uid != null) await _cargarUsuarioActual();

    bool esAdmin = (_me?.rol == 'administrador');
    if (!esAdmin) {
      esAdmin = await _isOfflineAdmin(); // permite sync si estabas como admin local
    }
    if (!esAdmin) return;

    final online = await hasInternet();
    _isOnline = online;
    if (!online) return;

    final pendientes = await off.popGastosPendientes();
    if (pendientes.isEmpty) return;

    for (final m in pendientes) {
      try {
        final dataMap = Map<String, dynamic>.from(m);
        final doc = _db.collection('gastos').doc();

        final normalized = Map<String, dynamic>.from(dataMap);
        final fechaStr = normalized['fecha'];
        if (fechaStr is String) {
          normalized['fecha'] = DateTime.tryParse(fechaStr) ?? DateTime.now();
        }

        await doc.set({
          ...normalized,
          'id': doc.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Si falla, reencola para no perder
        await off.addGastoPendiente(m);
      }
    }

    // Refrescamos lista visible
    try {
      await refrescarDesdeFirebase();
    } catch (_) {}
  }

  // ------- Consulta simple (últimos N) --------
  Future<void> refrescarDesdeFirebase({int limit = 50}) async {
    final snap = await _db
        .collection('gastos')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    final fresh = snap.docs.map((d) => Gasto.fromFirestore(d.id, d.data())).toList();

    // Mantener arriba los temporales (tmp_) si existieran
    final temporales = _gastos.where((g) => (g.id ?? '').startsWith('tmp_')).toList();
    _gastos = [...temporales, ...fresh];
    await _saveCache();
    notifyListeners();
  }
}
