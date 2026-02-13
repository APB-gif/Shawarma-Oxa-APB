import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shawarma_pos_nuevo/datos/modelos/caja.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/venta.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/caja_service.dart';
import 'package:shawarma_pos_nuevo/presentacion/widgets/notificaciones.dart';
import 'package:shawarma_pos_nuevo/presentacion/pagina_principal.dart';
import 'package:shawarma_pos_nuevo/presentacion/caja/gasto_apertura_dialog.dart';
import 'package:shawarma_pos_nuevo/presentacion/caja/modern_dialogs.dart' show showModernConfirmDialog, showCajaInitiatedDialog, showCajaClosedDialog;
import 'package:shawarma_pos_nuevo/datos/servicios/auth/auth_service.dart';
import 'package:shawarma_pos_nuevo/presentacion/auth/auth_gate.dart';
import 'package:shawarma_pos_nuevo/main.dart';

// --------- Helpers ---------
String _catNombre(dynamic p) {
  try {
    final cn = (p.categoriaNombre as String?)?.trim();
    if (cn != null && cn.isNotEmpty) return cn;
  } catch (_) {}
  try {
    final cid = (p.categoriaId as String?)?.trim();
    if (cid != null && cid.isNotEmpty) return cid;
  } catch (_) {}
  return '';
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  return null;
}

class _ThemeColors {
  static const Color background = Colors.white;
  static const Color cardBackground = Color(0xFFF7F8FC);
  static const Color primaryGradientStart = Color(0xFF00B2FF);
  static const Color primaryGradientEnd = Color(0xFF0061FF);
  static const Color dangerGradientStart = Color(0xFFE53935);
  static const Color accentText = Color(0xFF0B1229);
  static const Color inactive = Color(0xFF7A819D);
}

