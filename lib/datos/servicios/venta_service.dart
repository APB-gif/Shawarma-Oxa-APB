// lib/datos/servicios/venta_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/venta.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/caja_service.dart';

/// Servicio para CRUD de ventas. **Flujo de Ventas**:
/// - Al pagar en Ventas: SOLO guarda **local** via CajaService (NO Firestore).
/// - Al cerrar caja: CajaService sube todo a Firestore.
///
/// Los métodos que escriben en Firestore quedan para usos puntuales
/// (informes, reparaciones, migraciones, etc.), pero NO se usan en el flujo normal.
class VentaService {
  VentaService();

  CollectionReference<Map<String, dynamic>> get _rawCol =>
      FirebaseFirestore.instance.collection('ventas');

  /// Versión tipada para lecturas / informes
  CollectionReference<Venta> get _col =>
      FirebaseFirestore.instance.collection('ventas').withConverter<Venta>(
            fromFirestore: (snap, _) => Venta.fromFirestore(snap),
            toFirestore: (venta, _) => venta.toFirestore(),
          );

  // ---------------------------------------------------------------------------
  // ✔️ FLUJO NORMAL (NO Firestore aquí)
  // ---------------------------------------------------------------------------

  /// Llamado desde la página de Ventas al confirmar el pago.
  /// 👉 NO sube a Firestore. Solo agrega al buffer local de la caja.
  Future<void> registrarVentaLocal(Venta venta, CajaService cajaService) async {
    await cajaService.agregarVentaLocal(venta);
    if (kDebugMode) {
      print('[VentaService] Venta ${venta.id} agregada LOCAL a la caja.');
    }
  }

  /// Mueve una venta desde "pendientes" a "eliminadas" en la caja (local).
  Future<void> marcarVentaEliminadaLocal(
      Venta venta, CajaService cajaService) async {
    await cajaService.registrarVentaEliminada(venta);
    // Opcional: también quitarla de pendientes si aún estuviera
    await cajaService.eliminarVentaLocal(venta);
    if (kDebugMode) {
      print('[VentaService] Venta ${venta.id} marcada como ELIMINADA (local).');
    }
  }

  /// Quita una venta del buffer local (pendientes) y ajusta totales.
  Future<void> eliminarVentaDePendientesLocal(
      Venta venta, CajaService cajaService) async {
    await cajaService.eliminarVentaLocal(venta);
    if (kDebugMode) {
      print(
          '[VentaService] Venta ${venta.id} eliminada de pendientes (local).');
    }
  }

  // ---------------------------------------------------------------------------
  // 🔧 UTILIDADES DIRECTAS A FIRESTORE (no se usan en el flujo normal)
  // ---------------------------------------------------------------------------

  /// Guarda una venta directamente en Firestore (uso puntual: migraciones, admin).
  Future<void> registrarVenta(Venta venta) async {
    await _rawCol.doc(venta.id).set(venta.toFirestore());
    if (kDebugMode) {
      print(
          '[VentaService] Venta ${venta.id} registrada en Firestore (uso directo).');
    }
  }

  /// Borra una venta puntual por id en Firestore (uso puntual).
  Future<void> eliminarVenta(String ventaId) async {
    await _rawCol.doc(ventaId).delete();
    if (kDebugMode) {
      print('[VentaService] Venta $ventaId eliminada de Firestore.');
    }
  }

  /// Elimina todas las ventas asociadas a una sesión/caja en Firestore (uso puntual).
  Future<void> eliminarVentasDeSesion(String cajaId) async {
    final query = await _rawCol.where('cajaId', isEqualTo: cajaId).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    if (kDebugMode) {
      print(
          '[VentaService] Ventas de la sesión $cajaId eliminadas de Firestore.');
    }
  }

  // ---------------------------------------------------------------------------
  // 📊 Lecturas / informes
  // ---------------------------------------------------------------------------

  /// Obtiene ventas de una caja (una sola lectura).
  Future<List<Venta>> getVentasDeCaja(String cajaId) async {
    final snap = await _col.where('cajaId', isEqualTo: cajaId).get();
    return snap.docs.map((d) => d.data()).toList();
    // Nota: estas son ventas que YA se subieron (o sea, después del cierre).
  }

  /// Stream de ventas por rango de fecha (para informes).
  Stream<List<Venta>> streamVentasPorRango({
    required DateTime desde,
    required DateTime hasta,
  }) {
    return _col
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(hasta))
        .orderBy('fecha', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }
}
