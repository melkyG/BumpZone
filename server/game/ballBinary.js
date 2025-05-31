// Utility for encoding/decoding balls as binary (no id for now)
function encodeBalls(balls) {
  const count = balls.length;
  const buffer = Buffer.allocUnsafe(4 + count * 16);
  buffer.writeUInt32LE(count, 0);
  balls.forEach((b, i) => {
    buffer.writeFloatLE(b.x, 4 + i * 16 + 0);
    buffer.writeFloatLE(b.y, 4 + i * 16 + 4);
    buffer.writeFloatLE(b.vx, 4 + i * 16 + 8);
    buffer.writeFloatLE(b.vy, 4 + i * 16 + 12);
  });
  return buffer;
}

function decodeBalls(buffer) {
  const count = buffer.readUInt32LE(0);
  const balls = [];
  for (let i = 0; i < count; i++) {
    const base = 4 + i * 16;
    balls.push({
      x: buffer.readFloatLE(base + 0),
      y: buffer.readFloatLE(base + 4),
      vx: buffer.readFloatLE(base + 8),
      vy: buffer.readFloatLE(base + 12),
    });
  }
  return balls;
}

module.exports = { encodeBalls, decodeBalls };
