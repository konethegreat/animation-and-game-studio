import "./creator-probe.css";
import "@fontsource-variable/fraunces";
import "@fontsource-variable/manrope";
import "@fontsource/ibm-plex-mono/400.css";

import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";

type MorphMesh = { mesh: THREE.Mesh; targets: Map<string, number> };
type SliderDef = { name: string; label: string };
type ViewName = "face" | "three" | "bust" | "full";

const SHAPE_SLIDERS: SliderDef[] = [
  { name: "shape_jaw_width", label: "Jaw width" },
  { name: "shape_jaw_angle", label: "Jaw corner" },
  { name: "shape_chin_length", label: "Chin length" },
  { name: "shape_chin_width", label: "Chin width" },
  { name: "shape_cheek_hollow", label: "Cheek hollow" },
  { name: "feat_cheeks", label: "Cheekbones" },
];

// Curated, the way the best creators do it: each is a set of anatomical controls
// tuned together, so every choice is a face that already works.
const FACE_SHAPES: Record<string, Record<string, number>> = {
  Oval: {},
  Round: { shape_jaw_width: 0.45, shape_jaw_angle: -0.4, shape_chin_length: -0.5, shape_chin_width: 0.4, shape_cheek_hollow: -0.8, feat_cheeks: 0.2 },
  Square: { shape_jaw_width: 0.5, shape_jaw_angle: 0.9, shape_chin_length: 0.1, shape_chin_width: 0.6, shape_cheek_hollow: 0.3 },
  Heart: { shape_jaw_width: -0.6, shape_jaw_angle: -0.7, shape_chin_length: 0.2, shape_chin_width: -0.6, feat_cheeks: 0.7 },
  Diamond: { shape_jaw_width: -0.5, shape_jaw_angle: -0.2, shape_chin_length: 0.4, shape_chin_width: -0.5, shape_cheek_hollow: 0.5, feat_cheeks: 1.0 },
  Long: { shape_jaw_width: -0.25, shape_chin_length: 0.9, shape_chin_width: -0.2, shape_cheek_hollow: 0.5 },
};

const BODY_SLIDERS: SliderDef[] = [
  { name: "body_width", label: "Build" },
  { name: "body_chest", label: "Chest" },
  { name: "body_shoulders", label: "Shoulders" },
  { name: "body_waist", label: "Waist" },
  { name: "body_belly", label: "Belly" },
  { name: "body_bust", label: "Bust" },
  { name: "body_hips", label: "Hips" },
  { name: "body_pelvis", label: "Pelvis" },
];

const FACE_SLIDERS: SliderDef[] = [
  { name: "feat_lips", label: "Lip fullness" },
  { name: "feat_nose_wide", label: "Nose width" },
  { name: "feat_nose_bridge", label: "Nose bridge" },
  { name: "face_jaw", label: "Head size" },
  { name: "face_chin", label: "Chin" },
  { name: "face_midface", label: "Midface" },
  { name: "face_mouth", label: "Mouth" },
  { name: "face_forehead", label: "Forehead" },
  { name: "face_nose", label: "Nose" },
  { name: "face_brow", label: "Brow ridge" },
  { name: "face_cheeks", label: "Cheeks" },
  { name: "face_lips", label: "Lips" },
];

const EXPRESSIONS: Record<string, Record<string, number>> = {
  neutral: {},
  smile: { expr_smile_L: 0.85, expr_smile_R: 0.85, expr_innerbrow_L: 0.12, expr_innerbrow_R: 0.12 },
  curious: {
    expr_innerbrow_L: 0.6,
    expr_innerbrow_R: 0.6,
    expr_outerbrow_L: 0.4,
    expr_outerbrow_R: 0.4,
    expr_lookup_L: 0.55,
    expr_lookup_R: 0.55,
  },
  surprised: {
    expr_outerbrow_L: 0.8,
    expr_outerbrow_R: 0.8,
    expr_jawdrop: 0.38,
    expr_upperlid_L: 0.3,
    expr_upperlid_R: 0.3,
  },
  frown: { expr_innerbrow_L: 0.7, expr_innerbrow_R: 0.7, expr_smile_L: -0.4, expr_smile_R: -0.4 },
  blink: { expr_eyesclosed_L: 0.94, expr_eyesclosed_R: 0.94 },
};

const EXPRESSION_TARGETS = new Set(
  Object.values(EXPRESSIONS).flatMap((morphs) => Object.keys(morphs)),
);

const VIEWS: Record<ViewName, { position: THREE.Vector3; target: THREE.Vector3; fov: number }> = {
  face: {
    position: new THREE.Vector3(0.05, 1.655, 1.62),
    target: new THREE.Vector3(0, 1.64, 0.06),
    fov: 15,
  },
  three: {
    position: new THREE.Vector3(0.86, 1.68, 1.34),
    target: new THREE.Vector3(0, 1.635, 0.03),
    fov: 15,
  },
  bust: {
    position: new THREE.Vector3(0.62, 1.66, 2.3),
    target: new THREE.Vector3(0, 1.47, 0),
    fov: 22,
  },
  full: {
    position: new THREE.Vector3(0.72, 1.14, 3.05),
    target: new THREE.Vector3(0, 0.92, 0),
    fov: 36,
  },
};

// Each tone carries its own lips, palms and specular. Deep skin is not a darkened
// light skin: it has two-tone lips, much lighter palms and a stronger sheen.
type SkinTone = {
  label: string;
  value: number;
  lipUpper: number;
  lipLower: number;
  palm: number;
  shine: number;
};

const SKIN_TONES: SkinTone[] = [
  { label: "Ebony", value: 0x3a241b, lipUpper: 0x3c2320, lipLower: 0x4f2d29, palm: 0x8c6250, shine: 1.0 },
  { label: "Espresso", value: 0x4d2f20, lipUpper: 0x4a2c27, lipLower: 0x5f3831, palm: 0x9e7059, shine: 0.95 },
  { label: "Umber", value: 0x62402b, lipUpper: 0x5e3730, lipLower: 0x70433a, palm: 0xad7f66, shine: 0.88 },
  { label: "Mahogany", value: 0x74492f, lipUpper: 0x733f33, lipLower: 0x8a5040, palm: 0xb88a6e, shine: 0.8 },
  { label: "Chestnut", value: 0x8c5c3d, lipUpper: 0x84503f, lipLower: 0x9a5f4e, palm: 0xc69a7c, shine: 0.7 },
  { label: "Caramel", value: 0x97694a, lipUpper: 0x7e4a3d, lipLower: 0xa86a58, palm: 0xd2ab8d, shine: 0.6 },
  { label: "Bronze", value: 0xac8059, lipUpper: 0x905748, lipLower: 0xb47a66, palm: 0xdcb99c, shine: 0.54 },
  { label: "Honey", value: 0xc89e77, lipUpper: 0xa06650, lipLower: 0xbf8470, palm: 0xe4c4a8, shine: 0.48 },
  { label: "Sand", value: 0xdcbb98, lipUpper: 0xae7260, lipLower: 0xc98e7c, palm: 0xecd0b6, shine: 0.46 },
  { label: "Porcelain", value: 0xf3dcc8, lipUpper: 0xb87a6c, lipLower: 0xd0988a, palm: 0xf3dcc8, shine: 0.44 },
];

const HAIR_COLORS = [
  { label: "Natural black", value: 0x1b1513 },
  { label: "Soft black", value: 0x2c211c },
  { label: "Espresso", value: 0x402819 },
  { label: "Chestnut", value: 0x5b3522 },
  { label: "Auburn", value: 0x7d341b },
  { label: "Burgundy", value: 0x5a1a22 },
  { label: "Honey blonde", value: 0xab7d50 },
  { label: "Silver", value: 0xb4b0a8 },
];

const HAIR_STYLES = [
  { id: "afro", label: "Afro" },
  { id: "puff", label: "Puff" },
  { id: "coils", label: "Short coils" },
  { id: "fade", label: "Fade" },
  { id: "waves", label: "Waves" },
  { id: "locs", label: "Locs" },
  { id: "twists", label: "Twists" },
  { id: "braids", label: "Box braids" },
  { id: "cornrows", label: "Cornrows" },
  { id: "bantu", label: "Bantu knots" },
  { id: "crop", label: "Textured crop" },
  { id: "shaved", label: "Shaved" },
];

type BodyType = "female" | "male";

type Look = {
  stubble?: number;
  id: string;
  label: string;
  body: BodyType;
  skin: string;
  hair: string;
  hairColor: string;
  iris: string;
  cloth: string;
  shape: Record<string, number>;
};

