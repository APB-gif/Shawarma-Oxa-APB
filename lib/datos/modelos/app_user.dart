enum Role { administrador, trabajador, espectador, fueraDeServicio }

class AppUser {
  final String uid;
  final String email;
  final String nombre;
  final Role rol; // Cambiado a Enum

  AppUser({
    required this.uid,
    required this.email,
    required this.nombre,
    required this.rol,
  });

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      nombre: data['nombre'] ?? 'Usuario',
      rol: _roleFromString(data['rol'] ?? 'trabajador'),
    );
  }

  // Convertir String a Role
  static Role _roleFromString(String role) {
    switch (role) {
      case 'administrador':
        return Role.administrador;
      case 'trabajador':
        return Role.trabajador;
      case 'espectador':
        return Role.espectador;
      case 'fuera de servicio':
        return Role.fueraDeServicio;
      default:
        return Role.trabajador;
    }
  }
}
