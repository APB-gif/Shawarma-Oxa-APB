// lib/presentacion/gastos/pagina_gastos.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

// Base
import 'package:shawarma_pos_nuevo/datos/modelos/categoria.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/pago.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/producto.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/app_user.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/gasto.dart';
import 'package:shawarma_pos_nuevo/datos/repositorios/admin_repository.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/servicio_lista_compras.dart';
import 'package:shawarma_pos_nuevo/datos/servicios/servicio_gastos.dart';

// Catálogo local (fallback)
import 'package:shawarma_pos_nuevo/datos/catalogo_gastos.dart';

// Helpers
import 'package:shawarma_pos_nuevo/core/net/connectivity_utils.dart' show hasInternet;

// UI Gastos
import 'package:shawarma_pos_nuevo/presentacion/gastos/panel_gastos.dart' as pg;
import 'package:shawarma_pos_nuevo/presentacion/gastos/pagina_lista_compras.dart';
import 'package:shawarma_pos_nuevo/presentacion/gastos/panel_pago_gastos.dart';
import 'package:shawarma_pos_nuevo/presentacion/comunes/net_status_strip.dart';

/// ===== Helpers de dinero exacto (centavos) =====
int _toCents(num v) => (v * 100).round();
double _fromCents(int c) => c / 100.0;
double _norm(double v) => _fromCents(_toCents(v));

String _metodoKey(PaymentMethod m) {
  switch (m) {
    case PaymentMethod.cash:
      return 'Efectivo';
    case PaymentMethod.izipayCard:
      return 'Tarjeta';
    case PaymentMethod.yapePersonal:
      return 'Yape Personal';
    default:
      return m.displayName;
  }
}

/// ===== Página principal =====
class PaginaGastos extends StatefulWidget {
  const PaginaGastos({super.key});

  @override
  State<PaginaGastos> createState() => _PaginaGastosState();
}

class _PaginaGastosState extends State<PaginaGastos> {
  final _repo = AdminRepository.instance;

  bool _isLoading = true;

  Map<String, List<Producto>> _productosPorCategoria = {};
  List<Categoria> _categoriasDeGastos = [];
  Categoria? _selectedCategory;

  final List<pg.ItemGasto> _gastosCart = [];
  final ServicioListaCompras _servicioListaCompras = ServicioListaCompras();
  final Map<String, String> _mapUniqueToShoppingId = {};

  @override
  void initState() {
    super.initState();
    _repo.limpiarCache();
    _cargarDatosDeGastos();
  }

Future<void> _cargarDatosDeGastos() async {
  if (!mounted) return;

  // Puedes mostrar loading aquí si quieres, pero también lo haré al final:
  // setState(() => _isLoading = true);

  Map<String, List<Producto>> mapa = <String, List<Producto>>{};
  List<Categoria> cats = <Categoria>[];

  try {
    await _repo.cargarDatos();

    final productosRemotos = List<Producto>.from(_repo.getProductosGastos());
    final categoriasRemotas = List<Categoria>.from(_repo.getCategoriasGastos());

    cats = categoriasRemotas.isNotEmpty
        ? categoriasRemotas
        : List<Categoria>.from(CatalogoGastos.categories);

    if (productosRemotos.isNotEmpty) {
      for (final p in productosRemotos) {
        (mapa[p.categoriaId] ??= <Producto>[]).add(p);
      }
    } else {
      CatalogoGastos.productsByCategory.forEach((catId, list) {
        mapa[catId] = List<Producto>.from(list);
      });
    }
  } catch (e, st) {
    debugPrint('Error cargando gastos: $e\n$st');

    // Fallback local
    CatalogoGastos.productsByCategory.forEach((catId, list) {
      mapa[catId] = List<Producto>.from(list);
    });
    cats = List<Categoria>.from(CatalogoGastos.categories);
  }

  // Ordenamientos (se hacen en memoria, sin tocar el estado)
  cats.sort((a, b) => a.orden.compareTo(b.orden));
  for (final list in mapa.values) {
    list.sort((a, b) {
      final cmp = a.orden.compareTo(b.orden);
      return (cmp != 0)
          ? cmp
          : a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });
  }

  if (!mounted) return; // <- CLAVE

  setState(() {
    _productosPorCategoria = mapa;
    _categoriasDeGastos = cats;
    _selectedCategory = cats.isNotEmpty ? cats.first : null;
    _isLoading = false;
  });
}


