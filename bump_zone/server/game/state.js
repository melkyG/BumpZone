class GameState {
  constructor() {
    this.players = new Map();
  }

  addPlayer(id, username) {
    this.players.set(id, {
      id,
      username,
      position: { x: 200, y: 200 }, // Center of arena
      velocity: { x: 0, y: 0 },
    });
  }

  removePlayer(id) {
    this.players.delete(id);
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