import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/gasto.dart';

/// Servicio responsable por operaciones sobre el almacén/insumos.
class AlmacenService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AlmacenService();

  // helpers
  String _normalize(String s) {
    var x = s.trim().toLowerCase();
    const accents = 'áéíóúÁÉÍÓÚñÑüÜ';
    const replacements = 'aeiouAEIOUnNuU';
    for (var i = 0; i < accents.length; i++) {
      x = x.replaceAll(accents[i], replacements[i]);
    }
    return x;
  }

  String _normalizeForMatch(String s) {
    var x = _normalize(s);
    x = x.replaceAll(RegExp(r"[^a-z0-9 ]+"), ' ');
    x = x.replaceAll(RegExp(r"\s+"), ' ').trim();
    return x;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '.').trim();
    return double.tryParse(s) ?? 0.0;
  }

  double _round2(double v) => double.parse(v.toStringAsFixed(2));

  /// Descontar insumos según lista de GastoItem. Devuelve un reporte detallado.
  Future<List<Map<String, dynamic>>> descontarInsumosPorGastoConReporte(
      List<GastoItem> items) async {
    final report = <Map<String, dynamic>>[];
    if (items.isEmpty) return report;

    // --- Preload insumos
    final insumosSnap = await _db.collection('insumos').get();
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> byId = {};
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> byNormName =
        {};
    for (final d in insumosSnap.docs) {
      final data = d.data();
      final nombre = (data['nombre'] ?? '').toString();
      byId[d.id] = d;
      final norm = _normalizeForMatch(nombre);
      if (norm.isNotEmpty) byNormName[norm] = d;
    }

    // --- Preload recetas
    final recetasSnap = await _db.collection('recetas').get();
    final recetas = recetasSnap.docs;

    // --- Expandir items que sean recetas
    final List<GastoItem> expanded = [];
    for (final it in items) {
      bool expandedThis = false;

      // buscar por id
      try {
        final matches = recetas.where((r) => r.id == it.id).toList();
        if (matches.isNotEmpty) {
          final match = matches.first;
          final data = match.data();
          final insumosRec = List<dynamic>.from(data['insumos'] ?? []);
          final multiplier = it.cantidad;
          for (final ins in insumosRec) {
            final nombre = (ins['nombre'] ?? '').toString();
            if (nombre.trim().isEmpty) continue;
            final cant = _toDouble(ins['cantidad']) * multiplier;
            if (cant <= 0) continue;
            // extraer id
            dynamic rawId = ins['id'] ?? ins['insumoId'] ?? ins['insumo_id'];
            String insId;
            try {
              if (rawId == null) {
                insId = nombre;
              } else if (rawId is DocumentReference) {
                insId = rawId.id;
              } else if (rawId is Map && rawId['id'] != null) {
                insId = rawId['id'].toString();
              } else {
                insId = rawId.toString();
              }
            } catch (_) {
              insId = rawId?.toString() ?? nombre;
            }
            expanded.add(GastoItem(
                id: insId, nombre: nombre, precio: 0.0, cantidad: cant));
          }
          expandedThis = true;
        }
      } catch (_) {}

      if (expandedThis) continue;

      // buscar por nombre normalizado (it.id o it.nombre)
      final source = it.id.isNotEmpty ? it.id : it.nombre;
      final normTarget = _normalizeForMatch(source);
      if (normTarget.isNotEmpty) {
        final matches = recetas.where((r) {
          final nombreRec =
              (r.data() as Map<String, dynamic>?)?['nombre']?.toString() ?? '';
          return _normalizeForMatch(nombreRec) == normTarget;
        }).toList();
        if (matches.isNotEmpty) {
          final matchByName = matches.first;
          final data = matchByName.data();
          final insumosRec = List<dynamic>.from(data['insumos'] ?? []);
          final multiplier = it.cantidad;
          for (final ins in insumosRec) {
            final nombre = (ins['nombre'] ?? '').toString();
            if (nombre.trim().isEmpty) continue;
            final cant = _toDouble(ins['cantidad']) * multiplier;
            if (cant <= 0) continue;
            dynamic rawId = ins['id'] ?? ins['insumoId'] ?? ins['insumo_id'];
            String insId;
            try {
              if (rawId == null) {
                insId = nombre;
              } else if (rawId is DocumentReference) {
                insId = rawId.id;
              } else if (rawId is Map && rawId['id'] != null) {
                insId = rawId['id'].toString();
              } else {
                insId = rawId.toString();
              }
            } catch (_) {
              insId = rawId?.toString() ?? nombre;
            }
            expanded.add(GastoItem(
                id: insId, nombre: nombre, precio: 0.0, cantidad: cant));
          }
          expandedThis = true;
        }
      }

      if (!expandedThis) expanded.add(it);
    }

    // --- Procesar expanded
    for (final it in expanded) {
      try {
        final id = it.id.trim();
        final normName = _normalizeForMatch(it.nombre);
        final isMultiToken =
            normName.split(' ').where((t) => t.isNotEmpty).length > 1;

        try {
          print(
              'AlmacenService: procesando item id=${it.id} nombre=${it.nombre} cantidad=${it.cantidad} (norm="$normName")');
        } catch (_) {}

        QueryDocumentSnapshot<Map<String, dynamic>>? targetDoc;
        String matchType = 'none';

        // id exacto
        if (id.isNotEmpty && byId.containsKey(id)) {
          targetDoc = byId[id];
          matchType = 'id';
        }

        // nombre normalizado exacto
        if (targetDoc == null &&
            normName.isNotEmpty &&
            byNormName.containsKey(normName)) {
          targetDoc = byNormName[normName];
          matchType = 'normalized_name';
        }

        // contains/token overlap sólo si no parece receta (single token)
        if (targetDoc == null && !isMultiToken) {
          for (final entry in byNormName.entries) {
            final key = entry.key;
            if (key.contains(normName) || normName.contains(key)) {
              targetDoc = entry.value;
              matchType = 'contains';
              break;
            }
          }

          if (targetDoc == null) {
            final tokens =
                normName.split(' ').where((t) => t.isNotEmpty).toList();
            if (tokens.length == 1) {
              for (final entry in byNormName.entries) {
                final entryData = entry.value.data();
                final entryNorm =
                    _normalizeForMatch(entryData['nombre']?.toString() ?? '');
                final entryTokens =
                    entryNorm.split(' ').where((t) => t.isNotEmpty).toList();
                if (entryTokens.contains(tokens.first)) {
                  targetDoc = entry.value;
                  matchType = 'token_overlap';
                  break;
                }
              }
            }
          }
        }

        if (targetDoc == null) {
          try {
            final sample = byNormName.keys.take(8).join(', ');
            print(
                'AlmacenService: NO se encontró match para "${it.nombre}" (norm="$normName"). Keys sample: $sample');
          } catch (_) {}
          report.add({
            'id': it.id,
            'nombre': it.nombre,
            'found': false,
            'match_attempt': normName
          });
          continue;
        }

        final targetRef = targetDoc.reference;
        final txnResult = await _db.runTransaction((tx) async {
          final snap = await tx.get(targetRef);
          if (!snap.exists) return null;
          final beforeStock =
              (snap.data()!['stockActual'] as num?)?.toDouble() ?? 0.0;
          final nuevo = _round2(beforeStock - it.cantidad);
          tx.update(targetRef, {'stockActual': nuevo});
          return {
            'before': beforeStock,
            'after': nuevo,
            'nombre': snap.data()!['nombre'] ?? it.nombre
          };
        });

        if (txnResult == null) {
          report.add({
            'id': targetRef.id,
            'nombre': it.nombre,
            'found': false,
            'error': 'transaccion_null'
          });
          continue;
        }

        try {
          final after = await targetRef.get();
          final afterStock = (after.data()!['stockActual'] as num?)?.toDouble();
          print(
              'AlmacenService: actualizado (confirm): ${targetRef.id} - stockActual en DB=$afterStock');
          report.add({
            'id': targetRef.id,
            'nombre': txnResult['nombre'] ?? it.nombre,
            'antes': txnResult['before'],
            'descontado': it.cantidad,
            'despues': txnResult['after'],
            'found': true,
            'match': matchType,
            'db_after': afterStock,
          });
        } catch (e) {
          report.add({
            'id': targetRef.id,
            'nombre': txnResult['nombre'] ?? it.nombre,
            'antes': txnResult['before'],
            'descontado': it.cantidad,
            'despues': txnResult['after'],
            'found': true,
            'match': matchType,
            'db_after_error': e.toString(),
          });
        }
      } catch (e) {
        report.add({
          'id': it.id,
          'nombre': it.nombre,
          'found': false,
          'error': e.toString()
        });
      }
    }

    return report;
  }

  /// Wrapper de compatibilidad
  Future<void> descontarInsumosPorGasto(List<GastoItem> items) async {
    await descontarInsumosPorGastoConReporte(items);
  }

  /// Compatibilidad: descontar insumos por la receta asociada a un producto vendido.
  /// Busca la receta que contenga `productoId` en su array 'productos' y aplica los descuentos
  /// multiplicando las cantidades de la receta por `cantidadVendida`.
  Future<void> descontarInsumosPorVenta(
      String productoId, int cantidadVendida) async {
    if (cantidadVendida <= 0) return;
    try {
      final recetaSnap = await _db
          .collection('recetas')
          .where('productos', arrayContains: productoId)
          .limit(1)
          .get();
      if (recetaSnap.docs.isEmpty) return;
      final recetaData = recetaSnap.docs.first.data();
      final insumosRec = List<dynamic>.from(recetaData['insumos'] ?? []);
      final items = <GastoItem>[];
      for (final ins in insumosRec) {
        final nombre = (ins['nombre'] ?? '').toString();
        if (nombre.trim().isEmpty) continue;
        final cantPorUnidad = _toDouble(ins['cantidad']);
        final total = cantPorUnidad * cantidadVendida;
        if (total <= 0) continue;
        dynamic rawId = ins['id'] ?? ins['insumoId'] ?? ins['insumo_id'];
        String insId;
        try {
          if (rawId == null) {
            insId = nombre;
          } else if (rawId is DocumentReference) {
            insId = rawId.id;
          } else if (rawId is Map && rawId['id'] != null) {
            insId = rawId['id'].toString();
          } else {
            insId = rawId.toString();
          }
        } catch (_) {
          insId = rawId?.toString() ?? nombre;
        }
        items.add(
            GastoItem(id: insId, nombre: nombre, precio: 0.0, cantidad: total));
      }
      if (items.isNotEmpty) await descontarInsumosPorGasto(items);
    } catch (_) {}
  }
}
