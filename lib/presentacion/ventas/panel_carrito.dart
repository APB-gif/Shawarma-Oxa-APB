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
        title: Text('Comentario para ${item.producto.nombre}'),
        content: TextField(
          controller: comentarioController,
          decoration: InputDecoration(
            labelText: 'Escribe tu comentario',
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => comentarioController.clear(),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, comentarioController.text),
              child: const Text('Guardar')),
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
        title: const Text('Vaciar Carrito'),
        content: const Text(
            '¿Estás seguro de que quieres eliminar todos los productos del carrito actual?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, vaciar'),
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
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(headerTitle,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              const Divider(),
              Expanded(
                child: widget.items.isEmpty
                    ? const Center(child: Text('Tu carrito está vacío'))
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: groupedItems.length,
                        itemBuilder: (context, index) {
                          final itemsInGroup =
                              groupedItems.values.elementAt(index);

                          if (itemsInGroup.length == 1) {
                            return _buildIndividualItemTile(itemsInGroup.first);
                          }

                          final bool allSelected = itemsInGroup.every(
                              (item) => _selectedItems.contains(item.uniqueId));
                          final bool someSelected = !allSelected &&
                              itemsInGroup.any((item) =>
                                  _selectedItems.contains(item.uniqueId));

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
                            clipBehavior: Clip.antiAlias,
                            child: ExpansionTile(
                              leading: _selectedItems.isEmpty
                                  ? null
                                  : Checkbox(
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
                                              _selectedItems.add(item.uniqueId);
                                            }
                                          }
                                        });
                                      },
                                    ),
                              title: Text(
                                  '${itemsInGroup.first.producto.nombre} (${itemsInGroup.length})'),
                              children: itemsInGroup
                                  .map((item) => _buildIndividualItemTile(item,
                                      isSubItem: true))
                                  .toList(),
                            ),
                          );
                        },
                      ),
              ),
              const Divider(),
              _buildTotalsAndActions(),
            ],
          ),
        );
      },
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

    return Card(
      margin: EdgeInsets.fromLTRB(isSubItem ? 24.0 : 8.0, 4, 8, 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: _selectedItems.isNotEmpty ? toggleSelection : null,
        onLongPress: toggleSelection,
        selected: isSelected,
        selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.15),
        title: Text(item.producto.nombre),
        subtitle: hasComment
            ? Text(
                'S/ ${item.precioEditable.toStringAsFixed(2)} - ${item.comentario}')
            : Text('S/ ${item.precioEditable.toStringAsFixed(2)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: Icon(
                  Icons.edit_note_rounded,
                  color: isPriceEdited ? Colors.orangeAccent : null,
                ),
                onPressed: () => _showEditPriceDialog(item)),
            IconButton(
                icon: Icon(
                  Icons.comment_outlined,
                  color: hasComment ? Colors.orangeAccent : null,
                ),
                onPressed: () => _showComentarioDialog(item)),
            IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    color: Colors.redAccent),
                onPressed: () {
                  widget.onRemoveItem(item.uniqueId);
                  setState(() {});
                }),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsAndActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _totalsSection(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 16, 16),
          child: Row(
            children: [
              // =======================================================================
              // MODIFICADO: Se ajusta la llamada a onSavePending para cerrar el panel de forma segura
              // =======================================================================
              IconButton(
                color: const Color.fromARGB(255, 4, 87, 138),
                icon: const Icon(Icons.save_outlined),
                tooltip: 'Guardar pendiente',
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
              OutlinedButton.icon(
                onPressed: widget.items.isEmpty ? null : _showDiscountDialog,
                icon: const Icon(Icons.local_offer_outlined, size: 20),
                label: _discountAmount > 0
                    ? Text(_discountLabel!)
                    : const Text("Descuento"),
              ),
              if (_selectedItems.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded),
                  tooltip: 'Eliminar seleccionados',
                  color: Colors.red,
                  onPressed: () {
                    widget.onRemoveSelected(_selectedItems);
                    setState(() {
                      _selectedItems.clear();
                    });
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Vaciar carrito',
                  onPressed: widget.items.isEmpty
                      ? null
                      : _showClearConfirmationDialog,
                  color: Colors.red,
                ),
              const Spacer(),
              FilledButton.icon(
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
                                    {required pagos, required fechaVenta}) =>
                                widget.onConfirm(
                                    pagos: pagos, fechaVenta: fechaVenta),
                          ),
                        );
                      },
                icon: const Icon(Icons.payment),
                label: const Text('Pagar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _totalsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _line('Subtotal', 'S/ ${_currentSubtotal.toStringAsFixed(2)}', null),
          if (_discountAmount > 0)
            _line('Descuento', '- S/ ${_discountAmount.toStringAsFixed(2)}',
                null),
          const Divider(),
          _line('Total', 'S/ ${_finalTotal.toStringAsFixed(2)}',
              Theme.of(context).textTheme.titleLarge)
        ],
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
    return AlertDialog(
      title: Text('Editar Precio de ${widget.productName}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: 'S/ ',
            labelText: 'Nuevo Precio',
            suffixIcon: IconButton(
              color: Colors.red,
              icon: const Icon(Icons.undo_rounded),
              tooltip: 'Restaurar precio original',
              onPressed: () {
                _controller.text = widget.originalPrice.toStringAsFixed(2);
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
              },
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
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
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _submit,
          child: const Text('Confirmar'),
        )
      ],
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
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Aplicar Descuento',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Porcentaje'),
                Tab(text: 'Monto Fijo'),
              ],
            ),
            const Divider(height: 1),
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.initialDiscount > 0)
                    TextButton(
                      onPressed: _removeDiscount,
                      child: const Text('Quitar'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _applyDiscount,
                    child: const Text('Aplicar'),
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
