// admin_repository.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/categoria.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/producto.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/producto_service.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/categoria_service.dart';

/// Repositorio para el **panel de Admin**. Mantiene cache en memoria.
class AdminRepository {
  AdminRepository._privateConstructor();
  static final AdminRepository instance = AdminRepository._privateConstructor();

  final _productoService = ProductoService();
  final _categoriaService = CategoriaService();
  final _storage = FirebaseStorage.instance;

  // --- Cache ---
  List<Producto> _productosVentas = [];
  List<Producto> _productosGastos = [];
  List<Categoria> _categoriasVentas = [];
  List<Categoria> _categoriasGastos = [];
  bool _isDataLoaded = false;

  List<Producto> getProductosVentas() => List.unmodifiable(_productosVentas);
  List<Producto> getProductosGastos() => List.unmodifiable(_productosGastos);
  List<Categoria> getCategoriasVentas() => List.unmodifiable(_categoriasVentas);
  List<Categoria> getCategoriasGastos() => List.unmodifiable(_categoriasGastos);

  void limpiarCache() => _isDataLoaded = false;

  /// Carga **desde Firebase** y separa por tipo.
  Future<void> cargarDatos() async {
    if (_isDataLoaded) return;

    final todosLosProductos = await _productoService.getProductos();
    final todasLasCategorias = await _categoriaService.getCategorias();

    _categoriasVentas = todasLasCategorias
        .where((c) => c.tipo.toLowerCase() == 'venta')
        .toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
    _categoriasGastos = todasLasCategorias
        .where((c) => c.tipo.toLowerCase() == 'gasto')
        .toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));

    final idsCategoriasVenta = _categoriasVentas.map((c) => c.id).toSet();
    final idsCategoriasGasto = _categoriasGastos.map((c) => c.id).toSet();

    _productosVentas = todosLosProductos
        .where((p) =>
            p.tipo.toLowerCase() == 'venta' &&
            idsCategoriasVenta.contains(p.categoriaId))
        .toList();
    _productosGastos = todosLosProductos
        .where((p) =>
            p.tipo.toLowerCase() == 'gasto' &&
            idsCategoriasGasto.contains(p.categoriaId))
        .toList();

    _isDataLoaded = true;
  }

  // ---- CRUD (delegan a servicios) ----

  Future<void> crearProducto(Producto producto) async {
    await _productoService.addProducto(producto);
    limpiarCache();
  }

  Future<void> actualizarProducto(Producto producto) async {
    await _productoService.updateProducto(producto);
    limpiarCache();
  }

  Future<void> eliminarProducto(Producto producto) async {
    await _productoService.deleteProducto(producto.id);
    limpiarCache();
  }

  Future<void> crearCategoria(Categoria categoria) async {
    await _categoriaService.addCategoria(categoria);
    limpiarCache();
  }

  Future<void> actualizarCategoria(Categoria categoria) async {
    await _categoriaService.updateCategoria(categoria);
    limpiarCache();
  }

  Future<void> eliminarCategoria(String categoriaId) async {
    await _categoriaService.deleteCategoria(categoriaId);
    limpiarCache();
  }

  /// Sube un SVG a Storage y actualiza el campo `iconAssetPath` de la categoría con su URL.
  Future<void> actualizarIconoCategoria(
      Categoria categoria, File imagenSvg) async {
    final ref = _storage.ref('category_icons/${categoria.id}.svg');
    await ref.putFile(imagenSvg);
    final downloadUrl = await ref.getDownloadURL();

    final categoriaActualizada = categoria.copyWith(iconAssetPath: downloadUrl);
    await actualizarCategoria(categoriaActualizada);
  }
}
