// lib/presentacion/ventas/panel_pago.dart

import 'package:flutter/material.dart';
import 'package:shawarma_pos_nuevo/presentacion/pagina_principal.dart';
import 'package:intl/intl.dart'; // <-- AÑADIDO
import 'package:shawarma_pos_nuevo/presentacion/ventas/item_carrito.dart';

enum MetodoDePago {
  cash,
  izipayCard,
  izipayYape,
  yapePersonal,
  split;

  String get displayName {
    switch (this) {
      case MetodoDePago.cash:
        return 'Efectivo';
      case MetodoDePago.izipayCard:
        return 'Tarjeta';
      case MetodoDePago.izipayYape:
        return 'IziPay Yape';
      case MetodoDePago.yapePersonal:
        return 'Yape Pers.';
      case MetodoDePago.split:
        return 'Dividir';
    }
  }

  IconData get icon {
    switch (this) {
      case MetodoDePago.cash:
        return Icons.money_outlined;
      case MetodoDePago.izipayCard:
        return Icons.credit_card_outlined;
      case MetodoDePago.izipayYape:
        return Icons.qr_code_2_outlined;
      case MetodoDePago.yapePersonal:
        return Icons.phone_android_outlined;
      case MetodoDePago.split:
        return Icons.call_split_outlined;
    }
  }
}

class PanelPago extends StatefulWidget {
  final double subtotal;
  final List<ItemCarrito> items;
  // MODIFICADO: onConfirm ahora también devuelve la fecha de la venta
  final Future<void> Function({
    required Map<String, double> pagos,
    required DateTime fechaVenta,
  }) onConfirm;

  const PanelPago({
    super.key,
    required this.subtotal,
    required this.items,
    required this.onConfirm,
  });

  @override
  State<PanelPago> createState() => _PanelPagoState();
}

class _PanelPagoState extends State<PanelPago> {
  MetodoDePago _method = MetodoDePago.cash;
  final _cashCtl = TextEditingController();
  final _cardCtl = TextEditingController();
  final _izipayYapeCtl = TextEditingController();
  final _yapePersonalCtl = TextEditingController();
  final _fnCash = FocusNode();
  final _fnCard = FocusNode();
  final _fnIziYape = FocusNode();
  final _fnYapePers = FocusNode();
  static const double _cardFeeRate = 0.05;
  final bool _autoFill = true;

  // NUEVO: Asignación por ítem cuando el método es split con montos parciales
  // item.uniqueId -> {MetodoDePago: montoBase}
  final Map<String, Map<MetodoDePago, double>> _splitsByItem = {};
  // Última acción rápida aplicada (para resaltar el ícono seleccionado)
  MetodoDePago? _quickSelected;

  // NUEVO: Split por total (en vez de por ítem)
  bool _splitByTotal = false;
  final _stCashCtl = TextEditingController();
  final _stCardCtl = TextEditingController(); // base sin fee
  final _stIziCtl = TextEditingController();
  final _stYapeCtl = TextEditingController();
  final _stCashFn = FocusNode();
  final _stCardFn = FocusNode();
  final _stIziFn = FocusNode();
  final _stYapeFn = FocusNode();

  // Visual metadata for methods
  _MethodDisp _methodDisplay(MetodoDePago m) {
    switch (m) {
      case MetodoDePago.cash:
        return _MethodDisp('Efectivo', Icons.money_outlined, Colors.green.shade700);
      case MetodoDePago.izipayCard:
        return _MethodDisp('Tarjeta', Icons.credit_card_outlined, Colors.blue.shade700);
      case MetodoDePago.izipayYape:
        return _MethodDisp('IziYape', Icons.qr_code_2_outlined, Colors.purple.shade700);
      case MetodoDePago.yapePersonal:
        return _MethodDisp('Yape Pers.', Icons.phone_android_outlined, Colors.purple.shade900);
      case MetodoDePago.split:
        // No se usa como método por ítem; devolver un estilo neutral por si acaso.
        return _MethodDisp('Dividir', Icons.call_split_outlined, Colors.teal.shade700);
    }
  }

  // Eliminado: el selector antiguo por método se reemplazó por el editor de montos por ítem
  // NUEVO: Variable de estado para la fecha de la venta
  DateTime _fechaVenta = DateTime.now();

  double get _subtotal => widget.subtotal;
  double _cardWithFee(double base) => base * (1 + _cardFeeRate);
  double _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0;

