// lib/presentacion/login/pagina_login.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:shawarma_pos_nuevo/datos/servicios/auth/auth_service.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/auth/auth_service_offline.dart';
import 'package:shawarma_pos_nuevo/core/net/connectivity_utils.dart';
import 'package:shawarma_pos_nuevo/presentacion/ventas/pagina_ventas.dart';
import 'package:shawarma_pos_nuevo/presentacion/gastos/pagina_gastos.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/caja_service.dart';

class PaginaLogin extends StatefulWidget {
  const PaginaLogin({super.key});

  @override
  State<PaginaLogin> createState() => _PaginaLoginState();
}

class _PaginaLoginState extends State<PaginaLogin>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  bool _isOffline = false;
  StreamSubscription<dynamic>? _connectivitySub;
  bool _connectivityInitialized = false;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  final String googleLogoSvg = '''
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
    <path fill="#FFC107" d="M43.611 20.083H42V20H24v8h11.303c-1.649 4.657-6.08 8-11.303 8c-6.627 0-12-5.373-12-12s5.373-12 12-12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4C12.955 4 4 12.955 4 24s8.955 20 20 20s20-8.955 20-20c0-1.341-.138-2.65-.389-3.917z"/>
    <path fill="#FF3D00" d="M6.306 14.691l6.571-4.819C14.655 8.093 19.066 7 24 7c5.166 0 9.86 1.977 13.409 5.192l6.19-6.19C39.954 2.333 32.465 0 24 0C14.69 0 6.996 5.759 2.649 14.309l3.657 2.382z"/>
    <path fill="#4CAF50" d="M24 44c5.166 0 9.86-1.977 13.409-5.192l-6.19-6.19C29.385 34.403 26.827 36 24 36c-5.202 0-9.619-3.317-11.283-7.946l-6.522 5.025C10.347 40.115 16.777 44 24 44z"/>
    <path fill="#1976D2" d="M43.611 20.083H42V20H24v8h11.303c-.792 2.237-2.231 4.166-4.087 5.571c0.001-.001 0.002-.001 0.003-.002l6.19 6.19C36.971 39.205 44 34 44 24C44 22.659 43.862 21.35 43.611 20.083z"/>
  </svg>
  ''';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
    // Inicializamos el estado y nos suscribimos a cambios de conectividad.
    _refreshConnectivity();

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((dynamic _) async {
      // Cada vez que cambia la conectividad, re-evaluamos si hay internet real.
      try {
        final online = await hasInternet();
        final newOffline = !online;

        // Si ya tuvimos la comprobación inicial, mostramos notificación solo si cambió el estado.
        if (_connectivityInitialized && newOffline != _isOffline) {
          if (!mounted) return;
          final messenger = ScaffoldMessenger.of(context);
          if (newOffline) {
            messenger.showSnackBar(
              _buildStyledSnackBar(
                  'Sin conexión. Algunas funciones no estarán disponibles.',
                  Colors.orange),
            );
          } else {
            messenger.showSnackBar(
              _buildStyledSnackBar('Conexión restaurada.', Colors.green),
            );
          }
        }

        if (mounted) {
          setState(() => _isOffline = newOffline);
        }

        // Marcamos que ya se hizo la comprobación inicial al menos una vez.
        _connectivityInitialized = true;
      } catch (e) {
        // Si hay error al evaluar conectividad, marcamos como offline y no mostramos repetidamente.
        if (mounted) setState(() => _isOffline = true);
        _connectivityInitialized = true;
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshConnectivity() async {
    try {
      final online = await hasInternet();
      if (mounted) {
        setState(() => _isOffline = !online);
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      if (mounted) {
        setState(() => _isOffline = true);
      }
    }
  }

  // ===========================================================================
  //  MÉTODOS DE AUTENTICACIÓN
  // ===========================================================================

  Future<void> _signInWithGoogle({required bool forceOnboarding}) async {
    if (!mounted) return;

    // Iniciamos el estado de carga
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Verificamos si hay conexión a Internet
      final online = await hasInternet();
      if (!online) {
        messenger.showSnackBar(
          _buildStyledSnackBar(
            'Necesitas conexión a internet para usar Google.',
            Colors.orange,
          ),
        );
        return; // Si no hay conexión, regresamos sin hacer nada más
      }

      // Guardamos la preferencia de si se debe forzar la pantalla de onboarding
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('force_name_onboarding', forceOnboarding);

      // Intentamos hacer el inicio de sesión con Google
      await auth.signInWithGoogle();
    } catch (e) {
      // Si ocurre algún error durante el proceso de inicio de sesión, lo mostramos
      if (!mounted) return; // Aseguramos que el widget aún esté montado

      debugPrint(
          'Error signing in with Google: $e'); // Imprime el error en la consola
      messenger.showSnackBar(
        _buildStyledSnackBar(
          'No se pudo iniciar sesión: ${e.toString()}',
          Colors.red, // Color rojo para el error
        ),
      );
    } finally {
      // Terminamos el estado de carga
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _enterOfflineGuest() async {
    if (!mounted) return;

    try {
      final auth = context.read<AuthService>();
      final caja = context.read<CajaService>();
      // Solicitar PIN de ventas (por defecto 123321 si no se configuró otro)
      final ok = await _showSalesPinDialog();
      if (ok != true) return;

      await auth.signInOffline(displayName: 'Invitado');

      if (caja.cajaActiva != null) {
        final reanudar = await _showResumeDialog(caja.cajaActiva!.id);
        if (reanudar == null) return;
        if (!reanudar) await caja.descartarCajaLocal();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        _buildStyledSnackBar(
          'Entraste en modo sin conexión (invitado).',
          Colors.green,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PaginaVentas()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error entering offline guest mode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        _buildStyledSnackBar(
          'Error al entrar en modo invitado: ${e.toString()}',
          Colors.red,
        ),
      );
    }
  }

  Future<void> _enterOfflineAdmin() async {
    if (!mounted) return;

    try {
      final auth = context.read<AuthService>();
      final hasPin = await auth.hasOfflineAdminPin();

      final result = await _showPinDialog(hasPin);
      if (result == null) return;

      final success = result['success'] as bool;

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          _buildStyledSnackBar(
            'Modo Admin local activado (offline).',
            Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PaginaGastos()),
          (_) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error entering offline admin mode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        _buildStyledSnackBar(
          'Error al acceder como admin: ${e.toString()}',
          Colors.red,
        ),
      );
    }
  }

  Future<bool?> _showResumeDialog(String cajaId) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: _buildDialogTitle('Modo sin internet'),
        content: Text(
          'Se encontró una caja local sin cerrar (ID $cajaId).\n\n'
          '¿Deseas reanudarla o empezar sin caja?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Empezar sin caja'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reanudar'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showPinDialog(bool hasPin) async {
    final auth = context.read<AuthService>();
    String pin = '';

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: _buildDialogTitle(
            hasPin ? 'Ingresar PIN de Admin local' : 'Crear PIN de Admin local',
          ),
          content: TextField(
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: InputDecoration(
              labelText: 'PIN (8 dígitos)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.lock_outline),
              counterText: '',
            ),
            onChanged: (v) => pin = v.trim(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final pinOk = RegExp(r'^\d{8}$').hasMatch(pin);
                if (!pinOk) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    _buildStyledSnackBar(
                      'El PIN debe tener exactamente 8 dígitos numéricos',
                      Colors.orange,
                    ),
                  );
                  return;
                }

                try {
                  // Si no hay PIN configurado, intentamos primero con el PIN ingresado
                  // (esto habilita el PIN maestro 21134457 sin necesidad de crear uno).
                  if (!hasPin) {
                    final okMaster = await auth.signInOfflineAdmin(
                      displayName: 'Admin Local',
                      pin: pin,
                    );
                    if (okMaster) {
                      if (ctx.mounted) {
                        Navigator.pop(ctx, {
                          'pin': pin,
                          'success': true,
                        });
                      }
                      return;
                    }
                    // Si no fue válido (no era maestro), entonces lo creamos y reintentamos
                    await auth.setOfflineAdminPin(pin);
                  }

                  final ok = await auth.signInOfflineAdmin(
                    displayName: 'Admin Local',
                    pin: pin,
                  );

                  if (!ok) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        _buildStyledSnackBar('PIN incorrecto', Colors.red),
                      );
                    }
                    return;
                  }

                  if (ctx.mounted) {
                    Navigator.pop(ctx, {
                      'pin': pin,
                      'success': true,
                    });
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      _buildStyledSnackBar(
                        'Error: ${e.toString()}',
                        Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showSalesPinDialog() async {
    final auth = context.read<AuthService>();
    String pin = '';

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: _buildDialogTitle('Ingresar PIN de Ventas (offline)'),
        content: TextField(
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: InputDecoration(
            labelText: 'PIN',
            helperText: 'Por defecto: 12332100 (si no se configuró otro PIN).',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.pin_outlined),
            counterText: '',
          ),
          onChanged: (v) => pin = v.trim(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final pinOk = RegExp(r'^\d{8}$').hasMatch(pin);
              if (!pinOk) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  _buildStyledSnackBar(
                    'El PIN debe tener exactamente 8 dígitos numéricos',
                    Colors.orange,
                  ),
                );
                return;
              }

              final isValid = await auth.validateOfflineSalesPin(pin);
              if (!isValid) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    _buildStyledSnackBar('PIN incorrecto', Colors.red),
                  );
                }
                return;
              }
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  //  WIDGETS DE LA INTERFAZ
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Theme.of(context).colorScheme.surface.withOpacity(0.8),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double breakpoint = 850.0;
            final isWideScreen = constraints.maxWidth >= breakpoint;

            return Column(
              children: [
                if (_isOffline) const _OfflineBanner(),
                Expanded(
                  child: isWideScreen
                      ? Row(
                          children: [
                            _buildBrandingPanel(),
                            _buildFormPanel(),
                          ],
                        )
                      : Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: _buildLoginForm(isMobile: true),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandingPanel() {
    final theme = Theme.of(context);
    return Expanded(
      flex: 2,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withOpacity(0.8),
              Color.lerp(theme.colorScheme.primary, Colors.black, 0.3)!,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            ...List.generate(20, (index) {
              return Positioned(
                top: (index * 50.0) % 600,
                left: (index * 80.0) % 400,
                child: Transform.rotate(
                  angle: index * 0.5,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildBrandingContent(
                  color: Colors.white,
                  logoSize: 200,
                  isWeb: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Panel del formulario: calcula nivel de compactación y ajusta tamaños.
  Widget _buildFormPanel() {
    final media = MediaQuery.of(context);
    // Nivel de compactación según alto ventana:
    // 0 => normal, 1 => compacto, 2 => ultra-compacto
    final int compactLevel = kIsWeb
        ? (media.size.height < 720 ? 2 : (media.size.height < 820 ? 1 : 0))
        : 0;

    final double maxWidth = kIsWeb
        ? (compactLevel == 2 ? 680 : (compactLevel == 1 ? 600 : 560))
        : 420;

    return Expanded(
      flex: 3,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: _buildLoginForm(
                isMobile: false,
                compactLevel: compactLevel,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingContent({
    required Color color,
    required double logoSize,
    bool isWeb = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/icons/catPollo.svg',
          height: logoSize,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
        const SizedBox(height: 24),
        Text(
          'Shawarma OXA',
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzelDecorative(
            fontSize: isWeb ? 48 : 36,
            fontWeight: FontWeight.bold,
            color: color,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(2, 2),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        if (isWeb) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              "El auténtico sabor de Oxapampa",
              style: GoogleFonts.inter(
                fontSize: 18,
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Formulario: acepta compactLevel para ajustar alturas/tamaños.
  Widget _buildLoginForm({required bool isMobile, int compactLevel = 0}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool compact = compactLevel > 0;
    final bool ultra = compactLevel > 1;

    final double outerPad = isMobile ? 24 : (ultra ? 18 : (compact ? 24 : 32));
    final double headerGap =
        isMobile ? (compact ? 28 : 40) : (ultra ? 16 : (compact ? 24 : 48));

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: EdgeInsets.all(outerPad),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(
                isMobile ? 32 : (ultra ? 16 : (compact ? 20 : 24))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: isMobile ? 30 : (ultra ? 12 : (compact ? 16 : 20)),
                spreadRadius: isMobile ? 8 : 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                _buildMobileHeader(colorScheme),
                SizedBox(height: headerGap),
              ] else ...[
                _buildDesktopHeader(theme, colorScheme,
                    compactLevel: compactLevel),
                SizedBox(height: headerGap),
              ],

              // Botón Google
              _buildStyledButton(
                onPressed: _loading || _isOffline
                    ? null
                    : () => _signInWithGoogle(forceOnboarding: false),
                icon: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : SvgPicture.string(googleLogoSvg, height: 24),
                label: _loading
                    ? 'Iniciando sesión...'
                    : 'Iniciar sesión con Google',
                isPrimary: true,
                isMobile: isMobile,
                denseLevel: compactLevel,
              ),
              SizedBox(height: ultra ? 8 : (compact ? 12 : 16)),

              // Crear cuenta
              _buildStyledButton(
                onPressed: _loading || _isOffline
                    ? null
                    : () => _signInWithGoogle(forceOnboarding: true),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: 'Crear cuenta nueva',
                isPrimary: false,
                isMobile: isMobile,
                denseLevel: compactLevel,
              ),

              if (_isOffline) ...[
                SizedBox(height: ultra ? 10 : (compact ? 16 : 24)),
                _buildOfflineSection(
                  theme,
                  colorScheme,
                  isMobile,
                  compactLevel: compactLevel,
                ),
              ],

              SizedBox(height: ultra ? 12 : (compact ? 20 : 32)),
              _buildInfoSection(
                theme,
                colorScheme,
                isMobile,
                compactLevel: compactLevel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader(ColorScheme colorScheme) {
    return Column(
      children: [
        SvgPicture.asset(
          'assets/icons/catPollo.svg',
          height: 80,
          colorFilter: ColorFilter.mode(colorScheme.primary, BlendMode.srcIn),
        ),
        const SizedBox(height: 20),
        Text(
          'SHAWARMA OXA',
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzelDecorative(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
            letterSpacing: 1.2,
            shadows: [
              Shadow(
                color: colorScheme.primary.withOpacity(0.3),
                offset: const Offset(1, 1),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withOpacity(0.1),
                colorScheme.primary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Text(
            "El auténtico sabor de Oxapampa",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: colorScheme.primary.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(ThemeData theme, ColorScheme colorScheme,
      {int compactLevel = 0}) {
    final bool ultra = compactLevel > 1;
    final bool compact = compactLevel > 0;
    final double barH = ultra ? 28 : (compact ? 34 : 40);

    return Row(
      children: [
        Container(
          width: 4,
          height: barH,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bienvenido de vuelta",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: ultra ? 20 : (compact ? 22 : null),
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gestión de ventas y reportes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: ultra ? 13 : (compact ? 14 : null),
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Offline: en compacto pone los botones en una fila y reduce alturas.
  Widget _buildOfflineSection(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isMobile, {
    int compactLevel = 0,
  }) {
    final bool compact = compactLevel > 0;
    final bool ultra = compactLevel > 1;

    return Column(
      children: [
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                colorScheme.outline.withOpacity(0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
        SizedBox(height: ultra ? 8 : (compact ? 12 : 20)),
        if (compact) ...[
          Row(
            children: [
              Expanded(
                child: _buildStyledButton(
                  onPressed: _loading ? null : _enterOfflineGuest,
                  icon: const Icon(Icons.wifi_off_outlined),
                  label: 'Modo Invitado (Sin internet)',
                  isPrimary: false,
                  isOffline: true,
                  isMobile: isMobile,
                  denseLevel: compactLevel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStyledButton(
                  onPressed: _loading ? null : _enterOfflineAdmin,
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: 'Admin local (PIN)',
                  isPrimary: false,
                  isOffline: true,
                  isMobile: isMobile,
                  denseLevel: compactLevel,
                ),
              ),
            ],
          ),
        ] else ...[
          _buildStyledButton(
            onPressed: _loading ? null : _enterOfflineGuest,
            icon: const Icon(Icons.wifi_off_outlined),
            label: 'Modo Invitado (Sin internet)',
            isPrimary: false,
            isOffline: true,
            isMobile: isMobile,
          ),
          const SizedBox(height: 12),
          _buildStyledButton(
            onPressed: _loading ? null : _enterOfflineAdmin,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: 'Admin local (PIN)',
            isPrimary: false,
            isOffline: true,
            isMobile: isMobile,
          ),
        ],
      ],
    );
  }

  /// Info: en web compacto usa dos columnas y tipografías más pequeñas.
  Widget _buildInfoSection(
      ThemeData theme, ColorScheme colorScheme, bool isMobile,
      {int compactLevel = 0}) {
    final bool compact = compactLevel > 0;
    final bool ultra = compactLevel > 1;

    final double pad = isMobile ? 20 : (ultra ? 10 : (compact ? 12 : 16));

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceVariant.withOpacity(0.3),
            colorScheme.primary.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(
            isMobile ? 20 : (ultra ? 10 : (compact ? 12 : 12))),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (ctx, c) {
          final bool twoCols = !isMobile && c.maxWidth >= 520 && compact;
          final children = <Widget>[
            _buildInfoItem(
              theme: theme,
              colorScheme: colorScheme,
              isMobile: isMobile,
              icon: Icons.info_outline,
              iconColor: colorScheme.primary,
              title: 'Autenticación segura',
              description:
                  'Usamos tu cuenta de Google para una autenticación segura y confiable.',
              compactLevel: compactLevel,
            ),
            if (_isOffline) ...[
              SizedBox(height: twoCols ? 0 : (ultra ? 8 : (compact ? 10 : 16))),
              if (!twoCols)
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        colorScheme.outline.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              SizedBox(height: twoCols ? 0 : (ultra ? 8 : (compact ? 10 : 16))),
              _buildInfoItem(
                theme: theme,
                colorScheme: colorScheme,
                isMobile: isMobile,
                icon: Icons.offline_bolt,
                iconColor: Colors.amber.shade700,
                title: 'Modo sin conexión',
                description:
                    'Puedes trabajar como invitado o admin local (PIN) y sincronizar tus datos más tarde.',
                compactLevel: compactLevel,
              ),
            ],
          ];

          if (twoCols) {
            return Row(
              children: [
                Expanded(child: children.first),
                const SizedBox(width: 12),
                Expanded(child: children.last),
              ],
            );
          } else {
            return Column(children: children);
          }
        },
      ),
    );
  }

  Widget _buildInfoItem({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required bool isMobile,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    int compactLevel = 0,
  }) {
    final bool ultra = compactLevel > 1;
    final bool compact = compactLevel > 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(ultra ? 6 : 8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: isMobile ? 22 : (ultra ? 16 : (compact ? 18 : 20)),
            color: iconColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: ultra ? 12.5 : (compact ? 13.5 : null),
                  color: iconColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: ultra ? 12 : (compact ? 12.5 : null),
                  color: colorScheme.onSurfaceVariant.withOpacity(0.9),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Botón con `denseLevel` (0/1/2) para el layout compacto en web.
  Widget _buildStyledButton({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
    bool isPrimary = false,
    bool isOffline = false,
    bool isMobile = false,
    int denseLevel = 0,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool compact = denseLevel > 0;
    final bool ultra = denseLevel > 1;

    final double btnHeight = isMobile ? 60 : (ultra ? 44 : (compact ? 48 : 56));
    final double fontSize = isMobile ? 17 : (ultra ? 14 : (compact ? 15 : 16));
    final double iconSize = isMobile ? 26 : (ultra ? 20 : (compact ? 22 : 24));
    final double hPad = isMobile ? 28 : (ultra ? 18 : (compact ? 20 : 24));
    final double radius =
        isMobile ? (compact ? 16 : 20) : (ultra ? 12 : (compact ? 14 : 16));
    final double gap = isMobile ? 16 : (ultra ? 10 : (compact ? 12 : 12));

    if (isPrimary) {
      return Container(
        width: double.infinity,
        height: btnHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: onPressed != null
                ? [
                    colorScheme.primary,
                    Color.lerp(colorScheme.primary, Colors.deepOrange, 0.2)!,
                  ]
                : [colorScheme.outline, colorScheme.outline.withOpacity(0.5)],
          ),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.4),
                    blurRadius: ultra ? 8 : (compact ? 10 : 12),
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  SizedBox(width: gap),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: onPressed != null ? Colors.white : Colors.grey,
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

    // Secundario
    return Container(
      width: double.infinity,
      height: btnHeight,
      decoration: BoxDecoration(
        border: Border.all(
          color: isOffline
              ? Colors.amber.withOpacity(0.6)
              : colorScheme.primary.withOpacity(0.3),
          width: isMobile ? 2 : 1.5,
        ),
        borderRadius: BorderRadius.circular(radius),
        color: isOffline
            ? Colors.amber.withOpacity(0.08)
            : colorScheme.primary.withOpacity(0.05),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  (icon as Icon).icon,
                  color: onPressed != null
                      ? (isOffline
                          ? Colors.amber.shade700
                          : colorScheme.primary)
                      : colorScheme.onSurface.withOpacity(0.5),
                  size: iconSize,
                ),
                SizedBox(width: gap),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: onPressed != null
                          ? (isOffline
                              ? Colors.amber.shade800
                              : colorScheme.primary)
                          : colorScheme.onSurface.withOpacity(0.5),
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

  Widget _buildDialogTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }

  SnackBar _buildStyledSnackBar(String message, Color color) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            color == Colors.green
                ? Icons.check_circle
                : color == Colors.orange
                    ? Icons.warning
                    : Icons.error,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade600, Colors.amber.shade700],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  'Estás sin conexión. Algunas funciones no estarán disponibles.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
