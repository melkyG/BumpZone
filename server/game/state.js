class GameState {
  constructor() {
    //this.players = new Map();
    this.players = [];
  }

  addPlayer(username, ws) {
  if (this.players.some(p => p.username === username)) {
    return { success: false };
  }

  const playerId = Date.now().toString(); 
  this.players.push({ playerId, username, ws });

  return { success: true, playerId };
}

  removePlayer(id) {
  // Safely reassigns players without the one matching the given id
  this.players = this.players.filter(player => player.id !== id);
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

  getPlayers() {
    return Array.from(this.players.values());
  }

  checkEliminations(callback) {
    const arenaRadius = 400;
    this.players.forEach((player, id) => {
      const distance = Math.sqrt(player.position.x ** 2 + player.position.y ** 2);
      if (distance > arenaRadius) {
        this.players.delete(id);
        callback(id);
      }
    });
  }
}

module.exports = { GameState };
