// Arena/game configuration (shared with all clients)
const ARENA_SIZE = 3000; // Logical units (e.g., pixels)

const ACCELERATION = 580; // units per second^2

const BALL_MASS = 2.5; // Initial mass
const BALL_RADIUS = 18; // Initial radius
const BALL_MASS_GROWTH_INTERVAL = 3.0; // seconds between mass increments
const BALL_MASS_INCREMENT = 0.07; // How much to increase mass each interval
const BALL_MASS_MAX_MULTIPLIER = 12; // Max mass = BALL_MASS * 6

const BAND_SEGMENTS_PER_SIDE = 20; // from reference code
const BAND_SPRING_CONSTANT = 15;
const BAND_DAMPING_COEFF = 0.04;
const BAND_MASS = 0.04;
const BAND_REST_LENGTH_SCALE = 0.02;
const BAND_COEFFICIENT_OF_RESTITUTION = 0.65;

const POST_RADIUS = 22; // for collision, slightly larger than ball

// Stamina system constants
const STAMINA_MAX = 1.0;
const STAMINA_DRAIN_PER_SEC = 0.15; // how fast stamina drains when holding (per second)
const STAMINA_RECOVER_PER_SEC = 0.29; // how fast stamina recovers when not holding (per second)
const STAMINA_MIN_TO_MOVE = 0.01; // must have at least this much stamina to move

// Burst settings
const BURST_STAMINA_COST = 0.3;
const BURST_MIN_STAMINA = 0.66;
const BURST_IMPULSE = 375; // tweak as needed

// Bot settings
const BOT_UPDATE_INTERVAL = 0.5; // seconds between bot direction changes
const BOT_MOVE_CHANCE = 0.7; // probability of bot moving in a direction
const BOT_BURST_CHANCE = 0.1; // probability of bot using burst

class GameState {
  constructor() {
    // console.log('[DEBUG] GameState constructor called');
    this.players = [];
    // Balls keyed by playerId: { [playerId]: { x, y, vx, vy } }
    this.balls = {};
    // Store input direction for each player
    this.inputDirections = {}; // { playerId: {dx, dy} }
    this.pendingImpulses = {}; // { playerId: {dx, dy} }
    this.burstRequests = {}; // { playerId: {dx, dy} }

    // --- Elastic Zone Data Structures ---
    // Four posts at the corners of a square
    const margin = 800;
    this.posts = [
      { x: margin, y: margin },
      { x: ARENA_SIZE - margin, y: margin },
      { x: ARENA_SIZE - margin, y: ARENA_SIZE - margin },
      { x: margin, y: ARENA_SIZE - margin }
    ];

    // Each band is an array of segments (particles) between posts
    this.bands = [];
    for (let i = 0; i < 4; i++) {
      const start = this.posts[i];
      const end = this.posts[(i + 1) % 4];
      const segments = [];
      const velocities = [];
      const sideLength = Math.sqrt(
        Math.pow(end.x - start.x, 2) + Math.pow(end.y - start.y, 2)
      );
      // Apply restLengthScale here
      const restLength = (sideLength / (BAND_SEGMENTS_PER_SIDE - 1)) * BAND_REST_LENGTH_SCALE;
      for (let j = 0; j < BAND_SEGMENTS_PER_SIDE; j++) {
        const t = j / (BAND_SEGMENTS_PER_SIDE - 1);
        // Initial position: evenly spaced between start and end, NO wiggle
        let x = start.x + (end.x - start.x) * t;
        let y = start.y + (end.y - start.y) * t;
        // (No wiggle offset)
        segments.push({ x, y });
        velocities.push({ x: 0, y: 0 });
      }
      this.bands.push({
        segments,
        velocities,
        springConstant: BAND_SPRING_CONSTANT,
        dampingCoeff: BAND_DAMPING_COEFF,
        mass: BAND_MASS,
        restLength,
        coefficientOfRestitution: BAND_COEFFICIENT_OF_RESTITUTION,
        fixedIndices: [0, BAND_SEGMENTS_PER_SIDE - 1],
        segmentsPerSide: BAND_SEGMENTS_PER_SIDE,
        restLengthScale: BAND_REST_LENGTH_SCALE,
      });
    }

    // After initializing balls and bands, add:
    // console.log('Initial ball positions:', Object.values(this.balls));
    // console.log('Initial band segment positions:', this.bands.map(b => b.segments.map(s => [s.x, s.y])));

    this.bots = {}; // Store bot data
    this._lastBotUpdate = 0; // Track last bot update time
    this.botCounter = 1; // Add counter for bot names
  }

