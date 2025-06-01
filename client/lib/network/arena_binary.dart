import 'dart:typed_data';
import 'dart:convert';
import 'package:bump_zone/models/ball.dart';

class BandSegment {
  final double x, y;
  BandSegment(this.x, this.y);
}

class Band {
  final List<BandSegment> segments;
  Band(this.segments);
}

class ArenaState {
  final List<Ball> balls;
  final List<Band> bands;
  final List<BandSegment> posts;
  ArenaState({required this.balls, required this.bands, required this.posts});
}

ArenaState decodeArenaState(Uint8List bytes) {
  final byteData = ByteData.sublistView(bytes);
  int offset = 0;
  const idLen = 16;

  // Balls
  final ballCount = byteData.getUint32(offset, Endian.little); offset += 4;
  final balls = <Ball>[];
  for (int i = 0; i < ballCount; i++) {
    final idBytes = bytes.sublist(offset, offset + idLen);
    final id = utf8.decode(idBytes.where((b) => b != 0).toList());
    offset += idLen;
    final x = byteData.getFloat32(offset, Endian.little); offset += 4;
    final y = byteData.getFloat32(offset, Endian.little); offset += 4;
    final vx = byteData.getFloat32(offset, Endian.little); offset += 4;
    final vy = byteData.getFloat32(offset, Endian.little); offset += 4;
    balls.add(Ball(id: id, x: x, y: y, vx: vx, vy: vy));
  }

  // Bands
  final bandCount = byteData.getUint32(offset, Endian.little); offset += 4;
  final bands = <Band>[];
  for (int i = 0; i < bandCount; i++) {
    final segCount = byteData.getUint32(offset, Endian.little); offset += 4;
    final segments = <BandSegment>[];
    for (int j = 0; j < segCount; j++) {
      final x = byteData.getFloat32(offset, Endian.little); offset += 4;
      final y = byteData.getFloat32(offset, Endian.little); offset += 4;
      segments.add(BandSegment(x, y));
    }
    bands.add(Band(segments));
  }

  // Posts
  final postCount = byteData.getUint32(offset, Endian.little); offset += 4;
  final posts = <BandSegment>[];
  for (int i = 0; i < postCount; i++) {
    final x = byteData.getFloat32(offset, Endian.little); offset += 4;
    final y = byteData.getFloat32(offset, Endian.little); offset += 4;
    posts.add(BandSegment(x, y));
  }

  return ArenaState(balls: balls, bands: bands, posts: posts);
}
