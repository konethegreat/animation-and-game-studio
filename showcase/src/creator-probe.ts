import "./creator-probe.css";
import "@fontsource-variable/fraunces";
import "@fontsource-variable/manrope";
import "@fontsource/ibm-plex-mono/400.css";

import * as THREE from "three";
import {
  createStore,
  defaultState,
  sanitizeState,
  SCAR_COUNT,
  TATTOO_COUNT,
  type BodyType,
  type CharacterState,
} from "./creator-state";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";

type MorphMesh = { mesh: THREE.Mesh; targets: Map<string, number> };
type SliderDef = { name: string; label: string };
type ViewName = "macro" | "face" | "three" | "bust" | "full";

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
  { name: "feat_lip_bow", label: "Cupid's bow" },
  { name: "feat_lip_balance", label: "Upper / lower lip" },
  { name: "feat_nose_wide", label: "Nose width" },
  { name: "feat_nose_bridge", label: "Nose bridge" },
  { name: "feat_nose_tip", label: "Nose tip" },
  { name: "feat_eye_tilt", label: "Eye corner tilt" },
  { name: "feat_eye_hood", label: "Lid hooding" },
  { name: "feat_brow_arch", label: "Brow arch" },
  { name: "face_jaw", label: "Head size" },
  { name: "face_jawwidth", label: "Face width" },
  { name: "face_eyes", label: "Eye set" },
  { name: "face_nosewidth", label: "Nose shape" },
  { name: "face_mouth2", label: "Mouth shape" },
  { name: "face_chin", label: "Chin" },
  { name: "face_midface", label: "Midface" },
  { name: "face_mouth", label: "Mouth" },
  { name: "face_forehead", label: "Forehead" },
  { name: "face_nose", label: "Nose" },
  { name: "face_brow", label: "Brow ridge" },
  { name: "face_cheeks", label: "Cheeks" },
  { name: "face_lips", label: "Lips" },
];

// Local VALID references do not establish source-avatar redistribution rights.
const REFERENCE_SLIDERS: SliderDef[] = [
  { name: "ref_f_1", label: "Reference woman 1" },
  { name: "ref_f_2", label: "Reference woman 2" },
  { name: "ref_f_3", label: "Reference woman 3" },
  { name: "ref_m_1", label: "Reference man 1" },
  { name: "ref_m_2", label: "Reference man 2" },
  { name: "ref_m_3", label: "Reference man 3" },
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
  macro: {
    position: new THREE.Vector3(0.34, 1.625, 1.02),
    target: new THREE.Vector3(0, 1.605, 0.08),
    fov: 11,
  },
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
  { label: "Ebony", value: 0x3b2419, lipUpper: 0x301d1d, lipLower: 0x4f2e2c, palm: 0x8c6250, shine: 1.0 },
  { label: "Espresso", value: 0x4a2d1f, lipUpper: 0x3c2421, lipLower: 0x5c3531, palm: 0x9e7059, shine: 0.95 },
  { label: "Umber", value: 0x573727, lipUpper: 0x452825, lipLower: 0x693e38, palm: 0xad7f66, shine: 0.88 },
  { label: "Mahogany", value: 0x643f2d, lipUpper: 0x52302b, lipLower: 0x794840, palm: 0xb88a6e, shine: 0.8 },
  { label: "Chestnut", value: 0x77523c, lipUpper: 0x6a3f34, lipLower: 0x8c554a, palm: 0xc69a7c, shine: 0.7 },
  { label: "Caramel", value: 0x8c6244, lipUpper: 0x7e4a3d, lipLower: 0xa86a58, palm: 0xd2ab8d, shine: 0.6 },
  { label: "Bronze", value: 0x9c7450, lipUpper: 0x905748, lipLower: 0xb47a66, palm: 0xdcb99c, shine: 0.54 },
  { label: "Honey", value: 0xb28a64, lipUpper: 0xa06650, lipLower: 0xbf8470, palm: 0xe4c4a8, shine: 0.48 },
  { label: "Sand", value: 0xba9272, lipUpper: 0xae7260, lipLower: 0xc98e7c, palm: 0xecd0b6, shine: 0.46 },
  { label: "Porcelain", value: 0xc99f86, lipUpper: 0xb87a6c, lipLower: 0xd0988a, palm: 0xf3dcc8, shine: 0.44 },
];

const HAIR_COLORS = [
  { label: "Natural black", value: 0x1b1513 },
  { label: "Soft black", value: 0x2c211c },
  { label: "Espresso", value: 0x402819 },
  { label: "Chestnut", value: 0x5b3522 },
  { label: "Auburn", value: 0x642a16 },
  { label: "Burgundy", value: 0x5a1a22 },
  { label: "Honey blonde", value: 0xab7d50 },
  { label: "Silver", value: 0xb4b0a8 },
];

const TOP_CUTS = [
  { id: "tank", label: "Tank" },
  { id: "tee", label: "Tee" },
  { id: "long", label: "Long sleeve" },
];
const BOTTOM_CUTS = [
  { id: "trousers", label: "Trousers" },
  { id: "shorts", label: "Shorts" },
];
const BOTTOM_COLORS = [
  { label: "Charcoal", value: 0x1e2024 },
  { label: "Denim", value: 0x2b3c5a },
  { label: "Khaki", value: 0x7d6e52 },
  { label: "Olive", value: 0x3e4632 },
  { label: "Cream", value: 0xcfc5ae },
];
const SHOE_COLORS = [
  { label: "Black", value: 0x17181b },
  { label: "Brown", value: 0x4a2e1c },
  { label: "White", value: 0xd8d4cc },
  { label: "Clay", value: 0xa2604a },
];
// Each starting look has clothes that suit it, not one uniform for everyone.
const LOOK_OUTFITS: Record<string, Partial<CharacterState["outfit"]>> = {
  amara: { top: "tee", topFit: 0.3, bottomColor: "#2b3c5a" },
  thabo: { top: "tee", topFit: 0.6, bottomFit: 0.8 },
  naledi: { top: "long", topFit: 0.2, bottomColor: "#7d6e52", bottomFit: 0.6 },
  kofi: { top: "tank", topFit: 0.5, bottomFit: 0.9, bottomColor: "#3e4632" },
  zola: { top: "long", topFit: 0.1, bottomColor: "#1e2024" },
  malik: { top: "tee", topFit: 0.8, bottomFit: 0.7, bottomColor: "#2b3c5a", shoeColor: "#d8d4cc" },
  imani: { top: "tank", topFit: 0.1, bottomColor: "#cfc5ae", bottomFit: 0.5, shoeColor: "#4a2e1c" },
  tariq: { top: "long", topFit: 0.5, bottomFit: 0.7, bottomColor: "#7d6e52", shoeColor: "#4a2e1c" },
};

