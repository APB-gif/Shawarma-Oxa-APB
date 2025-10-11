import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shawarma_pos_nuevo/widgets/cached_svg_image.dart';

/// Muestra imágenes desde URL http(s) o rutas gs:// de Firebase Storage.
/// Cachea en memoria el downloadURL para evitar reconsultas.
class StorageImage extends StatelessWidget {
  final String? urlOrGs;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;

  const StorageImage({
    super.key,
    required this.urlOrGs,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.placeholder,
  });

  // Nota: el widget devuelve un fallback visual (placeholder) cuando la
  // descarga de la imagen falla (por ejemplo 404 o token inválido). Esto
  // previene que Image.network lance una excepción que haga caer la app.

  static final Map<String, String> _cache = {};

  Future<String> _resolve(String pathOrUrl) async {
    if (_cache.containsKey(pathOrUrl)) return _cache[pathOrUrl]!;
    if (pathOrUrl.startsWith('gs://')) {
      final ref = FirebaseStorage.instance.refFromURL(pathOrUrl);
      final url = await ref.getDownloadURL();
      _cache[pathOrUrl] = url;
      return url;
    }
    _cache[pathOrUrl] = pathOrUrl;
    return pathOrUrl;
  }

  @override
  Widget build(BuildContext context) {
    final src = (urlOrGs ?? '').trim();
    if (src.isEmpty) {
      return placeholder ?? const Icon(Icons.inventory_2_outlined, size: 48);
    }
    return FutureBuilder<String>(
      future: _resolve(src),
      builder: (context, snap) {
        if (!snap.hasData) {
          return placeholder ??
              const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final url = snap.data!;
        if (url.toLowerCase().endsWith('.svg')) {
          return CachedSvgImage(url: url, width: width, height: height, imageUrl: '',);
        }
        return Image.network(
          url,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (ctx, error, stack) => Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, size: 24, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }
}