  getPlayerBySocket(ws) {
    return this.players.find(p => p.ws === ws);
  }

  addPlayer(username, ws, color) {
    // Prevent duplicate usernames
    if (this.players.some(p => p.username === username)) {
      return { success: false };
    }

    const playerId = Date.now().toString();
    this.players.push({ playerId, username, ws, color });

    // Spawn a ball for this player at a random spot near the center, not overlapping others
    const radius = 18; // must match client
    const maxAttempts = 20;
    let spawnX, spawnY, attempts = 0;
    let safe = false;
    while (!safe && attempts < maxAttempts) {
      // Random offset within 120px of center
      const offset = () => (Math.random() - 0.5) * 240;
      spawnX = ARENA_SIZE / 2 + offset();
      spawnY = ARENA_SIZE / 2 + offset();
      safe = true;
      for (const ball of Object.values(this.balls)) {
        const dx = spawnX - ball.x;
        const dy = spawnY - ball.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < radius * 2 + 4) { // 4px buffer
          safe = false;
          break;
        }
      }
      attempts++;
    }
    // fallback to center if no safe spot found
    if (!safe) {
      spawnX = ARENA_SIZE / 2;
      spawnY = ARENA_SIZE / 2;
    }
    this.balls[playerId] = {
      id: playerId,
      x: spawnX,
      y: spawnY,
      vx: 0,
      vy: 0,
      color: color || '#ff2196f3',
      stamina: STAMINA_MAX,
      mass: BALL_MASS, // Add per-ball mass
    };
    // console.log('[DEBUG] Ball added:', this.balls[playerId]);

