// Game loop: update balls and broadcast state at fixed interval
const TICK_RATE = 20; // 20 times per second
const TICK_INTERVAL = 1000 / TICK_RATE;
let lastTick = Date.now();
function gameLoop() {
  const now = Date.now();
  const dt = (now - lastTick) / 50;
  lastTick = now;
  // Substep physics for better collision detection
  const substeps = 4;
  for (let i = 0; i < substeps; i++) {
    gameState.update(dt / substeps);
  }
  // --- Send balls, bands, and posts as binary ---
  const balls = gameState.getBalls();
  const bands = gameState.bands;
  const posts = gameState.posts;
  const buffer = encodeArenaState(balls, bands, posts);
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(buffer);
    }
  });
}
setInterval(gameLoop, TICK_INTERVAL);
const express = require('express');
const WebSocket = require('ws');
const path = require('path');
const { GameState, ARENA_SIZE } = require('./server/game/state');
const gameState = new GameState(); // Only one instance!
const { encodeBalls } = require('./server/game/ballBinary');
// Add this utility for bands and posts:
function encodeArenaState(balls, bands, posts) {
  // Format:
  // [ballCount, ...balls, bandCount, ...bands, postCount, ...posts]
  // Each ball: id (16 bytes), x, y, vx, vy (4x float32)
  // Each band: segmentCount, ...segments (x, y float32)
  // Each post: x, y (float32)
  const idLen = 16;
  const ballCount = balls.length;
  const bandCount = bands.length;
  const postCount = posts.length;
  let bandSegmentsTotal = 0;
  for (const band of bands) bandSegmentsTotal += band.segments.length;

  // Calculate total buffer size
  const ballBytes = 4 + ballCount * (idLen + 4 * 4); // 4 bytes for count, idLen for id, 4 floats (x, y, vx, vy)
  const bandBytes = 4 + bands.reduce((sum, band) => sum + 4 + band.segments.length * 8, 0); // 4 bytes for count, 4 for segCount, 8 per segment
  const postBytes = 4 + postCount * 8;
  const totalBytes = ballBytes + bandBytes + postBytes;

  const buffer = Buffer.allocUnsafe(totalBytes);
  let offset = 0;

  // Balls
  buffer.writeUInt32LE(ballCount, offset); offset += 4;
  balls.forEach(b => {
    const idBuf = Buffer.alloc(idLen);
    idBuf.write(b.id ? String(b.id) : '', 0, idLen, 'utf8');
    idBuf.copy(buffer, offset); offset += idLen;
    buffer.writeFloatLE(b.x, offset); offset += 4;
    buffer.writeFloatLE(b.y, offset); offset += 4;
    buffer.writeFloatLE(b.vx, offset); offset += 4;
    buffer.writeFloatLE(b.vy, offset); offset += 4;
  });

  // Bands
  buffer.writeUInt32LE(bandCount, offset); offset += 4;
  bands.forEach(band => {
    buffer.writeUInt32LE(band.segments.length, offset); offset += 4;
    band.segments.forEach(seg => {
      buffer.writeFloatLE(seg.x, offset); offset += 4;
      buffer.writeFloatLE(seg.y, offset); offset += 4;
    });
  });

  // Posts
  buffer.writeUInt32LE(postCount, offset); offset += 4;
  posts.forEach(post => {
    buffer.writeFloatLE(post.x, offset); offset += 4;
    buffer.writeFloatLE(post.y, offset); offset += 4;
  });

  return buffer;
}

const app = express();
console.log('🧠 Running on process ID:', process.pid);
const PORT = process.env.PORT || 3002;
const server = app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
const wss = new WebSocket.Server({ server });

// Serve static files from bump_zone/server/public/
app.use(express.static(path.join(__dirname, 'server', 'public')));

