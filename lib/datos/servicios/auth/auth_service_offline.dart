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
const _kOfflineAdminPinHash = 'offline_admin_pin'; // String (sha256)
const _kOfflineSalesPinHash = 'offline_sales_pin'; // String (sha256)

// Firestore remote config path
const String _kPinsCollection = 'config';
const String _kPinsDoc = 'offline_pins';
const String _kFieldAdminPin = 'adminPinHash';
const String _kFieldSalesPin = 'salesPinHash';

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
    return p.containsKey(_kOfflineAdminPinHash);
  }

  /// Configura PIN (hash sha256).
  Future<void> setOfflineAdminPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final hash = sha256.convert(utf8.encode(pin)).toString();
    await p.setString(_kOfflineAdminPinHash, hash);
  }

  /// Valida PIN de admin local contra el valor cacheado (previamente sincronizado desde Firestore).
  Future<bool> validateOfflineAdminPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_kOfflineAdminPinHash);
    if (saved == null) return false;
    final hash = sha256.convert(utf8.encode(pin)).toString();
    return saved == hash;
  }

  /// ¿Ya hay PIN configurado para ventas (modo invitado offline)?
  Future<bool> hasOfflineSalesPin() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_kOfflineSalesPinHash);
  }

  /// Configura PIN de ventas (hash sha256).
  Future<void> setOfflineSalesPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final hash = sha256.convert(utf8.encode(pin)).toString();
    await p.setString(_kOfflineSalesPinHash, hash);
  }

  /// Valida PIN de ventas contra el valor cacheado (previamente sincronizado desde Firestore).
  Future<bool> validateOfflineSalesPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_kOfflineSalesPinHash);
    if (saved == null) return false;
    final hash = sha256.convert(utf8.encode(pin)).toString();
    return saved == hash;
  }

  /// Borra el PIN de admin local (deja de estar configurado).
  Future<void> clearOfflineAdminPin() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kOfflineAdminPinHash);
  }

  /// Borra el PIN de ventas (vuelve a usar el PIN por defecto si no se configura otro).
  Future<void> clearOfflineSalesPin() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kOfflineSalesPinHash);
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
      final adminHash = data?[_kFieldAdminPin] as String?;
      final salesHash = data?[_kFieldSalesPin] as String?;
      if (adminHash != null && adminHash.isNotEmpty) {
        await p.setString(_kOfflineAdminPinHash, adminHash);
      } else {
        await p.remove(_kOfflineAdminPinHash);
      }
      if (salesHash != null && salesHash.isNotEmpty) {
        await p.setString(_kOfflineSalesPinHash, salesHash);
      } else {
        await p.remove(_kOfflineSalesPinHash);
      }
    } else {
      await p.remove(_kOfflineAdminPinHash);
      await p.remove(_kOfflineSalesPinHash);
    }
  }

  /// Establece el PIN de admin en Firestore y actualiza el cache local.
  Future<void> setRemoteAdminPin(String pin) async {
    final hash = sha256.convert(utf8.encode(pin)).toString();
    final ref = FirebaseFirestore.instance
        .collection(_kPinsCollection)
        .doc(_kPinsDoc);
    await ref.set({_kFieldAdminPin: hash, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOfflineAdminPinHash, hash);
  }

  /// Elimina el PIN de admin en Firestore y en cache local.
  Future<void> clearRemoteAdminPin() async {
    final ref = FirebaseFirestore.instance
        .collection(_kPinsCollection)
        .doc(_kPinsDoc);
    await ref.set({_kFieldAdminPin: FieldValue.delete(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await clearOfflineAdminPin();
  }

  /// Establece el PIN de ventas en Firestore y actualiza el cache local.
  Future<void> setRemoteSalesPin(String pin) async {
    final hash = sha256.convert(utf8.encode(pin)).toString();
    final ref = FirebaseFirestore.instance
        .collection(_kPinsCollection)
        .doc(_kPinsDoc);
    await ref.set({_kFieldSalesPin: hash, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOfflineSalesPinHash, hash);
  }

  /// Elimina el PIN de ventas en Firestore y en cache local.
  Future<void> clearRemoteSalesPin() async {
    final ref = FirebaseFirestore.instance
        .collection(_kPinsCollection)
        .doc(_kPinsDoc);
    await ref.set({_kFieldSalesPin: FieldValue.delete(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await clearOfflineSalesPin();
  }

  /// Obtiene estado remoto de existencia de PINs.
  Future<Map<String, bool>> getRemotePinsState() async {
    final doc = await FirebaseFirestore.instance
        .collection(_kPinsCollection)
        .doc(_kPinsDoc)
        .get();
    if (!doc.exists) return {'admin': false, 'sales': false};
    final data = doc.data();
    final hasAdmin = (data?[_kFieldAdminPin] as String?)?.isNotEmpty == true;
    final hasSales = (data?[_kFieldSalesPin] as String?)?.isNotEmpty == true;
    return {'admin': hasAdmin, 'sales': hasSales};
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
