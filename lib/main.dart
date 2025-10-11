import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shawarma_pos_nuevo/presentacion/admin/categoria_page.dart'; // Importa la categoría
import 'package:shawarma_pos_nuevo/datos/servicios/almacen_service.dart';
import 'firebase_options.dart';
import 'nucleo/tema.dart';

import 'package:shawarma_pos_nuevo/datos/servicios/auth/auth_service.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/caja_service.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/informe_service.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/venta_service.dart';
import 'package:shawarma_pos_nuevo/presentacion/auth/auth_gate.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/servicio_gastos.dart';
import 'presentacion/admin/almacen_page.dart'; // Almacén

// >>>>>>>> IMPORTA HIVE <<<<<<<<
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<bool> hasInternet() async {
  final result = await Connectivity().checkConnectivity();
  if (result == ConnectivityResult.none) return false;

  try {
    final lookup = await InternetAddress.lookup('example.com');
    return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // >>>>>>>> INICIALIZA HIVE <<<<<<<<
  await Hive.initFlutter();

  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<CajaService>(
            lazy: false, create: (_) => CajaService()..init()),
        ChangeNotifierProvider<InformeService>(create: (_) => InformeService()),
        Provider<VentaService>(create: (_) => VentaService()),
        ChangeNotifierProvider<ServicioGastos>(create: (_) => ServicioGastos()),
        ChangeNotifierProvider<AlmacenService>(create: (_) => AlmacenService()),
      ],
      child: OnlineReauthOnReconnect(
        child: MaterialApp(
          title: 'Shawarma Oxa',
          theme: appTheme,
          scaffoldMessengerKey: scaffoldMessengerKey,
          navigatorKey: navigatorKey,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('es', '')],
          home: const AuthGate(),
          debugShowCheckedModeBanner: false,
          routes: {
            '/almacen': (context) => ChangeNotifierProvider(
                  create: (_) => AlmacenService(),
                  child: const AlmacenPage(),
                ),
            '/categorias': (context) => const CategoriaPage(),
          },
          builder: (context, child) {
            ErrorWidget.builder = (FlutterErrorDetails details) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    details.exceptionAsString(),
                    style: TextStyle(color: Colors.red, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            };
            return child!;
          },
        ),
      ),
    );
  }
}

class OnlineReauthOnReconnect extends StatefulWidget {
  const OnlineReauthOnReconnect({super.key, required this.child});
  final Widget child;

  @override
  State<OnlineReauthOnReconnect> createState() =>
      _OnlineReauthOnReconnectState();
}

class _OnlineReauthOnReconnectState extends State<OnlineReauthOnReconnect>
    with WidgetsBindingObserver {
  StreamSubscription<dynamic>? _sub;
  Timer? _poller;
  bool _promptShown = false;
  bool _lastOnline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _sub = Connectivity().onConnectivityChanged.listen((event) async {
      bool hasNet;
      if (event is ConnectivityResult) {
        hasNet = event != ConnectivityResult.none;
      } else {
        hasNet = event.isNotEmpty && !event.contains(ConnectivityResult.none);
      }

      if (!mounted) return;
      await _maybePromptLoginOnBackOnline(hasNet);
    });

    _poller = Timer.periodic(const Duration(seconds: 6), (_) async {
      final ok = await hasInternet();
      if (!mounted) return;
      await _maybePromptLoginOnBackOnline(ok);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      hasInternet().then((ok) {
        if (mounted) _maybePromptLoginOnBackOnline(ok);
      });
    }
  }

  Future<void> _maybePromptLoginOnBackOnline(bool nowOnline) async {
    if (nowOnline == _lastOnline && _promptShown) return;
    _lastOnline = nowOnline;

    final auth = context.read<AuthService>();
    final caja = context.read<CajaService>();
    final gastos = context.read<ServicioGastos>();

    if (!nowOnline) {
      _promptShown = false;
      return;
    }

    // Si ya estás online con Firebase user, intenta sincronizar SOLO gastos
    if (auth.currentUser != null) {
      try {
        await gastos.syncPendientes(); // gastos siguen pudiendo sincronizarse
        // 👇 NO subir ventas automáticamente:
        // await caja.syncPendientes();  // <- desactivado por política offline-first
      } catch (_) {}
      return;
    }

    if (!auth.offlineListenable.value) return;
    if (_promptShown) return;
    _promptShown = true;

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Text(
            'Conexión restablecida. Inicia sesión para sincronizar.'),
        action: SnackBarAction(
          label: 'Iniciar sesión',
          onPressed: () async {
            try {
              final cred = await auth.signInWithGoogle();
              final user = cred?.user;
              if (!mounted) return;

              if (user == null) {
                _promptShown = false;
                return;
              }

              await auth.ensureUserDocForCurrentUser();

              if (caja.cajaActiva != null &&
                  (caja.cajaActiva!.usuarioAperturaId == 'local')) {
                await caja.actualizarUsuarioSesion(
                  user.uid,
                  (user.displayName?.trim().isNotEmpty ?? false)
                      ? user.displayName!.trim()
                      : (user.email ?? 'Usuario'),
                );
              }

              await gastos.syncPendientes();
              // 👇 NO subimos ventas aquí:
              // await caja.syncPendientes();

              await auth.clearOfflineMode();
              navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthGate()),
                (_) => false,
              );

              scaffoldMessengerKey.currentState?.showSnackBar(
                const SnackBar(content: Text('Sesión iniciada ✅')),
              );
            } catch (e) {
              _promptShown = false;
              scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(content: Text('Error al iniciar sesión: $e')),
              );
            }
          },
        ),
        duration: const Duration(seconds: 10),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _poller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
