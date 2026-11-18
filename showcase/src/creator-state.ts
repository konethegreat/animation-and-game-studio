// The single source of truth for the character. Every control writes here and the
// scene reads from here, so a look, a randomized character and an imported JSON
// file are all just values of this one type.

export type BodyType = "female" | "male";

export type CharacterState = {
  version: 1;
  look: string | null;
  expression: string;
  light: string;
  cloth: string;
  outfit: {
    top: string;
    topFit: number;
    bottom: string;
    bottomFit: number;
    bottomColor: string;
    shoes: boolean;
    shoeColor: string;
  };
  body: { type: BodyType; height: number };
  morphs: Record<string, number>;
  skin: {
    tone: string;
    undertone: number;
    contrast: number;
    scatter: number;
    age: number;
    freckles: number;
    vitiligo: number;
    stubble: number;
    scar: number;
    scarIntensity: number;
    tattoo: number;
    tattooColor: string;
    tattooOpacity: number;
    lipColor: string;
    lipOpacity: number;
    lipGloss: number;
    eyeColor: string;
    eyeOpacity: number;
    liner: number;
    blushColor: string;
    blushOpacity: number;
  };
  eyes: { left: string; right: string; sclera: number; pupil: number; glow: number };
  hair: { style: string; beard: string; color: string; highlights: string; highlightAmount: number; graying: number };
};

export const SCAR_COUNT = 3;
export const TATTOO_COUNT = 3;

export function defaultState(): CharacterState {
  return {
    version: 1,
    look: null,
    expression: "neutral",
    light: "softbox",
    cloth: "#23272f",
    outfit: { top: "tank", topFit: 0, bottom: "trousers", bottomFit: 0, bottomColor: "#1e2024", shoes: true, shoeColor: "#17181b" },
    body: { type: "female", height: 1 },
    morphs: {},
    skin: {
      tone: "Umber",
      undertone: 0,
      contrast: 0.5,
      scatter: 0.24,
      age: 0,
      freckles: 0,
      vitiligo: 0,
      stubble: 0,
      scar: 0,
      scarIntensity: 0.7,
      tattoo: 0,
      tattooColor: "#14202a",
      tattooOpacity: 0.85,
      lipColor: "#6b1f35",
      lipOpacity: 0,
      lipGloss: 0.3,
      eyeColor: "#6b4426",
      eyeOpacity: 0,
      liner: 0,
      blushColor: "#a8483c",
      blushOpacity: 0,
    },
    eyes: { left: "#4e2f1c", right: "#4e2f1c", sclera: 0.6, pupil: 0.5, glow: 0 },
    hair: { style: "afro", beard: "none", color: "#1b1513", highlights: "#8c5230", highlightAmount: 0, graying: 0 },
  };
}

export type StateOptions = {
  tones: readonly string[];
  styles: readonly string[];
  beards: readonly string[];
  lights: readonly string[];
  expressions: readonly string[];
  morphs: readonly string[];
};

function clamp(value: unknown, low: number, high: number, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? Math.min(high, Math.max(low, value)) : fallback;
}

function hex(value: unknown, fallback: string): string {
  return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value) ? value.toLowerCase() : fallback;
}

