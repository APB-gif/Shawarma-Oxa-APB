import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UsuariosPage extends StatelessWidget {
  const UsuariosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error al cargar usuarios'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No hay usuarios'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index];
              final data = d.data();
              final displayName = (data['displayName'] ?? data['name'] ?? d.id) as String;
              final role = (data['rol'] ?? 'sin rol') as String;
              final habilitado = (data['habilitado_fuera_horario'] ?? false) as bool;

              return ListTile(
                title: Text(displayName),
                subtitle: Text('Rol: $role'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Fuera horario'),
                    const SizedBox(width: 8),
                    Switch(
                      value: habilitado,
                      onChanged: (v) async {
                        try {
                          await FirebaseFirestore.instance.collection('users').doc(d.id).set(
                            {'habilitado_fuera_horario': v},
                            SetOptions(merge: true),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Actualizado: $displayName')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
