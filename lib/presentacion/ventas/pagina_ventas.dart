import 'dart:async';

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

// Nota: la funcionalidad de registrar gasto de insumos por apertura ahora
// se realiza desde el diálogo centralizado en `gasto_apertura_dialog.dart`

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

  // Estado local de salsa: lista de potes con fracción individual
  // Cada pote tiene: id, fracción (0.0-1.0)
  List<Map<String, dynamic>> _salsaPotes = [
    {'id': 1, 'fraccion': 1.0},
    {'id': 2, 'fraccion': 1.0},
    {'id': 3, 'fraccion': 1.0},
  ];
  int _nextPoteId = 4;

  // Listener de Firestore para sincronización en tiempo real
  StreamSubscription<DocumentSnapshot>? _salsaSubscription;

  // Carrito y pendientes
  final List<ItemCarrito> _cart = [];
  final List<PedidoPendiente> _pedidosPendientes = [];
  String? _activeOrderName;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
    _loadSalsaEstado();
  }

  @override
  void dispose() {
    _salsaSubscription?.cancel();
    super.dispose();
  }

  /// Carga el estado de salsa desde Firestore y configura listener en tiempo real
  Future<void> _loadSalsaEstado() async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('configuracion')
          .doc('salsa_de_ajo');

      // Configurar listener en tiempo real
      _salsaSubscription = docRef.snapshots().listen((snapshot) {
        if (!mounted) return;

        if (snapshot.exists) {
          try {
            final data = snapshot.data();
            if (data != null && data['potes'] != null) {
              final List<dynamic> potesData = data['potes'];
              final potes = potesData
                  .map((p) => Map<String, dynamic>.from(p as Map))
                  .toList();
              final maxId = potes.fold<int>(0,
                  (max, p) => (p['id'] as int) > max ? (p['id'] as int) : max);

              setState(() {
                _salsaPotes = potes;
                _nextPoteId = maxId + 1;
              });
            }
          } catch (e) {
            print('Error al parsear datos de salsa: $e');
          }
        } else {
          // Si no existe el documento, crearlo con valores por defecto
          _saveSalsaEstado();
        }
      }, onError: (error) {
        print('Error en listener de salsa: $error');
      });
    } catch (e) {
      print('Error al configurar listener de salsa: $e');
    }
  }

  /// Guarda el estado de salsa en Firestore (visible para todos los dispositivos)
  Future<void> _saveSalsaEstado() async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('configuracion')
          .doc('salsa_de_ajo');
      await docRef.set({
        'potes': _salsaPotes,
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mainScaffoldContext != null) {
        mostrarNotificacionElegante(
          mainScaffoldContext!,
          'Error al guardar estado de salsa: $e',
          esError: true,
          messengerKey: principalMessengerKey,
        );
      }
    }
  }

  Future<void> _showSalsaDialog() async {
    // Copiar estado actual para editar
    final tmpPotes =
        _salsaPotes.map((p) => Map<String, dynamic>.from(p)).toList();
    int tmpNextId = _nextPoteId;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header con gradiente
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.invert_colors_rounded,
                          color: theme.colorScheme.onPrimary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estado de Salsa de ajo',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimary,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Control de potes disponibles',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onPrimary
                                    .withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: Icon(Icons.close_rounded,
                            color: theme.colorScheme.onPrimary),
                        tooltip: 'Cerrar',
                      ),
                    ],
                  ),
                ),
                // Contenido scrollable
                Flexible(
                  child: StatefulBuilder(
                    builder: (ctx2, setStateDialog) => SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Instrucción
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    theme.colorScheme.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cloud_sync_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Sincronizado en tiempo real • Visible desde cualquier dispositivo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.8),
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Lista de potes
                          ...tmpPotes.asMap().entries.map((entry) {
                            final index = entry.key;
                            final pote = entry.value;
                            final poteId = pote['id'] as int;
                            final fraccion =
                                (pote['fraccion'] as num).toDouble();
                            final porcentaje = (fraccion * 100).toInt();

                            // Determinar color según porcentaje
                            Color poteColor;
                            Color borderColor;
                            IconData iconData;
                            String estadoText;

                            if (porcentaje == 0) {
                              poteColor = Colors.red.shade100;
                              borderColor = Colors.red.shade600;
                              iconData = Icons.cancel_rounded;
                              estadoText = 'Vacío';
                            } else if (porcentaje == 100) {
                              poteColor = Colors.green.shade100;
                              borderColor = Colors.green.shade600;
                              iconData = Icons.check_circle_rounded;
                              estadoText = 'Lleno';
                            } else {
                              poteColor = Colors.orange.shade100;
                              borderColor = Colors.orange.shade600;
                              iconData = Icons.pie_chart_rounded;
                              estadoText = '$porcentaje%';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: poteColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: borderColor, width: 2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header del pote
                                  Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: poteColor,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: borderColor, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  borderColor.withOpacity(0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(iconData,
                                            color: borderColor, size: 28),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Pote $poteId',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              estadoText,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: borderColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Botón eliminar (solo si hay más de 1 pote)
                                      if (tmpPotes.length > 1)
                                        IconButton(
                                          onPressed: () {
                                            setStateDialog(() {
                                              tmpPotes.removeAt(index);
                                            });
                                          },
                                          icon: Icon(
                                              Icons.delete_outline_rounded,
                                              color: theme.colorScheme.error),
                                          tooltip: 'Eliminar pote',
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Slider de fracción
                                  SliderTheme(
                                    data: SliderTheme.of(ctx2).copyWith(
                                      activeTrackColor: borderColor,
                                      inactiveTrackColor:
                                          theme.colorScheme.surfaceVariant,
                                      thumbColor: borderColor,
                                      overlayColor:
                                          borderColor.withOpacity(0.2),
                                      trackHeight: 6,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 10),
                                    ),
                                    child: Slider(
                                      value: fraccion,
                                      onChanged: (v) {
                                        setStateDialog(() {
                                          tmpPotes[index]['fraccion'] = v;
                                        });
                                      },
                                      min: 0.0,
                                      max: 1.0,
                                      divisions: 20,
                                    ),
                                  ),
                                  // Marcadores de porcentaje
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('0%',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withOpacity(0.6))),
                                        Text('25%',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withOpacity(0.6))),
                                        Text('50%',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withOpacity(0.6))),
                                        Text('75%',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withOpacity(0.6))),
                                        Text('100%',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withOpacity(0.6))),
                                      ],
                                    ),
                                  ),
                                  // Botones rápidos
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _QuickButton(
                                        label: 'Vacío',
                                        icon: Icons.remove_circle_outline,
                                        color: Colors.red,
                                        onTap: () => setStateDialog(() =>
                                            tmpPotes[index]['fraccion'] = 0.0),
                                      ),
                                      _QuickButton(
                                        label: '1/4',
                                        icon: Icons.pie_chart_outline,
                                        color: Colors.orange,
                                        onTap: () => setStateDialog(() =>
                                            tmpPotes[index]['fraccion'] = 0.25),
                                      ),
                                      _QuickButton(
                                        label: '1/2',
                                        icon: Icons.donut_small,
                                        color: Colors.amber,
                                        onTap: () => setStateDialog(() =>
                                            tmpPotes[index]['fraccion'] = 0.5),
                                      ),
                                      _QuickButton(
                                        label: '3/4',
                                        icon: Icons.pie_chart,
                                        color: Colors.lightGreen,
                                        onTap: () => setStateDialog(() =>
                                            tmpPotes[index]['fraccion'] = 0.75),
                                      ),
                                      _QuickButton(
                                        label: 'Lleno',
                                        icon: Icons.check_circle,
                                        color: Colors.green,
                                        onTap: () => setStateDialog(() =>
                                            tmpPotes[index]['fraccion'] = 1.0),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                          // Botón agregar pote
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setStateDialog(() {
                                  // Recalcular el siguiente ID basado en los potes existentes
                                  final maxId = tmpPotes.fold<int>(
                                      0,
                                      (max, p) => (p['id'] as int) > max
                                          ? (p['id'] as int)
                                          : max);
                                  final nuevoId = maxId + 1;
                                  tmpPotes
                                      .add({'id': nuevoId, 'fraccion': 1.0});
                                  tmpNextId = nuevoId + 1;
                                });
                              },
                              icon:
                                  const Icon(Icons.add_circle_outline_rounded),
                              label: const Text('Agregar otro pote'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(
                                    color: theme.colorScheme.primary, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Resumen
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer
                                  .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.assessment_rounded,
                                  color: theme.colorScheme.secondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total disponible',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.7),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${tmpPotes.fold<double>(0.0, (sum, p) => sum + (p['fraccion'] as num).toDouble()).toStringAsFixed(2)} potes',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Footer con botones
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        label: const Text('Guardar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == true) {
      setState(() {
        _salsaPotes = tmpPotes;
        _nextPoteId = tmpNextId;
      });
      await _saveSalsaEstado();
    }
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
        final theme = Theme.of(ctx);
        return StatefulBuilder(builder: (context, modalSetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (_, controller) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Header con gradiente
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.inventory_2_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pedidos Pendientes',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_pedidosPendientes.length} ${_pedidosPendientes.length == 1 ? 'pedido guardado' : 'pedidos guardados'}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white),
                              tooltip: 'Cerrar',
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Contenido
                    Expanded(
                      child: _pedidosPendientes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.inventory_2_outlined,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No hay pedidos guardados',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Los pedidos guardados aparecerán aquí',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: controller,
                              padding: const EdgeInsets.all(16),
                              itemCount: _pedidosPendientes.length,
                              itemBuilder: (context, index) {
                                final pedido = _pedidosPendientes[index];
                                final itemCount = pedido.items.length;
                                final timeAgo = _formatTimeAgo(pedido.fecha);

                                // Construir la tarjeta como widget reutilizable
                                final card = Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Theme(
                                    data: theme.copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: ExpansionTile(
                                      tilePadding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      childrenPadding: const EdgeInsets.all(0),
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.restaurant_menu_rounded,
                                          color: theme.colorScheme.primary,
                                          size: 24,
                                        ),
                                      ),
                                      title: Text(
                                        pedido.nombre,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.receipt_long_rounded,
                                                  size: 14,
                                                  color: Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$itemCount ${itemCount == 1 ? 'producto' : 'productos'}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(
                                                  Icons.access_time_rounded,
                                                  size: 14,
                                                  color: Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  timeAgo,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color:
                                                        Colors.green.shade200),
                                              ),
                                              child: Text(
                                                'S/ ${pedido.subtotal.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      trailing:
                                          const Icon(Icons.expand_more_rounded),
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            border: Border(
                                              top: BorderSide(
                                                  color: Colors.grey.shade200),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              ..._buildPreviewItems(
                                                  pedido.items),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: FilledButton.icon(
                                                      onPressed: () =>
                                                          _loadPendingOrder(
                                                              pedido),
                                                      icon: const Icon(
                                                          Icons
                                                              .play_arrow_rounded,
                                                          size: 18),
                                                      label: const Text(
                                                          'Reanudar'),
                                                      style: FilledButton
                                                          .styleFrom(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 12),
                                                        backgroundColor: theme
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  OutlinedButton(
                                                    onPressed: () {
                                                      modalSetState(() {
                                                        _pedidosPendientes
                                                            .removeAt(index);
                                                      });
                                                      setState(() {});
                                                    },
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              12),
                                                      side: BorderSide(
                                                          color: Colors
                                                              .red.shade400,
                                                          width: 1.5),
                                                    ),
                                                    child: Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      color:
                                                          Colors.red.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );

                                // Habilitar drag & drop para unir órdenes: presionar largo y arrastrar
                                return DragTarget<PedidoPendiente>(
                                  onWillAccept: (incoming) =>
                                      incoming != null && incoming != pedido,
                                  onAccept: (incoming) {
                                    // Backup del estado anterior para poder deshacer
                                    final prevSnapshot = _pedidosPendientes
                                        .map((p) => PedidoPendiente(
                                              nombre: p.nombre,
                                              items: List<ItemCarrito>.from(
                                                  p.items),
                                              subtotal: p.subtotal,
                                              fecha: p.fecha,
                                            ))
                                        .toList();

                                    modalSetState(() {
                                      final sourceIndex = _pedidosPendientes
                                          .indexWhere((p) => p == incoming);
                                      final targetIndex = index;
                                      if (sourceIndex == -1 ||
                                          sourceIndex == targetIndex) return;

                                      final source = _pedidosPendientes
                                          .elementAt(sourceIndex);
                                      final target = _pedidosPendientes
                                          .elementAt(targetIndex);

                                      // Combinar nombres: "Destino + Origen"
                                      final mergedName =
                                          '${target.nombre} + ${source.nombre}';

                                      final mergedItems = <ItemCarrito>[]
                                        ..addAll(target.items)
                                        ..addAll(source.items);

                                      final mergedSubtotal =
                                          (target.subtotal) + (source.subtotal);

                                      // Reemplazar target con la orden resultante (nombre combinado)
                                      _pedidosPendientes[targetIndex] =
                                          PedidoPendiente(
                                        nombre: mergedName,
                                        items: mergedItems,
                                        subtotal: mergedSubtotal,
                                        fecha: DateTime.now(),
                                      );

                                      // Eliminar la orden source
                                      _pedidosPendientes
                                          .removeWhere((p) => p == source);
                                    });

                                    setState(() {});

                                    // Mostrar Snackbar con opción a deshacer
                                    final messengerContext =
                                        (mainScaffoldContext ?? context);
                                    ScaffoldMessenger.of(messengerContext)
                                        .showSnackBar(SnackBar(
                                      content: Text(
                                          'Órdenes unidas. ${_pedidosPendientes[index].nombre}'),
                                      action: SnackBarAction(
                                        label: 'Deshacer',
                                        onPressed: () {
                                          // Restaurar snapshot anterior
                                          modalSetState(() {
                                            _pedidosPendientes.clear();
                                            _pedidosPendientes
                                                .addAll(prevSnapshot);
                                          });
                                          setState(() {});
                                        },
                                      ),
                                      duration: const Duration(seconds: 5),
                                    ));
                                  },
                                  builder: (context, candidateData, rejected) {
                                    final isReceiving = candidateData.isNotEmpty;
                                    return LongPressDraggable<PedidoPendiente>(
                                      data: pedido,
                                      dragAnchorStrategy:
                                          pointerDragAnchorStrategy,
                                      feedback: Material(
                                        color: Colors.transparent,
                                        child: Opacity(
                                          opacity: 0.98,
                                          child: SizedBox(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width -
                                                64,
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.12),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 6),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.inventory_2_rounded,
                                                    size: 20,
                                                    color: Colors.black87,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      '${pedido.nombre} — ${pedido.items.length} items',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      childWhenDragging:
                                          Opacity(opacity: 0.45, child: card),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        transform: isReceiving
                                            ? (Matrix4.identity()..scale(1.01))
                                            : Matrix4.identity(),
                                        decoration: isReceiving
                                            ? BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: theme.colorScheme.primary
                                                        .withOpacity(0.06),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 6),
                                                  ),
                                                ],
                                              )
                                            : null,
                                        child: card,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        });
      },
    );
  }

  String _formatTimeAgo(DateTime fecha) {
    final now = DateTime.now();
    final diff = now.difference(fecha);

    if (diff.inMinutes < 1) {
      return 'Ahora';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours}h';
    } else {
      return DateFormat('dd/MM h:mm a').format(fecha);
    }
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
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF059669)),
                ),
                child: Text(
                  'x$count',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstItem.producto.nombre,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (firstItem.comentario.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.comment_rounded,
                                size: 12, color: Colors.amber.shade700),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                firstItem.comentario,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber.shade900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Text(
                      firstItem.categoryName,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'S/ ${(firstItem.precioEditable * count).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      } else {
        return Column(
          children: groupItems
              .map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.producto.nombre,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (item.comentario.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.comment_rounded,
                                          size: 12,
                                          color: Colors.amber.shade700),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          item.comentario,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.amber.shade900,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF1E293B).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: const Color(0xFF64748B)),
                              ),
                              child: Text(
                                item.categoryName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'S/ ${item.precioEditable.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
        onConfirmPartial: ({required pagos, required fechaVenta, required itemIds}) => _procesarVentaParcial(
            pagos: pagos, fechaVenta: fechaVenta, cajaActiva: cajaActiva, itemIds: itemIds),
        cajaId: cajaActiva.id,
        onAddItem: _addToCart,
        onUpdateComment: _updateComment,
        onUpdatePrice: _updatePrice,
        onSavePending: _savePending,
        onRemoveSelected: _removeSelectedItems,
      ),
    );
  }

  Future<void> _procesarVentaParcial({
    required Map<String, double> pagos,
    required DateTime fechaVenta,
    required Caja cajaActiva,
    required Set<String> itemIds,
  }) async {
    final totalPagado = pagos.values.fold(0.0, (sum, amount) => sum + amount);

    final ventaItems = _cart
        .where((c) => itemIds.contains(c.uniqueId))
        .map((c) => VentaItem(
              producto: c.producto,
              uniqueId: c.uniqueId,
              precioEditable: c.precioEditable,
              comentario: c.comentario,
            ))
        .toList();

    if (ventaItems.isEmpty) return;

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

      // Descontar Pan Árabe por cada shawarma vendido (solo los items pagados)
      final panArabeVendidos = ventaItems
          .where((item) => item.producto.nombre.toLowerCase().contains('shawarma'))
          .length;
      if (panArabeVendidos > 0) {
        try {
          final insumosQuery = await FirebaseFirestore.instance
              .collection('insumos')
              .where('nombre', isGreaterThanOrEqualTo: 'Pan Árabe')
              .where('nombre', isLessThan: 'Pan Áráz')
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
              break;
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

      // Remove only the paid items from the cart
      setState(() {
        _cart.removeWhere((c) => itemIds.contains(c.uniqueId));
      });

      if (mounted && mainScaffoldContext != null) {
        mostrarNotificacionElegante(
          mainScaffoldContext!,
          "Venta parcial registrada en la caja",
          messengerKey: principalMessengerKey,
        );
      }
    } catch (e) {
      if (mounted && mainScaffoldContext != null) {
        mostrarNotificacionElegante(
          mainScaffoldContext!,
          "Error al registrar la venta parcial: $e",
          esError: true,
          messengerKey: principalMessengerKey,
        );
      }
    }
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

  // ===================== GASTO INSUMOS APERTURA =====================
  // Nota: la UI para registrar el gasto de insumos por apertura ahora está
  // centralizada en `lib/presentacion/caja/gasto_apertura_dialog.dart`. Se
  // debe abrir desde la pantalla de Caja (cierre/apertura), no desde Ventas.

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
          // (Botón de Gasto de Insumos removido del AppBar)
          // 🧴 Estado salsa de ajo (mostramos en color si hay potes disponibles)
          IconButton(
            icon: Icon(Icons.invert_colors,
                color: _salsaPotes
                        .any((p) => (p['fraccion'] as num).toDouble() > 0)
                    ? Colors.orange
                    : Colors.grey),
            tooltip: 'Estado Salsa de ajo',
            onPressed: _showSalsaDialog,
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

/// Widget auxiliar para botones rápidos de fracción
class _QuickButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
