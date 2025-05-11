//javascript
const express = require('express');
const WebSocket = require('ws');
const path = require('path');

const app = express();
const port = process.env.PORT || 3000;

// Serve static files (Flutter web build) from public/
app.use(express.static(path.join(__dirname, 'public')));

// Start WebSocket server
const server = app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});

const wss = new WebSocket.Server({ server });

// Handle WebSocket connections
wss.on('connection', (ws) => {
  console.log('Client connected');
  ws.on('message', (message) => {
    console.log('Received:', message);
  });
  ws.on('close', () => {
    console.log('Client disconnected');
  });
});