function choice(value: unknown, allowed: readonly string[], fallback: string): string {
  return typeof value === "string" && allowed.includes(value) ? value : fallback;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function record(value: unknown): Record<string, unknown> {
  return isRecord(value) ? value : {};
}

// Reject unrelated JSON before sanitizing values that can become asset URLs.
export function sanitizeState(input: unknown, options: StateOptions): CharacterState {
  if (
    !isRecord(input) || input.version !== 1 ||
    ["body", "skin", "eyes", "hair", "morphs"].some((key) => !isRecord(input[key])) ||
    (input.outfit !== undefined && !isRecord(input.outfit))
  ) {
    throw new Error("Not a version 1 character document.");
  }
  const base = defaultState();
  const root = input;
  const body = record(root.body);
  const outfit = record(root.outfit);
  const skin = record(root.skin);
  const eyes = record(root.eyes);
  const hair = record(root.hair);
  const incoming = record(root.morphs);
  const morphs: Record<string, number> = {};
  for (const name of options.morphs) {
    if (name in incoming) morphs[name] = clamp(incoming[name], -1, 1, 0);
  }
  return {
    version: 1,
    look: null,
    expression: choice(root.expression, options.expressions, base.expression),
    light: choice(root.light, options.lights, base.light),
    cloth: hex(root.cloth, base.cloth),
    outfit: {
      top: choice(outfit.top, ["tank", "tee", "long"], base.outfit.top),
      topFit: clamp(outfit.topFit, 0, 1, 0),
      bottom: choice(outfit.bottom, ["trousers", "shorts"], base.outfit.bottom),
      bottomFit: clamp(outfit.bottomFit, 0, 1, 0),
      bottomColor: hex(outfit.bottomColor, base.outfit.bottomColor),
      shoes: outfit.shoes !== false,
      shoeColor: hex(outfit.shoeColor, base.outfit.shoeColor),
    },
    body: {
      type: body.type === "male" ? "male" : "female",
      height: clamp(body.height, 0.92, 1.08, base.body.height),
    },
    morphs,
    skin: {
      tone: choice(skin.tone, options.tones, base.skin.tone),
      undertone: clamp(skin.undertone, -1, 1, 0),
      contrast: clamp(skin.contrast, 0, 1, 0.5),
      scatter: clamp(skin.scatter, 0, 1, base.skin.scatter),
      age: clamp(skin.age, 0, 1, 0),
      freckles: clamp(skin.freckles, 0, 1, 0),
      vitiligo: clamp(skin.vitiligo, 0, 1, 0),
      stubble: clamp(skin.stubble, 0, 1, 0),
      scar: Math.round(clamp(skin.scar, 0, SCAR_COUNT, 0)),
      scarIntensity: clamp(skin.scarIntensity, 0, 1, base.skin.scarIntensity),
      tattoo: Math.round(clamp(skin.tattoo, 0, TATTOO_COUNT, 0)),
      tattooColor: hex(skin.tattooColor, base.skin.tattooColor),
      tattooOpacity: clamp(skin.tattooOpacity, 0, 1, base.skin.tattooOpacity),
      lipColor: hex(skin.lipColor, base.skin.lipColor),
      lipOpacity: clamp(skin.lipOpacity, 0, 1, 0),
      lipGloss: clamp(skin.lipGloss, 0, 1, base.skin.lipGloss),
      eyeColor: hex(skin.eyeColor, base.skin.eyeColor),
      eyeOpacity: clamp(skin.eyeOpacity, 0, 1, 0),
      liner: clamp(skin.liner, 0, 1, 0),
      blushColor: hex(skin.blushColor, base.skin.blushColor),
      blushOpacity: clamp(skin.blushOpacity, 0, 1, 0),
    },
    eyes: {
      left: hex(eyes.left, base.eyes.left),
      right: hex(eyes.right, base.eyes.right),
      sclera: clamp(eyes.sclera, 0.3, 1, base.eyes.sclera),
      pupil: clamp(eyes.pupil, 0, 1, base.eyes.pupil),
      glow: clamp(eyes.glow, 0, 1, 0),
    },
    hair: {
      style: choice(hair.style, options.styles, base.hair.style),
      beard: choice(hair.beard, options.beards, base.hair.beard),
      color: hex(hair.color, base.hair.color),
      highlights: hex(hair.highlights, base.hair.highlights),
      highlightAmount: clamp(hair.highlightAmount, 0, 1, 0),
      graying: clamp(hair.graying, 0, 1, 0),
    },
  };
}

export type StateListener = (state: CharacterState) => void;

export type CharacterStore = {
  get: () => CharacterState;
  update: (change: (state: CharacterState) => void) => void;
  replace: (next: CharacterState) => void;
  subscribe: (listener: StateListener) => void;
};

export function createStore(initial: CharacterState): CharacterStore {
  let state = initial;
  const listeners: StateListener[] = [];
  const notify = (): void => {
    for (const listener of listeners) listener(state);
  };
  return {
    get: () => state,
    update: (change) => {
      change(state);
      notify();
    },
    replace: (next) => {
      state = next;
      notify();
    },
    subscribe: (listener) => {
      listeners.push(listener);
    },
  };
}
