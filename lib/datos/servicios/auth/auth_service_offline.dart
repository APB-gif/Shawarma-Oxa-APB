// lib/datos/servicios/auth/auth_service_offline.dart
//
// Extensión *no invasiva* para tu AuthService existente.
// Añade modo Invitado y modo Admin Local (PIN) sin tocar tu arquitectura.
// Funciona aunque AuthService NO extienda ChangeNotifier.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:shawarma_pos_nuevo/datos/servicios/auth/auth_service.dart';

/// Claves en SharedPreferences
const _kOfflineMode = 'offline_mode'; // bool
const _kOfflineUserName = 'offline_user_name'; // String
const _kOfflineRole = 'offline_role'; // 'guest' | 'admin'
const _kOfflineAdminPinHash = 'offline_admin_pin'; // String (sha256) LEGACY
const _kOfflineSalesPinHash = 'offline_sales_pin'; // String (sha256) LEGACY
const _kOfflineAdminPins = 'offline_admin_pins'; // List<String> (sha256)
const _kOfflineSalesPins = 'offline_sales_pins'; // List<String> (sha256)
// Caché local opcional de PINs en claro para la UI
const _kOfflineAdminPinsPlainLocal = 'offline_admin_pins_plain'; // List<String>
const _kOfflineSalesPinsPlainLocal = 'offline_sales_pins_plain'; // List<String>

// Firestore remote config path
const String _kPinsCollection = 'config';
const String _kPinsDoc = 'offline_pins';
const String _kFieldAdminPin = 'adminPinHash'; // LEGACY single
const String _kFieldSalesPin = 'salesPinHash'; // LEGACY single
const String _kFieldAdminPins = 'adminPinHashes'; // List<String>
const String _kFieldSalesPins = 'salesPinHashes'; // List<String>
const String _kPinsSecretDoc = 'offline_pins_secrets';
const String _kFieldAdminPinsPlain = 'adminPinsPlain'; // List<String> (plaintext) - secrets doc
const String _kFieldSalesPinsPlain = 'salesPinsPlain'; // List<String>

/// Estado interno (singleton) para exponer si la app está en modo offline.
class _OfflineState {
  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);
  static final _OfflineState instance = _OfflineState._();
  _OfflineState._();
}

/// ==============================
///  MODO OFFLINE (Invitado/Admin)
/// ==============================
extension AuthServiceOfflineX on AuthService {
  /// ¿La app está en sesión local (invitado o admin) sin auth?
  bool get isOffline => _OfflineState.instance.isOffline.value;

  /// Listenable por si la UI quiere reaccionar a cambios.
  ValueListenable<bool> get offlineListenable =>
      _OfflineState.instance.isOffline;