  double get _totalAPagar {
    if (_method == MetodoDePago.izipayCard) {
      return _cardWithFee(_subtotal);
    } else if (_method == MetodoDePago.split) {
      // En split (por ítem o por total), calcular el total con fee de tarjeta
      final totals = _currentSplitTotals();
      final cardBase = totals[MetodoDePago.izipayCard] ?? 0.0;
      final others = (totals[MetodoDePago.cash] ?? 0.0) +
          (totals[MetodoDePago.izipayYape] ?? 0.0) +
          (totals[MetodoDePago.yapePersonal] ?? 0.0);
      return others + _cardWithFee(cardBase);
    }
    return _subtotal;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Prefill texts without focusing any field to avoid opening the keyboard.
      if (_autoFill) _setTextsForMethod(_method);
      _unfocusAll();
      // Preparar estado inicial para split: por defecto todo a efectivo (monto completo)
      if (_splitsByItem.isEmpty) {
        for (final it in widget.items) {
          _splitsByItem[it.uniqueId] = {MetodoDePago.cash: it.precioEditable};
        }
        setState(() {});
      }
      // Inicial por total: todo a efectivo
      _stCashCtl.text = widget.subtotal.toStringAsFixed(2);
      _stCardCtl.clear();
      _stIziCtl.clear();
      _stYapeCtl.clear();
    });
  }

  @override
  void dispose() {
    _cashCtl.dispose();
    _cardCtl.dispose();
    _izipayYapeCtl.dispose();
    _yapePersonalCtl.dispose();
    _fnCash.dispose();
    _fnCard.dispose();
    _fnIziYape.dispose();
    _fnYapePers.dispose();
    _stCashFn.dispose();
    _stCardFn.dispose();
    _stIziFn.dispose();
    _stYapeFn.dispose();
    _stCashCtl.dispose();
    _stCardCtl.dispose();
    _stIziCtl.dispose();
    _stYapeCtl.dispose();
    super.dispose();
  }

  void _clearAllInputs() {
    _cashCtl.clear();
    _cardCtl.clear();
    _izipayYapeCtl.clear();
    _yapePersonalCtl.clear();
  }

  void _unfocusAll() {
    FocusScope.of(context).unfocus();
  }

  // Eliminado enfoque automático para no abrir teclado; el usuario enfocará manualmente.

  void _setTextsForMethod(MetodoDePago m) {
    _clearAllInputs();
    switch (m) {
      case MetodoDePago.cash:
        _cashCtl.text = _subtotal.toStringAsFixed(2);
        break;
      case MetodoDePago.izipayCard:
        _cardCtl.text = _cardWithFee(_subtotal).toStringAsFixed(2);
        break;
      case MetodoDePago.izipayYape:
        _izipayYapeCtl.text = _subtotal.toStringAsFixed(2);
        break;
      case MetodoDePago.yapePersonal:
        _yapePersonalCtl.text = _subtotal.toStringAsFixed(2);
        break;
      case MetodoDePago.split:
        break;
    }
  }

  void _onMethodChanged(MetodoDePago m) {
    setState(() {
      _method = m;
      if (_autoFill) _setTextsForMethod(m);
    });
    // No solicitar foco automáticamente; el usuario decide cuándo ingresar montos.
  }

  Map<MetodoDePago, double> _buildSplitTotals() {
    final totals = <MetodoDePago, double>{
      MetodoDePago.cash: 0.0,
      MetodoDePago.izipayCard: 0.0,
      MetodoDePago.izipayYape: 0.0,
      MetodoDePago.yapePersonal: 0.0,
    };
    for (final parts in _splitsByItem.values) {
      parts.forEach((met, amount) {
        if (totals.containsKey(met)) {
          totals[met] = (totals[met] ?? 0.0) + amount;
        }
      });
    }
    return totals;
  }

  // Totales actuales considerando el modo de split activo
  Map<MetodoDePago, double> _currentSplitTotals() {
    if (_splitByTotal) {
      double p(TextEditingController c) =>
          double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0;
      return {
        MetodoDePago.cash: p(_stCashCtl),
        MetodoDePago.izipayCard: p(_stCardCtl),
        MetodoDePago.izipayYape: p(_stIziCtl),
        MetodoDePago.yapePersonal: p(_stYapeCtl),
      };
    }
    return _buildSplitTotals();
  }

  void _confirm() async {
    final Map<String, double> pagos = {};
    try {
      switch (_method) {
        case MetodoDePago.cash:
          pagos['Efectivo'] = _subtotal;
          break;
        case MetodoDePago.izipayCard:
          pagos['Tarjeta'] = _cardWithFee(_subtotal);
          break;
        case MetodoDePago.izipayYape:
          pagos['IziPay Yape'] = _subtotal;
          break;
        case MetodoDePago.yapePersonal:
          pagos['Yape Personal'] = _subtotal;
          break;
        case MetodoDePago.split:
          // Construir totales por método desde el modo activo (por ítem o por total)
          final totals = _currentSplitTotals();
          final cashAmount = totals[MetodoDePago.cash] ?? 0.0;
          final cardBase = totals[MetodoDePago.izipayCard] ?? 0.0;
          final cardAmount = _cardWithFee(cardBase);
          final iziYapeAmount = totals[MetodoDePago.izipayYape] ?? 0.0;
          final yapePersAmount = totals[MetodoDePago.yapePersonal] ?? 0.0;

          if (cashAmount > 0) pagos['Efectivo'] = cashAmount;
          if (cardAmount > 0) pagos['Tarjeta'] = cardAmount;
          if (iziYapeAmount > 0) pagos['IziPay Yape'] = iziYapeAmount;
          if (yapePersAmount > 0) pagos['Yape Personal'] = yapePersAmount;

          final assignedBase = cashAmount + cardBase + iziYapeAmount + yapePersAmount;
          if ((assignedBase - _subtotal).abs() > 0.01) {
            principalMessengerKey.currentState?.showSnackBar(const SnackBar(
                content: Text('Los montos no coinciden con el total. Completa o corrige los importes.')));
            return;
          }
          break;
      }

      if (pagos.isEmpty) {
        principalMessengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Debe ingresar al menos un monto.')));
        return;
      }

      // Aquí se ejecuta la lógica de descuento de insumos y registro de venta
      await widget.onConfirm(pagos: pagos, fechaVenta: _fechaVenta);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      principalMessengerKey.currentState?.showSnackBar(
        SnackBar(
            content:
                Text('Error al registrar la venta o descontar insumos: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _unfocusAll,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header con gradiente azul moderno (consistente con panel_carrito)
            Container(
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.payment_rounded,
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
                              const Text(
                                'Procesar Pago',
                                style: TextStyle(
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
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            iconSize: 20,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Total en card blanco moderno
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total a Pagar',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_method == MetodoDePago.izipayCard) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Incluye 5% tarjeta',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'S/ ${_totalAPagar.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF1E40AF),
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Contenido scrolleable moderno
            Expanded(
              child: Container(
                color: const Color(0xFFF1F5F9),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Métodos de pago
                    _buildPaymentMethodsSection(),

                    const SizedBox(height: 20),

                    // Campos según método
                    ..._buildFieldsByMethod(),

                    const SizedBox(height: 20),

                    // Selector de fecha y hora
                    _buildDateTimePicker(),

                    const SizedBox(height: 20),

                    // Botón de confirmar moderno
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: FilledButton.icon(
                        onPressed: _confirm,
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: const Text('Confirmar y Guardar'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: const Color(0xFF1E40AF).withOpacity(0.3),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(
                        height: MediaQuery.of(context).viewInsets.bottom + 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NUEVO: Widget completo para los selectores de fecha y hora.
  Widget _buildDateTimePicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available_rounded,
                size: 20,
                color: Color(0xFF1E40AF),
              ),
              const SizedBox(width: 8),
              Text(
                'Fecha y Hora de Venta',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    DateFormat.yMMMd('es_ES').format(_fechaVenta),
                    style: const TextStyle(fontSize: 13),
                  ),
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _fechaVenta,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _fechaVenta = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          _fechaVenta.hour,
                          _fechaVenta.minute,
                        );
                      });
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time_outlined, size: 18),
                  label: Text(
                    DateFormat.jm('es_ES').format(_fechaVenta),
                    style: const TextStyle(fontSize: 13),
                  ),
                  onPressed: () async {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_fechaVenta),
                    );
                    if (pickedTime != null) {
                      setState(() {
                        _fechaVenta = DateTime(
                          _fechaVenta.year,
                          _fechaVenta.month,
                          _fechaVenta.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Método de Pago',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: MetodoDePago.values.map((method) {
                final isSelected = _method == method;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () => _onMethodChanged(method),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 75,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            method.icon,
                            size: 28,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            method.displayName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.2,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, {Color? borderColor}) {
    return InputDecoration(
      labelText: label,
      prefixText: 'S/ ',
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: borderColor ?? const Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: borderColor ?? const Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
    );
  }

  List<Widget> _buildFieldsByMethod() {
    switch (_method) {
      case MetodoDePago.cash:
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.money_rounded,
                      size: 20,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pago en Efectivo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cashCtl,
                  focusNode: _fnCash,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDeco('Monto recibido',
                      borderColor: Colors.green.shade300),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _CashChangePreview(
                    subtotal: _subtotal, received: _parse(_cashCtl)),
              ],
            ),
          ),
        ];

      case MetodoDePago.izipayCard:
        final totalConFee = _cardWithFee(_subtotal);
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.credit_card_rounded,
                      size: 20,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pago con Tarjeta',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Subtotal: S/ ${_subtotal.toStringAsFixed(2)} + 5% = S/ ${totalConFee.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cardCtl,
                  focusNode: _fnCard,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDeco('Monto a cobrar',
                      borderColor: Colors.blue.shade300),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ];

      case MetodoDePago.izipayYape:
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      size: 20,
                      color: Colors.purple.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'IziPay Yape',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _izipayYapeCtl,
                  focusNode: _fnIziYape,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDeco('Monto por IziPay Yape',
                      borderColor: Colors.purple.shade300),
                ),
              ],
            ),
          ),
        ];

      case MetodoDePago.yapePersonal:
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.phone_android_rounded,
                      size: 20,
                      color: Colors.purple.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Yape Personal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _yapePersonalCtl,
                  focusNode: _fnYapePers,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDeco('Monto por Yape personal',
                      borderColor: Colors.purple.shade300),
                ),
              ],
            ),
          ),
        ];

      case MetodoDePago.split:
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.call_split_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Asigna método por ítem',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _QuickGrid(
                  selectedMethod: _quickSelected,
                  onAllCash: () {
                    setState(() {
                      if (_splitByTotal) {
                        _stCashCtl.text = widget.subtotal.toStringAsFixed(2);
                        _stCardCtl.clear();
                        _stIziCtl.clear();
                        _stYapeCtl.clear();
                        FocusScope.of(context).requestFocus(_stCashFn);
                        _stCashCtl.selection = TextSelection(baseOffset: 0, extentOffset: _stCashCtl.text.length);
                      } else {
                        for (final it in widget.items) {
                          _splitsByItem[it.uniqueId] = {
                            MetodoDePago.cash: it.precioEditable
                          };
                        }
                      }
                      _quickSelected = MetodoDePago.cash;
                    });
                  },
                  onAllCard: () {
                    setState(() {
                      if (_splitByTotal) {
                        _stCardCtl.text = widget.subtotal.toStringAsFixed(2);
                        _stCashCtl.clear();
                        _stIziCtl.clear();
                        _stYapeCtl.clear();
                        FocusScope.of(context).requestFocus(_stCardFn);
                        _stCardCtl.selection = TextSelection(baseOffset: 0, extentOffset: _stCardCtl.text.length);
                      } else {
                        for (final it in widget.items) {
                          _splitsByItem[it.uniqueId] = {
                            MetodoDePago.izipayCard: it.precioEditable
                          };
                        }
                      }
                      _quickSelected = MetodoDePago.izipayCard;
                    });
                  },
                  onAllIziYape: () {
                    setState(() {
                      if (_splitByTotal) {
                        _stIziCtl.text = widget.subtotal.toStringAsFixed(2);
                        _stCashCtl.clear();
                        _stCardCtl.clear();
                        _stYapeCtl.clear();
                        FocusScope.of(context).requestFocus(_stIziFn);
                        _stIziCtl.selection = TextSelection(baseOffset: 0, extentOffset: _stIziCtl.text.length);
                      } else {
                        for (final it in widget.items) {
                          _splitsByItem[it.uniqueId] = {
                            MetodoDePago.izipayYape: it.precioEditable
                          };
                        }
                      }
                      _quickSelected = MetodoDePago.izipayYape;
                    });
                  },
                  onAllYapePers: () {
                    setState(() {
                      if (_splitByTotal) {
                        _stYapeCtl.text = widget.subtotal.toStringAsFixed(2);
                        _stCashCtl.clear();
                        _stCardCtl.clear();
                        _stIziCtl.clear();
                        FocusScope.of(context).requestFocus(_stYapeFn);
                        _stYapeCtl.selection = TextSelection(baseOffset: 0, extentOffset: _stYapeCtl.text.length);
                      } else {
                        for (final it in widget.items) {
                          _splitsByItem[it.uniqueId] = {
                            MetodoDePago.yapePersonal: it.precioEditable
                          };
                        }
                      }
                      _quickSelected = MetodoDePago.yapePersonal;
                    });
                  },
                ),
                const SizedBox(height: 8),
                // Toggle entre Por ítem y Por total
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Por ítem'),
                      selected: !_splitByTotal,
                      onSelected: (v) => setState(() => _splitByTotal = !v ? true : false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Por total'),
                      selected: _splitByTotal,
                      onSelected: (v) => setState(() => _splitByTotal = v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_splitByTotal)
                  _buildTotalSplitEditor()
                else
                  ...widget.items.map((it) {
                  final splits = _splitsByItem[it.uniqueId] ?? {};
                  MetodoDePago? mainMet;
                  if (splits.length == 1) {
                    mainMet = splits.keys.first;
                  } else if (splits.isNotEmpty) {
                    mainMet = splits.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
                  }
                  final isMixed = splits.length > 1;
                  final disp = isMixed
                      ? _methodDisplay(MetodoDePago.split)
                      : _methodDisplay(mainMet ?? MetodoDePago.cash);
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CategoryPill(category: it.categoryName),
                              const SizedBox(height: 6),
                              Text(
                                it.producto.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'S/ ${it.precioEditable.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Color(0xFF1E40AF),
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () async {
                            final edited = await _editItemSplit(it);
                            if (edited != null) {
                              setState(() {
                                _splitsByItem[it.uniqueId] = edited;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: disp.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: disp.color.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(isMixed ? Icons.call_split_rounded : disp.icon, size: 16, color: disp.color),
                                const SizedBox(width: 6),
                                Text(
                                  isMixed ? 'Mixto' : disp.label,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: disp.color,
                                      fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.expand_more, size: 16, color: Color(0xFF6B7280)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 12),
                _buildSplitSummary(),
              ],
            ),
          ),
        ];
    }
  }

  // NUEVO: abrir editor de montos por ítem
  Future<Map<MetodoDePago, double>?> _editItemSplit(ItemCarrito it) async {
    final current = _splitsByItem[it.uniqueId] ?? {};
    return showModalBottomSheet<Map<MetodoDePago, double>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditItemSplitSheet(item: it, initial: current),
    );
  }

  

  Widget _buildSplitSummary() {
    final totals = _currentSplitTotals();
    final cash = totals[MetodoDePago.cash] ?? 0.0;
    final cardBase = totals[MetodoDePago.izipayCard] ?? 0.0;
    final card = _cardWithFee(cardBase);
    final izi = totals[MetodoDePago.izipayYape] ?? 0.0;
    final yape = totals[MetodoDePago.yapePersonal] ?? 0.0;

    Widget tile(String title, double amount, Color color, IconData icon,
        {String? subtitle}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(title,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
              const SizedBox(height: 6),
              Text('S/ ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E40AF))),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Resumen por método',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            tile('Efectivo', cash, Colors.green.shade700,
                Icons.money_outlined),
            const SizedBox(width: 8),
            tile('Tarjeta', card, Colors.blue.shade700,
                Icons.credit_card_outlined,
                subtitle: '+5% sobre S/ ${cardBase.toStringAsFixed(2)}'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            tile('IziPay Yape', izi, Colors.purple.shade700,
                Icons.qr_code_2_outlined),
            const SizedBox(width: 8),
            tile('Yape Pers.', yape, Colors.purple.shade800,
                Icons.phone_android_outlined),
          ],
        ),
      ],
    );
  }

  // Editor de división por total
  Widget _buildTotalSplitEditor() {
    double p(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0;
    final sum = p(_stCashCtl) + p(_stCardCtl) + p(_stIziCtl) + p(_stYapeCtl);
    final restante = (widget.subtotal - sum);
    final ok = restante.abs() <= 0.01 && sum > 0.0;

    InputDecoration deco(String label, Color color) => InputDecoration(
          labelText: label,
          prefixText: 'S/ ',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: color, width: 2),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 3.4,
                ),
                children: [
                  TextField(
                    controller: _stCashCtl,
                    focusNode: _stCashFn,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: deco('Efectivo', Colors.green.shade700),
                    onChanged: (_) => setState(() {}),
                    onTap: () {
                      _stCashCtl.selection = TextSelection(baseOffset: 0, extentOffset: _stCashCtl.text.length);
                    },
                  ),
                  TextField(
                    controller: _stCardCtl,
                    focusNode: _stCardFn,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: deco('Tarjeta (base)', Colors.blue.shade700),
                    onChanged: (_) => setState(() {}),
                    onTap: () {
                      _stCardCtl.selection = TextSelection(baseOffset: 0, extentOffset: _stCardCtl.text.length);
                    },
                  ),
                  TextField(
                    controller: _stIziCtl,
                    focusNode: _stIziFn,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: deco('IziPay Yape', Colors.purple.shade700),
                    onChanged: (_) => setState(() {}),
                    onTap: () {
                      _stIziCtl.selection = TextSelection(baseOffset: 0, extentOffset: _stIziCtl.text.length);
                    },
                  ),
                  TextField(
                    controller: _stYapeCtl,
                    focusNode: _stYapeFn,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: deco('Yape Pers.', Colors.purple.shade900),
                    onChanged: (_) => setState(() {}),
                    onTap: () {
                      _stYapeCtl.selection = TextSelection(baseOffset: 0, extentOffset: _stYapeCtl.text.length);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (restante > 0.01) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Completar restante en:',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _QuickActionChip(
                      icon: Icons.payments_rounded,
                      label: 'Efectivo',
                      color: Colors.green.shade700,
                      onTap: () => setState(() {
                        final v = (p(_stCashCtl) + restante).toStringAsFixed(2);
                        _stCashCtl.text = v;
                        FocusScope.of(context).requestFocus(_stCashFn);
                        _stCashCtl.selection = TextSelection(baseOffset: 0, extentOffset: v.length);
                      }),
                    ),
                    _QuickActionChip(
                      icon: Icons.credit_card_outlined,
                      label: 'Tarjeta',
                      color: Colors.blue.shade700,
                      onTap: () => setState(() {
                        final v = (p(_stCardCtl) + restante).toStringAsFixed(2);
                        _stCardCtl.text = v;
                        FocusScope.of(context).requestFocus(_stCardFn);
                        _stCardCtl.selection = TextSelection(baseOffset: 0, extentOffset: v.length);
                      }),
                    ),
                    _QuickActionChip(
                      icon: Icons.qr_code_2_outlined,
                      label: 'IziYape',
                      color: Colors.purple.shade700,
                      onTap: () => setState(() {
                        final v = (p(_stIziCtl) + restante).toStringAsFixed(2);
                        _stIziCtl.text = v;
                        FocusScope.of(context).requestFocus(_stIziFn);
                        _stIziCtl.selection = TextSelection(baseOffset: 0, extentOffset: v.length);
                      }),
                    ),
                    _QuickActionChip(
                      icon: Icons.phone_android_outlined,
                      label: 'Yape Pers.',
                      color: Colors.purple.shade900,
                      onTap: () => setState(() {
                        final v = (p(_stYapeCtl) + restante).toStringAsFixed(2);
                        _stYapeCtl.text = v;
                        FocusScope.of(context).requestFocus(_stYapeFn);
                        _stYapeCtl.selection = TextSelection(baseOffset: 0, extentOffset: v.length);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: restante < -0.01
                      ? Colors.red.shade50
                      : (ok ? Colors.green.shade50 : Colors.amber.shade50),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: restante < -0.01
                        ? Colors.red.shade200
                        : (ok ? Colors.green.shade200 : Colors.amber.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      restante < -0.01
                          ? Icons.error_outline
                          : (ok ? Icons.check_circle_outline : Icons.info_outline),
                      color: restante < -0.01
                          ? Colors.red.shade700
                          : (ok ? Colors.green.shade700 : Colors.amber.shade700),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        restante < -0.01
                            ? 'Te pasaste por S/ ${(-restante).toStringAsFixed(2)}'
                            : 'Restante: S/ ${restante.clamp(0, 1e9).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: restante < -0.01
                              ? Colors.red.shade900
                              : (ok ? Colors.green.shade900 : Colors.amber.shade900),
                          fontWeight: FontWeight.w600,
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
    );
  }
}

class _MethodDisp {
  final String label;
  final IconData icon;
  final Color color;
  const _MethodDisp(this.label, this.icon, this.color);
}

class _CategoryPill extends StatelessWidget {
  final String category;
  const _CategoryPill({required this.category});

  Color _categoryColor(String c) {
    final name = c.toLowerCase();
    if (name.contains('pollo')) return Colors.amber.shade700;
    if (name.contains('carne')) return Colors.red.shade600;
    if (name.contains('mixto')) return Colors.blue.shade600;
    if (name.contains('veget')) return Colors.green.shade700;
    if (name.contains('oxa')) return Colors.indigo.shade600;
    return const Color(0xFF475569); // slate
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        category,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ModernSheet extends StatelessWidget {
  final Widget child;
  const _ModernSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

class _CashChangePreview extends StatelessWidget {
  final double subtotal;
  final double received;
  const _CashChangePreview({required this.subtotal, required this.received});

  @override
  Widget build(BuildContext context) {
    final change = (received - subtotal) > 0 ? (received - subtotal) : 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade50,
            Colors.green.shade100,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money_rounded,
                  size: 20, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'Vuelto:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
          Text(
            'S/ ${change.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickGrid extends StatelessWidget {
  final MetodoDePago? selectedMethod;
  final VoidCallback onAllCash;
  final VoidCallback onAllCard;
  final VoidCallback onAllIziYape;
  final VoidCallback onAllYapePers;
  const _QuickGrid({
    required this.selectedMethod,
    required this.onAllCash,
    required this.onAllCard,
    required this.onAllIziYape,
    required this.onAllYapePers,
  });

  @override
  Widget build(BuildContext context) {
    Widget btn({
      required IconData icon,
      required Color color,
      required String tooltip,
      required VoidCallback onTap,
      required bool selected,
    }) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? color.withOpacity(0.08) : Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? color : color.withOpacity(0.4), width: selected ? 2 : 1),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
          ),
        ),
      );
    }

    return GridView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.6,
      ),
      children: [
        btn(icon: Icons.payments_rounded, color: Colors.green, tooltip: 'Todo a Efectivo', onTap: onAllCash, selected: selectedMethod == MetodoDePago.cash),
        btn(icon: Icons.credit_card_outlined, color: Colors.blue, tooltip: 'Todo a Tarjeta', onTap: onAllCard, selected: selectedMethod == MetodoDePago.izipayCard),
        btn(icon: Icons.qr_code_2_outlined, color: Colors.purple, tooltip: 'Todo a IziYape', onTap: onAllIziYape, selected: selectedMethod == MetodoDePago.izipayYape),
        btn(icon: Icons.phone_android_outlined, color: Colors.purple.shade900, tooltip: 'Todo a Yape Pers.', onTap: onAllYapePers, selected: selectedMethod == MetodoDePago.yapePersonal),
      ],
    );
  }
}

// NUEVO: Sheet para editar montos parciales de un ítem entre métodos de pago
class _EditItemSplitSheet extends StatefulWidget {
  final ItemCarrito item;
  final Map<MetodoDePago, double> initial;
  const _EditItemSplitSheet({required this.item, required this.initial});

  @override
  State<_EditItemSplitSheet> createState() => _EditItemSplitSheetState();
}

class _EditItemSplitSheetState extends State<_EditItemSplitSheet> {
  late final TextEditingController _efecCtl;
  late final TextEditingController _cardCtl;
  late final TextEditingController _iziCtl;
  late final TextEditingController _yapeCtl;
  final _fnEfec = FocusNode();
  final _fnCard = FocusNode();
  final _fnIzi = FocusNode();
  final _fnYape = FocusNode();

  @override
  void initState() {
    super.initState();
    double v(MetodoDePago m) => (widget.initial[m] ?? 0.0);
    String f(double d) => d > 0 ? d.toStringAsFixed(2) : '';
    _efecCtl = TextEditingController(text: f(v(MetodoDePago.cash)));
    _cardCtl = TextEditingController(text: f(v(MetodoDePago.izipayCard)));
    _iziCtl = TextEditingController(text: f(v(MetodoDePago.izipayYape)));
    _yapeCtl = TextEditingController(text: f(v(MetodoDePago.yapePersonal)));
  }

  @override
  void dispose() {
    _fnEfec.dispose();
    _fnCard.dispose();
    _fnIzi.dispose();
    _fnYape.dispose();
    _efecCtl.dispose();
    _cardCtl.dispose();
    _iziCtl.dispose();
    _yapeCtl.dispose();
    super.dispose();
  }

  double _p(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0;

  double get _sum => _p(_efecCtl) + _p(_cardCtl) + _p(_iziCtl) + _p(_yapeCtl);
  double get _price => widget.item.precioEditable;

  InputDecoration _dec(String label, Color color) => InputDecoration(
        labelText: label,
        prefixText: 'S/ ',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
      );

  void _setAllTo(MetodoDePago m) {
    setState(() {
      _efecCtl.text = m == MetodoDePago.cash ? _price.toStringAsFixed(2) : '';
      _cardCtl.text = m == MetodoDePago.izipayCard ? _price.toStringAsFixed(2) : '';
      _iziCtl.text = m == MetodoDePago.izipayYape ? _price.toStringAsFixed(2) : '';
      _yapeCtl.text = m == MetodoDePago.yapePersonal ? _price.toStringAsFixed(2) : '';
    });
  }

  void _clearAll() {
    setState(() {
      _efecCtl.clear();
      _cardCtl.clear();
      _iziCtl.clear();
      _yapeCtl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final restante = (_price - _sum);
    final ok = restante.abs() <= 0.01 && _sum > 0;
    return _ModernSheet(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Montos para ${widget.item.producto.nombre}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text('Precio: S/ ${_price.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3.4,
              ),
              children: [
                TextField(
                  controller: _efecCtl,
                  focusNode: _fnEfec,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('Efectivo', Colors.green.shade700),
                  onChanged: (_) => setState(() {}),
                  onTap: () {
                    _efecCtl.selection = TextSelection(baseOffset: 0, extentOffset: _efecCtl.text.length);
                  },
                ),
                TextField(
                  controller: _cardCtl,
                  focusNode: _fnCard,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('Tarjeta (base)', Colors.blue.shade700),
                  onChanged: (_) => setState(() {}),
                  onTap: () {
                    _cardCtl.selection = TextSelection(baseOffset: 0, extentOffset: _cardCtl.text.length);
                  },
                ),
                TextField(
                  controller: _iziCtl,
                  focusNode: _fnIzi,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('IziPay Yape', Colors.purple.shade700),
                  onChanged: (_) => setState(() {}),
                  onTap: () {
                    _iziCtl.selection = TextSelection(baseOffset: 0, extentOffset: _iziCtl.text.length);
                  },
                ),
                TextField(
                  controller: _yapeCtl,
                  focusNode: _fnYape,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('Yape Pers.', Colors.purple.shade900),
                  onChanged: (_) => setState(() {}),
                  onTap: () {
                    _yapeCtl.selection = TextSelection(baseOffset: 0, extentOffset: _yapeCtl.text.length);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _QuickActionChip(
                  icon: Icons.payments_rounded,
                  label: 'Todo Efectivo',
                  color: Colors.green.shade700,
                  onTap: () => _setAllTo(MetodoDePago.cash),
                ),
                const SizedBox(width: 8),
                _QuickActionChip(
                  icon: Icons.credit_card_outlined,
                  label: 'Todo Tarjeta',
                  color: Colors.blue.shade700,
                  onTap: () => _setAllTo(MetodoDePago.izipayCard),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _QuickActionChip(
                  icon: Icons.qr_code_2_outlined,
                  label: 'Todo IziYape',
                  color: Colors.purple.shade700,
                  onTap: () => _setAllTo(MetodoDePago.izipayYape),
                ),
                const SizedBox(width: 8),
                _QuickActionChip(
                  icon: Icons.phone_android_outlined,
                  label: 'Todo Yape Pers.',
                  color: Colors.purple.shade900,
                  onTap: () => _setAllTo(MetodoDePago.yapePersonal),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearAll,
                  child: const Text('Limpiar'),
                ),
              ],
            ),
            if (restante > 0.01) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Completar restante en:',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _QuickActionChip(
                    icon: Icons.payments_rounded,
                    label: 'Efectivo',
                    color: Colors.green.shade700,
                    onTap: () => setState(() {
                      final v = (_p(_efecCtl) + restante).toStringAsFixed(2);
                      _efecCtl.text = v;
                      _efecCtl.selection = TextSelection(baseOffset: 0, extentOffset: v.length);
                    }),
                  ),
                  _QuickActionChip(
                    icon: Icons.credit_card_outlined,
                    label: 'Tarjeta',
                    color: Colors.blue.shade700,
                    onTap: () => setState(() {
                      final v = (_p(_cardCtl) + restante).toStringAsFixed(2);
                      _cardCtl.text = v;
                      _cardCtl.selection = TextSelection(baseOffset: 0, extentOffset: v.length);
                    }),
                  ),
                  _QuickActionChip(
                    icon: Icons.qr_code_2_outlined,
                    label: 'IziYape',
                    color: Colors.purple.shade700,
                    onTap: () => setState(() {
                      final v = (_p(_iziCtl) + restante).toStringAsFixed(2);
                      _iziCtl.text = v;
                      _iziCtl.selection = TextSelection(baseOffset: 0, extentOffset: v.length);
                    }),
                  ),
                  _QuickActionChip(
                    icon: Icons.phone_android_outlined,
                    label: 'Yape Pers.',
                    color: Colors.purple.shade900,
                    onTap: () => setState(() {
                      final v = (_p(_yapeCtl) + restante).toStringAsFixed(2);
                      _yapeCtl.text = v;
                      _yapeCtl.selection = TextSelection(baseOffset: 0, extentOffset: v.length);
                    }),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: restante < -0.01
                    ? Colors.red.shade50
                    : (ok ? Colors.green.shade50 : Colors.amber.shade50),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: restante < -0.01
                      ? Colors.red.shade200
                      : (ok ? Colors.green.shade200 : Colors.amber.shade200),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    restante < -0.01
                        ? Icons.error_outline
                        : (ok ? Icons.check_circle_outline : Icons.info_outline),
                    color: restante < -0.01
                        ? Colors.red.shade700
                        : (ok ? Colors.green.shade700 : Colors.amber.shade700),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      restante < -0.01
                          ? 'Te pasaste por S/ ${(-restante).toStringAsFixed(2)}'
                          : 'Restante: S/ ${restante.clamp(0, 1e9).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: restante < -0.01
                            ? Colors.red.shade900
                            : (ok ? Colors.green.shade900 : Colors.amber.shade900),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: ok
                        ? () {
                            final map = <MetodoDePago, double>{};
                            void put(MetodoDePago m, TextEditingController c) {
                              final v = _p(c);
                              if (v > 0.0001) map[m] = double.parse(v.toStringAsFixed(2));
                            }
                            put(MetodoDePago.cash, _efecCtl);
                            put(MetodoDePago.izipayCard, _cardCtl);
                            put(MetodoDePago.izipayYape, _iziCtl);
                            put(MetodoDePago.yapePersonal, _yapeCtl);
                            Navigator.of(context).pop(map);
                          }
                        : null,
                    icon: const Icon(Icons.save_alt_rounded, size: 18),
                    label: const Text('Guardar'),
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

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

