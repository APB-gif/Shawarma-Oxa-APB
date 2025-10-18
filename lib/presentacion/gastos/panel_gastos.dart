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
    final theme = Theme.of(context);
    final totalGastos = _items.fold(0.0, (sum, item) => sum + item.precioEditable);
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
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
                  Color(0xFF059669), // Verde esmeralda
                  Color(0xFF10B981), // Verde más claro
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withOpacity(0.3),
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
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
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
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.payments_rounded,
                            color: Color(0xFF059669),
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
                          color: Color(0xFF059669),
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
                        onPressed: _items.isEmpty || _savingList ? null : _saveAndCloseList,
                        icon: _savingList
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.playlist_add_check_rounded, size: 18),
                        label: Text(_savingList ? 'Guardando...' : 'A Lista'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: _items.isEmpty ? Colors.grey.shade300 : theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Botón vaciar
                    OutlinedButton(
                      onPressed: _items.isEmpty ? null : _showClearConfirmationDialog,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(14),
                        side: BorderSide(
                          color: _items.isEmpty ? Colors.grey.shade300 : Colors.red.shade400,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.delete_sweep_rounded,
                        color: _items.isEmpty ? Colors.grey.shade400 : Colors.red.shade600,
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Botón registrar
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _items.isEmpty ? null : () => widget.onConfirm(totalGastos),
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('Registrar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
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
            // Nombre del producto
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.item.producto.nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 4),
                        
                        // Campo de texto
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: isMobile ? 15 : 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF059669),
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
                              final newPrice = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
                              widget.onUpdatePrice(widget.item.uniqueId, newPrice);
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