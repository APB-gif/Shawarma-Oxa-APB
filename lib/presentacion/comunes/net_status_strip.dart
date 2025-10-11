// lib/presentacion/comunes/net_status_strip.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Prefijo para nuestra comprobación real de internet
import 'package:shawarma_pos_nuevo/core/net/connectivity_utils.dart' as net;

// Traemos SOLO las keys globales desde main.dart (sin mezclar hide/show)
import 'package:shawarma_pos_nuevo/main.dart' show navigatorKey, scaffoldMessengerKey;

import 'package:shawarma_pos_nuevo/datos/servicios/auth/auth_service.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/caja_service.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/servicio_gastos.dart';
import 'package:shawarma_pos_nuevo/presentacion/auth/auth_gate.dart';

/// Tira superior de estado de red + acciones de reconexión/sync.
///
/// Casos:
///  - 🔴 Sin internet => tira roja visible para todos.
///  - 🟢 Internet volvió + modo invitado => botón "Iniciar sesión".
///  - 🟢 Internet volvió + usuario autenticado => botón "Sincronizar ahora"
///    (Caja/Gastos) + opcional auto-sync.
class NetStatusStrip extends StatefulWidget {
  const NetStatusStrip({
    super.key,
    this.syncCaja = true,
    this.syncGastos = true,
    this.autoSyncOnBackOnline = true, // intenta sincronizar cuando vuelve internet (si hay user)
    this.showGreenForAuthed = true,   // muestra banner verde con botón "Sincronizar" para usuarios autenticados
  });

  final bool syncCaja;
  final bool syncGastos;
  final bool autoSyncOnBackOnline;
  final bool showGreenForAuthed;

  @override
  State<NetStatusStrip> createState() => _NetStatusStripState();
}

class _NetStatusStripState extends State<NetStatusStrip> {
  bool _online = true;
  StreamSubscription? _connSub;
  Timer? _poller;
  bool _working = false;
  bool _justCameOnline = false; // para mostrar 1 vez el verde cuando vuelve la red

