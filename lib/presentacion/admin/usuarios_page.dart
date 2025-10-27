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
                      tooltip: 'Configurar horario',
                      icon: const Icon(Icons.access_time),
                      onPressed: () => _showConfigureScheduleDialog(context, d.id, displayName),
                    ),
                    IconButton(
                      tooltip: 'Asignar horario',
                      icon: const Icon(Icons.schedule),
                      onPressed: () => _showAssignScheduleDialog(context, d.id, displayName),
                    ),
                    IconButton(
                      tooltip: 'Ver/Editar horarios',
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: () => _showUserSchedulesDialog(context, d.id, displayName),
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

  Future<void> _showUserSchedulesDialog(BuildContext context, String userId, String displayName) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Horarios de $displayName'),
          content: SizedBox(
            width: 420,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('horarios')
                  .where('userId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return const Text('Error al cargar horarios');
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(height: 8),
                      Text('Este usuario no tiene horarios asignados.'),
                    ],
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final ref = docs[i].reference;
                    final d = docs[i].data();
                    final s = (d['startTime'] ?? '') as String;
                    final e = (d['endTime'] ?? '') as String;
                    final active = (d['active'] ?? true) as bool;
                    final days = (d['days'] is List)
                        ? List<int>.from(d['days'] as List)
                        : <int>[];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('$s - $e', style: const TextStyle(fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Switch(
                                  value: active,
                                  onChanged: (v) async {
                                    await ref.set({'active': v, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                                  },
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: List.generate(7, (idx) {
                                const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                                final selected = days.contains(idx);
                                return ChoiceChip(
                                  label: Text(labels[idx]),
                                  selected: selected,
                                  onSelected: (sel) async {
                                    final newDays = List<int>.from(days);
                                    if (sel && !newDays.contains(idx)) newDays.add(idx);
                                    if (!sel) newDays.remove(idx);
                                    newDays.sort();
                                    await ref.set({'days': newDays, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                                  },
                                );
                              }),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () async {
                                    final newStart = await _pickTime(context, s);
                                    if (newStart == null) return;
                                    await ref.set({'startTime': newStart, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                                  },
                                  child: const Text('Cambiar inicio'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () async {
                                    final newEnd = await _pickTime(context, e);
                                    if (newEnd == null) return;
                                    await ref.set({'endTime': newEnd, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                                  },
                                  child: const Text('Cambiar fin'),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Eliminar horario'),
                                        content: const Text('¿Seguro que deseas eliminar este horario?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                                        ],
                                      ),
                                    );
                                    if (ok == true) await ref.delete();
                                  },
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showAssignScheduleDialog(context, userId, displayName);
              },
              child: const Text('Agregar desde plantilla'),
            ),
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
          ],
        );
      },
    );
  }

  Future<String?> _pickTime(BuildContext context, String current) async {
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: parts.length > 1 ? int.tryParse(parts[0]) ?? 17 : 17,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return null;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _showConfigureScheduleDialog(BuildContext context, String userId, String displayName) async {
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 17, minute: 0);
    final selectedDays = <int>{0,1,2,3,4,5,6};

    String fmt(TimeOfDay t) => t.hour.toString().padLeft(2, '0') + ':' + t.minute.toString().padLeft(2, '0');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: Text('Configurar horario - $displayName'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Presets'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    OutlinedButton(
                      onPressed: () => setState(() { start = const TimeOfDay(hour: 9, minute: 0); end = const TimeOfDay(hour: 17, minute: 0); }),
                      child: const Text('Mañana 09:00-17:00'),
                    ),
                    OutlinedButton(
                      onPressed: () => setState(() { start = const TimeOfDay(hour: 17, minute: 0); end = const TimeOfDay(hour: 23, minute: 0); }),
                      child: const Text('Noche 17:00-23:00'),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Inicio'),
                        subtitle: Text(fmt(start)),
                        onTap: () async {
                          final p = await showTimePicker(context: context, initialTime: start);
                          if (p != null) setState(() => start = p);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fin'),
                        subtitle: Text(fmt(end)),
                        onTap: () async {
                          final p = await showTimePicker(context: context, initialTime: end);
                          if (p != null) setState(() => end = p);
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  const Text('Días'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: List.generate(7, (idx) {
                      const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                      final selected = selectedDays.contains(idx);
                      return ChoiceChip(
                        label: Text(labels[idx]),
                        selected: selected,
                        onSelected: (sel) {
                          setState(() {
                            if (sel) { selectedDays.add(idx); } else { selectedDays.remove(idx); }
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    // Desactivar otros horarios activos del usuario
                    final q = await FirebaseFirestore.instance.collection('horarios').where('userId', isEqualTo: userId).get();
                    final batch = FirebaseFirestore.instance.batch();
                    for (final doc in q.docs) {
                      batch.set(doc.reference, {'active': false, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                    }
                    // Crear el nuevo horario activo
                    await FirebaseFirestore.instance.collection('horarios').add({
                      'userId': userId,
                      'userName': displayName,
                      'startTime': fmt(start),
                      'endTime': fmt(end),
                      'days': selectedDays.toList()..sort(),
                      'active': true,
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    await batch.commit();
                    if (context.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horario configurado correctamente')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        });
      },
    );
  }
}
