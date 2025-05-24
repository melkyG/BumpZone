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

  updatePlayerMovement(username, posx, posy, dx, dy) {
    console.log(`📡 Updating movement for username: ${username}, pos: (${posx}, ${posy}), velocity: (${dx}, ${dy})`);
    let playerFound = false;
    for (const player of this.players.values()) {
      if (player.username === username) {
        console.log(`✅ Found player: ${username} (ID: ${player.id})`);
        player.velocity.x = dx;
        player.velocity.y = dy;
        player.position.x = posx;
        player.position.y = posy;
        playerFound = true;
        console.log(`Updated player: ${username}, new state: `, {
          position: { x: player.position.x, y: player.position.y },
          velocity: { x: player.velocity.x, y: player.velocity.y }
        });
        break;
      }
    }
    if (!playerFound) {
      console.warn(`⚠️ Player not found for username: ${username}`);
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
