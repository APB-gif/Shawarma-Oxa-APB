import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:shawarma_pos_nuevo/datos/modelos/caja.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/categoria.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/producto.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/venta.dart';

import 'package:shawarma_pos_nuevo/datos/servicios/caja_service.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/categoria_service.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/producto_service.dart';
// import eliminado: almacen_service.dart no se usa en esta pantalla

import 'package:shawarma_pos_nuevo/presentacion/ventas/item_carrito.dart';
import 'package:shawarma_pos_nuevo/presentacion/ventas/panel_carrito.dart';

import 'package:shawarma_pos_nuevo/presentacion/widgets/notificaciones.dart';
import 'package:shawarma_pos_nuevo/presentacion/pagina_principal.dart';

// 👉 Navegar a la pantalla de Caja
import 'package:shawarma_pos_nuevo/presentacion/caja/pagina_caja.dart';
import 'package:shawarma_pos_nuevo/presentacion/comunes/net_status_strip.dart';

/// Estructura para “pedidos pendientes”
class PedidoPendiente {
  final String nombre;
  final List<ItemCarrito> items;
  final double subtotal;
  final DateTime fecha;

  PedidoPendiente({
    required this.nombre,
    required this.items,
    required this.subtotal,
    required this.fecha,
  });
}

class PaginaVentas extends StatefulWidget {
  const PaginaVentas({super.key});

  @override
  State<PaginaVentas> createState() => _PaginaVentasState();
}

class _PaginaVentasState extends State<PaginaVentas> {
  final _productoService = ProductoService();
  final _categoriaService = CategoriaService();

  // Cache en memoria
  List<Categoria> _todasLasCategorias = [];
  List<Producto> _todosLosProductos = [];

  bool _isLoading = true;
  Categoria? _selectedCategory;

  // Carrito y pendientes
  final List<ItemCarrito> _cart = [];
  final List<PedidoPendiente> _pedidosPendientes = [];
  String? _activeOrderName;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  /// Carga categorías y productos una sola vez, y filtra SOLO ventas.
  Future<void> _cargarDatosIniciales() async {
    try {
      final results = await Future.wait([
        _categoriaService.getCategorias(),
        _productoService.getProductos(),
      ]);

      final categoriasTodas = (results[0] as List<Categoria>);
      final productosTodos = (results[1] as List<Producto>);

      final categoriasVenta = categoriasTodas
          .where((c) => (c.tipo).toLowerCase() == 'venta')
          .toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));

      final productosVenta = productosTodos
          .where((p) => (p.tipo).toLowerCase() == 'venta')
          .toList();

