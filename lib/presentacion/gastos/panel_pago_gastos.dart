// lib/presentacion/gastos/panel_pago_gastos.dart
//
// Ajuste: no cambia UI, pero esto se usa desde PaginaGastos
// que ahora delega el guardado a ServicioGastos con soporte offline solo-admin.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:shawarma_pos_nuevo/datos/modelos/pago.dart';
import 'package:shawarma_pos_nuevo/presentacion/gastos/panel_gastos.dart';

String _metodoKey(PaymentMethod m) {
  switch (m) {
    case PaymentMethod.cash:
      return 'Efectivo';
    case PaymentMethod.izipayCard:
      return 'Ruben';
    case PaymentMethod.yapePersonal:
      return 'Aharhel';
    default:
      return m.displayName;
  }
}

class PanelPagoGastos extends StatefulWidget {
  final double totalGasto;
  final List<ItemGasto> items;

  /// Devuelve un mapa de pagos (clave: nombre método, valor: monto) y la fecha elegida
  final void Function({required Map<String, double> pagos, required DateTime date}) onConfirm;

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
  // Nuevo: switch para dividir pagos
  bool _isSplit = false;
  bool _splitByTotal = true; // true: por total, false: por item

  // Split por total controladores
  final _stCashCtl = TextEditingController();
  final _stCardCtl = TextEditingController();
  final _stYapeCtl = TextEditingController();

