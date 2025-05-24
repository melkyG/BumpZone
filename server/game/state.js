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

  updatePlayerMovement(playerId, posx, posy, dx, dy) {
    const player = this.players.get(playerId);
    if (player) {
      player.velocity.x = dx;
      player.velocity.y = dy;
      player.position.x = posx; 
      player.position.y = posy;
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
