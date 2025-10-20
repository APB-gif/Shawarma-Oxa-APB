// lib/presentacion/ventas/panel_carrito.dart

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/producto.dart';
import 'package:shawarma_pos_nuevo/presentacion/ventas/item_carrito.dart';
import 'package:shawarma_pos_nuevo/presentacion/ventas/panel_pago.dart';
import 'package:shawarma_pos_nuevo/presentacion/ventas/pagina_ventas.dart';

/// Widget para mostrar ícono de categoría (SVG o imagen)
class _CategoriaIcon extends StatelessWidget {
  final String? categoriaId;
  final String categoriaNombre;

  const _CategoriaIcon({
    required this.categoriaId,
    required this.categoriaNombre,
  });

  static bool _isSvg(String s) => s.toLowerCase().endsWith('.svg');
  static bool _isHttp(String s) =>
      s.startsWith('http://') || s.startsWith('https://');
  static bool _isGs(String s) => s.startsWith('gs://');

  Future<String> _gsToUrl(String gs) async {
    final ref = FirebaseStorage.instance.refFromURL(gs);
    return ref.getDownloadURL();
  }

  String _getCategoriaIconPath(String? categoriaId, String categoriaNombre) {
    // Mapeo basado en nombre de categoría usando archivos existentes
    final nombreLower = categoriaNombre.toLowerCase();

    // Shawarmas
    if (nombreLower.contains('shawarma') && nombreLower.contains('pollo')) {
      return 'assets/icons/catPollo.svg';
    } else if (nombreLower.contains('shawarma') &&
        nombreLower.contains('carne')) {
      return 'assets/icons/catCarne.svg';
    } else if (nombreLower.contains('shawarma') &&
        nombreLower.contains('mixto')) {
      return 'assets/icons/catMixto.svg';
    } else if (nombreLower.contains('shawarma') &&
        nombreLower.contains('vegetariano')) {
      return 'assets/icons/catVeg.svg';
    } else if (nombreLower.contains('shawarma') &&
        nombreLower.contains('oxa')) {
      return 'assets/icons/catShawOxa.svg';
    } else if (nombreLower.contains('shawarma')) {
      return 'assets/icons/catPollo.svg'; // Fallback para shawarmas genéricos
    }

    // Bebidas
    else if (nombreLower.contains('bebida') ||
        nombreLower.contains('gaseosa')) {
      return 'assets/icons/Gaseosas.svg';
    } else if (nombreLower.contains('infusion') ||
        nombreLower.contains('té') ||
        nombreLower.contains('cafe')) {
      return 'assets/icons/Infusiones.svg';
    }

    // Carnes y embutidos
    else if (nombreLower.contains('carne') ||
        nombreLower.contains('embutido')) {
      return 'assets/icons/CarnesEmbutidos.svg';
    }

    // Fallback genérico
    return 'assets/icons/default.svg';
  }

  @override
  Widget build(BuildContext context) {
    final iconPath = _getCategoriaIconPath(categoriaId, categoriaNombre);

    if (iconPath.isEmpty) {
      return const Icon(Icons.restaurant_menu, size: 18, color: Colors.white);
    }

    // Asset local
    if (!_isHttp(iconPath) && !_isGs(iconPath)) {
      if (_isSvg(iconPath)) {
        return SvgPicture.asset(
          iconPath,
          width: 18,
          height: 18,
          fit: BoxFit.contain,
        );
      }
      return Image.asset(
        iconPath,
        width: 18,
        height: 18,
        fit: BoxFit.contain,
      );
    }

    // HTTP(S)
    if (_isHttp(iconPath)) {
      if (_isSvg(iconPath)) {
        return SvgPicture.network(
          iconPath,
          width: 18,
          height: 18,
          fit: BoxFit.contain,
        );
      }
      return CachedNetworkImage(
        imageUrl: iconPath,
        width: 18,
        height: 18,
        fit: BoxFit.contain,
        placeholder: (_, __) => const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 1),
        ),
        errorWidget: (_, __, ___) =>
            const Icon(Icons.restaurant_menu, size: 18, color: Colors.white),
      );
    }

    // gs:// (Firebase Storage)
    return FutureBuilder<String>(
      future: _gsToUrl(iconPath),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 1),
          );
        }
        final url = snap.data!;
        if (_isSvg(url)) {
          return SvgPicture.network(
            url,
            width: 18,
            height: 18,
            fit: BoxFit.contain,
          );
        }
        return CachedNetworkImage(
          imageUrl: url,
          width: 18,
          height: 18,
          fit: BoxFit.contain,
          placeholder: (_, __) => const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 1),
          ),
          errorWidget: (_, __, ___) =>
              const Icon(Icons.restaurant_menu, size: 18, color: Colors.white),
        );
      },
    );
  }
}

