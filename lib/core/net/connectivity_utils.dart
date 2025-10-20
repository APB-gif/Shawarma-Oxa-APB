// lib/core/net/connectivity_utils.dart
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb; // 👈 IMPORTANTE: Para detectar si es web

/// Chequea si hay conectividad y salida real a Internet.
/// - En la web, solo se puede verificar la disponibilidad de la red.
/// - En móvil/escritorio, se hace una prueba de conexión real.
Future<bool> hasInternet(
    {Duration timeout = const Duration(seconds: 2)}) async {
  // =======================================================================
  //  CAMBIO CLAVE: Lógica diferente para la web
  // =======================================================================
  if (kIsWeb) {
    final status = await Connectivity().checkConnectivity();
    // En la web, si no es 'none', asumimos que hay conexión. El navegador gestiona el resto.
    return !status.contains(ConnectivityResult.none);
  }
  // =======================================================================

  // --- Lógica original para plataformas nativas (Android, iOS, etc.) ---
  final dynamic res = await Connectivity().checkConnectivity();

  // Normaliza a lista para soportar v3 y v6+ del plugin
  late final List<ConnectivityResult> results;
  if (res is List<ConnectivityResult>) {
    results = res;
  } else if (res is ConnectivityResult) {
    results = <ConnectivityResult>[res];
  } else {
    results = const <ConnectivityResult>[ConnectivityResult.none];
  }

  final hasAnyNetwork = results.any((r) => r != ConnectivityResult.none);
  if (!hasAnyNetwork) return false;

  // 1) Sondeo TCP a 1.1.1.1:53 (DNS de Cloudflare)
  try {
    final s = await Socket.connect('1.1.1.1', 53, timeout: timeout);
    s.destroy();
    return true;
  } catch (_) {}

  // 2) Fallback TCP a google.com:443
  try {
    final s = await Socket.connect('google.com', 443, timeout: timeout);
    s.destroy();
    return true;
  } catch (_) {}

  return false;
}
