class GameState {
  constructor() {
    this.players = new Map(); // ✅ Store players by ID
  }

  addPlayer(username, ws) {
    // Check if username exists
    for (const player of this.players.values()) {
      if (player.username === username) return { success: false };
    }

    const playerId = Date.now().toString();
    this.players.set(playerId, {
      id: playerId,
      username,
      ws,
      position: { x: 300, y: 300 },
      velocity: { x: 0, y: 0 },
      mass: 1,
      radius: 10,
    });

    return { success: true, playerId };
  }

  removePlayer(ws) {
    for (const [id, player] of this.players.entries()) {
      if (player.ws === ws) {
        this.players.delete(id);
        break;
      }
    }
  }

  getPlayers() {
    return Array.from(this.players.values());
  }

  updatePlayerMovement(id, dx, dy) {
    const player = this.players.get(id);
    if (player) {
      player.velocity.x = dx * 100;
      player.velocity.y = dy * 100;
      player.position.x += player.velocity.x / 30;
      player.position.y += player.velocity.y / 30;
    }
  }

  checkEliminations(callback) {
    const arenaRadius = 400;
    for (const [id, player] of this.players.entries()) {
      const distance = Math.sqrt(player.position.x ** 2 + player.position.y ** 2);
      if (distance > arenaRadius) {
        this.players.delete(id);
        callback(id);
      }
    }
  }
}

module.exports = { GameState };
