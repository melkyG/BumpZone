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
      // Send balls as JSON with color for rendering
      const jsonBalls = balls.map(b => ({
        id: b.id,
        x: b.x,
        y: b.y,
        vx: b.vx,
        vy: b.vy,
        color: b.color, // include color if present
        stamina: b.stamina, // include stamina
        mass: b.mass // include mass
      }));
      client.send(JSON.stringify({
        type: 'balls',
        balls: jsonBalls
      }));
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
// Add these constants for defaults:
const {
  BAND_SPRING_CONSTANT,
  BAND_DAMPING_COEFF,
  BAND_MASS,
  BAND_COEFFICIENT_OF_RESTITUTION,
  BAND_SEGMENTS_PER_SIDE,
  BAND_REST_LENGTH_SCALE
} = require('./server/game/state');
// Add this utility for bands and posts:
function encodeArenaState(balls, bands, posts) {
  // Format:
  // [ballCount, ...balls, bandCount, ...bands, postCount, ...posts]
  // Each ball: id (16 bytes), x, y, vx, vy, stamina (5x float32)
  const idLen = 16;
  const ballCount = balls.length;
  const bandCount = bands.length;
  const postCount = posts.length;
  let bandSegmentsTotal = 0;
  for (const band of bands) bandSegmentsTotal += band.segments.length;

  // Calculate total buffer size
  // 4 bytes for count, idLen for id, 5 floats (x, y, vx, vy, stamina)
  const ballBytes = 4 + ballCount * (idLen + 5 * 4);
  const bandBytes = 4 + bands.reduce((sum, band) => sum + 4 + band.segments.length * 8, 0);
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
    buffer.writeFloatLE(typeof b.stamina === 'number' ? b.stamina : 1.0, offset); offset += 4; // Add stamina
    // NOTE: color is NOT sent in the binary buffer!
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
      segmentsPerSide: Number(b.segmentsPerSide), // <-- add
      restLengthScale: Number(b.restLengthScale), // <-- add
    }));
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
          // Accept color from client if provided
          const result = gameState.addPlayer(data.username, ws, data.color);
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
          username: p.username,
          color: p.color,
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
          // Pass burst flag to handleMove
          gameState.handleMove(player.playerId, data.direction.dx, data.direction.dy, !!data.burst);
        }
      } else if (data.type === 'setBandSettings') {
        // Update band settings for all bands
        if (typeof data.springConstant === 'number') gameState.bands.forEach(b => b.springConstant = data.springConstant);
        if (typeof data.dampingCoeff === 'number') gameState.bands.forEach(b => b.dampingCoeff = data.dampingCoeff);
        if (typeof data.mass === 'number') gameState.bands.forEach(b => b.mass = data.mass);
        if (typeof data.restitution === 'number') gameState.bands.forEach(b => b.coefficientOfRestitution = data.restitution);

        // Fix: Avoid optional chaining for Node.js compatibility
        var segmentsPerSide = (gameState.bands.length > 0 && typeof gameState.bands[0].segmentsPerSide === 'number')
          ? gameState.bands[0].segmentsPerSide
          : 35;
        var restLengthScale = (gameState.bands.length > 0 && typeof gameState.bands[0].restLengthScale === 'number')
          ? gameState.bands[0].restLengthScale
          : 1.0;

        let needRebuild = false;
        if (typeof data.segmentsPerSide === 'number' && data.segmentsPerSide !== segmentsPerSide) {
          segmentsPerSide = data.segmentsPerSide;
          needRebuild = true;
        }
        if (typeof data.restLengthScale === 'number' && data.restLengthScale !== restLengthScale) {
          restLengthScale = data.restLengthScale;
          needRebuild = true;
        }
        if (needRebuild) {
          gameState.updateBandStructure(segmentsPerSide, restLengthScale);
        } else {
          if (typeof data.segmentsPerSide === 'number') gameState.bands.forEach(b => b.segmentsPerSide = data.segmentsPerSide);
          if (typeof data.restLengthScale === 'number') gameState.bands.forEach(b => b.restLengthScale = data.restLengthScale);
        }

        console.log('[SERVER] Band settings updated:', {
          springConstant: data.springConstant,
          dampingCoeff: data.dampingCoeff,
          mass: data.mass,
          restitution: data.restitution,
          segmentsPerSide,
          restLengthScale,
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
              segmentsPerSide,
              restLengthScale,
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
            segmentsPerSide: Number(b.segmentsPerSide),
            restLengthScale: Number(b.restLengthScale),
          }));
        }
      } else if (data.type === 'resetBandSettings') {
        // Reset all bands to default values
        gameState.updateBandStructure(BAND_SEGMENTS_PER_SIDE, BAND_REST_LENGTH_SCALE);
        gameState.bands.forEach(b => {
          b.springConstant = BAND_SPRING_CONSTANT;
          b.dampingCoeff = BAND_DAMPING_COEFF;
          b.mass = BAND_MASS;
          b.coefficientOfRestitution = BAND_COEFFICIENT_OF_RESTITUTION;
        });
        // Broadcast new settings to all clients
        wss.clients.forEach((client) => {
          if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({
              type: 'bandSettings',
              springConstant: BAND_SPRING_CONSTANT,
              dampingCoeff: BAND_DAMPING_COEFF,
              mass: BAND_MASS,
              restitution: BAND_COEFFICIENT_OF_RESTITUTION,
              segmentsPerSide: BAND_SEGMENTS_PER_SIDE,
              restLengthScale: BAND_REST_LENGTH_SCALE,
            }));
          }
        });
      } else if (data.type === 'respawn') {
        // Respawn the player's ball at the center of the arena
        const player = gameState.getPlayerBySocket(ws);
        if (player && gameState.balls[player.playerId]) {
          gameState.balls[player.playerId].x = ARENA_SIZE / 2;
          gameState.balls[player.playerId].y = ARENA_SIZE / 2;
          gameState.balls[player.playerId].vx = 0;
          gameState.balls[player.playerId].vy = 0;
        }
      } else if (data.type === 'spawnBot') {
        // Add a bot to the game
        const botId = gameState.addBot();
        console.log(`🤖 Bot spawned with ID: ${botId}`);
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

  ws.on('close', () => {
    console.log('❎ WebSocket connection closed');
    const removed = gameState.removePlayer(ws);

    const players = gameState.getPlayers();
    console.log('🧑‍🤝‍🧑 Players remaining:', players.length, '| Usernames:', players.map(p => p.username).join(', '));

    const simplifiedPlayers = players.map(p => ({
      playerId: p.playerId,
      username: p.username,
      color: p.color,
    }));

    wss.clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        console.log('📡 Broadcasting updated player list after disconnect');
        client.send(JSON.stringify({ type: 'playerList', players: simplifiedPlayers }));
      }
    });
  });

  // Clean up interval on server close
  wss.on('close', function close() {
    clearInterval(interval);
  });
});

// Fallback to serve index.html for SPA routing
app.get('*', (req, res) => {
  console.log(`📄 Serving index.html for route: ${req.url}`);
  res.sendFile(path.join(__dirname, 'server', 'public', 'index.html'));
});