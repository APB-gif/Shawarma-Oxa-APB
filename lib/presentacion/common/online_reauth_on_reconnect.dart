// lib/presentacion/common/online_reauth_on_reconnect.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shawarma_pos_nuevo/datos/servicios/auth/auth_service.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/caja_service.dart';

class OnlineReauthOnReconnect extends StatefulWidget {
  final Widget child;
  const OnlineReauthOnReconnect({super.key, required this.child});

  @override
  State<OnlineReauthOnReconnect> createState() => _OnlineReauthOnReconnectState();
}

class _OnlineReauthOnReconnectState extends State<OnlineReauthOnReconnect> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _showingPrompt = false;

  @override
  void initState() {
    super.initState();
    _sub = Connectivity().onConnectivityChanged.listen((results) async {
      final hasNet = results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (!mounted || !hasNet) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null && !_showingPrompt) {
        _showLoginPrompt();
      } else if (user != null) {
        unawaited(context.read<CajaService>().syncPendientes());
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _showLoginPrompt() async {
    _showingPrompt = true;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Conexión restablecida'),
        content: const Text('¿Quieres iniciar sesión para volver a modo online y sincronizar tus datos?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Más tarde')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _showEmailLoginDialog();
            },
            child: const Text('Correo / Clave'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.account_circle_outlined),
            label: const Text('Google'),
            onPressed: () async {
              try {
                final auth = context.read<AuthService>();
                final cred = await auth.signInWithGoogle();
                final u = cred?.user ?? FirebaseAuth.instance.currentUser;

                if (u != null) {
                  final cajaSrv = context.read<CajaService>();
                  await cajaSrv.actualizarUsuarioSesion(
                    u.uid,
                    (u.displayName?.trim().isNotEmpty ?? false) ? u.displayName!.trim() : 'Usuario',
                  );
                  await cajaSrv.syncPendientes();
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sesión iniciada y datos sincronizados.')),
                  );
                }
              } catch (e) {
                // Dispositivo sin GMS u otro error → no reventamos
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo usar Google en este dispositivo. Usa Correo/Clave. ($e)')),
                  );
                  // abrimos inmediatamente la alternativa por correo
                  await _showEmailLoginDialog();
                }
              }
            },
          ),
        ],
      ),
    );

    _showingPrompt = false;
  }

  Future<void> _showEmailLoginDialog() async {
    final formKey = GlobalKey<FormState>();
    final emailCtl = TextEditingController();
    final passCtl = TextEditingController();
    bool loading = false;

    await showDialog(
      context: context,
      barrierDismissible: !loading,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Iniciar sesión'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailCtl,
                  decoration: const InputDecoration(labelText: 'Correo'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passCtl,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: loading ? null : () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => loading = true);
                      try {
                        final auth = context.read<AuthService>();
                        final cred = await auth.signInWithEmailAndPassword(
                          emailCtl.text.trim(),
                          passCtl.text.trim(),
                        );
                        final u = cred.user!;
                        final cajaSrv = context.read<CajaService>();
                        await cajaSrv.actualizarUsuarioSesion(
                          u.uid,
                          (u.displayName?.trim().isNotEmpty ?? false) ? u.displayName!.trim() : 'Usuario',
                        );
                        await cajaSrv.syncPendientes();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sesión iniciada y datos sincronizados.')),
                          );
                        }
                      } catch (e) {
                        setS(() => loading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error de autenticación: $e')),
                          );
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