  void _addGastoToCart(Producto producto) {
    final uniqueId = '${producto.id}_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _gastosCart.add(
        pg.ItemGasto(
          producto: producto,
          uniqueId: uniqueId,
          precioEditable: 0.0,
        ),
      );
    });
    // <<-- ÚNICO CAMBIO: Se elimina la siguiente línea para que el panel no se abra automáticamente.
    // _openGastosCart();
  }

  void _removeOneFromCart(String productId) {
    if (_gastosCart.isEmpty) return;
    final idx = _gastosCart.lastIndexWhere((e) => e.producto.id == productId);
    if (idx != -1) {
      final uniqueId = _gastosCart[idx].uniqueId;
      setState(() {
        _gastosCart.removeAt(idx);
        _mapUniqueToShoppingId.remove(uniqueId);
      });
    }
  }

  void _addGastoFromShopping(
    Producto producto,
    double precioEditable,
    String shoppingId,
  ) {
    final uniqueId = '${producto.id}_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _gastosCart.add(
        pg.ItemGasto(
          producto: producto,
          uniqueId: uniqueId,
          precioEditable: precioEditable,
        ),
      );
      _mapUniqueToShoppingId[uniqueId] = shoppingId;
    });
  }

  Future<void> _openShoppingList() async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const PaginaListaCompras()),
    );
    if (res is Map && res['action'] == 'comprar') {
      final producto = res['producto'] as Producto;
      final double precio = (res['precio'] as num?)?.toDouble() ?? producto.precio;
      final String shoppingId = res['shoppingId'] as String;
      _addGastoFromShopping(producto, precio, shoppingId);
      _openGastosCart();
    }
  }

  void _openGastosCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return pg.PanelGastos(
              items: _gastosCart,
              onClear: () {
                setState(() {
                  _gastosCart.clear();
                  _mapUniqueToShoppingId.clear();
                });
              },
              onRemoveItem: (uniqueId) {
                setState(() {
                  _gastosCart.removeWhere((e) => e.uniqueId == uniqueId);
                  _mapUniqueToShoppingId.remove(uniqueId);
                });
                setSheetState(() {});
              },
              onUpdatePrice: (uniqueId, newPrice) {
                setState(() {
                  final i = _gastosCart.indexWhere((e) => e.uniqueId == uniqueId);
                  if (i != -1) {
                    _gastosCart[i] = _gastosCart[i].copyWith(precioEditable: newPrice);
                  }
                });
                setSheetState(() {});
              },
              onSaveToShoppingList: _saveToShoppingList,
              onConfirm: (total) {
                Navigator.of(context).pop();
                _showPaymentPanelForExpenses(total);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _saveToShoppingList() async {
    if (_gastosCart.isEmpty) return;
    for (final it in _gastosCart) {
      await _servicioListaCompras.agregarItem(
        nombre: it.producto.nombre,
        cantidad: 1.0,
        unidad: null,
        precioEstimado: _norm(it.precioEditable),
        categoriaId: it.producto.categoriaId,
        productoId: it.producto.id,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añadido a lista de compras')),
      );
    }
  }

  void _showPaymentPanelForExpenses(double totalFromPanel) {
    if (_gastosCart.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => PanelPagoGastos(
        totalGasto: _norm(totalFromPanel),
        items: _gastosCart,
        onConfirm: (method, date) async {
          Navigator.of(ctx).pop();
          await _saveGasto(method, date);
        },
      ),
    );
  }

  Future<void> _saveGasto(PaymentMethod method, DateTime dateTime) async {
    if (_gastosCart.isEmpty) return;

    try {
      final items = _gastosCart
          .map((it) => GastoItem(
                id: it.producto.id,
                nombre: it.producto.nombre,
                precio: _norm(it.precioEditable),
                cantidad: 1.0,
                categoriaId: it.producto.categoriaId,
              ))
          .toList();

      final total = _gastosCart.fold<double>(0.0, (a, it) => a + it.precioEditable);
      final pagos = <String, double>{_metodoKey(method): _norm(total)};
      
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
      String nombre = 'Usuario';
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          final me = AppUser.fromFirestore(doc.data() as Map<String, dynamic>, uid);
          nombre = me.nombre;
        }
      } catch (_) {}

      final svc = context.read<ServicioGastos>();
      await svc.registrarGasto(
        proveedor: 'Proveedor',
        descripcion: 'Gasto registrado desde panel',
        items: items,
        pagos: pagos,
        usuarioId: uid,
        usuarioNombre: nombre,
        fecha: dateTime,
      );

      if (_mapUniqueToShoppingId.isNotEmpty) {
        await _servicioListaCompras.marcarCompradoPorIds(_mapUniqueToShoppingId.values);
      }

      if (!mounted) return;
      setState(() {
        _gastosCart.clear();
        _mapUniqueToShoppingId.clear();
      });

      final online = await hasInternet();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(online ? 'Gasto registrado' : 'Gasto en cola (offline, admin).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar gasto: $e')),
      );
    }
  }

  // ======= UI (El resto del build y widgets de UI no cambian) =======
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Producto> productosDeCategoria = _selectedCategory != null
        ? _productosPorCategoria[_selectedCategory!.id] ?? []
        : [];

    final qtyById = <String, int>{};
    for (final it in _gastosCart) {
      qtyById.update(it.producto.id, (v) => v + 1, ifAbsent: () => 1);
    }

    final cartCount = _gastosCart.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Gastos',
            style: GoogleFonts.cinzelDecorative(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Lista de Compras',
            onPressed: _openShoppingList,
          ),
        ],
      ),
      body: Column(
        children: [
          const NetStatusStrip(
            syncCaja: true,
            syncGastos: true,
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(width: 104, child: _buildCategoryRail()),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _buildGastosGrid(
                    productos: productosDeCategoria,
                    qtyById: qtyById,
                    categoryFallbackIcon:
                        _selectedCategory?.iconAssetPath ?? 'assets/icons/default.svg',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _gastosCart.isEmpty
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: _showClearGastosCartConfirmationDialog,
                  backgroundColor: Colors.grey.shade700,
                  tooltip: 'Vaciar lista de gastos',
                  mini: true,
                  heroTag: 'clear_gastos_fab',
                  child: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.extended(
                  onPressed: _openGastosCart,
                  heroTag: 'open_gastos_fab',
                  label: Text('Registrar ($cartCount)'),
                  icon: const Icon(Icons.shopping_cart_checkout),
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
    );
  }

  void _showClearGastosCartConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vaciar lista de gastos'),
        content: const Text('¿Seguro que quieres quitar todos los ítems?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _gastosCart.clear();
                _mapUniqueToShoppingId.clear();
              });
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Vaciar'),
          )
        ],
      ),
    );
  }

  Widget _buildCategoryRail() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        itemCount: _categoriasDeGastos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final cat = _categoriasDeGastos[i];
          final selected = cat.id == _selectedCategory?.id;
          return Tooltip(
            message: cat.nombre,
            waitDuration: const Duration(milliseconds: 300),
            child: _CategoryTile(
              cat: cat,
              selected: selected,
              onTap: () => setState(() => _selectedCategory = cat),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGastosGrid({
    required List<Producto> productos,
    required Map<String, int> qtyById,
    required String categoryFallbackIcon,
  }) {
    if (_selectedCategory == null) {
      return const Center(child: Text('Selecciona una categoría'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        int cols = 4;
        if (w < 480) cols = 2;
        else if (w < 720) cols = 3;
        else if (w < 1024) cols = 4;
        else if (w < 1280) cols = 5;
        else cols = 6;

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemCount: productos.length,
          itemBuilder: (context, index) {
            final p = productos[index];
            final qty = qtyById[p.id] ?? 0;
            return _ProductoTile(
              producto: p,
              currentQty: qty,
              fallbackImagePath: categoryFallbackIcon,
              onAdd: () => _addGastoToCart(p),
              onRemove: () => _removeOneFromCart(p.id),
            );
          },
        );
      },
    );
  }
}

// ... El resto de los widgets (_CategoryTile, _ProductoTile, ProductoImage, _CategoriaIcon) no necesitan cambios.
class _CategoryTile extends StatelessWidget {
  final Categoria cat;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.cat,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bg = selected ? theme.colorScheme.primary.withOpacity(.10) : theme.cardColor;
    final borderColor = selected ? theme.colorScheme.primary : Colors.grey.shade300;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: _CategoriaIcon(path: cat.iconAssetPath),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.nombre,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.05,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? theme.colorScheme.primary : null,
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, size: 14, color: theme.colorScheme.onPrimary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductoTile extends StatelessWidget {
  final Producto producto;
  final int currentQty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final String fallbackImagePath;

  const _ProductoTile({
    required this.producto,
    required this.currentQty,
    required this.onAdd,
    required this.onRemove,
    required this.fallbackImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmall = MediaQuery.of(context).size.width < 380;
    final minusSize = isSmall ? 32.0 : 36.0;

    return Material(
      color: theme.cardColor,
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: currentQty > 0 ? theme.colorScheme.primary : Colors.grey.shade300,
              width: currentQty > 0 ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          color: theme.colorScheme.surfaceVariant.withOpacity(.25),
                          alignment: Alignment.center,
                          child: ProductoImage(
                            path: (producto.imagenUrl ?? '').trim(),
                            fallback: fallbackImagePath,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      producto.nombre,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (currentQty > 0)
                  Positioned(
                    top: 6,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'x$currentQty',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (currentQty > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Material(
                      color: theme.colorScheme.primary,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onRemove,
                        child: SizedBox(
                          width: minusSize,
                          height: minusSize,
                          child: Icon(Icons.remove,
                              size: isSmall ? 18 : 20,
                              color: theme.colorScheme.onPrimary),
                        ),
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
}

class ProductoImage extends StatelessWidget {
  final String? path;
  final String? fallback;
  const ProductoImage({super.key, this.path, this.fallback});

  static bool _isSvg(String s) => s.toLowerCase().endsWith('.svg');
  static bool _isHttp(String s) => s.startsWith('http://') || s.startsWith('https://');
  static bool _isGs(String s) => s.startsWith('gs://');

  Future<String> _gsToUrl(String gs) async {
    final ref = FirebaseStorage.instance.refFromURL(gs);
    return ref.getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    String src = (path ?? '').trim();
    if (src.isEmpty) {
      final f = (fallback ?? '').trim();
      if (f.isNotEmpty) {
        if (_isHttp(f)) {
          if (_isSvg(f)) return SvgPicture.network(f, fit: BoxFit.contain);
          return CachedNetworkImage(imageUrl: f, fit: BoxFit.contain);
        }
        if (_isSvg(f)) return SvgPicture.asset(f, fit: BoxFit.contain);
        return Image.asset(f, fit: BoxFit.contain);
      }
      return const Icon(Icons.image_outlined, size: 40);
    }
    if (!_isHttp(src) && !_isGs(src)) {
      if (_isSvg(src)) return SvgPicture.asset(src, fit: BoxFit.contain);
      return Image.asset(src, fit: BoxFit.contain);
    }
    if (_isHttp(src)) {
      if (_isSvg(src)) return SvgPicture.network(src, fit: BoxFit.contain);
      return CachedNetworkImage(
        imageUrl: src,
        fit: BoxFit.contain,
        placeholder: (_, __) =>
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      );
    }
    return FutureBuilder<String>(
      future: _gsToUrl(src),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        final url = snap.data!;
        if (_isSvg(url)) return SvgPicture.network(url, fit: BoxFit.contain);
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, __) =>
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
        );
      },
    );
  }
}

class _CategoriaIcon extends StatelessWidget {
  final String path;
  const _CategoriaIcon({required this.path});

  static bool _isSvg(String s) => s.toLowerCase().endsWith('.svg');
  static bool _isHttp(String s) => s.startsWith('http://') || s.startsWith('https://');
  static bool _isGs(String s) => s.startsWith('gs://');

  Future<String> _gsToUrl(String gs) async {
    final ref = FirebaseStorage.instance.refFromURL(gs);
    return ref.getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    final src = path.trim();
    if (src.isEmpty) {
      return const Icon(Icons.category_outlined, size: 22);
    }
    if (!_isHttp(src) && !_isGs(src)) {
      if (_isSvg(src)) return SvgPicture.asset(src, fit: BoxFit.contain);
      return Image.asset(src, fit: BoxFit.contain);
    }
    if (_isHttp(src)) {
      if (_isSvg(src)) return SvgPicture.network(src, fit: BoxFit.contain);
      return CachedNetworkImage(
        imageUrl: src,
        fit: BoxFit.contain,
        placeholder: (_, __) =>
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported_outlined),
      );
    }
    return FutureBuilder<String>(
      future: _gsToUrl(src),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        final url = snap.data!;
        if (_isSvg(url)) return SvgPicture.network(url, fit: BoxFit.contain);
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, __) =>
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported_outlined),
        );
      },
    );
  }
}