import 'dart:typed_data';
import 'package:bump_zone/models/ball.dart';

List<Ball> decodeBalls(Uint8List bytes) {
  final byteData = ByteData.sublistView(bytes);
  final count = byteData.getUint32(0, Endian.little);
  final balls = <Ball>[];
  for (int i = 0; i < count; i++) {
    final base = 4 + i * 16;
    final x = byteData.getFloat32(base + 0, Endian.little);
    final y = byteData.getFloat32(base + 4, Endian.little);
    final vx = byteData.getFloat32(base + 8, Endian.little);
    final vy = byteData.getFloat32(base + 12, Endian.little);
    balls.add(Ball(id: '$i', x: x, y: y, vx: vx, vy: vy));
  }
  return balls;
}