      if (!mounted) return;
      setState(() {
        _todasLasCategorias = categoriasVenta;
        _todosLosProductos = productosVenta;
        _selectedCategory =
            _todasLasCategorias.isNotEmpty ? _todasLasCategorias.first : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mainScaffoldContext != null) {
        mostrarNotificacionElegante(
            mainScaffoldContext!, "Error al cargar datos: $e",
            esError: true, messengerKey: principalMessengerKey);
      }
    }
  }

  // ===================== CARRITO / PENDIENTES =====================

  double get _cartTotal =>
      _cart.fold(0.0, (sum, item) => sum + item.precioEditable);
  int get _cartCount => _cart.length;

  void _addToCart(Producto p) {
    // Guard defensivo: por si se llama desde otro lado sin caja.
    final cajaActiva = context.read<CajaService>().cajaActiva;
    if (cajaActiva == null) {
      if (mainScaffoldContext != null) {
        mostrarNotificacionElegante(
            mainScaffoldContext!, 'Abre una caja para comenzar a vender.',
            messengerKey: principalMessengerKey);
      }
      return;
    }
    setState(() {
      _cart.add(ItemCarrito(
        producto: p,
        uniqueId: '${p.id}-${DateTime.now().millisecondsSinceEpoch}',
        categoryName: p.categoriaNombre,
      ));
    });
  }

  void _removeOneByProductId(String productId) {
    if (_cart.isEmpty) return;
    final idx = _cart.lastIndexWhere((e) => e.producto.id == productId);
    if (idx != -1) {
      setState(() {
        _cart.removeAt(idx);
      });
    }
  }

  void _removeItem(String uniqueId) {
    setState(() {
      _cart.removeWhere((item) => item.uniqueId == uniqueId);
    });
  }

  void _removeSelectedItems(Set<String> ids) {
    setState(() {
      _cart.removeWhere((it) => ids.contains(it.uniqueId));
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _activeOrderName = null;
    });
  }

  Future<void> _confirmAndClearCart() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar Carrito'),
        content: const Text(
            '¿Estás seguro de que quieres eliminar todos los productos del pedido actual?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Sí, Vaciar'),
          ),
        ],
      ),
    );

    if (confirmed == true) _clearCart();
  }

  void _updateComment(String uniqueId, String comment) {
    setState(() {
      final i = _cart.indexWhere((x) => x.uniqueId == uniqueId);
      if (i != -1) _cart[i].comentario = comment;
    });
  }

  void _updatePrice(String uniqueId, double newPrice) {
    setState(() {
      final i = _cart.indexWhere((x) => x.uniqueId == uniqueId);
      if (i != -1) _cart[i].precioEditable = newPrice;
    });
  }

  Future<bool> _savePending({
    required List<ItemCarrito> items,
    required double subtotal,
  }) async {
    String? nombre;

    Future<String?> _askForName() async {
      return showDialog<String>(
        context: context,
        builder: (ctx) {
          final ctl = TextEditingController();
          return AlertDialog(
            title: const Text('Guardar Pedido Pendiente'),
            content: TextField(
              controller: ctl,
              decoration:
                  const InputDecoration(labelText: 'Nombre (ej: Mesa 5)'),
              autofocus: true,
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () {
                    if (ctl.text.trim().isNotEmpty) {
                      Navigator.pop(ctx, ctl.text.trim());
                    }
                  },
                  child: const Text('Guardar')),
            ],
          );
        },
      );
    }

    if (_activeOrderName != null) {
      final result = await showDialog<int>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Guardar Cambios'),
              content: Text(
                  'Este pedido ya existe como "$_activeOrderName". ¿Qué deseas hacer?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, 2),
                    child: const Text('Cambiar Nombre')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, 1),
                    child: const Text('Guardar Igual')),
              ],
            ),
          ) ??
          0;

      if (result == 1) {
        nombre = _activeOrderName;
      } else if (result == 2) {
        nombre = await _askForName();
      } else {
        return false;
      }
    } else {
      nombre = await _askForName();
    }

    if (nombre == null || nombre.trim().isEmpty) return false;

    final nuevo = PedidoPendiente(
      nombre: nombre,
      items: List.from(items),
      subtotal: subtotal,
      fecha: DateTime.now(),
    );

    setState(() {
      _pedidosPendientes.removeWhere((p) => p.nombre == nombre);
      _pedidosPendientes.add(nuevo);
    });

    _clearCart();
    return true;
  }

  void _showPendingOrders() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, modalSetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (_, controller) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Pedidos Pendientes',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  Expanded(
                    child: _pedidosPendientes.isEmpty
                        ? const Center(child: Text('No hay pedidos guardados.'))
                        : ListView.builder(
                            controller: controller,
                            itemCount: _pedidosPendientes.length,
                            itemBuilder: (context, index) {
                              final pedido = _pedidosPendientes[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 4.0),
                                clipBehavior: Clip.antiAlias,
                                child: ExpansionTile(
                                  title: Text(pedido.nombre,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  subtitle: Text(
                                    'S/ ${pedido.subtotal.toStringAsFixed(2)} - ${DateFormat('h:mm a').format(pedido.fecha)}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                          onPressed: () =>
                                              _loadPendingOrder(pedido),
                                          child: const Text('Reanudar')),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.redAccent),
                                        onPressed: () {
                                          modalSetState(() {
                                            _pedidosPendientes.removeAt(index);
                                          });
                                          setState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                  children: _buildPreviewItems(pedido.items),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        });
      },
    );
  }

  List<Widget> _buildPreviewItems(List<ItemCarrito> items) {
    final grouped = groupBy(items, (ItemCarrito item) => item.producto.id);
    return grouped.entries.map((entry) {
      final groupItems = entry.value;
      final firstItem = groupItems.first;
      final count = groupItems.length;

      final isUniform = groupItems.every((item) =>
          item.precioEditable == firstItem.precioEditable &&
          item.comentario == firstItem.comentario);

      if (count > 1 && isUniform) {
        return ListTile(
          contentPadding: const EdgeInsets.only(left: 24, right: 16),
          dense: true,
          title: Text('${firstItem.producto.nombre} (x$count)'),
          subtitle: firstItem.comentario.isNotEmpty
              ? Text(firstItem.comentario)
              : null,
          trailing: Text(
              'S/ ${(firstItem.precioEditable * count).toStringAsFixed(2)}'),
        );
      } else {
        return Column(
          children: groupItems
              .map((item) => ListTile(
                    contentPadding: const EdgeInsets.only(left: 24, right: 16),
                    dense: true,
                    title: Text(item.producto.nombre),
                    subtitle: item.comentario.isNotEmpty
                        ? Text(item.comentario)
                        : null,
                    trailing:
                        Text('S/ ${item.precioEditable.toStringAsFixed(2)}'),
                  ))
              .toList(),
        );
      }
    }).toList();
  }

  Future<void> _loadPendingOrder(PedidoPendiente pedido) async {
    bool canLoad = true;
    if (_cart.isNotEmpty) {
      canLoad = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cargar Pedido'),
              content: const Text(
                  'Tienes un pedido en curso. ¿Deseas reemplazarlo con este pedido pendiente?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('No')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sí, reemplazar')),
              ],
            ),
          ) ??
          false;
    }
    if (!canLoad || !mounted) return;

    final cajaActiva = context.read<CajaService>().cajaActiva;
    setState(() {
      _cart.clear();
      _cart.addAll(pedido.items);
      _activeOrderName = pedido.nombre;
      _pedidosPendientes.remove(pedido);
    });

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(); // cerrar sheet
    }

    if (cajaActiva != null) {
      _openCart(cajaActiva);
    }
  }

  void _openCart(Caja cajaActiva) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => PanelCarrito(
        items: _cart,
        orderName: _activeOrderName,
        onRemoveItem: _removeItem,
        onClear: _clearCart,
        onConfirm: ({required pagos, required fechaVenta}) => _procesarVenta(
            pagos: pagos, fechaVenta: fechaVenta, cajaActiva: cajaActiva),
        cajaId: cajaActiva.id,
        onAddItem: _addToCart,
        onUpdateComment: _updateComment,
        onUpdatePrice: _updatePrice,
        onSavePending: _savePending,
        onRemoveSelected: _removeSelectedItems,
      ),
    );
  }

  Future<void> _procesarVenta({
    required Map<String, double> pagos,
    required DateTime fechaVenta,
    required Caja cajaActiva,
  }) async {
    final totalPagado = pagos.values.fold(0.0, (sum, amount) => sum + amount);

    final ventaItems = _cart
        .map((c) => VentaItem(
              producto: c.producto,
              uniqueId: c.uniqueId,
              precioEditable: c.precioEditable,
              comentario: c.comentario,
            ))
        .toList();

    final nuevaVenta = Venta(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      cajaId: cajaActiva.id,
      fecha: fechaVenta,
      items: ventaItems,
      total: totalPagado,
      pagos: pagos,
      usuarioId: cajaActiva.usuarioAperturaId,
      usuarioNombre: cajaActiva.usuarioAperturaNombre,
    );

    try {
      final cajaService = Provider.of<CajaService>(context, listen: false);
      await cajaService.agregarVentaLocal(nuevaVenta);

      // Ya no se descuenta insumos aquí, solo al cerrar caja

      // Descontar Pan Árabe por cada shawarma vendido
      final panArabeVendidos = _cart
          .where(
              (item) => item.producto.nombre.toLowerCase().contains('shawarma'))
          .length;
      if (panArabeVendidos > 0) {
        try {
          final insumosQuery = await FirebaseFirestore.instance
              .collection('insumos')
              .where('nombre', isGreaterThanOrEqualTo: 'Pan Árabe')
              .where('nombre',
                  isLessThan: 'Pan Áráz') // Para filtrar solo los Pan Árabe
              .get();
          bool descontado = false;
          for (final doc in insumosQuery.docs) {
            final nombre = (doc.data()['nombre'] ?? '').toString();
            if (nombre.startsWith('Pan Árabe')) {
              final stockActual =
                  (doc.data()['stockActual'] ?? doc.data()['stockTotal'] ?? 0)
                      .toDouble();
              final nuevoStock = stockActual - panArabeVendidos;
              await doc.reference.update({'stockActual': nuevoStock});
              descontado = true;
              break; // Solo descuenta el primero que encuentre
            }
          }
          if (!descontado) {
            if (mainScaffoldContext != null) {
              mostrarNotificacionElegante(
                mainScaffoldContext!,
                "No se encontró el insumo 'Pan Árabe' para descontar.",
                esError: true,
                messengerKey: principalMessengerKey,
              );
            }
          }
        } catch (e) {
          if (mainScaffoldContext != null) {
            mostrarNotificacionElegante(
              mainScaffoldContext!,
              "Error al descontar Pan Árabe: $e",
              esError: true,
              messengerKey: principalMessengerKey,
            );
          }
        }
      }

      _clearCart();
      if (mounted && mainScaffoldContext != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        mostrarNotificacionElegante(
          mainScaffoldContext!,
          "Venta registrada en la caja y almacén actualizado",
          messengerKey: principalMessengerKey,
        );
      }
    } catch (e) {
      if (mounted && mainScaffoldContext != null) {
        mostrarNotificacionElegante(
          mainScaffoldContext!,
          "Error al registrar la venta: $e",
          esError: true,
          messengerKey: principalMessengerKey,
        );
      }
    }
  }

  // ===================== AUX: DESCARTAR CAJA LOCAL =====================

  Future<void> _confirmDiscardCajaLocal() async {
    final caja = context.read<CajaService>().cajaActiva;
    if (caja == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar caja local'),
        content: Text(
          'Se eliminará la caja local actual (ID ${caja.id}) con sus datos temporales '
          'no sincronizados. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Sí, descartar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await context.read<CajaService>().descartarCajaLocal();
      if (mounted && mainScaffoldContext != null) {
        mostrarNotificacionElegante(
            mainScaffoldContext!, 'Caja local descartada.',
            messengerKey: principalMessengerKey);
        setState(() {}); // refrescar vista
      }
    }
  }

  // ===================== ORDENAMIENTO DE PRODUCTOS =====================

  int _shawarmaRank(String name) {
    final n = name.trim().toLowerCase();
    if (n.contains('junior')) return 0;
    if (n.contains('regular')) return 1;
    if (n.contains('extra')) return 2;
    return 99;
  }

  bool _esCategoriaShawarma(Categoria c) {
    final id = c.id.toLowerCase();
    final nombre = c.nombre.toLowerCase();
    return id == 'pollo' ||
        id == 'carne' ||
        id == 'mixto' ||
        id == 'oxa' ||
        id == 'veg' ||
        nombre.contains('shawarma');
  }

  List<Producto> _ordenarProductosParaCategoria(
      List<Producto> list, Categoria cat) {
    final copia = List<Producto>.from(list);
    if (_esCategoriaShawarma(cat)) {
      copia.sort((a, b) {
        final ra = _shawarmaRank(a.nombre);
        final rb = _shawarmaRank(b.nombre);
        if (ra != rb) return ra.compareTo(rb);
        return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });
    } else {
      copia.sort(
          (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    }
    return copia;
  }

  // ===================== WIDGETS =====================

  @override
  Widget build(BuildContext context) {
    final cajaActiva = context.watch<CajaService>().cajaActiva;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Cantidades en el carrito (para pintar badges)
    final qtyById = <String, int>{};
    for (final item in _cart) {
      qtyById.update(item.producto.id, (v) => v + 1, ifAbsent: () => 1);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Ventas',
            style: GoogleFonts.cinzelDecorative(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // 🔒 Ir a la pantalla de Caja
          IconButton(
            icon: const Icon(Icons.lock_outline_rounded),
            tooltip: 'Caja',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaginaCaja()),
              );
            },
          ),
          // 🗑️ Descartar caja local (solo si hay una abierta)
          if (cajaActiva != null)
            IconButton(
              icon: const Icon(Icons.delete_forever_outlined),
              tooltip: 'Descartar caja local',
              onPressed: _confirmDiscardCajaLocal,
            ),
          if (_pedidosPendientes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Badge(
                label: Text(_pedidosPendientes.length.toString()),
                child: IconButton(
                  icon: const Icon(Icons.inventory_2_outlined),
                  tooltip: 'Pedidos Pendientes',
                  onPressed: _showPendingOrders,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const NetStatusStrip(
            syncCaja:
                false, // 🔄 sincroniza caja/ventas pendientes al reconectar/loguear
            syncGastos: false, // en Ventas no hace falta sincronizar gastos
          ),
          Expanded(
            child: (context.watch<CajaService>().cajaActiva == null)
                ? _buildCajaCerradaView()
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategoryRail(),
                      Expanded(
                        child: _buildProductosGrid(qtyById: qtyById),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: cajaActiva == null || _cart.isEmpty
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: _confirmAndClearCart,
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  heroTag: 'vaciarCarrito',
                  tooltip: 'Vaciar Carrito',
                  child: const Icon(Icons.delete_forever_rounded),
                ),
                const SizedBox(width: 16),
                FloatingActionButton.extended(
                  onPressed: () => _openCart(cajaActiva),
                  heroTag: 'abrirCarrito',
                  label:
                      Text('$_cartCount • S/ ${_cartTotal.toStringAsFixed(2)}'),
                  icon: const Icon(Icons.shopping_basket_outlined),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryRail() {
    return Container(
      width: 104,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.30),
      child: ListView.builder(
        itemCount: _todasLasCategorias.length,
        itemBuilder: (context, index) {
          final categoria = _todasLasCategorias[index];
          final bool isSelected = _selectedCategory?.id == categoria.id;
          return Material(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                : Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _selectedCategory = categoria),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12.0, horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 40,
                      width: 40,
                      child:
                          _CategoriaIconVentas(path: categoria.iconAssetPath),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      categoria.nombre,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductosGrid({required Map<String, int> qtyById}) {
    if (_selectedCategory == null) {
      return const Center(child: Text('Seleccione una categoría'));
    }

    final base = _todosLosProductos
        .where((p) => p.categoriaId == _selectedCategory!.id)
        .toList();
    final productosOrdenados =
        _ordenarProductosParaCategoria(base, _selectedCategory!);

    final fallbackImage =
        _selectedCategory?.iconAssetPath ?? 'assets/icons/default.svg';

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        int cols = 4;
        if (w < 380) {
          cols = 2;
        } else if (w < 600) {
          cols = 3;
        } else if (w < 900) {
          cols = 4;
        } else if (w < 1200) {
          cols = 5;
        } else {
          cols = 6;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.92,
          ),
          itemCount: productosOrdenados.length,
          itemBuilder: (context, i) {
            final p = productosOrdenados[i];
            final qty = qtyById[p.id] ?? 0;
            return _ProductoTileVentas(
              producto: p,
              currentQty: qty,
              fallbackImagePath: fallbackImage,
              onAdd: () => _addToCart(p),
              onRemove: () => _removeOneByProductId(p.id),
            );
          },
        );
      },
    );
  }

  Widget _buildCajaCerradaView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("Ventas deshabilitadas",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Para vender necesitas abrir una caja.",
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            // 👉 Ir a la pantalla de Caja para abrirla allí
            FilledButton.icon(
              icon: const Icon(Icons.point_of_sale_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaginaCaja()),
                );
              },
              label: const Text('Abrir caja'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== Tarjeta de producto para VENTAS (tap = +, badge xN arriba, botón – arriba der.) =====
class _ProductoTileVentas extends StatelessWidget {
  final Producto producto;
  final int currentQty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final String fallbackImagePath;

  const _ProductoTileVentas({
    required this.producto,
    required this.currentQty,
    required this.onAdd,
    required this.onRemove,
    required this.fallbackImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmall = MediaQuery.of(context).size.width < 380;
    final minusSize = isSmall ? 32.0 : 36.0;

    return Material(
      color: theme.cardColor,
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: currentQty > 0
                  ? theme.colorScheme.primary
                  : Colors.grey.shade300,
              width: currentQty > 0 ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          color:
                              theme.colorScheme.surfaceVariant.withOpacity(.25),
                          alignment: Alignment.center,
                          child: ProductoImageVentas(
                            path: (producto.imagenUrl ?? '').trim(),
                            fallback: fallbackImagePath,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      producto.nombre,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'S/ ${producto.precio.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (currentQty > 0)
                  Positioned(
                    top: 6,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'x$currentQty',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (currentQty > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Material(
                      color: theme.colorScheme.primary,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onRemove,
                        child: SizedBox(
                          width: minusSize,
                          height: minusSize,
                          child: Icon(Icons.remove,
                              size: isSmall ? 18 : 20,
                              color: theme.colorScheme.onPrimary),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Imagen de producto (cache http) + soporte asset/svg/gs://
class ProductoImageVentas extends StatelessWidget {
  final String? path;
  final String? fallback;
  const ProductoImageVentas({super.key, this.path, this.fallback});

  static bool _isSvg(String s) => s.toLowerCase().endsWith('.svg');
  static bool _isHttp(String s) =>
      s.startsWith('http://') || s.startsWith('https://');
  static bool _isGs(String s) => s.startsWith('gs://');

  Future<String> _gsToUrl(String gs) async {
    final ref = FirebaseStorage.instance.refFromURL(gs);
    return ref.getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    String src = (path ?? '').trim();
    if (src.isEmpty) {
      final f = (fallback ?? '').trim();
      if (f.isNotEmpty) {
        if (_isHttp(f)) {
          if (_isSvg(f)) return SvgPicture.network(f, fit: BoxFit.contain);
          return CachedNetworkImage(imageUrl: f, fit: BoxFit.contain);
        }
        if (_isSvg(f)) return SvgPicture.asset(f, fit: BoxFit.contain);
        return Image.asset(f, fit: BoxFit.contain);
      }
      return const Icon(Icons.image_outlined, size: 40);
    }

    if (!_isHttp(src) && !_isGs(src)) {
      if (_isSvg(src)) return SvgPicture.asset(src, fit: BoxFit.contain);
      return Image.asset(src, fit: BoxFit.contain);
    }

    if (_isHttp(src)) {
      if (_isSvg(src)) return SvgPicture.network(src, fit: BoxFit.contain);
      return CachedNetworkImage(
        imageUrl: src,
        fit: BoxFit.contain,
        placeholder: (_, __) => const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      );
    }

    return FutureBuilder<String>(
      future: _gsToUrl(src),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        final url = snap.data!;
        if (_isSvg(url)) return SvgPicture.network(url, fit: BoxFit.contain);
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, __) => const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
          errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
        );
      },
    );
  }
}

/// Icono de categoría: asset / http(s) / gs:// con SVG y cache
class _CategoriaIconVentas extends StatelessWidget {
  final String path;
  const _CategoriaIconVentas({required this.path});

  static bool _isSvg(String s) => s.toLowerCase().endsWith('.svg');
  static bool _isHttp(String s) =>
      s.startsWith('http://') || s.startsWith('https://');
  static bool _isGs(String s) => s.startsWith('gs://');

  Future<String> _gsToUrl(String gs) async {
    final ref = FirebaseStorage.instance.refFromURL(gs);
    return ref.getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    final src = path.trim();
    if (src.isEmpty) {
      return const Icon(Icons.category_outlined, size: 22);
    }

    // Asset local
    if (!_isHttp(src) && !_isGs(src)) {
      if (_isSvg(src)) return SvgPicture.asset(src, fit: BoxFit.contain);
      return Image.asset(src, fit: BoxFit.contain);
    }

    // HTTP(S)
    if (_isHttp(src)) {
      if (_isSvg(src)) return SvgPicture.network(src, fit: BoxFit.contain);
      return CachedNetworkImage(
        imageUrl: src,
        fit: BoxFit.contain,
        placeholder: (_, __) => const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) =>
            const Icon(Icons.image_not_supported_outlined),
      );
    }

    // gs://
    return FutureBuilder<String>(
      future: _gsToUrl(src),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        final url = snap.data!;
        if (_isSvg(url)) return SvgPicture.network(url, fit: BoxFit.contain);
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, __) => const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          errorWidget: (_, __, ___) =>
              const Icon(Icons.image_not_supported_outlined),
        );
      },
    );
  }
}
