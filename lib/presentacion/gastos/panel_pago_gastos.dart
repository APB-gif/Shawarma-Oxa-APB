// lib/presentacion/gastos/panel_pago_gastos.dart
//
// Ajuste: no cambia UI, pero esto se usa desde PaginaGastos
// que ahora delega el guardado a ServicioGastos con soporte offline solo-admin.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:shawarma_pos_nuevo/datos/modelos/pago.dart';
import 'package:shawarma_pos_nuevo/presentacion/gastos/panel_gastos.dart';

class PanelPagoGastos extends StatefulWidget {
  final double totalGasto;
  final List<ItemGasto> items;

  /// Devuelve el método y la fecha elegida
  final void Function(PaymentMethod method, DateTime date) onConfirm;

  const PanelPagoGastos({
    super.key,
    required this.totalGasto,
    required this.items,
    required this.onConfirm,
  });

  @override
  State<PanelPagoGastos> createState() => _PanelPagoGastosState();
}

class _PanelPagoGastosState extends State<PanelPagoGastos> {
  PaymentMethod _method = PaymentMethod.cash;
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = DateTime.now();
  }

  void _onMethodChanged(Set<PaymentMethod> newSelection) {
    setState(() => _method = newSelection.first);
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(now.year - 5),
      lastDate: now, // no futuro
    );
    if (pickedDate == null) return;

    final TimeOfDay? pickedTime =
        await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_selectedDateTime));
    if (pickedTime == null) return;

    setState(() {
      _selectedDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Registrar Pago de Gasto', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'S/ ${widget.totalGasto.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildDateTimePicker(),
          const SizedBox(height: 16),
          const Text('Seleccionar método de pago:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildPaymentMethodSelector(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => widget.onConfirm(_method, _selectedDateTime),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirmar Gasto'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                backgroundColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: _pickDateTime,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, color: Colors.grey),
              const SizedBox(width: 12),
              const Expanded(child: Text('Fecha y Hora del Gasto')),
              Text(
                DateFormat('dd/MM/yy HH:mm').format(_selectedDateTime),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    final List<PaymentMethod> paymentOptions = [
      PaymentMethod.cash,
      PaymentMethod.izipayCard,
      PaymentMethod.yapePersonal,
    ];

    return SegmentedButton<PaymentMethod>(
      style: SegmentedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
      segments: paymentOptions
          .map((method) => ButtonSegment<PaymentMethod>(
                value: method,
                icon: Icon(method.icon, size: 20),
                label: Text(method.displayName),
              ))
          .toList(),
      selected: <PaymentMethod>{_method},
      onSelectionChanged: _onMethodChanged,
      showSelectedIcon: false,
      multiSelectionEnabled: false,
    );
  }
}
