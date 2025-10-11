
// lib/presentacion/gastos/pagina_lista_compras.dart
import 'package:flutter/material.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/producto.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/servicio_lista_compras.dart';

class PaginaListaCompras extends StatefulWidget {
  const PaginaListaCompras({super.key});

  @override
  State<PaginaListaCompras> createState() => _PaginaListaComprasState();
}

class _PaginaListaComprasState extends State<PaginaListaCompras> {
  final ServicioListaCompras _svc = ServicioListaCompras();
  bool _loading = true;
  List<CompraItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _svc.cargarHoy();
    setState(() {
      _items = _svc.obtenerListaHoy();
      _loading = false;
    });
  }

  Future<void> _toggleComprado(CompraItem it) async {
    await _svc.marcarComprado(it.id, comprado: !it.comprado);
    await _load();
  }

  Future<void> _eliminar(CompraItem it) async {
    await _svc.eliminarItem(it.id);
    await _load();
  }

  Future<void> _limpiarTodo() async {
    await _svc.limpiarHoy();
    await _load();
  }

  void _comprar(CompraItem it) {
    // Reconstruimos un Producto mínimo para el panel de gasto
    final mapProd = {
      'id': it.productoId ?? 'SL-${it.id}',
      'nombre': it.nombre,
      'precio': it.precioEstimado,
      'categoriaId': it.categoriaId ?? '',
      'categoriaNombre': '', // opcional
    };
    final producto = Producto.fromMap(mapProd);

    // Devolvemos al caller datos para arrancar el panel de gasto
    Navigator.of(context).pop({
      'action': 'comprar',
      'shoppingId': it.id,
      'producto': producto,
      'precio': it.precioEstimado,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final comprados = _items.where((e) => e.comprado).length;
    final total = _items.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Compras'),
        actions: [
          IconButton(
            tooltip: 'Limpiar lista del día',
            onPressed: total == 0 ? null : _limpiarTodo,
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Row(
                children: [
                  const Icon(Icons.today_outlined),
                  const SizedBox(width: 8),
                  const Text('Lista del día'),
                  const Spacer(),
                  Text('$comprados / $total comprados',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
              children: [
                if (total == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Tu lista de hoy está vacía.')),
                  )
                else
                  ..._items.map((it) => _ItemTile(
                        item: it,
                        onToggle: () => _toggleComprado(it),
                        onDelete: () => _eliminar(it),
                        onComprar: () => _comprar(it),
                      )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final CompraItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onComprar;

  const _ItemTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
    required this.onComprar,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    final precio = 'S/ ${item.precioEstimado.toStringAsFixed(2)}';
    return ListTile(
      leading: Checkbox(
        value: item.comprado,
        onChanged: (_) => onToggle(),
      ),
      title: Text(
        item.nombre,
        style: style?.copyWith(
          decoration: item.comprado ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(precio),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Comprar ahora',
            onPressed: onComprar,
            icon: const Icon(Icons.shopping_cart_checkout),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}
