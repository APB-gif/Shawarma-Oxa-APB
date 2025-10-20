// lib/presentacion/gastos/panel_gastos.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/producto.dart';
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
      );
    }

    // GS:// (Firebase Storage)
    if (_isGs(iconPath)) {
      return FutureBuilder<String>(
        future: _gsToUrl(iconPath),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 1),
            );
          }
          final url = snapshot.data!;
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
          );
        },
      );
    }

    return const Icon(Icons.restaurant_menu, size: 18, color: Colors.white);
  }
}

/// Widget para mostrar imagen de producto con fallback
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

class ItemGasto {
  final Producto producto;
  final String uniqueId;
  final bool isCompleted;
  final double precioEditable;

  const ItemGasto({
    required this.producto,
    required this.uniqueId,
    required this.precioEditable,
    this.isCompleted = false,
  });

  ItemGasto copyWith({
    Producto? producto,
    String? uniqueId,
    double? precioEditable,
    bool? isCompleted,
  }) {
    return ItemGasto(
      producto: producto ?? this.producto,
      uniqueId: uniqueId ?? this.uniqueId,
      precioEditable: precioEditable ?? this.precioEditable,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  factory ItemGasto.fromMap(Map<String, dynamic> map) {
    return ItemGasto(
      producto: Producto.fromMap(map['producto']),
      uniqueId: map['uniqueId'] as String,
      precioEditable: (map['precioEditable'] as num).toDouble(),
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'producto': producto.toMap(),
      'uniqueId': uniqueId,
      'precioEditable': precioEditable,
      'isCompleted': isCompleted,
    };
  }
}

class PanelGastos extends StatefulWidget {
  final List<ItemGasto> items;
  final VoidCallback onClear;
  final Function(String uniqueId) onRemoveItem;
  final Function(String uniqueId, double newPrice) onUpdatePrice;
  final Future<void> Function() onSaveToShoppingList;
  final void Function(double total) onConfirm;

  const PanelGastos({
    super.key,
    required this.items,
    required this.onClear,
    required this.onRemoveItem,
    required this.onUpdatePrice,
    required this.onSaveToShoppingList,
    required this.onConfirm,
  });

  @override
  State<PanelGastos> createState() => _PanelGastosState();
}

class _PanelGastosState extends State<PanelGastos> {
  late List<ItemGasto> _items;
  bool _savingList = false;
  final Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _items = List<ItemGasto>.from(widget.items);
  }

  @override
  void didUpdateWidget(covariant PanelGastos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != _items.length ||
        !widget.items.every((item) => _items.contains(item))) {
      setState(() {
        _items = List<ItemGasto>.from(widget.items);
      });
    }
  }

  void _localClear() {
    // Actualizar estado local inmediatamente para reflejar el vaciado
    setState(() {
      _items.clear();
    });
    // Notificar al padre para que también realice la acción de limpiar
    widget.onClear();
  }

  void _localRemove(String uniqueId) {
    widget.onRemoveItem(uniqueId);
  }

  void _localUpdatePrice(String uniqueId, double newPrice) {
    widget.onUpdatePrice(uniqueId, newPrice);
  }

  Future<void> _saveAndCloseList() async {
    if (_items.isEmpty || _savingList) return;
    setState(() => _savingList = true);
    try {
      await widget.onSaveToShoppingList();
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onClear();
    } finally {
      if (mounted) setState(() => _savingList = false);
    }
  }

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

