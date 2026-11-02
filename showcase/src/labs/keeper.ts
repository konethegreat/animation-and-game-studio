/**
 * Keeper Diorama: the rig, a paper bridge and a sleeping city in three.js.
 * Scrub the walk, change the hour, raise the lantern and wake the windows.
 */

import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import type { Project } from "../projects.generated";
import { createStage, type Stage } from "./stage";

const BASE = import.meta.env.BASE_URL;
const TAU = Math.PI * 2;
const DECK_START = 5.8;

const DUSK_TOP = new THREE.Color(0x2b1b3d);
const DUSK_HORIZON = new THREE.Color(0xff8a5c);
const DUSK_BOTTOM = new THREE.Color(0x1a1224);
const NIGHT_TOP = new THREE.Color(0x090b1c);
const NIGHT_HORIZON = new THREE.Color(0x4a2d45);
const NIGHT_BOTTOM = new THREE.Color(0x05060f);

const asset = (path: string) => `${BASE}${path.replace(/^\/+/, "")}`;
const smoothstep = (low: number, high: number, value: number) => {
  const t = Math.max(0, Math.min(1, (value - low) / (high - low)));
  return t * t * (3 - 2 * t);
};
const clamp = (value: number, low: number, high: number) => Math.max(low, Math.min(high, value));

const deckY = (z: number) => 0.18 + 0.40 * Math.max(0, Math.cos((Math.PI * z) / 12.2));

type Wake = { mesh: THREE.Mesh; delay: number; lit: boolean; width: number; height: number; depth: number };

type Diorama = {
  windows: Wake[];
  bulbs: Wake[];
  skyPaint: (dusk: number) => void;
  moon: THREE.Mesh;
  moonHalo: THREE.Sprite;
  hotWindow: THREE.MeshBasicMaterial;
  dimWindow: THREE.MeshBasicMaterial;
  hemi: THREE.HemisphereLight | null;
  key: THREE.DirectionalLight | null;
  rim: THREE.DirectionalLight | null;
  fill: THREE.DirectionalLight | null;
  fireflies: THREE.Mesh[];
};

function glowTexture(inner = "226,255,166", mid = "180,240,96", outer = "150,220,70"): THREE.CanvasTexture {
  const canvas = document.createElement("canvas");
  canvas.width = 128;
  canvas.height = 128;
  const context = canvas.getContext("2d");
  if (context) {
    const gradient = context.createRadialGradient(64, 64, 0, 64, 64, 64);
    gradient.addColorStop(0, `rgba(${inner},0.95)`);
    gradient.addColorStop(0.35, `rgba(${mid},0.45)`);
    gradient.addColorStop(1, `rgba(${outer},0)`);
    context.fillStyle = gradient;
    context.fillRect(0, 0, 128, 128);
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

function box(
  parent: THREE.Object3D,
  width: number,
  height: number,
  depth: number,
  x: number,
  y: number,
  z: number,
  material: THREE.Material,
  rotationX = 0,
): THREE.Mesh {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(width, height, depth), material);
  mesh.position.set(x, y, z);
  mesh.rotation.x = rotationX;
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  parent.add(mesh);
  return mesh;
}

function tube(parent: THREE.Object3D, a: THREE.Vector3, b: THREE.Vector3, radius: number, material: THREE.Material) {
  const direction = b.clone().sub(a);
  const mesh = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, direction.length(), 8), material);
  mesh.position.copy(a).add(b).multiplyScalar(0.5);
  mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.clone().normalize());
  parent.add(mesh);
  return mesh;
}

