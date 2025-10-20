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

  // Asignación por ítem cuando el método es split
  // item.uniqueId -> método de pago seleccionado
  final Map<String, MetodoDePago> _paymentByItem = {};
  // Última acción rápida aplicada (para resaltar el ícono seleccionado)
  MetodoDePago? _quickSelected;

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

  Future<MetodoDePago?> _pickMethodForItem(ItemCarrito it) async {
    return showModalBottomSheet<MetodoDePago>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ModernSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Método para ${it.producto.nombre}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              GridView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.8,
                ),
                children: [
                  for (final m in MetodoDePago.values.where((m) => m != MetodoDePago.split))
                    _MethodTile(
                      disp: _methodDisplay(m),
                      selected: _paymentByItem[it.uniqueId] == m,
                      onTap: () => Navigator.of(ctx).pop(m),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).maybePop(),
                    child: const Text('Cancelar'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
  // NUEVO: Variable de estado para la fecha de la venta
  DateTime _fechaVenta = DateTime.now();

  double get _subtotal => widget.subtotal;
  double _cardWithFee(double base) => base * (1 + _cardFeeRate);
  double _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0;

  double get _totalAPagar {
    if (_method == MetodoDePago.izipayCard) {
      return _cardWithFee(_subtotal);
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
      // Preparar estado inicial para split: sin asignación por defecto
      // (el usuario asignará manualmente). Si quieres, podríamos
      // preasignar a efectivo aquí.
      if (_paymentByItem.isEmpty) {
        for (final it in widget.items) {
          _paymentByItem[it.uniqueId] = MetodoDePago.cash; // opcional: efectivo por defecto
        }
        setState(() {});
      }
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

  double _sumFor(MetodoDePago m) {
    double sum = 0.0;
    for (final it in widget.items) {
      if (_paymentByItem[it.uniqueId] == m) sum += it.precioEditable;
    }
    return sum;
  }

  Map<MetodoDePago, double> _buildSplitTotals() {
    final totals = <MetodoDePago, double>{
      MetodoDePago.cash: _sumFor(MetodoDePago.cash),
      MetodoDePago.izipayCard: _sumFor(MetodoDePago.izipayCard),
      MetodoDePago.izipayYape: _sumFor(MetodoDePago.izipayYape),
      MetodoDePago.yapePersonal: _sumFor(MetodoDePago.yapePersonal),
    };
    return totals;
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
          // Construir totales por método desde la asignación por ítem
          final totals = _buildSplitTotals();
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
                content: Text('Faltan ítems por asignar a un método de pago.')));
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
                      for (final it in widget.items) {
                        _paymentByItem[it.uniqueId] = MetodoDePago.cash;
                      }
                      _quickSelected = MetodoDePago.cash;
                    });
                  },
                  onAllCard: () {
                    setState(() {
                      for (final it in widget.items) {
                        _paymentByItem[it.uniqueId] = MetodoDePago.izipayCard;
                      }
                      _quickSelected = MetodoDePago.izipayCard;
                    });
                  },
                  onAllIziYape: () {
                    setState(() {
                      for (final it in widget.items) {
                        _paymentByItem[it.uniqueId] = MetodoDePago.izipayYape;
                      }
                      _quickSelected = MetodoDePago.izipayYape;
                    });
                  },
                  onAllYapePers: () {
                    setState(() {
                      for (final it in widget.items) {
                        _paymentByItem[it.uniqueId] = MetodoDePago.yapePersonal;
                      }
                      _quickSelected = MetodoDePago.yapePersonal;
                    });
                  },
                ),
                const SizedBox(height: 8),
                ...widget.items.map((it) {
                  final selected = _paymentByItem[it.uniqueId] ?? MetodoDePago.cash;
                  final disp = _methodDisplay(selected);
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
                            final sel = await _pickMethodForItem(it);
                            if (sel != null) setState(() => _paymentByItem[it.uniqueId] = sel);
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
                                Icon(disp.icon, size: 16, color: disp.color),
                                const SizedBox(width: 6),
                                Text(
                                  disp.label,
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

  

  Widget _buildSplitSummary() {
    final totals = _buildSplitTotals();
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
}

class _MethodDisp {
  final String label;
  final IconData icon;
  final Color color;
  const _MethodDisp(this.label, this.icon, this.color);
}

class _MethodTile extends StatelessWidget {
  final _MethodDisp disp;
  final bool selected;
  final VoidCallback onTap;
  const _MethodTile({required this.disp, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? disp.color.withOpacity(0.12) : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? disp.color : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(disp.icon, color: disp.color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  disp.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: disp.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