const BEARD_STYLES = [
  { id: "none", label: "None" },
  { id: "beard_goatee", label: "Goatee" },
  { id: "beard_short", label: "Short beard" },
  { id: "beard_full", label: "Full beard" },
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

type Look = {
  stubble?: number;
  beard?: string;
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
  { id: "amara", label: "Amara", body: "female", skin: "Umber", hair: "afro", hairColor: "Natural black", iris: "Dark brown", cloth: "Moss", shape: { face_chin: 0.05, face_midface: -0.25, face_eyes: 0.05, face_brow: -0.15, feat_lips: 0.65, feat_lip_bow: 0.65, feat_lip_balance: -0.35, feat_nose_wide: 0.7, feat_nose_bridge: 0.55, feat_nose_tip: 0.05, feat_cheeks: 0.3, feat_eye_tilt: 0.5, feat_eye_hood: 0.25, feat_brow_arch: 0.2, shape_jaw_width: -0.1, shape_chin_width: 0.3, shape_chin_length: 0.15 } },
  { id: "thabo", beard: "beard_short", stubble: 0.55, label: "Thabo", body: "male", skin: "Espresso", hair: "fade", hairColor: "Natural black", iris: "Dark brown", cloth: "Ink", shape: { face_chin: 0.35, face_brow: 0.3, face_midface: -0.2, face_mouth: -0.25, face_cheeks: 0.2, feat_lips: 0.6, feat_nose_wide: 0.8, feat_nose_bridge: 0.5, feat_cheeks: 0.3, shape_jaw_width: 0.35, shape_jaw_angle: 0.6 } },
  { id: "naledi", label: "Naledi", body: "female", skin: "Ebony", hair: "braids", hairColor: "Natural black", iris: "Dark brown", cloth: "Bone", shape: { face_midface: -0.35, face_mouth: 0.35, face_cheeks: 0.15, face_nose: 0.15, feat_lips: 0.9, feat_lip_bow: -0.3, feat_lip_balance: 0.4, feat_nose_wide: 0.95, feat_nose_bridge: 0.85, feat_nose_tip: -0.25, feat_cheeks: 0.55, feat_eye_tilt: 0.05, feat_eye_hood: 0.7, feat_brow_arch: -0.55, shape_jaw_width: 0.55, shape_jaw_angle: 0.45, shape_chin_width: 0.6, shape_cheek_hollow: -0.25 } },
  { id: "kofi", beard: "beard_full", stubble: 0.7, label: "Kofi", body: "male", skin: "Mahogany", hair: "locs", hairColor: "Soft black", iris: "Hazel", cloth: "Moss", shape: { face_midface: 0.4, face_chin: -0.2, face_eyes: -0.35, face_nose: 0.3, feat_lips: 0.5, feat_nose_wide: 0.6, feat_nose_bridge: 0.3, feat_cheeks: 0.5 } },
  { id: "zola", label: "Zola", body: "female", skin: "Chestnut", hair: "cornrows", hairColor: "Natural black", iris: "Dark brown", cloth: "Slate", shape: { face_chin: 0.15, face_forehead: 0.2, face_mouth2: -0.2, face_eyes: -0.25, face_brow: -0.1, feat_lips: 0.4, feat_lip_bow: 0.85, feat_lip_balance: 0.05, feat_nose_wide: 0.35, feat_nose_bridge: -0.45, feat_nose_tip: -0.2, feat_cheeks: 0.55, feat_eye_tilt: 0.65, feat_eye_hood: 0.4, feat_brow_arch: 0.8, shape_jaw_width: 0.1, shape_jaw_angle: 0.35, shape_chin_width: 0.45, shape_chin_length: 0.65, shape_cheek_hollow: 0.15 } },
  { id: "malik", beard: "beard_goatee", stubble: 0.35, label: "Malik", body: "male", skin: "Umber", hair: "waves", hairColor: "Natural black", iris: "Dark brown", cloth: "Clay", shape: { face_chin: 0.15, face_midface: -0.45, face_brow: 0.4, face_mouth2: 0.35, face_forehead: -0.25, feat_lips: 0.45, feat_nose_wide: 0.5, feat_nose_bridge: 0.2, feat_cheeks: 0.35, shape_jaw_width: 0.15, shape_jaw_angle: 0.3 } },
  { id: "imani", label: "Imani", body: "female", skin: "Caramel", hair: "puff", hairColor: "Espresso", iris: "Amber", cloth: "Ink", shape: { face_chin: 0.1, face_midface: 0.25, face_cheeks: -0.3, face_nosewidth: -0.15, face_eyes: 0.15, feat_lips: 0.7, feat_lip_bow: -0.2, feat_lip_balance: -0.25, feat_nose_wide: 0.65, feat_nose_bridge: 0.6, feat_nose_tip: 0.45, feat_cheeks: 0.15, feat_eye_tilt: 0.3, feat_eye_hood: -0.1, feat_brow_arch: 0.35, shape_jaw_width: 0.25, shape_jaw_angle: -0.25, shape_chin_width: 0.4, shape_chin_length: 0.05, shape_cheek_hollow: -0.3 } },
  { id: "tariq", stubble: 0.45, label: "Tariq", body: "male", skin: "Bronze", hair: "crop", hairColor: "Espresso", iris: "Green", cloth: "Slate", shape: { face_chin: -0.25, face_nose: 0.4, face_brow: 0.25, face_eyes: -0.2, face_cheeks: -0.3, feat_lips: 0.1, feat_nose_wide: 0.1, shape_jaw_width: 0.25, shape_jaw_angle: 0.7 } },
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
  sky?: number;
  ground?: number;
  ambient?: number;
  environment?: number;
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
  daylight: {
    sky: 0xdfeaff,
    ground: 0xa89a84,
    ambient: 0.95,
    environment: 0.5,
    key: 0xfff4e6,
    keyIntensity: 2.6,
    keyPosition: [0.9, 2.2, 2.4],
    fill: 0xdce8ff,
    fillIntensity: 0.6,
    fillPosition: [-2.6, 1.2, 1.2],
    rim: 0xffffff,
    rimIntensity: 0.9,
    rimPosition: [-1.2, 2.4, -2.6],
    exposure: 1.0,
  },
  campfire: {
    sky: 0x2a3148,
    ground: 0x7a4a2c,
    ambient: 0.5,
    environment: 0.12,
    key: 0xffb278,
    keyIntensity: 2.5,
    keyPosition: [1.7, -0.5, 2.2],
    fill: 0x4a5a94,
    fillIntensity: 0.28,
    fillPosition: [-2.4, 1.0, 0.6],
    rim: 0x6f88d8,
    rimIntensity: 0.9,
    rimPosition: [-1.5, 2.0, -2.6],
    exposure: 1.0,
  },
  dungeon: {
    sky: 0x38506a,
    ground: 0x262c30,
    ambient: 0.55,
    environment: 0.1,
    key: 0xbcd4ff,
    keyIntensity: 2.3,
    keyPosition: [-1.4, 2.6, 1.3],
    fill: 0x4a6a58,
    fillIntensity: 0.2,
    fillPosition: [2.2, 0.4, 1.0],
    rim: 0xa8d8e8,
    rimIntensity: 0.9,
    rimPosition: [1.5, 1.6, -2.6],
    exposure: 1.0,
  },
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

const hemisphere = new THREE.HemisphereLight(0xfff3e4, 0x9c7a62, 0.62);
scene.add(hemisphere);

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
  uUndertone: { value: 0 },
  uContrast: { value: 0.5 },
  uAge: { value: 0 },
  uFreckles: { value: 0 },
  uVitiligo: { value: 0 },
  uScarPick: { value: new THREE.Vector3() },
  uScarIntensity: { value: 0.7 },
  uTattooPick: { value: new THREE.Vector3() },
  uTattooColor: { value: new THREE.Color(0x14202a) },
  uTattooOpacity: { value: 0.85 },
  uLipColor: { value: new THREE.Color(0x6b2d2b) },
  uLipOpacity: { value: 0 },
  uLipGloss: { value: 0.3 },
  uEyeColor: { value: new THREE.Color(0x2b1a14) },
  uEyeOpacity: { value: 0 },
  uLiner: { value: 0 },
  uBlushColor: { value: new THREE.Color(0xa8483c) },
  uBlushOpacity: { value: 0 },
  uLayers: { value: null as THREE.Texture | null },
  uMarks: { value: null as THREE.Texture | null },
  uArt: { value: null as THREE.Texture | null },
  uMakeup: { value: null as THREE.Texture | null },
  uSkinMask: { value: null as THREE.Texture | null },
};

const irisUniforms = {
  left: { value: new THREE.Color(0x4e2f1c) },
  right: { value: new THREE.Color(0x4e2f1c) },
  pupil: { value: 0.5 },
  glow: { value: 0 },
};
const scleraMaterials: THREE.MeshPhysicalMaterial[] = [];

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
  uRipple: { value: 0 },
  uNudge: { value: 0 },
  uHighlight: { value: new THREE.Color(0x8c5230) },
  uHighlightAmount: { value: 0 },
  uGraying: { value: 0 },
  uCharacterScale: { value: 1 },
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

const beardFollowKeys = new Map<string, number[]>();
const beardFollow = new THREE.Matrix4();

function sumFollow(keys: Map<string, number[]>, target: THREE.Matrix4): void {
  const sum = new Array<number>(12).fill(0);
  for (const [name, weight] of morphWeights) {
    const affine = keys.get(name);
    if (!affine || weight === 0) continue;
    for (let index = 0; index < 12; index += 1) sum[index] += affine[index] * weight;
  }
  target.set(
    1 + sum[0], sum[1], sum[2], sum[3],
    sum[4], 1 + sum[5], sum[6], sum[7],
    sum[8], sum[9], 1 + sum[10], sum[11],
    0, 0, 0, 1,
  );
}

function updateHairFollow(): void {
  sumFollow(hairFollowKeys, hairUniforms.uFollow.value);
  sumFollow(beardFollowKeys, beardFollow);
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
    uniform float uCharacterScale;
    uniform float uNudge;
    varying vec3 vTangentW;
    varying vec3 vWorld;
    varying vec4 vData;
    varying float vCoverage;
    varying float vAcross;
    varying float vArc;
    varying float vDetail;
    ${STRAND_WIDTH}

    void main() {
      vec4 world = modelMatrix * vec4(position, 1.0);
      world.xyz /= uCharacterScale;
      world = uFollow * world;
      world.xyz *= uCharacterScale;
      vec3 tangent = normalize(mat3(modelMatrix) * aTangent.xyz);
      vec3 toCamera = normalize(cameraPosition - world.xyz);
      world.xyz += toCamera * uNudge;
      vec3 across = normalize(cross(tangent, toCamera));
      vec4 clip = projectionMatrix * viewMatrix * world;
      float pixelsPerMetre = projectionMatrix[1][1] * uViewportHeight * 0.5 / clip.w;
      float width = strandWidth(aData.x, aData.z);
      if (uMode > 0.5) width *= mix(0.42, 1.0, smoothstep(0.0, 2.4, aArc));
      if (uMode > 2.5) width *= 0.86 + 0.26 * abs(sin(aArc * 2.6 * 3.14159));
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
    uniform vec3 uHighlight;
    uniform float uHighlightAmount;
    uniform float uGraying;
    uniform float uRipple;
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
      vec3 primaryColor = uColor + vec3(0.012, 0.0095, 0.0085);
      // Streaks and gray are decided per strand from its seed. Far away, the mix of
      // strands has to resolve to its average, or distance would change the colour.
      float raw = vData.w;
      float fine = uMode > 0.5 || vData.z < 0.3 ? 1.0 : 0.0;
      float streak = step(1.0 - uHighlightAmount * 0.5, fract(raw * 11.71)) * smoothstep(0.05, 0.45, t) * fine;
      float salt = step(1.0 - uGraying, fract(raw * 37.13)) * fine;
      vec3 grayHair = vec3(0.30, 0.295, 0.285);
      vec3 near = mix(mix(primaryColor, uHighlight, streak * 0.8), grayHair, salt);
      vec3 mean = mix(mix(primaryColor, uHighlight, uHighlightAmount * 0.4 * smoothstep(0.05, 0.45, t) * fine), grayHair, uGraying * fine);
      vec3 tint = mix(mean, near, vDetail) * (0.78 + 0.5 * seed);
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
          float left = sin((s * 2.6 + a * 0.95 + seed * 6.0) * 3.14159);
          float right = sin((s * 2.6 - a * 0.95 + seed * 6.0) * 3.14159);
          groove = 0.20 + 0.80 * pow(max(abs(left), abs(right) * 0.92), 2.6);
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
        if (uRipple > 0.5) {
          // 360 waves: rings of relief around the crown. Each ridge catches the key
          // as a soft band, which is the whole look, and it must survive on black.
          vec3 fromCrown = vWorld - (uHeadCenter + vec3(-0.016, 0.061, -0.046));
          vec3 outward = normalize(fromCrown - form * dot(fromCrown, form));
          float phase = length(fromCrown) * 100.0 * 3.3;
          vec3 ridge = normalize(form + outward * cos(phase) * 0.8);
          float band = pow(max(dot(ridge, H), 0.0), 14.0);
          float valley = 0.55 + 0.45 * sin(phase);
          diffuse *= 0.55 + 0.9 * valley;
          specular = min(specular * 0.2, vec3(0.03)) + uLightColor * lit * min(band, 0.7) * smoothstep(0.03, 0.05, vData.z) * (vec3(0.12, 0.112, 0.105) + hue * 0.6);
        }
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
    uCharacterScale: hairUniforms.uCharacterScale,
    uCapAlpha: capUniforms.uCapAlpha,
    uCapLow: capUniforms.uCapLow,
    uCapHigh: capUniforms.uCapHigh,
  },
  transparent: true,
  depthWrite: false,
  vertexShader: /* glsl */ `
    attribute vec4 color;
    uniform mat4 uFollow;
    uniform float uCharacterScale;
    varying float vDensity;
    varying vec3 vWorld;
    void main() {
      vDensity = color.r;
      vec4 world = modelMatrix * vec4(position, 1.0);
      world.xyz /= uCharacterScale;
      world = uFollow * world;
      world.xyz *= uCharacterScale;
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
let browsMaterial: THREE.MeshStandardMaterial | null = null;
let garmentMaterial: THREE.MeshPhysicalMaterial | null = null;
let trouserMaterial: THREE.MeshPhysicalMaterial | null = null;
let shoeMaterial: THREE.MeshPhysicalMaterial | null = null;
let shoeMesh: THREE.Mesh | null = null;

function sourceMaterial(mesh: THREE.Mesh): THREE.MeshStandardMaterial | null {
  const material = Array.isArray(mesh.material) ? mesh.material[0] : mesh.material;
  return material instanceof THREE.MeshStandardMaterial ? material : null;
}

const morphTargets = new Map<string, number>();
let morphsSettled = false;

function setMorphTarget(name: string, value: number, instant: boolean): void {
  morphTargets.set(name, value);
  morphsSettled = false;
  if (instant) writeMorph(name, value);
}

function writeMorph(name: string, value: number): void {
  morphWeights.set(name, value);
  for (const entry of morphMeshes) {
    const index = entry.targets.get(name);
    const influences = entry.mesh.morphTargetInfluences;
    if (index !== undefined && influences) influences[index] = value;
  }
}

function easeMorphs(deltaSeconds: number): void {
  if (morphsSettled) return;
  // Exponential approach, so the feel is the same at 30 fps and at 144.
  const blend = reducedMotion ? 1 : 1 - Math.exp(-deltaSeconds * 13);
  let moving = false;
  for (const [name, target] of morphTargets) {
    const current = morphWeights.get(name) ?? 0;
    if (current === target) continue;
    const next = Math.abs(target - current) < 0.0015 ? target : current + (target - current) * blend;
    writeMorph(name, next);
    moving = true;
  }
  updateHairFollow();
  renderer.shadowMap.needsUpdate = true;
  morphsSettled = !moving;
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
  const loadMask = (name: string): THREE.Texture => {
    const texture = new THREE.TextureLoader().load(`${import.meta.env.BASE_URL}models/probe/${name}.png`);
    texture.flipY = false;
    return texture;
  };
  skinUniforms.uSkinMask.value = loadMask("skin_mask");
  skinUniforms.uLayers.value = loadMask("skin_layers");
  skinUniforms.uMarks.value = loadMask("skin_marks");
  skinUniforms.uArt.value = loadMask("skin_art");
  skinUniforms.uMakeup.value = loadMask("skin_makeup");
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
    specularIntensity: 0.62,
    envMapIntensity: 0.42,
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
    for (const name of [
      "uUndertone", "uContrast", "uAge", "uFreckles", "uVitiligo", "uScarPick", "uScarIntensity",
      "uTattooPick", "uTattooColor", "uTattooOpacity", "uLipColor", "uLipOpacity", "uLipGloss",
      "uEyeColor", "uEyeOpacity", "uLiner", "uBlushColor", "uBlushOpacity", "uLayers", "uMarks", "uArt", "uMakeup",
    ] as const) {
      shader.uniforms[name] = skinUniforms[name];
    }
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
        uniform sampler2D uSkinMask;
        uniform float uUndertone;
        uniform float uContrast;
        uniform float uAge;
        uniform float uFreckles;
        uniform float uVitiligo;
        uniform vec3 uScarPick;
        uniform float uScarIntensity;
        uniform vec3 uTattooPick;
        uniform vec3 uTattooColor;
        uniform float uTattooOpacity;
        uniform vec3 uLipColor;
        uniform float uLipOpacity;
        uniform float uLipGloss;
        uniform vec3 uEyeColor;
        uniform float uEyeOpacity;
        uniform float uLiner;
        uniform vec3 uBlushColor;
        uniform float uBlushOpacity;
        uniform sampler2D uLayers;
        uniform sampler2D uMarks;
        uniform sampler2D uArt;
        uniform sampler2D uMakeup;

        // Age creases and scars share one height, used for both colour and normal.
        float probeRelief( vec2 uv ) {
          return texture2D( uLayers, uv ).b * uAge * 0.8 + dot( texture2D( uMarks, uv ).rgb, uScarPick ) * uScarIntensity;
        }`,
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
        // Layer 1, base: tone, undertone, and how much structure shows through.
        probeVariation = pow( max( probeVariation, vec3( 0.001 ) ), vec3( 0.65 + uContrast * 0.7 ) );
        vec3 probeTone = uSkinTone * probeVariation * mix( vec3( 1.0 ), uUndertone > 0.0 ? vec3( 1.09, 1.0, 0.88 ) : vec3( 0.93, 0.99, 1.12 ), abs( uUndertone ) );
        float probePalm = smoothstep( 0.5, 1.0, probeMask.b );
        float probeBeard = clamp( probeMask.b * 2.0, 0.0, 1.0 ) * ( 1.0 - step( 0.5, probeMask.b ) );
        probeTone = mix( probeTone, uPalm * probeVariation, probePalm );
        probeTone = mix( probeTone, probeTone * vec3( 0.50, 0.52, 0.56 ), probeBeard * uStubble );

        // Layer 2, skin conditions. Vitiligo is depigmented skin, so it keeps every
        // bit of the surface and only loses its melanin.
        vec3 probeLayer = texture2D( uLayers, vMapUv ).rgb;
        if ( uVitiligo > 0.001 ) {
          float probeCut = 1.0 - uVitiligo * 0.42;
          float probePatch = smoothstep( probeCut - 0.03, probeCut + 0.03, probeLayer.g );
          probeTone = mix( probeTone, vec3( 0.60, 0.42, 0.34 ) * probeVariation, probePatch );
        }
        float probeFreckle = smoothstep( 1.0 - uFreckles, 1.0 - uFreckles + 0.28, probeLayer.r ) * step( 0.001, uFreckles );
        probeTone = mix( probeTone, probeTone * vec3( 0.36, 0.26, 0.22 ), probeFreckle * 0.95 );

        // Layer 3, age and scars. Scars heal lighter, and paler still on deep skin.
        probeTone *= 1.0 - probeLayer.b * uAge * 0.34;
        probeTone = mix( probeTone, probeTone * vec3( 0.93, 0.95, 0.97 ), uAge * 0.3 );
        vec3 probeMark = texture2D( uMarks, vMapUv ).rgb;
        float probeScar = dot( probeMark, uScarPick ) * uScarIntensity;
        vec3 probeHealed = mix( probeTone * vec3( 1.32, 1.16, 1.12 ) + vec3( 0.018, 0.010, 0.009 ), vec3( 0.46, 0.30, 0.27 ), 0.12 );
        probeTone = mix( probeTone, probeHealed, clamp( probeScar, 0.0, 1.0 ) * 0.85 );

        // Layer 4, tattoos. Ink sits in the skin, so it is tinted by the skin's own
        // shading and the pores and normals stay on top of it.
        float probeInk = dot( texture2D( uArt, vMapUv ).rgb, uTattooPick ) * uTattooOpacity;
        probeTone = mix( probeTone, uTattooColor * ( 0.45 + 0.55 * probeLuma ), clamp( probeInk, 0.0, 1.0 ) );

        // Layer 5, the natural lip, then cosmetics over everything.
        vec3 probeLip = mix( uLipLower, uLipUpper, probeMask.g ) * ( 0.62 + 0.30 * probeLuma );
        probeTone = mix( probeTone, probeLip, probeMask.r * 0.92 );
        vec3 probeZones = texture2D( uMakeup, vMapUv ).rgb;
        probeTone = mix( probeTone, uBlushColor * ( 0.5 + 0.5 * probeLuma ), probeZones.b * uBlushOpacity * 0.22 );
        probeTone = mix( probeTone, uEyeColor * ( 0.5 + 0.5 * probeLuma ), probeZones.r * uEyeOpacity * 0.85 );
        probeTone = mix( probeTone, vec3( 0.012, 0.009, 0.009 ), probeZones.g * uLiner );
        probeTone = mix( probeTone, uLipColor * ( 0.55 + 0.45 * probeLuma ), probeMask.r * uLipOpacity );
        diffuseColor.rgb = probeTone;`,
      )
      .replace(
        "#include <normal_fragment_maps>",
        `#include <normal_fragment_maps>
        // Height differences for creases and scars, in UV space.
        float probeHere = probeRelief( vMapUv );
        if ( probeHere > 0.001 || uAge + uScarIntensity * dot( uScarPick, vec3( 1.0 ) ) > 0.001 ) {
          float probeStep = 1.0 / 1024.0;
          float probeU = probeRelief( vMapUv + vec2( probeStep, 0.0 ) ) - probeHere;
          float probeV = probeRelief( vMapUv + vec2( 0.0, probeStep ) ) - probeHere;
          normal = normalize( normal + ( tbn[ 0 ] * probeU + tbn[ 1 ] * probeV ) * 1.1 );
        }
        vec4 probePore = texture2D( uPores, vNormalMapUv * 26.0 );
        normal = normalize( normal + ( tbn[ 0 ] * ( probePore.x * 2.0 - 1.0 ) + tbn[ 1 ] * ( probePore.y * 2.0 - 1.0 ) ) * 0.28 );
        roughnessFactor = clamp( roughnessFactor * mix( 1.0, 0.68, uShine ) + ( 1.0 - probePore.a ) * 0.16, 0.0, 1.0 );
        diffuseColor.rgb *= mix( 0.95, 1.0, probePore.a );
        // Glossy or matte lips, satin eyeshadow, skin that dries a little with age.
        roughnessFactor = mix( roughnessFactor, mix( 0.62, 0.14, uLipGloss ), probeMask.r * uLipOpacity );
        roughnessFactor = mix( roughnessFactor, 0.42, probeZones.r * uEyeOpacity * 0.6 );
        roughnessFactor = clamp( roughnessFactor + uAge * 0.06, 0.0, 1.0 );`,
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
    shader.uniforms.uIrisTint = mesh.name === "iris_L" ? irisUniforms.left : irisUniforms.right;
    shader.uniforms.uPupil = irisUniforms.pupil;
    shader.uniforms.uGlow = irisUniforms.glow;
    shader.fragmentShader = shader.fragmentShader
      .replace(
        "#include <common>",
        "#include <common>\nuniform vec3 uIrisTint;\nuniform float uPupil;\nuniform float uGlow;",
      )
      .replace(
        "#include <map_fragment>",
        `#ifdef USE_MAP
          // Parallax: the iris sits behind the cornea, so it slides against the view.
          vec3 probeEye = transpose( mat3( viewMatrix ) ) * normalize( vViewPosition );
          vec2 probeDisc = ( vMapUv - 0.5 ) * 2.0 - vec2( probeEye.x, -probeEye.y ) * 0.09;
          float probeR = length( probeDisc );
          // Pupil dilation pulls the iris fibres inward instead of drawing over them.
          float probeWant = mix( 0.13, 0.46, uPupil );
          float probeSource = probeR < probeWant
            ? probeR * ( 0.27 / probeWant )
            : 0.27 + ( probeR - probeWant ) * ( 0.73 / ( 1.0 - probeWant ) );
          vec2 probeSampleUv = 0.5 + 0.5 * probeDisc * ( probeSource / max( probeR, 0.0001 ) );
          vec4 probeIris = texture2D( map, probeSampleUv );
          float probeLum = dot( probeIris.rgb, vec3( 0.2126, 0.7152, 0.0722 ) );
          float probeBody = smoothstep( 0.015, 0.1, probeLum );
          diffuseColor.rgb = mix( uIrisTint * 0.04, uIrisTint * ( 0.26 + probeLum * 0.95 ), probeBody );
          diffuseColor.rgb *= mix( 0.42, 1.0, smoothstep( 0.10, 0.46, vMapUv.y ) );
        #endif`,
      )
      .replace(
        "#include <emissivemap_fragment>",
        `#include <emissivemap_fragment>
        totalEmissiveRadiance += uIrisTint * uGlow * 1.1 * smoothstep( 0.015, 0.1, probeLum );`,
      );
  };
  material.customProgramCacheKey = () => "probe-iris";
  mesh.material = material;
  mesh.renderOrder = 1;
}

