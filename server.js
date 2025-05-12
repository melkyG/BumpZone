const express = require('express');
const WebSocket = require('ws');
const path = require('path');
const { GameState } = require('./game/state');

const app = express();
const port = process.env.PORT || 3000;

app.use(express.static(path.join(__dirname, 'public')));

const server = app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});

const wss = new WebSocket.Server({ server });
const gameState = new GameState();

wss.on('connection', (ws) => {
  console.log('Client connected');

  const playerId = Math.random().toString(36).substring(2, 10);
  ws.playerId = playerId;

  ws.send(JSON.stringify({
    type: 'playerList',
    players: gameState.getPlayers(),
  }));

  ws.on('message', (message) => {
    const data = JSON.parse(message.toString());
    switch (data.type) {
      case 'join':
        const isUsernameTaken = gameState.getPlayers().some(
          (p) => p.username.toLowerCase() === data.username.toLowerCase()
        );
        if (isUsernameTaken) {
          ws.send(JSON.stringify({
            type: 'error',
            reason: 'username_taken',
          }));
          return;
        }
        gameState.addPlayer(playerId, data.username);
        ws.send(JSON.stringify({
          type: 'welcome',
          playerId,
          players: gameState.getPlayers(),
        }));
        broadcastPlayerList();
        break;
      case 'move':
        gameState.updatePlayerMovement(playerId, data.direction.dx, data.direction.dy);
        break;
      case 'leave':
        gameState.removePlayer(playerId);
        broadcastPlayerList();
        break;
    }
  });

  ws.on('close', () => {
    gameState.removePlayer(playerId);
    broadcastPlayerList();
    console.log('Client disconnected');
  });
});

setInterval(() => {
  const state = {
    type: 'state',
    players: gameState.getPlayers(),
  };
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(state));
    }
  });

  gameState.checkEliminations((playerId) => {
    wss.clients.forEach((client) => {
      if (client.playerId === playerId && client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify({ type: 'eliminated', playerId }));
      }
    });
  });
}, 1000 / 30);

function broadcastPlayerList() {
  const playerList = {
    type: 'playerList',
    players: gameState.getPlayers(),
  };
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(playerList));
    }
  });
}