function buildDiorama(scene: THREE.Scene, moonGlow: THREE.Texture | null): Diorama {
  const cream = new THREE.MeshStandardMaterial({ color: 0xf3e8d4, roughness: 0.9, metalness: 0 });
  const paper = new THREE.MeshStandardMaterial({ color: 0xe6d7bd, roughness: 0.92, metalness: 0 });
  const ink = new THREE.MeshStandardMaterial({ color: 0x16141b, roughness: 0.55, metalness: 0.08 });
  const inkSoft = new THREE.MeshStandardMaterial({ color: 0x211e2a, roughness: 0.6, metalness: 0.05 });
  const leather = new THREE.MeshStandardMaterial({ color: 0x4a3528, roughness: 0.8, metalness: 0 });
  const water = new THREE.MeshStandardMaterial({ color: 0x0a0f1d, roughness: 0.18, metalness: 0.55 });
  const hotWindow = new THREE.MeshBasicMaterial({ color: 0xffc46e, toneMapped: false });
  const dimWindow = new THREE.MeshBasicMaterial({ color: 0x8a6338, toneMapped: false });
  const amber = new THREE.MeshBasicMaterial({ color: 0xffb45e, toneMapped: false });

  const windows: Wake[] = [];
  const bulbs: Wake[] = [];

  // Sky dome painted from vertex colors so the hour can change without a shader.
  const skyGeometry = new THREE.SphereGeometry(44, 32, 18);
  const count = skyGeometry.attributes.position.count;
  const skyColors = new Float32Array(count * 3);
  skyGeometry.setAttribute("color", new THREE.BufferAttribute(skyColors, 3));
  const sky = new THREE.Mesh(
    skyGeometry,
    new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.BackSide, depthWrite: false, fog: false, toneMapped: false }),
  );
  sky.renderOrder = -10;
  scene.add(sky);
  const skyPositions = skyGeometry.attributes.position;

  function skyPaint(dusk: number) {
    const top = DUSK_TOP.clone().lerp(NIGHT_TOP, dusk);
    const horizon = DUSK_HORIZON.clone().lerp(NIGHT_HORIZON, dusk);
    const bottom = DUSK_BOTTOM.clone().lerp(NIGHT_BOTTOM, dusk);
    const scratch = new THREE.Color();
    for (let index = 0; index < count; index += 1) {
      const h = skyPositions.getY(index) / 44;
      if (h < 0) {
        scratch.copy(bottom).lerp(horizon, smoothstep(-0.2, 0.02, h));
      } else {
        scratch.copy(horizon).lerp(top, smoothstep(0.02, 0.62, h));
      }
      skyColors[index * 3] = scratch.r;
      skyColors[index * 3 + 1] = scratch.g;
      skyColors[index * 3 + 2] = scratch.b;
    }
    skyGeometry.attributes.color.needsUpdate = true;
    scene.fog = new THREE.FogExp2(horizon.clone().lerp(bottom, 0.55).getHex(), 0.028);
  }
  skyPaint(0.32);

  // Moon and halo.
  const moon = new THREE.Mesh(
    new THREE.CircleGeometry(0.95, 48),
    new THREE.MeshBasicMaterial({ color: 0xfff2d4, toneMapped: false, fog: false, transparent: true, opacity: 0.95 }),
  );
  moon.position.set(-9.4, 7.6, -20);
  scene.add(moon);
  const moonHalo = new THREE.Sprite(
    moonGlow
      ? new THREE.SpriteMaterial({ map: moonGlow, transparent: true, opacity: 0.62, blending: THREE.AdditiveBlending, depthWrite: false, fog: false })
      : new THREE.SpriteMaterial({ color: 0xffd2a0, transparent: true, opacity: 0.3 }),
  );
  moonHalo.position.set(-9.3, 7.55, -19.9);
  moonHalo.scale.set(5.4, 5.4, 1);
  scene.add(moonHalo);

  // River and banks.
  const river = new THREE.Mesh(new THREE.PlaneGeometry(30, 15), water);
  river.rotation.x = -Math.PI / 2;
  river.position.set(0, -0.26, 0);
  river.receiveShadow = true;
  scene.add(river);

  for (const z of [7.1, -7.1]) {
    box(scene, 30, 0.34, 2.4, 0, -0.12, z, cream);
  }
  box(scene, 30, 0.24, 8, 0, 0.0, -11, paper);

  // A few warm reflections on the water.
  const reflectionMaterial = new THREE.MeshBasicMaterial({
    color: 0xffb377,
    transparent: true,
    opacity: 0.16,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
  });
  for (const [x, width, length, z] of [
    [-2.4, 0.5, 5.4, -4.6],
    [3.2, 0.32, 4.2, -5.2],
    [-7.4, 0.4, 5.8, -4.8],
  ] as const) {
    const strip = new THREE.Mesh(new THREE.PlaneGeometry(width, length), reflectionMaterial);
    strip.rotation.x = -Math.PI / 2;
    strip.position.set(x, -0.245, z);
    scene.add(strip);
  }

  // Bridge deck and posts.
  const bridge = new THREE.Group();
  const total = 21;
  for (let index = 0; index < total; index += 1) {
    const z = DECK_START - index * ((DECK_START * 2) / (total - 1));
    const slope = (deckY(z + 0.1) - deckY(z - 0.1)) / 0.2;
    box(bridge, 2.3, 0.07, 0.53, 0, deckY(z) - 0.035, z, paper, Math.atan(slope));
  }
  for (const side of [-1, 1]) {
    for (let index = 0; index < 12; index += 1) {
      const z = DECK_START - index * ((DECK_START * 2) / 11);
      const y = deckY(z);
      box(bridge, 0.055, 0.86, 0.055, 1.04 * side, y + 0.4, z, ink);
      box(bridge, 0.09, 0.05, 0.09, 1.04 * side, y + 0.84, z, leather);
      const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.03, 10, 8), amber);
      bulb.position.set(1.04 * side, y + 0.9, z);
      bulb.scale.setScalar(0.001);
      bridge.add(bulb);
      bulbs.push({ mesh: bulb, delay: 0.5 + (DECK_START - z) * 0.09, lit: false, width: 0.03, height: 0.036, depth: 0.03 });
    }
  }
  for (const side of [-1, 1]) {
    for (const level of [0.42, 0.76]) {
      for (let index = 0; index < 11; index += 1) {
        const zA = DECK_START - index * ((DECK_START * 2) / 11);
        const zB = DECK_START - (index + 1) * ((DECK_START * 2) / 11);
        tube(
          bridge,
          new THREE.Vector3(1.04 * side, deckY(zA) + level, zA),
          new THREE.Vector3(1.04 * side, deckY(zB) + level, zB),
          0.012,
          ink,
        );
      }
    }
  }
  scene.add(bridge);

  // Paper city on the far bank.
  const city = new THREE.Group();
  const buildings: Array<[number, number, number, number]> = [
    [-13.2, 3.0, 2.0, 1.8],
    [-10.6, 4.4, 1.8, 1.7],
    [-8.0, 3.4, 2.0, 1.9],
    [-5.4, 5.2, 1.8, 1.6],
    [-3.0, 2.8, 2.1, 1.8],
    [0.4, 4.8, 1.9, 2.0],
    [3.0, 3.6, 2.2, 1.7],
    [5.6, 6.0, 1.8, 1.9],
    [8.2, 4.2, 2.0, 1.8],
    [11.0, 5.4, 1.9, 2.0],
    [13.6, 3.2, 2.1, 1.7],
  ];
  const windowGeometry = new THREE.BoxGeometry(1, 1, 1);

  buildings.forEach(([x, height, width, depth], index) => {
    const z = -9.4 - (index % 3) * 0.95;
    box(city, width, height, depth, x, height / 2 + 0.12, z, index % 2 ? ink : inkSoft);
    box(city, width * 1.08, 0.07, depth * 1.08, x, height + 0.16, z, leather);
    if (index % 2 === 0) {
      const gable = new THREE.Mesh(new THREE.ConeGeometry(width * 0.72, 0.62, 4), leather);
      gable.position.set(x, height + 0.5, z);
      gable.rotation.y = Math.PI / 4;
      gable.scale.z = depth / width;
      gable.castShadow = true;
      city.add(gable);
    }
    const rows = Math.max(2, Math.floor(height / 0.7));
    const columns = width < 2 ? 2 : 3;
    for (let row = 0; row < rows; row += 1) {
      for (let column = 0; column < columns; column += 1) {
        const wx = x - width * 0.32 + column * width * 0.32;
        const wy = 0.62 + row * 0.58;
        if (wy > height - 0.24) continue;
        const lit = (row * 3 + column + index) % 11 === 0;
        const glint = new THREE.Mesh(windowGeometry, lit ? dimWindow : hotWindow);
        glint.scale.set(lit ? 1 : 0.001, lit ? 1 : 0.001, lit ? 1 : 0.001);
        glint.position.set(wx, wy, z + depth / 2 + 0.014);
        city.add(glint);
        windows.push({
          mesh: glint,
          delay: 0.62 + Math.abs(wx) * 0.035 + row * 0.025 + column * 0.03,
          lit,
          width: 0.12,
          height: 0.2,
          depth: 0.02,
        });
      }
    }
  });

  // Clock tower.
  box(city, 1.4, 8.2, 1.4, -6.7, 4.22, -10.4, ink);
  const clockCap = new THREE.Mesh(new THREE.ConeGeometry(1.2, 1.6, 4), leather);
  clockCap.position.set(-6.7, 9.12, -10.4);
  clockCap.rotation.y = Math.PI / 4;
  clockCap.castShadow = true;
  city.add(clockCap);
  const clockFace = new THREE.Mesh(
    new THREE.CircleGeometry(0.55, 40),
    new THREE.MeshBasicMaterial({ color: 0xffe6b8, toneMapped: false }),
  );
  clockFace.position.set(-6.7, 7.1, -9.69);
  city.add(clockFace);
  const hand = new THREE.Mesh(new THREE.BoxGeometry(0.035, 0.36, 0.02), ink);
  hand.position.set(-6.7, 7.22, -9.67);
  city.add(hand);

  // Paper trees.
  for (const [x, scale] of [
    [-11.6, 1.0],
    [6.4, 0.9],
    [10.6, 1.15],
  ] as const) {
    const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 1.1 * scale, 7), ink);
    trunk.position.set(x, 0.66 * scale + 0.1, -7.0);
    trunk.castShadow = true;
    city.add(trunk);
    const crown = new THREE.Mesh(new THREE.ConeGeometry(0.58 * scale, 1.4 * scale, 9), inkSoft);
    crown.position.set(x, 1.55 * scale + 0.1, -7.0);
    crown.castShadow = true;
    city.add(crown);
  }
  scene.add(city);

  // Fireflies.
  const fireflies: THREE.Mesh[] = [];
  const flyMaterial = new THREE.MeshBasicMaterial({
    color: 0xb8ff66,
    toneMapped: false,
    transparent: true,
    opacity: 0.9,
    blending: THREE.AdditiveBlending,
    depthWrite: false,
  });
  for (let index = 0; index < 28; index += 1) {
    const fly = new THREE.Mesh(new THREE.SphereGeometry(0.016, 6, 5), flyMaterial);
    const x = Math.sin(index * 12.9) * 6.2;
    const y = 0.55 + ((index * 37) % 100) / 100 * 2.1;
    const z = Math.cos(index * 4.3) * 5.4;
    fly.position.set(x, y, z);
    fly.userData.seed = index * 0.7;
    fly.userData.home = new THREE.Vector3(x, y, z);
    scene.add(fly);
    fireflies.push(fly);
  }

  // The lantern's own glow lives in the scene graph once the rig arrives.
  let hemi: THREE.HemisphereLight | null = null;
  let key: THREE.DirectionalLight | null = null;
  let rim: THREE.DirectionalLight | null = null;
  let fill: THREE.DirectionalLight | null = null;
  scene.traverse((object) => {
    if (object instanceof THREE.HemisphereLight) hemi = object;
    else if (object instanceof THREE.DirectionalLight) {
      if (!key) key = object;
      else if (!rim) rim = object;
      else if (!fill) fill = object;
    }
  });

  return { windows, bulbs, skyPaint, moon, moonHalo, hotWindow, dimWindow, hemi, key, rim, fill, fireflies };
}

