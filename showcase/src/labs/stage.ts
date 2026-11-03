/**
 * Shared three.js stage for the in-page labs: renderer, environment, lights,
 * orbit controls, resize, pointer tracking, a frame loop and teardown.
 */

import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";

export type StagePointer = { x: number; y: number; active: boolean };

export type StageOptions = {
  target?: THREE.Vector3;
  direction?: THREE.Vector3;
  distance?: number;
  fov?: number;
  zoom?: boolean;
  autoRotate?: boolean;
  minDistance?: number;
  maxDistance?: number;
  shadow?: number;
};

export type Stage = {
  renderer: THREE.WebGLRenderer;
  scene: THREE.Scene;
  camera: THREE.PerspectiveCamera;
  controls: OrbitControls;
  target: THREE.Vector3;
  pointer: StagePointer;
  addFrame: (callback: (delta: number, elapsed: number) => void) => void;
  resetView: () => void;
  dispose: () => void;
};

function disposeMaterial(material: THREE.Material | THREE.Material[]) {
  const list = Array.isArray(material) ? material : [material];
  for (const item of list) {
    const record = item as THREE.Material & Record<string, unknown>;
    for (const value of Object.values(record)) {
      if (value instanceof THREE.Texture) value.dispose();
    }
    item.dispose();
  }
}

export function createStage(host: HTMLElement, options: StageOptions = {}): Stage {
  const renderer = new THREE.WebGLRenderer({
    antialias: true,
    alpha: true,
    powerPreference: "high-performance",
    preserveDrawingBuffer: true,
  });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.02;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  renderer.domElement.className = "stage-canvas";
  renderer.domElement.setAttribute("aria-hidden", "true");
  host.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(options.fov ?? 32, 1, 0.1, 80);
  const target = options.target?.clone() ?? new THREE.Vector3(0, 1.55, 0);
  const direction = (options.direction?.clone() ?? new THREE.Vector3(0.52, 0.18, 0.84)).normalize();

  const pmrem = new THREE.PMREMGenerator(renderer);
  const environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  scene.environment = environment;
  scene.environmentIntensity = 0.45;
  pmrem.dispose();

  scene.add(new THREE.HemisphereLight(0xfff6e8, 0xcbbda2, 0.85));

  const key = new THREE.DirectionalLight(0xfff0d6, 2.9);
  key.position.set(5.5, 6.5, 6.5);
  key.castShadow = true;
  key.shadow.mapSize.set(2048, 2048);
  key.shadow.camera.left = -5;
  key.shadow.camera.right = 5;
  key.shadow.camera.top = 5;
  key.shadow.camera.bottom = -5;
  key.shadow.camera.near = 0.5;
  key.shadow.camera.far = 28;
  key.shadow.bias = -0.0004;
  key.shadow.normalBias = 0.02;
  key.shadow.radius = 2;
  scene.add(key);

  const rim = new THREE.DirectionalLight(0xff9b74, 1.7);
  rim.position.set(-5.5, 3.2, -4.5);
  scene.add(rim);

  const fill = new THREE.DirectionalLight(0xdbe6ff, 0.5);
  fill.position.set(-3.5, 2.2, 5.5);
  scene.add(fill);

  const shadowFloor = new THREE.Mesh(
    new THREE.CircleGeometry(8, 64),
    new THREE.ShadowMaterial({ opacity: options.shadow ?? 0.12 }),
  );
  shadowFloor.rotation.x = -Math.PI / 2;
  shadowFloor.position.y = 0.002;
  shadowFloor.receiveShadow = true;
  scene.add(shadowFloor);

  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.07;
  controls.enablePan = false;
  controls.enableZoom = options.zoom ?? true;
  controls.minDistance = options.minDistance ?? 4.5;
  controls.maxDistance = options.maxDistance ?? 14;
  controls.minPolarAngle = Math.PI * 0.12;
  controls.maxPolarAngle = Math.PI * 0.545;
  controls.autoRotate = options.autoRotate ?? false;
  controls.autoRotateSpeed = 1.1;
  controls.target.copy(target);

  let userMoved = false;
  controls.addEventListener("start", () => {
    userMoved = true;
  });

  let width = host.clientWidth || 640;
  let height = host.clientHeight || 420;
  const distance = options.distance ?? 7.6;

  const frame = () => {
    const aspect = width / height;
    const pull = Math.max(1, 1.12 / Math.min(aspect, 1.12));
    camera.position.copy(target).addScaledVector(direction, distance * pull);
    camera.lookAt(target);
  };

  const resize = () => {
    const nextWidth = host.clientWidth;
    const nextHeight = host.clientHeight;
    if (!nextWidth || !nextHeight) return;
    width = nextWidth;
    height = nextHeight;
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    if (!userMoved) frame();
  };

  const observer = new ResizeObserver(resize);
  observer.observe(host);
  resize();

  const pointer: StagePointer = { x: 0, y: 0, active: false };
  const onPointerMove = (event: PointerEvent) => {
    if (event.pointerType === "touch") return;
    const rect = renderer.domElement.getBoundingClientRect();
    pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    pointer.y = -(((event.clientY - rect.top) / rect.height) * 2 - 1);
    pointer.active = true;
  };
  const onPointerLeave = () => {
    pointer.active = false;
  };
  host.addEventListener("pointermove", onPointerMove);
  host.addEventListener("pointerleave", onPointerLeave);

  const callbacks: Array<(delta: number, elapsed: number) => void> = [];
  const timer = new THREE.Timer();
  let elapsed = 0;
  let raf = 0;
  let visible = true;

  const visibility = new IntersectionObserver(
    (entries) => {
      visible = entries[0]?.isIntersecting ?? true;
    },
    { rootMargin: "120px" },
  );
  visibility.observe(host);

  const loop = () => {
    raf = requestAnimationFrame(loop);
    timer.update();
    const delta = Math.min(timer.getDelta(), 0.05);
    elapsed += delta;
    controls.update();
    for (const callback of callbacks) callback(delta, elapsed);
    if (visible) renderer.render(scene, camera);
  };
  renderer.render(scene, camera);
  loop();

  const resetView = () => {
    userMoved = false;
    controls.target.copy(target);
    frame();
    controls.update();
  };

  const dispose = () => {
    cancelAnimationFrame(raf);
    observer.disconnect();
    visibility.disconnect();
    host.removeEventListener("pointermove", onPointerMove);
    host.removeEventListener("pointerleave", onPointerLeave);
    callbacks.length = 0;
    controls.dispose();
    scene.traverse((object) => {
      if (object instanceof THREE.Mesh) {
        object.geometry.dispose();
        disposeMaterial(object.material);
      }
    });
    shadowFloor.geometry.dispose();
    (shadowFloor.material as THREE.Material).dispose();
    environment.dispose();
    renderer.dispose();
    renderer.domElement.remove();
  };

  return {
    renderer,
    scene,
    camera,
    controls,
    target,
    pointer,
    addFrame: (callback) => callbacks.push(callback),
    resetView,
    dispose,
  };
}
