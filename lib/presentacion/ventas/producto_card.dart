import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart'; // <- para gs://
import '../../datos/modelos/producto.dart';
import '../../widgets/cached_svg_image.dart';

typedef AddToCart = void Function(Producto p);

class ProductoCard extends StatelessWidget {
  final Producto producto;
  final int qty;
  final AddToCart onAdd;
  final bool showAddButton;

  /// (Opcional) Asset local como fallback si no hay imagen
  final String? fallbackAssetSvg;

  /// (Opcional) Cambia el texto mostrado (p.ej. 'Costo' en Gastos)
  final String? labelPrecio;

  /// (Opcional) Permite mostrar otro valor (p.ej., costo editable en Gastos)
  final double? precioOverride;

  const ProductoCard({
    super.key,
    required this.producto,
    required this.qty,
    required this.onAdd,
    required this.showAddButton,
    this.fallbackAssetSvg,
    this.labelPrecio,
    this.precioOverride,
  });

  // === Helpers ===
  bool _isSvgUrl(String? src) {
    if (src == null) return false;
    final s = src.toLowerCase();
    return s.endsWith('.svg') ||
        s.contains('image%2fsvg') ||
        s.contains('svg+xml');
  }

  bool _isGsUrl(String? src) => src?.startsWith('gs://') ?? false;

  // ====== 🚀 OPTIMIZACIÓN: caches compartidos ======
  static final Map<String, String> _gsDownloadCache =
      <String, String>{}; // gs:// -> https
  static final Map<String, Future<String>> _gsPending =
      <String, Future<String>>{}; // evita llamadas duplicadas
  static final Set<String> _precached = <String>{}; // evita precache repetido

  Future<String?> _gsToHttps(String? src) async {
    if (src == null || src.trim().isEmpty) return null;
    final key = src.trim();

    // 1) cache en memoria
    final cached = _gsDownloadCache[key];
    if (cached != null) return cached;

    // 2) hay una solicitud en curso? reusa el mismo Future
    final pending = _gsPending[key];
    if (pending != null) {
      try {
        final url = await pending;
        _gsDownloadCache[key] = url;
        return url;
      } catch (_) {
        return null;
      }
    }

    // 3) crea la solicitud, guárdala en pending, y resuelve
    final future = FirebaseStorage.instance.refFromURL(key).getDownloadURL();
    _gsPending[key] = future;
    try {
      final url = await future;
      _gsDownloadCache[key] = url;
      return url;
    } catch (_) {
      return null;
    } finally {
      _gsPending.remove(key);
    }
  }

  void _precacheOnce(BuildContext context, String url) {
    if (_precached.contains(url)) return;
    _precached.add(url);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(Image.network(url).image, context);
    });
  }

  Widget _buildImageFromUrl(String url, BuildContext context) {
    const placeholder = SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2),
    );

    // Precarga en caché para futuros rebuilds/scrolls
    _precacheOnce(context, url);

    if (_isSvgUrl(url)) {
      // Tu CachedSvgImage exige imageUrl y url
      return CachedSvgImage(
        key: ValueKey(url),
        imageUrl: url,
        url: url,
        width: 140,
        height: 140,
        placeholder: placeholder,
      );
    }
    return Image.network(
      url,
      width: 140,
      height: 140,
      fit: BoxFit.contain,
      loadingBuilder: (ctx, child, progress) =>
          progress == null ? child : placeholder,
      errorBuilder: (ctx, err, st) =>
          Icon(Icons.fastfood_outlined, size: 80, color: Colors.grey.shade400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Fuente de imagen (http/https o gs://)
    final String? src = producto.imagenUrl;

    // Precio mostrado (permite override SIN afectar Ventas)
    final double precioMostrado = precioOverride ?? producto.precio;

    String precioTexto(double v) {
      final base = 'S/ ${v.toStringAsFixed(2)}';
      if (labelPrecio == null || labelPrecio!.trim().isEmpty) return base;
      return '$labelPrecio: $base';
    }

    const spinner = SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2),
    );

    Widget imageWidget;
    if (src == null || src.trim().isEmpty) {
      if (fallbackAssetSvg != null && fallbackAssetSvg!.isNotEmpty) {
        imageWidget = Image.asset(fallbackAssetSvg!, fit: BoxFit.contain);
      } else {
        imageWidget = Icon(Icons.fastfood_outlined,
            size: 80, color: Colors.grey.shade400);
      }
    } else if (_isGsUrl(src)) {
      // 🔁 Ahora reusa/memoiza la resolución gs:// → https y hace precache
      imageWidget = FutureBuilder<String?>(
        future: _gsToHttps(src),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return spinner;
          final url = snap.data;
          if (url == null || url.isEmpty) {
            return Icon(Icons.fastfood_outlined,
                size: 80, color: Colors.grey.shade400);
          }
          return _buildImageFromUrl(url, context);
        },
      );
    } else {
      // http/https como siempre (Ventas queda igual)
      imageWidget = _buildImageFromUrl(src, context);
    }

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Center(child: imageWidget)),
                const SizedBox(height: 8),
                Text(
                  producto.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  precioTexto(precioMostrado),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (showAddButton)
                  FilledButton.icon(
                    onPressed: () => onAdd(producto),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                  ),
                if (qty > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('En carrito: $qty',
                        style: theme.textTheme.labelMedium),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