export function keeperLabMarkup(project: Project): string {
  const poster = project.poster
    ? `<img class="lab-fallback" src="${asset(project.poster)}" alt="The lantern keeper raising his lantern on a paper bridge at dusk" />`
    : "";
  return `
  <section class="lab-section" id="lab" aria-labelledby="lab-title">
    <div class="section-head">
      <div><p class="eyebrow">Take the controls</p><h2 id="lab-title">Walk the bridge yourself.</h2></div>
      <p class="section-note">The exported rig stands on a live paper bridge. Scrub the walk, turn dusk into night, then raise the lantern and watch the city wake.</p>
    </div>
    <div class="lab-stage lab-stage-keeper" data-lab-stage>
      <div class="lab-viewer" data-lab-viewer></div>
      ${poster}
      <div class="lab-live mono"><span class="live-dot" aria-hidden="true"></span>Keeper Diorama / live glTF</div>
      <div class="lab-count mono" data-light-readout>Light / dark</div>
      <div class="lab-loading mono" data-lab-loading>Building the bridge</div>
    </div>
    <div class="lab-controls" role="group" aria-label="Keeper diorama controls">
      <label class="lab-slider mono">
        <span>Walk</span>
        <input type="range" min="0" max="100" value="12" step="0.5" data-scrub aria-label="Walk cycle position" />
        <output data-scrub-out>04</output>
      </label>
      <label class="lab-slider mono">
        <span>Hour</span>
        <input type="range" min="0" max="100" value="30" step="1" data-dusk aria-label="Time of evening" />
        <output data-dusk-out>Dusk</output>
      </label>
      <div class="lab-buttons">
        <button type="button" class="lab-toggle mono" data-walk aria-pressed="false">Play walk</button>
        <button type="button" class="lab-toggle mono" data-light aria-pressed="false">Light the lantern</button>
        <button type="button" class="lab-toggle mono" data-preset="bridge">Bridge</button>
        <button type="button" class="lab-toggle mono" data-preset="keeper">Keeper</button>
        <button type="button" class="lab-toggle mono" data-preset="city">City</button>
        <button type="button" class="lab-toggle mono" data-photo>Take a still</button>
      </div>
    </div>
    <p class="lab-hint mono"><span class="hint-pointer">Drag to orbit the diorama, scroll to zoom. Raise the lantern and the windows answer one by one.</span><span class="hint-touch">Drag to orbit, pinch to zoom. Raise the lantern and the windows answer one by one.</span></p>
  </section>`;
}