function buildSclera(mesh: THREE.Mesh): void {
  const source = sourceMaterial(mesh);
  const material = new THREE.MeshPhysicalMaterial({
    map: source?.map ?? null,
    color: 0xc9c2ba,
    roughness: 0.34,
    metalness: 0,
    clearcoat: 0.10,
    clearcoatRoughness: 0.24,
    envMapIntensity: 0.28,
  });
  scleraMaterials.push(material);
  mesh.material = material;
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

const garmentPick = { top: new THREE.Vector3(1, 0, 0), bottom: new THREE.Vector3(1, 0, 0), shoes: new THREE.Vector3(1, 0, 0) };

function buildGarment(mesh: THREE.Mesh, colour: number, pick: THREE.Vector3, sole = 0): THREE.MeshPhysicalMaterial {
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
  // Folds share the body's UVs, so they sit where a body actually creases cloth.
  const folds = new THREE.TextureLoader().load(`${import.meta.env.BASE_URL}models/probe/skin_cloth.png`);
  folds.flipY = false;
  material.bumpMap = folds;
  material.bumpScale = 1.3;
  // Cut on the distance field baked per vertex, with a stitched-looking hem.
  material.onBeforeCompile = (shader) => {
    shader.vertexShader = shader.vertexShader
      .replace("#include <common>", "#include <common>\nattribute vec4 color;\nvarying vec3 vEdge;")
      .replace("#include <begin_vertex>", "#include <begin_vertex>\nvEdge = color.rgb;");
    shader.uniforms.uPick = { value: pick };
    shader.uniforms.uSole = { value: sole };
    shader.fragmentShader = shader.fragmentShader
      .replace("#include <common>", "#include <common>\nvarying vec3 vEdge;\nuniform vec3 uPick;\nuniform float uSole;")
      .replace(
        "#include <alphatest_fragment>",
        `float probeEdge = ( dot( vEdge, uPick ) - 0.5 ) * 6.0;
        float probeEdgeWidth = max( fwidth( probeEdge ), 0.0001 );
        diffuseColor.a = smoothstep( -probeEdgeWidth, probeEdgeWidth, probeEdge );
        if ( diffuseColor.a < 0.01 ) discard;
        diffuseColor.rgb *= mix( 0.74, 1.0, smoothstep( 0.32, 0.46, probeEdge ) );
        diffuseColor.rgb = mix( diffuseColor.rgb, vec3( 0.72, 0.70, 0.66 ), uSole * smoothstep( 0.5, 0.515, vEdge.g ) );`,
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
  ripple?: number;
  mode: number;
  width: number;
  taper: number;
  shine: number;
  capAlpha: number;
  capLow: number;
  capHigh: number;
};

function buildHairStrands(
  buffer: ArrayBuffer,
  followKeys: Map<string, number[]> = hairFollowKeys,
  material: THREE.ShaderMaterial = hairMaterial,
): { mesh: THREE.Mesh; params: HairParams } {
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
  for (const [name, affine] of Object.entries(meta.follow)) followKeys.set(name, affine);
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
  const mesh = new THREE.Mesh(geometry, material);
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
  hairUniforms.uRipple.value = params.ripple ?? 0;
  applyCap(params);
  renderer.shadowMap.needsUpdate = true;
}

const beardMaterial = hairMaterial.clone();
// Shares colour, light and gray with the hair; only the fit and strand set differ.
beardMaterial.uniforms = {
  ...hairUniforms,
  uFollow: { value: beardFollow },
  uStrandWidth: { value: 0.012 },
  uTaper: { value: 0.5 },
  uMode: { value: 0 },
  uShine: { value: 0.3 },
  uRipple: { value: 0 },
  uNudge: { value: 0.007 },
  uHighlightAmount: { value: 0 },
};

const beardCache = new Map<string, Promise<THREE.Mesh>>();
let activeBeard: THREE.Mesh | null = null;
let beardRequest = 0;

async function setBeard(id: string): Promise<void> {
  const request = (beardRequest += 1);
  if (id === "none") {
    if (activeBeard) character.remove(activeBeard);
    activeBeard = null;
    return;
  }
  let pending = beardCache.get(id);
  if (!pending) {
    pending = fetch(`${import.meta.env.BASE_URL}models/probe/hair/${id}.bin`)
      .then((response) => {
        if (!response.ok) throw new Error(`beard ${id} ${response.status}`);
        return response.arrayBuffer();
      })
      .then((buffer) => {
        const { mesh } = buildHairStrands(buffer, beardFollowKeys, beardMaterial);
        mesh.name = "beard";
        mesh.castShadow = false;
        mesh.customDepthMaterial = undefined;
        return mesh;
      });
    beardCache.set(id, pending);
  }
  const mesh = await pending;
  if (request !== beardRequest) return;
  if (activeBeard) character.remove(activeBeard);
  activeBeard = mesh;
  character.add(mesh);
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
        garmentMaterial = buildGarment(object, CLOTH_COLORS[0].value, garmentPick.top);
        // Its depth pass would use the uncut margin and print a zigzag on the skin.
        object.castShadow = false;
        break;
      case "trousers":
        trouserMaterial = buildGarment(object, 0x1e2024, garmentPick.bottom);
        object.castShadow = false;
        break;
      case "shoes":
        shoeMaterial = buildGarment(object, 0x1e2024, garmentPick.shoes, 1);
        shoeMesh = object;
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

function setGaze(lift: number): void {
  // The eye is a shell behind the lids, so gaze slides the iris across it.
  for (const part of eyeParts) part.position.y = lift;
}

function applyLight(name: string): void {
  const preset = LIGHT_PRESETS[name];
  if (!preset) return;
  renderer.shadowMap.needsUpdate = true;
  key.color.set(preset.key);
  key.intensity = preset.keyIntensity;
  key.position.copy(HEAD_CENTER).add(new THREE.Vector3(...preset.keyPosition));
  key.target.position.copy(HEAD_CENTER);
  fill.color.set(preset.fill);
  fill.intensity = preset.fillIntensity;
  fill.position.set(...preset.fillPosition);
  rim.color.set(preset.rim);
  rim.intensity = preset.rimIntensity;
  rim.position.set(...preset.rimPosition);
  hemisphere.color.set(preset.sky ?? 0xfff3e4);
  hemisphere.groundColor.set(preset.ground ?? 0x9c7a62);
  hemisphere.intensity = preset.ambient ?? 0.62;
  scene.environmentIntensity = preset.environment ?? 0.34;
  renderer.toneMappingExposure = preset.exposure;
  hairUniforms.uLightColor.value.set(preset.key).multiplyScalar(preset.keyIntensity);
  hairUniforms.uLightDirection.value.set(...preset.keyPosition).normalize();
  hairUniforms.uRimColor.value.set(preset.rim).multiplyScalar(preset.rimIntensity);
  hairUniforms.uRimDirection.value.set(...preset.rimPosition).normalize();
  hairUniforms.uFillColor.value.set(preset.fill).multiplyScalar(preset.fillIntensity);
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
  const base = VIEWS[name];
  if (!base) return;
  // Framing follows the character's height.
  const scale = character.scale.y;
  const view = {
    position: base.position.clone().setY(base.position.y * scale),
    target: base.target.clone().setY(base.target.y * scale),
    fov: base.fov,
  };
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

// ---- State to scene. Every control writes the store; only this reads it.
const store = createStore(defaultState());
const LIGHT_NAMES = Object.keys(LIGHT_PRESETS);
const FACE_REACH = 2.4;
const ALL_SLIDERS = [...BODY_SLIDERS, ...SHAPE_SLIDERS, ...FACE_SLIDERS, ...REFERENCE_SLIDERS];
const stateOptions = {
  tones: SKIN_TONES.map((tone) => tone.label),
  styles: HAIR_STYLES.map((style) => style.id),
  beards: BEARD_STYLES.map((style) => style.id),
  lights: LIGHT_NAMES,
  expressions: Object.keys(EXPRESSIONS),
  morphs: ALL_SLIDERS.map((def) => def.name),
};

function colorHex(value: number): string {
  return `#${value.toString(16).padStart(6, "0")}`;
}

function pick(vector: THREE.Vector3, index: number): void {
  vector.set(index === 1 ? 1 : 0, index === 2 ? 1 : 0, index === 3 ? 1 : 0);
}

let appliedHair = "";
let appliedBeard = "";
let appliedLight = "";
let appliedBody: BodyType | "" = "";
let appliedScale = 0;
let firstSync = true;

function syncScene(state: CharacterState): void {
  const instant = firstSync;
  firstSync = false;

  // Morphs: sliders, body type, expression.
  for (const def of ALL_SLIDERS) {
    const reach = def.name.startsWith("face_") && def.name !== "face_jaw" ? FACE_REACH : 1;
    // The closed-lid morph is authored without aperture hooding.
    const value = def.name === "feat_eye_hood" && state.expression === "blink" ? 0 : (state.morphs[def.name] ?? 0) * reach;
    setMorphTarget(def.name, value, instant);
  }
  const female = state.body.type === "female";
  setMorphTarget("build_female", female ? 1 : 0, instant);
  setMorphTarget("build_male", female ? 0 : 1, instant);
  setMorphTarget("brow_fine", female ? 1 : 0, instant);
  setMorphTarget("lash_long", female ? 1 : 0, instant);
  const expression = EXPRESSIONS[state.expression] ?? {};
  for (const target of EXPRESSION_TARGETS) setMorphTarget(target, expression[target] ?? 0, instant);
  setGaze(state.expression === "curious" ? 0.0016 : 0);

  // Women are a little shorter on average; the slider works from there.
  const scale = state.body.height * (female ? 0.96 : 1);
  if (scale !== appliedScale || state.body.type !== appliedBody) {
    appliedScale = scale;
    appliedBody = state.body.type;
    character.scale.setScalar(scale);
    hairUniforms.uCharacterScale.value = scale;
    HEAD_CENTER.y = 1.655 * scale;
    appliedLight = "";
  }
  if (state.light !== appliedLight) {
    appliedLight = state.light;
    applyLight(state.light);
  }

  // Skin.
  const skin = state.skin;
  const tone = SKIN_TONES.find((item) => item.label === skin.tone) ?? SKIN_TONES[2];
  skinUniforms.uSkinTone.value.setHex(tone.value);
  skinUniforms.uLipUpper.value.setHex(tone.lipUpper);
  skinUniforms.uLipLower.value.setHex(tone.lipLower);
  skinUniforms.uPalm.value.setHex(tone.palm);
  skinUniforms.uShine.value = tone.shine;
  if (skinMaterial) skinMaterial.specularIntensity = 0.36 + 0.34 * tone.shine;
  // Terminator colour follows the skin: warm brown in deep tones, red in pale ones.
  const depth = 1 - Math.min(1, new THREE.Color(tone.value).getHSL({ h: 0, s: 0, l: 0 }).l * 1.5);
  sssUniforms.color.value.set(0xff5a3a).lerp(new THREE.Color(0x9c5a38), depth);
  sssUniforms.strength.value = skin.scatter;
  // A beard grows from shaded skin, whatever the stubble slider says.
  skinUniforms.uStubble.value = state.hair.beard === "none" ? skin.stubble : Math.max(skin.stubble, 0.9);
  skinUniforms.uUndertone.value = skin.undertone;
  skinUniforms.uContrast.value = skin.contrast;
  skinUniforms.uAge.value = skin.age;
  skinUniforms.uFreckles.value = skin.freckles;
  skinUniforms.uVitiligo.value = skin.vitiligo;
  pick(skinUniforms.uScarPick.value, skin.scar);
  skinUniforms.uScarIntensity.value = skin.scarIntensity;
  pick(skinUniforms.uTattooPick.value, skin.tattoo);
  skinUniforms.uTattooColor.value.setStyle(skin.tattooColor);
  skinUniforms.uTattooOpacity.value = skin.tattooOpacity;
  skinUniforms.uLipColor.value.setStyle(skin.lipColor);
  skinUniforms.uLipOpacity.value = skin.lipOpacity;
  skinUniforms.uLipGloss.value = skin.lipGloss;
  skinUniforms.uEyeColor.value.setStyle(skin.eyeColor);
  skinUniforms.uEyeOpacity.value = skin.eyeOpacity;
  skinUniforms.uLiner.value = skin.liner;
  skinUniforms.uBlushColor.value.setStyle(skin.blushColor);
  skinUniforms.uBlushOpacity.value = skin.blushOpacity;

  // Eyes.
  irisUniforms.left.value.setStyle(state.eyes.left);
  irisUniforms.right.value.setStyle(state.eyes.right);
  irisUniforms.pupil.value = state.eyes.pupil;
  irisUniforms.glow.value = state.eyes.glow;
  for (const material of scleraMaterials) material.color.setRGB(state.eyes.sclera, state.eyes.sclera * 0.965, state.eyes.sclera * 0.92);

  // Hair.
  hairUniforms.uColor.value.setStyle(state.hair.color);
  hairUniforms.uHighlight.value.setStyle(state.hair.highlights);
  hairUniforms.uHighlightAmount.value = state.hair.highlightAmount;
  hairUniforms.uGraying.value = state.hair.graying;
  browsMaterial?.color.setStyle(state.hair.color).multiplyScalar(0.62).lerp(new THREE.Color(0x7c7a76), state.hair.graying * 0.7);
  if (state.hair.style !== appliedHair) {
    appliedHair = state.hair.style;
    void setHairStyle(state.hair.style);
  }
  if (state.hair.beard !== appliedBeard) {
    appliedBeard = state.hair.beard;
    void setBeard(state.hair.beard);
  }

  garmentMaterial?.color.setStyle(state.cloth);
  const outfit = state.outfit;
  pick(garmentPick.top, TOP_CUTS.findIndex((cut) => cut.id === outfit.top) + 1);
  pick(garmentPick.bottom, BOTTOM_CUTS.findIndex((cut) => cut.id === outfit.bottom) + 1);
  setMorphTarget("garment_loose", outfit.topFit, instant);
  setMorphTarget("trousers_loose", outfit.bottom === "trousers" ? outfit.bottomFit : outfit.bottomFit * 0.5, instant);
  trouserMaterial?.color.setStyle(outfit.bottomColor);
  shoeMaterial?.color.setStyle(outfit.shoeColor);
  if (shoeMesh) shoeMesh.visible = outfit.shoes;
}

store.subscribe(syncScene);

// ---- Controls. Each registers how to reflect the state, so an imported character
// or a look moves every slider and swatch without further code.
const controlSyncs: Array<(state: CharacterState) => void> = [];
store.subscribe((state) => {
  for (const sync of controlSyncs) sync(state);
});

function buildRange(
  hostElement: HTMLElement,
  id: string,
  label: string,
  range: [number, number, number],
  read: (state: CharacterState) => number,
  write: (state: CharacterState, value: number) => void,
): void {
  const row = document.createElement("label");
  row.className = "probe-range";
  row.htmlFor = id;
  const head = document.createElement("span");
  head.className = "probe-range-label";
  const name = document.createElement("span");
  name.textContent = label;
  const output = document.createElement("output");
  head.append(name, output);
  const input = document.createElement("input");
  input.id = id;
  input.type = "range";
  [input.min, input.max, input.step] = range.map(String);
  input.addEventListener("input", () => {
    store.update((state) => {
      write(state, Number(input.value));
      state.look = null;
    });
  });
  row.append(head, input);
  hostElement.append(row);
  controlSyncs.push((state) => {
    const value = read(state);
    if (document.activeElement !== input || Number(input.value) !== value) input.value = String(value);
    output.textContent = value.toFixed(2);
  });
}

function buildMorphRanges(hostSelector: string, defs: SliderDef[]): void {
  const hostElement = must<HTMLElement>(hostSelector);
  for (const def of defs) {
    buildRange(
      hostElement,
      `morph-${def.name}`,
      def.label,
      [-1, 1, 0.01],
      (state) => state.morphs[def.name] ?? 0,
      (state, value) => {
        state.morphs[def.name] = value;
      },
    );
  }
}

function buildSwatches(
  hostSelector: string,
  options: Array<{ label: string; value: number }>,
  read: (state: CharacterState) => string,
  write: (state: CharacterState, hex: string, label: string) => void,
): void {
  const hostElement = must<HTMLElement>(hostSelector);
  const buttons = options.map((option) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "probe-swatch";
    button.title = option.label;
    button.setAttribute("aria-label", option.label);
    const hex = colorHex(option.value);
    button.dataset.hex = hex;
    button.style.background = hex;
    button.addEventListener("click", () => {
      store.update((state) => {
        write(state, hex, option.label);
        state.look = null;
      });
    });
    hostElement.append(button);
    return button;
  });
  controlSyncs.push((state) => {
    const current = read(state);
    for (const button of buttons) {
      const active = button.dataset.hex === current || button.title === current;
      button.classList.toggle("is-active", active);
      button.setAttribute("aria-pressed", String(active));
    }
  });
}

function buildChips(
  hostSelector: string,
  options: Array<{ id: string; label: string }>,
  read: (state: CharacterState) => string | null,
  write: (id: string) => void,
): void {
  const hostElement = must<HTMLElement>(hostSelector);
  const buttons = options.map((option) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = option.label;
    button.dataset.id = option.id;
    button.addEventListener("click", () => write(option.id));
    hostElement.append(button);
    return button;
  });
  controlSyncs.push((state) => {
    const current = read(state);
    for (const button of buttons) {
      const active = button.dataset.id === current;
      button.classList.toggle("is-active", active);
      button.setAttribute("aria-pressed", String(active));
    }
  });
}

const titled = (items: string[]): Array<{ id: string; label: string }> =>
  items.map((label) => ({ id: label.toLowerCase(), label }));

function lookState(look: Look): CharacterState {
  const state = defaultState();
  const hexOf = (list: Array<{ label: string; value: number }>, label: string): string =>
    colorHex((list.find((item) => item.label === label) ?? list[0]).value);
  state.look = look.id;
  state.body.type = look.body;
  state.morphs = { ...look.shape };
  state.skin.tone = look.skin;
  state.skin.stubble = look.stubble ?? 0;
  state.skin.age = look.body === "female" ? 0.08 : 0.16;
  state.hair.style = look.hair;
  state.hair.beard = look.beard ?? "none";
  state.hair.color = hexOf(HAIR_COLORS, look.hairColor);
  state.eyes.left = state.eyes.right = hexOf(IRIS_COLORS, look.iris);
  state.cloth = hexOf(CLOTH_COLORS, look.cloth);
  state.light = store.get().light;
  Object.assign(state.outfit, LOOK_OUTFITS[look.id] ?? {});
  return state;
}

function applyLook(look: Look): void {
  store.replace(lookState(look));
}

function randomize(): void {
  const any = <T,>(items: readonly T[]): T => items[Math.floor(Math.random() * items.length)];
  const spread = (amount: number): number => (Math.random() * 2 - 1) * amount;
  const state = defaultState();
  state.light = store.get().light;
  state.body.type = Math.random() < 0.5 ? "female" : "male";
  state.body.height = 0.97 + Math.random() * 0.06;
  state.skin.tone = any(SKIN_TONES).label;
  state.skin.undertone = spread(0.4);
  state.hair.style = any(HAIR_STYLES).id;
  state.hair.color = colorHex(any(HAIR_COLORS.slice(0, 5)).value);
  // Dark eyes are the norm, and nearly universal on deep skin.
  const toneIndex = SKIN_TONES.findIndex((tone) => tone.label === state.skin.tone);
  const lightEyes = toneIndex < 5 ? 0.06 : 0.35;
  const eye = colorHex(Math.random() < lightEyes ? any(IRIS_COLORS).value : IRIS_COLORS[0].value);
  state.eyes.left = state.eyes.right = eye;
  state.cloth = colorHex(any(CLOTH_COLORS).value);
  state.outfit.top = any(TOP_CUTS).id;
  state.outfit.topFit = Math.random() * 0.8;
  state.outfit.bottom = Math.random() < 0.85 ? "trousers" : "shorts";
  state.outfit.bottomFit = Math.random() * 0.9;
  state.outfit.bottomColor = colorHex(any(BOTTOM_COLORS).value);
  state.outfit.shoeColor = colorHex(any(SHOE_COLORS).value);
  // Stay inside the ranges that were tuned to look good, like a curated preset.
  state.morphs = { ...FACE_SHAPES[any(Object.keys(FACE_SHAPES))] };
  for (const def of FACE_SLIDERS) state.morphs[def.name] = def.name === "face_jaw" ? spread(0.2) : spread(0.55);
  state.morphs.feat_lips = Math.random() * 0.9;
  state.morphs.feat_nose_wide = Math.random() * 0.8;
  state.morphs.feat_nose_bridge = Math.random() * 0.5;
  for (const def of BODY_SLIDERS) state.morphs[def.name] = spread(0.45);
  state.skin.freckles = Math.random() < 0.3 ? Math.random() * 0.6 : 0;
  state.skin.age = 0.1 + (Math.random() < 0.3 ? Math.random() * 0.4 : Math.random() * 0.1);
  if (state.body.type === "male") {
    state.skin.stubble = Math.random() * 0.8;
    state.hair.beard = any(BEARD_STYLES).id;
  } else if (Math.random() < 0.5) {
    state.skin.lipOpacity = 0.25 + Math.random() * 0.45;
    state.skin.lipColor = colorHex(any(LIP_COLORS).value);
    state.skin.eyeOpacity = Math.random() * 0.4;
  }
  state.expression = "neutral";
  store.replace(state);
}

function exportState(): void {
  const blob = new Blob([JSON.stringify(store.get(), null, 2)], { type: "application/json" });
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = "character.json";
  link.click();
  URL.revokeObjectURL(link.href);
}

async function importState(file: File): Promise<void> {
  const note = must<HTMLElement>("#probe-file-note");
  try {
    store.replace(sanitizeState(JSON.parse(await file.text()), stateOptions));
    note.textContent = `Loaded ${file.name}`;
  } catch {
    note.textContent = "That file is not a character.";
  }
}

const TATTOO_COLORS = [
  { label: "Ink", value: 0x14202a },
  { label: "Indigo", value: 0x1f2a5c },
  { label: "Rust", value: 0x6e2a18 },
  { label: "Forest", value: 0x1e3a2a },
  { label: "White", value: 0xd8d4cc },
];
const LIP_COLORS = [
  { label: "Berry", value: 0x6b1f35 },
  { label: "Brick", value: 0x8a3322 },
  { label: "Nude", value: 0x9c6a58 },
  { label: "Plum", value: 0x4a1f3a },
  { label: "Red", value: 0xa11a22 },
  { label: "Coral", value: 0xc4553f },
];
const EYE_COLORS = [
  { label: "Bronze", value: 0x6b4426 },
  { label: "Plum", value: 0x4a2440 },
  { label: "Gold", value: 0xb08a3c },
  { label: "Teal", value: 0x1c5a5e },
  { label: "Smoke", value: 0x2b2a2c },
];
const BLUSH_COLORS = [
  { label: "Terracotta", value: 0xa8483c },
  { label: "Rose", value: 0xc05a68 },
  { label: "Plum", value: 0x7a2c50 },
];
const HIGHLIGHT_COLORS = [
  { label: "Copper", value: 0x8c5230 },
  { label: "Honey", value: 0xb88a4a },
  { label: "Burgundy", value: 0x6a1a2a },
  { label: "Blonde", value: 0xd2b070 },
  { label: "Blue", value: 0x2a4a8c },
];

buildChips("#probe-looks", LOOKS, (state) => state.look, (id) => {
  const look = LOOKS.find((item) => item.id === id);
  if (look) applyLook(look);
});
buildChips("#probe-build", titled(["Female", "Male"]), (state) => state.body.type, (id) => {
  store.update((state) => {
    state.body.type = id as BodyType;
    state.look = null;
  });
});
const rangeHost = (selector: string): HTMLElement => must<HTMLElement>(selector);
buildRange(rangeHost("#probe-height"), "state-height", "Height", [0.92, 1.08, 0.005], (s) => s.body.height, (s, v) => {
  s.body.height = v;
});
buildMorphRanges("#probe-body", BODY_SLIDERS);
const outfitChips = (host: string, cuts: Array<{ id: string; label: string }>, read: (s: CharacterState) => string, write: (s: CharacterState, id: string) => void): void =>
  buildChips(host, cuts, read, (id) => {
    store.update((s) => {
      write(s, id);
      s.look = null;
    });
  });
outfitChips("#probe-top", TOP_CUTS, (s) => s.outfit.top, (s, id) => {
  s.outfit.top = id;
});
buildSwatches("#probe-cloth", CLOTH_COLORS, (s) => s.cloth, (s, hex) => {
  s.cloth = hex;
});
buildRange(rangeHost("#probe-top-range"), "outfit-top-fit", "Fitted to relaxed", [0, 1, 0.01], (s) => s.outfit.topFit, (s, v) => {
  s.outfit.topFit = v;
});
outfitChips("#probe-bottom", BOTTOM_CUTS, (s) => s.outfit.bottom, (s, id) => {
  s.outfit.bottom = id;
});
buildSwatches("#probe-bottom-color", BOTTOM_COLORS, (s) => s.outfit.bottomColor, (s, hex) => {
  s.outfit.bottomColor = hex;
});
buildRange(rangeHost("#probe-bottom-range"), "outfit-bottom-fit", "Slim to straight", [0, 1, 0.01], (s) => s.outfit.bottomFit, (s, v) => {
  s.outfit.bottomFit = v;
});
outfitChips("#probe-shoes", [{ id: "on", label: "Shoes" }, { id: "off", label: "Barefoot" }], (s) => (s.outfit.shoes ? "on" : "off"), (s, id) => {
  s.outfit.shoes = id === "on";
});
buildSwatches("#probe-shoe-color", SHOE_COLORS, (s) => s.outfit.shoeColor, (s, hex) => {
  s.outfit.shoeColor = hex;
});

buildChips("#probe-face-shapes", titled(Object.keys(FACE_SHAPES)), () => null, (id) => {
  const name = Object.keys(FACE_SHAPES).find((item) => item.toLowerCase() === id) ?? "Oval";
  store.update((state) => {
    for (const def of SHAPE_SLIDERS) state.morphs[def.name] = FACE_SHAPES[name][def.name] ?? 0;
    state.look = null;
  });
});
buildMorphRanges("#probe-shape", SHAPE_SLIDERS);
buildMorphRanges("#probe-face", [...REFERENCE_SLIDERS, ...FACE_SLIDERS]);
buildChips("#probe-expressions", titled(Object.keys(EXPRESSIONS)), (state) => state.expression, (id) => {
  store.update((state) => {
    state.expression = id;
  });
});

const percent: [number, number, number] = [0, 1, 0.01];
const skinRange = (host: string, id: keyof CharacterState["skin"], label: string, range = percent): void =>
  buildRange(rangeHost(host), `skin-${id}`, label, range, (s) => s.skin[id] as number, (s, v) => {
    (s.skin[id] as number) = v;
  });

buildSwatches("#probe-skin", SKIN_TONES, (s) => s.skin.tone, (s, _hex, label) => {
  s.skin.tone = label;
});
skinRange("#probe-skin-base", "undertone", "Undertone, cool to warm", [-1, 1, 0.01]);
skinRange("#probe-skin-base", "contrast", "Skin definition");
skinRange("#probe-skin-base", "scatter", "Light scatter");
skinRange("#probe-skin-conditions", "age", "Age");
skinRange("#probe-skin-conditions", "freckles", "Freckles");
skinRange("#probe-skin-conditions", "vitiligo", "Vitiligo");
skinRange("#probe-skin-conditions", "stubble", "Stubble");
const numbered = (name: string, count: number): Array<{ id: string; label: string }> => [
  { id: "0", label: "None" },
  ...Array.from({ length: count }, (_, index) => ({ id: String(index + 1), label: `${name} ${index + 1}` })),
];
buildChips("#probe-scars", numbered("Scar", SCAR_COUNT), (s) => String(s.skin.scar), (id) => {
  store.update((s) => {
    s.skin.scar = Number(id);
    s.look = null;
  });
});
skinRange("#probe-scar-range", "scarIntensity", "Scar strength");

buildChips("#probe-tattoos", [
  { id: "0", label: "None" },
  { id: "1", label: "Forearm" },
  { id: "2", label: "Upper arm" },
  { id: "3", label: "Neck" },
], (s) => String(s.skin.tattoo), (id) => {
  store.update((s) => {
    s.skin.tattoo = Number(id);
    s.look = null;
  });
  if (id === "1" || id === "2") applyView("full");
  if (id === "3") applyView("three");
});
buildSwatches("#probe-tattoo-color", TATTOO_COLORS, (s) => s.skin.tattooColor, (s, hex) => {
  s.skin.tattooColor = hex;
});
skinRange("#probe-tattoo-range", "tattooOpacity", "Ink strength");
buildSwatches("#probe-lip-color", LIP_COLORS, (s) => s.skin.lipColor, (s, hex) => {
  s.skin.lipColor = hex;
});
skinRange("#probe-lip-range", "lipOpacity", "Lip colour");
skinRange("#probe-lip-range", "lipGloss", "Matte to gloss");
buildSwatches("#probe-eye-color", EYE_COLORS, (s) => s.skin.eyeColor, (s, hex) => {
  s.skin.eyeColor = hex;
});
skinRange("#probe-eye-range", "eyeOpacity", "Eyeshadow");
skinRange("#probe-eye-range", "liner", "Eyeliner");
buildSwatches("#probe-blush-color", BLUSH_COLORS, (s) => s.skin.blushColor, (s, hex) => {
  s.skin.blushColor = hex;
});
skinRange("#probe-blush-range", "blushOpacity", "Blush");

buildChips("#probe-styles", HAIR_STYLES, (s) => s.hair.style, (id) => {
  store.update((s) => {
    s.hair.style = id;
    s.look = null;
  });
});
buildChips("#probe-beards", BEARD_STYLES, (s) => s.hair.beard, (id) => {
  store.update((s) => {
    s.hair.beard = id;
    s.look = null;
  });
  if (id !== "none") applyView("three");
});
buildSwatches("#probe-hair", HAIR_COLORS, (s) => s.hair.color, (s, hex) => {
  s.hair.color = hex;
});
buildSwatches("#probe-highlights", HIGHLIGHT_COLORS, (s) => s.hair.highlights, (s, hex) => {
  s.hair.highlights = hex;
});
buildRange(rangeHost("#probe-hair-range"), "hair-highlight", "Highlights", percent, (s) => s.hair.highlightAmount, (s, v) => {
  s.hair.highlightAmount = v;
});
buildRange(rangeHost("#probe-hair-range"), "hair-gray", "Gray", percent, (s) => s.hair.graying, (s, v) => {
  s.hair.graying = v;
});
buildSwatches("#probe-iris", IRIS_COLORS, (s) => s.eyes.left, (s, hex) => {
  s.eyes.left = hex;
  s.eyes.right = hex;
});
buildSwatches("#probe-iris-right", IRIS_COLORS, (s) => s.eyes.right, (s, hex) => {
  s.eyes.right = hex;
});
buildRange(rangeHost("#probe-eye-state"), "eye-pupil", "Pupil size", percent, (s) => s.eyes.pupil, (s, v) => {
  s.eyes.pupil = v;
});
buildRange(rangeHost("#probe-eye-state"), "eye-sclera", "Eye whites", [0.3, 1, 0.01], (s) => s.eyes.sclera, (s, v) => {
  s.eyes.sclera = v;
});
buildRange(rangeHost("#probe-eye-state"), "eye-glow", "Glow", percent, (s) => s.eyes.glow, (s, v) => {
  s.eyes.glow = v;
});

buildChips("#probe-light", titled(LIGHT_NAMES.map((name) => name[0].toUpperCase() + name.slice(1))), (s) => s.light, (id) => {
  store.update((s) => {
    s.light = id;
  });
});

// Each tab frames what it edits.
const TAB_VIEWS: Record<string, ViewName> = {
  identity: "full",
  face: "three",
  skin: "macro",
  art: "face",
  hair: "bust",
};

function openTab(id: string): void {
  for (const button of document.querySelectorAll<HTMLButtonElement>("#probe-tabs button")) {
    const active = button.dataset.tab === id;
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-selected", String(active));
    button.tabIndex = active ? 0 : -1;
  }
  for (const panel of document.querySelectorAll<HTMLElement>(".probe-tab-panel")) {
    panel.hidden = panel.dataset.panel !== id;
  }
  must<HTMLElement>(".probe-panel").scrollTop = must<HTMLElement>("#probe-tabs").offsetTop - 12;
  applyView(TAB_VIEWS[id] ?? "three");
}

const tabButtons = [...document.querySelectorAll<HTMLButtonElement>("#probe-tabs button")];
for (const [index, button] of tabButtons.entries()) {
  button.addEventListener("click", () => openTab(button.dataset.tab ?? "identity"));
  button.addEventListener("keydown", (event) => {
    const step = event.key === "ArrowRight" ? 1 : event.key === "ArrowLeft" ? -1 : 0;
    if (!step) return;
    const next = tabButtons[(index + step + tabButtons.length) % tabButtons.length];
    next.focus();
    openTab(next.dataset.tab ?? "identity");
  });
}
for (const button of document.querySelectorAll<HTMLButtonElement>("#probe-views button")) {
  button.addEventListener("click", () => applyView((button.dataset.view as ViewName) ?? "bust"));
}
must<HTMLButtonElement>("#probe-reset").addEventListener("click", () => {
  store.update((state) => {
    state.morphs = {};
    state.expression = "neutral";
    state.look = null;
  });
});
must<HTMLButtonElement>("#probe-randomize").addEventListener("click", randomize);
must<HTMLButtonElement>("#probe-export").addEventListener("click", exportState);
const importInput = must<HTMLInputElement>("#probe-import-file");
must<HTMLButtonElement>("#probe-import").addEventListener("click", () => importInput.click());
importInput.addEventListener("change", () => {
  const file = importInput.files?.[0];
  if (file) void importState(file);
  importInput.value = "";
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

let lastFrame = performance.now();

function animate(): void {
  requestAnimationFrame(animate);
  const frameStart = performance.now();
  easeMorphs((frameStart - lastFrame) / 1000);
  lastFrame = frameStart;

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
    applyLook(LOOKS[0]);
    openTab("identity");
    applyView("three", true);
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
        store,
        openTab,
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
