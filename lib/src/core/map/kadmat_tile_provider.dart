import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

TileProvider kadmatTileProvider() {
  // Use cancellable tile requests across platforms to reduce useless in-flight
  // downloads while panning/zooming maps on real devices.
  return CancellableNetworkTileProvider();
}