export function mountKeeperLab(section: HTMLElement, project: Project): () => void {
  if (!project.model) return () => undefined;
  const host = section.querySelector<HTMLElement>("[data-lab-viewer]");
  const stageEl = section.querySelector<HTMLElement>("[data-lab-stage]");
  if (!host || !stageEl) return () => undefined;

  const loading = section.querySelector<HTMLElement>("[data-lab-loading]");
  const lightReadout = section.querySelector<HTMLElement>("[data-light-readout]");
  const scrub = section.querySelector<HTMLInputElement>("[data-scrub]");
  const scrubOut = section.querySelector<HTMLOutputElement>("[data-scrub-out]");
  const dusk = section.querySelector<HTMLInputElement>("[data-dusk]");
  const duskOut = section.querySelector<HTMLOutputElement>("[data-dusk-out]");
  const walkButton = section.querySelector<HTMLButtonElement>("[data-walk]");
  const lightButton = section.querySelector<HTMLButtonElement>("[data-light]");
  const photoButton = section.querySelector<HTMLButtonElement>("[data-photo]");
  const presetButtons = Array.from(section.querySelectorAll<HTMLButtonElement>("[data-preset]"));

  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  let stage: Stage | null = null;
  let diorama: Diorama | null = null;
  let model: THREE.Group | null = null;
  let mixer: THREE.AnimationMixer | null = null;
  let walkAction: THREE.AnimationAction | null = null;
  let liftAction: THREE.AnimationAction | null = null;
  let walkClip: THREE.AnimationClip | null = null;
  let playing = false;
  let lit = false;
  let lightLevel = 0;
  let wakeTime = 0;
  let tween: {
    from: THREE.Vector3;
    to: THREE.Vector3;
    fromTarget: THREE.Vector3;
    toTarget: THREE.Vector3;
    elapsed: number;
    duration: number;
  } | null = null;
  let scrubbing = false;
  let disposed = false;

  let lanternNode: THREE.Object3D | null = null;
  let lanternLight: THREE.PointLight | null = null;
  let lanternSpot: THREE.SpotLight | null = null;
  let beam: THREE.Mesh | null = null;
  let halo: THREE.Sprite | null = null;
  let glassMaterial: THREE.MeshStandardMaterial | null = null;
  const glassBase = { emissiveIntensity: 1 };

  const tmpVec = new THREE.Vector3();
  const tmpVecB = new THREE.Vector3();
  const tmpColor = new THREE.Color();

  function updateUI() {
    walkButton?.setAttribute("aria-pressed", String(playing));
    lightButton?.setAttribute("aria-pressed", String(lit));
    if (lightReadout) lightReadout.textContent = lit ? "Light / city waking" : "Light / dark";
    if (walkButton) walkButton.textContent = playing ? "Pause walk" : "Play walk";
  }

  function updateDusk(value: number) {
    if (!diorama) return;
    diorama.skyPaint(value);
    const night = clamp(value, 0, 1);
    if (diorama.hemi) diorama.hemi.intensity = 0.95 - 0.55 * night;
    if (diorama.key) diorama.key.intensity = 2.9 - 1.35 * night;
    if (diorama.rim) diorama.rim.intensity = 1.7 - 0.8 * night;
    if (diorama.fill) diorama.fill.intensity = 0.52 - 0.2 * night;
    if (stage) stage.scene.environmentIntensity = 0.5 - 0.28 * night;
    diorama.hotWindow.color.setHSL(0.085, 0.82, 0.52 + 0.2 * night);
    tmpColor.setRGB(1, 0.93, 0.8).multiplyScalar(0.7 + 0.3 * night);
    (diorama.moon.material as THREE.MeshBasicMaterial).color.copy(tmpColor);
    diorama.moonHalo.material.opacity = 0.44 + 0.25 * night;
    if (duskOut) duskOut.textContent = value < 0.36 ? "Dusk" : value < 0.72 ? "Evening" : "Night";
  }

  function setWalk(next: boolean) {
    if (!walkAction) return;
    if (next && lit) setLit(false);
    playing = next;
    walkAction.paused = !playing;
    if (playing) walkAction.fadeIn(0.25).play();
    else walkAction.fadeOut(0.2);
    updateUI();
  }

  function setLit(next: boolean) {
    if (!mixer || !walkAction || !liftAction) return;
    if (next === lit) return;
    lit = next;
    playing = false;
    walkAction.paused = true;
    if (lit) {
      wakeTime = 0;
      walkAction.fadeOut(0.3);
      liftAction.reset();
      liftAction.setLoop(THREE.LoopOnce, 1);
      liftAction.clampWhenFinished = true;
      liftAction.fadeIn(0.3).play();
    } else {
      liftAction.fadeOut(0.35);
      walkAction.fadeIn(0.35).play();
    }
    updateUI();
  }

  function applyPreset(name: string) {
    if (!stage) return;
    const presets: Record<string, [THREE.Vector3, THREE.Vector3]> = {
      bridge: [new THREE.Vector3(4.7, 2.9, 6.2), new THREE.Vector3(0, 1.0, -0.7)],
      keeper: [new THREE.Vector3(2.1, 1.9, 3.6), new THREE.Vector3(0, 1.35, 0.3)],
      city: [new THREE.Vector3(1.4, 2.7, 2.6), new THREE.Vector3(0, 2.5, -8.6)],
    };
    const preset = presets[name];
    if (!preset) return;
    if (reduced) {
      stage.camera.position.copy(preset[0]);
      stage.controls.target.copy(preset[1]);
      stage.controls.update();
      return;
    }
    tween = {
      from: stage.camera.position.clone(),
      to: preset[0].clone(),
      fromTarget: stage.controls.target.clone(),
      toTarget: preset[1].clone(),
      elapsed: 0,
      duration: 1.15,
    };
  }

  async function takeStill() {
    if (!stage) return;
    stage.renderer.render(stage.scene, stage.camera);
    try {
      await document.fonts.ready;
    } catch {
      // System faces are a fine fallback.
    }
    const still = document.createElement("canvas");
    still.width = 1600;
    still.height = 1040;
    const out = still.getContext("2d");
    if (!out) return;
    out.fillStyle = "#100d16";
    out.fillRect(0, 0, still.width, still.height);
    const source = stage.renderer.domElement;
    const scale = Math.max(1600 / source.width, 900 / source.height);
    const drawW = source.width * scale;
    const drawH = source.height * scale;
    out.drawImage(source, (1600 - drawW) / 2, (900 - drawH) / 2, drawW, drawH);

    out.strokeStyle = "rgba(246,241,230,0.22)";
    out.lineWidth = 1;
    out.beginPath();
    out.moveTo(0, 900);
    out.lineTo(still.width, 900);
    out.stroke();

    out.fillStyle = "#f6f1e6";
    out.font = "600 46px 'Fraunces Variable', Georgia, serif";
    out.fillText("Lantern Keeper", 48, 972);
    out.fillStyle = "#a9ab9c";
    out.font = "400 17px 'IBM Plex Mono', monospace";
    out.fillText("KEEPER DIORAMA / LIVE GLTF RIG", 49, 1006);
    out.textAlign = "right";
    out.fillStyle = "#b7e05a";
    out.beginPath();
    out.arc(1348, 960, 7, 0, TAU);
    out.fill();
    out.fillStyle = "#f6f1e6";
    out.font = "400 17px 'IBM Plex Mono', monospace";
    out.fillText("KONE STUDIO / 2026", 1552, 966);
    out.textAlign = "left";

    still.toBlob((blob) => {
      if (!blob) return;
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "lantern-keeper-diorama.png";
      link.click();
      window.setTimeout(() => URL.revokeObjectURL(url), 4000);
    }, "image/png");
  }

  void (async () => {
    try {
      stage = createStage(host, {
        target: new THREE.Vector3(0, 1.05, 0),
        direction: new THREE.Vector3(0.58, 0.24, 0.78),
        distance: 7.3,
        fov: 34,
        zoom: true,
        minDistance: 4.2,
        maxDistance: 13,
        shadow: 0,
      });

      // The shared stage's floor disc sits above the river.
      stage.scene.traverse((object) => {
        if (object instanceof THREE.Mesh && object.material instanceof THREE.ShadowMaterial) object.visible = false;
      });

      const moonGlow = glowTexture("255,230,190", "255,190,130", "255,150,90");
      const lanternGlow = glowTexture();
      diorama = buildDiorama(stage.scene, moonGlow);
      updateDusk(Number(dusk?.value ?? 30) / 100);

      const gltf = await new GLTFLoader().loadAsync(asset(project.model!));
      if (disposed) {
        stage.dispose();
        stage = null;
        return;
      }

      model = gltf.scene;
      model.traverse((object) => {
        if (!(object instanceof THREE.Mesh)) return;
        object.castShadow = true;
        object.receiveShadow = false;
        const materials = Array.isArray(object.material) ? object.material : [object.material];
        for (const material of materials) {
          if ("envMapIntensity" in material) {
            (material as THREE.MeshStandardMaterial).envMapIntensity = 0.7;
          }
        }
      });
      model.position.set(0, deckY(0.5) + 0.005, 0.5);
      model.rotation.y = -0.16;
      stage.scene.add(model);

      lanternNode = model.getObjectByName("lantern") ?? model.getObjectByName("hand_L") ?? null;
      const glass = model.getObjectByName("LanternGlass");
      if (glass instanceof THREE.Mesh) {
        const material = glass.material;
        if (material instanceof THREE.MeshStandardMaterial) {
          glassMaterial = material;
          glassBase.emissiveIntensity = material.emissiveIntensity;
        }
      }

      lanternLight = new THREE.PointLight(0xc4ff7a, 0, 4.6, 2);
      stage.scene.add(lanternLight);
      lanternSpot = new THREE.SpotLight(0xd2ff8a, 0, 7, Math.PI / 5.4, 0.8, 1.4);
      lanternSpot.castShadow = false;
      stage.scene.add(lanternSpot);
      stage.scene.add(lanternSpot.target);

      beam = new THREE.Mesh(
        new THREE.ConeGeometry(0.42, 1.3, 32, 1, true),
        new THREE.MeshBasicMaterial({
          color: 0xc8ff7a,
          transparent: true,
          opacity: 0,
          blending: THREE.AdditiveBlending,
          depthWrite: false,
          side: THREE.DoubleSide,
          toneMapped: false,
        }),
      );
      // Tip down at the lantern glass, widening upward into the night.
      beam.rotation.set(Math.PI + 0.09, 0, 0);
      beam.visible = false;
      stage.scene.add(beam);

      halo = new THREE.Sprite(
        new THREE.SpriteMaterial({
          map: lanternGlow,
          color: 0xd8ff9a,
          transparent: true,
          opacity: 0,
          blending: THREE.AdditiveBlending,
          depthWrite: false,
          toneMapped: false,
        }),
      );
      halo.scale.set(1.15, 1.15, 1);
      stage.scene.add(halo);

      mixer = new THREE.AnimationMixer(model);
      const clips = gltf.animations;
      walkClip = THREE.AnimationClip.findByName(clips, "Walk") ?? clips[0] ?? null;
      const liftClip = THREE.AnimationClip.findByName(clips, "Lift");
      if (!walkClip) throw new Error("The keeper rig shipped without a walk clip");
      walkAction = mixer.clipAction(walkClip);
      walkAction.play();
      walkAction.paused = true;
      walkAction.time = walkClip.duration * 0.12;
      if (liftClip) {
        liftAction = mixer.clipAction(liftClip);
        liftAction.setLoop(THREE.LoopOnce, 1);
        liftAction.clampWhenFinished = true;
      }

      updateUI();
      stageEl.classList.add("is-live");
      loading?.remove();

      stage.addFrame((delta, elapsed) => {
        if (!stage || !diorama) return;

        mixer?.update(delta);

        if (playing && walkAction && walkClip && !scrubbing) {
          const progress = (walkAction.time / walkClip.duration) * 100;
          if (scrub) scrub.value = String(progress);
          if (scrubOut) scrubOut.textContent = String(Math.round(progress * 0.32)).padStart(2, "0");
        }

        const target = lit ? 1 : 0;
        lightLevel += (target - lightLevel) * Math.min(1, delta * (lit ? 2.3 : 3.2));
        if (lit) wakeTime += delta;

        const wake = wakeTime;
        for (const item of diorama.windows) {
          const local = item.lit ? 1 : clamp((wake - item.delay) / 0.5, 0, 1);
          const level = item.lit ? 1 : local;
          item.mesh.scale.set(item.width * level, item.height * level, item.depth * level);
          const want = item.lit && !lit ? diorama.dimWindow : diorama.hotWindow;
          if (item.mesh.material !== want) item.mesh.material = want;
        }
        for (const item of diorama.bulbs) {
          const local = clamp((wake - item.delay) / 0.45, 0, 1);
          item.mesh.scale.setScalar(0.001 + 0.999 * local);
        }

        if (glassMaterial) {
          glassMaterial.emissiveIntensity = glassBase.emissiveIntensity + lightLevel * 1.7;
        }

        if (lanternNode) {
          lanternNode.getWorldPosition(tmpVec);
          if (lanternLight) {
            lanternLight.position.copy(tmpVec);
            lanternLight.intensity = lightLevel * 2.3;
          }
          if (halo) {
            halo.position.copy(tmpVec);
            halo.position.y -= 0.17;
            const haloScale = 0.5 + 0.42 * lightLevel;
            halo.scale.set(haloScale, haloScale, 1);
            (halo.material as THREE.SpriteMaterial).opacity = 0.55 * lightLevel;
            halo.visible = lightLevel > 0.02;
          }
          if (beam) {
            beam.position.copy(tmpVec);
            beam.position.y += 0.6;
            beam.visible = lightLevel > 0.02;
            (beam.material as THREE.MeshBasicMaterial).opacity = 0.16 * lightLevel;
            beam.scale.setScalar(0.55 + 0.45 * lightLevel);
          }
          if (lanternSpot) {
            lanternSpot.position.copy(tmpVec);
            lanternSpot.position.y -= 0.04;
            lanternSpot.target.position.copy(tmpVec).add(tmpVecB.set(0.05, -3.2, -0.55));
            lanternSpot.target.updateMatrixWorld();
            lanternSpot.intensity = lightLevel * 26;
          }
        }

        if (!reduced) {
          for (const fly of diorama.fireflies) {
            const home = fly.userData.home as THREE.Vector3;
            const seed = fly.userData.seed as number;
            fly.position.set(
              home.x + 0.28 * Math.sin(elapsed * 0.6 + seed),
              home.y + 0.16 * Math.sin(elapsed * 0.9 + seed * 1.7),
              home.z + 0.22 * Math.cos(elapsed * 0.5 + seed),
            );
          }
        }

        if (tween) {
          tween.elapsed += delta;
          const t = clamp(tween.elapsed / tween.duration, 0, 1);
          const ease = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
          stage.camera.position.lerpVectors(tween.from, tween.to, ease);
          stage.controls.target.lerpVectors(tween.fromTarget, tween.toTarget, ease);
          stage.controls.update();
          if (t >= 1) tween = null;
        }
      });

      stage.controls.addEventListener("start", () => {
        tween = null;
      });

      updateUI();
    } catch (error) {
      console.warn("Keeper diorama unavailable", error);
      if (loading) loading.textContent = "3D unavailable";
      stage?.dispose();
      stage = null;
    }
  })();

  scrub?.addEventListener("input", () => {
    if (!walkAction || !walkClip) return;
    if (lit) setLit(false);
    playing = false;
    walkAction.paused = true;
    walkAction.time = (Number(scrub.value) / 100) * walkClip.duration;
    if (scrubOut) scrubOut.textContent = String(Math.round(Number(scrub.value) * 0.32)).padStart(2, "0");
    updateUI();
  });
  scrub?.addEventListener("pointerdown", () => {
    scrubbing = true;
  });
  const endScrub = () => {
    scrubbing = false;
  };
  scrub?.addEventListener("pointerup", endScrub);
  scrub?.addEventListener("pointercancel", endScrub);
  scrub?.addEventListener("blur", endScrub);

  dusk?.addEventListener("input", () => updateDusk(Number(dusk.value) / 100));
  walkButton?.addEventListener("click", () => setWalk(!playing));
  lightButton?.addEventListener("click", () => setLit(!lit));
  photoButton?.addEventListener("click", () => void takeStill());
  for (const button of presetButtons) {
    button.addEventListener("click", () => applyPreset(button.dataset.preset ?? ""));
  }

  if (reduced) {
    const hint = section.querySelector(".lab-hint");
    if (hint) hint.textContent = "Reduced motion is on. The diorama holds still until you move it. Drag to orbit, use the walk slider, and light the lantern when you are ready.";
  }

  return () => {
    disposed = true;
    mixer?.stopAllAction();
    stage?.dispose();
    stage = null;
    model = null;
    diorama = null;
  };
}