/// Widget auxiliar que muestra la imagen del producto si existe (asset/http/gs),
/// y si no existe muestra el ícono de la categoría como fallback.
class _ProductoImage extends StatelessWidget {
  final Producto producto;
  final double size;

  const _ProductoImage({required this.producto, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final src = (producto.imagenUrl ?? '').trim();
    if (src.isNotEmpty) {
      return SizedBox(
          width: size, height: size, child: ProductoImageVentas(path: src));
    }

    // Si no hay imagen en el objeto producto, intentar recuperar la URL desde Firestore
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      future: FirebaseFirestore.instance
          .collection('productos')
          .doc(producto.id)
          .get()
          .then((doc) => doc.exists ? doc : null)
          .catchError((_) => null),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
              width: size,
              height: size,
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 1)));
        }
        final doc = snap.data;
        final fetched =
            (doc != null) ? (doc['imagenUrl']?.toString() ?? '').trim() : '';
        if (fetched.isNotEmpty) {
          return SizedBox(
              width: size,
              height: size,
              child: ProductoImageVentas(path: fetched));
        }
        // fallback al ícono de categoría
        return _CategoriaIcon(
          categoriaId: producto.categoriaId,
          categoriaNombre: producto.categoriaNombre,
        );
      },
    );
  }
}

// Acciones del item en el menú compacto
class PanelCarrito extends StatefulWidget {
  final String cajaId;
  final List<ItemCarrito> items;
  final String? orderName;
  final void Function(Producto producto) onAddItem;
  final void Function(String uniqueId) onRemoveItem;
  final void Function(String uniqueId, String comment) onUpdateComment;
  final void Function(String uniqueId, double newPrice) onUpdatePrice;
  final VoidCallback onClear;
  // =======================================================================
  // MODIFICADO: La firma de onSavePending cambia para devolver un booleano
  // =======================================================================
  final Future<bool> Function({
    required List<ItemCarrito> items,
    required double subtotal,
  }) onSavePending;

  final Future<void> Function({
    required Map<String, double> pagos,
    required DateTime fechaVenta,
  }) onConfirm;

  final void Function(Set<String> uniqueIds) onRemoveSelected;

  const PanelCarrito({
    super.key,
    required this.cajaId,
    required this.items,
    this.orderName,
    required this.onClear,
    required this.onSavePending,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onUpdateComment,
    required this.onUpdatePrice,
    required this.onConfirm,
    required this.onRemoveSelected,
  });

  @override
  State<PanelCarrito> createState() => _PanelCarritoState();
}

class _PanelCarritoState extends State<PanelCarrito> {
  final Set<String> _selectedItems = {};
  ScrollController? _sheetController;
  double _discountAmount = 0;
  String? _discountLabel;
  // Split bills state
  bool _splitModeActive = false;
  int _splitCount = 0;
  // map item.uniqueId -> cuentaIndex (1.._splitCount)
  final Map<String, int> _itemToSplit = {};

