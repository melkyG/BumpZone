const express = require('express');
const WebSocket = require('ws');
const path = require('path');
const { GameState } = require('./server/game/state');

const app = express();
console.log('🧠 Running on process ID:', process.pid);
const server = app.listen(3000, () => console.log('Server running on port 3000'));
const wss = new WebSocket.Server({ server });
const gameState = new GameState();

// Serve static files from bump_zone/server/public/
app.use(express.static(path.join(__dirname, 'server', 'public')));

// WebSocket connection handling
wss.on('connection', (ws) => {
  ws.on('message', (message) => {
    const data = JSON.parse(message);
    if (data.type === 'join') {
      const result = gameState.addPlayer(data.username, ws);
      if (result.success) {
        ws.send(JSON.stringify({ type: 'welcome', playerId: result.playerId.toString(), players: gameState.getPlayers() }));
        wss.clients.forEach((client) => {
          if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({ type: 'playerList', players: gameState.getPlayers() }));
          }
        });
      } else {
        ws.send(JSON.stringify({ type: 'error', message: 'username_taken' }));
      }
    }
  });

  ws.on('close', () => {
    gameState.removePlayer(ws);
    wss.clients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify({ type: 'playerList', players: gameState.getPlayers() }));
      }
    });
  });
});

// Fallback to serve index.html for SPA routing
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'server', 'public', 'index.html'));
});