class GameState {
  constructor() {
    this.players = []; // List of all player data
    this.socketMap = new Map(); // Map WebSocket -> player
  }

  addPlayer(username, socket) {
    const playerId = Date.now(); // Or use a UUID if preferred
    const player = {
      playerId,
      username,
      socket,
    };

    this.players.push(player);
    this.socketMap.set(socket, player);
    return player;
  }

  removePlayer(socket) {
    const player = this.socketMap.get(socket);
    if (player) {
      this.players = this.players.filter(p => p !== player);
      this.socketMap.delete(socket);
    }
  }

  getAllPlayers() {
    // Return just public info (no socket)
    return this.players.map(({ playerId, username }) => ({
      playerId,
      username,
    }));
  }

  getPlayerBySocket(socket) {
    return this.socketMap.get(socket); // Reliable lookup
  }

  getPlayerById(id) {
    return this.players.find(p => p.playerId === id);
  }
}

module.exports = { GameState };
