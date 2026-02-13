import 'package:flutter/material.dart';

/// Diálogo moderno con estilo consistente (similar a panel_pago)
class ModernDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> content;
  final List<Widget>? actions;
  final Color? primaryColor;
  final IconData? icon;
  final bool showIcon;

  const ModernDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.content,
    this.actions,
    this.primaryColor,
    this.icon,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = primaryColor ?? Colors.blue.shade600;

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Center(
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(
              parent:
                  ModalRoute.of(context)?.animation ?? const AlwaysStoppedAnimation<double>(1.0),
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
                if (showIcon && icon != null)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withOpacity(0.7),
                          color,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                if (showIcon && icon != null) const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                ],
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  ...content,
                ],
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  if (actions!.length == 1)
                    actions![0]
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: actions!,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Diálogo de confirmación moderno
Future<bool?> showModernConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmText = 'Confirmar',
  String? cancelText = 'Cancelar',
  Color? confirmColor,
  IconData? icon = Icons.help_outline_rounded,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ModernDialog(
      title: title,
      subtitle: message,
      primaryColor: confirmColor,
      icon: icon,
      content: [],
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelText ?? 'Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: confirmColor ?? Colors.blue.shade600,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText ?? 'Confirmar'),
        ),
      ],
    ),
  );
}

/// Diálogo de éxito moderno
Future<void> showModernSuccessDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? buttonText = 'Continuar',
  VoidCallback? onDismiss,
  List<Widget>? contentWidgets,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ModernDialog(
      title: title,
      subtitle: subtitle,
      primaryColor: Colors.green.shade600,
      icon: Icons.check_circle_rounded,
      content: contentWidgets ?? [],
      actions: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              onDismiss?.call();
            },
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              buttonText ?? 'Continuar',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Diálogo de error moderno
Future<void> showModernErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? buttonText = 'Entendido',
  VoidCallback? onDismiss,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ModernDialog(
      title: title,
      subtitle: message,
      primaryColor: Colors.red.shade600,
      icon: Icons.error_outline_rounded,
      content: [],
      actions: [
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            onDismiss?.call();
          },
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: Text(
            buttonText ?? 'Entendido',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Diálogo de advertencia moderno
Future<void> showModernWarningDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? buttonText = 'Entendido',
  VoidCallback? onDismiss,
  List<Widget>? contentWidgets,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ModernDialog(
      title: title,
      subtitle: message,
      primaryColor: Colors.amber.shade600,
      icon: Icons.warning_amber_rounded,
      content: contentWidgets ?? [],
      actions: [
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            onDismiss?.call();
          },
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: Text(
            buttonText ?? 'Entendido',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.amber.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Diálogo de información moderno
Future<void> showModernInfoDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? buttonText = 'Entendido',
  VoidCallback? onDismiss,
  List<Widget>? contentWidgets,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ModernDialog(
      title: title,
      subtitle: subtitle,
      primaryColor: Colors.blue.shade600,
      icon: Icons.info_outline_rounded,
      content: contentWidgets ?? [],
      actions: [
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            onDismiss?.call();
          },
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: Text(
            buttonText ?? 'Entendido',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Diálogo de caja iniciada correctamente
Future<void> showCajaInitiatedDialog(
  BuildContext context, {
  bool isGuest = false,
  VoidCallback? onDismiss,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ModernDialog(
      title: isGuest ? 'Caja Iniciada (Invitado)' : 'Caja Iniciada',
      subtitle: isGuest
          ? 'Funcionando en modo invitado (offline)'
          : 'La caja se ha abierto correctamente',
      primaryColor: Colors.green.shade600,
      icon: Icons.check_circle_rounded,
      content: [
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
                  Icon(Icons.check_rounded, size: 18, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lista para registrar ventas',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              if (isGuest) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 18, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Se sincronizará cuando regrese internet',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
      actions: [
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            onDismiss?.call();
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
            backgroundColor: Colors.green.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Diálogo de caja cerrada correctamente
Future<void> showCajaClosedDialog(
  BuildContext context, {
  required double montoContado,
  required double montoEsperado,
  required String motivo,
  VoidCallback? onDismiss,
}) {
  final diferencia = montoContado - montoEsperado;
  final sobrante = diferencia > 0;

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ModernDialog(
      title: 'Caja Cerrada',
      subtitle: 'La caja se ha cerrado y guardado correctamente',
      primaryColor: Colors.blue.shade600,
      icon: Icons.lock_clock_rounded,
      content: [
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
                  Icon(Icons.receipt_long_rounded, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Monto Esperado:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    'S/ ${montoEsperado.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.monetization_on_rounded, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Monto Contado:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    'S/ ${montoContado.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sobrante ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sobrante ? Colors.green.shade300 : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      sobrante ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 18,
                      color: sobrante ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Diferencia:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: sobrante ? Colors.green.shade700 : Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${sobrante ? '+' : ''}S/ ${diferencia.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: sobrante ? Colors.green.shade900 : Colors.orange.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      actions: [
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            onDismiss?.call();
          },
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: const Text(
            'Entendido',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Diálogo de caja descartada
Future<void> showCajaDiscardedDialog(
  BuildContext context, {
  VoidCallback? onDismiss,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ModernDialog(
      title: 'Caja Descartada',
      subtitle: 'La caja local ha sido descartada',
      primaryColor: Colors.orange.shade600,
      icon: Icons.delete_outline_rounded,
      content: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Los datos locales se han eliminado. Puedes abrir una nueva caja.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      actions: [
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            onDismiss?.call();
          },
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: const Text(
            'Entendido',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.orange.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    ),
  );
}

