import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Carga un SVG remoto con:
/// 1) Cache en memoria (rápido entre categorías)
/// 2) Cache local de `flutter_cache_manager`
/// 3) Fallback por red sin errores rojos
class CachedSvgImage extends StatefulWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Widget? placeholder;

  const CachedSvgImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.placeholder, required String url,
  });

  @override
  State<CachedSvgImage> createState() => _CachedSvgImageState();
}

class _CachedSvgImageState extends State<CachedSvgImage> {
  /// Cache en memoria para respuestas instantáneas
  static final Map<String, Uint8List> _memCache = <String, Uint8List>{};

  late Future<Uint8List?> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = _loadBytes();
  }

  @override
  void didUpdateWidget(covariant CachedSvgImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      // La URL cambió: regenerar el future para que no se “pegue” la imagen previa
      _bytesFuture = _loadBytes();
      setState(() {});
    }
  }

  Future<Uint8List?> _loadBytes() async {
    final url = widget.imageUrl;
    if (url.isEmpty) return null;

    // 1) Memoria
    final mem = _memCache[url];
    if (mem != null) return mem;

    // 2) Cache local (archivo)
    try {
      final cached = await DefaultCacheManager().getFileFromCache(url);
      if (cached != null) {
        try {
          final b = await cached.file.readAsBytes();
          _memCache[url] = b;
          return b;
        } catch (_) {}
      }
    } catch (_) {}

    // 3) Descarga y cachea (stream) — compatible con web
    try {
      final stream =
          DefaultCacheManager().getFileStream(url, withProgress: false);
      await for (final resp in stream) {
        if (resp is FileInfo) {
          try {
            final b = await resp.file.readAsBytes();
            _memCache[url] = b;
            return b;
          } catch (_) {
            break;
          }
        }
      }
    } catch (_) {}

    // 4) Fallback directo por red (sin cache manager)
    try {
      final uri = Uri.parse(url);
      final bd = await NetworkAssetBundle(uri).load(url);
      final b = bd.buffer.asUint8List();
      _memCache[url] = b;
      return b;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.placeholder ??
        SizedBox(
          width: widget.width ?? 120,
          height: widget.height ?? 120,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );

    return FutureBuilder<Uint8List?>(
      future: _bytesFuture,
      builder: (context, snap) {
        // 1) Tenemos bytes
        if (snap.connectionState == ConnectionState.done &&
            snap.data != null) {
          return SvgPicture.memory(
            snap.data!,
            height: widget.height,
            width: widget.width,
            fit: widget.fit,
            // evita parpadeo cuando cambia de frame
            allowDrawingOutsideViewBox: true,
            clipBehavior: Clip.hardEdge,
          );
        }

        // 2) Error o sin bytes: render directo por red
        if (snap.hasError ||
            (snap.connectionState == ConnectionState.done &&
                snap.data == null)) {
          return SvgPicture.network(
            widget.imageUrl,
            height: widget.height,
            width: widget.width,
            fit: widget.fit,
            placeholderBuilder: (_) => placeholder,
            // sin errorBuilder → evita “pantalla roja”
          );
        }

        // 3) Cargando
        return placeholder;
      },
    );
  }
}
