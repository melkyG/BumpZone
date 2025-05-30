// Arena/game configuration (shared with all clients)
const ARENA_SIZE = 1000; // Logical units (e.g., pixels)


class GameState {
  constructor() {
    this.players = [];
    // Balls keyed by playerId: { [playerId]: { x, y, vx, vy } }
    this.balls = {};
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
    const ball = this.balls[playerId];
    if (!ball) return;
    // Scale for reasonable speed (tweak as needed)
    const SPEED = 6.0;
    ball.vx = dx * SPEED;
    ball.vy = dy * SPEED;
  }

  // Update all balls' positions based on their velocities, apply friction
  updateBalls(dt) {
    const FRICTION = 0.96; // 1 = no friction, <1 = slows down
    for (const ball of Object.values(this.balls)) {
      ball.x += ball.vx * dt;
      ball.y += ball.vy * dt;
      // Apply friction
      ball.vx *= FRICTION;
      ball.vy *= FRICTION;
      // Clamp to arena bounds
      const r = 18;
      ball.x = Math.max(r, Math.min(ARENA_SIZE - r, ball.x));
      ball.y = Math.max(r, Math.min(ARENA_SIZE - r, ball.y));
    }
  }
}

module.exports = { GameState, ARENA_SIZE };
