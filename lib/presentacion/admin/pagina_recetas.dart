import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/receta.dart';

class PaginaRecetas extends StatefulWidget {
  const PaginaRecetas({super.key});

  @override
  State<PaginaRecetas> createState() => _PaginaRecetasState();
}

class _PaginaRecetasState extends State<PaginaRecetas> {
  final _formKey = GlobalKey<FormState>();
  String _nombreReceta = '';
  List<String> _productosAsociados = [];
  List<InsumoReceta> _insumos = [];
  String? _editId;

  void _abrirFormularioNuevaReceta({String? editId, Receta? receta}) {
    if (receta != null) {
      _nombreReceta = receta.nombre;
      _productosAsociados = List<String>.from(receta.productos);
      _insumos = List<InsumoReceta>.from(receta.insumos);
      _editId = receta.id;
    } else {
      _nombreReceta = '';
      _productosAsociados = [];
      _insumos = [];
      _editId = null;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _fetchProductosEInsumos(),
          builder: (context, snap) {
            final productos =
                snap.data?['productos'] as List<Map<String, String>>? ?? [];
            final insumos = snap.data?['insumos'] as List<String>? ?? [];
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_editId == null ? 'Nueva Receta' : 'Editar Receta',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _nombreReceta,
                        decoration: const InputDecoration(
                            labelText: 'Nombre de la receta'),
                        onChanged: (v) => _nombreReceta = v,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      StatefulBuilder(
                        builder: (context, setLocalState) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Productos asociados',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                ...productos.map((p) => CheckboxListTile(
                                      title: Text(p['nombre'] ?? ''),
                                      value:
                                          _productosAsociados.contains(p['id']),
                                      onChanged: (checked) {
                                        setLocalState(() {
                                          if (checked == true) {
                                            _productosAsociados.add(p['id']!);
                                          } else {
                                            _productosAsociados.remove(p['id']);
                                          }
                                        });
                                      },
                                    ))
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('Insumos de la receta',
                          style: Theme.of(context).textTheme.titleMedium),
                      StatefulBuilder(
                        builder: (context, setLocalState) {
                          return Column(
                            children: [
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _insumos.length,
                                itemBuilder: (ctx, i) {
                                  final insumo = _insumos[i];
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: insumos.contains(insumo.nombre)
                                              ? insumo.nombre
                                              : null,
                                          items: insumos
                                              .map((ii) => DropdownMenuItem(
                                                  value: ii, child: Text(ii)))
                                              .toList(),
                                          decoration: const InputDecoration(
                                              labelText: 'Insumo'),
                                          onChanged: (v) => setLocalState(() {
                                            _insumos[i] = InsumoReceta(
                                                nombre: v ?? '',
                                                cantidad: insumo.cantidad);
                                          }),
                                          validator: (v) =>
                                              v == null || v.trim().isEmpty
                                                  ? 'Obligatorio'
                                                  : null,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 80,
                                        child: TextFormField(
                                          initialValue:
                                              insumo.cantidad.toString(),
                                          decoration: const InputDecoration(
                                              labelText: 'Cantidad'),
                                          keyboardType: TextInputType.number,
                                          onChanged: (v) => setLocalState(() {
                                            _insumos[i] = InsumoReceta(
                                                nombre: insumo.nombre,
                                                cantidad:
                                                    double.tryParse(v) ?? 0);
                                          }),
                                          validator: (v) =>
                                              (double.tryParse(v ?? '') ?? 0) >
                                                      0
                                                  ? null
                                                  : '>',
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () {
                                          setLocalState(
                                              () => _insumos.removeAt(i));
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Agregar insumo'),
                                  onPressed: () {
                                    setLocalState(() => _insumos.add(
                                        InsumoReceta(nombre: '', cantidad: 0)));
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: Text(_editId == null
                            ? 'Guardar receta'
                            : 'Actualizar receta'),
                        onPressed: () async {
                          if ((_formKey.currentState?.validate() ?? false) &&
                              _productosAsociados.isNotEmpty) {
                            final recetaMap = {
                              'nombre': _nombreReceta,
                              'productos': _productosAsociados,
                              'insumos':
                                  _insumos.map((e) => e.toMap()).toList(),
                            };
                            final col = FirebaseFirestore.instance
                                .collection('recetas');
                            if (_editId == null) {
                              await col.add(recetaMap);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Receta guardada')),
                              );
                            } else {
                              await col.doc(_editId).update(recetaMap);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Receta actualizada')),
                              );
                            }
                            setState(() {});
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchProductosEInsumos() async {
    final productosSnap =
        await FirebaseFirestore.instance.collection('productos').get();
    final insumosSnap =
        await FirebaseFirestore.instance.collection('insumos').get();
    final productos = productosSnap.docs
        .map((d) => {
              'id': d.id,
              'nombre': (d.data()['nombre'] ?? '').toString(),
            })
        .where((p) => p['nombre']!.isNotEmpty)
        .toList();
    final insumos = insumosSnap.docs
        .map((d) => (d.data()['nombre'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList();
    return {'productos': productos, 'insumos': insumos};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Recetas'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchProductosEInsumos(),
        builder: (context, snapshot) {
          final productos =
              snapshot.data?['productos'] as List<Map<String, String>>? ?? [];
          final productosMap = {for (var p in productos) p['id']: p['nombre']};
          return StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('recetas').snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No hay recetas registradas.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final receta = Receta.fromDoc(docs[i]);
                  // Mostrar nombres de productos en vez de IDs
                  final nombresProductos = receta.productos
                      .map((id) => productosMap[id] ?? id)
                      .toList();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text(receta.nombre,
                          style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Productos: ${nombresProductos.join(", ")}'),
                          ...receta.insumos.map((ins) =>
                              Text('• ${ins.nombre}: ${ins.cantidad}')),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _abrirFormularioNuevaReceta(
                                editId: receta.id, receta: receta),
                            tooltip: 'Editar',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('recetas')
                                  .doc(receta.id)
                                  .delete();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Receta eliminada')),
                              );
                            },
                            tooltip: 'Eliminar',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormularioNuevaReceta(),
        child: const Icon(Icons.add),
        tooltip: 'Nueva receta',
      ),
    );
  }
}
