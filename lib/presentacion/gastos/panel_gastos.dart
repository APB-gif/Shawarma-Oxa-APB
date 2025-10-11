// lib/presentacion/gastos/panel_gastos.dart
import 'package:flutter/material.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/producto.dart';

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

  void _showClearConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vaciar Lista'),
        content: const Text('¿Estás seguro de que quieres quitar todos los ítems?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
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
    final totalGastos = _items.fold(0.0, (sum, item) => sum + item.precioEditable);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Resumen de Gastos', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: _items.isEmpty
                  ? const Center(child: Text('Añade productos para registrar un gasto.'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _GastoItemTile(
                          key: ValueKey(item.uniqueId),
                          item: item,
                          onRemoveItem: _localRemove,
                          onUpdatePrice: _localUpdatePrice,
                        );
                      },
                    ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Gasto:', style: Theme.of(context).textTheme.titleLarge),
                Text(
                  'S/ ${totalGastos.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  icon: _savingList
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.playlist_add_check_outlined),
                  tooltip: _savingList ? 'Guardando...' : 'Añadir a lista de compras',
                  onPressed: _items.isEmpty || _savingList ? null : _saveAndCloseList,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Vaciar lista',
                  onPressed: _items.isEmpty ? null : _showClearConfirmationDialog,
                  color: Colors.redAccent,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _items.isEmpty ? null : () => widget.onConfirm(totalGastos),
                  icon: const Icon(Icons.payment),
                  label: const Text('Registrar Gasto'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            )
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

  const _GastoItemTile({
    super.key,
    required this.item,
    required this.onRemoveItem,
    required this.onUpdatePrice,
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
    _controller = TextEditingController(text: widget.item.precioEditable > 0 ? widget.item.precioEditable.toStringAsFixed(2) : '');
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
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    }
  }

  @override
  void didUpdateWidget(covariant _GastoItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentPriceInController = double.tryParse(_controller.text.replaceAll(',', '.')) ?? -1;
    if ((widget.item.precioEditable - currentPriceInController).abs() > 0.001) {
      final newText = widget.item.precioEditable > 0 ? widget.item.precioEditable.toStringAsFixed(2) : '';
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceTextStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: theme.textTheme.bodyLarge?.color,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(widget.item.producto.nombre),
        trailing: SizedBox(
          width: 150,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: priceTextStyle,
                  decoration: InputDecoration(
                    prefixText: 'S/ ',
                    prefixStyle: priceTextStyle,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    // <<-- CAMBIO: Añadido para que el borde siempre sea visible.
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
                    ),
                    // <<-- CAMBIO: Define cómo se ve el borde cuando está seleccionado.
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: theme.primaryColor, width: 2.0),
                    ),
                  ),
                  onChanged: (value) {
                    final newPrice = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
                    widget.onUpdatePrice(widget.item.uniqueId, newPrice);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () => widget.onRemoveItem(widget.item.uniqueId),
              ),
            ],
          ),
        ),
      ),
    );
  }
}