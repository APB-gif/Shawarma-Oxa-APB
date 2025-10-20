// lib/datos/servicios/user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Método principal para obtener todos los datos de un usuario ---
  // Devuelve un mapa con todos los campos del documento del usuario.
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      // Apunta a la colección 'users' y al documento con el 'uid' del usuario.
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        // Si el documento existe, devuelve sus datos.
        return doc.data() as Map<String, dynamic>?;
      }

      // Si no existe, devuelve null.
      print("Advertencia: No se encontró un documento para el uid: $uid");
      return null;
    } catch (e) {
      // Si hay un error en la comunicación con Firestore, lo muestra en consola.
      print("Error al obtener datos del usuario: $e");
      return null;
    }
  }

  // --- Método específico para obtener solo el rol del usuario ---
  // Es más eficiente si solo necesitas saber el rol y no todos sus datos.
  Future<String?> getUserRole(String uid) async {
    try {
      final userData = await getUserData(uid);

      // Comprueba si obtuvimos datos y si esos datos contienen la clave 'rol'.
      if (userData != null && userData.containsKey('rol')) {
        return userData['rol'];
      }

      // Si el usuario existe pero no tiene un campo 'rol' (por alguna razón),
      // es más seguro asignarle un rol por defecto.
      if (userData != null && !userData.containsKey('rol')) {
        return 'usuario';
      }

      // Si el usuario no fue encontrado, devuelve null.
      return null;
    } catch (e) {
      print("Error al obtener el rol del usuario: $e");
      return null;
    }
  }
}