  /// Nombre mostrado almacenado cuando se entró offline.
  Future<String?> getOfflineDisplayName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kOfflineUserName);
  }

  /// ¿Es admin local?
  Future<bool> isOfflineAdmin() async {
    final p = await SharedPreferences.getInstance();
    return (p.getBool(_kOfflineMode) ?? false) &&
        (p.getString(_kOfflineRole) == 'admin');
  }

  /// ¿Ya hay PIN configurado para admin local?
  Future<bool> hasOfflineAdminPin() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kOfflineAdminPins);
    if (list != null && list.isNotEmpty) return true;
    return p.containsKey(_kOfflineAdminPinHash);
  }

  /// Configura PIN (hash sha256).
  Future<void> setOfflineAdminPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final hash = sha256.convert(utf8.encode(pin)).toString();
    // migrate to list storage
    final list = p.getStringList(_kOfflineAdminPins) ?? <String>[];
    if (!list.contains(hash)) list.add(hash);
    await p.setStringList(_kOfflineAdminPins, list);
    await p.remove(_kOfflineAdminPinHash);
  }

  /// Valida PIN de admin local contra el valor cacheado (previamente sincronizado desde Firestore).
  Future<bool> validateOfflineAdminPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final hash = sha256.convert(utf8.encode(pin)).toString();
    final list = p.getStringList(_kOfflineAdminPins);
    if (list != null) return list.contains(hash);
    final legacy = p.getString(_kOfflineAdminPinHash);
    if (legacy != null) return legacy == hash;
    return false;
  }

  /// ¿Ya hay PIN configurado para ventas (modo invitado offline)?
  Future<bool> hasOfflineSalesPin() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kOfflineSalesPins);
    if (list != null && list.isNotEmpty) return true;
    return p.containsKey(_kOfflineSalesPinHash);
  }

  /// Configura PIN de ventas (hash sha256).
  Future<void> setOfflineSalesPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final hash = sha256.convert(utf8.encode(pin)).toString();
    final list = p.getStringList(_kOfflineSalesPins) ?? <String>[];
    if (!list.contains(hash)) list.add(hash);
    await p.setStringList(_kOfflineSalesPins, list);
    await p.remove(_kOfflineSalesPinHash);
  }

  /// Valida PIN de ventas contra el valor cacheado (previamente sincronizado desde Firestore).
  Future<bool> validateOfflineSalesPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final hash = sha256.convert(utf8.encode(pin)).toString();
    final list = p.getStringList(_kOfflineSalesPins);
    if (list != null) return list.contains(hash);
    final legacy = p.getString(_kOfflineSalesPinHash);
    if (legacy != null) return legacy == hash;
    return false;
  }

  /// Borra el PIN de admin local (deja de estar configurado).
  Future<void> clearOfflineAdminPin() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kOfflineAdminPinHash);
    await p.remove(_kOfflineAdminPins);
  }

  /// Borra el PIN de ventas (vuelve a usar el PIN por defecto si no se configura otro).
  Future<void> clearOfflineSalesPin() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kOfflineSalesPinHash);
    await p.remove(_kOfflineSalesPins);
  }

  /// ----------------------------
  /// Remote (Firestore) helpers
  /// ----------------------------

  /// Sincroniza desde Firestore los PINs y los cachea localmente (hashes).
  Future<void> syncPinsFromRemote() async {
    final doc = await FirebaseFirestore.instance
        .collection(_kPinsCollection)
        .doc(_kPinsDoc)
        .get();
    final p = await SharedPreferences.getInstance();
    if (doc.exists) {
      final data = doc.data();
      final adminList = (data?[_kFieldAdminPins] as List?)
              ?.whereType<String>()
              .toList() ??
          [];
      final salesList = (data?[_kFieldSalesPins] as List?)
              ?.whereType<String>()
              .toList() ??
          [];

      // Legacy single fields support
      final legacyAdmin = data?[_kFieldAdminPin] as String?;
      if (legacyAdmin != null && legacyAdmin.isNotEmpty &&
          !adminList.contains(legacyAdmin)) {
        adminList.add(legacyAdmin);
      }
      final legacySales = data?[_kFieldSalesPin] as String?;
      if (legacySales != null && legacySales.isNotEmpty &&
          !salesList.contains(legacySales)) {
        salesList.add(legacySales);
      }

      if (adminList.isNotEmpty) {
        await p.setStringList(_kOfflineAdminPins, adminList);
      } else {
        await p.remove(_kOfflineAdminPins);
      }
      if (salesList.isNotEmpty) {
        await p.setStringList(_kOfflineSalesPins, salesList);
      } else {
        await p.remove(_kOfflineSalesPins);
      }
    } else {
      await p.remove(_kOfflineAdminPins);
      await p.remove(_kOfflineSalesPins);
    }
  }

  /// Establece el PIN de admin en Firestore y actualiza el cache local.
  Future<void> setRemoteAdminPin(String pin) async {
    // Backward-compatible: treat as ADD to the list
    await addRemoteAdminPin(pin);
  }

  Future<void> addRemoteAdminPin(String pin) async {
    final hash = sha256.convert(utf8.encode(pin)).toString();
    final ref = FirebaseFirestore.instance
        .collection(_kPinsCollection)
        .doc(_kPinsDoc);
    await ref.set({
      _kFieldAdminPins: FieldValue.arrayUnion([hash]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // Also store plaintext in a separate secrets doc (admin-only access in rules)
    final secretRef = FirebaseFirestore.instance.collection(_kPinsCollection).doc(_kPinsSecretDoc);
    await secretRef.set({
      _kFieldAdminPinsPlain: FieldValue.arrayUnion([pin]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kOfflineAdminPins) ?? <String>[];
    if (!list.contains(hash)) list.add(hash);
    await p.setStringList(_kOfflineAdminPins, list);
    // Cache local del PIN en claro para que la UI lo muestre al reingresar
    final plainList = p.getStringList(_kOfflineAdminPinsPlainLocal) ?? <String>[];
    if (!plainList.contains(pin)) plainList.add(pin);
    await p.setStringList(_kOfflineAdminPinsPlainLocal, plainList);
  }

  /// Elimina el PIN de admin en Firestore y en cache local.
  Future<void> clearRemoteAdminPin() async {
    final ref = FirebaseFirestore.instance
        .collection(_kPinsCollection)
        .doc(_kPinsDoc);
    await ref.set({
      _kFieldAdminPins: FieldValue.delete(),
      _kFieldAdminPin: FieldValue.delete(), // legacy cleanup
      'updatedAt': FieldValue.serverTimestamp()
    }, SetOptions(merge: true));
    final secretRef = FirebaseFirestore.instance.collection(_kPinsCollection).doc(_kPinsSecretDoc);
    await secretRef.set({
      _kFieldAdminPinsPlain: FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await clearOfflineAdminPin();
    // Limpiar caché local de plaintext
    final p = await SharedPreferences.getInstance();
    await p.remove(_kOfflineAdminPinsPlainLocal);
  }

  Future<void> removeRemoteAdminPin(String pin) async {
    final hash = sha256.convert(utf8.encode(pin)).toString();
    final ref = FirebaseFirestore.instance
        .collection(_kPinsCollection)
        .doc(_kPinsDoc);
    await ref.set({
      _kFieldAdminPins: FieldValue.arrayRemove([hash]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final secretRef = FirebaseFirestore.instance.collection(_kPinsCollection).doc(_kPinsSecretDoc);
    await secretRef.set({
      _kFieldAdminPinsPlain: FieldValue.arrayRemove([pin]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kOfflineAdminPins) ?? <String>[];
    list.remove(hash);
    if (list.isEmpty) {
      await p.remove(_kOfflineAdminPins);
    } else {
      await p.setStringList(_kOfflineAdminPins, list);
    }
    // Actualizar caché local de plaintext
    final plainList = p.getStringList(_kOfflineAdminPinsPlainLocal) ?? <String>[];
    plainList.remove(pin);
    if (plainList.isEmpty) {
      await p.remove(_kOfflineAdminPinsPlainLocal);
    } else {
      await p.setStringList(_kOfflineAdminPinsPlainLocal, plainList);
    }
  }

  /// Establece el PIN de ventas en Firestore y actualiza el cache local.
  Future<void> setRemoteSalesPin(String pin) async {
    await addRemoteSalesPin(pin);
  }

  Future<void> addRemoteSalesPin(String pin) async {
    final hash = sha256.convert(utf8.encode(pin)).toString();
    final ref = FirebaseFirestore.instance
        .collection(_kPinsCollection)
        .doc(_kPinsDoc);
    await ref.set({
      _kFieldSalesPins: FieldValue.arrayUnion([hash]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final secretRef = FirebaseFirestore.instance.collection(_kPinsCollection).doc(_kPinsSecretDoc);
    await secretRef.set({
      _kFieldSalesPinsPlain: FieldValue.arrayUnion([pin]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kOfflineSalesPins) ?? <String>[];
    if (!list.contains(hash)) list.add(hash);
    await p.setStringList(_kOfflineSalesPins, list);
    // Cache local del PIN en claro para la UI
    final plainList = p.getStringList(_kOfflineSalesPinsPlainLocal) ?? <String>[];
    if (!plainList.contains(pin)) plainList.add(pin);
    await p.setStringList(_kOfflineSalesPinsPlainLocal, plainList);
  }

  /// Elimina el PIN de ventas en Firestore y en cache local.
  Future<void> clearRemoteSalesPin() async {
    final ref = FirebaseFirestore.instance
        .collection(_kPinsCollection)
        .doc(_kPinsDoc);
    await ref.set({
      _kFieldSalesPins: FieldValue.delete(),
      _kFieldSalesPin: FieldValue.delete(), // legacy cleanup
      'updatedAt': FieldValue.serverTimestamp()
    }, SetOptions(merge: true));
    final secretRef = FirebaseFirestore.instance.collection(_kPinsCollection).doc(_kPinsSecretDoc);
    await secretRef.set({
      _kFieldSalesPinsPlain: FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await clearOfflineSalesPin();
    // Limpiar caché local de plaintext
    final p = await SharedPreferences.getInstance();
    await p.remove(_kOfflineSalesPinsPlainLocal);
  }

  Future<void> removeRemoteSalesPin(String pin) async {
    final hash = sha256.convert(utf8.encode(pin)).toString();
    final ref = FirebaseFirestore.instance
        .collection(_kPinsCollection)
        .doc(_kPinsDoc);
    await ref.set({
      _kFieldSalesPins: FieldValue.arrayRemove([hash]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final secretRef = FirebaseFirestore.instance.collection(_kPinsCollection).doc(_kPinsSecretDoc);
    await secretRef.set({
      _kFieldSalesPinsPlain: FieldValue.arrayRemove([pin]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_kOfflineSalesPins) ?? <String>[];
    list.remove(hash);
    if (list.isEmpty) {
      await p.remove(_kOfflineSalesPins);
    } else {
      await p.setStringList(_kOfflineSalesPins, list);
    }
    // Actualizar caché local de plaintext
    final plainList = p.getStringList(_kOfflineSalesPinsPlainLocal) ?? <String>[];
    plainList.remove(pin);
    if (plainList.isEmpty) {
      await p.remove(_kOfflineSalesPinsPlainLocal);
    } else {
      await p.setStringList(_kOfflineSalesPinsPlainLocal, plainList);
    }
  }

  /// Obtiene estado remoto de existencia de PINs.
  Future<Map<String, bool>> getRemotePinsState() async {
    final doc = await FirebaseFirestore.instance
        .collection(_kPinsCollection)
        .doc(_kPinsDoc)
        .get();
    if (!doc.exists) return {'admin': false, 'sales': false};
    final data = doc.data();
    final hasAdmin = ((data?[_kFieldAdminPins] as List?)?.isNotEmpty == true) ||
        ((data?[_kFieldAdminPin] as String?)?.isNotEmpty == true);
    final hasSales = ((data?[_kFieldSalesPins] as List?)?.isNotEmpty == true) ||
        ((data?[_kFieldSalesPin] as String?)?.isNotEmpty == true);
    return {'admin': hasAdmin, 'sales': hasSales};
  }

  /// Devuelve listas de hashes de PIN remotos (para contadores).
  Future<Map<String, List<String>>> getRemotePins() async {
    final doc = await FirebaseFirestore.instance
        .collection(_kPinsCollection)
        .doc(_kPinsDoc)
        .get();
    if (!doc.exists) return {'admin': [], 'sales': []};
    final data = doc.data();
    final admin = (data?[_kFieldAdminPins] as List?)?.whereType<String>().toList() ?? [];
    final sales = (data?[_kFieldSalesPins] as List?)?.whereType<String>().toList() ?? [];
    // legacy single
    final legacyAdmin = data?[_kFieldAdminPin] as String?;
    if (legacyAdmin != null && legacyAdmin.isNotEmpty && !admin.contains(legacyAdmin)) admin.add(legacyAdmin);
    final legacySales = data?[_kFieldSalesPin] as String?;
    if (legacySales != null && legacySales.isNotEmpty && !sales.contains(legacySales)) sales.add(legacySales);
    return {'admin': admin, 'sales': sales};
  }

  /// Devuelve listas de PINs en texto plano (solo admins pueden leer este documento según las reglas)
  Future<Map<String, List<String>>> getRemotePlainPins() async {
    final doc = await FirebaseFirestore.instance
        .collection(_kPinsCollection)
        .doc(_kPinsSecretDoc)
        .get();
    if (!doc.exists) return {'admin': [], 'sales': []};
    final data = doc.data();
    final admin = (data?[_kFieldAdminPinsPlain] as List?)?.whereType<String>().toList() ?? [];
    final sales = (data?[_kFieldSalesPinsPlain] as List?)?.whereType<String>().toList() ?? [];
    return {'admin': admin, 'sales': sales};
  }

  /// Devuelve el caché local de PINs en claro (persistido en SharedPreferences)
  Future<Map<String, List<String>>> getLocalPlainPinsCache() async {
    final p = await SharedPreferences.getInstance();
    final admin = p.getStringList(_kOfflineAdminPinsPlainLocal) ?? <String>[];
    final sales = p.getStringList(_kOfflineSalesPinsPlainLocal) ?? <String>[];
    return {'admin': admin, 'sales': sales};
  }

  /// Inicia sesión local como **invitado**.
  Future<void> signInOffline({required String displayName}) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOfflineMode, true);
    await p.setString(_kOfflineUserName, displayName);
    await p.setString(_kOfflineRole, 'guest');
    _OfflineState.instance.isOffline.value = true;
  }

  /// Inicia sesión local como **admin** (si el PIN es válido).
  Future<bool> signInOfflineAdmin({
    required String displayName,
    required String pin,
  }) async {
    if (!await validateOfflineAdminPin(pin)) return false;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOfflineMode, true);
    await p.setString(_kOfflineUserName, displayName);
    await p.setString(_kOfflineRole, 'admin');
    _OfflineState.instance.isOffline.value = true;
    return true;
  }

  /// ¿Puedo reanudar una sesión (FirebaseAuth o Invitado/Admin local cacheado)?
  Future<bool> canResumeCachedSession() async {
    final p = await SharedPreferences.getInstance();
    final hasFirebaseUser = FirebaseAuth.instance.currentUser != null;
    final hasGuestOrAdmin = p.getBool(_kOfflineMode) ?? false;
    return hasFirebaseUser || hasGuestOrAdmin;
  }

  /// Reanuda sesión cacheada (Firebase user o invitado/admin).
  Future<void> resumeCachedSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _OfflineState.instance.isOffline.value = false;
      return;
    }
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_kOfflineMode) ?? false) {
      _OfflineState.instance.isOffline.value = true;
    }
  }

  /// Limpia el modo offline (guest o admin) y cierra sesión si corresponde.
  Future<void> clearOfflineMode() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kOfflineMode);
    await p.remove(_kOfflineUserName);
    await p.remove(_kOfflineRole);
    _OfflineState.instance.isOffline.value = false;
  }
}

/// =======================================
///  PERFIL DE USUARIO (para AuthGate)
/// =======================================
extension AuthServiceUserDocX on AuthService {
  Future<void> ensureUserDocForCurrentUser() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    final prefs = await SharedPreferences.getInstance();
    final offlineName = prefs.getString(_kOfflineUserName);

    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    await ref.set(
      {
        'uid': u.uid,
        'email': u.email,
        'displayName': u.displayName ?? offlineName ?? 'Usuario',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
