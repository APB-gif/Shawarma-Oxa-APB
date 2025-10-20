import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../datos/servicios/auth/auth_service.dart';

class UsuariosPage extends StatelessWidget {
  const UsuariosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    Widget _buildLockedView() {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.lock, size: 48, color: Color(0xFF64748B)),
              SizedBox(height: 12),
              Text('Inicia sesión para ver la lista de usuarios',
                  style: TextStyle(fontSize: 16, color: Color(0xFF64748B))),
            ]),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      body: Builder(builder: (context) {
        // Si no hay sesión y no estamos en modo offline, no subscribimos al stream
        if (auth.currentUser == null && !auth.offlineListenable.value) {
          return _buildLockedView();
        }

        final stream = FirebaseFirestore.instance
            .collection('users')
            .orderBy('fechaCreacion', descending: true)
            .snapshots();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (!snap.hasData)
              return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;
            if (docs.isEmpty)
              return const Center(child: Text('Sin usuarios aún'));

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final d = docs[i].data();
                final uid = d['uid'] as String? ?? docs[i].id;
                final email = d['email'] as String? ?? '';
                final nombre = d['nombre'] as String? ?? 'Usuario';
                final rol = d['rol'] as String? ?? 'trabajador';

                return ListTile(
                  leading: CircleAvatar(
                      child: Text(nombre.isNotEmpty ? nombre[0] : '?')),
                  title: Text(nombre),
                  subtitle: Text(email),
                  trailing: DropdownButton<String>(
                    value: rol,
                    items: const [
                      DropdownMenuItem(
                          value: 'administrador', child: Text('Administrador')),
                      DropdownMenuItem(
                          value: 'trabajador', child: Text('Trabajador')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      try {
                        await auth.updateUserRole(uid, v);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Rol actualizado a $v')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('No se pudo actualizar: $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                  ),
                );
              },
            );
          },
        );
      }),
    );
  }
}
