// lib/presentacion/pagina_principal.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:shawarma_pos_nuevo/datos/servicios/auth/auth_service.dart';

// Páginas
import 'package:shawarma_pos_nuevo/presentacion/admin/pagina_admin.dart';
import 'package:shawarma_pos_nuevo/presentacion/caja/pagina_caja.dart';
import 'package:shawarma_pos_nuevo/presentacion/gastos/pagina_gastos.dart';
import 'package:shawarma_pos_nuevo/presentacion/informes/pagina_informes.dart';
import 'package:shawarma_pos_nuevo/presentacion/ventas/pagina_ventas.dart';

// Perfil (sheet)
import 'package:shawarma_pos_nuevo/presentacion/perfil/perfil_sheet.dart';

// AuthGate para logout recomendado
import 'package:shawarma_pos_nuevo/presentacion/auth/auth_gate.dart';
import 'package:shawarma_pos_nuevo/presentacion/widgets/notificaciones.dart';

final GlobalKey<ScaffoldMessengerState> principalMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

const kRolAdmin = 'administrador';
const kRolTrab = 'trabajador';
const kRolEsp = 'espectador';
const kRolOff = 'fuera de servicio';

class PaginaPrincipal extends StatefulWidget {
  const PaginaPrincipal({super.key});

  @override
  State<PaginaPrincipal> createState() => _PaginaPrincipalState();
}

// Contexto global del Scaffold principal para notificaciones elegantes
BuildContext? mainScaffoldContext;

