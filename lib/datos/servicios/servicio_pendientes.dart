// lib/datos/servicios/servicio_pendientes.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../modelos/orden.dart';

class ServicioPendientes {
  static const _kKey = 'pending_orders';

  Future<void> savePending({
    required String label,
    required List<OrdenItem> items,
    required double subtotal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kKey) ?? <String>[];
    final data = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'createdAt': DateTime.now().toIso8601String(),
      'label': label,
      'subtotal': subtotal,
      'items': items.map((e) => e.toJson()).toList(),
    };
    list.insert(0, jsonEncode(data));
    await prefs.setStringList(_kKey, list);
  }

  Future<List<Map<String, dynamic>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kKey) ?? <String>[];
    return list.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  Future<void> removeById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kKey) ?? <String>[];
    list.removeWhere((s) {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return m['id'] == id;
    });
    await prefs.setStringList(_kKey, list);
  }
}
