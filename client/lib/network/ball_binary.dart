import 'dart:typed_data';
import 'dart:convert';
import 'package:bump_zone/models/ball.dart';

List<Ball> decodeBalls(Uint8List bytes) {
  final byteData = ByteData.sublistView(bytes);
  final count = byteData.getUint32(0, Endian.little);
  const int idLen = 16;
  final balls = <Ball>[];
  for (int i = 0; i < count; i++) {
    final base = 4 + i * (idLen + 16);
    // Decode id as UTF-8 string, trim nulls
    final idBytes = bytes.sublist(base, base + idLen);
    final id = utf8.decode(idBytes.where((b) => b != 0).toList());
    final x = byteData.getFloat32(base + idLen + 0, Endian.little);
    final y = byteData.getFloat32(base + idLen + 4, Endian.little);
    final vx = byteData.getFloat32(base + idLen + 8, Endian.little);
    final vy = byteData.getFloat32(base + idLen + 12, Endian.little);
    balls.add(Ball(id: id, x: x, y: y, vx: vx, vy: vy));
  }
  return balls;
}
