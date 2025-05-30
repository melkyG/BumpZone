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

    // Spawn a ball for this player in the center of the arena
    this.balls[playerId] = {
      id: playerId,
      x: ARENA_SIZE / 2,
      y: ARENA_SIZE / 2,
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
    // Return an array of all balls
    return Object.values(this.balls);
  }

  getPlayers() {
    // Return player info without WebSocket object
    return this.players.map(({ playerId, username }) => ({ playerId, username }));
  }
}

module.exports = { GameState, ARENA_SIZE };
