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
  "010-maker-at-work": {
    madeWith: ["Blender 4.5 LTS", "Cycles", "Python", "Pillow", "FFmpeg"],
    notes: [
      "Every set is built in Blender Python. The desk, the lamp, the paper, the lantern and the camera move are keyed in scripts that live next to the shot.",
      "The pilot covers the opening, the portrait and the return. Each shot renders as an image sequence, then FFmpeg encodes it and ffprobe checks the result before anything is published.",
      "The portrait shot uses one photograph mounted on a depth displaced plate. The camera moves a few centimetres, so the face keeps its own structure instead of being redrawn by a model.",
      "Frames render at 1920 by 800 in Cycles, 128 samples with denoising on the graphics card, then encode to MP4, WebM and the poster on this page.",
    ],
  },
  "011-bin-city": {
    madeWith: ["Godot 4.7.2", "GDScript", "Procedural audio", "Web export"],
    notes: [
      "Dawn Market is built at run time from primitives: cobbles, awnings, stalls, a canal and a bridge. There are no imported models or textures in the build.",
      "Score, vacuum hum and effects are generated as PCM16 waveforms at 22050 Hz. Without image or audio samples the whole web build stays inside the 40 MB budget.",
      "The collector changes costume at every rank. Rank 1 is a street sweeper with a broom. Rank 2 swaps the cap, adds a coat and widens the carry stack.",
      "The camera sweeps a sphere against the world so it does not clip through stalls, planters or the skip.",
    ],
  },
};

export type PlayInfo = {
  hook: string;
  controls: { label: string; body: string }[];
  loop: string;
  credits: string;
};

export const PLAY: Record<string, PlayInfo> = {
  "011-bin-city": {
    hook: "One collector. One cart. One very messy morning.",
    controls: [
      { label: "Move", body: "WASD or arrow keys, the left stick on a gamepad, or the on screen stick on touch." },
      { label: "Vacuum", body: "Hold the left mouse button, RT, or the VAC pad. Short bursts clear a cone of litter." },
      { label: "Interact", body: "E, X, or USE to lift a heavy load, bag a pile, or sort at a depot." },
      { label: "Look", body: "Right drag or the right stick. Scroll to pull the camera in and out." },
      { label: "Run", body: "Shift, LB, or the RUN pad. Rank 2 unlocks a third carry slot." },
    ],
    loop: "Vacuum litter, sort it into four depot bins, and carry the heavy things to the skip. Clean 90 percent of Dawn Market before the shutters open.",
    credits: "Designed, built, written and scored by Kone Tshivhinda. No imported models, textures or audio.",
  },
};

export type FilmShot = { no: string; title: string; time: string; length: string; body: string };
export type FilmCare = { label: string; body: string };
export type FilmDetail = { shotList: FilmShot[]; care: FilmCare[] };

export const FILM: Record<string, FilmDetail> = {
  "010-maker-at-work": {
    shotList: [
      {
        no: "01",
        title: "Desk",
        time: "0:00",
        length: "7 s",
        body: "A dark desk at night. Lamp, sketchbook and a framed portrait. The camera creeps in while dust drifts through the lamp light.",
      },
      {
        no: "02",
        title: "Portrait",
        time: "0:07",
        length: "9 s",
        body: "The framed photograph fills the frame. The plate moves on its depth map, so the face holds its shape while the light travels across the room.",
      },
      {
        no: "08",
        title: "Return",
        time: "0:16",
        length: "9 s",
        body: "The camera pulls back to the desk. The lantern glows, the title lands and the score resolves on the last chord.",
      },
    ],
    care: [
      {
        label: "Likeness",
        body: "The portrait is one still photograph the owner supplied, graded and mounted on a depth map. No generative model redraws the face. It is treated as a physical print on the desk, and it was checked at full size against the source before it went into a frame.",
      },
      {
        label: "Score",
        body: "The pilot score is an original cue written in numpy. A low drone, a slow pad, a half time pulse and a small melody, all synthesised from waveforms. No sampled music and no quoted theme.",
      },
      {
        label: "Voice",
        body: "Three spoken lines in the pilot come from a clone of a short reference the owner recorded for this project. The reference, the model and every raw render stay in a private, gitignored folder. Only the mixed film is published.",
      },
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