const LOOKS: Look[] = [
  { id: "amara", label: "Amara", body: "female", skin: "Umber", hair: "afro", hairColor: "Natural black", iris: "Dark brown", cloth: "Moss", shape: { feat_lips: 0.75, feat_nose_wide: 0.55, feat_nose_bridge: 0.35, feat_cheeks: 0.6 } },
  { id: "thabo", stubble: 0.55, label: "Thabo", body: "male", skin: "Espresso", hair: "fade", hairColor: "Natural black", iris: "Dark brown", cloth: "Ink", shape: { feat_lips: 0.6, feat_nose_wide: 0.8, feat_nose_bridge: 0.5, feat_cheeks: 0.3, shape_jaw_width: 0.35, shape_jaw_angle: 0.6 } },
  { id: "naledi", label: "Naledi", body: "female", skin: "Ebony", hair: "braids", hairColor: "Natural black", iris: "Dark brown", cloth: "Bone", shape: { feat_lips: 0.9, feat_nose_wide: 0.7, feat_nose_bridge: 0.55, feat_cheeks: 0.8 } },
  { id: "kofi", stubble: 0.7, label: "Kofi", body: "male", skin: "Mahogany", hair: "locs", hairColor: "Soft black", iris: "Hazel", cloth: "Moss", shape: { feat_lips: 0.5, feat_nose_wide: 0.6, feat_nose_bridge: 0.3, feat_cheeks: 0.5 } },
  { id: "zola", label: "Zola", body: "female", skin: "Chestnut", hair: "cornrows", hairColor: "Natural black", iris: "Dark brown", cloth: "Slate", shape: { feat_lips: 0.55, feat_nose_wide: 0.35, feat_nose_bridge: 0.15, feat_cheeks: 0.7 } },
  { id: "malik", stubble: 0.35, label: "Malik", body: "male", skin: "Umber", hair: "waves", hairColor: "Natural black", iris: "Dark brown", cloth: "Clay", shape: { feat_lips: 0.45, feat_nose_wide: 0.5, feat_nose_bridge: 0.2, feat_cheeks: 0.35, shape_jaw_width: 0.15, shape_jaw_angle: 0.3 } },
  { id: "imani", label: "Imani", body: "female", skin: "Caramel", hair: "puff", hairColor: "Espresso", iris: "Amber", cloth: "Ink", shape: { feat_lips: 0.5, feat_nose_wide: 0.3, feat_nose_bridge: 0.1, feat_cheeks: 0.5 } },
  { id: "tariq", stubble: 0.45, label: "Tariq", body: "male", skin: "Bronze", hair: "crop", hairColor: "Espresso", iris: "Green", cloth: "Slate", shape: { feat_lips: 0.1, feat_nose_wide: 0.1, shape_jaw_width: 0.25, shape_jaw_angle: 0.7 } },
];

const IRIS_COLORS = [
  { label: "Dark brown", value: 0x4e2f1c },
  { label: "Hazel", value: 0x9a7448 },
  { label: "Green", value: 0x63805d },
  { label: "Blue", value: 0x627f9c },
  { label: "Grey", value: 0x8b8e91 },
  { label: "Amber", value: 0xbd883f },
];

const CLOTH_COLORS = [
  { label: "Ink", value: 0x23272f },
  { label: "Slate", value: 0x445364 },
  { label: "Moss", value: 0x4d5a44 },
  { label: "Clay", value: 0xa2604a },
  { label: "Bone", value: 0xd8cdb8 },
];

type LightPreset = {
  key: number;
  keyIntensity: number;
  keyPosition: [number, number, number];
  fill: number;
  fillIntensity: number;
  fillPosition: [number, number, number];
  rim: number;
  rimIntensity: number;
  rimPosition: [number, number, number];
  exposure: number;
};

const LIGHT_PRESETS: Record<string, LightPreset> = {
  softbox: {
    key: 0xfff5ee,
    keyIntensity: 2.7,
    keyPosition: [1.35, 1.05, 2.7],
    fill: 0xe4e8f4,
    fillIntensity: 0.55,
    fillPosition: [-2.6, 1.6, 1.2],
    rim: 0xffd0b4,
    rimIntensity: 1.7,
    rimPosition: [-1.3, 2.7, -2.5],
    exposure: 1.0,
  },
  golden: {
    key: 0xffdcc0,
    keyIntensity: 2.6,
    keyPosition: [2.6, 0.7, 1.6],
    fill: 0xa8bcf0,
    fillIntensity: 0.65,
    fillPosition: [-2.0, 1.5, -0.5],
    rim: 0xffa878,
    rimIntensity: 1.3,
    rimPosition: [-2.2, 2.4, -2.6],
    exposure: 1.0,
  },
  editorial: {
    key: 0xfaf7f2,
    keyIntensity: 2.9,
    keyPosition: [0.7, 2.3, 2.6],
    fill: 0xd9e7ff,
    fillIntensity: 0.6,
    fillPosition: [-2.8, 1.2, 0.6],
    rim: 0x9fc0ff,
    rimIntensity: 1.6,
    rimPosition: [-1.0, 2.0, -3.0],
    exposure: 0.98,
  },
};

const HEAD_CENTER = new THREE.Vector3(0, 1.655, 0.01);
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

function must<T extends Element>(selector: string): T {
  const element = document.querySelector<T>(selector);
  if (!element) throw new Error(`Missing element ${selector}`);
  return element;
}

const host = must<HTMLDivElement>("#probe-view");
const splash = must<HTMLDivElement>("#probe-splash");
const progressBar = must<HTMLSpanElement>("#probe-progress");
const progressLabel = must<HTMLParagraphElement>("#probe-progress-label");
const stateLabel = must<HTMLSpanElement>("#probe-state");
const fpsEl = must<HTMLElement>("#stat-fps");
const trisEl = must<HTMLElement>("#stat-tris");
const callsEl = must<HTMLElement>("#stat-calls");
const sizeEl = must<HTMLElement>("#stat-size");
const loadEl = must<HTMLElement>("#stat-load");

