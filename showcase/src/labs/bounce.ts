/**
 * Bounce Lab: a live canvas physics toy that shares the Paper City vocabulary.
 * Drag the courier, fling him, nudge the striped awnings, and take a poster.
 */

const VIEW_W = 16;
const VIEW_H = 9;
const GROUND = 7.55;
const ROAD = 8.24;
const R = 0.42;
const TAU = Math.PI * 2;

const INK = "#181512";
const INK_SOFT = "#3d3833";
const SKY_TOP = "#fcf6ea";
const SKY_BOTTOM = "#f4e6d1";
const PAPER = "#fbf4e7";
const PAPER_LIGHT = "#fef9ef";
const PAPER_MID = "#f6ebd9";
const PAPER_DARK = "#ecdbc2";
const HAZE = "#e6d4bb";
const ACCENT = "#c65b36";
const ACCENT_DARK = "#a24527";
const ACCENT_LIGHT = "#e08056";
const WARM = "#ffc779";
const WARM_PALE = "#ffe3b0";
const SAGE = "#8b906f";
const CREAM = "#faefdc";
const SHADOW = "#967c5f";

type Rng = () => number;

function makeRng(seed: number): Rng {
  let state = seed >>> 0;
  return () => {
    state = (state * 1664525 + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

type Win = { x: number; y: number; w: number; h: number; lit: boolean; shutter: boolean };
type Facade = {
  x: number;
  w: number;
  top: number;
  tone: string;
  windows: Win[];
  door: number;
  shop: boolean;
  roof: "tank" | "chimney" | "antenna" | "plants";
};

function buildBack(): Facade[] {
  const rng = makeRng(41);
  const out: Facade[] = [];
  let x = -1.0;
  while (x < VIEW_W + 1.5) {
    const w = 1.6 + rng() * 0.8;
    const top = 3.0 + rng() * 1.25;
    const windows: Win[] = [];
    for (let row = 0; row < 2; row += 1) {
      for (let col = 0; col < 2; col += 1) {
        windows.push({
          x: x + w * (0.27 + col * 0.42),
          y: top + 0.45 + row * 0.62,
          w: 0.18,
          h: 0.26,
          lit: rng() < 0.22,
          shutter: false,
        });
      }
    }
    out.push({
      x,
      w,
      top,
      tone: HAZE,
      windows,
      door: x + w * 0.2,
      shop: false,
      roof: ["tank", "chimney", "antenna"][Math.floor(rng() * 3)] as Facade["roof"],
    });
    x += w + 0.08;
  }
  return out;
}

function buildFront(): Facade[] {
  const rng = makeRng(77);
  const out: Facade[] = [];
  let x = -0.9;
  while (x < VIEW_W + 1.2) {
    const w = 2.35 + rng() * 0.85;
    const top = 4.45 + rng() * 0.85;
    const windows: Win[] = [];
    for (let row = 0; row < 2; row += 1) {
      for (let col = 0; col < 2; col += 1) {
        windows.push({
          x: x + w * (0.22 + col * 0.46),
          y: top + 0.55 + row * 0.82,
          w: 0.30,
          h: 0.42,
          lit: rng() < 0.55,
          shutter: rng() < 0.2,
        });
      }
    }
    out.push({
      x,
      w,
      top,
      tone: rng() < 0.5 ? PAPER : PAPER_MID,
      windows,
      door: x + w * (0.16 + rng() * 0.1),
      shop: rng() < 0.6,
      roof: ["tank", "chimney", "antenna", "plants"][Math.floor(rng() * 4)] as Facade["roof"],
    });
    x += w + 0.05;
  }
  return out;
}

const BACK = buildBack();
const FRONT = buildFront();

type Awning = { x: number; y: number; w: number; h: number; seed: number };

const AWNING_H = 0.34;
const W = 2.34;
const START_AWNINGS: Awning[] = [
  { x: 3.1, y: 4.95, w: W, h: AWNING_H, seed: 1 },
  { x: 8.1, y: 4.05, w: W, h: AWNING_H, seed: 2 },
  { x: 12.8, y: 5.15, w: W, h: AWNING_H, seed: 3 },
];

type Ball = {
  x: number;
  y: number;
  vx: number;
  vy: number;
  squash: number;
  flare: number;
};

const START_BALL: Ball = { x: 2.1, y: 2.6, vx: 4.6, vy: 1.4, squash: 0, flare: 0 };

function clamp(value: number, low: number, high: number): number {
  return Math.max(low, Math.min(high, value));
}

function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

function mixHex(a: string, b: string, t: number): string {
  const pa = parseInt(a.slice(1), 16);
  const pb = parseInt(b.slice(1), 16);
  const ar = (pa >> 16) & 255;
  const ag = (pa >> 8) & 255;
  const ab = pa & 255;
  const br = (pb >> 16) & 255;
  const bg = (pb >> 8) & 255;
  const bb = pb & 255;
  return `rgb(${Math.round(lerp(ar, br, t))}, ${Math.round(lerp(ag, bg, t))}, ${Math.round(
    lerp(ab, bb, t),
  )})`;
}

function makeGrain(): HTMLCanvasElement {
  const tile = document.createElement("canvas");
  tile.width = 128;
  tile.height = 128;
  const ctx = tile.getContext("2d");
  if (!ctx) return tile;
  const rng = makeRng(9);
  const image = ctx.createImageData(128, 128);
  for (let i = 0; i < image.data.length; i += 4) {
    const v = 25 + rng() * 60;
    image.data[i] = 90;
    image.data[i + 1] = 70;
    image.data[i + 2] = 50;
    image.data[i + 3] = v;
  }
  ctx.putImageData(image, 0, 0);
  return tile;
}

export function bounceLabMarkup(): string {
  return `
  <section class="lab-section" id="lab" aria-labelledby="lab-title">
    <div class="section-head">
      <div><p class="eyebrow">Take the controls</p><h2 id="lab-title">Fling the courier.</h2></div>
      <p class="section-note">A live physics toy drawn on canvas. Drag the ball, let go, and nudge an awning while he flies.</p>
    </div>
    <div class="lab-stage" data-lab-stage>
      <canvas width="1600" height="900" role="img" aria-label="Paper City bounce lab. A paper courier bounces between striped awnings above a cream street.">A paper courier bounces between awnings above a cream street.</canvas>
      <div class="lab-live mono"><span class="live-dot" aria-hidden="true"></span>Bounce Lab / live physics</div>
      <div class="lab-count mono" data-bounces>0 bounces</div>
    </div>
    <div class="lab-controls" role="group" aria-label="Bounce lab controls">
      <label class="lab-slider">
        <span class="mono">Gravity</span>
        <input type="range" min="10" max="40" step="1" value="24" data-gravity />
        <output class="mono" data-gravity-out>24</output>
      </label>
      <label class="lab-slider">
        <span class="mono">Bounce</span>
        <input type="range" min="35" max="92" step="1" value="78" data-restitution />
        <output class="mono" data-restitution-out>78%</output>
      </label>
      <label class="lab-slider">
        <span class="mono">Stretch</span>
        <input type="range" min="0" max="100" step="1" value="60" data-stretch />
        <output class="mono" data-stretch-out>60%</output>
      </label>
      <div class="lab-buttons">
        <button type="button" class="lab-toggle mono" data-onion aria-pressed="false">Onion skin</button>
        <button type="button" class="lab-toggle mono" data-slow aria-pressed="false">Slow motion</button>
        <button type="button" class="lab-toggle mono" data-pause aria-pressed="false">Pause</button>
        <button type="button" class="lab-toggle mono" data-poster>Take a poster</button>
        <button type="button" class="lab-toggle mono" data-reset>Reset</button>
      </div>
    </div>
    <p class="lab-hint mono">Tip: drag an awning up or down to change his path. The counter tracks every clean bounce.</p>
  </section>`;
}

export function mountBounceLab(section: HTMLElement): () => void {
  const stageNode = section.querySelector<HTMLElement>("[data-lab-stage]");
  const canvasNode = section.querySelector<HTMLCanvasElement>("canvas");
  if (!stageNode || !canvasNode) return () => undefined;
  const stage: HTMLElement = stageNode;
  const canvas: HTMLCanvasElement = canvasNode;
  const context = canvas.getContext("2d");
  if (!context) return () => undefined;
  const ctx: CanvasRenderingContext2D = context;

  const gravityInput = section.querySelector<HTMLInputElement>("[data-gravity]");
  const restitutionInput = section.querySelector<HTMLInputElement>("[data-restitution]");
  const stretchInput = section.querySelector<HTMLInputElement>("[data-stretch]");
  const gravityOut = section.querySelector<HTMLOutputElement>("[data-gravity-out]");
  const restitutionOut = section.querySelector<HTMLOutputElement>("[data-restitution-out]");
  const stretchOut = section.querySelector<HTMLOutputElement>("[data-stretch-out]");
  const bouncesOut = section.querySelector<HTMLElement>("[data-bounces]");
  const onionButton = section.querySelector<HTMLButtonElement>("[data-onion]");
  const slowButton = section.querySelector<HTMLButtonElement>("[data-slow]");
  const pauseButton = section.querySelector<HTMLButtonElement>("[data-pause]");
  const posterButton = section.querySelector<HTMLButtonElement>("[data-poster]");
  const resetButton = section.querySelector<HTMLButtonElement>("[data-reset]");

  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const grain = makeGrain();
  const grainPattern = ctx.createPattern(grain, "repeat");

  let awningState = START_AWNINGS.map((item) => ({ ...item }));
  let ball: Ball = { ...START_BALL };
  let gravity = Number(gravityInput?.value ?? 24);
  let restitution = Number(restitutionInput?.value ?? 78) / 100;
  let stretch = Number(stretchInput?.value ?? 60) / 100;
  let paused = reduced;
  let slow = false;
  let onion = false;
  let bounces = 0;
  let ghostClock = 0;
  let stillTime = 0;
  let raf = 0;
  let last = 0;
  let accumulator = 0;
  let disposed = false;

  type TrailPoint = { x: number; y: number };
  let trail: TrailPoint[] = [];
  type Ghost = { x: number; y: number; sx: number; sy: number };
  let ghosts: Ghost[] = [];

  type Drag =
    | { kind: "ball"; grabX: number; grabY: number; vx: number; vy: number; lastX: number; lastY: number }
    | { kind: "awning"; index: number; dx: number; dy: number };
  let drag: Drag | null = null;

  const setPressed = (button: HTMLButtonElement | null, value: boolean) => {
    button?.setAttribute("aria-pressed", String(value));
  };

  function updatePauseLabel() {
    if (!pauseButton) return;
    pauseButton.textContent = paused ? "Play" : "Pause";
    setPressed(pauseButton, paused);
  }

  function updateReadout() {
    if (bouncesOut) bouncesOut.textContent = `${bounces} ${bounces === 1 ? "bounce" : "bounces"}`;
  }

  function reset() {
    ball = { ...START_BALL };
    awningState = START_AWNINGS.map((item) => ({ ...item }));
    trail = [];
    ghosts = [];
    bounces = 0;
    stillTime = 0;
    accumulator = 0;
    updateReadout();
  }

  function resize() {
    const rect = canvas.getBoundingClientRect();
    if (!rect.width || !rect.height) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(rect.width * dpr);
    canvas.height = Math.round(rect.height * dpr);
  }

  const observer = new ResizeObserver(resize);
  observer.observe(stage);
  resize();

  function applyControls() {
    gravity = Number(gravityInput?.value ?? 24);
    restitution = Number(restitutionInput?.value ?? 78) / 100;
    stretch = Number(stretchInput?.value ?? 60) / 100;
    if (gravityOut) gravityOut.textContent = String(Math.round(gravity));
    if (restitutionOut) restitutionOut.textContent = `${Math.round(restitution * 100)}%`;
    if (stretchOut) stretchOut.textContent = `${Math.round(stretch * 100)}%`;
  }

  function impact(speed: number) {
    if (speed > 2.4) {
      ball.squash = clamp(speed / 17, 0.15, 1);
      ball.flare = clamp(speed / 22, 0, 1);
      bounces += 1;
      updateReadout();
    }
  }

  function surfaceUnder(x: number, y: number): number {
    let surface = GROUND;
    for (const a of awningState) {
      if (Math.abs(x - a.x) < a.w / 2 && a.y > y) surface = Math.min(surface, a.y);
    }
    return surface;
  }

  function physics(dt: number) {
    if (drag?.kind === "ball") return;
    ball.vy += gravity * dt;
    ball.x += ball.vx * dt;
    ball.y += ball.vy * dt;
    ball.vx *= 1 - 0.04 * dt;

    if (ball.x < R) {
      ball.x = R;
      ball.vx = Math.abs(ball.vx) * restitution;
    } else if (ball.x > VIEW_W - R) {
      ball.x = VIEW_W - R;
      ball.vx = -Math.abs(ball.vx) * restitution;
    }
    if (ball.y < R + 0.3) {
      ball.y = R + 0.3;
      ball.vy = Math.abs(ball.vy) * restitution;
    }

    if (ball.y + R >= GROUND) {
      ball.y = GROUND - R;
      if (ball.vy > 0) {
        impact(ball.vy);
        ball.vy = -ball.vy * restitution;
      }
      ball.vx *= 0.985;
      if (Math.abs(ball.vy) < 0.9) ball.vy = 0;
    }

    for (const a of awningState) {
      const left = a.x - a.w / 2;
      const right = a.x + a.w / 2;
      const top = a.y;
      const bottom = a.y + a.h;
      const closestX = clamp(ball.x, left, right);
      const closestY = clamp(ball.y, top, bottom);
      const dx = ball.x - closestX;
      const dy = ball.y - closestY;
      const distSq = dx * dx + dy * dy;
      if (distSq > R * R) continue;

      if (distSq > 1e-8) {
        const dist = Math.sqrt(distSq);
        const nx = dx / dist;
        const ny = dy / dist;
        ball.x = closestX + nx * R;
        ball.y = closestY + ny * R;
        const vn = ball.vx * nx + ball.vy * ny;
        if (vn < 0) {
          ball.vx -= (1 + restitution) * vn * nx;
          ball.vy -= (1 + restitution) * vn * ny;
          if (ny < -0.4) impact(Math.abs(vn));
        }
      } else {
        const penetrations = [
          { axis: "x" as const, value: ball.x - left + R, dir: -1 },
          { axis: "x" as const, value: right - ball.x + R, dir: 1 },
          { axis: "y" as const, value: ball.y - top + R, dir: -1 },
          { axis: "y" as const, value: bottom - ball.y + R, dir: 1 },
        ].sort((p, q) => p.value - q.value);
        const best = penetrations[0];
        if (best.axis === "x") {
          ball.x = best.dir < 0 ? left - R : right + R;
          ball.vx = best.dir * Math.abs(ball.vx) * restitution;
        } else {
          ball.y = best.dir < 0 ? top - R : bottom + R;
          ball.vy = best.dir * Math.abs(ball.vy) * restitution;
          if (best.dir < 0) impact(Math.abs(ball.vy));
        }
      }
    }

    const speed = Math.hypot(ball.vx, ball.vy);
    if (speed < 0.45) stillTime += dt;
    else stillTime = 0;
    if (stillTime > 2.6) {
      stillTime = 0;
      ball.vy = -10.5;
      ball.vx = (Math.random() < 0.5 ? -1 : 1) * (2.2 + Math.random() * 2.2);
    }
  }

  function step(dt: number) {
    const scale = slow ? 0.35 : 1;
    accumulator = Math.min(accumulator + dt * scale, 0.2);
    const fixed = 1 / 240;
    while (accumulator >= fixed) {
      physics(fixed);
      accumulator -= fixed;
    }

    ball.squash *= Math.exp(-9 * dt * scale);
    ball.flare *= Math.exp(-4 * dt * scale);

    const speed = Math.hypot(ball.vx, ball.vy);
    if (speed > 1.2 || drag?.kind === "ball") {
      trail.push({ x: ball.x, y: ball.y });
      if (trail.length > 30) trail.shift();
    } else if (trail.length) {
      trail.shift();
    }

    if (onion) {
      ghostClock += dt * scale;
      if (ghostClock > 0.11 && speed > 1.2) {
        ghostClock = 0;
        const factor = squashFactors();
        ghosts.push({ x: ball.x, y: ball.y, sx: factor.sx, sy: factor.sy });
        if (ghosts.length > 5) ghosts.shift();
      }
    } else if (ghosts.length) {
      ghosts = [];
    }
  }

  function squashFactors(): { sx: number; sy: number } {
    const speed = Math.hypot(ball.vx, ball.vy);
    const stretchAmt = clamp(speed / 26, 0, 1) * stretch * 0.3;
    const sx = 1 + ball.squash * 0.42 * stretch + stretchAmt * 0.55;
    const sy = 1 - ball.squash * 0.34 * stretch - stretchAmt;
    return { sx, sy };
  }

  // ---------------------------------------------------------------- scene
  function drawSky(time: number) {
    const gradient = ctx.createLinearGradient(0, 0, 0, GROUND);
    gradient.addColorStop(0, SKY_TOP);
    gradient.addColorStop(1, SKY_BOTTOM);
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);

    ctx.save();
    ctx.globalAlpha = 0.55;
    const sun = ctx.createRadialGradient(13.2, 1.5, 0.15, 13.2, 1.5, 1.5);
    sun.addColorStop(0, WARM_PALE);
    sun.addColorStop(1, "rgba(255,227,176,0)");
    ctx.fillStyle = sun;
    ctx.beginPath();
    ctx.arc(13.2, 1.5, 1.5, 0, TAU);
    ctx.fill();
    ctx.globalAlpha = 0.9;
    ctx.fillStyle = WARM_PALE;
    ctx.beginPath();
    ctx.arc(13.2, 1.5, 0.52, 0, TAU);
    ctx.fill();
    ctx.restore();

    const clouds = [
      { x: 2.1, y: 1.35, span: 0.9, phase: 0.4 },
      { x: 7.4, y: 0.95, span: 0.7, phase: 2.1 },
      { x: 10.8, y: 2.15, span: 0.62, phase: 4.2 },
    ];
    for (const cloud of clouds) {
      const drift = paused ? 0 : Math.sin(time * 0.25 + cloud.phase) * 0.16;
      const cx = cloud.x + drift;
      ctx.save();
      ctx.fillStyle = "rgba(214,196,168,0.34)";
      for (const blob of [
        { dx: -0.45, dy: 0.1, r: 0.3 },
        { dx: -0.08, dy: 0.0, r: 0.4 },
        { dx: 0.3, dy: 0.08, r: 0.3 },
      ]) {
        ctx.beginPath();
        ctx.ellipse(cx + blob.dx * cloud.span, cloud.y + (blob.dy + 0.12) * cloud.span, blob.r * cloud.span, blob.r * cloud.span * 0.72, 0, 0, TAU);
        ctx.fill();
      }
      ctx.fillStyle = "rgba(255,251,242,0.94)";
      for (const blob of [
        { dx: -0.45, dy: 0.1, r: 0.3 },
        { dx: -0.08, dy: 0.0, r: 0.4 },
        { dx: 0.3, dy: 0.08, r: 0.3 },
      ]) {
        ctx.beginPath();
        ctx.ellipse(cx + blob.dx * cloud.span, cloud.y + blob.dy * cloud.span, blob.r * cloud.span, blob.r * cloud.span * 0.72, 0, 0, TAU);
        ctx.fill();
      }
      ctx.restore();
    }
  }

  function drawFacade(facade: Facade, front: boolean, time: number) {
    const base = GROUND + (front ? 0 : 0.05);
    ctx.fillStyle = front ? facade.tone : HAZE;
    ctx.fillRect(facade.x, facade.top, facade.w, base - facade.top);

    if (front) {
      ctx.strokeStyle = INK;
      ctx.lineWidth = 0.035;
      ctx.strokeRect(facade.x, facade.top, facade.w, base - facade.top);
      ctx.fillStyle = "rgba(254,249,239,0.6)";
      ctx.fillRect(facade.x, facade.top, facade.w, 0.05);
      ctx.fillStyle = "rgba(150,124,95,0.12)";
      ctx.fillRect(facade.x, base - 0.24, facade.w, 0.24);
      ctx.fillStyle = "rgba(24,21,18,0.08)";
      ctx.fillRect(facade.x, base - 0.24, facade.w, 0.02);
    } else {
      ctx.strokeStyle = "rgba(24,21,18,0.24)";
      ctx.lineWidth = 0.02;
      ctx.strokeRect(facade.x, facade.top, facade.w, base - facade.top);
    }

    for (const win of facade.windows) {
      const light = front && win.lit ? 1 : 0;
      if (light) {
        const glow = ctx.createRadialGradient(
          win.x + win.w / 2,
          win.y + win.h / 2,
          0.02,
          win.x + win.w / 2,
          win.y + win.h / 2,
          win.w * 1.4,
        );
        glow.addColorStop(0, "rgba(255,199,121,0.5)");
        glow.addColorStop(1, "rgba(255,199,121,0)");
        ctx.fillStyle = glow;
        ctx.fillRect(win.x - win.w, win.y - win.h, win.w * 3, win.h * 3);
      }
      ctx.fillStyle = front ? (win.lit ? mixHex(WARM, WARM_PALE, 0.4) : "#6e553c") : "rgba(61,56,51,0.3)";
      ctx.fillRect(win.x, win.y, win.w, win.h);
      if (front) {
        ctx.strokeStyle = INK;
        ctx.lineWidth = 0.022;
        ctx.strokeRect(win.x, win.y, win.w, win.h);
        ctx.strokeStyle = "rgba(24,21,18,0.5)";
        ctx.lineWidth = 0.012;
        ctx.beginPath();
        ctx.moveTo(win.x + win.w / 2, win.y);
        ctx.lineTo(win.x + win.w / 2, win.y + win.h);
        ctx.moveTo(win.x, win.y + win.h / 2);
        ctx.lineTo(win.x + win.w, win.y + win.h / 2);
        ctx.stroke();
        if (win.shutter) {
          ctx.fillStyle = SAGE;
          ctx.fillRect(win.x - win.w * 0.22, win.y, win.w * 0.18, win.h);
          ctx.fillRect(win.x + win.w + win.w * 0.04, win.y, win.w * 0.18, win.h);
        }
      } else if (front) {
        ctx.strokeStyle = "rgba(24,21,18,0.4)";
        ctx.lineWidth = 0.012;
        ctx.strokeRect(win.x, win.y, win.w, win.h);
      }
    }

    if (front) {
      const doorX = facade.door;
      ctx.fillStyle = INK;
      ctx.fillRect(doorX, GROUND - 0.92, 0.42, 0.92);
      ctx.fillStyle = mixHex(ACCENT_DARK, INK, 0.45);
      ctx.fillRect(doorX + 0.05, GROUND - 0.86, 0.32, 0.8);
      ctx.strokeStyle = "rgba(255,247,232,0.35)";
      ctx.lineWidth = 0.014;
      ctx.strokeRect(doorX + 0.09, GROUND - 0.78, 0.24, 0.26);
      ctx.strokeRect(doorX + 0.09, GROUND - 0.44, 0.24, 0.3);
      ctx.fillStyle = "rgba(24,21,18,0.2)";
      ctx.fillRect(doorX - 0.06, GROUND - 0.04, 0.54, 0.04);
      if (facade.shop) {
        ctx.fillStyle = "#3b2a20";
        ctx.fillRect(doorX + 0.58, GROUND - 0.72, 0.7, 0.66);
        ctx.fillStyle = "rgba(255,199,121,0.88)";
        ctx.fillRect(doorX + 0.62, GROUND - 0.68, 0.62, 0.5);
        ctx.strokeStyle = INK;
        ctx.lineWidth = 0.02;
        ctx.strokeRect(doorX + 0.58, GROUND - 0.72, 0.7, 0.66);
        ctx.fillStyle = ACCENT;
        ctx.fillRect(doorX + 0.54, GROUND - 0.78, 0.78, 0.1);
      }
    }

    const roof = facade.roof;
    if (roof === "tank") {
      ctx.fillStyle = front ? PAPER_LIGHT : HAZE;
      ctx.strokeStyle = "rgba(24,21,18,0.5)";
      ctx.lineWidth = 0.02;
      ctx.fillRect(facade.x + facade.w * 0.6, facade.top - 0.3, 0.26, 0.3);
      ctx.strokeRect(facade.x + facade.w * 0.6, facade.top - 0.3, 0.26, 0.3);
    } else if (roof === "chimney") {
      ctx.fillStyle = ACCENT;
      ctx.fillRect(facade.x + facade.w * 0.26, facade.top - 0.26, 0.18, 0.26);
      ctx.fillStyle = PAPER_LIGHT;
      ctx.fillRect(facade.x + facade.w * 0.25, facade.top - 0.29, 0.2, 0.05);
    } else if (roof === "antenna") {
      ctx.strokeStyle = INK;
      ctx.lineWidth = 0.018;
      ctx.beginPath();
      ctx.moveTo(facade.x + facade.w * 0.7, facade.top);
      ctx.lineTo(facade.x + facade.w * 0.7, facade.top - 0.55);
      ctx.moveTo(facade.x + facade.w * 0.62, facade.top - 0.4);
      ctx.lineTo(facade.x + facade.w * 0.78, facade.top - 0.4);
      ctx.stroke();
    } else {
      for (let i = 0; i < 3; i += 1) {
        ctx.fillStyle = ACCENT_DARK;
        ctx.fillRect(facade.x + facade.w * (0.3 + i * 0.16), facade.top - 0.07, 0.1, 0.07);
        ctx.fillStyle = SAGE;
        ctx.beginPath();
        ctx.arc(facade.x + facade.w * (0.35 + i * 0.16), facade.top - 0.12, 0.07, 0, TAU);
        ctx.fill();
      }
    }

    if (front && facade.top - 0.06 > 0) {
      ctx.strokeStyle = "rgba(24,21,18,0.18)";
      ctx.lineWidth = 0.012;
      for (let row = 1; row < 4; row += 1) {
        const y = facade.top + row * 0.34;
        if (y < GROUND - 0.4) {
          ctx.beginPath();
          ctx.moveTo(facade.x + 0.04, y);
          ctx.lineTo(facade.x + facade.w - 0.04, y);
          ctx.stroke();
        }
      }
    }
    void time;
  }

  function drawBunting(time: number) {
    ctx.save();
    const spans = [
      { x: -0.4, y: 3.15 },
      { x: 3.9, y: 3.0 },
      { x: 8.2, y: 3.2 },
      { x: 12.4, y: 2.95 },
    ];
    for (const span of spans) {
      const endX = span.x + 4.3;
      const endY = span.y + 0.16;
      const midX = (span.x + endX) / 2;
      const midY = Math.max(span.y, endY) + 0.46;
      ctx.strokeStyle = "rgba(24,21,18,0.42)";
      ctx.lineWidth = 0.016;
      ctx.beginPath();
      ctx.moveTo(span.x, span.y);
      ctx.quadraticCurveTo(midX, midY, endX, endY);
      ctx.stroke();
      const flags = 9;
      for (let i = 1; i < flags; i += 1) {
        const t = i / flags;
        const x = (1 - t) * (1 - t) * span.x + 2 * (1 - t) * t * midX + t * t * endX;
        const y = (1 - t) * (1 - t) * span.y + 2 * (1 - t) * t * midY + t * t * endY;
        const sway = paused ? 0 : Math.sin(time * 2.2 + i * 0.7) * 0.018;
        ctx.fillStyle = i % 3 === 0 ? CREAM : ACCENT;
        ctx.beginPath();
        ctx.moveTo(x - 0.16, y);
        ctx.lineTo(x + 0.16, y);
        ctx.lineTo(x + sway, y + 0.28);
        ctx.closePath();
        ctx.fill();
      }
    }
    ctx.restore();
  }

  function drawAwnings(time: number) {
    for (const awning of awningState) {
      const left = awning.x - awning.w / 2;
      const top = awning.y;
      const bottom = awning.y + awning.h;
      ctx.save();
      ctx.shadowColor = "rgba(118,98,79,0.22)";
      ctx.shadowBlur = 8;
      ctx.shadowOffsetY = 4;
      ctx.fillStyle = PAPER_LIGHT;
      ctx.fillRect(left, top, awning.w, awning.h);
      ctx.restore();

      const stripes = 8;
      const stripeW = awning.w / stripes;
      for (let i = 0; i < stripes; i += 1) {
        ctx.fillStyle = i % 2 === 0 ? ACCENT : PAPER_LIGHT;
        ctx.fillRect(left + i * stripeW, top, stripeW, awning.h);
      }
      ctx.strokeStyle = INK;
      ctx.lineWidth = 0.032;
      ctx.strokeRect(left, top, awning.w, awning.h);

      for (let i = 0; i < 7; i += 1) {
        const cx = left + (i + 0.5) * (awning.w / 7);
        ctx.fillStyle = i % 2 === 0 ? PAPER_LIGHT : ACCENT_LIGHT;
        ctx.beginPath();
        ctx.arc(cx, bottom, awning.w / 14, 0, Math.PI);
        ctx.fill();
        ctx.strokeStyle = INK;
        ctx.lineWidth = 0.02;
        ctx.stroke();
      }

      ctx.strokeStyle = "rgba(24,21,18,0.55)";
      ctx.lineWidth = 0.022;
      ctx.beginPath();
      ctx.moveTo(left + 0.16, top);
      ctx.lineTo(left + 0.34, top - 0.42);
      ctx.moveTo(left + awning.w - 0.16, top);
      ctx.lineTo(left + awning.w - 0.34, top - 0.42);
      ctx.stroke();

      const pulse = 0.5 + 0.5 * Math.sin(time * 1.8 + awning.seed);
      ctx.fillStyle = `rgba(254,249,239,${0.55 + pulse * 0.3})`;
      for (let i = -1; i <= 1; i += 1) {
        ctx.beginPath();
        ctx.arc(awning.x + i * 0.14, top + awning.h / 2, 0.035, 0, TAU);
        ctx.fill();
      }
    }
  }

  function drawStreet() {
    ctx.fillStyle = PAPER_DARK;
    ctx.fillRect(0, GROUND, VIEW_W, ROAD - GROUND);
    ctx.strokeStyle = "rgba(24,21,18,0.6)";
    ctx.lineWidth = 0.02;
    ctx.beginPath();
    ctx.moveTo(0, GROUND);
    ctx.lineTo(VIEW_W, GROUND);
    ctx.stroke();

    ctx.fillStyle = "rgba(24,21,18,0.08)";
    for (let x = 0.4; x < VIEW_W; x += 1.1) {
      ctx.fillRect(x, GROUND + 0.18, 0.5, 0.02);
    }
    ctx.strokeStyle = "rgba(24,21,18,0.5)";
    ctx.lineWidth = 0.03;
    ctx.beginPath();
    ctx.moveTo(0, ROAD);
    ctx.lineTo(VIEW_W, ROAD);
    ctx.stroke();

    ctx.fillStyle = "#e9d9c1";
    ctx.fillRect(0, ROAD, VIEW_W, VIEW_H - ROAD);
    ctx.fillStyle = ACCENT;
    ctx.fillRect(0, ROAD + 0.16, VIEW_W, 0.055);
    ctx.fillStyle = "rgba(24,21,18,0.22)";
    for (let x = 0.4; x < VIEW_W; x += 1.3) {
      ctx.fillRect(x, ROAD + 0.66, 0.7, 0.035);
    }

    const leaves = [
      { x: 1.2, y: 8.7, r: 0.05, angle: 0.3 },
      { x: 4.9, y: 8.48, r: 0.04, angle: -0.6 },
      { x: 6.7, y: 8.82, r: 0.055, angle: 0.9 },
      { x: 10.3, y: 8.62, r: 0.045, angle: 0.2 },
      { x: 14.6, y: 8.78, r: 0.05, angle: -0.4 },
    ];
    for (const leaf of leaves) {
      ctx.save();
      ctx.translate(leaf.x, leaf.y);
      ctx.rotate(leaf.angle);
      ctx.fillStyle = "rgba(110,116,86,0.7)";
      ctx.beginPath();
      ctx.ellipse(0, 0, leaf.r * 1.6, leaf.r * 0.7, 0, 0, TAU);
      ctx.fill();
      ctx.restore();
    }
  }

  function drawShadow() {
    const surface = surfaceUnder(ball.x, ball.y);
    const height = clamp(surface - ball.y - R, 0, 6);
    const alpha = clamp(0.24 - height * 0.03, 0.04, 0.24);
    const spread = 1 + height * 0.07;
    ctx.save();
    ctx.fillStyle = `rgba(118,98,79,${alpha})`;
    ctx.beginPath();
    ctx.ellipse(ball.x, surface - 0.015, R * 1.05 * spread, R * 0.26 * spread, 0, 0, TAU);
    ctx.fill();
    ctx.restore();
  }

  function drawTrail(time: number) {
    if (trail.length < 2) return;
    for (let i = 1; i < trail.length; i += 1) {
      const from = trail[i - 1];
      const to = trail[i];
      const f = i / trail.length;
      const angle = Math.atan2(to.y - from.y, to.x - from.x);
      const flutter = Math.sin(time * 5 + i * 0.9) * 0.035;
      const ox = Math.cos(angle + Math.PI / 2) * flutter;
      const oy = Math.sin(angle + Math.PI / 2) * flutter;
      ctx.strokeStyle = i % 5 === 0 ? ACCENT : CREAM;
      ctx.lineWidth = R * 0.5 * f + 0.028;
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(from.x + ox, from.y + oy);
      ctx.lineTo(to.x + ox, to.y + oy);
      ctx.stroke();
    }
    const end = trail[0];
    ctx.fillStyle = CREAM;
    ctx.strokeStyle = INK;
    ctx.lineWidth = 0.02;
    ctx.beginPath();
    ctx.moveTo(end.x - 0.1, end.y);
    ctx.lineTo(end.x + 0.12, end.y - 0.02);
    ctx.lineTo(end.x + 0.06, end.y + 0.12);
    ctx.lineTo(end.x - 0.06, end.y + 0.1);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
  }

  function drawGhosts() {
    for (let i = 0; i < ghosts.length; i += 1) {
      const ghost = ghosts[i];
      const alpha = 0.035 + (i / ghosts.length) * 0.05;
      ctx.save();
      ctx.translate(ghost.x, ghost.y);
      ctx.scale(ghost.sx, ghost.sy);
      ctx.strokeStyle = `rgba(198,91,54,${alpha})`;
      ctx.lineWidth = 0.03;
      ctx.beginPath();
      ctx.arc(0, 0, R, 0, TAU);
      ctx.stroke();
      ctx.restore();
    }
  }

  function drawCourier(time: number) {
    const dir = ball.vx >= -0.1 ? 1 : -1;
    const factors = squashFactors();
    ctx.save();
    ctx.translate(ball.x, ball.y);
    ctx.scale(factors.sx, factors.sy);

    const body = ctx.createRadialGradient(-R * 0.36, -R * 0.44, R * 0.12, 0, 0, R * 1.14);
    body.addColorStop(0, "#d9724b");
    body.addColorStop(0.58, "#c85c37");
    body.addColorStop(1, "#a84a2a");
    ctx.fillStyle = body;
    ctx.beginPath();
    ctx.arc(0, 0, R, 0, TAU);
    ctx.fill();
    ctx.strokeStyle = INK;
    ctx.lineWidth = 0.045;
    ctx.stroke();

    ctx.save();
    ctx.beginPath();
    ctx.arc(0, 0, R - 0.02, 0, TAU);
    ctx.clip();
    ctx.fillStyle = CREAM;
    ctx.fillRect(-R, R * 0.43, R * 2, R * 0.32);
    ctx.fillStyle = ACCENT;
    ctx.fillRect(-R, R * 0.63, R * 2, R * 0.055);
    ctx.strokeStyle = INK;
    ctx.lineWidth = 0.02;
    ctx.beginPath();
    ctx.moveTo(-R, R * 0.43);
    ctx.lineTo(R, R * 0.43);
    ctx.moveTo(-R, R * 0.75);
    ctx.lineTo(R, R * 0.75);
    ctx.stroke();
    ctx.restore();

    ctx.strokeStyle = "rgba(255,247,232,0.5)";
    ctx.lineWidth = 0.055;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.arc(0, 0, R * 0.84, Math.PI * 0.86, Math.PI * 1.2);
    ctx.stroke();

    ctx.fillStyle = INK;
    for (const side of [-1, 1]) {
      ctx.beginPath();
      ctx.arc(side * R * 0.27, -R * 0.12, R * 0.105, 0, TAU);
      ctx.fill();
    }
    ctx.fillStyle = CREAM;
    for (const side of [-1, 1]) {
      ctx.beginPath();
      ctx.arc(side * R * 0.27 - R * 0.03, -R * 0.15, R * 0.032, 0, TAU);
      ctx.fill();
    }
    ctx.fillStyle = "rgba(255,226,206,0.55)";
    for (const side of [-1, 1]) {
      ctx.beginPath();
      ctx.ellipse(side * R * 0.44, R * 0.10, R * 0.09, R * 0.065, 0, 0, TAU);
      ctx.fill();
    }
    ctx.strokeStyle = INK;
    ctx.lineWidth = 0.035;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.arc(0, R * 0.04, R * 0.2, Math.PI * 0.16, Math.PI * 0.84);
    ctx.stroke();

    const sway = Math.sin(time * 4.2) * 0.03;
    const bagX = R * 0.62;
    const bagY = R * 0.34;
    ctx.strokeStyle = CREAM;
    ctx.lineWidth = 0.05;
    ctx.beginPath();
    ctx.moveTo(-R * 0.5, -R * 0.35);
    ctx.quadraticCurveTo(R * 0.05, R * 0.05, bagX - 0.04, bagY - 0.02);
    ctx.stroke();
    ctx.fillStyle = "#3d2d22";
    ctx.strokeStyle = INK;
    ctx.lineWidth = 0.022;
    const bagW = R * 0.42;
    const bagH = R * 0.3;
    ctx.beginPath();
    ctx.roundRect(bagX - bagW / 2, bagY - bagH / 2 + sway * 0.2, bagW, bagH, 0.05);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = ACCENT;
    ctx.fillRect(bagX - bagW / 2 + 0.01, bagY - bagH / 2 - 0.005, bagW - 0.02, bagH * 0.28);
    ctx.fillStyle = CREAM;
    ctx.beginPath();
    ctx.arc(bagX, bagY + bagH * 0.06, R * 0.035, 0, TAU);
    ctx.fill();

    ctx.fillStyle = CREAM;
    ctx.strokeStyle = INK;
    ctx.lineWidth = 0.025;
    for (const side of [-1, 1]) {
      ctx.beginPath();
      ctx.ellipse(side * R * 0.32, R * 0.92, R * 0.16, R * 0.09, 0, 0, TAU);
      ctx.fill();
      ctx.stroke();
    }

    const capBase = -R * 0.58;
    ctx.fillStyle = CREAM;
    ctx.strokeStyle = INK;
    ctx.lineWidth = 0.028;
    ctx.beginPath();
    ctx.ellipse(0, capBase, R * 0.6, R * 0.46, 0, Math.PI, TAU);
    ctx.fill();
    ctx.stroke();
    ctx.fillRect(-R * 0.6, capBase - R * 0.03, R * 1.2, R * 0.07);
    ctx.fillStyle = ACCENT;
    ctx.fillRect(-R * 0.6, capBase - R * 0.1, R * 1.2, R * 0.09);
    ctx.strokeStyle = INK;
    ctx.lineWidth = 0.018;
    const brim = R * 0.48;
    ctx.beginPath();
    ctx.moveTo(-R * 0.08, capBase - R * 0.04);
    ctx.lineTo(dir * (R * 0.12 + brim), capBase + R * 0.02);
    ctx.lineTo(dir * (R * 0.1 + brim), capBase + R * 0.13);
    ctx.lineTo(dir * R * 0.06, capBase + R * 0.08);
    ctx.closePath();
    ctx.fillStyle = CREAM;
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = ACCENT;
    ctx.beginPath();
    ctx.arc(0, capBase - R * 0.43, R * 0.045, 0, TAU);
    ctx.fill();
    ctx.stroke();

    ctx.restore();
  }

  function drawOverlay(time: number) {
    if (!grainPattern) return;
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalAlpha = 0.06;
    ctx.fillStyle = grainPattern;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.restore();

    ctx.save();
    const vignette = ctx.createRadialGradient(
      VIEW_W / 2,
      VIEW_H * 0.46,
      VIEW_H * 0.3,
      VIEW_W / 2,
      VIEW_H * 0.5,
      VIEW_W * 0.68,
    );
    vignette.addColorStop(0, "rgba(120,90,60,0)");
    vignette.addColorStop(1, "rgba(120,90,60,0.12)");
    ctx.fillStyle = vignette;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);
    ctx.restore();
    void time;
  }

  function draw(time: number) {
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.setTransform(canvas.width / VIEW_W, 0, 0, canvas.height / VIEW_H, 0, 0);
    ctx.lineJoin = "round";

    drawSky(time);
    for (const facade of BACK) drawFacade(facade, false, time);
    for (const facade of FRONT) drawFacade(facade, true, time);
    drawBunting(time);
    drawStreet();
    drawAwnings(time);
    drawShadow();
    drawGhosts();
    drawTrail(time);
    drawCourier(time);
    drawOverlay(time);
  }

  function loop(now: number) {
    if (disposed) return;
    raf = requestAnimationFrame(loop);
    const dt = last ? Math.min(0.05, (now - last) / 1000) : 0;
    last = now;
    if (!paused) step(dt);
    draw(now / 1000);
  }

  // ------------------------------------------------------------- pointers
  function toWorld(event: PointerEvent): { x: number; y: number } {
    const rect = canvas.getBoundingClientRect();
    return {
      x: ((event.clientX - rect.left) / rect.width) * VIEW_W,
      y: ((event.clientY - rect.top) / rect.height) * VIEW_H,
    };
  }

  function awningAt(x: number, y: number): number {
    for (let i = awningState.length - 1; i >= 0; i -= 1) {
      const a = awningState[i];
      if (x > a.x - a.w / 2 - 0.15 && x < a.x + a.w / 2 + 0.15 && y > a.y - 0.15 && y < a.y + a.h + 0.2) {
        return i;
      }
    }
    return -1;
  }

  function onPointerDown(event: PointerEvent) {
    if (event.button !== 0) return;
    const point = toWorld(event);
    const dist = Math.hypot(point.x - ball.x, point.y - ball.y);
    if (dist < R * 1.8) {
      drag = {
        kind: "ball",
        grabX: point.x - ball.x,
        grabY: point.y - ball.y,
        vx: 0,
        vy: 0,
        lastX: point.x,
        lastY: point.y,
      };
      ball.vx = 0;
      ball.vy = 0;
      stillTime = 0;
      canvas.setPointerCapture(event.pointerId);
      canvas.classList.add("is-grabbing");
      event.preventDefault();
      return;
    }
    const index = awningAt(point.x, point.y);
    if (index >= 0) {
      const a = awningState[index];
      drag = { kind: "awning", index, dx: point.x - a.x, dy: point.y - a.y };
      canvas.setPointerCapture(event.pointerId);
      canvas.classList.add("is-grabbing");
      event.preventDefault();
    }
  }

  function onPointerMove(event: PointerEvent) {
    const point = toWorld(event);
    if (!drag) {
      const nearBall = Math.hypot(point.x - ball.x, point.y - ball.y) < R * 1.8;
      canvas.style.cursor = nearBall ? "grab" : awningAt(point.x, point.y) >= 0 ? "move" : "default";
      return;
    }
    if (drag.kind === "ball") {
      const targetX = point.x - drag.grabX;
      const targetY = point.y - drag.grabY;
      drag.vx = (point.x - drag.lastX) * 12;
      drag.vy = (point.y - drag.lastY) * 12;
      drag.lastX = point.x;
      drag.lastY = point.y;
      ball.x = clamp(targetX, R, VIEW_W - R);
      ball.y = clamp(targetY, R + 0.3, GROUND - R);
      stillTime = 0;
      if (Math.hypot(ball.vx, ball.vy) > 0.4) {
        trail.push({ x: ball.x, y: ball.y });
        if (trail.length > 30) trail.shift();
      }
      event.preventDefault();
      return;
    }
    const a = awningState[drag.index];
    if (!a) return;
    a.x = clamp(point.x - drag.dx, a.w / 2 + 0.2, VIEW_W - a.w / 2 - 0.2);
    a.y = clamp(point.y - drag.dy, 2.2, GROUND - a.h - 0.45);
    event.preventDefault();
  }

  function endDrag(event: PointerEvent) {
    if (!drag) return;
    if (drag.kind === "ball") {
      ball.vx = clamp(drag.vx, -26, 26);
      ball.vy = clamp(drag.vy, -26, 26);
    }
    drag = null;
    canvas.classList.remove("is-grabbing");
    if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
  }

  function onPointerCancel(event: PointerEvent) {
    if (drag?.kind === "ball") {
      ball.vx = 0;
      ball.vy = 0;
    }
    drag = null;
    canvas.classList.remove("is-grabbing");
    if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
  }

  // --------------------------------------------------------------- toolbar
  function onGravity() {
    applyControls();
  }

  function onOnion() {
    onion = !onion;
    setPressed(onionButton, onion);
    ghosts = [];
  }

  function onSlow() {
    slow = !slow;
    setPressed(slowButton, slow);
  }

  function onPause() {
    paused = !paused;
    updatePauseLabel();
  }

  function onReset() {
    reset();
  }

  async function takePoster() {
    const still = document.createElement("canvas");
    still.width = 1600;
    still.height = 1030;
    const out = still.getContext("2d");
    if (!out) return;
    try {
      await document.fonts.ready;
    } catch {
      // Fonts are a nicety; the poster still exports with system faces.
    }
    out.fillStyle = "#f6f1e6";
    out.fillRect(0, 0, still.width, still.height);
    out.drawImage(canvas, 0, 0, 1600, 900);

    out.strokeStyle = "rgba(24,21,18,0.18)";
    out.lineWidth = 1;
    out.beginPath();
    out.moveTo(0, 900);
    out.lineTo(still.width, 900);
    out.stroke();

    out.fillStyle = "#181512";
    out.font = "600 46px 'Fraunces Variable', Georgia, serif";
    out.fillText("Paper City", 48, 968);
    out.fillStyle = "#73756c";
    out.font = "400 17px 'IBM Plex Mono', monospace";
    out.fillText("BOUNCE LAB / A LIVE PHYSICS TOY", 49, 1000);
    out.textAlign = "right";
    out.fillStyle = "#c65b36";
    out.beginPath();
    out.arc(1516, 956, 7, 0, TAU);
    out.fill();
    out.fillStyle = "#181512";
    out.font = "400 17px 'IBM Plex Mono', monospace";
    out.fillText("KONE STUDIO / 2026", 1552, 962);
    out.textAlign = "left";

    still.toBlob((blob) => {
      if (!blob) return;
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "paper-city-bounce-lab.png";
      link.click();
      window.setTimeout(() => URL.revokeObjectURL(url), 4000);
    }, "image/png");
  }

  gravityInput?.addEventListener("input", onGravity);
  restitutionInput?.addEventListener("input", onGravity);
  stretchInput?.addEventListener("input", onGravity);
  onionButton?.addEventListener("click", onOnion);
  slowButton?.addEventListener("click", onSlow);
  pauseButton?.addEventListener("click", onPause);
  resetButton?.addEventListener("click", onReset);
  posterButton?.addEventListener("click", () => void takePoster());
  canvas.addEventListener("pointerdown", onPointerDown);
  canvas.addEventListener("pointermove", onPointerMove);
  canvas.addEventListener("pointerup", endDrag);
  canvas.addEventListener("pointercancel", onPointerCancel);
  canvas.addEventListener("pointerleave", (event) => {
    if (!drag) canvas.style.cursor = "default";
    if (drag?.kind === "ball") endDrag(event);
  });

  applyControls();
  updatePauseLabel();
  updateReadout();
  if (reduced) {
    ball = { ...START_BALL, y: 3.4, vx: 0, vy: 0 };
  }
  draw(0);
  raf = requestAnimationFrame(loop);

  return () => {
    disposed = true;
    cancelAnimationFrame(raf);
    observer.disconnect();
    gravityInput?.removeEventListener("input", onGravity);
    restitutionInput?.removeEventListener("input", onGravity);
    stretchInput?.removeEventListener("input", onGravity);
    onionButton?.removeEventListener("click", onOnion);
    slowButton?.removeEventListener("click", onSlow);
    pauseButton?.removeEventListener("click", onPause);
    resetButton?.removeEventListener("click", onReset);
    canvas.removeEventListener("pointerdown", onPointerDown);
    canvas.removeEventListener("pointermove", onPointerMove);
    canvas.removeEventListener("pointerup", endDrag);
    canvas.removeEventListener("pointercancel", onPointerCancel);
  };
}
