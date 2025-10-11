import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../datos/servicios/auth/auth_service.dart';
import '../../datos/servicios/auth/auth_service_offline.dart';
import '../login/pagina_login.dart';
import '../ventas/pagina_ventas.dart';
import '../gastos/pagina_gastos.dart';
import '../welcome_dashboard.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return ValueListenableBuilder<bool>(
      valueListenable: auth.offlineListenable,
      builder: (_, isOffline, __) {
        // 🔌 OFFLINE → decidir por rol local (admin => Gastos, invitado => Ventas)
        if (isOffline) {
          return FutureBuilder<bool>(
            future: auth.isOfflineAdmin(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final esAdmin = snap.data == true;
              return esAdmin
                  ? const PaginaGastos(key: ValueKey('gastos_offline_admin'))
                  : const PaginaVentas(key: ValueKey('ventas_offline_guest'));
            },
          );
        }

        // 🌐 ONLINE → flujo normal con FirebaseAuth
        return StreamBuilder<User?>(
          stream: auth.authStateChanges,
          initialData: FirebaseAuth.instance.currentUser,
          builder: (context, snap) {
            final user = snap.data;

            if (user == null) {
              return const PaginaLogin(key: ValueKey('login_online'));
            }

            // Garantiza users/{uid} y limpia flag offline si quedó prendido
            WidgetsBinding.instance.addPostFrameCallback((_) {
              auth.ensureUserDocForCurrentUser();
              if (auth.offlineListenable.value) {
                auth.disableOfflineMode();
              }
            });

            return const WelcomeDashboard(key: ValueKey('home_online'));
          },
        );
      },
    );
  }
}
