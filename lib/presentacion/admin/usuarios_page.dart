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
                    IconButton(
                      tooltip: 'Asignar horario',
                      icon: const Icon(Icons.schedule),
                      onPressed: () => _showAssignScheduleDialog(context, d.id, displayName),
                    ),
                    const SizedBox(width: 8),
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

  Future<void> _showAssignScheduleDialog(BuildContext context, String userId, String displayName) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Seleccionar plantilla de horario'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance.collection('horarios').where('active', isEqualTo: true).get(),
              builder: (context, snap) {
                if (snap.hasError) return const Text('Error al cargar plantillas');
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs.where((d) {
                  final data = d.data();
                  final uid = (data['userId'] ?? '') as String;
                  final name = (data['userName'] ?? '') as String;
                  return uid.trim().isEmpty || name.toString().toUpperCase().startsWith('TEMPLATE');
                }).toList();
                if (docs.isEmpty) return const Text('No hay plantillas disponibles');
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final title = (d['userName'] ?? 'Plantilla') as String;
                    final s = (d['startTime'] ?? '') as String;
                    final e = (d['endTime'] ?? '') as String;
                    return ListTile(
                      title: Text(title),
                      subtitle: Text('$s - $e'),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        try {
                          final copy = Map<String, dynamic>.from(d);
                          copy['userId'] = userId;
                          copy['userName'] = displayName;
                          copy['createdAt'] = FieldValue.serverTimestamp();
                          copy['updatedAt'] = FieldValue.serverTimestamp();
                          copy['active'] = true;
                          final newRef = await FirebaseFirestore.instance.collection('horarios').add(copy);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Horario asignado (id: ${newRef.id})')));
                        } catch (err) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al asignar: $err')));
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
          ],
        );
      },
    );
  }
}