  @override
  void initState() {
    super.initState();

    // 1) Suscripción a cambios (soporta firma de v3 y v6+ del plugin)
    _connSub = Connectivity().onConnectivityChanged.listen((event) async {
      final nowOnline = await _eventToOnline(event);
      if (!mounted) return;
      if (_online != nowOnline) {
        setState(() {
          _online = nowOnline;
          _justCameOnline = nowOnline; // se activará la tira verde
        });
        if (nowOnline && widget.autoSyncOnBackOnline) {
          _maybeAutoSync();
        }
      }
    });

    // 2) Poll defensivo (cautivo/DNS) cada 8s
    _poller = Timer.periodic(const Duration(seconds: 8), (_) async {
      final ok = await net.hasInternet();
      if (!mounted) return;
      if (_online != ok) {
        setState(() {
          _online = ok;
          _justCameOnline = ok;
        });
        if (ok && widget.autoSyncOnBackOnline) {
          _maybeAutoSync();
        }
      }
    });

    // 3) Estado inicial confiable
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = await net.hasInternet();
      if (mounted) {
        setState(() {
          _online = ok;
          _justCameOnline = false; // no parpadear en verde al abrir la pantalla
        });
      }
    });
  }

  Future<bool> _eventToOnline(dynamic event) async {
    // event puede ser ConnectivityResult (v3) o List<ConnectivityResult> (v6+)
    if (event is ConnectivityResult) {
      if (event == ConnectivityResult.none) return false;
      return await net.hasInternet();
    }
    if (event is List<ConnectivityResult>) {
      if (event.isEmpty || event.contains(ConnectivityResult.none)) return false;
      return await net.hasInternet();
    }
    // Fallback con verificación real
    return await net.hasInternet();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _poller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final hasUser = auth.currentUser != null;

    // 🔴 Sin internet => siempre mostrar
    if (!_online) {
      return _buildStrip(
        bg: Colors.red.shade700,
        icon: Icons.wifi_off,
        text: 'Sin conexión a internet',
        trailing: null,
      );
    }

    // Escucha reactiva del modo invitado (ValueNotifier)
    return ValueListenableBuilder<bool>(
      valueListenable: auth.offlineListenable,
      builder: (_, isOfflineMode, __) {
    // 🟢 Con internet + sin usuario (invitado) => botón de login
    if (_online && (!hasUser || isOfflineMode)) {
      return _buildStrip(
        bg: Colors.green.shade600,
        icon: Icons.wifi,
        text: 'Conexión restablecida. Estás en modo invitado.',
        trailing: _actionButton(
          label: _working ? 'Conectando...' : 'Iniciar sesión',
          icon: _working ? null : Icons.login,
          busy: _working,
          onTap: _working ? null : () => _handleLoginAndSync(context),
        ),
      );
    }


        // 🟢 Con internet + usuario autenticado:
        //     si se acaba de recuperar la conexión, muestra tira verde con botón "Sincronizar ahora".
        if (_online && hasUser && widget.showGreenForAuthed && _justCameOnline) {
          // se auto-oculta después de unos segundos si no interactúan
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() => _justCameOnline = false);
          });

          return _buildStrip(
            bg: Colors.green.shade600,
            icon: Icons.wifi,
            text: 'Conexión restablecida.',
            trailing: _actionButton(
              label: _working ? 'Sincronizando...' : 'Sincronizar ahora',
              icon: _working ? null : Icons.sync,
              busy: _working,
              onTap: _working ? null : () => _handleSyncOnly(context),
            ),
          );
        }

        // ✅ Con internet + usuario → no molestar
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildStrip({
    required Color bg,
    required IconData icon,
    required String text,
    Widget? trailing,
  }) {
    return Material(
      color: bg,
      child: SafeArea(
        bottom: false,
        left: false,
        right: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required bool busy,
    VoidCallback? onTap,
    IconData? icon,
  }) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon ?? Icons.sync),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black.withOpacity(.85),
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _maybeAutoSync() async {
    // Ejecuta sync silencioso cuando vuelve internet y hay usuario (no invitado).
    if (!mounted) return;
    final auth = context.read<AuthService>();
    final caja = context.read<CajaService>();
    final gastos = context.read<ServicioGastos>();

    final isGuest = auth.offlineListenable.value;
    if (isGuest) return; // invitados ven el botón de login, no autosync
    if (auth.currentUser == null) return;

    try {
      if (widget.syncGastos) {
        await gastos.syncPendientes();
      }
      if (widget.syncCaja) {
        await caja.syncPendientes();
      }
      if (!mounted) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Sincronizado automáticamente ✅')),
      );
    } catch (_) {
      // silencioso
    }
  }

  Future<void> _handleSyncOnly(BuildContext context) async {
    if (_working) return;
    setState(() => _working = true);

    final caja = context.read<CajaService>();
    final gastos = context.read<ServicioGastos>();

    try {
      if (widget.syncGastos) {
        await gastos.syncPendientes();
      }
      if (widget.syncCaja) {
        await caja.syncPendientes();
      }
      if (mounted) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Sincronización completada ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error al sincronizar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
      if (mounted) setState(() => _justCameOnline = false);
    }
  }

  Future<void> _handleLoginAndSync(BuildContext context) async {
    if (_working) return;
    setState(() => _working = true);

    final auth = context.read<AuthService>();
    final caja = context.read<CajaService>();
    final gastos = context.read<ServicioGastos>();

    try {
      final cred = await auth.signInWithGoogle();
      final user = cred?.user;

      if (!mounted) return;

      if (user == null) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar sesión. Inténtalo de nuevo.')),
        );
        setState(() => _working = false);
        return;
      }

      await auth.ensureUserDocForCurrentUser();

      // Reasigna caja local si estaba en 'local'
      if (caja.cajaActiva != null && (caja.cajaActiva!.usuarioAperturaId == 'local')) {
        await caja.actualizarUsuarioSesion(
          user.uid,
          (user.displayName?.trim().isNotEmpty ?? false)
              ? user.displayName!.trim()
              : (user.email ?? 'Usuario'),
        );
      }

      // Sincronizar pendientes
      if (widget.syncGastos) {
        try { await gastos.syncPendientes(); } catch (_) {}
      }
      if (widget.syncCaja) {
        try { await caja.syncPendientes(); } catch (_) {}
      }

      // Salimos del modo invitado
      auth.disableOfflineMode();

      // Relanzar a AuthGate para reconstruir el árbol en modo online
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );

      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Sesión iniciada y sincronizada ✅')),
      );
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error al iniciar sesión: $e')),
      );
      setState(() => _working = false);
    }
  }
}