/// Diálogo reutilizable para abrir caja (admin o trabajador)
Future<void> _mostrarDialogoAbrirCajaGenerico(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController();
  final cajaService = Provider.of<CajaService>(context, listen: false);

  DateTime fechaSeleccionada = DateTime.now();

  bool _ctxMounted(BuildContext c) {
    return c is Element && c.mounted;
  }

  Future<void> abrirCaja(
    double monto,
    DateTime fecha,
    BuildContext dialogContext, {
    bool skipDialogClose = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null;
    // Capturar referencia al servicio antes de cualquier await que pueda disparar
    // reconstrucciones que reciclen el context. Usar el context del navigator
    // global si el context local fue desmontado.
    final authContext = navigatorKey.currentContext ?? context;
    final authSvc = Provider.of<AuthService>(authContext, listen: false);

    bool _didCloseDialog = false;
    try {
      // Antes de abrir, validar si el trabajador tiene permiso según horarios
      final uidNow = FirebaseAuth.instance.currentUser?.uid;
      if (uidNow != null && !(user?.email ?? '').contains('@admin')) {
        try {
          // Si no es administrador, comprobar horarios y bandera de habilitación
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uidNow).get();
          final currentRole = (userDoc.data()?['rol'] ?? '').toString().toLowerCase();
          final habilitadoPorAdmin = (userDoc.data()?['habilitado_fuera_horario'] ?? false) as bool;

          bool allowedBySchedule = false;
          if (currentRole == 'administrador') allowedBySchedule = true;

          if (!allowedBySchedule) {
            final now = DateTime.now();
            final weekdayIndex = now.weekday - 1; // 0=Lun .. 6=Dom (coincide con UI)
            final horariosSnap = await FirebaseFirestore.instance
                .collection('horarios')
                .where('userId', isEqualTo: uidNow)
                .where('active', isEqualTo: true)
                .get();

            for (final h in horariosSnap.docs) {
              try {
                final data = h.data();
                final days = (data['days'] is List) ? List<dynamic>.from(data['days']) : <dynamic>[];
                if (days.isNotEmpty && !days.contains(weekdayIndex)) continue;
                final s = (data['startTime'] ?? '').toString();
                final e = (data['endTime'] ?? '').toString();
                if (s.isEmpty || e.isEmpty) continue;
                final sp = s.split(':');
                final ep = e.split(':');
                if (sp.length != 2 || ep.length != 2) continue;
                final sh = int.tryParse(sp[0]) ?? 0;
                final sm = int.tryParse(sp[1]) ?? 0;
                final eh = int.tryParse(ep[0]) ?? 0;
                final em = int.tryParse(ep[1]) ?? 0;
                final startDt = DateTime(now.year, now.month, now.day, sh, sm);
                final endDt = DateTime(now.year, now.month, now.day, eh, em);
                // Si end < start asumimos que cruza medianoche y añadimos 1 día a end
                final adjustedEnd = endDt.isBefore(startDt) ? endDt.add(const Duration(days: 1)) : endDt;
                final nowDt = now;
                // Cuando el horario cruza medianoche, comparamos una versión
                // ajustada de "now" para poder estar dentro del intervalo
                // que abarca la pasada medianoche.
                final nowCmp = nowDt.isBefore(startDt) ? nowDt.add(const Duration(days: 1)) : nowDt;
                if ((nowCmp.isAtSameMomentAs(startDt) || nowCmp.isAfter(startDt)) && nowCmp.isBefore(adjustedEnd)) {
                  allowedBySchedule = true;
                  break;
                }
              } catch (_) {}
            }
          }

          if (!allowedBySchedule && habilitadoPorAdmin != true) {
            if (mainScaffoldContext != null) {
              mostrarNotificacionElegante(
                mainScaffoldContext!,
                'No es hora de apertura para tu turno. Pide al administrador habilitar el ingreso.',
                esError: true,
                messengerKey: principalMessengerKey,
              );
            }
            return;
          }
        } catch (_) {
          // En caso de fallo al comprobar horarios, permitimos la apertura por compatibilidad
        }
      }

      await cajaService.abrirCaja(
        montoInicial: monto,
        usuarioId: user?.uid ?? 'local',
        usuarioNombre: user?.displayName ?? user?.email ?? 'Invitado',
        fechaSeleccionada: fecha,
      );

      // Al abrir caja: si el usuario no es admin, poner rol "trabajador"
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          final rol = (userDoc.data()?['rol'] ?? '').toString().toLowerCase();
          if (rol != 'administrador') {
            // Cambiar rol a trabajador durante la sesión de caja (sin usar context luego)
            await authSvc.updateUserRole(uid, 'trabajador');
          }
        }
      } catch (_) {}

      if (!skipDialogClose) {
        // Cerrar el diálogo de apertura de forma robusta para cubrir casos
        // offline donde los contextos/navigators pueden variar. Intentamos
        // cerrar usando el contexto local `dialogContext` y, si falla,
        // usamos el navigator global (`navigatorKey`) como fallback.
        try {
          if (_ctxMounted(dialogContext) && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
            _didCloseDialog = true;
          } else {
            final rootNav = navigatorKey.currentState;
            if (rootNav != null && rootNav.canPop()) {
              rootNav.pop();
              _didCloseDialog = true;
            }
          }
        } catch (_) {
          try {
            final rootNav = navigatorKey.currentState;
            if (rootNav != null && rootNav.canPop()) {
              rootNav.pop();
              _didCloseDialog = true;
            }
          } catch (_) {}
        }
      }
      if (mainScaffoldContext != null) {
        await showCajaInitiatedDialog(
          mainScaffoldContext!,
          isGuest: isGuest,
        );
      }
    } catch (e) {
      if (mainScaffoldContext != null) {
        mostrarNotificacionElegante(mainScaffoldContext!, 'Error: $e',
            esError: true, messengerKey: principalMessengerKey);
      }
    }

    // Asegurar cierre del diálogo incluso si ocurrió una excepción antes
    // de llegar al bloque anterior. Solo intentamos cerrar si no lo hicimos
    // y si no se pidió explícitamente omitir el cierre.
    if (!_didCloseDialog && !skipDialogClose) {
      try {
        if (_ctxMounted(dialogContext) && Navigator.of(dialogContext).canPop()) {
          Navigator.of(dialogContext).pop();
        } else {
          final rootNav = navigatorKey.currentState;
          if (rootNav != null && rootNav.canPop()) rootNav.pop();
        }
      } catch (_) {}
    }
  }

  void confirmarAbrirConCero(BuildContext parentDialogContext) {
    showModernConfirmDialog(
      context,
      title: 'Confirmar Apertura',
      message: 'El monto está vacío. ¿Desea abrir la caja con S/ 0.00?',
      confirmText: 'Sí, abrir',
      cancelText: 'Cancelar',
      confirmColor: Colors.blue.shade600,
      icon: Icons.info_outline_rounded,
    ).then((confirmed) async {
      if (confirmed == true) {
        // Intentar cerrar el diálogo padre usando el navigator global primero
        try {
          final rootNav = navigatorKey.currentState;
          if (rootNav != null && rootNav.canPop()) {
            rootNav.pop();
          } else if (_ctxMounted(parentDialogContext) && Navigator.of(parentDialogContext).canPop()) {
            Navigator.of(parentDialogContext).pop();
          }
        } catch (_) {}
        await abrirCaja(0.0, fechaSeleccionada, parentDialogContext, skipDialogClose: true);
      }
    });
  }

  // Mostrar el diálogo principal de apertura de caja con estilo moderno
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Center(
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(
              parent: ModalRoute.of(dialogContext)?.animation ?? const AlwaysStoppedAnimation<double>(1.0),
              curve: Curves.elasticOut,
            ),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
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
            child: StatefulBuilder(
              builder: (ctx, setDialogState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono con gradiente
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade400,
                          Colors.blue.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.store_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Título
                  const Text(
                    'Iniciar Nueva Caja',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ingresa el monto inicial y selecciona la fecha',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Contenido del formulario
                  Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: 'Monto Inicial (S/)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.monetization_on_rounded),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          autofocus: true,
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            if (double.tryParse(v.replaceAll(',', '.')) == null)
                              return 'Monto inválido.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Selección de fecha y hora
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fecha y Hora',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.calendar_today_outlined),
                                      label: Text(
                                        DateFormat.yMMMd('es_ES').format(fechaSeleccionada),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onPressed: () async {
                                        final pickedDate = await showDatePicker(
                                          context: context,
                                          initialDate: fechaSeleccionada,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime.now(),
                                        );
                                        if (pickedDate != null) {
                                          setDialogState(() {
                                            fechaSeleccionada = DateTime(
                                              pickedDate.year,
                                              pickedDate.month,
                                              pickedDate.day,
                                              fechaSeleccionada.hour,
                                              fechaSeleccionada.minute,
                                            );
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.access_time_outlined),
                                      label: Text(
                                        DateFormat.jm('es_ES').format(fechaSeleccionada),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onPressed: () async {
                                        final pickedTime = await showTimePicker(
                                          context: context,
                                          initialTime: TimeOfDay.fromDateTime(fechaSeleccionada),
                                        );
                                        if (pickedTime != null) {
                                          setDialogState(() {
                                            fechaSeleccionada = DateTime(
                                              fechaSeleccionada.year,
                                              fechaSeleccionada.month,
                                              fechaSeleccionada.day,
                                              pickedTime.hour,
                                              pickedTime.minute,
                                            );
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              if (controller.text.isEmpty) {
                                // Cerrar el diálogo de inicio y abrir confirmación para 0
                                if (_ctxMounted(dialogContext) && Navigator.of(dialogContext).canPop()) Navigator.of(dialogContext).pop();
                                confirmarAbrirConCero(dialogContext);
                              } else {
                                final monto = double.parse(controller.text.replaceAll(',', '.'));
                                // Cerrar inmediatamente el diálogo antes de iniciar la caja
                                if (_ctxMounted(dialogContext) && Navigator.of(dialogContext).canPop()) Navigator.of(dialogContext).pop();
                                await abrirCaja(monto, fechaSeleccionada, dialogContext, skipDialogClose: true);
                              }
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Iniciar Caja', style: TextStyle(fontWeight: FontWeight.w600)),
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
  );
}

class _AdminCloseParams {
  final String motivo;
  final double? montoContado;
  final DateTime? fechaCierre;
  _AdminCloseParams(
      {required this.motivo, this.montoContado, this.fechaCierre});
}

Future<_AdminCloseParams?> _pedirDatosCierre(
  BuildContext context, {
  DateTime? minFecha,
  DateTime? maxFecha,
}) async {
  final formKey = GlobalKey<FormState>();
  final motivoCtrl = TextEditingController(text: 'Cierre remoto por admin');
  final montoCtrl = TextEditingController();
  DateTime fechaSel = DateTime.now();

  Future<void> pickFechaHora(StateSetter setState) async {
    final now = DateTime.now();
    final initialDate = fechaSel.isAfter(now) ? now : fechaSel;
    final first = minFecha ?? DateTime(2020);
    final last = maxFecha ?? now;

    final d = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: first,
      lastDate: last,
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(fechaSel),
    );
    if (t == null) return;
    final combinado = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (minFecha != null && combinado.isBefore(minFecha)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La fecha no puede ser anterior a la apertura.')),
      );
      return;
    }
    if (combinado.isAfter(last)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha no puede ser futura.')),
      );
      return;
    }
    setState(() => fechaSel = combinado);
  }

  final result = await showDialog<_AdminCloseParams>(
    context: context,
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
            constraints: const BoxConstraints(maxWidth: 500),
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
            child: StatefulBuilder(
              builder: (ctx, setState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono con gradiente
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Título
                  const Text(
                    'Cierre Remoto (Admin)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ingresa los detalles para cerrar la caja remotamente',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Formulario
                  Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: motivoCtrl,
                          decoration: InputDecoration(
                            labelText: 'Motivo',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.note_rounded),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: montoCtrl,
                          decoration: InputDecoration(
                            labelText: 'Monto contado (opcional)',
                            hintText: 'Si lo dejas vacío, se usa el esperado',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.monetization_on_rounded),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            return double.tryParse(v.replaceAll(',', '.')) == null
                                ? 'Número inválido'
                                : null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Selección de fecha y hora
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.edit_calendar_outlined, size: 18, color: Colors.orange.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Fecha y hora: ${DateFormat('dd/MM/yyyy HH:mm').format(fechaSel)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => pickFechaHora(setState),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Cambiar fecha y hora', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            final motivo = motivoCtrl.text.trim().isEmpty
                                ? 'Cierre remoto por admin'
                                : motivoCtrl.text.trim();
                            final txt = montoCtrl.text.trim();
                            final monto =
                                txt.isEmpty ? null : double.parse(txt.replaceAll(',', '.'));
                            Navigator.pop(
                              ctx,
                              _AdminCloseParams(
                                motivo: motivo,
                                montoContado: monto,
                                fechaCierre: fechaSel,
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Enviar comando', style: TextStyle(fontWeight: FontWeight.w600)),
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
  );
  return result;
}

class PaginaCaja extends StatelessWidget {
  const PaginaCaja({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CajaService>(
      builder: (context, cajaService, child) {
        if (cajaService.isLoading) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // Detectar rol del usuario actual (stream tipado)
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final Stream<DocumentSnapshot<Map<String, dynamic>>> userDoc =
            (uid != null)
                ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots()
                : Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userDoc,
          builder: (ctx, snap) {
            final rol = ((snap.data?.data()?['rol'] ?? 'trabajador')
                    .toString()
                    .trim())
                .toLowerCase();
            final isAdmin = rol == 'administrador';
            final isViewer = rol == 'espectador';
            final isOff = rol == 'fuera de servicio';

            if (isOff) {
              final colorScheme = Theme.of(context).colorScheme;
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Caja'),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final auth = Provider.of<AuthService>(context, listen: false);
                            final shouldLogout = await showModernConfirmDialog(
                              context,
                              title: 'Cerrar Sesión',
                              message: '¿Quieres cerrar sesión para cambiar de cuenta?',
                              confirmText: 'Salir',
                              cancelText: 'Cancelar',
                              confirmColor: Colors.red.shade600,
                              icon: Icons.logout_rounded,
                            );
                            if (shouldLogout != true) return;

                            principalMessengerKey.currentState
                                ?.clearSnackBars();
                            final rootNav = Navigator.of(context,
                                rootNavigator: true);
                            if (rootNav.canPop()) {
                              rootNav.popUntil((route) => route.isFirst);
                            }

                            // Usar instancia capturada para evitar mirar el árbol tras posibles pops
                            await auth.signOut();
                            if (!context.mounted) return;
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) => const AuthGate()),
                              (route) => false,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_person_rounded,
                            size: 64, color: colorScheme.error),
                        const SizedBox(height: 12),
                        const Text('Acceso restringido',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          'Tu rol actual no permite operar en Caja.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Adoptar caja local al usuario autenticado (si cambió de sesión)
            final cajaActiva = cajaService.cajaActiva;
            final uidNow = FirebaseAuth.instance.currentUser?.uid;
            final liveDeletePending = cajaService.liveDeletePending;
            if (cajaActiva != null &&
                uidNow != null &&
                cajaActiva.usuarioAperturaId != uidNow) {
              final nombreNow = (snap.data?.data()?['nombre'] as String?) ??
                  FirebaseAuth.instance.currentUser?.displayName ??
                  FirebaseAuth.instance.currentUser?.email ??
                  'Usuario';
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                // Usar la instancia capturada de cajaService en lugar de context.read
                try {
                  await cajaService.actualizarUsuarioSesion(uidNow, nombreNow);
                  await cajaService.pushLiveNow();
                } catch (_) {
                  // Ignorar fallos silenciosamente: la sincronización es opcional aquí.
                }
              });
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('Caja'),
                centerTitle: true,
                actions: [
                  if (isAdmin) ...[
                    IconButton(
                      tooltip: 'Abrir caja aquí',
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () =>
                          _mostrarDialogoAbrirCajaGenerico(context),
                    ),
                    if (cajaActiva != null) // 👈 solo cuando hay caja local
                      IconButton(
                        tooltip: 'Actualizar vista en vivo',
                        icon: const Icon(Icons.visibility_outlined),
                        onPressed: () =>
                            context.read<CajaService>().pushLiveNow(),
                      ),
                  ],
                ],
              ),
              backgroundColor: _ThemeColors.background,
              body: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
        child: cajaActiva != null
            ? _VistaCajaAbierta(
                key: ValueKey(cajaActiva.id), caja: cajaActiva)
            : (!isAdmin
                ? _VistaCajaCerrada(
                    key: const ValueKey('caja-cerrada'),
                    allowOpen: !isViewer,
                    isViewer: isViewer,
                  )
                : (liveDeletePending
                    ? _VistaCajaCerrada(
                        key: const ValueKey('caja-cerrada-pendiente'),
                        allowOpen: true,
                        isViewer: false,
                      )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('cajas_live')
                            .limit(1)
                            .snapshots(),
                        builder: (ctx2, s2) {
                          final hasLive =
                              (s2.data?.docs.isNotEmpty ?? false);
                          return hasLive
                              ? const _VistaCajasActivasAdmin(
                                  key: ValueKey('admin-live'))
                              : _VistaCajaCerrada(
                                  key: const ValueKey('caja-cerrada'),
                                  allowOpen: true,
                                  isViewer: false,
                                );
                        },
                      ))),
              ),
            );
          },
        );
      },
    );
  }
}

// -------- VISTA CAJA CERRADA (trabajador) --------
class _VistaCajaCerrada extends StatelessWidget {
  final bool allowOpen;
  final bool isViewer;
  const _VistaCajaCerrada({super.key, required this.allowOpen, required this.isViewer});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ThemeColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Gestión de Caja',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: _ThemeColors.accentText,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: _ThemeColors.cardBackground,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200, width: 2),
                  ),
                  child: const Icon(
                    Icons.point_of_sale_outlined,
                    size: 80,
                    color: _ThemeColors.inactive,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Caja Cerrada',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _ThemeColors.accentText,
                      ),
                ),
                const SizedBox(height: 8),
                if (!isViewer)
                  Text(
                    'Inicia una nueva sesión para comenzar a registrar ventas.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _ThemeColors.inactive,
                        ),
                  )
                else
                  Text(
                    'Modo espectador: no puedes abrir caja ni registrar acciones.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _ThemeColors.inactive,
                        ),
                  ),
                const SizedBox(height: 40),
                InkWell(
                  onTap: allowOpen ? () => _mostrarDialogoAbrirCajaGenerico(context) : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: allowOpen
                          ? const LinearGradient(
                              colors: [
                                _ThemeColors.primaryGradientStart,
                                _ThemeColors.primaryGradientEnd
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [
                                Colors.grey.shade400,
                                Colors.grey.shade500,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Iniciar Sesión de Caja',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -------- VISTA ADMIN: listado de cajas activas en vivo --------
class _VistaCajasActivasAdmin extends StatelessWidget {
  const _VistaCajasActivasAdmin({super.key});

  double _toDouble(dynamic v) =>
      (v is int) ? v.toDouble() : (v as num?)?.toDouble() ?? 0.0;
  int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('cajas_live');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: col.orderBy('lastUpdate', descending: true).snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No hay cajas activas'),
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  onPressed: () => _mostrarDialogoAbrirCajaGenerico(context),
                  label: const Text('Abrir nueva caja aquí'),
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  onPressed: () => _mostrarDialogoAbrirCajaGenerico(context),
                  label: const Text('Abrir nueva caja aquí'),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverList.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  final cajaId = (d['cajaId'] ?? docs[i].id).toString();
                  final nombre =
                      (d['usuarioNombre'] ?? 'Trabajador').toString();
                  final totalVentas = _toDouble(d['totalVentas']);
                  final ventasPend = _toInt(d['ventasPendientes']);
                  final elimPend = _toInt(d['ventasEliminadasPendientes']);
                  final estado = (d['estado'] ?? 'abierta').toString();

                  final fechaApertura = _asDate(d['fechaApertura']);
                  final montoInicial = _toDouble(d['montoInicial']);
                  final totalesPorMetodo =
                      Map<String, dynamic>.from(d['totalesPorMetodo'] ?? {});
                  final lastUpdate = _asDate(d['lastUpdate']);

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _ThemeColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                'Caja $cajaId • $nombre',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _ThemeColors.accentText,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  estado == 'abierta'
                                      ? Icons.circle
                                      : Icons.stop_circle_outlined,
                                  size: 10,
                                  color: estado == 'abierta'
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  estado == 'abierta' ? 'Abierta' : estado,
                                  style: const TextStyle(
                                      color: _ThemeColors.inactive),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              _ThemeColors.primaryGradientStart,
                              _ThemeColors.primaryGradientEnd
                            ],
                          ).createShader(
                              Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                          child: Text(
                            'S/ ${(montoInicial + totalVentas).toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                                fontSize: 36, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _InfoChip(
                              icon: Icons.keyboard_double_arrow_up_rounded,
                              label: 'Monto Inicial',
                              value: 'S/ ${montoInicial.toStringAsFixed(2)}',
                              color: Colors.blueGrey,
                            ),
                            _InfoChip(
                              icon: Icons.point_of_sale_rounded,
                              label: 'Total Ventas',
                              value: 'S/ ${totalVentas.toStringAsFixed(2)}',
                              color: Colors.green.shade600,
                            ),
                            _InfoChip(
                              icon: Icons.receipt_long_outlined,
                              label: 'Pendientes',
                              value: '$ventasPend',
                              color: Colors.indigo.shade600,
                            ),
                            _InfoChip(
                              icon: Icons.delete_forever_outlined,
                              label: 'Eliminadas',
                              value: '$elimPend',
                              color: _ThemeColors.dangerGradientStart,
                            ),
                          ],
                        ),
                        if (totalesPorMetodo.isNotEmpty) ...[
                          const Divider(height: 28),
                          Text(
                            'Ventas por método',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _ThemeColors.accentText.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: totalesPorMetodo.entries.map((e) {
                              final k = e.key.toString();
                              final v = _toDouble(e.value);
                              return _InfoChip(
                                icon: _getPaymentMethodIcon(k),
                                label: k,
                                value: 'S/ ${v.toStringAsFixed(2)}',
                                color: _getPaymentMethodColor(k),
                              );
                            }).toList(),
                          ),
                        ],
                        if (fechaApertura != null || lastUpdate != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (fechaApertura != null)
                                Text(
                                  'Abrió: ${DateFormat('dd/MM HH:mm').format(fechaApertura)}',
                                  style: const TextStyle(
                                      color: _ThemeColors.inactive,
                                      fontSize: 12),
                                ),
                              if (lastUpdate != null)
                                Text(
                                  'Actualizado: ${DateFormat('HH:mm:ss').format(lastUpdate)}',
                                  style: const TextStyle(
                                      color: _ThemeColors.inactive,
                                      fontSize: 12),
                                ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      _DetalleCajaActivaPage(cajaId: cajaId),
                                ));
                              },
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Ver detalle'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        );
      },
    );
  }
}

// -------- VISTA ADMIN: detalle de una caja activa (solo lectura) --------
class _DetalleCajaActivaPage extends StatelessWidget {
  final String cajaId;
  const _DetalleCajaActivaPage({required this.cajaId});

  double _toDouble(dynamic v) =>
      (v is int) ? v.toDouble() : (v as num?)?.toDouble() ?? 0.0;
  int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;
  List<Map<String, dynamic>> _asListMap(dynamic v) {
    if (v is List) {
      return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('cajas_live').doc(cajaId);

    return Scaffold(
      backgroundColor: _ThemeColors.background,
      appBar: AppBar(title: Text('Caja $cajaId (en vivo)')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Caja no disponible'));
          }
          final d = snap.data!.data()!;
          final nombre = (d['usuarioNombre'] ?? 'Trabajador').toString();
          final totalVentas = _toDouble(d['totalVentas']);
          final montoInicial = _toDouble(d['montoInicial']);
          final totalEstimado = montoInicial + totalVentas;
          final totalesPorMetodo =
              Map<String, dynamic>.from(d['totalesPorMetodo'] ?? {});
          final ventasPend = _toInt(d['ventasPendientes']);
          final elimPend = _toInt(d['ventasEliminadasPendientes']);
          final recientes = _asListMap(d['recientes']);
          final eliminadasRecientes = _asListMap(d['eliminadasRecientes']);
          final fechaApertura = _asDate(d['fechaApertura']);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeaderDashboardLive(
                  operador: nombre,
                  totalEstimado: totalEstimado,
                  montoInicial: montoInicial,
                  totalVentas: totalVentas,
                  totalesPorMetodo: {
                    for (final e in totalesPorMetodo.entries)
                      e.key.toString(): _toDouble(e.value),
                  },
                  fechaApertura: fechaApertura,
                  ventasPend: ventasPend,
                  elimPend: elimPend,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Continuar caja aquí'),
                          onPressed: () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) return;

                            final fecha = fechaApertura;
                            if (fecha == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'No se pudo leer la fecha de apertura.')),
                              );
                              return;
                            }

                            final mapa =
                                Map<String, dynamic>.from(totalesPorMetodo);
                            final mapaDouble = <String, double>{
                              for (final e in mapa.entries)
                                e.key.toString(): (e.value is num)
                                    ? (e.value as num).toDouble()
                                    : double.tryParse(e.value.toString()) ?? 0.0
                            };

                            await context
                                .read<CajaService>()
                                .continuarCajaDesdeLive(
                                  cajaId: cajaId,
                                  fechaApertura: fecha,
                                  montoInicial: montoInicial,
                                  totalVentas: totalVentas,
                                  totalesPorMetodo: mapaDouble,
                                  usuarioOriginalId:
                                      (d['usuarioId'] ?? '').toString(),
                                  usuarioOriginalNombre:
                                      (d['usuarioNombre'] ?? 'Trabajador')
                                          .toString(),
                                  cambiarOperadorAlActual: true,
                                );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Caja adoptada en este dispositivo.')),
                              );
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _ThemeColors.dangerGradientStart,
                          ),
                          onPressed: () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) return;

                            final params = await _pedirDatosCierre(
                              context,
                              minFecha: fechaApertura,
                              maxFecha: DateTime.now(),
                            );
                            if (params == null) return;

                            await context
                                .read<CajaService>()
                                .adminCerrarYGuardarCajaDesdeLive(
                                  cajaId: cajaId,
                                  adminUid: user.uid,
                                  adminNombre: user.displayName ?? user.email,
                                  montoContado: params.montoContado,
                                  fechaCierre: params.fechaCierre,
                                  motivo: params.motivo,
                                );

                            // Tras cierre remoto por admin, forzar rol "fuera de servicio" al operador original de esta caja
                            try {
                              final operadorUid = (d['usuarioId'] ?? '').toString();
                              if (operadorUid.isNotEmpty) {
                                final operadorSnap = await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(operadorUid)
                                    .get();
                                final rolOperador = (operadorSnap.data()?['rol'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                if (rolOperador != 'administrador') {
                                  // Si no es admin, pasarlo a fuera de servicio inmediatamente.
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(operadorUid)
                                      .update({'rol': 'fuera de servicio'});
                                }
                              }
                            } catch (_) {}

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Caja cerrada, guardada y eliminada del live.')),
                              );
                              Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.lock_clock_outlined),
                          label: const Text('Cerrar ahora (admin)'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Ventas recientes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _ThemeColors.accentText,
                        ),
                  ),
                ),
              ),
              if (recientes.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text('No hay ventas recientes.',
                          style: TextStyle(color: _ThemeColors.inactive)),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverList.separated(
                    itemBuilder: (_, i) => _LiveVentaCard(data: recientes[i]),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: recientes.length,
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Órdenes borradas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _ThemeColors.dangerGradientStart,
                        ),
                  ),
                ),
              ),
              if (eliminadasRecientes.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text('No hay ventas eliminadas recientes.',
                          style: TextStyle(color: _ThemeColors.inactive)),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.separated(
                    itemBuilder: (_, i) =>
                        _LiveVentaEliminadaCard(data: eliminadasRecientes[i]),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: eliminadasRecientes.length,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// -------- Header en vivo --------
class _HeaderDashboardLive extends StatelessWidget {
  final String operador;
  final double totalEstimado;
  final double montoInicial;
  final double totalVentas;
  final Map<String, double> totalesPorMetodo;
  final DateTime? fechaApertura;
  final int ventasPend;
  final int elimPend;

  const _HeaderDashboardLive({
    required this.operador,
    required this.totalEstimado,
    required this.montoInicial,
    required this.totalVentas,
    required this.totalesPorMetodo,
    required this.fechaApertura,
    required this.ventasPend,
    required this.elimPend,
  });

  @override
  Widget build(BuildContext context) {
    final hora = fechaApertura != null
        ? DateFormat('hh:mm a', 'es_ES').format(fechaApertura!)
        : null;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ThemeColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  'Caja en vivo — $operador',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _ThemeColors.accentText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (hora != null)
                Text(
                  'Inició: $hora',
                  style: const TextStyle(
                      fontSize: 14, color: _ThemeColors.inactive),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  _ThemeColors.primaryGradientStart,
                  _ThemeColors.primaryGradientEnd
                ],
              ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              child: Text(
                'S/ ${totalEstimado.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                    fontSize: 48, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const Divider(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InfoChip(
                icon: Icons.keyboard_double_arrow_up_rounded,
                label: 'Monto Inicial',
                value: 'S/ ${montoInicial.toStringAsFixed(2)}',
                color: Colors.blueGrey,
              ),
              _InfoChip(
                icon: Icons.point_of_sale_rounded,
                label: 'Total Ventas',
                value: 'S/ ${totalVentas.toStringAsFixed(2)}',
                color: Colors.green.shade600,
              ),
              _InfoChip(
                icon: Icons.receipt_long_outlined,
                label: 'Pendientes',
                value: '$ventasPend',
                color: Colors.indigo.shade600,
              ),
              _InfoChip(
                icon: Icons.delete_forever_outlined,
                label: 'Eliminadas',
                value: '$elimPend',
                color: _ThemeColors.dangerGradientStart,
              ),
            ],
          ),
          if (totalesPorMetodo.isNotEmpty) ...[
            const Divider(height: 32),
            Text(
              'Ventas por Método de Pago',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _ThemeColors.accentText.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: totalesPorMetodo.entries.map((e) {
                final k = e.key;
                final v = e.value;
                return _InfoChip(
                  icon: _getPaymentMethodIcon(k),
                  label: k,
                  value: 'S/ ${v.toStringAsFixed(2)}',
                  color: _getPaymentMethodColor(k),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// -------- Tarjetas de ventas en vivo --------
class _LiveVentaCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LiveVentaCard({required this.data});

  double _toDouble(dynamic v) =>
      (v is int) ? v.toDouble() : (v as num?)?.toDouble() ?? 0.0;
  int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final id = (data['id'] ?? '').toString();
    final total = _toDouble(data['total']);
    final items = _toInt(data['items']);
    final fecha = _asDate(data['fecha']);
    final pagos = Map<String, dynamic>.from(data['pagos'] ?? {});
    final lineas = (data['lineas'] is List)
        ? (data['lineas'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()
        : const <Map<String, dynamic>>[];
    final metodos = pagos.keys.join(', ');

    return Container(
      decoration: BoxDecoration(
        color: _ThemeColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.only(left: 20, right: 8),
        leading: CircleAvatar(
          backgroundColor: _ThemeColors.primaryGradientEnd.withOpacity(0.1),
          foregroundColor: _ThemeColors.primaryGradientEnd,
          child: const Icon(Icons.receipt_long_outlined),
        ),
        title: Text(
          'Venta $id — S/ ${total.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$items item(s) • $metodos',
          style: const TextStyle(color: _ThemeColors.inactive),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fecha != null)
              Text(
                DateFormat('hh:mm a').format(fecha),
                style: const TextStyle(color: _ThemeColors.inactive),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...lineas.map((l) => _buildLinea(l)),
        ],
      ),
    );
  }

  Widget _buildLinea(Map<String, dynamic> l) {
    final nombre = (l['nombre'] ?? '').toString();
    final categoria = (l['categoria'] ?? '').toString().trim();
    final cantidad = _toInt(l['cantidad']);
    final subtotal = _toDouble(l['subtotal']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(
                  '• ${cantidad}x $nombre${categoria.isNotEmpty ? '  ·  $categoria' : ''}')),
          Text('S/ ${subtotal.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}

class _LiveVentaEliminadaCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LiveVentaEliminadaCard({required this.data});

  double _toDouble(dynamic v) =>
      (v is int) ? v.toDouble() : (v as num?)?.toDouble() ?? 0.0;
  int _toInt(dynamic v) => (v as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final id = (data['id'] ?? '').toString();
    final total = _toDouble(data['total']);
    final items = _toInt(data['items']);
    final fecha = _asDate(data['fecha']);
    final pagos = Map<String, dynamic>.from(data['pagos'] ?? {});
    final metodos = pagos.keys.join(', ');
    final lineas = (data['lineas'] is List)
        ? (data['lineas'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()
        : const <Map<String, dynamic>>[];

    return Opacity(
      opacity: 0.85,
      child: Card(
        color: _ThemeColors.dangerGradientStart.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: _ThemeColors.dangerGradientStart.withOpacity(0.2)),
        ),
        elevation: 0,
        child: ExpansionTile(
          shape: const Border(),
          tilePadding: const EdgeInsets.only(left: 20, right: 8),
          leading: CircleAvatar(
            backgroundColor: _ThemeColors.dangerGradientStart.withOpacity(0.15),
            foregroundColor: _ThemeColors.dangerGradientStart,
            child: const Icon(Icons.delete_forever_outlined),
          ),
          title: Text(
            'Eliminada $id — S/ ${total.toStringAsFixed(2)}',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.lineThrough),
          ),
          subtitle: Text(
            '$items item(s) • $metodos',
            style: const TextStyle(color: _ThemeColors.inactive),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fecha != null)
                Text(
                  DateFormat('hh:mm a').format(fecha),
                  style: const TextStyle(color: _ThemeColors.inactive),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...lineas.map((l) => _buildLinea(l)),
          ],
        ),
      ),
    );
  }

  Widget _buildLinea(Map<String, dynamic> l) {
    final nombre = (l['nombre'] ?? '').toString();
    final categoria = (l['categoria'] ?? '').toString().trim();
    final cantidad = _toInt(l['cantidad']);
    final subtotal = _toDouble(l['subtotal']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(
                  '• ${cantidad}x $nombre${categoria.isNotEmpty ? '  ·  $categoria' : ''}')),
          Text('S/ ${subtotal.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}

// -------- VISTA CAJA ABIERTA (trabajador/admin) --------
class _VistaCajaAbierta extends StatelessWidget {
  final Caja caja;
  const _VistaCajaAbierta({super.key, required this.caja});

  @override
  Widget build(BuildContext context) {
    final ventasDeLaSesion = context.watch<CajaService>().ventasLocales;
    final ventasMostradas = ventasDeLaSesion.reversed.toList();
    final ventasEliminadas = context.watch<CajaService>().ventasEliminadas;
    final adoptada = context.watch<CajaService>().adoptadaLocalmente;

    // Leemos rol para decidir si mostramos "Devolver caja"
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final userDoc = (uid != null)
        ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots()
        : const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();

    void mostrarDialogoCerrarCaja() {
      final formKey = GlobalKey<FormState>();
      final totalEstimado = caja.montoInicial + caja.totalVentas;
      final controller =
          TextEditingController(text: totalEstimado.toStringAsFixed(2));
      final cajaService = context.read<CajaService>();
      bool isCerrando = false;

      DateTime fechaSeleccionada = DateTime.now();

      Future<void> seleccionarFechaHora(
        BuildContext dialogContext,
        StateSetter setDialogState,
      ) async {
        final now = DateTime.now();
        final apertura = caja.fechaApertura;
        final initialDate = (fechaSeleccionada.isBefore(apertura) ||
                fechaSeleccionada.isAfter(now))
            ? now
            : fechaSeleccionada;

        final pickedDate = await showDatePicker(
          context: dialogContext,
          initialDate: initialDate,
          firstDate: apertura,
          lastDate: now,
        );
        if (pickedDate == null) return;
        final pickedTime = await showTimePicker(
          context: dialogContext,
          initialTime: TimeOfDay.fromDateTime(fechaSeleccionada),
        );
        if (pickedTime == null) return;

        final combinado = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        if (combinado.isBefore(apertura)) {
          if (mainScaffoldContext != null) {
            mostrarNotificacionElegante(
              mainScaffoldContext!,
              'La fecha/hora de cierre no puede ser anterior a la apertura.',
              esError: true,
              messengerKey: principalMessengerKey,
            );
          }
          return;
        }
        if (combinado.isAfter(now)) {
          if (mainScaffoldContext != null) {
            mostrarNotificacionElegante(
              mainScaffoldContext!,
              'La fecha/hora de cierre no puede ser futura.',
              esError: true,
              messengerKey: principalMessengerKey,
            );
          }
          return;
        }
        setDialogState(() => fechaSeleccionada = combinado);
      }

      showDialog(
        context: context,
        barrierDismissible: !isCerrando,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              // Capturar servicio antes de operaciones async que pueden desmontar este build context
              final authSvc = Provider.of<AuthService>(context, listen: false);
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('Cerrar Caja'),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                          'Ingresa el monto final contado en caja para calcular la diferencia.'),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Monto Contado (S/)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        autofocus: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'El monto es requerido.';
                          }
                          if (double.tryParse(v.replaceAll(',', '.')) == null) {
                            return 'Por favor, ingrese un número válido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule_rounded),
                        title: const Text('Fecha y hora de cierre'),
                        subtitle: Text(DateFormat('dd/MM/yyyy HH:mm')
                            .format(fechaSeleccionada)),
                        trailing: TextButton.icon(
                          icon: const Icon(Icons.edit_calendar_outlined),
                          label: const Text('Cambiar'),
                          onPressed: () => seleccionarFechaHora(
                              dialogContext, setDialogState),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isCerrando
                        ? null
                        : () {
                            final nav = (mainScaffoldContext != null)
                                ? Navigator.of(mainScaffoldContext!,
                                    rootNavigator: true)
                                : Navigator.of(dialogContext,
                                    rootNavigator: true);
                            if (nav.mounted && nav.canPop()) nav.pop();
                          },
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
          onPressed: isCerrando
                        ? null
                        :  () async {
                            if (formKey.currentState?.validate() ?? false) {
                              setDialogState(() => isCerrando = true);
                // Cerrar teclado para evitar re-composiciones durante el cierre
                FocusManager.instance.primaryFocus?.unfocus();
                final navigator = (mainScaffoldContext != null)
                  ? Navigator.of(mainScaffoldContext!,
                    rootNavigator: true)
                  : Navigator.of(dialogContext,
                    rootNavigator: true);
                              try {
                                final monto = double.parse(
                                    controller.text.replaceAll(',', '.'));

                                // Antes de cerrar, verificar si existe gasto de apertura
                                final tieneGastoApertura =
                                    cajaService.gastosLocales.any((g) =>
                                        (g.tipo ?? '') == 'insumos_apertura');

                                if (!tieneGastoApertura) {
                                  // Mostrar diálogo para registrar gasto de apertura y ESPERAR confirmación

                                  // Mostrar el diálogo de insumos encima DEL diálogo actual
                                  // para evitar que se desmonte el diálogo padre al cerrar/confirmar.
                                  final registrado = await showGastoInsumosAperturaDialog(
                                      dialogContext, caja,
                                      useRootNavigator: false);

                                  // Si NO se presionó Registrar, abortar el cierre
                                  if (registrado != true) {
                                    if (dialogContext.mounted) {
                                      setDialogState(() => isCerrando = false);
                                    }
                                    if (navigator.mounted) {
                                      // Si el usuario canceló y la caja aún está abierta, nada más.
                                    }
                                    return;
                                  }
                                }

                                // Intentar cerrar ahora que existe el gasto de apertura
                                await cajaService.cerrarCaja(
                                  montoContado: monto,
                                  fechaCierreSeleccionada: fechaSeleccionada,
                                );

                                // Capturar montos para el diálogo
                                final montoEsperado = caja.montoInicial + caja.totalVentas;

                                // Al cerrar caja: si el usuario no es admin, poner rol "fuera de servicio"
                                try {
                                  final uid = FirebaseAuth.instance.currentUser?.uid;
                                  if (uid != null) {
                                    final userSnap = await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(uid)
                                        .get();
                                    final rol =
                                        (userSnap.data()?['rol'] ?? '')
                                            .toString()
                                            .toLowerCase();
                                    if (rol != 'administrador') {
                                      await authSvc.updateUserRole(uid, 'fuera de servicio');
                                    }

                                    // Si la caja fue originalmente abierta por otro usuario (p.ej. admin adoptó y cierra),
                                    // también actualizar su rol a "fuera de servicio".
                                    try {
                                      final originalUid = caja.usuarioAperturaId;
                                      if (originalUid.isNotEmpty && originalUid != uid) {
                                        final originalSnap = await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(originalUid)
                                            .get();
                                        final rolOriginal = (originalSnap.data()?['rol'] ?? '')
                                            .toString()
                                            .toLowerCase();
                                        if (rolOriginal != 'administrador') {
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(originalUid)
                                              .update({'rol': 'fuera de servicio'});
                                        }
                                      }
                                    } catch (_) {}
                                  }
                                } catch (_) {}

                                if (navigator.mounted && navigator.canPop()) {
                                  navigator.pop();
                                }
                                if (mainScaffoldContext != null && mainScaffoldContext!.mounted) {
                                  await showCajaClosedDialog(
                                    mainScaffoldContext!,
                                    montoContado: monto,
                                    montoEsperado: montoEsperado,
                                    motivo: 'Cierre de sesión',
                                  );
                                }
                              } catch (e) {
                                if (mainScaffoldContext != null) {
                                  mostrarNotificacionElegante(
                                    mainScaffoldContext!,
                                    'Error al cerrar la caja: $e',
                                    esError: true,
                                    messengerKey: principalMessengerKey,
                                  );
                                }
                              } finally {
                                if (dialogContext.mounted) {
                                  setDialogState(() => isCerrando = false);
                                }
                              }
                            }
                          },
                    child: isCerrando
                        ? _ModernLoadingWidget()
                        : const Text('Sí, Cerrar Caja'),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDoc,
      builder: (context, snap) {
        final rol = ((snap.data?.data()?['rol'] ?? 'trabajador')
                .toString()
                .trim())
            .toLowerCase();
        final isAdmin = rol == 'administrador';
        final isViewer = rol == 'espectador';

        return Scaffold(
          backgroundColor: _ThemeColors.background,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _HeaderDashboard(caja: caja)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Historial de Ventas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _ThemeColors.accentText,
                        ),
                  ),
                ),
              ),
              if (ventasMostradas.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'Aún no hay ventas en esta sesión.',
                        style: TextStyle(color: _ThemeColors.inactive),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16, 0),
                  sliver: SliverList.separated(
                    itemBuilder: (context, index) =>
                        _VentaCard(venta: ventasMostradas[index]),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemCount: ventasMostradas.length,
                  ),
                ),
              if (ventasEliminadas.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Órdenes Borradas',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _ThemeColors.dangerGradientStart,
                          ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16, 96),
                  sliver: SliverList.separated(
                    itemBuilder: (context, index) =>
                        _VentaEliminadaCard(venta: ventasEliminadas[index]),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemCount: ventasEliminadas.length,
                  ),
                ),
              ] else
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
          // FABs según rol/adopción
      floatingActionButton: isViewer
        ? null
        : isAdmin
              ? (adoptada
                  // Admin + ADOPTADA: mostrar Devolver + Cerrar
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.extended(
                          heroTag: 'fab_devolver_${caja.id}',
                          onPressed: () async {
                            await context
                                .read<CajaService>()
                                .devolverCajaAlTrabajador();
                            if (context.mounted) {
                              mostrarNotificacionElegante(
                                  context, 'Caja devuelta al trabajador.',
                                  messengerKey: principalMessengerKey);
                            }
                          },
                          label: const Text('Devolver caja',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          icon: const Icon(Icons.undo_rounded),
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        FloatingActionButton.extended(
                          heroTag: 'fab_cerrar_${caja.id}',
                          onPressed: mostrarDialogoCerrarCaja,
                          label: const Text('Cerrar Caja',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          icon: const Icon(Icons.archive_outlined),
                          extendedPadding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          backgroundColor: _ThemeColors.dangerGradientStart,
                          foregroundColor: Colors.white,
                          elevation: 4,
                        ),
                      ],
                    )
                  // Admin + NO adoptada (abierta por el admin): SOLO Cerrar
                  : FloatingActionButton.extended(
                      heroTag: 'fab_cerrar_${caja.id}',
                      onPressed: mostrarDialogoCerrarCaja,
                      label: const Text('Cerrar Caja',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      icon: const Icon(Icons.archive_outlined),
                      extendedPadding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      backgroundColor: _ThemeColors.dangerGradientStart,
                      foregroundColor: Colors.white,
                      elevation: 4,
                    ))
              // Trabajador: solo Cerrar
              : FloatingActionButton.extended(
                  heroTag: 'fab_cerrar_${caja.id}',
                  onPressed: mostrarDialogoCerrarCaja,
                  label: const Text('Cerrar Caja',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  icon: const Icon(Icons.archive_outlined),
                  extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  backgroundColor: _ThemeColors.dangerGradientStart,
                  foregroundColor: Colors.white,
                  elevation: 4,
                ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}

// -------- Widgets y helpers existentes --------
void _mostrarDialogoEditarMontoInicial(BuildContext context, Caja caja) {
  final formKey = GlobalKey<FormState>();
  final controller =
      TextEditingController(text: caja.montoInicial.toStringAsFixed(2));
  final cajaService = context.read<CajaService>();
  controller.selection =
      TextSelection(baseOffset: 0, extentOffset: controller.value.text.length);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Center(
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(
              parent: ModalRoute.of(dialogContext)?.animation ?? const AlwaysStoppedAnimation<double>(1.0),
              curve: Curves.elasticOut,
            ),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
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
                // Icono con gradiente
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.purple.shade400,
                        Colors.purple.shade600,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                // Título
                const Text(
                  'Editar Monto Inicial',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ingresa el nuevo monto inicial en caja',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Formulario
                Form(
                  key: formKey,
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Nuevo Monto (S/)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.monetization_on_rounded),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'El monto es requerido.';
                      if (double.tryParse(v.replaceAll(',', '.')) == null) {
                        return 'Monto inválido.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),
                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final nuevoMonto =
                                double.parse(controller.text.replaceAll(',', '.'));
                            try {
                              await cajaService.actualizarMontoInicial(nuevoMonto);
                              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                              if (context.mounted) {
                                mostrarNotificacionElegante(
                                    context, 'Monto inicial actualizado.',
                                    messengerKey: principalMessengerKey);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                mostrarNotificacionElegante(context, 'Error: $e',
                                    esError: true, messengerKey: principalMessengerKey);
                              }
                            }
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.w600)),
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

class _HeaderDashboard extends StatelessWidget {
  final Caja caja;
  const _HeaderDashboard({required this.caja});

  @override
  Widget build(BuildContext context) {
    final totalEstimado = caja.montoInicial + caja.totalVentas;
    final horaApertura =
        DateFormat('hh:mm a', 'es_ES').format(caja.fechaApertura);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ThemeColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Flexible(
                child: Text(
                  'Total Estimado en Caja',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _ThemeColors.accentText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Inició: $horaApertura',
                style:
                    const TextStyle(fontSize: 14, color: _ThemeColors.inactive),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  _ThemeColors.primaryGradientStart,
                  _ThemeColors.primaryGradientEnd
                ],
              ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              child: Text(
                'S/ ${totalEstimado.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const Divider(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InfoChip(
                icon: Icons.keyboard_double_arrow_up_rounded,
                label: 'Monto Inicial',
                value: 'S/ ${caja.montoInicial.toStringAsFixed(2)}',
                color: Colors.blueGrey,
                onTap: () => _mostrarDialogoEditarMontoInicial(context, caja),
              ),
              _InfoChip(
                icon: Icons.point_of_sale_rounded,
                label: 'Total Ventas',
                value: 'S/ ${caja.totalVentas.toStringAsFixed(2)}',
                color: Colors.green.shade600,
              ),
              if (caja.totalGastos > 0)
                _InfoChip(
                  icon: Icons.money_off_rounded,
                  label: 'Total Gastos',
                  value: 'S/ ${caja.totalGastos.toStringAsFixed(2)}',
                  color: Colors.red.shade400,
                ),
            ],
          ),
          if (caja.totalesPorMetodo.isNotEmpty) ...[
            const Divider(height: 32),
            Text(
              'Ventas por Método de Pago',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _ThemeColors.accentText.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: caja.totalesPorMetodo.entries
                  .map(
                    (e) => _InfoChip(
                      icon: _getPaymentMethodIcon(e.key),
                      label: e.key,
                      value: 'S/ ${e.value.toStringAsFixed(2)}',
                      color: _getPaymentMethodColor(e.key),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipContent = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: _ThemeColors.accentText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(
                Icons.edit_outlined,
                size: 16,
                color: _ThemeColors.inactive,
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: chipContent,
        ),
      );
    }
    return chipContent;
  }
}

class _VentaCard extends StatelessWidget {
  final Venta venta;
  const _VentaCard({required this.venta});

  @override
  Widget build(BuildContext context) {
    final cajaService = context.read<CajaService>();
    final notificationContext =
      mainScaffoldContext ?? navigatorKey.currentContext ?? context;

    void mostrarDialogoConfirmarBorrado() {
      showModernConfirmDialog(
        context,
        title: 'Confirmar Eliminación',
        message: '¿Eliminar la venta de S/ ${venta.total.toStringAsFixed(2)}?',
        confirmText: 'Sí, eliminar',
        cancelText: 'Cancelar',
        confirmColor: _ThemeColors.dangerGradientStart,
        icon: Icons.delete_outline_rounded,
      ).then((confirmed) async {
        if (confirmed == true) {
          var localSuccess = true;
          try {
            await cajaService.eliminarVentaLocal(venta);
          } catch (_) {
            localSuccess = false;
          }

          try {
            await cajaService.registrarVentaEliminada(venta);
          } catch (_) {
            // El registro remoto puede reintentar al reconectar; no bloquear la UX.
          }

          mostrarNotificacionElegante(
            notificationContext,
            localSuccess
                ? 'Venta eliminada (se registrará al cerrar la caja).'
                : 'No se pudo eliminar la venta. Intenta nuevamente.',
            esError: !localSuccess,
            messengerKey: principalMessengerKey,
          );
        }
      });
    }

    final itemsAgrupados =
        groupBy(venta.items, (VentaItem item) => item.producto.id);
    final metodosDePago = venta.pagos.keys.join(', ');

    return Container(
      decoration: BoxDecoration(
        color: _ThemeColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.only(left: 20, right: 8),
        leading: CircleAvatar(
          backgroundColor: _ThemeColors.primaryGradientEnd.withOpacity(0.1),
          foregroundColor: _ThemeColors.primaryGradientEnd,
          child: const Icon(Icons.receipt_long_outlined),
        ),
        title: Text(
          'Venta - S/ ${venta.total.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${venta.items.length} item(s) • $metodosDePago',
          style: const TextStyle(color: _ThemeColors.inactive),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('hh:mm a').format(venta.fecha),
              style: const TextStyle(color: _ThemeColors.inactive),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: _ThemeColors.dangerGradientStart),
              onPressed: mostrarDialogoConfirmarBorrado,
              tooltip: 'Eliminar Venta',
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...itemsAgrupados.entries.map((entry) {
            final primerItem = entry.value.first;
            final cantidad = entry.value.length;
            final cat = _catNombre(primerItem.producto);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '• ${cantidad}x ${primerItem.producto.nombre}${cat.isNotEmpty ? '  ·  $cat' : ''}',
                    ),
                  ),
                  Text(
                      'S/ ${(primerItem.precioEditable * cantidad).toStringAsFixed(2)}'),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _VentaEliminadaCard extends StatelessWidget {
  final Venta venta;
  const _VentaEliminadaCard({required this.venta});

  @override
  Widget build(BuildContext context) {
    final metodosDePago = venta.pagos.keys.join(', ');
    return Opacity(
      opacity: 0.7,
      child: Card(
        color: _ThemeColors.dangerGradientStart.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _ThemeColors.dangerGradientStart.withOpacity(0.2),
          ),
        ),
        elevation: 0,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _ThemeColors.dangerGradientStart.withOpacity(0.2),
            foregroundColor: _ThemeColors.dangerGradientStart,
            child: const Icon(Icons.delete_forever_outlined),
          ),
          title: Text(
            'Venta Eliminada - S/ ${venta.total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          subtitle: Text(
            '${venta.items.length} item(s) • $metodosDePago',
            style: const TextStyle(color: _ThemeColors.inactive),
          ),
          trailing: Text(DateFormat('hh:mm a').format(venta.fecha)),
        ),
      ),
    );
  }
}

// --- Widget de carga moderno y animado ---
class _ModernLoadingWidget extends StatefulWidget {
  @override
  _ModernLoadingWidgetState createState() => _ModernLoadingWidgetState();
}

class _ModernLoadingWidgetState extends State<_ModernLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Controlador para el efecto pulsante
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Controlador para la rotación
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // Controlador para la escala
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // Iniciar animaciones
    _scaleController.forward();
    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseAnimation,
        _rotationAnimation,
        _scaleAnimation,
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Círculo pulsante con gradiente
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Transform.rotate(
                    angle: _rotationAnimation.value * 2 * 3.14159,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.8),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.sync_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Texto animado con efecto de aparición
              AnimatedOpacity(
                // elasticOut puede sobrepasar 1.0, por eso limitamos el rango seguro 0..1
                opacity: _scaleAnimation.value.clamp(0.0, 1.0).toDouble(),
                duration: const Duration(milliseconds: 300),
                child: const Text(
                  'Cerrando caja...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- Auxiliares ---
IconData _getPaymentMethodIcon(String key) {
  switch (key) {
    case 'Efectivo':
      return Icons.money_rounded;
    case 'Tarjeta':
      return Icons.credit_card_rounded;
      case 'IziPay Yape':
      case 'Yape Personal':
      case 'Yape':
        return Icons.qr_code_2_rounded;
    default:
      return Icons.payment_rounded;
  }
}

Color _getPaymentMethodColor(String key) {
  switch (key) {
    case 'Efectivo':
      return Colors.green.shade600;
    case 'Tarjeta':
      return Colors.indigo.shade600;
    case 'IziPay Yape':
    case 'Yape Personal':
    case 'Yape':
      return Colors.deepPurple.shade400;
    default:
      return Colors.grey.shade600;
  }
}