const renderer = new THREE.WebGLRenderer({
  antialias: true,
  alpha: true,
  powerPreference: "high-performance",
  preserveDrawingBuffer: true,
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;
renderer.domElement.setAttribute("aria-hidden", "true");
host.prepend(renderer.domElement);

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(34, 1, 0.05, 40);

const pmrem = new THREE.PMREMGenerator(renderer);
const environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
scene.environment = environment;
scene.environmentIntensity = 0.34;
pmrem.dispose();

scene.add(new THREE.HemisphereLight(0xfff3e4, 0x9c7a62, 0.62));

const key = new THREE.DirectionalLight(0xffe3c8, 2.8);
key.target.position.copy(HEAD_CENTER);
key.position.copy(HEAD_CENTER).add(new THREE.Vector3(1.5, 1.35, 2.5));
// A tight frustum around the head, so lids, nose and hair cast crisp shadows.
key.castShadow = true;
renderer.shadowMap.autoUpdate = false;
key.shadow.mapSize.set(2048, 2048);
key.shadow.camera.left = -0.24;
key.shadow.camera.right = 0.24;
key.shadow.camera.top = 0.24;
key.shadow.camera.bottom = -0.3;
key.shadow.camera.near = 1.5;
key.shadow.camera.far = 6;
key.shadow.bias = -0.0002;
key.shadow.normalBias = 0.0016;
key.shadow.radius = 6;
key.shadow.intensity = 0.72;
scene.add(key, key.target);

const fill = new THREE.DirectionalLight(0xcddcff, 0.8);
fill.position.set(-2.6, 1.7, 1.4);
scene.add(fill);

const rim = new THREE.DirectionalLight(0xffc4a0, 1.5);
rim.position.set(-1.8, 2.6, -2.2);
scene.add(rim);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.08;
controls.enablePan = false;
controls.minDistance = 0.3;
controls.maxDistance = 5.2;
controls.minPolarAngle = 0.3;
controls.maxPolarAngle = 1.72;
controls.target.copy(VIEWS.bust.target);
camera.position.copy(VIEWS.bust.position);
camera.lookAt(VIEWS.bust.target);

const character = new THREE.Group();
scene.add(character);

const morphMeshes: MorphMesh[] = [];
const sliderInputs: HTMLInputElement[] = [];
const eyeParts: THREE.Object3D[] = [];

const sssUniforms = {
  color: { value: new THREE.Color(0xff5a3a) },
  strength: { value: 0.24 },
  keyDirection: { value: new THREE.Vector3(0, 0, 1) },
};

const skinUniforms = {
  uSkinTone: { value: new THREE.Color(SKIN_TONES[2].value) },
  uLipUpper: { value: new THREE.Color(SKIN_TONES[2].lipUpper) },
  uLipLower: { value: new THREE.Color(SKIN_TONES[2].lipLower) },
  uPalm: { value: new THREE.Color(SKIN_TONES[2].palm) },
  uShine: { value: SKIN_TONES[2].shine },
  uStubble: { value: 0 },
  uSkinMask: { value: null as THREE.Texture | null },
};

const irisUniforms = { tint: { value: new THREE.Color(0x9a7448) } };

const hairUniforms = {
  uColor: { value: new THREE.Color(HAIR_COLORS[0].value) },
  uLightDirection: { value: new THREE.Vector3(1.5, 1.35, 2.5).normalize() },
  uLightColor: { value: new THREE.Color(0xfff5ee).multiplyScalar(3.0) },
  uRimDirection: { value: new THREE.Vector3(-1.3, 2.7, -2.5).normalize() },
  uRimColor: { value: new THREE.Color(0xffd0b4).multiplyScalar(1.7) },
  uFillColor: { value: new THREE.Color(0xd8e4f8).multiplyScalar(0.34) },
  uHeadCenter: { value: HEAD_CENTER },
  uViewportHeight: { value: 1080 },
  uStrandWidth: { value: 0.012 },
  uTaper: { value: 1 },
  uMode: { value: 0 },
  uShine: { value: 1 },
  uFollow: { value: new THREE.Matrix4() },
};

const capUniforms = {
  uCapAlpha: { value: 1 },
  uCapLow: { value: 0 },
  uCapHigh: { value: 0 },
};

// One fitted affine per shape key, from the hair file. Hair, its shadow and the
// cap all read the same summed matrix, so they stay seated as the head changes.
const hairFollowKeys = new Map<string, number[]>();
const morphWeights = new Map<string, number>();

function updateHairFollow(): void {
  const sum = new Array<number>(12).fill(0);
  for (const [name, weight] of morphWeights) {
    const affine = hairFollowKeys.get(name);
    if (!affine || weight === 0) continue;
    for (let index = 0; index < 12; index += 1) sum[index] += affine[index] * weight;
  }
  hairUniforms.uFollow.value.set(
    1 + sum[0], sum[1], sum[2], sum[3],
    sum[4], 1 + sum[5], sum[6], sum[7],
    sum[8], sum[9], 1 + sum[10], sum[11],
    0, 0, 0, 1,
  );
}

const STRAND_ATTRIBUTES = /* glsl */ `
  attribute vec4 aTangent;
  attribute vec4 aData;
  attribute float aSide;
  attribute float aArc;
`;

// t runs root to tip; the ribbon tapers and turns toward whoever looks at it.
const STRAND_WIDTH = /* glsl */ `
  uniform float uTaper;
  float strandWidth(float t, float scale) {
    float fine = smoothstep(0.0, 0.2, t + 0.012) * (pow(max(0.0, 1.0 - t), 0.55) * 0.92 + 0.08);
    float rope = (1.0 - smoothstep(0.93, 1.0, t) * 0.82);
    return uStrandWidth * scale * mix(rope, fine, uTaper);
  }
`;

// Strands are geometry, not alpha cards, so there is nothing to sort or to dither.
const hairMaterial = new THREE.ShaderMaterial({
  uniforms: hairUniforms,
  side: THREE.DoubleSide,
  alphaToCoverage: true,
  vertexShader: /* glsl */ `
    ${STRAND_ATTRIBUTES}
    uniform float uViewportHeight;
    uniform float uStrandWidth;
    uniform float uMode;
    uniform vec3 uHeadCenter;
    uniform mat4 uFollow;
    varying vec3 vTangentW;
    varying vec3 vWorld;
    varying vec4 vData;
    varying float vCoverage;
    varying float vAcross;
    varying float vArc;
    varying float vDetail;
    ${STRAND_WIDTH}

    void main() {
      vec4 world = uFollow * modelMatrix * vec4(position, 1.0);
      vec3 tangent = normalize(mat3(modelMatrix) * aTangent.xyz);
      vec3 toCamera = normalize(cameraPosition - world.xyz);
      vec3 across = normalize(cross(tangent, toCamera));
      vec4 clip = projectionMatrix * viewMatrix * world;
      float pixelsPerMetre = projectionMatrix[1][1] * uViewportHeight * 0.5 / clip.w;
      float width = strandWidth(aData.x, aData.z);
      if (uMode > 0.5) width *= mix(0.42, 1.0, smoothstep(0.0, 2.4, aArc));
      float baseWidth = uStrandWidth * aData.z;
      // Detail is how many pixels a typical strand spans: 1 up close, 0 far away.
      vDetail = smoothstep(0.55, 3.2, baseWidth * pixelsPerMetre);
      if (uMode < 0.5 && aData.z < 0.3) {
        // Decide per strand, from the head's distance: if this varied along a
        // strand, part of it would stretch off to the discard point.
        float headPixels = projectionMatrix[1][1] * uViewportHeight * 0.5 / length(cameraPosition - uHeadCenter);
        float keep = mix(0.5, 1.0, smoothstep(0.55, 3.2, baseWidth * headPixels));
        if (aData.w > keep) {
          gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
          return;
        }
        width *= mix(1.0 / sqrt(keep) * 1.3, 1.0, vDetail);
      }
      // Below a pixel the ribbon holds its size and fades, or it would flicker.
      float minimum = 1.0 / pixelsPerMetre;
      vCoverage = clamp(width / minimum, 0.2, 1.0);
      world.xyz += across * aSide * max(width, minimum) * 0.5;
      vTangentW = tangent;
      vWorld = world.xyz;
      vData = aData;
      vAcross = aSide;
      vArc = aArc;
      gl_Position = projectionMatrix * viewMatrix * world;
    }
  `,
  fragmentShader: /* glsl */ `
    uniform vec3 uColor;
    uniform vec3 uLightDirection;
    uniform vec3 uLightColor;
    uniform vec3 uRimDirection;
    uniform vec3 uRimColor;
    uniform vec3 uFillColor;
    uniform vec3 uHeadCenter;
    uniform float uMode;
    uniform float uShine;
    varying vec3 vTangentW;
    varying vec3 vWorld;
    varying vec4 vData;
    varying float vCoverage;
    varying float vAcross;
    varying float vArc;
    varying float vDetail;

    float strandSpec(vec3 tangent, vec3 halfVector, float power) {
      float dotTH = dot(tangent, halfVector);
      return pow(sqrt(max(0.0, 1.0 - dotTH * dotTH)), power) * smoothstep(-1.0, 0.0, dotTH + 0.6);
    }

    void main() {
      vec3 T = normalize(vTangentW);
      vec3 V = normalize(cameraPosition - vWorld);
      vec3 form = normalize(vWorld - uHeadCenter);
      vec3 L = normalize(uLightDirection);
      vec3 H = normalize(L + V);
      float t = vData.x;
      // Far away, per-strand contrast fades toward the mass's average tone.
      float shade = mix(0.42 + 0.36 * vData.y, vData.y, vDetail);
      float seed = mix(0.5, vData.w, vDetail);
      float facing = dot(form, L);
      float lit = smoothstep(-0.55, 0.65, facing);
      vec3 tint = (uColor + vec3(0.012, 0.0095, 0.0085)) * (0.78 + 0.5 * seed);
      vec3 diffuse;
      vec3 specular;

      if (uMode > 0.5) {
        // A ribbon shaded as a round rope, with its braid or twist cut into it.
        vec3 S = normalize(cross(T, V));
        float a = clamp(vAcross, -0.98, 0.98);
        vec3 N = normalize(S * a + V * sqrt(1.0 - a * a));
        float s = vArc;
        float groove;
        if (uMode < 1.5) {
          // Locs: matted, gently lumpy, with fine fibre and no regular pattern.
          float lump = sin(s * 1.7 + seed * 31.0) * 0.5 + sin(s * 4.3 + seed * 11.0) * 0.5;
          float fibre = sin(a * 19.0 + s * 5.0 + seed * 40.0) * sin(s * 13.0 - a * 7.0);
          groove = 0.70 + 0.14 * lump + 0.16 * fibre;
        } else if (uMode < 2.5) {
          // Twists: two plies wrapping around each other.
          float ply = sin((s * 5.2 + a * 1.35 + seed * 6.0) * 3.14159);
          groove = 0.30 + 0.70 * pow(abs(ply), 0.55);
        } else {
          // Braids: three strands, read as overlapping chevrons.
          float left = sin((s * 6.4 + a * 1.1 + seed * 6.0) * 3.14159);
          float right = sin((s * 6.4 - a * 1.1 + seed * 6.0) * 3.14159);
          groove = 0.24 + 0.76 * pow(max(abs(left), abs(right) * 0.9), 2.2);
        }
        float fine = 0.92 + 0.08 * sin(a * 42.0 + s * 21.0);
        float wrap = clamp(dot(N, L) * 0.5 + 0.5, 0.0, 1.0);
        vec3 rise = uLightColor * wrap * wrap * mix(0.5, 1.0, lit) * 0.40;
        diffuse = tint * shade * groove * fine * (rise + uFillColor * 1.1 + vec3(0.26, 0.24, 0.22));
        float gloss = pow(max(dot(N, H), 0.0), 34.0) * groove;
        specular = uLightColor * lit * shade * gloss * (0.075 + tint * 0.26) * uShine;
        vec3 RL = normalize(uRimDirection);
        specular += uRimColor * pow(max(dot(N, normalize(RL + V)), 0.0), 16.0) * shade * (0.04 + tint * 0.3) * uShine;
      } else {
        // Fine and coiled hair: a round cross section with a strand tangent.
        float round = sqrt(max(0.0, 1.0 - vAcross * vAcross * 0.85));
        float sinTL = sqrt(max(0.0, 1.0 - pow(dot(T, L), 2.0)));
        vec3 hue = (tint + vec3(0.020, 0.017, 0.016) * max(0.0, uShine - 1.0)) * mix(vec3(0.62, 0.66, 0.70), vec3(0.98, 1.06, 1.14), t);
        diffuse = hue * shade * round
          * (uLightColor * lit * (0.34 + 0.66 * sinTL) * 0.42 + uFillColor * 1.1 + vec3(0.30, 0.27, 0.25));
        vec3 shifted = normalize(T + form * (0.14 + 0.10 * seed));
        vec3 shiftedB = normalize(T - form * 0.10);
        float primary = strandSpec(shifted, H, 110.0);
        float secondary = strandSpec(shiftedB, H, 26.0);
        // Black hair has no diffuse to speak of; its shape is all in the sheen.
        specular = uLightColor * lit * shade * round * uShine
          * (primary * (vec3(0.022) + hue * 0.20) * vDetail + secondary * (vec3(0.012) + hue * 0.30));
        vec3 HR = normalize(normalize(uRimDirection) + V);
        float rim = strandSpec(T, HR, 44.0) * smoothstep(-0.2, 0.5, dot(form, normalize(uRimDirection)));
        specular += uRimColor * rim * shade * (0.022 + hue * 0.4) * mix(0.5, 1.0, min(uShine, 1.0)) * mix(0.35, 1.0, vDetail);
      }

      gl_FragColor = vec4(diffuse + specular, vCoverage);
      #include <tonemapping_fragment>
      #include <colorspace_fragment>
    }
  `,
});

// The shadow pass needs the same ribbons, expanded toward the light.
const hairDepthMaterial = new THREE.MeshDepthMaterial({ depthPacking: THREE.RGBADepthPacking });
hairDepthMaterial.onBeforeCompile = (shader) => {
  shader.uniforms.uLightDirection = hairUniforms.uLightDirection;
  shader.uniforms.uStrandWidth = hairUniforms.uStrandWidth;
  shader.uniforms.uTaper = hairUniforms.uTaper;
  shader.uniforms.uFollow = hairUniforms.uFollow;
  shader.vertexShader = shader.vertexShader
    .replace(
      "#include <common>",
      `#include <common>
      ${STRAND_ATTRIBUTES}
      uniform vec3 uLightDirection;
      uniform float uStrandWidth;
      uniform mat4 uFollow;
      ${STRAND_WIDTH}`,
    )
    .replace(
      "#include <begin_vertex>",
      `vec3 transformed = (uFollow * vec4(position, 1.0)).xyz;
      transformed += normalize(cross(aTangent.xyz, uLightDirection)) * aSide
        * max(strandWidth(aData.x, aData.z), 0.0009) * 0.5;`,
    );
};

// Soft dark underlayer. It blends, so the hairline shades the skin gradually.
const hairCapMaterial = new THREE.ShaderMaterial({
  uniforms: {
    uColor: hairUniforms.uColor,
    uLightDirection: hairUniforms.uLightDirection,
    uHeadCenter: hairUniforms.uHeadCenter,
    uFollow: hairUniforms.uFollow,
    uCapAlpha: capUniforms.uCapAlpha,
    uCapLow: capUniforms.uCapLow,
    uCapHigh: capUniforms.uCapHigh,
  },
  transparent: true,
  depthWrite: false,
  vertexShader: /* glsl */ `
    attribute vec4 color;
    uniform mat4 uFollow;
    varying float vDensity;
    varying vec3 vWorld;
    void main() {
      vDensity = color.r;
      vec4 world = uFollow * modelMatrix * vec4(position, 1.0);
      vWorld = world.xyz;
      gl_Position = projectionMatrix * viewMatrix * world;
    }
  `,
  fragmentShader: /* glsl */ `
    uniform vec3 uColor;
    uniform vec3 uLightDirection;
    uniform vec3 uHeadCenter;
    uniform float uCapAlpha;
    uniform float uCapLow;
    uniform float uCapHigh;
    varying float vDensity;
    varying vec3 vWorld;
    void main() {
      float alpha = smoothstep(0.45, 1.0, vDensity) * uCapAlpha;
      if (uCapHigh > uCapLow) {
        // A fade: dark up top, down to skin at the nape. Stubble breaks up the ramp.
        float grade = smoothstep(uCapLow, uCapHigh, vWorld.y);
        float stubble = fract(sin(dot(floor(vWorld * 1400.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
        alpha *= grade * (0.55 + 0.45 * smoothstep(1.0 - grade - 0.25, 1.0 - grade + 0.25, stubble));
      }
      if (alpha < 0.005) discard;
      float lit = dot(normalize(vWorld - uHeadCenter), normalize(uLightDirection)) * 0.5 + 0.5;
      gl_FragColor = vec4(uColor * (0.14 + 0.30 * lit) + vec3(0.002), alpha * 0.90);
      #include <tonemapping_fragment>
      #include <colorspace_fragment>
    }
  `,
});

let skinMaterial: THREE.MeshPhysicalMaterial | null = null;
let irisMaterial: THREE.MeshPhysicalMaterial | null = null;
let browsMaterial: THREE.MeshStandardMaterial | null = null;
let garmentMaterial: THREE.MeshPhysicalMaterial | null = null;

function sourceMaterial(mesh: THREE.Mesh): THREE.MeshStandardMaterial | null {
  const material = Array.isArray(mesh.material) ? mesh.material[0] : mesh.material;
  return material instanceof THREE.MeshStandardMaterial ? material : null;
}

function applyMorph(name: string, value: number): void {
  renderer.shadowMap.needsUpdate = true;
  morphWeights.set(name, value);
  updateHairFollow();
  for (const entry of morphMeshes) {
    const index = entry.targets.get(name);
    const influences = entry.mesh.morphTargetInfluences;
    if (index !== undefined && influences) influences[index] = value;
  }
}

// Tiling pore detail, generated here so it adds nothing to the download. The
// baked skin map cannot carry pores: it has about half a millimetre per texel.
function createPoreTexture(): THREE.DataTexture {
  const size = 512;
  const height = new Float32Array(size * size);
  let seed = 7;
  const random = (): number => {
    seed = (seed * 16807) % 2147483647;
    return seed / 2147483647;
  };
  for (let pore = 0; pore < 2400; pore += 1) {
    const cx = random() * size;
    const cy = random() * size;
    const radius = 1.3 + random() * 2.2;
    const depth = 0.35 + random() * 0.65;
    const reach = Math.ceil(radius * 2.2);
    for (let dy = -reach; dy <= reach; dy += 1) {
      for (let dx = -reach; dx <= reach; dx += 1) {
        const x = (Math.floor(cx) + dx + size) % size;
        const y = (Math.floor(cy) + dy + size) % size;
        height[y * size + x] -= depth * Math.exp(-(dx * dx + dy * dy) / (radius * radius));
      }
    }
  }
  const data = new Uint8Array(size * size * 4);
  for (let y = 0; y < size; y += 1) {
    for (let x = 0; x < size; x += 1) {
      const left = height[y * size + ((x + size - 1) % size)];
      const right = height[y * size + ((x + 1) % size)];
      const down = height[((y + size - 1) % size) * size + x];
      const up = height[((y + 1) % size) * size + x];
      const offset = (y * size + x) * 4;
      data[offset] = THREE.MathUtils.clamp(128 + (left - right) * 120, 0, 255);
      data[offset + 1] = THREE.MathUtils.clamp(128 + (down - up) * 120, 0, 255);
      data[offset + 2] = 255;
      data[offset + 3] = THREE.MathUtils.clamp(255 + height[y * size + x] * 190, 0, 255);
    }
  }
  const texture = new THREE.DataTexture(data, size, size, THREE.RGBAFormat);
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.magFilter = THREE.LinearFilter;
  texture.minFilter = THREE.LinearMipmapLinearFilter;
  texture.generateMipmaps = true;
  texture.anisotropy = Math.min(8, renderer.capabilities.getMaxAnisotropy());
  texture.needsUpdate = true;
  return texture;
}

function buildSkin(mesh: THREE.Mesh): void {
  const source = sourceMaterial(mesh);
  const poreTexture = createPoreTexture();
  const maskUrl = `${import.meta.env.BASE_URL}models/probe/skin_mask.png`;
  skinUniforms.uSkinMask.value = new THREE.TextureLoader().load(maskUrl, (texture) => {
    texture.flipY = false;
    texture.needsUpdate = true;
  });
  skinUniforms.uSkinMask.value.flipY = false;
  const material = new THREE.MeshPhysicalMaterial({
    map: source?.map ?? null,
    normalMap: source?.normalMap ?? null,
    roughnessMap: source?.roughnessMap ?? null,
    color: 0xffffff,
    roughness: 1.0,
    metalness: 0,
    normalScale: new THREE.Vector2(0.55, 0.55),
    sheen: 0.02,
    sheenRoughness: 0.9,
    sheenColor: new THREE.Color(0xffe2d2),
    specularIntensity: 0.46,
    envMapIntensity: 0.3,
  });
  if (material.map) {
    material.map.anisotropy = Math.min(8, renderer.capabilities.getMaxAnisotropy());
  }
  material.onBeforeCompile = (shader) => {
    shader.uniforms.uSssColor = sssUniforms.color;
    shader.uniforms.uSssStrength = sssUniforms.strength;
    shader.uniforms.uKeyDirection = sssUniforms.keyDirection;
    shader.uniforms.uPores = { value: poreTexture };
    shader.uniforms.uSkinTone = skinUniforms.uSkinTone;
    shader.uniforms.uLipUpper = skinUniforms.uLipUpper;
    shader.uniforms.uLipLower = skinUniforms.uLipLower;
    shader.uniforms.uPalm = skinUniforms.uPalm;
    shader.uniforms.uShine = skinUniforms.uShine;
    shader.uniforms.uStubble = skinUniforms.uStubble;
    shader.uniforms.uSkinMask = skinUniforms.uSkinMask;
    shader.fragmentShader = shader.fragmentShader
      .replace(
        "#include <common>",
        `#include <common>
        uniform vec3 uSssColor;
        uniform float uSssStrength;
        uniform vec3 uKeyDirection;
        uniform sampler2D uPores;
        uniform vec3 uSkinTone;
        uniform vec3 uLipUpper;
        uniform vec3 uLipLower;
        uniform vec3 uPalm;
        uniform float uShine;
        uniform float uStubble;
        uniform sampler2D uSkinMask;`,
      )
      .replace(
        "#include <map_fragment>",
        `// The map stores variation around a neutral base, in linear light. Dividing it
        // out lets any tone keep the same blood, shadow and cavity structure.
        vec3 probeSample = texture2D( map, vMapUv ).rgb;
        vec3 probeRatio = probeSample / vec3( 0.485, 0.296, 0.233 );
        float probeLuma = dot( probeRatio, vec3( 0.3, 0.55, 0.15 ) );
        float probeDepth = 1.0 - clamp( dot( uSkinTone, vec3( 0.3, 0.55, 0.15 ) ) * 1.6, 0.0, 1.0 );
        // Deep skin hides blood colour, so hue variation fades while shading stays.
        vec3 probeVariation = mix( probeRatio, vec3( probeLuma ), probeDepth * 0.62 );
        vec4 probeMask = texture2D( uSkinMask, vMapUv );
        vec3 probeTone = uSkinTone * probeVariation;
        float probePalm = smoothstep( 0.5, 1.0, probeMask.b );
        float probeBeard = clamp( probeMask.b * 2.0, 0.0, 1.0 ) * ( 1.0 - step( 0.5, probeMask.b ) );
        probeTone = mix( probeTone, uPalm * probeVariation, probePalm );
        // Stubble cools and darkens the skin, relative to the tone it sits on.
        probeTone = mix( probeTone, probeTone * vec3( 0.50, 0.52, 0.56 ), probeBeard * uStubble );
        vec3 probeLip = mix( uLipLower, uLipUpper, probeMask.g ) * ( 0.62 + 0.30 * probeLuma );
        probeTone = mix( probeTone, probeLip, probeMask.r * 0.92 );
        diffuseColor.rgb = probeTone;`,
      )
      .replace(
        "#include <normal_fragment_maps>",
        `#include <normal_fragment_maps>
        vec4 probePore = texture2D( uPores, vNormalMapUv * 26.0 );
        normal = normalize( normal + ( tbn[ 0 ] * ( probePore.x * 2.0 - 1.0 ) + tbn[ 1 ] * ( probePore.y * 2.0 - 1.0 ) ) * 0.28 );
        roughnessFactor = clamp( roughnessFactor * mix( 1.0, 0.76, uShine ) + ( 1.0 - probePore.a ) * 0.16, 0.0, 1.0 );
        diffuseColor.rgb *= mix( 0.95, 1.0, probePore.a );`,
      )
      .replace(
        "#include <emissivemap_fragment>",
        `#include <emissivemap_fragment>
        vec3 probeView = normalize( vViewPosition );
        float probeBack = pow( saturate( dot( -probeView, normalize( uKeyDirection ) ) ), 5.0 );
        totalEmissiveRadiance += uSssColor * probeBack * uSssStrength * ( 0.35 + diffuseColor.rgb );
        float probeNdl = dot( normal, normalize( uKeyDirection ) );
        float probeScatter = smoothstep( -0.22, 0.03, probeNdl ) * ( 1.0 - smoothstep( 0.03, 0.40, probeNdl ) );
        totalEmissiveRadiance += diffuseColor.rgb * vec3( 1.0, 0.24, 0.12 ) * probeScatter * uSssStrength * 0.8;`,
      );
  };
  material.customProgramCacheKey = () => "probe-skin-sss";
  skinMaterial = material;
  mesh.material = material;
}

function buildIris(mesh: THREE.Mesh): void {
  const source = sourceMaterial(mesh);
  const material = new THREE.MeshPhysicalMaterial({
    map: source?.map ?? null,
    color: 0xffffff,
    roughness: 0.62,
    metalness: 0,
    specularIntensity: 0.2,
    envMapIntensity: 0.1,
    side: THREE.DoubleSide,
  });
  material.onBeforeCompile = (shader) => {
    shader.uniforms.uIrisTint = irisUniforms.tint;
    shader.fragmentShader = shader.fragmentShader
      .replace("#include <common>", "#include <common>\nuniform vec3 uIrisTint;")
      .replace(
        "#include <map_fragment>",
        `#ifdef USE_MAP
          vec4 probeIris = texture2D( map, vMapUv );
          float probeLum = dot( probeIris.rgb, vec3( 0.2126, 0.7152, 0.0722 ) );
          float probeBody = smoothstep( 0.015, 0.1, probeLum );
          diffuseColor.rgb = mix( uIrisTint * 0.04, uIrisTint * ( 0.26 + probeLum * 0.95 ), probeBody );
          diffuseColor.rgb *= mix( 0.42, 1.0, smoothstep( 0.10, 0.46, vMapUv.y ) );
        #endif`,
      );
  };
  material.customProgramCacheKey = () => "probe-iris";
  irisMaterial = material;
  mesh.material = material;
  mesh.renderOrder = 1;
}

function buildSclera(mesh: THREE.Mesh): void {
  const source = sourceMaterial(mesh);
  mesh.material = new THREE.MeshPhysicalMaterial({
    map: source?.map ?? null,
    color: 0xc9c2ba,
    roughness: 0.34,
    metalness: 0,
    clearcoat: 0.10,
    clearcoatRoughness: 0.24,
    envMapIntensity: 0.28,
  });
}

// Reflection only, added over the eye. The mesh is shallow so it stays behind the
// lids; the shading assumes a real 8 mm cornea, or the key light could never land
// on it and the eye would have no catch light.
const corneaMaterial = new THREE.ShaderMaterial({
  uniforms: {
    uLightDirection: hairUniforms.uLightDirection,
    uLightColor: hairUniforms.uLightColor,
    uFillColor: hairUniforms.uFillColor,
  },
  transparent: true,
  blending: THREE.AdditiveBlending,
  depthWrite: false,
  vertexShader: /* glsl */ `
    #include <common>
    #include <morphtarget_pars_vertex>
    varying vec2 vDisc;
    varying vec3 vWorld;
    void main() {
      vDisc = (uv - 0.5) * vec2(2.0, -2.0);
      #include <begin_vertex>
      #include <morphtarget_vertex>
      #include <project_vertex>
      vWorld = (modelMatrix * vec4(transformed, 1.0)).xyz;
    }
  `,
  fragmentShader: /* glsl */ `
    uniform vec3 uLightDirection;
    uniform vec3 uLightColor;
    uniform vec3 uFillColor;
    varying vec2 vDisc;
    varying vec3 vWorld;
    void main() {
      vec2 slope = vDisc * 0.9;
      vec3 N = normalize(vec3(slope, sqrt(max(0.05, 1.0 - dot(slope, slope)))));
      vec3 V = normalize(cameraPosition - vWorld);
      vec3 H = normalize(normalize(uLightDirection) + V);
      vec3 HF = normalize(normalize(vec3(-0.5, 0.35, 0.8)) + V);
      float fresnel = 0.04 + 0.96 * pow(1.0 - max(dot(N, V), 0.0), 5.0);
      vec3 color = uLightColor * pow(max(dot(N, H), 0.0), 520.0) * 0.55
        + uFillColor * pow(max(dot(N, HF), 0.0), 90.0) * 0.28
        + vec3(0.32, 0.34, 0.38) * fresnel;
      float edge = 1.0 - smoothstep(0.82, 1.0, length(vDisc));
      gl_FragColor = vec4(color * edge, 1.0);
      #include <tonemapping_fragment>
      #include <colorspace_fragment>
    }
  `,
});

function buildCornea(mesh: THREE.Mesh): void {
  mesh.material = corneaMaterial;
  mesh.renderOrder = 2;
  mesh.castShadow = false;
  mesh.receiveShadow = false;
}

function buildGarment(mesh: THREE.Mesh, colour: number = CLOTH_COLORS[0].value): THREE.MeshPhysicalMaterial {
  const source = sourceMaterial(mesh);
  const material = new THREE.MeshPhysicalMaterial({
    map: source?.map ?? null,
    alphaToCoverage: true,
    color: colour,
    roughness: 0.94,
    metalness: 0,
    sheen: 0.12,
    sheenRoughness: 0.9,
    sheenColor: new THREE.Color(0xffffff),
    side: THREE.DoubleSide,
    envMapIntensity: 0.25,
  });
  if (material.map) {
    material.map.anisotropy = Math.min(8, renderer.capabilities.getMaxAnisotropy());
  }
  // Cut on the distance field baked per vertex, with a stitched-looking hem.
  material.onBeforeCompile = (shader) => {
    shader.vertexShader = shader.vertexShader
      .replace("#include <common>", "#include <common>\nattribute vec4 color;\nvarying float vEdge;")
      .replace("#include <begin_vertex>", "#include <begin_vertex>\nvEdge = color.r;");
    shader.fragmentShader = shader.fragmentShader
      .replace("#include <common>", "#include <common>\nvarying float vEdge;")
      .replace(
        "#include <alphatest_fragment>",
        `float probeEdge = ( vEdge - 0.5 ) * 6.0;
        float probeEdgeWidth = max( fwidth( probeEdge ), 0.0001 );
        diffuseColor.a = smoothstep( -probeEdgeWidth, probeEdgeWidth, probeEdge );
        if ( diffuseColor.a < 0.01 ) discard;
        diffuseColor.rgb *= mix( 0.74, 1.0, smoothstep( 0.32, 0.46, probeEdge ) );`,
      );
  };
  material.customProgramCacheKey = () => "probe-garment";
  mesh.material = material;
  return material;
}

function buildBrows(mesh: THREE.Mesh): void {
  browsMaterial = new THREE.MeshStandardMaterial({
    color: new THREE.Color(HAIR_COLORS[0].value).multiplyScalar(0.62),
    roughness: 0.62,
    metalness: 0,
    side: THREE.DoubleSide,
  });
  mesh.material = browsMaterial;
  mesh.castShadow = false;
}

function buildHairCap(mesh: THREE.Mesh): void {
  mesh.material = hairCapMaterial;
  mesh.frustumCulled = false;
  mesh.castShadow = false;
  mesh.receiveShadow = false;
}

type HairParams = {
  mode: number;
  width: number;
  taper: number;
  shine: number;
  capAlpha: number;
  capLow: number;
  capHigh: number;
};

function buildHairStrands(buffer: ArrayBuffer): { mesh: THREE.Mesh; params: HairParams } {
  const [strands, points] = new Uint32Array(buffer, 0, 2);
  const counts = new Uint8Array(buffer, 8, strands);
  let offset = 8 + strands + ((4 - (strands % 4)) % 4);
  const sourcePosition = new Float32Array(buffer, offset, points * 3);
  offset += points * 12;
  const sourceTangent = new Int8Array(buffer, offset, points * 4);
  offset += points * 4;
  const sourceData = new Uint8Array(buffer, offset, points * 4);
  offset += points * 4;
  const sourceArc = new Float32Array(buffer.slice(offset, offset + points * 4));
  offset += points * 4;
  const metaLength = new DataView(buffer).getUint32(offset, true);
  const meta = JSON.parse(new TextDecoder().decode(new Uint8Array(buffer, offset + 4, metaLength))) as HairParams & {
    follow: Record<string, number[]>;
  };
  for (const [name, affine] of Object.entries(meta.follow)) hairFollowKeys.set(name, affine);
  updateHairFollow();

  // Each point becomes a left and right vertex; the shader spreads them apart.
  const position = new Float32Array(points * 6);
  const tangent = new Int8Array(points * 8);
  const data = new Uint8Array(points * 8);
  const side = new Float32Array(points * 2);
  const arc = new Float32Array(points * 2);
  for (let point = 0; point < points; point += 1) {
    for (let copy = 0; copy < 2; copy += 1) {
      const vertex = point * 2 + copy;
      position.set(sourcePosition.subarray(point * 3, point * 3 + 3), vertex * 3);
      tangent.set(sourceTangent.subarray(point * 4, point * 4 + 4), vertex * 4);
      data.set(sourceData.subarray(point * 4, point * 4 + 4), vertex * 4);
      side[vertex] = copy === 0 ? -1 : 1;
      arc[vertex] = sourceArc[point];
    }
  }
  const indices = new Uint32Array((points - strands) * 6);
  let cursor = 0;
  let base = 0;
  for (const count of counts) {
    for (let segment = 0; segment < count - 1; segment += 1) {
      const a = (base + segment) * 2;
      indices.set([a, a + 1, a + 3, a, a + 3, a + 2], cursor);
      cursor += 6;
    }
    base += count;
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute("position", new THREE.BufferAttribute(position, 3));
  geometry.setAttribute("aTangent", new THREE.BufferAttribute(tangent, 4, true));
  geometry.setAttribute("aData", new THREE.BufferAttribute(data, 4, true));
  geometry.setAttribute("aSide", new THREE.BufferAttribute(side, 1));
  geometry.setAttribute("aArc", new THREE.BufferAttribute(arc, 1));
  geometry.setIndex(new THREE.BufferAttribute(indices, 1));
  // Coil strands are stored in random order, so a phone can simply draw fewer.
  if (meta.mode === 0 && window.innerWidth < 800) {
    geometry.setDrawRange(0, Math.floor((indices.length * 0.6) / 6) * 6);
  }
  const mesh = new THREE.Mesh(geometry, hairMaterial);
  mesh.name = "hair";
  mesh.frustumCulled = false;
  mesh.castShadow = true;
  mesh.customDepthMaterial = hairDepthMaterial;
  return { mesh, params: meta };
}

const hairCache = new Map<string, Promise<{ mesh: THREE.Mesh; params: HairParams }>>();
let activeHair: THREE.Mesh | null = null;
let hairRequest = 0;

function loadHair(id: string): Promise<{ mesh: THREE.Mesh; params: HairParams }> {
  let pending = hairCache.get(id);
  if (!pending) {
    pending = fetch(`${import.meta.env.BASE_URL}models/probe/hair/${id}.bin`)
      .then((response) => {
        if (!response.ok) throw new Error(`hair ${id} ${response.status}`);
        return response.arrayBuffer();
      })
      .then(buildHairStrands);
    hairCache.set(id, pending);
  }
  return pending;
}

function applyCap(params: { capAlpha: number; capLow: number; capHigh: number }): void {
  capUniforms.uCapAlpha.value = params.capAlpha;
  capUniforms.uCapLow.value = params.capLow;
  capUniforms.uCapHigh.value = params.capHigh;
}

async function setHairStyle(id: string): Promise<void> {
  for (const button of document.querySelectorAll<HTMLButtonElement>("#probe-styles button")) {
    button.classList.toggle("is-active", button.dataset.style === id);
  }
  const request = (hairRequest += 1);
  if (id === "shaved") {
    if (activeHair) character.remove(activeHair);
    activeHair = null;
    applyCap({ capAlpha: 0.3, capLow: 0, capHigh: 0 });
    renderer.shadowMap.needsUpdate = true;
    return;
  }
  const { mesh, params } = await loadHair(id);
  // A newer choice may have landed while this one was still downloading.
  if (request !== hairRequest) return;
  if (activeHair) character.remove(activeHair);
  activeHair = mesh;
  character.add(mesh);
  hairUniforms.uStrandWidth.value = params.width;
  hairUniforms.uTaper.value = params.taper;
  hairUniforms.uMode.value = params.mode;
  hairUniforms.uShine.value = params.shine;
  applyCap(params);
  renderer.shadowMap.needsUpdate = true;
}

function buildCharacter(root: THREE.Object3D): void {
  root.traverse((object) => {
    if (!(object instanceof THREE.Mesh)) return;
    object.castShadow = true;
    object.receiveShadow = true;
    const targets = object.morphTargetDictionary;
    if (targets && object.morphTargetInfluences) {
      morphMeshes.push({ mesh: object, targets: new Map(Object.entries(targets)) });
      for (let index = 0; index < object.morphTargetInfluences.length; index += 1) {
        object.morphTargetInfluences[index] = 0;
      }
    }

    switch (object.name) {
      case "body_mesh":
        buildSkin(object);
        break;
      case "hair_cap":
        buildHairCap(object);
        break;
      case "brows":
        buildBrows(object);
        break;
      case "garment":
        garmentMaterial = buildGarment(object);
        // Its depth pass would use the uncut margin and print a zigzag on the skin.
        object.castShadow = false;
        break;
      case "trousers":
        buildGarment(object, 0x1e2024);
        object.castShadow = false;
        break;
      case "sclera_L":
      case "sclera_R":
        buildSclera(object);
        break;
      case "iris_L":
      case "iris_R":
        buildIris(object);
        eyeParts.push(object);
        break;
      case "cornea_L":
      case "cornea_R":
        buildCornea(object);
        eyeParts.push(object);
        break;
      case "waterline_L":
      case "waterline_R":
        object.material = new THREE.MeshPhysicalMaterial({
          color: 0xa06e60,
          roughness: 0.28,
          side: THREE.DoubleSide,
        });
        object.castShadow = false;
        break;
      default:
        break;
    }

  });
  character.add(root);
}

function setExpression(name: string): void {
  for (const target of EXPRESSION_TARGETS) applyMorph(target, 0);
  const morphs = EXPRESSIONS[name] ?? {};
  for (const [target, value] of Object.entries(morphs)) applyMorph(target, value);
  for (const button of document.querySelectorAll<HTMLButtonElement>("#probe-expressions button")) {
    button.classList.toggle("is-active", button.dataset.expression === name);
  }
  setGaze(name === "curious" ? 0.0016 : 0);
}

function setGaze(lift: number): void {
  // The eye is a shell behind the lids, so gaze slides the iris across it.
  for (const part of eyeParts) part.position.y = lift;
}

function buildSliders(hostElement: HTMLElement, defs: SliderDef[]): void {
  for (const def of defs) {
    const label = document.createElement("label");
    label.className = "probe-range";
    label.htmlFor = `morph-${def.name}`;

    const head = document.createElement("span");
    head.className = "probe-range-label";
    const name = document.createElement("span");
    name.textContent = def.label;
    const output = document.createElement("output");
    output.textContent = "0.00";
    head.append(name, output);

    const input = document.createElement("input");
    input.id = `morph-${def.name}`;
    input.type = "range";
    input.min = "-1";
    input.max = "1";
    input.step = "0.01";
    input.value = "0";
    input.addEventListener("input", () => {
      const value = Number(input.value);
      output.textContent = value.toFixed(2);
      applyMorph(def.name, value);
    });

    label.append(head, input);
    hostElement.append(label);
    sliderInputs.push(input);
  }
}

function buildSwatches(
  hostElement: HTMLElement,
  options: Array<{ label: string; value: number }>,
  onPick: (value: number) => void,
): void {
  options.forEach((option, index) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "probe-swatch";
    button.title = option.label;
    button.setAttribute("aria-label", option.label);
    button.style.background = `#${option.value.toString(16).padStart(6, "0")}`;
    if (index === 0) button.classList.add("is-active");
    button.addEventListener("click", () => {
      for (const sibling of hostElement.querySelectorAll(".probe-swatch")) {
        sibling.classList.remove("is-active");
      }
      button.classList.add("is-active");
      onPick(option.value);
    });
    hostElement.append(button);
  });
}

function applyLight(name: string): void {
  const preset = LIGHT_PRESETS[name];
  if (!preset) return;
  renderer.shadowMap.needsUpdate = true;
  key.color.set(preset.key);
  key.intensity = preset.keyIntensity;
  key.position.copy(HEAD_CENTER).add(new THREE.Vector3(...preset.keyPosition));
  fill.color.set(preset.fill);
  fill.intensity = preset.fillIntensity;
  fill.position.set(...preset.fillPosition);
  rim.color.set(preset.rim);
  rim.intensity = preset.rimIntensity;
  rim.position.set(...preset.rimPosition);
  renderer.toneMappingExposure = preset.exposure;
  hairUniforms.uLightColor.value.set(preset.key).multiplyScalar(preset.keyIntensity);
  hairUniforms.uLightDirection.value.set(...preset.keyPosition).normalize();
  hairUniforms.uRimColor.value.set(preset.rim).multiplyScalar(preset.rimIntensity);
  hairUniforms.uRimDirection.value.set(...preset.rimPosition).normalize();
  hairUniforms.uFillColor.value.set(preset.fill).multiplyScalar(preset.fillIntensity);
  for (const button of document.querySelectorAll<HTMLButtonElement>("#probe-light button")) {
    button.classList.toggle("is-active", button.dataset.light === name);
  }
}

type Tween = {
  fromPosition: THREE.Vector3;
  toPosition: THREE.Vector3;
  fromTarget: THREE.Vector3;
  toTarget: THREE.Vector3;
  fromFov: number;
  toFov: number;
  start: number;
  duration: number;
};

let tween: Tween | null = null;

function applyView(name: ViewName, instant = reducedMotion): void {
  const view = VIEWS[name];
  if (!view) return;
  if (instant) {
    camera.position.copy(view.position);
    controls.target.copy(view.target);
    camera.fov = view.fov;
    camera.updateProjectionMatrix();
    controls.update();
    tween = null;
  } else {
    tween = {
      fromPosition: camera.position.clone(),
      toPosition: view.position.clone(),
      fromTarget: controls.target.clone(),
      toTarget: view.target.clone(),
      fromFov: camera.fov,
      toFov: view.fov,
      start: performance.now(),
      duration: 700,
    };
  }
  for (const button of document.querySelectorAll<HTMLButtonElement>("#probe-views button")) {
    button.classList.toggle("is-active", button.dataset.view === name);
  }
}

function resetShape(): void {
  for (const input of sliderInputs) {
    input.value = "0";
    input.dispatchEvent(new Event("input"));
  }
  setExpression("neutral");
}

buildSliders(must<HTMLElement>("#probe-body"), BODY_SLIDERS);
buildSliders(must<HTMLElement>("#probe-shape"), SHAPE_SLIDERS);
buildSliders(must<HTMLElement>("#probe-face"), FACE_SLIDERS);
function applySkin(tone: SkinTone): void {
  skinUniforms.uSkinTone.value.setHex(tone.value);
  skinUniforms.uLipUpper.value.setHex(tone.lipUpper);
  skinUniforms.uLipLower.value.setHex(tone.lipLower);
  skinUniforms.uPalm.value.setHex(tone.palm);
  skinUniforms.uShine.value = tone.shine;
  if (skinMaterial) skinMaterial.specularIntensity = 0.36 + 0.34 * tone.shine;
  // Terminator colour follows the skin: warm brown in deep tones, red in pale ones.
  const depth = 1 - Math.min(1, new THREE.Color(tone.value).getHSL({ h: 0, s: 0, l: 0 }).l * 1.5);
  sssUniforms.color.value.set(0xff5a3a).lerp(new THREE.Color(0x9c5a38), depth);
}

buildSwatches(must<HTMLElement>("#probe-skin"), SKIN_TONES, (value) => {
  const tone = SKIN_TONES.find((item) => item.value === value);
  if (tone) applySkin(tone);
});
buildSwatches(must<HTMLElement>("#probe-cloth"), CLOTH_COLORS, (value) => {
  garmentMaterial?.color.setHex(value);
});
buildSwatches(must<HTMLElement>("#probe-hair"), HAIR_COLORS, (value) => {
  hairUniforms.uColor.value.setHex(value);
  if (browsMaterial) {
    browsMaterial.color.setHex(value).multiplyScalar(0.62);
  }
});
buildSwatches(must<HTMLElement>("#probe-iris"), IRIS_COLORS, (value) => {
  irisUniforms.tint.value.setHex(value);
});

function pickSwatch(host: string, label: string): void {
  must<HTMLElement>(host).querySelector<HTMLButtonElement>(`.probe-swatch[title="${label}"]`)?.click();
}

function setBody(type: BodyType): void {
  applyMorph("build_female", type === "female" ? 1 : 0);
  applyMorph("build_male", type === "male" ? 1 : 0);
  applyMorph("brow_fine", type === "female" ? 1 : 0);
  applyMorph("lash_long", type === "female" ? 1 : 0);
  for (const button of document.querySelectorAll<HTMLButtonElement>("#probe-build button")) {
    button.classList.toggle("is-active", button.dataset.build === type);
  }
}

function buildChips<T>(host: string, items: T[], label: (item: T) => string, data: (item: T, button: HTMLButtonElement) => void, pick: (item: T) => void): void {
  const element = must<HTMLElement>(host);
  for (const item of items) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = label(item);
    data(item, button);
    button.addEventListener("click", () => pick(item));
    element.append(button);
  }
}

function setStubble(value: number): void {
  skinUniforms.uStubble.value = value;
  const input = must<HTMLInputElement>("#probe-stubble");
  input.value = String(value);
  must<HTMLOutputElement>("#probe-stubble-value").textContent = value.toFixed(2);
}

must<HTMLInputElement>("#probe-stubble").addEventListener("input", (event) => {
  setStubble(Number((event.currentTarget as HTMLInputElement).value));
});

function setFaceShape(name: string): void {
  const shape = FACE_SHAPES[name] ?? {};
  for (const def of SHAPE_SLIDERS) {
    const input = must<HTMLInputElement>(`#morph-${def.name}`);
    input.value = String(shape[def.name] ?? 0);
    input.dispatchEvent(new Event("input"));
  }
  for (const button of document.querySelectorAll<HTMLButtonElement>("#probe-face-shapes button")) {
    button.classList.toggle("is-active", button.textContent === name);
  }
}

function applyLook(look: Look): void {
  for (const input of sliderInputs) {
    const name = input.id.replace("morph-", "");
    input.value = String(look.shape[name] ?? 0);
    input.dispatchEvent(new Event("input"));
  }
  setBody(look.body);
  setStubble(look.stubble ?? 0);
  pickSwatch("#probe-skin", look.skin);
  pickSwatch("#probe-hair", look.hairColor);
  pickSwatch("#probe-iris", look.iris);
  pickSwatch("#probe-cloth", look.cloth);
  void setHairStyle(look.hair);
  for (const button of document.querySelectorAll<HTMLButtonElement>("#probe-looks button")) {
    button.classList.toggle("is-active", button.dataset.look === look.id);
  }
}

buildChips("#probe-face-shapes", Object.keys(FACE_SHAPES), (name) => name, () => undefined, setFaceShape);
buildChips("#probe-looks", LOOKS, (look) => look.label, (look, button) => { button.dataset.look = look.id; }, applyLook);
buildChips("#probe-styles", HAIR_STYLES, (style) => style.label, (style, button) => { button.dataset.style = style.id; }, (style) => void setHairStyle(style.id));
for (const button of document.querySelectorAll<HTMLButtonElement>("#probe-build button")) {
  button.addEventListener("click", () => setBody(button.dataset.build as BodyType));
}

for (const button of document.querySelectorAll<HTMLButtonElement>("#probe-expressions button")) {
  button.addEventListener("click", () => setExpression(button.dataset.expression ?? "neutral"));
}
for (const button of document.querySelectorAll<HTMLButtonElement>("#probe-views button")) {
  button.addEventListener("click", () => applyView((button.dataset.view as ViewName) ?? "bust"));
}
for (const button of document.querySelectorAll<HTMLButtonElement>("#probe-light button")) {
  button.addEventListener("click", () => applyLight(button.dataset.light ?? "softbox"));
}
must<HTMLButtonElement>("#probe-reset").addEventListener("click", resetShape);
must<HTMLInputElement>("#probe-sss").addEventListener("input", (event) => {
  const value = Number((event.currentTarget as HTMLInputElement).value);
  sssUniforms.strength.value = value;
  must<HTMLOutputElement>("#probe-sss-value").textContent = value.toFixed(2);
});

let width = host.clientWidth || 720;
let height = host.clientHeight || 600;
const resize = (): void => {
  const nextWidth = host.clientWidth;
  const nextHeight = host.clientHeight;
  if (!nextWidth || !nextHeight) return;
  width = nextWidth;
  height = nextHeight;
  renderer.setSize(width, height, false);
  camera.aspect = width / height;
  camera.updateProjectionMatrix();
  hairUniforms.uViewportHeight.value = height * renderer.getPixelRatio();
};
new ResizeObserver(resize).observe(host);
resize();

let frames = 0;
let fpsWindow = performance.now();
let fps = 0;

function refreshStats(): void {
  fpsEl.textContent = fps.toFixed(0);
  trisEl.textContent = renderer.info.render.triangles.toLocaleString("en-US");
  callsEl.textContent = renderer.info.render.calls.toString();
}

function animate(): void {
  requestAnimationFrame(animate);

  if (tween) {
    const progress = Math.min(1, (performance.now() - tween.start) / tween.duration);
    const eased = 1 - (1 - progress) ** 3;
    camera.position.lerpVectors(tween.fromPosition, tween.toPosition, eased);
    controls.target.lerpVectors(tween.fromTarget, tween.toTarget, eased);
    camera.fov = THREE.MathUtils.lerp(tween.fromFov, tween.toFov, eased);
    camera.updateProjectionMatrix();
    if (progress >= 1) tween = null;
  }

  controls.update();
  camera.updateMatrixWorld();

  sssUniforms.keyDirection.value
    .copy(key.position)
    .sub(key.target.position)
    .normalize()
    .transformDirection(camera.matrixWorldInverse);

  renderer.render(scene, camera);

  frames += 1;
  const now = performance.now();
  if (now - fpsWindow >= 700) {
    fps = (frames * 1000) / (now - fpsWindow);
    frames = 0;
    fpsWindow = now;
    refreshStats();
  }
}

const assetUrl = `${import.meta.env.BASE_URL}models/probe/probe.glb`;
const loadStart = performance.now();
new GLTFLoader().load(
  assetUrl,
  (gltf) => {
    const loadTime = performance.now() - loadStart;
    buildCharacter(gltf.scene);
    setExpression("neutral");
    applyView("three", true);
    applyLight("softbox");
    applyLook(LOOKS[0]);
    stateLabel.textContent = "Live";
    stateLabel.classList.add("is-live");
    loadEl.textContent = loadTime.toFixed(0);
    progressBar.style.width = "100%";
    progressLabel.textContent = "Ready";
    splash.classList.add("is-done");
    refreshStats();
    void loadHair(LOOKS[0].hair).finally(() => {
      (window as unknown as { __probe: unknown }).__probe = {
        scene,
        camera,
        controls,
        renderer,
        character,
        loadTime,
        setHairStyle,
        applyLook,
        looks: LOOKS,
      };
    });
  },
  (event) => {
    if (event.total) {
      const percent = Math.min(100, Math.round((event.loaded / event.total) * 100));
      progressBar.style.width = `${percent}%`;
      progressLabel.textContent = `${percent}% of ${(event.total / 1048576).toFixed(1)} MB`;
    } else {
      progressLabel.textContent = `${(event.loaded / 1048576).toFixed(1)} MB loaded`;
    }
  },
  (error) => {
    console.error(error);
    stateLabel.textContent = "Asset missing";
    progressLabel.textContent = "The probe asset did not load. Start the showcase dev server.";
  },
);

fetch(assetUrl, { method: "HEAD" })
  .then((response) => Number(response.headers.get("content-length") ?? 0))
  .then((bytes) => {
    if (bytes > 0) sizeEl.textContent = (bytes / 1048576).toFixed(1);
  })
  .catch(() => {
    sizeEl.textContent = "5.1";
  });

animate();
