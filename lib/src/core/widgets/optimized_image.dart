import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';
import 'dart:typed_data';

class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration? fadeInDuration;
  final bool enableCompression;
  final int compressionQuality;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration,
    this.enableCompression = true,
    this.compressionQuality = 85,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildErrorWidget();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: fadeInDuration ?? const Duration(milliseconds: 300),
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(),
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      cacheKey: _generateCacheKey(),
      imageBuilder: (context, imageProvider) {
        return Image(
          image: imageProvider,
          width: width,
          height: height,
          fit: fit,
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.grey, size: 32),
      ),
    );
  }

  String _generateCacheKey() {
    final key = '${imageUrl}_${width ?? ''}_${height ?? ''}';
    return key.hashCode.toString();
  }

  static Future<File> compressImage(File file, {int quality = 85}) async {
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        '${file.path}_compressed.jpg',
        quality: quality,
      );

      return result as File? ?? file;
    } catch (e) {
      debugPrint('Image compression failed: $e');
      return file;
    }
  }

  static Future<Uint8List> compressImageFromBytes(
    Uint8List bytes, {
    int quality = 85,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
      );

      return result;
    } catch (e) {
      debugPrint('Image compression failed: $e');
      return bytes;
    }
  }

  static void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
  }

  static void preloadImage(BuildContext context, String imageUrl) {
    if (imageUrl.isNotEmpty) {
      precacheImage(NetworkImage(imageUrl), context);
    }
  }
}
