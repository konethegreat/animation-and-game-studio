import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";

export type ViewerOptions = {
  interactive?: boolean;
  zoom?: boolean;
  autoRotate?: boolean;
};

export type ViewerHandle = {
  controls: OrbitControls | null;
  reset: () => void;
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

export async function mountTurntable(
  host: HTMLElement,
  url: string,
  options: ViewerOptions = {},
): Promise<ViewerHandle> {
  const renderer = new THREE.WebGLRenderer({
    antialias: true,
    alpha: true,
    powerPreference: "high-performance",
  });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  renderer.domElement.className = "viewer-canvas";
  renderer.domElement.setAttribute("aria-hidden", "true");
  host.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(32, 1, 0.1, 60);
  const target = new THREE.Vector3(0, 1.6, 0);
  const direction = new THREE.Vector3(0.52, 0.2, 0.84).normalize();
  let userMoved = false;

  const pmrem = new THREE.PMREMGenerator(renderer);
  const envTexture = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  scene.environment = envTexture;
  scene.environmentIntensity = 0.42;
  pmrem.dispose();

  scene.add(new THREE.HemisphereLight(0xfff6e6, 0xcbbda2, 0.95));

  const key = new THREE.DirectionalLight(0xfff1d8, 2.7);
  key.position.set(5.5, 6.4, 6.5);
  key.castShadow = true;
  key.shadow.mapSize.set(2048, 2048);
  key.shadow.camera.left = -6;
  key.shadow.camera.right = 6;
  key.shadow.camera.top = 6;
  key.shadow.camera.bottom = -6;
  key.shadow.camera.near = 0.5;
  key.shadow.camera.far = 30;
  key.shadow.bias = -0.0004;
  key.shadow.normalBias = 0.02;
  scene.add(key);

  const rim = new THREE.DirectionalLight(0xc9f24d, 1.35);
  rim.position.set(-5.5, 2.1, -5.5);
  scene.add(rim);

  const bounce = new THREE.DirectionalLight(0xff8f73, 0.5);
  bounce.position.set(-4, 1.5, 5);
  scene.add(bounce);

  const ground = new THREE.Mesh(
    new THREE.CircleGeometry(6, 64),
    new THREE.ShadowMaterial({ opacity: 0.16 }),
  );
  ground.rotation.x = -Math.PI / 2;
  ground.position.y = 0.002;
  ground.receiveShadow = true;
  scene.add(ground);

  const controls = options.interactive
    ? new OrbitControls(camera, renderer.domElement)
    : null;

  if (controls) {
    // OrbitControls sets touch-action none, which traps page scroll on phones; vertical swipes should scroll.
    renderer.domElement.style.touchAction = "pan-y";
    controls.enableDamping = true;
    controls.dampingFactor = 0.06;
    controls.enablePan = false;
    controls.enableZoom = options.zoom ?? false;
    controls.minDistance = 5;
    controls.maxDistance = 15;
    controls.minPolarAngle = Math.PI * 0.18;
    controls.maxPolarAngle = Math.PI * 0.54;
    controls.autoRotate = options.autoRotate ?? false;
    controls.autoRotateSpeed = 1.2;
    controls.target.copy(target);
    controls.addEventListener("start", () => {
      userMoved = true;
    });
  }

  let width = host.clientWidth || 640;
  let height = host.clientHeight || 480;

  const frame = () => {
    const aspect = width / height;
    const distance = 8.4 * Math.max(1, 1.12 / Math.min(aspect, 1.12));
    camera.position.copy(target).addScaledVector(direction, distance);
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

  const loader = new GLTFLoader();
  const gltf = await loader.loadAsync(url);
  const model = gltf.scene;
  model.traverse((object) => {
    if (!(object instanceof THREE.Mesh)) return;
    object.castShadow = true;
    object.receiveShadow = false;
    const materials = Array.isArray(object.material) ? object.material : [object.material];
    for (const material of materials) {
      if ("envMapIntensity" in material) {
        (material as THREE.MeshStandardMaterial).envMapIntensity = 0.7;
      }
      if (material instanceof THREE.MeshStandardMaterial && material.name === "Pedestal") {
        material.color.multiplyScalar(0.35);
        material.metalness = 0;
        material.roughness = 0.78;
      }
    }
  });
  scene.add(model);

  const box = new THREE.Box3().setFromObject(model);
  const center = box.getCenter(new THREE.Vector3());
  target.set(0, center.y, 0);
  if (controls) controls.target.copy(target);
  frame();

  const mixer = new THREE.AnimationMixer(model);
  for (const clip of gltf.animations) mixer.clipAction(clip).play();

  let visible = true;
  const visibility = new IntersectionObserver(
    (entries) => {
      visible = entries[0]?.isIntersecting ?? true;
    },
    { rootMargin: "120px" },
  );
  visibility.observe(host);

  let raf = 0;
  const timer = new THREE.Timer();
  const loop = () => {
    raf = requestAnimationFrame(loop);
    timer.update();
    const delta = Math.min(timer.getDelta(), 0.05);
    mixer.update(delta);
    controls?.update();
    if (visible) renderer.render(scene, camera);
  };
  renderer.render(scene, camera);
  loop();

  const reset = () => {
    userMoved = false;
    if (controls) controls.target.copy(target);
    frame();
    controls?.update();
  };

  const dispose = () => {
    cancelAnimationFrame(raf);
    observer.disconnect();
    visibility.disconnect();
    controls?.dispose();
    mixer.stopAllAction();
    scene.traverse((object) => {
      if (!(object instanceof THREE.Mesh)) return;
      object.geometry.dispose();
      disposeMaterial(object.material);
    });
    envTexture.dispose();
    ground.geometry.dispose();
    (ground.material as THREE.Material).dispose();
    renderer.dispose();
    renderer.domElement.remove();
  };

  return { controls, reset, dispose };
}
