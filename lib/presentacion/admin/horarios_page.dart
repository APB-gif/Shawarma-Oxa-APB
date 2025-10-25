import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HorariosPage extends StatelessWidget {
  const HorariosPage({super.key});

  String _daysLabel(List<dynamic>? days) {
    if (days == null || days.isEmpty) return 'Todos los días';
    final mapping = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    return (days.map((d) => mapping[(d as int) % 7]).join(', '));
  }

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('horarios').orderBy('userName');

    return Scaffold(
      appBar: AppBar(title: const Text('Horarios de Personal')),
      body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream: col.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          return ListView.separated(
            itemCount: docs.length + 1,
            separatorBuilder: (_,__)=>const Divider(height:0),
            itemBuilder: (ctx, i) {
              if (i==0) {
                return ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Crear nuevo horario'),
                  onTap: () => _showEditor(context),
                );
              }
              final d = docs[i-1];
              final data = d.data();
              final id = d.id;
              final userName = data['userName'] as String? ?? 'Usuario';
              final start = data['startTime'] as String? ?? '--:--';
              final end = data['endTime'] as String? ?? '--:--';
              final days = data['days'] as List<dynamic>?;
              final active = data['active'] as bool? ?? true;

              return ListTile(
                leading: CircleAvatar(child: Text(userName.isNotEmpty? userName[0] : '?')),
                title: Text(userName),
                subtitle: Text('$start — $end • ${_daysLabel(days)}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v=='edit') _showEditor(context, docId: id, initial: data);
                    if (v=='delete') {
                      final ok = await showDialog<bool>(context: context, builder: (c)=>AlertDialog(
                        title: const Text('Eliminar horario'),
                        content: const Text('¿Eliminar este horario?'),
                        actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Cancelar')), FilledButton(onPressed: ()=>Navigator.pop(c,true), child: const Text('Eliminar'))],
                      ));
                      if (ok==true) await FirebaseFirestore.instance.collection('horarios').doc(id).delete();
                    }
                    if (v=='toggle') {
                      await FirebaseFirestore.instance.collection('horarios').doc(id).update({'active': !active});
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value:'edit', child: Text('Editar')),
                    PopupMenuItem(value:'toggle', child: Text(active? 'Desactivar' : 'Activar')),
                    const PopupMenuItem(value:'delete', child: Text('Eliminar')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showEditor(BuildContext context, {String? docId, Map<String,dynamic>? initial}) async {
    final usersSnap = await FirebaseFirestore.instance.collection('users').orderBy('nombre').get();
    final users = usersSnap.docs.map((d)=>{'uid': d.id, 'nombre': (d.data()['nombre'] as String?) ?? d.id}).toList();

    final formKey = GlobalKey<FormState>();
    String? selectedUid = initial?['userId'] as String?;
    String? selectedName = initial?['userName'] as String?;
    TimeOfDay start = TimeOfDay(hour:9, minute:0);
    TimeOfDay end = TimeOfDay(hour:18, minute:0);
    List<int> days = (initial?['days'] as List<dynamic>?)?.map((e)=> (e as int)).toList() ?? [];
    bool active = initial?['active'] as bool? ?? true;

    if (initial!=null) {
      final s = initial['startTime'] as String?;
      final e = initial['endTime'] as String?;
      if (s!=null) {
        final p = s.split(':');
        if (p.length==2) start = TimeOfDay(hour:int.parse(p[0]), minute:int.parse(p[1]));
      }
      if (e!=null) {
        final p = e.split(':');
        if (p.length==2) end = TimeOfDay(hour:int.parse(p[0]), minute:int.parse(p[1]));
      }
      selectedUid = initial['userId'] as String? ?? selectedUid;
      selectedName = initial['userName'] as String? ?? selectedName;
    }

    await showDialog<void>(context: context, builder: (ctx){
      return AlertDialog(
        title: Text(docId==null? 'Crear Horario' : 'Editar Horario'),
        content: StatefulBuilder(builder: (ctx2, setState){
          return SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedUid,
                      decoration: const InputDecoration(labelText: 'Trabajador'),
                      items: users.map((u)=>DropdownMenuItem(value: u['uid'] as String, child: Text(u['nombre'] as String))).toList(),
                      validator: (v)=> v==null? 'Selecciona un trabajador' : null,
                      onChanged: (v){
                        setState(()=> selectedUid = v);
                        try {
                          final found = users.firstWhere((x)=> x['uid']==v);
                          selectedName = (found['nombre'] != null) ? found['nombre'].toString() : selectedName;
                        } catch (_) {}
                      },
                    ),
                    const SizedBox(height:8),
                    Row(children: [
                      Expanded(child: ListTile(
                        title: Text('Inicio: ${start.format(ctx2)}'),
                        trailing: const Icon(Icons.edit),
                        onTap: () async {
                          final t = await showTimePicker(context: ctx2, initialTime: start);
                          if (t!=null) setState(()=> start = t);
                        },
                      )),
                      Expanded(child: ListTile(
                        title: Text('Fin: ${end.format(ctx2)}'),
                        trailing: const Icon(Icons.edit),
                        onTap: () async {
                          final t = await showTimePicker(context: ctx2, initialTime: end);
                          if (t!=null) setState(()=> end = t);
                        },
                      )),
                    ]),
                    const SizedBox(height:8),
                    Wrap(spacing:6, children: List.generate(7, (i){
                      final labels = ['L','M','X','J','V','S','D'];
                      final sel = days.contains(i);
                        return ChoiceChip(
                          label: Text(labels[i]),
                          selected: sel,
                          onSelected: (v){
                            setState((){
                              if (v) {
                                if (!days.contains(i)) days.add(i);
                              } else {
                                days.remove(i);
                              }
                            });
                          },
                        );
                    })),
                    const SizedBox(height:8),
                    Row(children: [
                      const Text('Activo'),
                      Switch(value: active, onChanged: (v)=> setState(()=> active=v)),
                    ])
                  ],
                ),
              ),
            ),
          );
        }),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final doc = FirebaseFirestore.instance.collection('horarios').doc(docId);
            final map = {
              'userId': selectedUid,
              'userName': selectedName ?? '',
              'startTime': '${start.hour.toString().padLeft(2,'0')}:${start.minute.toString().padLeft(2,'0')}',
              'endTime': '${end.hour.toString().padLeft(2,'0')}:${end.minute.toString().padLeft(2,'0')}',
              'days': days,
              'active': active,
              'updatedAt': FieldValue.serverTimestamp(),
            };
            if (docId==null) await FirebaseFirestore.instance.collection('horarios').add({...map, 'createdAt': FieldValue.serverTimestamp()});
            else await doc.update(map);
            Navigator.pop(ctx);
          }, child: const Text('Guardar'))
        ],
      );
    });
  }
}
