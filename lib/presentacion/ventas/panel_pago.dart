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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView(
          children: [
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text('Pagar',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('S/ ${_totalAPagar.toStringAsFixed(2)}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildMobilePaymentMethods(),
            const SizedBox(height: 24),
            ..._buildFieldsByMethod(),
            const SizedBox(height: 24),
            // NUEVO: Widget para seleccionar fecha y hora de la venta
            _buildDateTimePicker(),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _confirm,
              icon: Icon(_method.icon),
              label: const Text('Confirmar y guardar'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  )),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 24),
          ],
        ),
      ),
    );
  }

  // NUEVO: Widget completo para los selectores de fecha y hora.
  Widget _buildDateTimePicker() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            label: Text(DateFormat.yMMMd('es_ES').format(_fechaVenta)),
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
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.access_time_outlined, size: 20),
            label: Text(DateFormat.jm('es_ES').format(_fechaVenta)),
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
          ),
        ),
      ],
    );
  }

  Widget _buildMobilePaymentMethods() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: MetodoDePago.values.map((method) {
          final isSelected = _method == method;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: InkWell(
              onTap: () => _onMethodChanged(method),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 70,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2)
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      method.icon,
                      size: 28,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      method.displayName.replaceAll(' ', '\n'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      prefixText: 'S/ ',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
    );
  }

  List<Widget> _buildFieldsByMethod() {
    switch (_method) {
      case MetodoDePago.cash:
        return [
          TextField(
            controller: _cashCtl,
            focusNode: _fnCash,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDeco('Monto recibido (efectivo)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _CashChangePreview(subtotal: _subtotal, received: _parse(_cashCtl)),
        ];

      case MetodoDePago.izipayCard:
        final totalConFee = _cardWithFee(_subtotal);
        return [
          Text(
            'Subtotal: S/ ${_subtotal.toStringAsFixed(2)} + 5% = S/ ${totalConFee.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cardCtl,
            focusNode: _fnCard,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDeco('Monto a cobrar por tarjeta'),
            onChanged: (_) => setState(() {}),
          ),
        ];

      case MetodoDePago.izipayYape:
        return [
          TextField(
            controller: _izipayYapeCtl,
            focusNode: _fnIziYape,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDeco('Monto por IziPay Yape'),
          ),
        ];

      case MetodoDePago.yapePersonal:
        return [
          TextField(
            controller: _yapePersonalCtl,
            focusNode: _fnYapePers,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDeco('Monto por Yape personal'),
          ),
        ];

      case MetodoDePago.split:
        return [
          TextField(
            controller: _cashCtl,
            decoration: _inputDeco('Parte en efectivo'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cardCtl,
            decoration: _inputDeco('Parte por tarjeta (+5%)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _izipayYapeCtl,
            decoration: _inputDeco('Parte por IziPay Yape'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _yapePersonalCtl,
            decoration: _inputDeco('Parte por Yape personal'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
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
    return ListTile(
      title: Text('Vuelto:', style: Theme.of(context).textTheme.titleMedium),
      trailing: Text(
        'S/ ${change.toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}
