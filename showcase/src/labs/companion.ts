/**
 * Companion Lab: the exported rig, live in three.js. Cursor-guided head
 * tracking, three moods, a turntable spin, reset and a downloadable still.
 */

import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import type { Project } from "../projects.generated";
import { createStage, type Stage } from "./stage";

const BASE = import.meta.env.BASE_URL;
const TAU = Math.PI * 2;

type Mood = "scan" | "sleep" | "hi";

const MOOD_LABEL: Record<Mood, string> = {
  scan: "scanning",
  sleep: "sleeping",
  hi: "waving",
};

const asset = (path: string) => `${BASE}${path.replace(/^\/+/, "")}`;

export function companionLabMarkup(project: Project): string {
  const poster = project.poster ? `<img class="lab-fallback" src="${asset(project.poster)}" alt="The companion floating above its dark disc in a cream studio" />` : "";
  return `
  <section class="lab-section" id="lab" aria-labelledby="lab-title">
    <div class="section-head">
      <div><p class="eyebrow">Take the controls</p><h2 id="lab-title">Say hello to the companion.</h2></div>
      <p class="section-note">The exported rig runs live in the browser. Guide its gaze with your cursor, pick a mood, or orbit the little stage.</p>
    </div>
    <div class="lab-stage lab-stage-companion" data-lab-stage>
      <div class="lab-viewer" data-lab-viewer></div>
      ${poster}
      <div class="lab-live mono"><span class="live-dot" aria-hidden="true"></span>Companion Lab / live glTF</div>
      <div class="lab-count mono" data-mood-readout>Mood / scanning</div>
      <div class="lab-loading mono" data-lab-loading>Loading rig</div>
    </div>
    <div class="lab-controls" role="group" aria-label="Companion lab controls">
      <div class="lab-buttons lab-moods" role="group" aria-label="Companion moods">
        <span class="mono lab-label">Mood</span>
        <button type="button" class="lab-toggle mono" data-mood="hi">Say hi</button>
        <button type="button" class="lab-toggle mono" data-mood="scan" aria-pressed="true">Scan</button>
        <button type="button" class="lab-toggle mono" data-mood="sleep">Sleep</button>
      </div>
      <div class="lab-buttons">
        <button type="button" class="lab-toggle mono" data-spin aria-pressed="false">Spin</button>
        <button type="button" class="lab-toggle mono" data-reset>Reset</button>
        <button type="button" class="lab-toggle mono" data-photo>Take a still</button>
      </div>
    </div>
    <p class="lab-hint mono">Move your cursor across the stage and the companion follows. Drag to orbit, scroll to zoom.</p>
  </section>`;
}

type EyeMaterial = { material: THREE.MeshStandardMaterial; base: number };

function collectEyeMaterials(mesh: THREE.Mesh): EyeMaterial[] {
  const found: EyeMaterial[] = [];
  const materials = (Array.isArray(mesh.material) ? mesh.material : [mesh.material]).map((item) => item.clone());
  mesh.material = Array.isArray(mesh.material) ? materials : materials[0];
  for (const material of materials) {
    if (material instanceof THREE.MeshStandardMaterial) {
      found.push({ material, base: material.emissiveIntensity });
    }
  }
  return found;
}

