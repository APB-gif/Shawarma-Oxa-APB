import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier;

import 'package:shawarma_pos_nuevo/datos/modelos/app_user.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Flag de modo offline (invitado)
  final ValueNotifier<bool> offlineListenable = ValueNotifier<bool>(false);
  void enableOfflineMode() => offlineListenable.value = true;
  void disableOfflineMode() => offlineListenable.value = false;

  /// Alias para compatibilidad con llamadas existentes
  Future<void> clearOfflineMode() async {
    disableOfflineMode();
  }

  /// ⚠️ Cambia por tu correo para forzar admin (además del primer usuario).
  static const List<String> _adminEmails = [
    '2000aharhel@gmail.com', // <-- cámbialo por el tuyo
  ];

  User? get currentUser => _firebaseAuth.currentUser;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<AppUser?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) return AppUser.fromFirestore(doc.data()!, uid);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Ingreso con Google.
// Asegúrate de que el widget de Firebase Auth esté correctamente configurado
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      try {
        final cred = await _firebaseAuth
            .signInWithPopup(provider); // Usar Popup en lugar de Redirect
        if (cred.user != null) {
          await _ensureUserDoc(cred.user!);
          disableOfflineMode();
        }
        return cred;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' || e.code == 'popup-blocked') {
          await _firebaseAuth.signInWithRedirect(provider);
          return null; // El resultado llega por authStateChanges
        }
        rethrow;
      }
    } else {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile')
        ..setCustomParameters({'prompt': 'select_account'});

      final cred = await _firebaseAuth.signInWithProvider(provider);
      if (cred.user != null) {
        await _ensureUserDoc(cred.user!);
        disableOfflineMode();
      }
      return cred;
    }
  }

  /// Email/Password
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final cred = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    disableOfflineMode();
    await ensureUserDocForCurrentUser();
    return cred;
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> _ensureUserDoc(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;

    final noHayAdmins = await _noAdminsExist();
    final debeSerAdmin = noHayAdmins || _adminEmails.contains(user.email);

    await ref.set({
      'uid': user.uid,
      'email': user.email,
      'nombre': (user.displayName ?? '').trim(),
      // Rol por defecto:
      //  - Si no hay administradores aún, o el correo está en la whitelist, será 'administrador'.
      //  - En cualquier otro caso, ahora se crea como 'espectador' (solo lectura hasta que un admin cambie el rol).
      'rol': debeSerAdmin ? 'administrador' : 'espectador',
      'fechaCreacion': Timestamp.now(),
    });
  }

  Future<void> ensureUserDocForCurrentUser() async {
    final u = _firebaseAuth.currentUser;
    if (u != null) await _ensureUserDoc(u);
  }

  Future<void> updateUserRole(String uid, String newRole) async {
    // Validar que el nuevo rol sea uno de los roles permitidos
    if (!['administrador', 'trabajador', 'espectador', 'fuera de servicio']
        .contains(newRole)) {
      throw Exception('Rol no permitido.');
    }
    await _firestore.collection('users').doc(uid).update({'rol': newRole});
  }

  Future<void> changeUserRoleSafe({
    required String targetUid,
    required String
        newRole, // 'administrador' | 'trabajador' | 'espectador' | 'fuera de servicio'
  }) async {
    final db = _firestore;
    final currentUid = _firebaseAuth.currentUser!.uid;

    await db.runTransaction((tx) async {
      final adminsSnap = await db
          .collection('users')
          .where('rol', isEqualTo: 'administrador')
          .get();

      final adminCount = adminsSnap.docs.length;
      final isTargetAdminNow = adminsSnap.docs.any((d) => d.id == targetUid);

      final isDemotion = newRole != 'administrador';
      final isLastAdmin = isDemotion && isTargetAdminNow && adminCount == 1;
      if (isLastAdmin) {
        throw Exception('No puedes dejar el sistema sin administradores.');
      }

      final isSelf = targetUid == currentUid;
      if (isSelf && isDemotion && adminCount == 1) {
        throw Exception(
            'No puedes quitarte tu propio rol si eres el único administrador.');
      }

      // Actualiza el rol del usuario
      tx.update(db.collection('users').doc(targetUid), {'rol': newRole});
    });
  }

  Future<void> setUserDisplayName(String name) async {
    await updateProfile(name: name);
  }

  Future<void> updateProfile({String? name, String? photoUrl}) async {
    final u = _firebaseAuth.currentUser;
    if (u == null) return;

    final updates = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) {
      updates['nombre'] = name.trim();
    }
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      updates['photoUrl'] = photoUrl.trim();
    }
    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(u.uid).update(updates);
    }

    try {
      if (name != null && name.trim().isNotEmpty) {
        await u.updateDisplayName(name.trim());
      }
      if (photoUrl != null && photoUrl.trim().isNotEmpty) {
        await u.updatePhotoURL(photoUrl.trim());
      }
    } catch (_) {}
  }

  Future<String> uploadProfilePhoto(
    Uint8List bytes, {
    String? filename,
    String contentType = 'image/jpeg',
  }) async {
    final u = _firebaseAuth.currentUser;
    if (u == null) throw Exception('No hay usuario autenticado');

    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeName = (filename?.trim().isNotEmpty == true)
        ? filename!.trim()
        : 'avatar_$ts.jpg';

    final ref = FirebaseStorage.instance.ref('user_photos/${u.uid}/$safeName');
    final meta = SettableMetadata(
      contentType: contentType,
      cacheControl: 'public, max-age=3600',
    );
    await ref.putData(bytes, meta);
    final url = await ref.getDownloadURL();

    await updateProfile(photoUrl: url);
    return url;
  }

  Future<bool> _noAdminsExist() async {
    final q = await _firestore
        .collection('users')
        .where('rol', isEqualTo: 'administrador')
        .limit(1)
        .get();
    return q.docs.isEmpty;
  }

  void logout() {}
}
