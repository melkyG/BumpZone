// Utility for encoding/decoding balls as binary (no id for now)
function encodeBalls(balls) {
  const count = balls.length;
  const idLen = 16; // bytes per id (increase if your ids are longer)
  const buffer = Buffer.allocUnsafe(4 + count * (idLen + 16));
  buffer.writeUInt32LE(count, 0);
  balls.forEach((b, i) => {
    // Write id as fixed-length UTF-8 string (padded with 0)
    const idBuf = Buffer.alloc(idLen);
    idBuf.write(b.id ? String(b.id) : '', 0, idLen, 'utf8');
    idBuf.copy(buffer, 4 + i * (idLen + 16));
    buffer.writeFloatLE(b.x, 4 + i * (idLen + 16) + idLen + 0);
    buffer.writeFloatLE(b.y, 4 + i * (idLen + 16) + idLen + 4);
    buffer.writeFloatLE(b.vx, 4 + i * (idLen + 16) + idLen + 8);
    buffer.writeFloatLE(b.vy, 4 + i * (idLen + 16) + idLen + 12);
  });
  return buffer;
}

function decodeBalls(buffer) {
  const count = buffer.readUInt32LE(0);
  const idLen = 16;
  const balls = [];
  for (let i = 0; i < count; i++) {
    const base = 4 + i * (idLen + 16);
    const id = buffer.toString('utf8', base, base + idLen).replace(/\0.*$/g, '');
    balls.push({
      id,
      x: buffer.readFloatLE(base + idLen + 0),
      y: buffer.readFloatLE(base + idLen + 4),
      vx: buffer.readFloatLE(base + idLen + 8),
      vy: buffer.readFloatLE(base + idLen + 12),
    });
  }
  return balls;
}

module.exports = { encodeBalls, decodeBalls };