  void _showClearConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vaciar Lista'),
        content:
            const Text('¿Estás seguro de que quieres quitar todos los ítems?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _localClear();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Vaciar'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalGastos =
        _items.fold(0.0, (sum, item) => sum + item.precioEditable);
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con gradiente
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E40AF), // Azul moderno
                  Color(0xFF3B82F6), // Azul más claro
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E40AF).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: theme.colorScheme.onSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumen de Gastos',
                        style: TextStyle(
                          color: theme.colorScheme.onSecondary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_items.length} ${_items.length == 1 ? 'producto' : 'productos'}',
                        style: TextStyle(
                          color: theme.colorScheme.onSecondary.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: theme.colorScheme.onSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Lista de items (scrollable)
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.5 - keyboardHeight,
              ),
              child: _items.isEmpty
                  ? _buildEmptyState()
                  : Container(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                      child: () {
                        // Agrupar items por categoría manualmente
                        final Map<String, List<ItemGasto>> groupedItems = {};
                        for (final item in _items) {
                          final categoryId = item.producto.categoriaId;
                          if (!groupedItems.containsKey(categoryId)) {
                            groupedItems[categoryId] = [];
                          }
                          groupedItems[categoryId]!.add(item);
                        }

                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: groupedItems.length,
                          itemBuilder: (context, index) {
                            final categoryId =
                                groupedItems.keys.elementAt(index);
                            final itemsInGroup = groupedItems[categoryId]!;

                            if (itemsInGroup.length == 1) {
                              return _buildIndividualGastoTile(
                                  itemsInGroup.first);
                            }

                            final isExpanded =
                                _expandedCategories.contains(categoryId);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
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
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF1E40AF)
                                          .withOpacity(0.15),
                                    ),
                                  ),
                                  child: _ProductoImage(
                                    producto: itemsInGroup.first.producto,
                                    size: 28,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _shortCategoriaName(itemsInGroup
                                            .first.producto.categoriaNombre),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${itemsInGroup.length} productos',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E40AF)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'S/ ${itemsInGroup.fold(0.0, (sum, item) => sum + item.precioEditable).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF1E40AF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                initiallyExpanded: isExpanded,
                                onExpansionChanged: (expanded) {
                                  setState(() {
                                    if (expanded) {
                                      _expandedCategories.add(categoryId);
                                    } else {
                                      _expandedCategories.remove(categoryId);
                                    }
                                  });
                                },
                                children: itemsInGroup.map((item) {
                                  return Container(
                                    margin: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 12),
                                    child: _buildIndividualGastoTile(item,
                                        isInsideGroup: true),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        );
                      }(),
                    ),
            ),
          ),

          // Footer con total y acciones
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + keyboardHeight),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Total
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E40AF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1E40AF).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.payments_rounded,
                            color: Color(0xFF1E40AF),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Total Gasto',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'S/ ${totalGastos.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Botones de acción
                Row(
                  children: [
                    // Botón añadir a lista
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _items.isEmpty || _savingList
                            ? null
                            : _saveAndCloseList,
                        icon: _savingList
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.playlist_add_check_rounded,
                                size: 18),
                        label: Text(_savingList ? 'Guardando...' : 'A Lista'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: _items.isEmpty
                                ? Colors.grey.shade300
                                : theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Botón vaciar
                    OutlinedButton(
                      onPressed:
                          _items.isEmpty ? null : _showClearConfirmationDialog,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(14),
                        side: BorderSide(
                          color: _items.isEmpty
                              ? Colors.grey.shade300
                              : Colors.red.shade400,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.delete_sweep_rounded,
                        color: _items.isEmpty
                            ? Colors.grey.shade400
                            : Colors.red.shade600,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Botón registrar
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _items.isEmpty
                            ? null
                            : () => widget.onConfirm(totalGastos),
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('Registrar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualGastoTile(ItemGasto item,
      {bool isInsideGroup = false}) {
    return _GastoItemTile(
      key: ValueKey(item.uniqueId),
      item: item,
      onRemoveItem: _localRemove,
      onUpdatePrice: _localUpdatePrice,
      isInsideGroup: isInsideGroup,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin productos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Añade productos para registrar un gasto',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GastoItemTile extends StatefulWidget {
  final ItemGasto item;
  final Function(String uniqueId) onRemoveItem;
  final Function(String uniqueId, double newPrice) onUpdatePrice;
  final bool isInsideGroup;

  const _GastoItemTile({
    super.key,
    required this.item,
    required this.onRemoveItem,
    required this.onUpdatePrice,
    this.isInsideGroup = false,
  });

  @override
  State<_GastoItemTile> createState() => _GastoItemTileState();
}

class _GastoItemTileState extends State<_GastoItemTile> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
        text: widget.item.precioEditable > 0
            ? widget.item.precioEditable.toStringAsFixed(2)
            : '');
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _controller.selection =
          TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    }
  }

  @override
  void didUpdateWidget(covariant _GastoItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentPriceInController =
        double.tryParse(_controller.text.replaceAll(',', '.')) ?? -1;
    if ((widget.item.precioEditable - currentPriceInController).abs() > 0.001) {
      final newText = widget.item.precioEditable > 0
          ? widget.item.precioEditable.toStringAsFixed(2)
          : '';
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 400;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nombre del producto con imagen
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF1E40AF).withOpacity(0.15),
                    ),
                  ),
                  child: _ProductoImage(
                    producto: widget.item.producto,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.producto.nombre,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!widget.isInsideGroup &&
                          widget.item.producto.categoriaNombre.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.item.producto.categoriaNombre,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Precio y botón eliminar
            Row(
              children: [
                // Etiqueta "Precio"
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text(
                    'Precio:',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Campo de precio
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _focusNode.hasFocus
                            ? theme.colorScheme.primary
                            : Colors.grey.shade300,
                        width: _focusNode.hasFocus ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Prefijo "S/"
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: const Text(
                            'S/',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ),

                        const SizedBox(width: 4),

                        // Campo de texto
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: isMobile ? 15 : 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E40AF),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              hintText: '0.00',
                            ),
                            onChanged: (value) {
                              final newPrice =
                                  double.tryParse(value.replaceAll(',', '.')) ??
                                      0.0;
                              widget.onUpdatePrice(
                                  widget.item.uniqueId, newPrice);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Botón eliminar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: () => widget.onRemoveItem(widget.item.uniqueId),
                    tooltip: 'Eliminar',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
