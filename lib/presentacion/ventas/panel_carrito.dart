// lib/presentacion/ventas/panel_carrito.dart

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/producto.dart';
import 'package:shawarma_pos_nuevo/presentacion/ventas/item_carrito.dart';
import 'package:shawarma_pos_nuevo/presentacion/ventas/panel_pago.dart';

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
  double _discountAmount = 0;
  String? _discountLabel;

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

  @override
  Widget build(BuildContext context) {
    final groupedItems = groupBy(widget.items, (item) => item.producto.id);
    final headerTitle = _selectedItems.isNotEmpty
        ? '${_selectedItems.length} seleccionados'
        : (widget.orderName ?? ' ✫⸻Shawarma Oxa⸻✫');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 1.0,
      minChildSize: .5,
      maxChildSize: 1.0,
      builder: (_, controller) {
        return Material(
          color: Colors.grey[50],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            children: [
              // Header con gradiente azul moderno
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _selectedItems.isNotEmpty
                            ? Icons.checklist_rtl
                            : Icons.shopping_cart,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headerTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.items.isNotEmpty)
                            Text(
                              '${widget.items.length} productos',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: widget.items.isEmpty
                    ? _buildEmptyState()
                    : Container(
                        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
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
                              margin: const EdgeInsets.only(bottom: 8),
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
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF1E40AF),
                                              Color(0xFF3B82F6)
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.category,
                                          color: Colors.white,
                                          size: 20,
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
                                        itemsInGroup.first.producto.nombre,
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Leading icon/checkbox
                if (_selectedItems.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => toggleSelection(),
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),

                // Product info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.producto.nombre,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          // Price badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
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
                            child: Text(
                              'S/ ${item.precioEditable.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Category badge
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Producto',
                              style: const TextStyle(
                                color: Color(0xFF1E40AF),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (hasComment) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.comment,
                              size: 16,
                              color: Colors.orange.shade600,
                            ),
                          ],
                        ],
                      ),

                      // Comment display
                      if (hasComment) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.orange.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.comentario,
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Action buttons
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(
                      icon: Icons.edit_note_rounded,
                      color: isPriceEdited ? Colors.orange : Colors.blue,
                      onPressed: () => _showEditPriceDialog(item),
                      tooltip: 'Editar precio',
                    ),
                    _buildActionButton(
                      icon: Icons.comment_outlined,
                      color: hasComment ? Colors.orange : Colors.grey,
                      onPressed: () => _showComentarioDialog(item),
                      tooltip: 'Agregar comentario',
                    ),
                    _buildActionButton(
                      icon: Icons.remove_circle_outline,
                      color: Colors.red,
                      onPressed: () {
                        widget.onRemoveItem(item.uniqueId);
                        setState(() {});
                      },
                      tooltip: 'Eliminar',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: const EdgeInsets.all(6),
      ),
    );
  }

  Widget _buildTotalsAndActions() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Totals section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _line('Subtotal', 'S/ ${_currentSubtotal.toStringAsFixed(2)}',
                    const TextStyle(color: Colors.white70, fontSize: 16)),
                if (_discountAmount > 0) ...[
                  const SizedBox(height: 8),
                  _line(
                      'Descuento',
                      '- S/ ${_discountAmount.toStringAsFixed(2)}',
                      TextStyle(color: Colors.orange.shade200, fontSize: 16)),
                ],
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                _line(
                    'Total',
                    'S/ ${_finalTotal.toStringAsFixed(2)}',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Actions section
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
                    const SizedBox(width: 12),
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
                const SizedBox(height: 12),

                // Second row: Clear and Pay
                Row(
                  children: [
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
                    const SizedBox(width: 12),
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
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border:
            isPrimary ? Border.all(color: Colors.white.withOpacity(0.3)) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
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