class _PaginaPrincipalState extends State<PaginaPrincipal> {
  int _paginaSeleccionada = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Por si el widget vive un frame más después de logout
    if (user == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.primary.withOpacity(0.1),
                colorScheme.surface,
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        // Si pierdes permisos al salir (permission-denied en Web), no colgamos.
        if (snap.hasError) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primary.withOpacity(0.1),
                    colorScheme.surface,
                  ],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primary.withOpacity(0.1),
                    colorScheme.surface,
                  ],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final data = snap.data!.data() ?? {};
        final rol = (data['rol'] as String?)?.trim() ?? kRolEsp;
        final nombre = (data['nombre'] as String?)?.trim() ?? '';
        final isAdmin = rol == kRolAdmin;
        final isViewer = rol == kRolEsp;
        final isOff = rol == kRolOff;

        // Si está fuera de servicio, bloquear toda la app hasta que un admin cambie su rol
        if (isOff) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Acceso restringido'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            title: Row(
                              children: [
                                Icon(Icons.logout_rounded,
                                    color: colorScheme.primary),
                                const SizedBox(width: 8),
                                const Text('Cerrar Sesión'),
                              ],
                            ),
                            content: const Text(
                                '¿Quieres cerrar sesión para cambiar de cuenta?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Salir'),
                              ),
                            ],
                          ),
                        );
                        if (shouldLogout != true) return;

                        principalMessengerKey.currentState?.clearSnackBars();
                        final rootNav =
                            Navigator.of(context, rootNavigator: true);
                        if (rootNav.canPop()) {
                          rootNav.popUntil((route) => route.isFirst);
                        }

                        await context.read<AuthService>().signOut();
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
                    const Text(
                      'Tu cuenta está fuera de servicio',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Un administrador debe asignarte un rol activo para continuar.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Define items por rol (viewer ve Ventas y Caja igual que trabajador)
        final paginas = isAdmin
            ? <Widget>[
                const PaginaVentas(),
                const PaginaCaja(),
                const PaginaGastos(),
                const PaginaInformes(),
                const PaginaAdmin(),
              ]
            : <Widget>[
                const PaginaVentas(),
                const PaginaCaja(),
              ];

    final items = isAdmin
            ? <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: _paginaSeleccionada == 0
                        ? BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
                    child: Icon(
                      Icons.point_of_sale_rounded,
                      color: _paginaSeleccionada == 0
                          ? colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                  label: 'Ventas',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: _paginaSeleccionada == 1
                        ? BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: _paginaSeleccionada == 1
                          ? colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                  label: 'Caja',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: _paginaSeleccionada == 2
                        ? BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: _paginaSeleccionada == 2
                          ? colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                  label: 'Gastos',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: _paginaSeleccionada == 3
                        ? BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
                    child: Icon(
                      Icons.analytics_rounded,
                      color: _paginaSeleccionada == 3
                          ? colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                  label: 'Informes',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: _paginaSeleccionada == 4
                        ? BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      color: _paginaSeleccionada == 4
                          ? colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                  label: 'Admin',
                ),
              ]
            : <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: _paginaSeleccionada == 0
                        ? BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
                    child: Icon(
                      Icons.point_of_sale_rounded,
                      color: _paginaSeleccionada == 0
                          ? colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                  label: 'Ventas',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: _paginaSeleccionada == 1
                        ? BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: _paginaSeleccionada == 1
                          ? colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                  label: 'Caja',
                ),
              ];

        // Si cambió el rol y el índice quedó fuera de rango, reajústalo
        if (_paginaSeleccionada >= paginas.length) {
          _paginaSeleccionada = paginas.length - 1;
        }

        final photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
        String roleBadge;
        Color roleBadgeColor;
        if (isAdmin) {
          roleBadge = 'ADMIN';
          roleBadgeColor = Colors.amber;
        } else if (isViewer) {
          roleBadge = 'VIEW';
          roleBadgeColor = Colors.blueGrey;
        } else {
          roleBadge = 'STAFF';
          roleBadgeColor = Colors.green;
        }

        return ScaffoldMessenger(
          key: principalMessengerKey,
          child: Builder(
            builder: (scaffoldCtx) {
              mainScaffoldContext = scaffoldCtx;
              return Scaffold(
                extendBodyBehindAppBar: true,
                appBar: AppBar(
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: Colors.transparent,
                  flexibleSpace: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withOpacity(0.8),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  title: Expanded(
                    child: Row(
                      children: [
                        // Logo compacto
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colorScheme.onPrimary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.restaurant_rounded,
                            color: colorScheme.onPrimary,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Nombre y badge compactos
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Shawarma POS',
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: roleBadgeColor.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  roleBadge,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Indicador online compacto
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Text(
                                'ONLINE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    // Perfil (avatar con cache para evitar 429)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              showDragHandle: true,
                              useSafeArea: true,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.only(bottom: 16),
                                  child: SingleChildScrollView(
                                      child: PerfilSheet()),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.onPrimary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colorScheme.onPrimary.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Hero(
                                  tag: 'profile-avatar',
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor:
                                        colorScheme.onPrimary.withOpacity(0.3),
                                    child: ClipOval(
                                      child: (photoUrl != null &&
                                              photoUrl.isNotEmpty)
                                          ? CachedNetworkImage(
                                              imageUrl: photoUrl,
                                              width: 32,
                                              height: 32,
                                              fit: BoxFit.cover,
                                              fadeInDuration: Duration.zero,
                                              fadeOutDuration: Duration.zero,
                                              errorWidget: (_, __, ___) => Icon(
                                                Icons.person_rounded,
                                                size: 18,
                                                color: colorScheme.onPrimary,
                                              ),
                                            )
                                          : Icon(
                                              Icons.person_rounded,
                                              size: 18,
                                              color: colorScheme.onPrimary,
                                            ),
                                    ),
                                  ),
                                ),
                                if (nombre.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    nombre.length > 10
                                        ? '${nombre.substring(0, 10)}...'
                                        : nombre,
                                    style: TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Logout (recomendado): limpia overlays y vuelve al AuthGate
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            // Mostrar diálogo de confirmación
                            final shouldLogout = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Row(
                                  children: [
                                    Icon(
                                      Icons.logout_rounded,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Cerrar Sesión'),
                                  ],
                                ),
                                content: const Text(
                                  '¿Estás seguro de que quieres cerrar sesión?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Salir'),
                                  ),
                                ],
                              ),
                            );

                            if (shouldLogout != true) return;

                            // Cierra snackbars/modales antes de cortar la sesión
                            principalMessengerKey.currentState
                                ?.clearSnackBars();
                            final rootNav =
                                Navigator.of(context, rootNavigator: true);
                            if (rootNav.canPop()) {
                              rootNav.popUntil((route) => route.isFirst);
                            }

                            await context.read<AuthService>().signOut();
                            if (!context.mounted) return;

                            // Navega "en limpio" al AuthGate (que mostrará Login si user == null)
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) => const AuthGate()),
                              (route) => false,
                            );

                            mostrarNotificacionElegante(
                              context,
                              'Sesión cerrada correctamente',
                              messengerKey: principalMessengerKey,
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
                body: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colorScheme.primary.withOpacity(0.05),
                        colorScheme.surface,
                      ],
                      stops: const [0.0, 0.3],
                    ),
                  ),
                  child: SafeArea(
                    child: IndexedStack(
                      index: _paginaSeleccionada,
                      children: paginas,
                    ),
                  ),
                ),
                bottomNavigationBar: Container(
                  decoration: BoxDecoration(
                    color: isDark ? colorScheme.surface : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: BottomNavigationBar(
                        items: items,
                        currentIndex: _paginaSeleccionada,
                        onTap: (i) {
                          setState(() => _paginaSeleccionada = i);
                        },
                        selectedItemColor: colorScheme.primary,
                        unselectedItemColor:
                            colorScheme.onSurface.withOpacity(0.6),
                        selectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 11,
                        ),
                        type: BottomNavigationBarType.fixed,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
