// Arena/game configuration (shared with all clients)
const ARENA_SIZE = 1000; // Logical units (e.g., pixels)

const ACCELERATION = 600; // units per second^2

const BALL_RADIUS = 18; // must match client

const BAND_SEGMENTS_PER_SIDE = 35; // from reference code
const BAND_SPRING_CONSTANT = 350.0;
const BAND_DAMPING_COEFF = 0.08;
const BAND_MASS = 0.04;
const BAND_REST_LENGTH_SCALE = 0.35;
const BAND_COEFFICIENT_OF_RESTITUTION = 0.85;

const POST_RADIUS = 22; // for collision, slightly larger than ball

class GameState {
  constructor() {
    console.log('[DEBUG] GameState constructor called');
    this.players = [];
    // Balls keyed by playerId: { [playerId]: { x, y, vx, vy } }
    this.balls = {};
    // Store input direction for each player
    this.inputDirections = {}; // { playerId: {dx, dy} }
    this.pendingImpulses = {}; // { playerId: {dx, dy} }

    // --- Elastic Zone Data Structures ---
    // Four posts at the corners of a square
    const margin = 150;
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
      const restLength = (sideLength / (BAND_SEGMENTS_PER_SIDE - 1)) * BAND_REST_LENGTH_SCALE;
      for (let j = 0; j < BAND_SEGMENTS_PER_SIDE; j++) {
        const t = j / (BAND_SEGMENTS_PER_SIDE - 1);
        // Initial position with slight offset for "wiggle"
        let x = start.x + (end.x - start.x) * t;
        let y = start.y + (end.y - start.y) * t;
        if (j > 0 && j < BAND_SEGMENTS_PER_SIDE - 1) {
          // Offset for visual effect (optional)
          x += 15.0 * Math.sin(j * Math.PI / (BAND_SEGMENTS_PER_SIDE - 1));
          y += 15.0 * Math.cos(j * Math.PI / (BAND_SEGMENTS_PER_SIDE - 1));
        }
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
        fixedIndices: [0, BAND_SEGMENTS_PER_SIDE - 1], // ends fixed to posts
      });
    }

    // After initializing balls and bands, add:
    console.log('Initial ball positions:', Object.values(this.balls));
    console.log('Initial band segment positions:', this.bands.map(b => b.segments.map(s => [s.x, s.y])));
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
      vy: 0
    };
    console.log('[DEBUG] Ball added:', this.balls[playerId]);

    return { success: true, playerId };
  }

  removePlayer(ws) {
    console.log('[DEBUG] removePlayer called for ws:', ws && ws.readyState);
    const player = this.getPlayerBySocket(ws);
    if (player) {
      delete this.balls[player.playerId];
    }
    this.players = this.players.filter(player => player.ws !== ws);
  }
  getBalls() {
    const balls = Object.values(this.balls).filter(ball => {
      return (
        typeof ball.x === 'number' &&
        typeof ball.y === 'number' &&
        typeof ball.vx === 'number' &&
        typeof ball.vy === 'number'
      );
    });
    console.log('[DEBUG] getBalls:', balls);
    return balls;
  }

  getPlayers() {
    // Return player info without WebSocket object
    return this.players.map(({ playerId, username }) => ({ playerId, username }));
  }
  
  // Set the velocity of a player's ball based on input direction (dx, dy)
  handleMove(playerId, dx, dy) {
    // If this is a nonzero input, store as a pending impulse
    if (dx !== 0 || dy !== 0) {
      this.pendingImpulses[playerId] = { dx, dy };
    }
    // Always store the latest input direction
    this.inputDirections[playerId] = { dx, dy };
  }

  // Update all balls' positions based on their velocities, apply friction
  updateBalls(dt) {
    // dt is in "ticks" (e.g., 1 = 50ms)
    for (const ball of Object.values(this.balls)) {
      // Check for a pending impulse (from a quick tap/click)
      let input = this.inputDirections[ball.id] || { dx: 0, dy: 0 };
      let impulse = this.pendingImpulses[ball.id];
      if (impulse) {
        // Apply the impulse once
        const len = Math.sqrt(impulse.dx * impulse.dx + impulse.dy * impulse.dy);
        if (len > 0) {
          const ax = (impulse.dx / len) * ACCELERATION;
          const ay = (impulse.dy / len) * ACCELERATION;
          ball.vx += ax * dt * 0.05;
          ball.vy += ay * dt * 0.05;
        }
        delete this.pendingImpulses[ball.id];
      } else if (input.dx !== 0 || input.dy !== 0) {
        // Apply acceleration if input is held
        const len = Math.sqrt(input.dx * input.dx + input.dy * input.dy);
        if (len > 0) {
          const ax = (input.dx / len) * ACCELERATION;
          const ay = (input.dy / len) * ACCELERATION;
          ball.vx += ax * dt * 0.05;
          ball.vy += ay * dt * 0.05;
        }
      }
      // No friction, no max speed
      ball.x += ball.vx * dt * 0.05;
      ball.y += ball.vy * dt * 0.05;
      // Optionally: handle arena boundaries here
    }

    // --- Collision handling between balls ---
    const ballsArr = Object.values(this.balls);
    for (let i = 0; i < ballsArr.length; i++) {
      for (let j = i + 1; j < ballsArr.length; j++) {
        const a = ballsArr[i];
        const b = ballsArr[j];
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < BALL_RADIUS * 2 && dist > 0) {
          // Move balls apart so they just touch
          const overlap = BALL_RADIUS * 2 - dist;
          const nx = dx / dist;
          const ny = dy / dist;
          a.x -= nx * overlap / 2;
          a.y -= ny * overlap / 2;
          b.x += nx * overlap / 2;
          b.y += ny * overlap / 2;

          // Elastic collision: exchange velocity along normal
          const dvx = b.vx - a.vx;
          const dvy = b.vy - a.vy;
          const vn = dvx * nx + dvy * ny;
          if (vn < 0) { // Only if moving towards each other
            const impulse = vn;
            a.vx += nx * impulse;
            a.vy += ny * impulse;
            b.vx -= nx * impulse;
            b.vy -= ny * impulse;
          }
        }
      }
    }
  }

  // Add this method to update band physics
  updateBands(dt) {
    console.log('[DEBUG] updateBands called, balls:', Object.keys(this.balls));
    for (const band of this.bands) {
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
          const dx = prev.x - curr.x;
          const dy = prev.y - curr.y;
          const dist = Math.sqrt(dx * dx + dy * dy);
          if (dist !== 0) {
            const forceMag = springConstant * (dist - restLength);
            forces[i].x += (dx / dist) * forceMag;
            forces[i].y += (dy / dist) * forceMag;
          }
        }
        // Spring to next point
        if (i < numPts - 1) {
          const next = segments[i + 1];
          const curr = segments[i];
          const dx = next.x - curr.x;
          const dy = next.y - curr.y;
          const dist = Math.sqrt(dx * dx + dy * dy);
          if (dist !== 0) {
            const forceMag = springConstant * (dist - restLength);
            forces[i].x += (dx / dist) * forceMag;
            forces[i].y += (dy / dist) * forceMag;
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
        // Acceleration
        const ax = fx / mass;
        const ay = fy / mass;
        // Update velocity
        velocities[i].x += ax * dt * 0.05;
        velocities[i].y += ay * dt * 0.05;
        // Update position
        segments[i].x += velocities[i].x * dt * 0.05;
        segments[i].y += velocities[i].y * dt * 0.05;
      }
    }

    // After updating band segment positions, handle ball-band and ball-post collisions
    for (const ball of Object.values(this.balls)) {
      // --- Ball-Post collisions (rigid) ---
      for (const post of this.posts) {
        const dx = ball.x - post.x;
        const dy = ball.y - post.y;
        const dist = Math.sqrt(dx * dx + dy * dy);
        if (dist < BALL_RADIUS + POST_RADIUS) {
          // Push ball out
          const overlap = BALL_RADIUS + POST_RADIUS - dist;
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

          if (i === 0 && ball.id) {
            console.log(`[DEBUG] Ball ${ball.id} at (${ball.x.toFixed(1)},${ball.y.toFixed(1)}) vs band seg 0 (${p1.x.toFixed(1)},${p1.y.toFixed(1)}) dist=${dist.toFixed(2)} (BALL_RADIUS+6=${BALL_RADIUS+6})`);
          }
          if (dist < 100) {
            // Uncomment for more verbose proximity debug
            // console.log(`[DEBUG] Ball ${ball.id} near band seg ${i}: dist=${dist.toFixed(2)}`);
          }
          if (dist < BALL_RADIUS + 6) {
            console.log(`[COLLISION] Ball-band collision: ball at (${ball.x},${ball.y}), band seg ${i} at (${p1.x},${p1.y}), dist=${dist}`);
            const nx = (ball.x - closestX) / (dist || 1e-8);
            const ny = (ball.y - closestY) / (dist || 1e-8);
            const overlap = BALL_RADIUS + 6 - dist;
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
    for (const ball of Object.values(this.balls)) {
      console.log(`[TICK] Ball ${ball.id} at (${ball.x.toFixed(1)},${ball.y.toFixed(1)})`);
    }
    for (let b = 0; b < this.bands.length; b++) {
      const seg = this.bands[b].segments[0];
      console.log(`[TICK] Band ${b} seg0 at (${seg.x.toFixed(1)},${seg.y.toFixed(1)})`);
    }
  }

  update(dt) {
    this.updateBalls(dt);
    this.updateBands(dt);
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
}

module.exports = { GameState, ARENA_SIZE };

