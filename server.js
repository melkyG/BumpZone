const express = require('express');
const WebSocket = require('ws');
const path = require('path');
const { GameState } = require('./server/game/state');

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
  console.log('🔗 New WebSocket connection established');

  ws.on('message', (message) => {
    try {
      // Convert Buffer to string if necessary
      const jsonString = typeof message === 'string' ? message : message.toString('utf8');
      console.log('📩 Received message:', jsonString);      const data = JSON.parse(jsonString);
      
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
      }
    } catch (err) {
      console.error('❌ Failed to parse message:', err);
      ws.send(JSON.stringify({ type: 'error', message: 'invalid_json' }));
    }
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
