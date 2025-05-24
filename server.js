const express = require('express');
const WebSocket = require('ws');
const path = require('path');
const { GameState } = require('./server/game/state');

const app = express();
console.log('🧠 Running on process ID:', process.pid);
const server = app.listen(3000, () => console.log('🚀 Server running on port 3000'));
const wss = new WebSocket.Server({ server });
const gameState = new GameState();

// Serve static files from bump_zone/server/public/
app.use(express.static(path.join(__dirname, 'server', 'public')));

// WebSocket connection handling
wss.on('connection', (ws) => {
  console.log('🔗 New WebSocket connection established');

  ws.on('message', (message) => {
    console.log('📩 Received message:', message);

    let data;
    try {
      data = JSON.parse(message);
    } catch (err) {
      console.error('❌ Failed to parse message JSON:', err);
      ws.send(JSON.stringify({ type: 'error', message: 'invalid_json' }));
      return;
    }

    if (data.type === 'join') {
      console.log(`👤 Attempting to add player: ${data.username}`);
      const result = gameState.addPlayer(data.username, ws);
      if (result.success) {
        console.log(`✅ Player added: ${data.username} (ID: ${result.playerId})`);
        const players = gameState.getPlayers();
        console.log('🧑‍🤝‍🧑 Current players:', players);

        ws.send(JSON.stringify({ type: 'welcome', playerId: result.playerId.toString(), players }));

        wss.clients.forEach((client) => {
          if (client.readyState === WebSocket.OPEN) {
            console.log('📡 Broadcasting player list to client');
            client.send(JSON.stringify({ type: 'playerList', players }));
          }
        });
      } else {
        console.warn(`⚠️ Username taken: ${data.username}`);
        ws.send(JSON.stringify({ type: 'error', message: 'username_taken' }));
      }
    }
  });

  ws.on('close', () => {
    console.log('❎ WebSocket connection closed');
    gameState.removePlayer(ws);

    const players = gameState.getPlayers();
    console.log('🧑‍🤝‍🧑 Updated players after disconnect:', players);

    wss.clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        console.log('📡 Broadcasting updated player list after disconnect');
        client.send(JSON.stringify({ type: 'playerList', players }));
      }
    });
  });
});

// Fallback to serve index.html for SPA routing
app.get('*', (req, res) => {
  console.log(`📄 Serving index.html for route: ${req.url}`);
  res.sendFile(path.join(__dirname, 'server', 'public', 'index.html'));
});
