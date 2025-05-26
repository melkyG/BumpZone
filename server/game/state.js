class GameState {
  constructor() {
    this.players = [];
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

    return { success: true, playerId };
  }

  removePlayer(ws) {
    this.players = this.players.filter(player => player.ws !== ws);
  }

  getPlayers() {
    // Return player info without WebSocket object
    return this.players.map(({ playerId, username }) => ({ playerId, username }));
  }
}

module.exports = { GameState };