export function mountCompanionLab(section: HTMLElement, project: Project): () => void {
  if (!project.model) return () => undefined;
  const hostNode = section.querySelector<HTMLElement>("[data-lab-viewer]");
  const stageNode = section.querySelector<HTMLElement>("[data-lab-stage]");
  if (!hostNode || !stageNode) return () => undefined;
  const host: HTMLElement = hostNode;
  const stageEl: HTMLElement = stageNode;

  const readout = section.querySelector<HTMLElement>("[data-mood-readout]");
  const loading = section.querySelector<HTMLElement>("[data-lab-loading]");
  const moodButtons = Array.from(section.querySelectorAll<HTMLButtonElement>("[data-mood]"));
  const spinButton = section.querySelector<HTMLButtonElement>("[data-spin]");
  const resetButton = section.querySelector<HTMLButtonElement>("[data-reset]");
  const photoButton = section.querySelector<HTMLButtonElement>("[data-photo]");

  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  let stage: Stage | null = null;
  let model: THREE.Group | null = null;
  let mixer: THREE.AnimationMixer | null = null;
  let hiAction: THREE.AnimationAction | null = null;
  let mood: Mood = "scan";
  let hiActive = false;
  let spin = false;
  let disposed = false;

  let head: THREE.Object3D | null = null;
  let antenna: THREE.Object3D | null = null;
  let hover: THREE.Object3D | null = null;
  let body: THREE.Mesh | null = null;
  let armL: THREE.Object3D | null = null;
  let armR: THREE.Object3D | null = null;
  let elbowL: THREE.Object3D | null = null;
  let elbowR: THREE.Object3D | null = null;
  let scarf: THREE.Object3D | null = null;
  let eyeL: THREE.Object3D | null = null;
  let eyeR: THREE.Object3D | null = null;
  let rootNode: THREE.Object3D | null = null;
  const eyeMaterials: EyeMaterial[] = [];
  const base = {
    head: new THREE.Quaternion(),
    antenna: new THREE.Quaternion(),
    armL: new THREE.Quaternion(),
    armR: new THREE.Quaternion(),
    elbowL: new THREE.Quaternion(),
    elbowR: new THREE.Quaternion(),
    scarf: new THREE.Quaternion(),
    root: new THREE.Quaternion(),
    hoverY: 0,
    bodyScale: new THREE.Vector3(1, 1, 1),
  };

  let lookX = 0;
  let lookY = 0;
  let nextBlink = 2.8;
  let blinkLeft = 0;

  const tmpEuler = new THREE.Euler();
  const tmpQuat = new THREE.Quaternion();

  const clamp = (value: number, low: number, high: number) => Math.max(low, Math.min(high, value));

  function updateUI() {
    const activeKey: Mood = hiActive ? "hi" : mood;
    for (const button of moodButtons) {
      button.setAttribute("aria-pressed", String(button.dataset.mood === activeKey));
    }
    if (readout) {
      readout.textContent = `Mood / ${MOOD_LABEL[activeKey]}${spin && !reduced ? " / spin" : ""}`;
    }
    spinButton?.setAttribute("aria-pressed", String(spin && !reduced));
  }

  function stopHi() {
    hiActive = false;
    if (hiAction) hiAction.stop();
    if (rootNode) rootNode.quaternion.copy(base.root);
  }

  function playHi() {
    if (!mixer || !hiAction) {
      if (reduced) {
        hiActive = true;
        mood = "hi";
        updateUI();
      }
      return;
    }
    stopHi();
    mood = "hi";
    hiActive = true;
    if (!reduced) {
      hiAction.reset();
      hiAction.setLoop(THREE.LoopOnce, 1);
      hiAction.clampWhenFinished = false;
      hiAction.play();
    }
    updateUI();
  }

  function selectMood(next: Mood) {
    if (next === "hi") {
      playHi();
      return;
    }
    stopHi();
    mood = next;
    updateUI();
  }

  function resetAll() {
    stopHi();
    mood = "scan";
    spin = false;
    lookX = 0;
    lookY = 0;
    if (model) model.rotation.y = 0;
    stage?.resetView();
    updateUI();
  }

  function applyPose(delta: number, elapsed: number) {
    if (!model) return;

    if (spin && !reduced) model.rotation.y += delta * 0.45;

    if (hiActive && !reduced) {
      mixer?.update(delta);
      return;
    }

    const bodyYaw = spin ? Math.atan2(Math.sin(model.rotation.y), Math.cos(model.rotation.y)) : 0;
    let targetX = 0.30 * Math.sin(elapsed * 0.55);
    let targetY = 0.05 * Math.sin(elapsed * 0.9);
    if (stage?.pointer.active && !reduced) {
      targetX = clamp(stage.pointer.x * 0.45 - bodyYaw, -0.62, 0.62);
      targetY = clamp(-stage.pointer.y * 0.22, -0.2, 0.2);
    }

    if (mood === "sleep") {
      targetX = 0.07;
      targetY = 0.42;
    }
    if (hiActive && reduced) {
      targetX = 0.2;
      targetY = 0.02;
    }

    const ease = reduced ? 1 : Math.min(1, delta * 6.5);
    lookX += (targetX - lookX) * ease;
    lookY += (targetY - lookY) * ease;

    if (head) {
      const roll = hiActive && reduced ? 0.12 : mood === "sleep" ? 0.06 : 0.02 * Math.sin(elapsed * 0.7);
      head.quaternion
        .copy(base.head)
        .multiply(tmpQuat.setFromEuler(tmpEuler.set(lookY, lookX, roll, "YXZ")));
    }
    if (antenna) {
      const bounce = reduced ? 0 : 0.06 * Math.sin(elapsed * 1.7);
      antenna.quaternion
        .copy(base.antenna)
        .multiply(tmpQuat.setFromEuler(tmpEuler.set(bounce + lookY * 0.5, 0.05 * Math.sin(elapsed * 1.1) + lookX * 0.3, 0)));
    }
    if (hover) {
      const low = mood === "sleep" ? -0.16 : 0;
      const bob = reduced ? 0 : 0.045 * Math.sin(elapsed * 1.9);
      hover.position.y = base.hoverY + low + bob;
    }
    if (body) {
      const breath = reduced ? 0 : 0.012 * Math.sin(elapsed * 1.9 + 0.4);
      body.scale.set(base.bodyScale.x + breath, base.bodyScale.y + breath * 0.8, base.bodyScale.z - breath);
    }
    if (armL && armR) {
      const asleep = mood === "sleep";
      armL.rotation.set(0.02 * Math.sin(elapsed * 0.9 + 1.1), 0.18 + (asleep ? 0.06 : 0.02), 0);
      armR.rotation.set(0.02 * Math.sin(elapsed * 0.9), -0.18 - (asleep ? 0.06 : 0.02), 0);
      if (hiActive && reduced) {
        armR.rotation.set(0, -1.95, -0.28);
        if (elbowR) elbowR.rotation.set(0, -1.05, 0);
      } else {
        if (elbowR) elbowR.rotation.set(0, -0.08, 0);
        if (elbowL) elbowL.rotation.set(0, 0.08, 0);
      }
    }
    if (scarf) {
      scarf.rotation.set(
        reduced ? 0 : 0.05 * Math.sin(elapsed * 1.1 + 0.2),
        0,
        reduced ? 0 : 0.07 * Math.sin(elapsed * 1.6 + 1.4),
      );
    }

    updateEyes(mood === "sleep" ? 0.25 : 1, delta, elapsed);

    if (hiActive && !reduced) mixer?.update(delta);
  }

  function updateEyes(glow: number, delta: number, elapsed: number) {
    let openness = 1;
    if (mood === "sleep") {
      openness = 0.12;
    } else if (!reduced) {
      if (elapsed > nextBlink) {
        blinkLeft = 0.13;
        nextBlink = elapsed + 2.6 + Math.random() * 2.6;
      }
      blinkLeft = Math.max(0, blinkLeft - delta);
      if (blinkLeft > 0) openness = 0.14;
    }
    if (eyeL) eyeL.scale.y = openness;
    if (eyeR) eyeR.scale.y = openness;
    const factor = reduced && mood !== "sleep" ? 1 : glow;
    for (const entry of eyeMaterials) {
      entry.material.emissiveIntensity = entry.base * factor;
    }
  }

  async function takeStill() {
    if (!stage) return;
    stage.renderer.render(stage.scene, stage.camera);
    try {
      await document.fonts.ready;
    } catch {
      // The still exports with system faces if the web fonts are slow.
    }
    const still = document.createElement("canvas");
    still.width = 1600;
    still.height = 1000;
    const out = still.getContext("2d");
    if (!out) return;
    out.fillStyle = "#f6f1e6";
    out.fillRect(0, 0, still.width, still.height);
    const source = stage.renderer.domElement;
    const scale = Math.max(1600 / source.width, 900 / source.height);
    const drawW = source.width * scale;
    const drawH = source.height * scale;
    out.drawImage(source, (1600 - drawW) / 2, (900 - drawH) / 2, drawW, drawH);

    out.strokeStyle = "rgba(24,21,18,0.18)";
    out.lineWidth = 1;
    out.beginPath();
    out.moveTo(0, 900);
    out.lineTo(still.width, 900);
    out.stroke();

    out.fillStyle = "#181512";
    out.font = "600 46px 'Fraunces Variable', Georgia, serif";
    out.fillText("Companion", 48, 968);
    out.fillStyle = "#73756c";
    out.font = "400 17px 'IBM Plex Mono', monospace";
    out.fillText("COMPANION LAB / LIVE GLTF RIG", 49, 1000);
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
      link.download = "companion-lab.png";
      link.click();
      window.setTimeout(() => URL.revokeObjectURL(url), 4000);
    }, "image/png");
  }

  function buildSet(target: THREE.Scene) {
    const floor = new THREE.Mesh(
      new THREE.CircleGeometry(20, 96),
      new THREE.MeshStandardMaterial({ color: 0xefe3ce, roughness: 0.96, metalness: 0 }),
    );
    floor.rotation.x = -Math.PI / 2;
    floor.position.y = -0.002;
    floor.receiveShadow = true;
    target.add(floor);

    const disc = new THREE.Mesh(
      new THREE.CylinderGeometry(1.95, 1.95, 0.26, 128),
      new THREE.MeshStandardMaterial({ color: 0x0b0a0e, roughness: 0.22, metalness: 0.35 }),
    );
    disc.position.y = 0.13;
    disc.castShadow = true;
    disc.receiveShadow = true;
    target.add(disc);

    const inlay = new THREE.Mesh(
      new THREE.TorusGeometry(1.62, 0.012, 8, 128),
      new THREE.MeshStandardMaterial({
        color: 0xffd9a8,
        emissive: 0xffb066,
        emissiveIntensity: 1.8,
        roughness: 0.4,
      }),
    );
    inlay.rotation.x = -Math.PI / 2;
    inlay.position.y = 0.268;
    target.add(inlay);

    const pool = new THREE.Mesh(
      new THREE.CircleGeometry(0.62, 64),
      new THREE.MeshBasicMaterial({
        color: 0xff8a4a,
        transparent: true,
        opacity: 0.22,
        blending: THREE.AdditiveBlending,
        depthWrite: false,
      }),
    );
    pool.rotation.x = -Math.PI / 2;
    pool.position.y = 0.269;
    target.add(pool);

    const glow = new THREE.PointLight(0xff8a4a, 6, 3, 2);
    glow.position.set(0, 0.55, 0);
    target.add(glow);
  }

  void (async () => {
    try {
      stage = createStage(host, {
        target: new THREE.Vector3(0, 1.55, 0),
        distance: 7.5,
        zoom: true,
        minDistance: 4.2,
        maxDistance: 13,
      });
      buildSet(stage.scene);

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
            (material as THREE.MeshStandardMaterial).envMapIntensity = 0.65;
          }
        }
      });
      stage.scene.add(model);

      head = model.getObjectByName("head") ?? null;
      antenna = model.getObjectByName("antenna") ?? null;
      hover = model.getObjectByName("Hover") ?? null;
      body = (model.getObjectByName("Body") as THREE.Mesh | undefined) ?? null;
      armL = model.getObjectByName("arm_l") ?? null;
      armR = model.getObjectByName("arm_r") ?? null;
      elbowL = model.getObjectByName("elbow_l") ?? null;
      elbowR = model.getObjectByName("elbow_r") ?? null;
      scarf = model.getObjectByName("scarf") ?? null;
      eyeL = model.getObjectByName("EyeL") ?? null;
      eyeR = model.getObjectByName("EyeR") ?? null;
      rootNode = model.getObjectByName("companion") ?? null;

      if (head) base.head.copy(head.quaternion);
      if (antenna) base.antenna.copy(antenna.quaternion);
      if (armL) base.armL.copy(armL.quaternion);
      if (armR) base.armR.copy(armR.quaternion);
      if (elbowL) base.elbowL.copy(elbowL.quaternion);
      if (elbowR) base.elbowR.copy(elbowR.quaternion);
      if (scarf) base.scarf.copy(scarf.quaternion);
      if (rootNode) base.root.copy(rootNode.quaternion);
      if (hover) base.hoverY = hover.position.y;
      if (body) base.bodyScale.copy(body.scale);
      if (eyeL instanceof THREE.Mesh) eyeMaterials.push(...collectEyeMaterials(eyeL));
      if (eyeR instanceof THREE.Mesh) eyeMaterials.push(...collectEyeMaterials(eyeR));

      mixer = new THREE.AnimationMixer(model);
      const clip = THREE.AnimationClip.findByName(gltf.animations, "Idle") ?? gltf.animations[0];
      if (clip) {
        hiAction = mixer.clipAction(clip);
        mixer.addEventListener("finished", (event) => {
          if (event.action !== hiAction) return;
          stopHi();
          mood = "scan";
          updateUI();
        });
      }

      stage.addFrame((delta, elapsed) => {
        if (hiActive && !reduced && mixer) {
          mixer.update(delta);
          updateEyes(1, delta, elapsed);
          return;
        }
        applyPose(delta, elapsed);
      });

      if (spinButton) {
        if (reduced) {
          spinButton.disabled = true;
          spinButton.title = "Spin follows your cursor when reduced motion is on";
        }
        spinButton.addEventListener("click", () => {
          if (reduced) return;
          spin = !spin;
          updateUI();
        });
      }

      stageEl.classList.add("is-live");
      loading?.remove();
      updateUI();
    } catch (error) {
      console.warn("Companion lab unavailable", error);
      if (loading) loading.textContent = "3D unavailable";
      stage?.dispose();
      stage = null;
    }
  })();

  for (const button of moodButtons) {
    button.addEventListener("click", () => {
      const next = button.dataset.mood as Mood | undefined;
      if (!next) return;
      selectMood(next);
    });
  }
  resetButton?.addEventListener("click", resetAll);
  photoButton?.addEventListener("click", () => void takeStill());
  if (reduced && spinButton) {
    spinButton.disabled = true;
    spinButton.title = "Spin is off with reduced motion";
  }

  return () => {
    disposed = true;
    stopHi();
    mixer?.stopAllAction();
    stage?.dispose();
    stage = null;
    model = null;
  };
}
