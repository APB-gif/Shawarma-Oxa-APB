
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/categoria.dart';

/// Servicio unificado para **categorías** (ventas y gastos).
class CategoriaService {
  final _col = FirebaseFirestore.instance.collection('categorias');

  /// Lee todas las categorías. Filtra por [tipo] si se especifica.
  Future<List<Categoria>> getCategorias({String? tipo}) async {
    try {
      Query<Map<String, dynamic>> q = _col;
      if (tipo != null) {
        q = q.where('tipo', isEqualTo: tipo);
      }
  final snapshot = await q.get();
  return snapshot.docs.map((d) => Categoria.fromFirestore(d)).toList();
    } on FirebaseException catch (e) {
      // Si Firestore rechaza la lectura por permisos, devolvemos lista vacía en lugar
      // de propagar la excepción para evitar que la UI se pare.
      if (e.code == 'permission-denied') {
        return [];
      }
      rethrow;
    }
  }

  Future<void> addCategoria(Categoria c) async {
    if (c.id.isEmpty) {
      final auto = _col.doc();
      await auto.set(c.copyWith(id: auto.id).toFirestore());
    } else {
      await _col.doc(c.id).set(c.toFirestore());
    }
  }

  Future<void> updateCategoria(Categoria c) async {
    await _col.doc(c.id).update(c.toFirestore());
  }

  Future<void> deleteCategoria(String id) async {
    await _col.doc(id).delete();
  }
}
