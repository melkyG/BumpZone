class GameState {
  constructor() {
    this.players = [];
  }
  getPlayerBySocket(ws) {
    return this.players.find(p => p.socket === ws);
  }

  addPlayer(username, ws) {
    // Prevent duplicate usernames
    if (this.players.some(p => p.username === username)) {
      return { success: false };
    }

    const playerId = Date.now().toString();
    this.players.push({ playerId, username, ws });

    return { success: true, playerId };
  }

  removePlayer(id) {
    this.players = this.players.filter(player => player.playerId !== id);
  }

  getPlayers() {
    // Return player info without WebSocket object
    return this.players.map(({ playerId, username }) => ({ playerId, username }));
  }
}

module.exports = { GameState };
