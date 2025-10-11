
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/categoria.dart';

/// Servicio unificado para **categorías** (ventas y gastos).
class CategoriaService {
  final _col = FirebaseFirestore.instance.collection('categorias');

  /// Lee todas las categorías. Filtra por [tipo] si se especifica.
  Future<List<Categoria>> getCategorias({String? tipo}) async {
    Query<Map<String, dynamic>> q = _col;
    if (tipo != null) {
      q = q.where('tipo', isEqualTo: tipo);
    }
    final snap = await q.get();
    return snap.docs.map((d) => Categoria.fromFirestore(d)).toList();
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