  double get _currentSubtotal =>
      widget.items.fold(0.0, (sum, item) => sum + item.precioEditable);

  double get _finalTotal =>
      (_currentSubtotal - _discountAmount).clamp(0.0, double.infinity);

  Future<void> _showComentarioDialog(ItemCarrito item) async {
    final comentarioController = TextEditingController(text: item.comentario);
    final nuevoComentario = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.comment, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Comentario para\n${item.producto.nombre}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: comentarioController,
            decoration: InputDecoration(
              labelText: 'Escribe tu comentario',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () => comentarioController.clear(),
              ),
            ),
            autofocus: true,
            maxLines: 3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, comentarioController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child:
                  const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );

    if (nuevoComentario != null && mounted) {
      widget.onUpdateComment(item.uniqueId, nuevoComentario);
      setState(() {});
    }
  }

  Future<void> _showEditPriceDialog(ItemCarrito item) async {
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => _EditPriceDialog(
        initialPrice: item.precioEditable,
        productName: item.producto.nombre,
        originalPrice: item.producto.precio,
      ),
    );

    if (result != null && mounted) {
      // Usamos un post-frame callback para evitar conflictos de estado
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onUpdatePrice(item.uniqueId, result);
          setState(() {});
        }
      });
    }
  }

  // =======================================================================
  // MODIFICADO: Ahora el panel se cierra a sí mismo de forma segura
  // =======================================================================
  Future<void> _showClearConfirmationDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.delete_outline,
                  color: Colors.red.shade600, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Vaciar Carrito',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: const Text(
            '¿Estás seguro de que quieres eliminar todos los productos del carrito actual?',
            style: TextStyle(fontSize: 16),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Sí, vaciar',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      widget.onClear();
      Navigator.of(context).pop();
    }
  }

  // Iniciar modo split: pregunta cuantas cuentas y activa modo asignacion
  Future<void> _startSplitDialog() async {
    final counts = [2, 3, 4, 5, 6];
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Separar en cuántas cuentas?'),
        children: counts
            .map((c) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(c),
                  child: Text('$c cuentas'),
                ))
            .toList(),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _splitCount = selected;
        _splitModeActive = true;
        _itemToSplit.clear();
      });
    }
  }

  // Aplicar split: genera grupos y abre panel de pago por cada cuenta (o devuelve datos al parent)
  void _applySplit() {
    if (!_splitModeActive || _splitCount < 2) return;
    // construir mapa cuenta -> items
    final Map<int, List<ItemCarrito>> groups = {};
    for (var i = 1; i <= _splitCount; i++) groups[i] = [];

    for (final item in widget.items) {
      final assigned = _itemToSplit[item.uniqueId] ?? 1;
      groups[assigned]!.add(item);
    }

    // Por ahora, notificamos al padre con onRemoveSelected para marcar los items seleccionados
    // Alternativamente podríamos emitir un evento más complejo. Aquí simplemente cerramos el modo.
    // Abrir modal de revisión para pagar cada grupo localmente (sin persistencia)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ReviewSplitDialog(
        groups: groups,
        onPayGroup: (groupIndex, items, subtotal) async {
          // Abrir PanelPago para este grupo y esperar confirmación
          final idsToRemove = items.map((e) => e.uniqueId).toSet();
          await showModalBottomSheet(
            context: ctx,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => PanelPago(
              subtotal: subtotal,
              items: items,
              onConfirm: ({required pagos, required fechaVenta}) async {
                // Llamar al handler general (si está conectado) para procesar la venta
                try {
                  await widget.onConfirm(pagos: pagos, fechaVenta: fechaVenta);
                } catch (_) {
                  // Ignorar errores de backend en este flujo local si existen
                }
                // Eliminar los items pagados del carrito local
                widget.onRemoveSelected(idsToRemove);
              },
            ),
          );
        },
      ),
    );

    // Salir del modo split (la revisión/acciones seguirán en el modal)
    setState(() {
      _splitModeActive = false;
      _splitCount = 0;
      _itemToSplit.clear();
    });
  }

  void _cancelSplit() {
    setState(() {
      _splitModeActive = false;
      _splitCount = 0;
      _itemToSplit.clear();
    });
  }

  Future<void> _showDiscountDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _DiscountDialog(
        currentSubtotal: _currentSubtotal,
        initialDiscount: _discountAmount,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _discountAmount = result['amount'];
        _discountLabel = result['label'];
      });
    }
  }

  // Devuelve un nombre corto para el producto quitando el prefijo de la categoría
  String _shortProductName(String fullName, String categoryName) {
    final f = fullName.trim();
    final c = categoryName.trim();
    if (c.isNotEmpty) {
      final lf = f.toLowerCase();
      final lc = c.toLowerCase();
      if (lf.startsWith(lc)) {
        var res = f.substring(c.length).trim();
        // eliminar separadores al inicio
        res = res.replaceFirst(RegExp(r'^[:\-–·\s,]+'), '').trim();
        if (res.isEmpty) return f; // si queda vacío, devolver el original
        return res;
      }
    }
    // Si no empieza exactamente por la categoría, intentar tomar la parte después de un '-' o ':'
    final parts = f.split(RegExp(r'[-–:·]'));
    if (parts.length > 1) {
      final last = parts.last.trim();
      if (last.isNotEmpty) return last;
    }
    return f;
  }

  // Devuelve una versión corta del nombre de la categoría.
  // Ej: 'Shawarma de Pollo' -> 'Pollo', 'Shawarma Carne' -> 'Carne'
  String _shortCategoriaName(String categoriaNombre) {
    final s = categoriaNombre.trim();
    if (s.isEmpty) return s;
    var low = s.toLowerCase();
    // eliminar prefijos comunes
    for (final prefix in ['shawarma de ', 'shawarma ', 'de ']) {
      if (low.startsWith(prefix)) {
        return s.substring(prefix.length).trim();
      }
    }
    // si contiene 'shawarma' en medio, intentar dividir
    if (low.contains('shawarma')) {
      final parts = s.split(RegExp(r'(?i)shawarma'));
      if (parts.length > 1) {
        final candidate =
            parts.last.replaceAll(RegExp(r'^[\-:·\s,]+'), '').trim();
        if (candidate.isNotEmpty) return candidate;
      }
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final groupedItems =
        groupBy(widget.items, (item) => item.producto.categoriaId);
    final headerTitle = _selectedItems.isNotEmpty
        ? '${_selectedItems.length} seleccionados'
        : (widget.orderName ?? 'Shawarma Oxa');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 1.0,
      minChildSize: .5,
      maxChildSize: 1.0,
      builder: (_, controller) {
        // Guardar referencia al controller interno para controlar offset
        _sheetController ??= controller;
        return Material(
          color: Colors.grey[50],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            children: [
              // Header con gradiente azul moderno
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _selectedItems.isNotEmpty
                              ? Icons.checklist_rtl
                              : Icons.shopping_cart,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              headerTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.items.isNotEmpty)
                              Text(
                                '${widget.items.length} producto${widget.items.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Nuevo: botón para dividir cuentas
                      if (!_splitModeActive) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: FilledButton.icon(
                            onPressed:
                                widget.items.isEmpty ? null : _startSplitDialog,
                            icon: const Icon(Icons.call_split_rounded,
                                color: Colors.white, size: 18),
                            label: const Text('Dividir'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.12),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          iconSize: 20,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: widget.items.isEmpty
                    ? _buildEmptyState()
                    : Container(
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                        child: ListView.builder(
                          controller: controller,
                          padding: EdgeInsets.zero,
                          itemCount: groupedItems.length,
                          itemBuilder: (context, index) {
                            final itemsInGroup =
                                groupedItems.values.elementAt(index);

                            if (itemsInGroup.length == 1) {
                              return _buildIndividualItemTile(
                                  itemsInGroup.first);
                            }

                            final bool allSelected = itemsInGroup.every(
                                (item) =>
                                    _selectedItems.contains(item.uniqueId));
                            final bool someSelected = !allSelected &&
                                itemsInGroup.any((item) =>
                                    _selectedItems.contains(item.uniqueId));

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: allSelected
                                      ? const Color(0xFF3B82F6)
                                      : Colors.grey.shade200,
                                  width: allSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ExpansionTile(
                                leading: _selectedItems.isEmpty
                                    ? Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF3B82F6)
                                                .withOpacity(0.15),
                                          ),
                                        ),
                                        child: _ProductoImage(
                                          producto: itemsInGroup.first.producto,
                                          size: 28,
                                        ),
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: allSelected
                                              ? const Color(0xFF3B82F6)
                                              : Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Checkbox(
                                          value: allSelected,
                                          tristate: someSelected,
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == false) {
                                                for (var item in itemsInGroup) {
                                                  _selectedItems
                                                      .remove(item.uniqueId);
                                                }
                                              } else {
                                                for (var item in itemsInGroup) {
                                                  _selectedItems
                                                      .add(item.uniqueId);
                                                }
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _shortCategoriaName(itemsInGroup
                                            .first.producto.categoriaNombre),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${itemsInGroup.length}',
                                        style: const TextStyle(
                                          color: Color(0xFF1E40AF),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                children: itemsInGroup
                                    .map((item) => _buildIndividualItemTile(
                                        item,
                                        isSubItem: true))
                                    .toList(),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              _buildTotalsAndActions(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tu carrito está vacío',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega productos para comenzar',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualItemTile(ItemCarrito item, {bool isSubItem = false}) {
    final bool isSelected = _selectedItems.contains(item.uniqueId);
    final bool hasComment = item.comentario.isNotEmpty;
    final bool isPriceEdited = item.precioEditable != item.producto.precio;

    void toggleSelection() {
      setState(() {
        if (isSelected) {
          _selectedItems.remove(item.uniqueId);
        } else {
          _selectedItems.add(item.uniqueId);
        }
      });
    }

    return Container(
      margin: EdgeInsets.fromLTRB(isSubItem ? 16.0 : 0, 0, 0, 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF3B82F6).withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _selectedItems.isNotEmpty ? toggleSelection : null,
          onLongPress: toggleSelection,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leading icon/checkbox
                if (_selectedItems.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 12, top: 2),
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => toggleSelection(),
                    ),
                  )
                else if (isSubItem)
                  // Subitems: show small product thumbnail (if available) or category fallback
                  Container(
                    margin: const EdgeInsets.only(right: 12, top: 2),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _ProductoImage(
                        producto: item.producto,
                        size: 40,
                      ),
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(right: 12, top: 2),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: _ProductoImage(
                      producto: item.producto,
                      size: 28,
                    ),
                  ),

                // Product info (compact): for subitems show only the product name + price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isSubItem) ...[
                        // Only product name for subitems (short variant)
                        Text(
                          _shortProductName(item.producto.nombre,
                              item.producto.categoriaNombre),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Price badge (tappable)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _showEditPriceDialog(item),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isPriceEdited
                                          ? [
                                              Colors.orange.shade400,
                                              Colors.orange.shade600
                                            ]
                                          : [
                                              const Color(0xFF1E40AF),
                                              const Color(0xFF3B82F6)
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isPriceEdited)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(
                                            Icons.edit,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      Text(
                                        'S/ ${item.precioEditable.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            // Category chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF3B82F6).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.category_outlined,
                                      size: 14, color: Color(0xFF1E40AF)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _shortCategoriaName(
                                          item.producto.categoriaNombre),
                                      style: const TextStyle(
                                          color: Color(0xFF1E40AF),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Product name
                            Expanded(
                              child: Text(
                                item.producto.nombre,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827)),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Price and optional comment indicator row
                        Row(
                          children: [
                            // Price badge (tappable)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _showEditPriceDialog(item),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isPriceEdited
                                          ? [
                                              Colors.orange.shade400,
                                              Colors.orange.shade600
                                            ]
                                          : [
                                              const Color(0xFF1E40AF),
                                              const Color(0xFF3B82F6)
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isPriceEdited)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(
                                            Icons.edit,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      Text(
                                        'S/ ${item.precioEditable.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            if (hasComment) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.comment_outlined,
                                  size: 16, color: Colors.orange.shade600),
                            ],
                          ],
                        ),
                      ],

                      // Comentario (si existe) mostrado debajo
                      if (hasComment) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.orange.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.comment,
                                size: 14,
                                color: Colors.orange.shade600,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.comentario,
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Single action button that opens a contextual menu (no overlap)
                const SizedBox(width: 8),
                Builder(builder: (ctx) {
                  return Container(
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.more_vert,
                          size: 18, color: Color(0xFF6B7280)),
                      onPressed: () async {
                        final RenderBox button =
                            ctx.findRenderObject() as RenderBox;
                        final overlay = Overlay.of(ctx)
                            .context
                            .findRenderObject() as RenderBox;
                        final position = RelativeRect.fromRect(
                          Rect.fromPoints(
                            button.localToGlobal(Offset.zero,
                                ancestor: overlay),
                            button.localToGlobal(
                                button.size.bottomRight(Offset.zero),
                                ancestor: overlay),
                          ),
                          Offset.zero & overlay.size,
                        );

                        final choice = await showMenu<int>(
                          context: ctx,
                          position: position,
                          items: [
                            PopupMenuItem(
                                value: 1,
                                child: Row(children: const [
                                  Icon(Icons.edit_note_rounded),
                                  SizedBox(width: 8),
                                  Text('Editar precio')
                                ])),
                            PopupMenuItem(
                                value: 2,
                                child: Row(children: const [
                                  Icon(Icons.comment_outlined),
                                  SizedBox(width: 8),
                                  Text('Comentario')
                                ])),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                                value: 3,
                                child: Row(children: const [
                                  Icon(Icons.remove_circle_outline,
                                      color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Eliminar')
                                ])),
                          ],
                        );

                        if (choice == 1) _showEditPriceDialog(item);
                        if (choice == 2) _showComentarioDialog(item);
                        if (choice == 3) {
                          // preservar offset actual
                          final prevOffset = _sheetController?.offset ?? 0.0;
                          widget.onRemoveItem(item.uniqueId);
                          setState(() {});
                          // restaurar offset después del rebuild (si aplica)
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_sheetController != null &&
                                _sheetController!.hasClients) {
                              final max =
                                  _sheetController!.position.maxScrollExtent;
                              final target = prevOffset.clamp(0.0, max);
                              _sheetController!.jumpTo(target);
                            }
                          });
                        }
                      },
                      tooltip: 'Acciones',
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: const EdgeInsets.all(6),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalsAndActions() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Totals section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _line('Subtotal', 'S/ ${_currentSubtotal.toStringAsFixed(2)}',
                    const TextStyle(color: Colors.white70, fontSize: 14)),
                if (_discountAmount > 0) ...[
                  const SizedBox(height: 4),
                  _line(
                      'Descuento',
                      '- S/ ${_discountAmount.toStringAsFixed(2)}',
                      TextStyle(color: Colors.orange.shade200, fontSize: 14)),
                ],
                const SizedBox(height: 8),
                Container(
                  height: 1,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 8),
                _line(
                    'Total',
                    'S/ ${_finalTotal.toStringAsFixed(2)}',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Actions section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // First row: Save and Discount
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButtonStyled(
                        icon: Icons.save_outlined,
                        label: 'Guardar',
                        color: Colors.white,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        onPressed: widget.items.isEmpty
                            ? null
                            : () async {
                                final success = await widget.onSavePending(
                                  items: widget.items,
                                  subtotal: _currentSubtotal,
                                );
                                if (success && mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButtonStyled(
                        icon: Icons.local_offer_outlined,
                        label:
                            _discountAmount > 0 ? _discountLabel! : 'Descuento',
                        color: Colors.white,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        onPressed:
                            widget.items.isEmpty ? null : _showDiscountDialog,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Second row: Clear/Pay or Split Apply/Cancel
                Row(
                  children: [
                    if (_splitModeActive) ...[
                      Expanded(
                        child: _buildActionButtonStyled(
                          icon: Icons.cancel_outlined,
                          label: 'Cancelar',
                          color: Colors.grey.shade800,
                          backgroundColor: Colors.white.withOpacity(0.9),
                          onPressed: _cancelSplit,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _buildActionButtonStyled(
                          icon: Icons.check_circle_outline,
                          label: 'Aplicar separación',
                          color: Colors.white,
                          backgroundColor: const Color(0xFF10B981),
                          isPrimary: true,
                          onPressed: _applySplit,
                        ),
                      ),
                    ] else ...[
                      if (_selectedItems.isNotEmpty)
                        Expanded(
                          child: _buildActionButtonStyled(
                            icon: Icons.delete_sweep_rounded,
                            label: 'Eliminar selec.',
                            color: Colors.red.shade600,
                            backgroundColor: Colors.red.shade50,
                            onPressed: () {
                              widget.onRemoveSelected(_selectedItems);
                              setState(() {
                                _selectedItems.clear();
                              });
                            },
                          ),
                        )
                      else
                        Expanded(
                          child: _buildActionButtonStyled(
                            icon: Icons.delete_outline,
                            label: 'Vaciar',
                            color: Colors.red.shade600,
                            backgroundColor: Colors.red.shade50,
                            onPressed: widget.items.isEmpty
                                ? null
                                : _showClearConfirmationDialog,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _buildActionButtonStyled(
                          icon: Icons.payment,
                          label: 'Pagar Ahora',
                          color: const Color(0xFF1E40AF),
                          backgroundColor: Colors.white,
                          isPrimary: true,
                          onPressed: widget.items.isEmpty
                              ? null
                              : () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    showDragHandle: true,
                                    builder: (_) => PanelPago(
                                      subtotal: _finalTotal,
                                      items: widget.items,
                                      onConfirm: (
                                              {required pagos,
                                              required fechaVenta}) =>
                                          widget.onConfirm(
                                              pagos: pagos,
                                              fechaVenta: fechaVenta),
                                    ),
                                  );
                                },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonStyled({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    bool isPrimary = false,
    VoidCallback? onPressed,
  }) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border:
            isPrimary ? Border.all(color: Colors.white.withOpacity(0.3)) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(String left, String right, TextStyle? style) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: style),
        Text(right, style: style),
      ],
    );
  }
}

// Diálogo para revisar los grupos generados por el split y pagar cada uno localmente
class ReviewSplitDialog extends StatelessWidget {
  final Map<int, List<ItemCarrito>> groups;
  final Future<void> Function(
      int groupIndex, List<ItemCarrito> items, double subtotal) onPayGroup;

  const ReviewSplitDialog(
      {super.key, required this.groups, required this.onPayGroup});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) {
          return Material(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  child: const Text('Revisar cuentas',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.all(12),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final key = groups.keys.elementAt(index);
                      final items = groups[key]!;
                      final subtotal = items.fold<double>(
                          0.0, (s, e) => s + e.precioEditable);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Cuenta $key',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  Text('S/ ${subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: items.map((it) {
                                  return ListTile(
                                    dense: true,
                                    leading: SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: _ProductoImage(
                                            producto: it.producto, size: 40)),
                                    title: Text(it.producto.nombre,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    trailing: Text(
                                        'S/ ${it.precioEditable.toStringAsFixed(2)}'),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('Cerrar'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () async {
                                        await onPayGroup(key, items, subtotal);
                                        // Cerrar el dialogo de revisión para que el flujo de pago muestre el panel de pago
                                        // Aquí no forzamos recarga; se espera que el caller elimine items al confirmar pago
                                      },
                                      child: const Text('Pagar'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EditPriceDialog extends StatefulWidget {
  final double initialPrice;
  final String productName;
  final double originalPrice;

  const _EditPriceDialog(
      {required this.initialPrice,
      required this.productName,
      required this.originalPrice});

  @override
  State<_EditPriceDialog> createState() => _EditPriceDialogState();
}

class _EditPriceDialogState extends State<_EditPriceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.initialPrice.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final newPrice = double.tryParse(_controller.text);
      Navigator.of(context).pop(newPrice);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_note,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Editar Precio de\n${widget.productName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _controller,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixText: 'S/ ',
                        labelText: 'Nuevo Precio',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            color: Colors.orange.shade600,
                            icon: const Icon(Icons.undo_rounded),
                            tooltip: 'Restaurar precio original',
                            onPressed: () {
                              _controller.text =
                                  widget.originalPrice.toStringAsFixed(2);
                              _controller.selection =
                                  TextSelection.fromPosition(
                                TextPosition(offset: _controller.text.length),
                              );
                            },
                          ),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            double.tryParse(value) == null) {
                          return 'Ingrese un monto válido';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),

                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Confirmar',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscountDialog extends StatefulWidget {
  final double currentSubtotal;
  final double initialDiscount;

  const _DiscountDialog({
    required this.currentSubtotal,
    required this.initialDiscount,
  });

  @override
  _DiscountDialogState createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _percentController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _percentController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _applyDiscount() {
    double finalAmount = 0.0;
    String finalLabel = '';

    if (_tabController.index == 0) {
      final percent = double.tryParse(_percentController.text) ?? 0;
      if (percent > 0) {
        finalAmount = (widget.currentSubtotal * percent) / 100;
        finalLabel = '$percent%';
      }
    } else {
      final amount = double.tryParse(_amountController.text) ?? 0;
      if (amount > 0) {
        finalAmount = amount;
        finalLabel = 'S/ ${amount.toStringAsFixed(2)}';
      }
    }
    Navigator.of(context).pop({'amount': finalAmount, 'label': finalLabel});
  }

  void _removeDiscount() {
    Navigator.of(context).pop({'amount': 0.0, 'label': null});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 340,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_offer,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Aplicar Descuento',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Tab bar
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey.shade600,
                      tabs: const [
                        Tab(text: 'Porcentaje'),
                        Tab(text: 'Monto Fijo'),
                      ],
                    ),
                  ),

                  // Tab content
                  SizedBox(
                    height: 100,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPercentTab(),
                        _buildAmountTab(),
                      ],
                    ),
                  ),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        if (widget.initialDiscount > 0)
                          TextButton.icon(
                            onPressed: _removeDiscount,
                            icon: const Icon(Icons.clear, size: 18),
                            label: const Text('Quitar'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade600,
                            ),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ElevatedButton(
                            onPressed: _applyDiscount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Aplicar',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
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
    );
  }

  Widget _buildPercentTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Center(
        child: TextFormField(
          controller: _percentController,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '0',
            suffixIcon: const Padding(
              padding: EdgeInsets.only(right: 12.0),
              child: Icon(Icons.percent, size: 18, color: Colors.grey),
            ),
            filled: true,
            fillColor:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
          ],
        ),
      ),
    );
  }

  Widget _buildAmountTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Center(
        child: TextFormField(
          controller: _amountController,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '0.00',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Text('S/',
                  style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodySmall?.color)),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
          ],
        ),
      ),
    );
  }
}
