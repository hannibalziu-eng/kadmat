import 'package:flutter/widgets.dart';

int? _cachePixelsFor(
  BuildContext context,
  double? logicalPixels, {
  int maxPixels = 2048,
}) {
  if (logicalPixels == null || !logicalPixels.isFinite || logicalPixels <= 0) {
    return null;
  }

  final devicePixelRatio =
      MediaQuery.maybeDevicePixelRatioOf(context) ??
      View.of(context).devicePixelRatio;
  final scaledPixels = (logicalPixels * devicePixelRatio).round();
  if (scaledPixels <= 0) return null;

  final pixelCap = maxPixels < 1 ? 1 : maxPixels;
  return scaledPixels.clamp(1, pixelCap).toInt();
}

int? cacheWidthFor(
  BuildContext context,
  double? logicalWidth, {
  int maxPixels = 2048,
}) {
  return _cachePixelsFor(context, logicalWidth, maxPixels: maxPixels);
}

int? cacheHeightFor(
  BuildContext context,
  double? logicalHeight, {
  int maxPixels = 2048,
}) {
  return _cachePixelsFor(context, logicalHeight, maxPixels: maxPixels);
}