    return { success: true, playerId };
  }

  removePlayer(ws) {
    const player = this.getPlayerBySocket(ws);
    if (player) {
      delete this.balls[player.playerId];
    }
    this.players = this.players.filter(player => player.ws !== ws);

    // Check if there are any human players left (non-bot players)
    const hasHumanPlayers = this.players.some(p => !p.playerId.startsWith('Bot'));
    if (!hasHumanPlayers) {
      console.log('No human players left, removing all bots');
      // Remove all bot balls and players
      Object.keys(this.balls).forEach(id => {
        if (id.startsWith('Bot')) {
          delete this.balls[id];
        }
      });
      this.players = this.players.filter(p => !p.playerId.startsWith('Bot'));
      this.botCounter = 1;
    }
  }
  getBalls() {
    // Return balls with color property from player if not already present
    return Object.values(this.balls).filter(ball => {
      return (
        typeof ball.x === 'number' &&
        typeof ball.y === 'number' &&
        typeof ball.vx === 'number' &&
        typeof ball.vy === 'number'
      );
    }).map(ball => {
      // Attach color from player if missing
      if (!ball.color) {
        const player = this.players.find(p => p.playerId === ball.id);
        if (player && player.color) {
          return { ...ball, color: player.color };
        }
      }
      // Always include stamina in the output
      const result = { ...ball, stamina: typeof ball.stamina === 'number' ? ball.stamina : STAMINA_MAX };
      return result;
    });
  }

  getPlayers() {
    // Return player info without WebSocket object, but only for players with active balls
    return this.players
      .filter(player => this.balls[player.playerId]) // Only include players with active balls
      .map(({ playerId, username, color }) => ({ playerId, username, color }));
  }
  
  // Set the velocity of a player's ball based on input direction (dx, dy) and burst
  handleMove(playerId, dx, dy, burst = false) {
    if (dx !== 0 || dy !== 0) {
      this.pendingImpulses[playerId] = { dx, dy };
    }
    this.inputDirections[playerId] = { dx, dy };
    if (burst) {
      // Only store burst request if player has enough stamina right now
      const ball = this.balls[playerId];
      if (ball && typeof ball.stamina === 'number' && ball.stamina >= BURST_MIN_STAMINA) {
        this.burstRequests[playerId] = { dx, dy };
      }
      // else: ignore burst request if not enough stamina
    }
  }

  // --- Helper to get current radius for a ball ---
  static getBallRadius(ball) {
    return BALL_RADIUS * (ball.mass / BALL_MASS);
  }

  // Update all balls' positions based on their velocities, apply friction, and update stamina
  updateBalls(dt) {
    // dt is in "ticks" (e.g., 1 = 50ms)
    for (const ball of Object.values(this.balls)) {
      // Check for boundary collision and eliminate player if they touch the boundary
      const radius = GameState.getBallRadius(ball);
      if (ball.x - radius < 0 || ball.x + radius > ARENA_SIZE || 
          ball.y - radius < 0 || ball.y + radius > ARENA_SIZE) {
        // Player has touched the boundary, eliminate them
        console.log(`Player ${ball.id} eliminated for touching boundary`);
        delete this.balls[ball.id];
        // Remove from players list but keep their WebSocket connection
        this.players = this.players.filter(p => p.playerId !== ball.id);
        continue; // Skip the rest of the update for this ball
      }

      // --- Stamina logic ---
      let input = this.inputDirections[ball.id] || { dx: 0, dy: 0 };
      const isMoving = input.dx !== 0 || input.dy !== 0;
      // Initialize stamina if missing
      if (typeof ball.stamina !== 'number') ball.stamina = STAMINA_MAX;

      // --- Burst logic ---
      const burst = this.burstRequests[ball.id];
      if (burst && ball.stamina >= BURST_MIN_STAMINA) {
        // Apply burst impulse immediately
        const len = Math.sqrt(burst.dx * burst.dx + burst.dy * burst.dy);
        if (len > 0) {
          // Scale burst impulse with mass, using square root for more gradual scaling
          const massScale = Math.sqrt(ball.mass / BALL_MASS);
          const bx = (burst.dx / len) * BURST_IMPULSE * massScale;
          const by = (burst.dy / len) * BURST_IMPULSE * massScale;
          ball.vx += bx;
          ball.vy += by;
          // Drain burst stamina
          ball.stamina -= BURST_STAMINA_COST;
          if (ball.stamina < 0) ball.stamina = 0;
        }
        delete this.burstRequests[ball.id];
      }

      if (isMoving) {
        // Drain stamina
        ball.stamina -= STAMINA_DRAIN_PER_SEC * (dt * 0.05);
        if (ball.stamina < 0) ball.stamina = 0;
      } else {
        // Recover stamina
        ball.stamina += STAMINA_RECOVER_PER_SEC * (dt * 0.05);
        if (ball.stamina > STAMINA_MAX) ball.stamina = STAMINA_MAX;
      }

      // --- Only apply movement if stamina is available ---
      let impulse = this.pendingImpulses[ball.id];
      if (impulse) {
        // Apply the impulse once, only if stamina is available
        if (ball.stamina > STAMINA_MIN_TO_MOVE) {
          const len = Math.sqrt(impulse.dx * impulse.dx + impulse.dy * impulse.dy);
          if (len > 0) {
            // Scale acceleration with mass, but use square root to make it more gradual
            const massScale = Math.sqrt(ball.mass / BALL_MASS);
            const ax = (impulse.dx / len) * ACCELERATION * massScale;
            const ay = (impulse.dy / len) * ACCELERATION * massScale;
            ball.vx += ax * dt * 0.05;
            ball.vy += ay * dt * 0.05;
            // Drain stamina for impulse
            ball.stamina -= STAMINA_DRAIN_PER_SEC * (dt * 0.05);
            if (ball.stamina < 0) ball.stamina = 0;
          }
        }
        delete this.pendingImpulses[ball.id];
      } else if (isMoving) {
        // Only apply acceleration if stamina is available
        if (ball.stamina > STAMINA_MIN_TO_MOVE) {
          const len = Math.sqrt(input.dx * input.dx + input.dy * input.dy);
          if (len > 0) {
            // Scale acceleration with mass, but use square root to make it more gradual
            const massScale = Math.sqrt(ball.mass / BALL_MASS);
            const ax = (input.dx / len) * ACCELERATION * massScale;
            const ay = (input.dy / len) * ACCELERATION * massScale;
            ball.vx += ax * dt * 0.05;
            ball.vy += ay * dt * 0.05;
          }
        }
      }
      // No friction, no max speed
      ball.x += ball.vx * dt * 0.05;
      ball.y += ball.vy * dt * 0.05;
    }

    // --- Collision handling between balls ---
    const ballsArr = Object.values(this.balls);
    for (let i = 0; i < ballsArr.length; i++) {
      for (let j = i + 1; j < ballsArr.length; j++) {
        const a = ballsArr[i];
        const b = ballsArr[j];
        const aRadius = GameState.getBallRadius(a);
        const bRadius = GameState.getBallRadius(b);
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < aRadius + bRadius && dist > 0) {
          // Move balls apart so they just touch
          const overlap = aRadius + bRadius - dist;
          const nx = dx / dist;
          const ny = dy / dist;
          a.x -= nx * overlap * (bRadius / (aRadius + bRadius));
          a.y -= ny * overlap * (bRadius / (aRadius + bRadius));
          b.x += nx * overlap * (aRadius / (aRadius + bRadius));
          b.y += ny * overlap * (aRadius / (aRadius + bRadius));

          // Elastic collision: exchange velocity along normal (mass-aware)
          const dvx = b.vx - a.vx;
          const dvy = b.vy - a.vy;
          const vn = dvx * nx + dvy * ny;
          if (vn < 0) {
            const ma = a.mass || BALL_MASS;
            const mb = b.mass || BALL_MASS;
            const impulse = (2 * vn) / (ma + mb);
            a.vx += impulse * mb * nx;
            a.vy += impulse * mb * ny;
            b.vx -= impulse * ma * nx;
            b.vy -= impulse * ma * ny;
          }
        }
      }
    }
  }

  // Add this method to update band physics
  updateBands(dt) {
    for (const bandIdx in this.bands) {
      const band = this.bands[bandIdx];
      const { segments, velocities, springConstant, dampingCoeff, mass, restLength, fixedIndices } = band;
      const numPts = segments.length;
      
      // Compute Hooke's law forces for each segment
      const forces = Array.from({ length: numPts }, () => ({ x: 0, y: 0 }));
      for (let i = 0; i < numPts; i++) {
        if (fixedIndices.includes(i)) continue;
        // Spring to previous point
        if (i > 0) {
          const prev = segments[i - 1];
          const curr = segments[i];
          if (!isFinite(prev.x) || !isFinite(prev.y) || !isFinite(curr.x) || !isFinite(curr.y)) {
            console.error(`[DEBUG] [prev] segment NaN at band ${bandIdx} seg ${i}: prev=(${prev.x},${prev.y}), curr=(${curr.x},${curr.y})`);
            continue;
          }
          const dx = prev.x - curr.x;
          const dy = prev.y - curr.y;
          // PATCH: Clamp dx/dy to a reasonable range to avoid huge values
          const safeDx = Math.max(Math.min(dx, 1000), -1000);
          const safeDy = Math.max(Math.min(dy, 1000), -1000);
          const dist = Math.sqrt(safeDx * safeDx + safeDy * safeDy);
          if (!isFinite(dist) || dist === Infinity) {
            console.error(`[DEBUG] [prev] dist not finite at band ${bandIdx} seg ${i}: dist=${dist}`);
            continue;
          }
          if (dist > 1e-6) {
            const forceMag = springConstant * (dist - restLength);
            const normX = safeDx / dist;
            const normY = safeDy / dist;
            if (!isFinite(normX) || !isFinite(normY)) {
              console.error(`[DEBUG] [prev] normX/normY not finite at band ${bandIdx} seg ${i}: normX=${normX}, normY=${normY}`);
              continue;
            }
            forces[i].x += normX * forceMag;
            forces[i].y += normY * forceMag;
          }
        }
        // Spring to next point
        if (i < numPts - 1) {
          const next = segments[i + 1];
          const curr = segments[i];
          if (!isFinite(next.x) || !isFinite(next.y) || !isFinite(curr.x) || !isFinite(curr.y)) {
            console.error(`[DEBUG] [next] segment NaN at band ${bandIdx} seg ${i}: next=(${next.x},${next.y}), curr=(${curr.x},${curr.y})`);
            continue;
          }
          const dx = next.x - curr.x;
          const dy = next.y - curr.y;
          // PATCH: Clamp dx/dy to a reasonable range to avoid huge values
          const safeDx = Math.max(Math.min(dx, 1000), -1000);
          const safeDy = Math.max(Math.min(dy, 1000), -1000);
          const dist = Math.sqrt(safeDx * safeDx + safeDy * safeDy);
          if (!isFinite(dist) || dist === Infinity) {
            console.error(`[DEBUG] [next] dist not finite at band ${bandIdx} seg ${i}: dist=${dist}`);
            continue;
          }
          if (dist > 1e-6) {
            const forceMag = springConstant * (dist - restLength);
            const normX = safeDx / dist;
            const normY = safeDy / dist;
            if (!isFinite(normX) || !isFinite(normY)) {
              console.error(`[DEBUG] [next] normX/normY not finite at band ${bandIdx} seg ${i}: normX=${normX}, normY=${normY}`);
              continue;
            }
            forces[i].x += normX * forceMag;
            forces[i].y += normY * forceMag;
          }
        }
      }
      // Integrate motion for each segment
      for (let i = 0; i < numPts; i++) {
        if (fixedIndices.includes(i)) continue;
        // Damping force
        const dampingForceX = -dampingCoeff * velocities[i].x;
        const dampingForceY = -dampingCoeff * velocities[i].y;
        // Total force
        const fx = forces[i].x + dampingForceX;
        const fy = forces[i].y + dampingForceY;
        if (!isFinite(fx) || !isFinite(fy)) {
          console.error(`[DEBUG] fx/fy not finite at band ${bandIdx} seg ${i}: fx=${fx}, fy=${fy}`);
          continue;
        }
        if (!isFinite(mass) || mass === 0) {
          console.error(`[DEBUG] mass not finite or zero at band ${bandIdx} seg ${i}: mass=${mass}`);
          continue;
        }
        // Acceleration
        const ax = fx / mass;
        const ay = fy / mass;
        if (!isFinite(ax) || !isFinite(ay)) {
          console.error(`[DEBUG] ax/ay not finite at band ${bandIdx} seg ${i}: ax=${ax}, ay=${ay}`);
          continue;
        }
        // Update velocity
        velocities[i].x += ax * dt * 0.05;
        velocities[i].y += ay * dt * 0.05;
        if (!isFinite(velocities[i].x) || !isFinite(velocities[i].y)) {
          console.error(`[DEBUG] velocity not finite at band ${bandIdx} seg ${i}: vx=${velocities[i].x}, vy=${velocities[i].y}`);
          velocities[i].x = 0;
          velocities[i].y = 0;
        }
        // Update position
        segments[i].x += velocities[i].x * dt * 0.05;
        segments[i].y += velocities[i].y * dt * 0.05;
        if (!isFinite(segments[i].x) || !isFinite(segments[i].y)) {
          console.error(`[ERROR] Band segment ${i} became non-finite, reset to 0`);
          segments[i].x = 0;
          segments[i].y = 0;
        }
      }
    }

    // After updating band segment positions, handle ball-band and ball-post collisions
    for (const ball of Object.values(this.balls)) {
      // --- Ball-Post collisions (rigid) ---
      for (const post of this.posts) {
        const dx = ball.x - post.x;
        const dy = ball.y - post.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < GameState.getBallRadius(ball) + POST_RADIUS) {
          // Push ball out
          const overlap = GameState.getBallRadius(ball) + POST_RADIUS - dist;
          const nx = dx / (dist || 1e-8);
          const ny = dy / (dist || 1e-8);
          ball.x += nx * overlap;
          ball.y += ny * overlap;
          // Reflect velocity (elastic)
          const vDotN = ball.vx * nx + ball.vy * ny;
          if (vDotN < 0) {
            ball.vx -= 2 * vDotN * nx;
            ball.vy -= 2 * vDotN * ny;
          }
        }
      }

      // --- Ball-Band collisions (elastic) ---
      for (const band of this.bands) {
        const { segments, velocities, mass, coefficientOfRestitution, fixedIndices } = band;
        if (!segments || segments.length < 2) continue;
        for (let i = 0; i < segments.length - 1; i++) {
          if (fixedIndices.includes(i) && fixedIndices.includes(i + 1)) continue;
          const p1 = segments[i], p2 = segments[i + 1];
          if (!p1 || !p2) continue;
          const segDx = p2.x - p1.x, segDy = p2.y - p1.y;
          const segLen2 = segDx * segDx + segDy * segDy;
          if (!isFinite(segDx) || !isFinite(segDy) || segLen2 === 0) continue;
          const t = GameState._clamp(
            ((ball.x - p1.x) * segDx + (ball.y - p1.y) * segDy) / segLen2,
            0, 1
          );
          const closestX = p1.x + segDx * t;
          const closestY = p1.y + segDy * t;
          const dist = GameState._dist(ball.x, ball.y, closestX, closestY);

          // if (i === 0 && ball.id) {
          //   console.log(`[DEBUG] Ball ${ball.id} at (${ball.x.toFixed(1)},${ball.y.toFixed(1)}) vs band seg 0 (${p1.x.toFixed(1)},${p1.y.toFixed(1)}) dist=${dist.toFixed(2)} (BALL_RADIUS+6=${BALL_RADIUS+6})`);
          // }
          // if (dist < 100) {
          //   // console.log(`[DEBUG] Ball ${ball.id} near band seg ${i}: dist=${dist.toFixed(2)}`);
          // }
          if (dist < GameState.getBallRadius(ball) + 10) {
            console.log(`[COLLISION] Ball-band collision: ball at (${ball.x},${ball.y}), band seg ${i} at (${p1.x},${p1.y}), dist=${dist}`);
            const nx = (ball.x - closestX) / (dist || 1e-8);
            const ny = (ball.y - closestY) / (dist || 1e-8);
            const overlap = GameState.getBallRadius(ball) + 10 - dist;
            ball.x += nx * overlap * 0.7;
            ball.y += ny * overlap * 0.7;
            if (!fixedIndices.includes(i)) {
              segments[i].x -= nx * overlap * 0.15;
              segments[i].y -= ny * overlap * 0.15;
            }
            if (!fixedIndices.includes(i + 1)) {
              segments[i + 1].x -= nx * overlap * 0.15;
              segments[i + 1].y -= ny * overlap * 0.15;
            }
            const bandVx = (velocities[i].x + velocities[i + 1].x) / 2;
            const bandVy = (velocities[i].y + velocities[i + 1].y) / 2;
            const relVx = ball.vx - bandVx;
            const relVy = ball.vy - bandVy;
            const vDotN = relVx * nx + relVy * ny;
            if (vDotN < 0) {
              const impulse = -(1 + coefficientOfRestitution) * vDotN / (1 / 1 + 1 / (2 * mass));
              ball.vx += (impulse / 1) * nx;
              ball.vy += (impulse / 1) * ny;
              if (!fixedIndices.includes(i)) {
                velocities[i].x -= (impulse / (2 * mass)) * nx;
                velocities[i].y -= (impulse / (2 * mass)) * ny;
              }
              if (!fixedIndices.includes(i + 1)) {
                velocities[i + 1].x -= (impulse / (2 * mass)) * nx;
                velocities[i + 1].y -= (impulse / (2 * mass)) * ny;
              }
            }
          }
        }
      }
    }

    // Print all ball positions and first segment of each band every tick
    // for (const ball of Object.values(this.balls)) {
    //   console.log(`[TICK] Ball ${ball.id} at (${ball.x.toFixed(1)},${ball.y.toFixed(1)})`);
    // }
    // for (let b = 0; b < this.bands.length; b++) {
    //   const seg = this.bands[b].segments[0];
    //   console.log(`[TICK] Band ${b} seg0 at (${seg.x.toFixed(1)},${seg.y.toFixed(1)})`);
    // }
  }

  update(dt) {
    // dt is in ticks (1 tick = 50ms), so dt*0.05 = seconds
    const seconds = dt * 0.05;
    this._elapsedMassGrowth = (this._elapsedMassGrowth || 0) + seconds;
    if (this._elapsedMassGrowth >= BALL_MASS_GROWTH_INTERVAL) {
      // Increment mass for all balls
      for (const ball of Object.values(this.balls)) {
        const maxMass = BALL_MASS * BALL_MASS_MAX_MULTIPLIER;
        if (ball.mass < maxMass) {
          ball.mass = Math.min(ball.mass + BALL_MASS_INCREMENT, maxMass);
        }
      }
      this._elapsedMassGrowth = 0;
    }
    this.updateBalls(dt);
    this.updateBands(dt);
  }

  updateBandStructure(segmentsPerSide, restLengthScale) {
    const margin = 800;
    this.posts = [
      { x: margin, y: margin },
      { x: ARENA_SIZE - margin, y: margin },
      { x: ARENA_SIZE - margin, y: ARENA_SIZE - margin },
      { x: margin, y: ARENA_SIZE - margin }
    ];
    this.bands = [];
    for (let i = 0; i < 4; i++) {
      const start = this.posts[i];
      const end = this.posts[(i + 1) % 4];
      const segments = [];
      const velocities = [];
      const sideLength = Math.sqrt(
        Math.pow(end.x - start.x, 2) + Math.pow(end.y - start.y, 2)
      );
      const restLength = (sideLength / (segmentsPerSide - 1)) * restLengthScale;
      for (let j = 0; j < segmentsPerSide; j++) {
        const t = j / (segmentsPerSide - 1);
        let x = start.x + (end.x - start.x) * t;
        let y = start.y + (end.y - start.y) * t;
        segments.push({ x, y });
        velocities.push({ x: 0, y: 0 });
      }
      this.bands.push({
        segments,
        velocities,
        springConstant: BAND_SPRING_CONSTANT,
        dampingCoeff: BAND_DAMPING_COEFF,
        mass: BAND_MASS,
        restLength,
        coefficientOfRestitution: BAND_COEFFICIENT_OF_RESTITUTION,
        fixedIndices: [0, segmentsPerSide - 1],
        segmentsPerSide,
        restLengthScale,
      });
    }
  }

  // Helper: distance between two points
  static _dist(x1, y1, x2, y2) {
    const dx = x2 - x1, dy = y2 - y1;
    return Math.sqrt(dx * dx + dy * dy);
  }

  // Helper: clamp value
  static _clamp(val, min, max) {
    return Math.max(min, Math.min(max, val));
  }

  // Helper to get a random color
  static getRandomColor() {
    const colors = [
      '#ff0000', // red
      '#ff4081', // pink
      '#9c27b0', // purple
      '#673ab7', // deep purple
      '#3f51b5', // indigo
      '#2196f3', // blue
      '#03a9f4', // light blue
      '#00bcd4', // cyan
      '#009688', // teal
      '#4caf50', // green
      '#8bc34a', // light green
      '#cddc39', // lime
      '#ffeb3b', // yellow
      '#ffc107', // amber
      '#ff9800', // orange
      '#ff5722', // deep orange
      '#795548', // brown
    ];
    return colors[Math.floor(Math.random() * colors.length)];
  }

  // Add a bot to the game
  addBot() {
    const botId = 'Bot' + this.botCounter++;
    const color = GameState.getRandomColor();
    
    // Spawn bot at a random spot near the center, not overlapping others
    const radius = 18;
    const maxAttempts = 20;
    let spawnX, spawnY, attempts = 0;
    let safe = false;
    while (!safe && attempts < maxAttempts) {
      const offset = () => (Math.random() - 0.5) * 240;
      spawnX = ARENA_SIZE / 2 + offset();
      spawnY = ARENA_SIZE / 2 + offset();
      safe = true;
      for (const ball of Object.values(this.balls)) {
        const dx = spawnX - ball.x;
        const dy = spawnY - ball.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < radius * 2 + 4) {
          safe = false;
          break;
        }
      }
      attempts++;
    }
    if (!safe) {
      spawnX = ARENA_SIZE / 2;
      spawnY = ARENA_SIZE / 2;
    }

    // Add bot to players list
    this.players.push({ playerId: botId, username: botId, color: color });

    this.balls[botId] = {
      id: botId,
      x: spawnX,
      y: spawnY,
      vx: 0,
      vy: 0,
      color: color,
      stamina: STAMINA_MAX,
      mass: BALL_MASS,
      isBot: true
    };

    return botId;
  }
}

// Helper function for safe normalization
function safeNormalize(dx, dy) {
  const len = Math.sqrt(dx * dx + dy * dy);
  if (!isFinite(len) || len < 1e-6) return { x: 0, y: 0 };
  return { x: dx / len, y: dy / len };
}

module.exports = {
  GameState,
  ARENA_SIZE,
  BAND_SPRING_CONSTANT,
  BAND_DAMPING_COEFF,
  BAND_MASS,
  BAND_COEFFICIENT_OF_RESTITUTION,
  BAND_SEGMENTS_PER_SIDE,
  BAND_REST_LENGTH_SCALE
};

