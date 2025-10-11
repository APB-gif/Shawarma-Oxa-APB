
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shawarma_pos_nuevo/datos/modelos/producto.dart';
import 'package:shawarma_pos_nuevo/widgets/cached_svg_image.dart';

typedef AddToCart = void Function(Producto p);

class CatalogoVentas extends StatelessWidget {
  final List<Producto> productos;
  final AddToCart onAdd;
  final Map<String, int> cartQuantities;
  final bool showAddButton;
  final double childAspectRatio;
  /// Si un producto no tiene `imagenUrl`, se usará este asset SVG como fallback (por ejemplo el ícono de la categoría).
  final String? fallbackAssetSvg;

  const CatalogoVentas({
    super.key,
    required this.productos,
    required this.onAdd,
    required this.cartQuantities,
    this.showAddButton = true,
    this.childAspectRatio = 1.0,
    this.fallbackAssetSvg,
  });

  @override
  Widget build(BuildContext context) {
    if (productos.isEmpty) {
      return const Center(child: Text('Sin productos para mostrar.'));
    }

    final cross = MediaQuery.of(context).size.width > 1200 ? 4 : 3;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: productos.length,
      itemBuilder: (context, i) {
        final p = productos[i];
        final q = cartQuantities[p.id] ?? 0;
        return _ProductCard(
          producto: p,
          qty: q,
          onAdd: onAdd,
          showAddButton: showAddButton,
          fallbackAssetSvg: fallbackAssetSvg,
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Producto producto;
  final int qty;
  final AddToCart onAdd;
  final bool showAddButton;
  final String? fallbackAssetSvg;

  const _ProductCard({
    required this.producto,
    required this.qty,
    required this.onAdd,
    required this.showAddButton,
    this.fallbackAssetSvg,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 0,
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: showAddButton ? () => onAdd(producto) : null,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(child: _ProductImage(src: producto.imagenUrl, fallbackAssetSvg: fallbackAssetSvg)),
                const SizedBox(height: 8),
                Text(
                  producto.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('S/ ${producto.precio.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                if (showAddButton)
                  FilledButton.icon(
                    onPressed: () => onAdd(producto),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                  ),
                if (qty > 0) Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('En carrito: $qty', style: theme.textTheme.labelMedium),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? src;
  final String? fallbackAssetSvg;
  const _ProductImage({required this.src, this.fallbackAssetSvg});

  bool get _isNetwork {
    final s = src ?? '';
    return s.startsWith('http://') || s.startsWith('https://');
  }

  bool get _isSvg {
    final s = src ?? '';
    try {
      final uri = Uri.parse(s);
      final path = uri.path.toLowerCase();
      return path.endsWith('.svg') || path.contains('.svg');
    } catch (_) {
      return s.toLowerCase().contains('.svg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(Icons.lunch_dining, size: 72, color: Theme.of(context).colorScheme.primary);

    if (src == null || src!.trim().isEmpty) {
      if (fallbackAssetSvg != null && fallbackAssetSvg!.isNotEmpty) {
        return Center(child: SvgPicture.asset(fallbackAssetSvg!, height: 120, fit: BoxFit.contain));
      }
      return Center(child: placeholder);
    }

    try {
      if (_isNetwork) {
        if (_isSvg) {
          return Center(child: CachedSvgImage(imageUrl: src!, height: 120, width: 120, url: '',));
        } else {
          return Center(child: Image.network(src!, height: 120, fit: BoxFit.contain));
        }
      } else {
        if (_isSvg) {
          return Center(child: SvgPicture.asset(src!, height: 120, fit: BoxFit.contain));
        } else {
          return Center(child: Image.asset(src!, height: 120, fit: BoxFit.contain));
        }
      }
    } catch (_) {
      if (fallbackAssetSvg != null && fallbackAssetSvg!.isNotEmpty) {
        return Center(child: SvgPicture.asset(fallbackAssetSvg!, height: 120, fit: BoxFit.contain));
      }
      return Center(child: placeholder);
    }
  }
}
