import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class AppQuestionImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool enableZoomOnTap;

  const AppQuestionImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.enableZoomOnTap = true,
  });

  /// Helper to convert a picked image's bytes into a clean Base64 data string
  static String bytesToBase64(Uint8List bytes, {String mimeType = 'image/jpeg'}) {
    final base64Str = base64Encode(bytes);
    return 'data:$mimeType;base64,$base64Str';
  }

  /// Decode Base64 data or raw Base64 string into bytes
  static Uint8List? _tryDecodeBase64(String source) {
    try {
      final clean = source.contains(',') ? source.split(',').last : source;
      return base64Decode(clean.trim());
    } catch (_) {
      return null;
    }
  }

  bool get _isBase64 {
    if (imageUrl == null || imageUrl!.isEmpty) return false;
    final trimmed = imageUrl!.trim();
    return trimmed.startsWith('data:image') || (!trimmed.startsWith('http://') && !trimmed.startsWith('https://'));
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final trimmed = imageUrl!.trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(12);

    Widget imageWidget;

    if (_isBase64) {
      final bytes = _tryDecodeBase64(trimmed);
      if (bytes == null) {
        imageWidget = _buildFallback(isDark);
      } else {
        imageWidget = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (ctx, err, stack) => _buildFallback(isDark),
        );
      }
    } else {
      imageWidget = Image.network(
        trimmed,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height ?? 120,
            alignment: Alignment.center,
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (ctx, err, stack) => _buildFallback(isDark),
      );
    }

    final clipped = ClipRRect(
      borderRadius: effectiveRadius,
      child: imageWidget,
    );

    if (!enableZoomOnTap) {
      return clipped;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showZoomDialog(context, trimmed),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            clipped,
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.zoom_in_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback(bool isDark) {
    return Container(
      width: width,
      height: height ?? 100,
      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_rounded, size: 28, color: Colors.grey.shade400),
          const SizedBox(height: 4),
          Text(
            'Image unavailable',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _showZoomDialog(BuildContext context, String source) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        Widget content;
        if (_isBase64) {
          final bytes = _tryDecodeBase64(source);
          content = bytes != null
              ? Image.memory(bytes, fit: BoxFit.contain)
              : _buildFallback(true);
        } else {
          content = Image.network(
            source,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => _buildFallback(true),
          );
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: content,
              ),
              Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
