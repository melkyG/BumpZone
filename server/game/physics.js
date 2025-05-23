const { GameState } = require('./state');

class Physics {
  constructor(gameState) {
    this.gameState = gameState;
  }

  handleBandCollision(playerId, bandId, velocity) {
    const player = this.gameState.players.get(playerId);
    const band = this.gameState.bands.find((b) => b.id === bandId);
    if (!player || !band) return;

    // Simple spring physics: stretch based on velocity
    const force = Math.sqrt(velocity.vx ** 2 + velocity.vy ** 2);
    const stretch = force / band.springConstant;
    this.gameState.updateBandStretch(bandId, stretch);

    // Trampoline effect: reverse and amplify velocity
    player.velocity.x = -velocity.vx * 1.5;
    player.velocity.y = -velocity.vy * 1.5;
  }
}

module.exports = {
  handlePhysics: new Physics(new GameState()),
};