// WebSocket connection handling
wss.on('connection', (ws) => {
  // Send arena size to the client on connect
  ws.send(JSON.stringify({ type: 'arenaInfo', size: ARENA_SIZE }));

  // Send current band settings to the client on connect
  if (gameState.bands.length > 0) {
    const b = gameState.bands[0];
    ws.send(JSON.stringify({
      type: 'bandSettings',
      springConstant: Number(b.springConstant),
      dampingCoeff: Number(b.dampingCoeff),
      mass: Number(b.mass),
      restitution: Number(b.coefficientOfRestitution),
    }));
    // This print statement is present:
    console.log('[SERVER] Sent bandSettings on connect:', {
      springConstant: b.springConstant,
      dampingCoeff: b.dampingCoeff,
      mass: b.mass,
      restitution: b.coefficientOfRestitution,
    });
  }
  console.log('🔗 New WebSocket connection established');

  // --- Ping/Pong keep-alive mechanism ---
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });

  ws.on('message', (message) => {
    try {
      // Convert Buffer to string if necessary
      const jsonString = typeof message === 'string' ? message : message.toString('utf8');
      console.log('📩 Received message:', jsonString);
      const data = JSON.parse(jsonString);

      if (data.type === 'join' || data.type === 'getPlayers') {
        if (data.type === 'join') {
          console.log(`👤 Attempting to add player: ${data.username}`);
          const result = gameState.addPlayer(data.username, ws);
          if (!result.success) {
            console.warn(`⚠️ Username taken: ${data.username}`);
            ws.send(JSON.stringify({ type: 'error', message: 'username_taken' }));
            return;
          }
          console.log(`✅ Player added: ${data.username} (ID: ${result.playerId})`);
          // Send welcome message with playerId to the joining client
          ws.send(JSON.stringify({ type: 'welcome', playerId: result.playerId }));
        }

        const players = gameState.getPlayers();
        console.log('🧑‍🤝‍🧑 Players online:', players.length, '| Usernames:', players.map(p => p.username).join(', '));

        const simplifiedPlayers = players.map(p => ({
          playerId: p.playerId,
          username: p.username
        }));

        // For join, broadcast to all. For getPlayers, send only to requester
        if (data.type === 'join') {
          wss.clients.forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
              console.log('📡 Broadcasting player list to client');
              client.send(JSON.stringify({ type: 'playerList', players: simplifiedPlayers }));
            }
          });
        } else {
          ws.send(JSON.stringify({ type: 'playerList', players: simplifiedPlayers }));
        }
      } else if (data.type === 'move') {
        // Find playerId by socket
        const player = gameState.getPlayerBySocket(ws);
        if (player && data.direction) {
          gameState.handleMove(player.playerId, data.direction.dx, data.direction.dy);
        }
      } else if (data.type === 'setBandSettings') {
        // Update band settings for all bands
        if (typeof data.springConstant === 'number') gameState.bands.forEach(b => b.springConstant = data.springConstant);
        if (typeof data.dampingCoeff === 'number') gameState.bands.forEach(b => b.dampingCoeff = data.dampingCoeff);
        if (typeof data.mass === 'number') gameState.bands.forEach(b => b.mass = data.mass);
        if (typeof data.restitution === 'number') gameState.bands.forEach(b => b.coefficientOfRestitution = data.restitution);
        console.log('[SERVER] Band settings updated:', {
          springConstant: data.springConstant,
          dampingCoeff: data.dampingCoeff,
          mass: data.mass,
          restitution: data.restitution,
        });
        // Broadcast new settings to all clients
        wss.clients.forEach((client) => {
          if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({
              type: 'bandSettings',
              springConstant: data.springConstant,
              dampingCoeff: data.dampingCoeff,
              mass: data.mass,
              restitution: data.restitution,
            }));
          }
        });
      } else if (data.type === 'getBandSettings') {
        if (gameState.bands.length > 0) {
          const b = gameState.bands[0];
          ws.send(JSON.stringify({
            type: 'bandSettings',
            springConstant: Number(b.springConstant),
            dampingCoeff: Number(b.dampingCoeff),
            mass: Number(b.mass),
            restitution: Number(b.coefficientOfRestitution),
          }));
        }
      }
    } catch (err) {
      console.error('❌ Failed to parse message:', err);
      ws.send(JSON.stringify({ type: 'error', message: 'invalid_json' }));
    }
  });

  // Set up ping interval for all clients
  const interval = setInterval(() => {
    wss.clients.forEach((ws) => {
      if (ws.isAlive === false) {
        console.log('Terminating unresponsive client');
        return ws.terminate();
      }
      ws.isAlive = false;
      ws.ping();
    });
  }, 30000); // 30 seconds

  wss.on('close', function close() {
    clearInterval(interval);
  });

  ws.on('close', () => {
    console.log('❎ WebSocket connection closed');
    const removed = gameState.removePlayer(ws);

    const players = gameState.getPlayers();
    console.log('🧑‍🤝‍🧑 Players remaining:', players.length, '| Usernames:', players.map(p => p.username).join(', '));

    const simplifiedPlayers = players.map(p => ({
      playerId: p.playerId,
      username: p.username
    }));

    wss.clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        console.log('📡 Broadcasting updated player list after disconnect');
        client.send(JSON.stringify({ type: 'playerList', players: simplifiedPlayers }));
      }
    });
  });
});

// Fallback to serve index.html for SPA routing
app.get('*', (req, res) => {
  console.log(`📄 Serving index.html for route: ${req.url}`);
  res.sendFile(path.join(__dirname, 'server', 'public', 'index.html'));
});
