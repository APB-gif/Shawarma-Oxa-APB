// lib/core/offline/offline_pending.dart
//
// Cola mínima para *guardar localmente* operaciones (ventas, gastos)
// cuando usas "Invitado" (sin Firebase Auth).
// Se suben al iniciar sesión Google.
//
// Si ya escribes con FirebaseAuth (aunque no haya internet),
// Firestore encola solo y no necesitas esto para esos casos.
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kVentasPendientesKey = 'ventas_pendientes';
const _kGastosPendientesKey = 'gastos_pendientes';

const Uuid _uuid = Uuid();

String genId() => _uuid.v4();

Future<void> addVentaPendiente(Map<String, dynamic> venta) async {
  final p = await SharedPreferences.getInstance();
  final list = p.getStringList(_kVentasPendientesKey) ?? <String>[];
  list.add(jsonEncode(venta));
  await p.setStringList(_kVentasPendientesKey, list);
}

Future<void> addGastoPendiente(Map<String, dynamic> gasto) async {
  final p = await SharedPreferences.getInstance();
  final list = p.getStringList(_kGastosPendientesKey) ?? <String>[];
  list.add(jsonEncode(gasto));
  await p.setStringList(_kGastosPendientesKey, list);
}

/// Devuelve y limpia ventas pendientes.
Future<List<Map<String, dynamic>>> popVentasPendientes() async {
  final p = await SharedPreferences.getInstance();
  final list = p.getStringList(_kVentasPendientesKey) ?? <String>[];
  await p.remove(_kVentasPendientesKey);
  return list.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
}

/// Devuelve y limpia gastos pendientes.
Future<List<Map<String, dynamic>>> popGastosPendientes() async {
  final p = await SharedPreferences.getInstance();
  final list = p.getStringList(_kGastosPendientesKey) ?? <String>[];
  await p.remove(_kGastosPendientesKey);
  return list.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
}