  // Split por item: item.uniqueId -> chosen PaymentMethod
  final Map<String, PaymentMethod> _splitItemChoice = {};
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = DateTime.now();
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
    if (!mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime));
    if (pickedTime == null) return;
    if (!mounted) return;

    setState(() {
      _selectedDateTime = DateTime(pickedDate.year, pickedDate.month,
          pickedDate.day, pickedTime.hour, pickedTime.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.payment_rounded,
                        color: theme.colorScheme.onSecondary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confirmar Pago',
                            style: TextStyle(
                              color: theme.colorScheme.onSecondary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.items.length} ${widget.items.length == 1 ? 'producto' : 'productos'}',
                            style: TextStyle(
                              color: theme.colorScheme.onSecondary
                                  .withValues(alpha: 0.9),
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
                const SizedBox(height: 16),
                // Total destacado
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Total:',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'S/ ${widget.totalGasto.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contenido
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + keyboardHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fecha y Hora
                  _buildDateTimePicker(),

                  const SizedBox(height: 20),

                  // Método de pago
                  _buildPaymentMethodSection(),

                  const SizedBox(height: 12),
                  // Opción para dividir método de pago
                  _buildSplitOption(),

                  const SizedBox(height: 24),

                  // Botón confirmar
                  FilledButton.icon(
                    onPressed: () {
                      // Construir el mapa de pagos según modo
                      final pagos = <String, double>{};
                      if (!_isSplit) {
                        pagos[_metodoKey(_method)] = widget.totalGasto;
                      } else {
                        if (_splitByTotal) {
                          double p(TextEditingController c) =>
                              double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0;
                          final cash = p(_stCashCtl);
                          final card = p(_stCardCtl);
                          final yape = p(_stYapeCtl);
                          final assigned = cash + card + yape;
                          if ((assigned - widget.totalGasto).abs() > 0.01) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Los montos no coinciden con el total.')));
                            return;
                          }
                          if (cash > 0) pagos[_metodoKey(PaymentMethod.cash)] = cash;
                          if (card > 0) pagos[_metodoKey(PaymentMethod.izipayCard)] = card;
                          if (yape > 0) pagos[_metodoKey(PaymentMethod.yapePersonal)] = yape;
                        } else {
                          // por item: asignar cada item al método seleccionado
                          final totals = <String, double>{};
                          for (final it in widget.items) {
                            final m = _splitItemChoice[it.uniqueId] ?? PaymentMethod.cash;
                            totals[_metodoKey(m)] = (totals[_metodoKey(m)] ?? 0.0) + it.precioEditable;
                          }
                          pagos.addAll(totals);
                        }
                      }

                      widget.onConfirm(pagos: pagos, date: _selectedDateTime);
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text('Confirmar Gasto'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker() {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _pickDateTime,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fecha y Hora',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM/yyyy • HH:mm')
                            .format(_selectedDateTime),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
              SizedBox(width: 8),
              Text(
                'Método de Pago',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        _buildPaymentMethodSelector(),
      ],
    );
  }

  Widget _buildPaymentMethodSelector() {
    final theme = Theme.of(context);
    final List<PaymentMethod> paymentOptions = [
      PaymentMethod.cash,
      PaymentMethod.izipayCard,
      PaymentMethod.yapePersonal,
    ];

    String displayNameForGastos(PaymentMethod m) {
      switch (m) {
        case PaymentMethod.izipayCard:
          return 'Ruben';
        case PaymentMethod.yapePersonal:
          return 'Aharhel';
        default:
          return m.displayName;
      }
    }

    return Column(
      children: paymentOptions.map((method) {
        final bool disabled = _isSplit; // Cuando está activo dividir, no debe verse ningún método seleccionado
        final isSelected = !disabled && _method == method;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : (disabled ? Colors.grey.shade100 : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : (disabled ? Colors.grey.shade300 : const Color(0xFFE2E8F0)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              // Si está activo "Dividir", deshabilitamos la selección de métodos individuales
              onTap: disabled ? null : () => setState(() => _method = method),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        method.icon,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (disabled ? Colors.grey.shade400 : Colors.grey.shade600),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        displayNameForGastos(method),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (disabled ? Colors.grey.shade500 : const Color(0xFF1E293B)),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      )
                    else
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: disabled ? Colors.grey.shade300 : Colors.grey.shade300,
                            width: 2,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSplitOption() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Botón de dividir método de pago con estilo similar a los métodos de pago
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _isSplit
                ? const Color(0xFF059669).withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isSplit
                  ? const Color(0xFF059669)
                  : const Color(0xFFE2E8F0),
              width: _isSplit ? 2 : 1,
            ),
            boxShadow: [
              if (_isSplit)
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() {
                _isSplit = !_isSplit;
                if (_isSplit) {
                  _stCashCtl.text = '';
                  _stCardCtl.text = '';
                  _stYapeCtl.text = '';
                  for (final it in widget.items) {
                    _splitItemChoice[it.uniqueId] = PaymentMethod.cash;
                  }
                }
              }),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isSplit
                            ? const Color(0xFF059669).withValues(alpha: 0.2)
                            : const Color(0xFF059669).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.call_split_rounded,
                        color: _isSplit
                            ? const Color(0xFF059669)
                            : const Color(0xFF059669).withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dividir método de pago',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: _isSplit ? FontWeight.w600 : FontWeight.w500,
                              color: _isSplit
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Partir el gasto entre varios métodos',
                            style: TextStyle(
                              fontSize: 13,
                              color: _isSplit
                                  ? const Color(0xFF059669).withValues(alpha: 0.8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _isSplit
                            ? const Color(0xFF059669)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: _isSplit
                            ? null
                            : Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                      child: _isSplit
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            )
                          : const SizedBox(width: 18, height: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_isSplit) ...[
          const SizedBox(height: 16),
          // Selector de modo de división con estilo mejorado
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _splitByTotal = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _splitByTotal
                            ? const Color(0xFF059669)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _splitByTotal
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calculate_rounded,
                            size: 18,
                            color: _splitByTotal
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Por total',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _splitByTotal
                                  ? Colors.white
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _splitByTotal = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_splitByTotal
                            ? const Color(0xFF059669)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: !_splitByTotal
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.list_alt_rounded,
                            size: 18,
                            color: !_splitByTotal
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Por item',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: !_splitByTotal
                                  ? Colors.white
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_splitByTotal) _buildSplitByTotalUI(),
          if (!_splitByTotal) _buildSplitByItemUI(),
        ],
      ],
    );
  }

  Widget _buildSplitByTotalUI() {
    // final theme = Theme.of(context); // no usado
    double otherSumExcluding(TextEditingController c) {
      double p(TextEditingController cc) => double.tryParse(cc.text.replaceAll(',', '.')) ?? 0.0;
      final controllers = [_stCashCtl, _stCardCtl, _stYapeCtl];
      return controllers.where((x) => x != c).map(p).fold(0.0, (a, b) => a + b);
    }

    void autoFill(TextEditingController target) {
      final assigned = otherSumExcluding(target);
      final rem = (widget.totalGasto - assigned).clamp(0.0, widget.totalGasto);
      setState(() {
        target.text = rem.toStringAsFixed(2);
      });
    }

    return Column(
      children: [
        _buildMoneyFieldWithButton('Efectivo', _stCashCtl, Icons.payments_rounded, () => autoFill(_stCashCtl)),
        const SizedBox(height: 12),
        _buildMoneyFieldWithButton('Tarjeta (Ruben)', _stCardCtl, Icons.credit_card_rounded, () => autoFill(_stCardCtl)),
        const SizedBox(height: 12),
        _buildMoneyFieldWithButton('Yape (Aharhel)', _stYapeCtl, Icons.qr_code_rounded, () => autoFill(_stYapeCtl)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Total asignado: S/ ${(_sumSplitTotal()).toStringAsFixed(2)} / S/ ${widget.totalGasto.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _sumSplitTotal() {
    double p(TextEditingController cc) => double.tryParse(cc.text.replaceAll(',', '.')) ?? 0.0;
    return p(_stCashCtl) + p(_stCardCtl) + p(_stYapeCtl);
  }


  Widget _buildMoneyFieldWithButton(String label, TextEditingController ctl, IconData icon, VoidCallback onAutoFill) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: const Color(0xFF059669),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: ctl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: label,
                prefixText: 'S/ ',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                labelStyle: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Material(
              color: const Color(0xFF059669).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: onAutoFill,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.auto_fix_high_rounded,
                    size: 20,
                    color: const Color(0xFF059669),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitByItemUI() {
    // final theme = Theme.of(context); // no usado
    final cashIcon = PaymentMethod.cash.icon;
    final cardIcon = PaymentMethod.izipayCard.icon;
    final yapeIcon = PaymentMethod.yapePersonal.icon;

    return Column(
      children: widget.items.map((it) {
        final chosen = _splitItemChoice[it.uniqueId] ?? PaymentMethod.cash;
        final idx = chosen == PaymentMethod.cash
            ? 0
            : chosen == PaymentMethod.izipayCard
                ? 1
                : 2;
        final selected = [idx == 0, idx == 1, idx == 2];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 20,
                  color: const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it.producto.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'S/ ${it.precioEditable.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ToggleButtons(
                  isSelected: selected,
                  borderRadius: BorderRadius.circular(8),
                  constraints: const BoxConstraints(minWidth: 42, minHeight: 38),
                  color: Colors.grey.shade700,
                  selectedColor: Colors.white,
                  fillColor: const Color(0xFF059669),
                  borderColor: Colors.transparent,
                  selectedBorderColor: Colors.transparent,
                  onPressed: (i) {
                    setState(() {
                      _splitItemChoice[it.uniqueId] =
                          i == 0
                              ? PaymentMethod.cash
                              : i == 1
                                  ? PaymentMethod.izipayCard
                                  : PaymentMethod.yapePersonal;
                    });
                  },
                  children: [
                    Tooltip(
                      message: 'Efectivo',
                      child: Icon(cashIcon, size: 18),
                    ),
                    Tooltip(
                      message: 'Tarjeta (Ruben)',
                      child: Icon(cardIcon, size: 18),
                    ),
                    Tooltip(
                      message: 'Yape (Aharhel)',
                      child: Icon(yapeIcon, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
