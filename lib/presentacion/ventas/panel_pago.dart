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
      if (mounted) _onMethodChanged(_method);
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

  void _selectAll(TextEditingController c, FocusNode fn) {
    fn.requestFocus();
    c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
  }

  void _setTextsForMethod(MetodoDePago m) {
    _clearAllInputs();
    switch (m) {
      case MetodoDePago.cash:
        _cashCtl.text = _subtotal.toStringAsFixed(2);
        _selectAll(_cashCtl, _fnCash);
        break;
      case MetodoDePago.izipayCard:
        _cardCtl.text = _cardWithFee(_subtotal).toStringAsFixed(2);
        _selectAll(_cardCtl, _fnCard);
        break;
      case MetodoDePago.izipayYape:
        _izipayYapeCtl.text = _subtotal.toStringAsFixed(2);
        _selectAll(_izipayYapeCtl, _fnIziYape);
        break;
      case MetodoDePago.yapePersonal:
        _yapePersonalCtl.text = _subtotal.toStringAsFixed(2);
        _selectAll(_yapePersonalCtl, _fnYapePers);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _unfocusAll();
    });
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
          final cashAmount = _parse(_cashCtl);
          final cardAmount = _parse(_cardCtl);
          final iziYapeAmount = _parse(_izipayYapeCtl);
          final yapePersAmount = _parse(_yapePersonalCtl);

          if (cashAmount > 0) pagos['Efectivo'] = cashAmount;
          if (cardAmount > 0) pagos['Tarjeta'] = cardAmount;
          if (iziYapeAmount > 0) pagos['IziPay Yape'] = iziYapeAmount;
          if (yapePersAmount > 0) pagos['Yape Personal'] = yapePersAmount;

          final sumAmounts =
              cashAmount + cardAmount + iziYapeAmount + yapePersAmount;

          if (sumAmounts + 1e-6 < _subtotal) {
            principalMessengerKey.currentState?.showSnackBar(const SnackBar(
                content: Text('La suma de montos no cubre el subtotal')));
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
            // Header con gradiente
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF059669),
                    Color(0xFF047857),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.payment_rounded,
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
                                'Procesar Pago',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.items.length} ${widget.items.length == 1 ? 'producto' : 'productos'}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Total en card blanco
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_method == MetodoDePago.izipayCard) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Incluye 5% tarjeta',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'S/ ${_totalAPagar.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF059669),
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
            
            // Contenido scrolleable
            Expanded(
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
                  
                  // Botón de confirmar
                  FilledButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text('Confirmar y Guardar'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
                ],
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
                color: Color(0xFF059669),
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
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDeco('Monto recibido', borderColor: Colors.green.shade300),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _CashChangePreview(subtotal: _subtotal, received: _parse(_cashCtl)),
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
                      Icon(Icons.info_outline_rounded, size: 18, color: Colors.orange.shade700),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDeco('Monto a cobrar', borderColor: Colors.blue.shade300),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDeco('Monto por IziPay Yape', borderColor: Colors.purple.shade300),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDeco('Monto por Yape personal', borderColor: Colors.purple.shade300),
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
                      'Pago Dividido',
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
                  decoration: _inputDeco('Parte en efectivo', borderColor: Colors.green.shade300),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cardCtl,
                  decoration: _inputDeco('Parte por tarjeta (+5%)', borderColor: Colors.blue.shade300),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _izipayYapeCtl,
                  decoration: _inputDeco('Parte por IziPay Yape', borderColor: Colors.purple.shade300),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _yapePersonalCtl,
                  decoration: _inputDeco('Parte por Yape personal', borderColor: Colors.purple.shade300),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ];
    }
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
              Icon(Icons.attach_money_rounded, size: 20, color: Colors.green.shade700),
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
