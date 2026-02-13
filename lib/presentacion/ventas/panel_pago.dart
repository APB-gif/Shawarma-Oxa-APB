// lib/presentacion/ventas/panel_pago.dart

import 'package:flutter/material.dart';
import 'package:shawarma_pos_nuevo/presentacion/pagina_principal.dart';
import 'package:intl/intl.dart'; // <-- AÑADIDO
import 'package:shawarma_pos_nuevo/presentacion/ventas/item_carrito.dart';
// removed provider and caja_service imports as panel pago restored to local-only flow
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shawarma_pos_nuevo/core/net/connectivity_utils.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';

enum MetodoDePago {
  cash,
  izipayCard,
  yapePersonal,
  split;

  String get displayName {
    switch (this) {
      case MetodoDePago.cash:
        return 'Efectivo';
      case MetodoDePago.izipayCard:
        return 'Tarjeta';
      
      case MetodoDePago.yapePersonal:
        return 'Yape';
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
  
  final _yapePersonalCtl = TextEditingController();
  final _fnCash = FocusNode();
  final _fnCard = FocusNode();
  
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
  
  final _stYapeCtl = TextEditingController();
  final _stCashFn = FocusNode();
  final _stCardFn = FocusNode();
  
  final _stYapeFn = FocusNode();

  // Visual metadata for methods
  _MethodDisp _methodDisplay(MetodoDePago m) {
    switch (m) {
      case MetodoDePago.cash:
        return _MethodDisp('Efectivo', Icons.money_outlined, Colors.green.shade700);
      case MetodoDePago.izipayCard:
        return _MethodDisp('Tarjeta', Icons.credit_card_outlined, Colors.blue.shade700);
      case MetodoDePago.yapePersonal:
        return _MethodDisp('Yape', Icons.phone_android_outlined, Colors.purple.shade900);
      case MetodoDePago.split:
        // No se usa como método por ítem; devolver un estilo neutral por si acaso.
        return _MethodDisp('Dividir', Icons.call_split_outlined, Colors.teal.shade700);
    }
  }

  // Eliminado: el selector antiguo por método se reemplazó por el editor de montos por ítem
  // NUEVO: Variable de estado para la fecha de la venta
  DateTime _fechaVenta = DateTime.now();
  // NUEVO: indica que la venta se está procesando (bloquea la UI)
  bool _isProcessing = false;
  // NUEVO: indica que la venta se está procesando (bloquea la UI)
  // Debug / timeout helpers
  Timer? _processingTimer;
  int _processingSeconds = 0;
  // Timeout configurable para verificación de conectividad / guardado offline
  final int _connectivityTimeoutSeconds = 5;

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
      final others = (totals[MetodoDePago.cash] ?? 0.0) + (totals[MetodoDePago.yapePersonal] ?? 0.0);
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
                  
      _stYapeCtl.clear();
    });
  }

  @override
  void dispose() {
    _cashCtl.dispose();
    _cardCtl.dispose();
    _yapePersonalCtl.dispose();
    _fnCash.dispose();
    _fnCard.dispose();
    _fnYapePers.dispose();
    _stCashFn.dispose();
    _stCardFn.dispose();
    
    _stYapeFn.dispose();
    _stCashCtl.dispose();
    _stCardCtl.dispose();
    
    _stYapeCtl.dispose();
    super.dispose();
  }

  void _clearAllInputs() {
    _cashCtl.clear();
    _cardCtl.clear();
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
        MetodoDePago.yapePersonal: p(_stYapeCtl),
      };
    }
    return _buildSplitTotals();
  }

  void _confirm() async {
    print('[PanelPago] _confirm: inicio (method=$_method, subtotal=$_subtotal)');
    final Map<String, double> pagos = {};
    try {
      switch (_method) {
        case MetodoDePago.cash:
          pagos['Efectivo'] = _subtotal;
          break;
        case MetodoDePago.izipayCard:
          pagos['Tarjeta'] = _cardWithFee(_subtotal);
          break;
        
        case MetodoDePago.yapePersonal:
          pagos['Yape'] = _subtotal;
          break;
        case MetodoDePago.split:
          final totals = _currentSplitTotals();
          final cashAmount = totals[MetodoDePago.cash] ?? 0.0;
          final cardBase = totals[MetodoDePago.izipayCard] ?? 0.0;
          final cardAmount = _cardWithFee(cardBase);
          final yapePersAmount = totals[MetodoDePago.yapePersonal] ?? 0.0;

          if (cashAmount > 0) pagos['Efectivo'] = cashAmount;
          if (cardAmount > 0) pagos['Tarjeta'] = cardAmount;
          if (yapePersAmount > 0) pagos['Yape'] = yapePersAmount;

          final assignedBase = cashAmount + cardBase + yapePersAmount;
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

      setState(() {
        _isProcessing = true;
      });
      print('[PanelPago] _confirm: set _isProcessing=true');
      _startProcessingTimer();

      // Verificar conectividad con timeout usando helper (maneja v3/v6 del plugin)
      print('[PanelPago] _confirm: comprobando conectividad (timeout ${_connectivityTimeoutSeconds}s)');
      bool isOnline = false;
      try {
        isOnline = await hasInternet(timeout: Duration(seconds: _connectivityTimeoutSeconds));
      } catch (err) {
        print('[PanelPago] hasInternet lanzó error: $err');
        isOnline = false;
      }
      print('[PanelPago] hasInternet => $isOnline');

      if (isOnline) {
        try {
          print('[PanelPago] onConfirm (online) - iniciando');
          await widget.onConfirm(pagos: pagos, fechaVenta: _fechaVenta);
          print('[PanelPago] onConfirm (online) - OK');

          // Preparar contexto seguro para mostrar diálogo después de cerrar el panel
          final hostContext = Navigator.of(context).overlay?.context ?? context;

          // Cerrar panel actual devolviendo resultado true para que el parent lo procese
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          }

          // Pequeña espera para que la animación de cierre termine
          await Future.delayed(const Duration(milliseconds: 260));

          // Mostrar diálogo de éxito sobre el contexto padre
          _showSuccessDialog(hostContext: hostContext);
        } catch (e) {
          print('[PanelPago] onConfirm (online) - error: $e');

          final hostContext = Navigator.of(context).overlay?.context ?? context;
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(false);
          }
          await Future.delayed(const Duration(milliseconds: 260));
          _showErrorDialog(e.toString(), hostContext: hostContext);
        } finally {
          print('[PanelPago] _confirm: finalizando (online)');
          _stopProcessingTimer();
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
        }
      } else {
        // Offline: intentar guardar localmente pero no bloquear la UI largo tiempo
        print('[PanelPago] Offline: intentando guardar localmente (timeout ${_connectivityTimeoutSeconds}s)');
        try {
          await widget
              .onConfirm(pagos: pagos, fechaVenta: _fechaVenta)
              .timeout(Duration(seconds: _connectivityTimeoutSeconds), onTimeout: () => Future.value());
          print('[PanelPago] Intento offline finalizado (ok/timeout)');
        } catch (err) {
          print('[PanelPago] Intento offline lanzó error: $err');
          // Ignorar errores en el intento offline
        }

        if (mounted) {
          print('[PanelPago] _confirm: finalizando (offline)');
          _stopProcessingTimer();
          setState(() {
            _isProcessing = false;
          });

          // Capturar un contexto estable (overlay) para mostrar el diálogo
          final hostContext = Navigator.of(context).overlay?.context ?? context;

          // Cerrar el panel actual (si está abierto) antes de mostrar el diálogo
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop(true);
          }

          // Esperar un pequeño lapso para que la animación de cierre termine
          await Future.delayed(const Duration(milliseconds: 260));

          // Mostrar diálogo usando el contexto del overlay (padre)
          _showOfflineSaveDialog(hostContext: hostContext);
        }
      }
    } catch (e) {
      print('[PanelPago] _confirm: excepción externa: $e');
      principalMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error al registrar la venta o descontar insumos: $e')),
      );
      _stopProcessingTimer();
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Inicia el timer de procesamiento que actualiza el contador cada segundo.
  void _startProcessingTimer() {
    _processingTimer?.cancel();
    _processingSeconds = 0;
    _processingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _processingSeconds++;
      // Actualizar UI con cada tick (muestra el contador)
      if (mounted) setState(() {});
      print('[PanelPago] timer tick: ${_processingSeconds}s');
    });
  }

  // Detiene y limpia el timer de procesamiento
  void _stopProcessingTimer() {
    if (_processingTimer != null) {
      print('[PanelPago] _stopProcessingTimer: deteniendo timer en ${_processingSeconds}s');
      _processingTimer?.cancel();
      _processingTimer = null;
    }
    _processingSeconds = 0;
  }

  void _showErrorDialog(String errorMessage, {BuildContext? hostContext}) {
    final dialogContext = hostContext ?? context;
    showDialog(
      context: dialogContext,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Center(
            child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(
                parent: ModalRoute.of(ctx)?.animation ?? const AlwaysStoppedAnimation<double>(1.0),
                curve: Curves.elasticOut,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono de error con animación
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.red.shade400,
                          Colors.red.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Texto de error
                  const Text(
                    '¡Error al Registrar!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hubo un problema al guardar la venta',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Detalles del error
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 20, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Reintentar',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Volver',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showOfflineSaveDialog({BuildContext? hostContext}) {
    final dialogContext = hostContext ?? context;
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Center(
            child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(
                parent: ModalRoute.of(ctx)?.animation ?? const AlwaysStoppedAnimation<double>(1.0),
                curve: Curves.elasticOut,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono de WiFi sin conexión
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.amber.shade400,
                          Colors.amber.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Título
                  const Text(
                    '¡Venta Guardada Localmente!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sin conexión a internet en este momento',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Detalles principales
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 18, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Venta registrada en el dispositivo',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.cloud_queue_rounded,
                                size: 18, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Se sincronizará cuando regrese internet',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 18, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Total: S/ ${_subtotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber.shade900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Información de sincronización
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'La venta se enviará automáticamente cuando haya conexión',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Botón para continuar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx); // Cerrar diálogo
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text(
                        'Continuar',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      // El panel se cierra automáticamente después del diálogo
    });
  }

  void _showSuccessDialog({BuildContext? hostContext}) {
    final dialogContext = hostContext ?? context;
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Center(
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(
                parent: ModalRoute.of(ctx)?.animation ?? const AlwaysStoppedAnimation<double>(1.0),
                curve: Curves.elasticOut,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.green.shade400,
                          Colors.green.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '¡Venta Registrada!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'La venta se ha guardado correctamente',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 18, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Total: S/ ${_subtotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 18, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(_fechaVenta),
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Continuar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
        child: Stack(
          children: [
            Column(
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
                                constraints:
                                    const BoxConstraints(minWidth: 32, minHeight: 32),
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
                              shadowColor:
                                  const Color(0xFF1E40AF).withOpacity(0.3),
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

            // Overlay bloqueante profesional mejorado
            _isProcessing
                ? Positioned.fill(
                    child: AbsorbPointer(
                      absorbing: true,
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        child: Center(
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                              CurvedAnimation(
                                parent: ModalRoute.of(context)?.animation ?? const AlwaysStoppedAnimation<double>(1.0),
                                curve: Curves.easeOut,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Indicador de progreso circular animado
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.blue.shade50,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.15),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 70,
                                        height: 70,
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Color(0xFF1E40AF),
                                          ),
                                          strokeWidth: 5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Título
                                  const Text(
                                    'Procesando Venta',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Subtítulo
                                  Text(
                                    'Por favor espera mientras se guarda la venta',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Detalles de progreso
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle_outline_rounded,
                                              size: 18,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Validando información',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.cloud_upload_outlined,
                                              size: 18,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Registrando venta',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.inventory_2_outlined,
                                              size: 18,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Actualizando insumos',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Indicador de tiempo
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _processingSeconds > 0
                                            ? 'Tiempo transcurrido: ${_processingSeconds}s'
                                            : 'Esto puede tomar unos segundos...',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
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
                      'Yape',
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
                  decoration: _inputDeco('Monto por Yape',
                      borderColor: Colors.purple.shade300),
                ),
                const SizedBox(height: 12),
                // QR de Yape: preferir asset si existe, sino mostrar un QR generado
                Center(
                  child: GestureDetector(
                    onTap: () {
                      // Abrir QR a pantalla completa (pantalla independiente con botón cerrar)
                      Navigator.of(context).push(MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => _YapeQrFullScreen(amountCtl: _yapePersonalCtl, subtotal: widget.subtotal),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8EAF0)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Mostrar asset si existe; si no, renderizar QR con datos mínimos
                          SizedBox(width: 180, height: 180, child: _YapeQrWidget(size: 170, amountCtl: _yapePersonalCtl, subtotal: widget.subtotal)),
                          const SizedBox(height: 8),
                          Text('Paga aquí con Yape', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                  ),
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
                  
                  onAllYapePers: () {
                    setState(() {
                      if (_splitByTotal) {
                        _stYapeCtl.text = widget.subtotal.toStringAsFixed(2);
                        _stCashCtl.clear();
                        _stCardCtl.clear();
                        
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
            tile('Yape', yape, Colors.purple.shade800,
                Icons.phone_android_outlined),
          ],
        ),
      ],
    );
  }

  // Editor de división por total
  Widget _buildTotalSplitEditor() {
    double p(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0;
    final sum = p(_stCashCtl) + p(_stCardCtl) + p(_stYapeCtl);
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
                    controller: _stYapeCtl,
                    focusNode: _stYapeFn,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: deco('Yape', Colors.purple.shade900),
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
                      icon: Icons.phone_android_outlined,
                      label: 'Yape',
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
  final VoidCallback onAllYapePers;
  const _QuickGrid({
    required this.selectedMethod,
    required this.onAllCash,
    required this.onAllCard,
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
        // Mover "Yape" al lado derecho de Efectivo
        btn(icon: Icons.phone_android_outlined, color: Colors.purple.shade900, tooltip: 'Todo a Yape', onTap: onAllYapePers, selected: selectedMethod == MetodoDePago.yapePersonal),
        btn(icon: Icons.credit_card_outlined, color: Colors.blue, tooltip: 'Todo a Tarjeta', onTap: onAllCard, selected: selectedMethod == MetodoDePago.izipayCard),
        // IziPay Yape eliminado: botón retirado
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
  late final TextEditingController _yapeCtl;
  final _fnEfec = FocusNode();
  final _fnCard = FocusNode();
  final _fnYape = FocusNode();

  @override
  void initState() {
    super.initState();
    double v(MetodoDePago m) => (widget.initial[m] ?? 0.0);
    String f(double d) => d > 0 ? d.toStringAsFixed(2) : '';
    _efecCtl = TextEditingController(text: f(v(MetodoDePago.cash)));
    _cardCtl = TextEditingController(text: f(v(MetodoDePago.izipayCard)));
    _yapeCtl = TextEditingController(text: f(v(MetodoDePago.yapePersonal)));
  }

  @override
  void dispose() {
    _fnEfec.dispose();
    _fnCard.dispose();
    _fnYape.dispose();
    _efecCtl.dispose();
    _cardCtl.dispose();
    _yapeCtl.dispose();
    super.dispose();
  }

  double _p(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0.0;

  double get _sum => _p(_efecCtl) + _p(_cardCtl) + _p(_yapeCtl);
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
      _yapeCtl.text = m == MetodoDePago.yapePersonal ? _price.toStringAsFixed(2) : '';
    });
  }

  void _clearAll() {
    setState(() {
      _efecCtl.clear();
      _cardCtl.clear();
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
                  controller: _yapeCtl,
                  focusNode: _fnYape,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('Yape', Colors.purple.shade900),
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
                const SizedBox(width: 8),
                  _QuickActionChip(
                    icon: Icons.phone_android_outlined,
                    label: 'Todo Yape',
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
                    icon: Icons.phone_android_outlined,
                    label: 'Yape',
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

  // Carga el asset JPEG exacto desde el bundle para asegurar que el QR mostrado
  // sea idéntico al archivo subido por el usuario. Si falla, genera un QR
  // dinámico como fallback.
  static Widget _buildFromBundle({required double size, required TextEditingController amountCtl, required double subtotal}) {
    return _YapeQrWidget(size: size, amountCtl: amountCtl, subtotal: subtotal);
  }

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

class _YapeQrWidget extends StatelessWidget {
  final double size;
  final TextEditingController amountCtl;
  final double subtotal;

  const _YapeQrWidget({required this.size, required this.amountCtl, required this.subtotal});

  Future<Uint8List> _loadAsset() async {
    final data = await rootBundle.load('assets/images/yape_qr.jpeg');
    return data.buffer.asUint8List();
  }

  String _qrPayload() => 'yape:amount=${amountCtl.text.isEmpty ? subtotal.toStringAsFixed(2) : amountCtl.text}';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _loadAsset(),
      builder: (ctx, snap) {
        if (snap.hasData) {
          return Image.memory(
            snap.data!,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          );
        }
        if (snap.hasError) {
          return Center(
            child: QrImageView(
              data: _qrPayload(),
              size: size,
            ),
          );
        }
        return const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)));
      },
    );
  }
}

class _YapeQrFullScreen extends StatelessWidget {
  final TextEditingController amountCtl;
  final double subtotal;

  const _YapeQrFullScreen({required this.amountCtl, required this.subtotal});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final double maxDimension = media.width < media.height ? media.width : media.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Imagen ocupando el máximo espacio posible (manteniendo aspect ratio)
            Positioned.fill(
              child: FutureBuilder<Uint8List>(
                future: rootBundle.load('assets/images/yape_qr.jpeg').then((d) => d.buffer.asUint8List()),
                builder: (ctx, snap) {
                  if (snap.hasData) {
                    return InteractiveViewer(
                      panEnabled: true,
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Center(
                        child: Image.memory(
                          snap.data!,
                          width: media.width,
                          height: media.height,
                          fit: BoxFit.contain, // escalar al máximo sin recortar
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                        ),
                      ),
                    );
                  }

                  if (snap.hasError) {
                    // fallback: generar QR dinámico si el asset falla
                    final payload = 'yape:amount=${amountCtl.text.isEmpty ? subtotal.toStringAsFixed(2) : amountCtl.text}';
                    return Center(
                      child: InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 3.0,
                        child: QrImageView(data: payload, size: maxDimension),
                      ),
                    );
                  }

                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),

            // Texto/leyenda sobre la imagen (opcional, semitransparente)
            Positioned(
              bottom: 28,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(24)),
                  child: const Text('Escanea para pagar con Yape', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ),
              ),
            ),

            // Botón cerrar
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Cerrar',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

