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
    madeWith: ["Python", "Pillow", "FFmpeg", "Canvas"],
    notes: [
      "Paper City is drawn from world-space geometry at twice the output size, then downsampled with a static paper grain so the loop stays clean and the GIF stays under budget.",
      "Every bounce is a function of one looping time value. The courier squashes on contact, trails a procedural scarf, and warms each window as he passes it.",
      "The Bounce Lab below runs the same character as a live canvas toy. Drag the ball, fling it, move the awnings, and the physics responds without any engine download.",
    ],
  },
  "002-turntable": {
    madeWith: ["Blender 4.5 LTS", "Python", "EEVEE Next", "glTF", "Three.js"],
    notes: [
      "The companion, the cyclorama studio and every light are built procedurally in Blender Python. There are no imported models or textures.",
      "A 192 frame loop at 24 fps carries an idle performance: breathing, blinks, antenna follow through and a wave that lands while the visor faces camera.",
      "The export merges the rig into one baked Idle animation, so the glTF viewer can play the wave and the web lab can keep steering the head and arms live.",
    ],
  },
  "003-micro-game": {
    madeWith: ["Godot 4.7.2", "GDScript", "Shader", "Web export"],
    notes: [
      "One planet, one orbit and one courier. Drag toward or away from the planet to change your radius, thread the debris ring and catch stars before they drift past.",
      "Stars build a combo. Close passes fill the surge drive, and every milestone restores a shield and repaints the sky, so a long run keeps changing shape instead of repeating.",
      "The planet and nebula are custom canvas shaders. Every line is drawn in code, and the score and effects are synthesised from waveforms when the build loads.",
      "The web build runs at 60 fps in a 960 by 540 canvas with the GL Compatibility renderer, so it plays on Pages without cross-origin isolation headers. Calm mode slows the orbit and removes flashes.",
    ],
  },
  "004-lantern-keeper": {
    madeWith: ["Blender 4.5 LTS", "Python", "EEVEE Next", "glTF", "Three.js"],
    notes: [
      "The keeper is a real armature now: a spine, neck, arms and legs weighted by hand, with a pleated coat, a ribbon scarf and a lime lantern that hangs from its own bone.",
      "Six seconds, 144 frames at 24 fps. Three steps carry a walk cycle, then the keeper stops, turns his head toward the city and lifts the lantern while the sky deepens and the windows wake in sequence.",
      "Walk, idle and lift are exported as separate glTF clips. The diorama below loads that same file and drives it live: scrub the walk, turn dusk into night, raise the lantern and orbit the bridge.",
      "The city, the arched bridge and the water are built in three.js around the exported rig, so the film's set and the playable set share one look and one character.",
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
