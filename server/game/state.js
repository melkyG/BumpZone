// Arena/game configuration (shared with all clients)
const ARENA_SIZE = 1000; // Logical units (e.g., pixels)

const ACCELERATION = 600; // units per second^2

class GameState {
  constructor() {
    this.players = [];
    // Balls keyed by playerId: { [playerId]: { x, y, vx, vy } }
    this.balls = {};
    // Store input direction for each player
    this.inputDirections = {}; // { playerId: {dx, dy} }
  }

  getPlayerBySocket(ws) {
    return this.players.find(p => p.ws === ws);
  }

  addPlayer(username, ws) {
    // Prevent duplicate usernames
    if (this.players.some(p => p.username === username)) {
      return { success: false };
    }

    const playerId = Date.now().toString();
    this.players.push({ playerId, username, ws });

    // Spawn a ball for this player at a random spot near the center, not overlapping others
    const radius = 18; // must match client
    const maxAttempts = 20;
    let spawnX, spawnY, attempts = 0;
    let safe = false;
    while (!safe && attempts < maxAttempts) {
      // Random offset within 120px of center
      const offset = () => (Math.random() - 0.5) * 240;
      spawnX = ARENA_SIZE / 2 + offset();
      spawnY = ARENA_SIZE / 2 + offset();
      safe = true;
      for (const ball of Object.values(this.balls)) {
        const dx = spawnX - ball.x;
        const dy = spawnY - ball.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < radius * 2 + 4) { // 4px buffer
          safe = false;
          break;
        }
      }
      attempts++;
    }
    // fallback to center if no safe spot found
    if (!safe) {
      spawnX = ARENA_SIZE / 2;
      spawnY = ARENA_SIZE / 2;
    }
    this.balls[playerId] = {
      id: playerId,
      x: spawnX,
      y: spawnY,
      vx: 0,
      vy: 0
    };

    return { success: true, playerId };
  }

  removePlayer(ws) {
    const player = this.getPlayerBySocket(ws);
    if (player) {
      delete this.balls[player.playerId];
    }
    this.players = this.players.filter(player => player.ws !== ws);
  }
  getBalls() {
    // Return an array of all balls with valid numeric properties only
    return Object.values(this.balls).filter(ball => {
      return (
        typeof ball.x === 'number' &&
        typeof ball.y === 'number' &&
        typeof ball.vx === 'number' &&
        typeof ball.vy === 'number'
      );
    });
  }

  getPlayers() {
    // Return player info without WebSocket object
    return this.players.map(({ playerId, username }) => ({ playerId, username }));
  }
  
  // Set the velocity of a player's ball based on input direction (dx, dy)
  handleMove(playerId, dx, dy) {
    // Save the latest input direction for this player
    this.inputDirections[playerId] = { dx, dy };
  }

  // Update all balls' positions based on their velocities, apply friction
  updateBalls(dt) {
    // dt is in "ticks" (e.g., 1 = 50ms)
    for (const ball of this.balls) {
      const input = this.inputDirections[ball.id] || { dx: 0, dy: 0 };
      // Apply acceleration if input is held or was just clicked
      if (input.dx !== 0 || input.dy !== 0) {
        const len = Math.sqrt(input.dx * input.dx + input.dy * input.dy);
        if (len > 0) {
          const ax = (input.dx / len) * ACCELERATION;
          const ay = (input.dy / len) * ACCELERATION;
          ball.vx += ax * dt * 0.05; // 0.05 = 50ms in seconds
          ball.vy += ay * dt * 0.05;
        }
      }
      // No friction, no max speed
      ball.x += ball.vx * dt * 0.05;
      ball.y += ball.vy * dt * 0.05;
      // Optionally: handle arena boundaries here
    }
  }
}

module.exports = { GameState, ARENA_SIZE };
