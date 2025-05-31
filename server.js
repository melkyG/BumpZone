// Game loop: update balls and broadcast state at fixed interval
const TICK_RATE = 20; // 20 times per second
const TICK_INTERVAL = 1000 / TICK_RATE;
let lastTick = Date.now();
function gameLoop() {
  const now = Date.now();
  const dt = (now - lastTick) / 50; // dt in "ticks" (50ms base)
  lastTick = now;
  gameState.updateBalls(dt);
  const balls = gameState.getBalls();
  const msg = JSON.stringify({ type: 'balls', balls });
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(msg);
    }
  });
}
setInterval(gameLoop, TICK_INTERVAL);
const express = require('express');
const WebSocket = require('ws');
const path = require('path');
const { GameState, ARENA_SIZE } = require('./server/game/state');

const app = express();
console.log('🧠 Running on process ID:', process.pid);
const PORT = process.env.PORT || 3002;
const server = app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));
const wss = new WebSocket.Server({ server });
const gameState = new GameState();

// Serve static files from bump_zone/server/public/
app.use(express.static(path.join(__dirname, 'server', 'public')));

// WebSocket connection handling
wss.on('connection', (ws) => {
  // Send arena size to the client on connect
  ws.send(JSON.stringify({ type: 'arenaInfo', size: ARENA_SIZE }));
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
