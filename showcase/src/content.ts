export const REPO = "https://github.com/konethegreat/animation-and-game-studio";

export const TYPE_LABEL: Record<string, string> = {
  "2d": "2D animation",
  "3d": "3D character",
  game: "Playable game",
};

export const ENGINE_LABEL: Record<string, string> = {
  python: "Python + Pillow",
  blender: "Blender 4.5 LTS",
  godot: "Godot 4.7.2",
};

export type ProjectNotes = {
  madeWith: string[];
  notes: string[];
};

export const NOTES: Record<string, ProjectNotes> = {
  "001-2d-bounce": {
    madeWith: ["Python", "Pillow", "FFmpeg"],
    notes: [
      "Bounce height, squash and impact dust are functions of one looping time value, so the motion is deterministic and re-renderable.",
      "Squash and stretch is driven by contact and velocity, with a small anticipation before each launch.",
      "Frames render at 1920 by 1080. The same source encodes to MP4, WebM, GIF and the poster on this page.",
    ],
  },
  "002-turntable": {
    madeWith: ["Blender 4.5 LTS", "Python", "EEVEE Next", "glTF"],
    notes: [
      "The robot, studio lights and pedestal are built procedurally in Blender Python. There are no imported models or textures.",
      "A 192 frame turntable loop closes seamlessly at 24 fps, with a slow hover, head drift and swinging antenna.",
      "The same scene exports a glTF binary that powers the live viewer on this site.",
    ],
  },
  "003-micro-game": {
    madeWith: ["Godot 4.7.2", "GDScript", "Web export"],
    notes: [
      "One screen, one ship, two verbs: collect stars and dodge rocks. Difficulty ramps as the score climbs.",
      "The best score persists in a local config file. Sound effects are generated from raw waveforms by a small Python script.",
      "The web build runs at 60 fps in a 960 by 540 canvas and does not need cross-origin isolation headers.",
    ],
  },
  "004-lantern-keeper": {
    madeWith: ["Blender 4.5 LTS", "Python", "EEVEE Next", "glTF"],
    notes: [
      "The keeper is built from primitives parented to an empty joint chain. There is no armature and no imported model or texture.",
      "Three steps, a pause and a lantern lift are keyed over five seconds. A spline camera dollies in and arcs about 66 degrees to a three quarter hero angle.",
      "The exported glTF is an in place walk loop, so the keeper walks on the spot in the live viewer while you orbit the camera.",
    ],
  },
};

export const PIPELINE = [
  {
    no: "01",
    title: "Write it as code",
    body: "Scenes, characters and levels are scripts and manifests, not opaque project files. Every choice is readable and reviewable.",
  },
  {
    no: "02",
    title: "Render headless",
    body: "Blender and Pillow render frames. FFmpeg encodes them and checks duration, resolution and file budgets before a frame is published.",
  },
  {
    no: "03",
    title: "Publish the build",
    body: "The showcase reads the same manifests, copies approved media and ships the site and game to GitHub Pages.",
  },
];

export const TOOLS = [
  "Blender",
  "Godot",
  "FFmpeg",
  "Python",
  "Pillow",
  "Three.js",
  "Vite",
  "GitHub Actions",
];
