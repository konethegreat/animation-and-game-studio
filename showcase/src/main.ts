import "./style.css";
import "@fontsource-variable/fraunces";
import "@fontsource-variable/fraunces/wght-italic.css";
import "@fontsource-variable/manrope";
import "@fontsource/ibm-plex-mono/400.css";
import "@fontsource/ibm-plex-mono/500.css";

import { projects, type Project } from "./projects.generated";
import { ENGINE_LABEL, FILM, NOTES, PIPELINE, PLAY, REPO, TOOLS, TYPE_LABEL, type FilmDetail } from "./content";
import { mountTurntable, type ViewerHandle } from "./viewer";
import { labMarkup, mountLab } from "./labs";

const BASE = import.meta.env.BASE_URL;
const app = document.querySelector<HTMLDivElement>("#app")!;
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

let viewer: ViewerHandle | null = null;
let labDispose: (() => void) | null = null;

const ESCAPES: Record<string, string> = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;",
};

const esc = (value: string) => value.replace(/[&<>"']/g, (char) => ESCAPES[char]);
const asset = (path?: string) => (path ? `${BASE}${path}` : "");
const href = (path = "") => `${BASE}${path.replace(/^\/+/, "")}`;
const projectHref = (project: Project) => href(`project/${project.id}`);
const playHref = (project: Project) => href(`play/${project.id}`);
const sourceHref = (project: Project) => `${REPO}/tree/main/projects/${project.id}`;

function durationSeconds(label?: string): number {
  if (!label) return 0;
  const [minutes, seconds] = label.split(":").map(Number);
  return minutes * 60 + seconds;
}

const motion = projects.reduce((total, project) => total + durationSeconds(project.duration), 0);
const motionLabel = `${String(Math.floor(motion / 60)).padStart(2, "0")}:${String(motion % 60).padStart(2, "0")}`;
const playable = projects.filter((project) => project.play).length;
const heroProject = projects.find((project) => project.hero) ?? projects.find((project) => project.type === "3d");

type Route =
  | { name: "home" }
  | { name: "project"; id: string }
  | { name: "play"; id: string }
  | { name: "demo" }
  | { name: "missing" };

function parseRoute(pathname: string): Route {
  let path = pathname.startsWith(BASE) ? pathname.slice(BASE.length) : pathname.replace(/^\/+/, "");
  path = path.replace(/^\/+|\/+$/g, "");
  if (!path) return { name: "home" };
  const [head, tail] = path.split("/");
  if (head === "project" && tail) return { name: "project", id: tail };
  if (head === "play" && tail) return { name: "play", id: tail };
  if (head === "demo") return { name: "demo" };
  return { name: "missing" };
}

function announce(): string {
  return `
  <aside class="announce" id="announcement" aria-label="Studio announcement">
    <div class="wrap announce-inner">
      <p class="announce-copy">
        <span class="announce-tag mono">In production</span>
        <span>More films, characters and games are on the way.</span>
      </p>
      <button type="button" class="announce-close mono" id="announce-close" aria-label="Dismiss announcement">Dismiss</button>
    </div>
  </aside>`;
}

function head(active?: string): string {
  const nav = [
    { label: "Work", href: `${href()}#work`, key: "work" },
    { label: "3D demo", href: href("demo/three"), key: "demo" },
    { label: "Play", href: href("play/011-bin-city"), key: "play" },
  ];
  return `
  <a class="skip" href="#main">Skip to content</a>
  <header class="site-head">
    <div class="wrap head-inner">
      <a class="brand" href="${href()}" data-link aria-label="Kone Studio home">
        <span class="brand-mark" aria-hidden="true"></span>
        <span>Kone Studio</span>
      </a>
      <nav class="head-nav" aria-label="Primary">
        ${nav
          .map(
            (item) =>
              `<a href="${item.href}" data-link ${active === item.key ? 'aria-current="page"' : ""}>${item.label}</a>`,
          )
          .join("")}
      </nav>
      <a class="repo-pill mono" href="${href()}#ownership" data-link>
        <span class="live-dot" aria-hidden="true"></span>Original work
      </a>
    </div>
  </header>
  ${announce()}`;
}

function foot(): string {
  return `
  <footer class="site-foot">
    <div class="wrap foot-top">
      <div>
        <p class="eyebrow light">Kone Studio</p>
        <p class="foot-line">Animation, characters and small games, made by Kone Tshivhinda.</p>
      </div>
      <nav class="foot-nav" aria-label="Footer">
        <a href="${href()}#work" data-link>Work</a>
        <a href="${href("demo/three")}" data-link>3D demo</a>
        <a href="${href("play/011-bin-city")}" data-link>Play</a>
        <a href="${REPO}" target="_blank" rel="noreferrer">GitHub</a>
        <a href="${REPO}/blob/main/LICENSE" target="_blank" rel="noreferrer">Licence</a>
      </nav>
    </div>
    <div class="wrap foot-own" id="ownership">
      <p class="mono foot-own-label">Original work</p>
      <p>Every film, model, game, score and line of code here is original work by Kone Tshivhinda. All rights reserved. Third party tools and fonts keep their own licences.</p>
    </div>
    <div class="wrap foot-bottom mono">
      <span>© 2026 Kone Tshivhinda / All rights reserved</span>
      <span>Blender / Godot / FFmpeg</span>
    </div>
  </footer>`;
}

function ticker(): string {
  const words = ["2D animation", "3D characters", "Playable games", "Original work"];
  const run = words
    .map((word) => `<span>${word}</span><i aria-hidden="true"></i>`)
    .join("");
  return `<div class="ticker" aria-hidden="true"><div class="ticker-track">${run}${run}${run}</div></div>`;
}

function card(project: Project, index: number): string {
  const label = TYPE_LABEL[project.type] ?? project.type;
  const meta = project.type === "game" ? `${project.fps} fps` : project.duration ?? `${project.frames} frames`;
  const mediaHref = project.type === "game" && project.play ? playHref(project) : projectHref(project);
  const cta = project.type === "game" ? "Play now" : project.interactive ? "Take the controls" : "View project";
  const preview =
    project.mp4 && project.type !== "game"
      ? `<video class="card-preview" data-preview src="${asset(project.mp4)}" muted loop playsinline preload="none" aria-hidden="true"></video>`
      : "";
  return `
  <article class="card" data-type="${project.type}" data-kind="${project.kind}" data-interactive="${project.interactive ?? ""}">
    <a class="card-media" href="${mediaHref}" ${project.type === "game" && !project.play ? 'data-link' : "data-link"}>
      <img src="${asset(project.poster)}" alt="${esc(project.title)} still" decoding="async" />
      ${preview}
      <span class="type-chip mono">${esc(label)}</span>
      ${project.interactive ? `<span class="lab-chip mono"><span class="live-dot" aria-hidden="true"></span>Interactive</span>` : ""}
      <span class="card-cta mono">${cta} <span aria-hidden="true">&#8599;</span></span>
    </a>
    <div class="card-body">
      <div class="card-meta mono">
        <span>${String(index + 1).padStart(2, "0")}</span>
        <span>${esc(meta)}</span>
      </div>
      <h3><a href="${projectHref(project)}" data-link>${esc(project.title)}</a></h3>
      <p>${esc(project.summary)}</p>
      <ul class="tags">${project.tags.map((tag) => `<li>${esc(tag)}</li>`).join("")}</ul>
    </div>
  </article>`;
}

function home(): string {
  const hero = heroProject;
  const films = projects.filter((project) => project.kind === "film").length;
  const labs = projects.filter((project) => project.interactive).length;
  const ordered = [...projects].sort(
    (a, b) => Number(b.kind === "film") - Number(a.kind === "film"),
  );
  const fallback = hero?.hero ?? hero?.poster;
  return `
  ${head()}
  <main id="main">
    <section class="hero wrap">
      <div class="hero-copy">
        <p class="eyebrow"><span class="pulse" aria-hidden="true"></span><span class="owner-name">Kone Tshivhinda</span> <span class="dim">/ Independent animation + game studio / 2026</span></p>
        <h1>Small worlds,<br />built <em>frame by frame.</em><span class="hero-star" aria-hidden="true">&#10033;</span></h1>
        <p class="lede">A working studio for 2D animation, 3D characters and playable games. Everything here is generated from source in one studio pipeline. No stock footage, no purchased models.</p>
        <div class="hero-actions">
          <a class="btn btn-ink" href="${href()}#work" data-link>See the work</a>
          <a class="btn btn-glow" href="${href("play/011-bin-city")}" data-link><span class="play-glyph" aria-hidden="true"></span>Play BIN CITY</a>
        </div>
        <dl class="hero-stats">
          <div><dt class="mono">Projects</dt><dd>${String(projects.length).padStart(2, "0")}</dd></div>
          <div><dt class="mono">Motion</dt><dd>${motionLabel}</dd></div>
          <div><dt class="mono">Playable</dt><dd>${String(playable).padStart(2, "0")}</dd></div>
        </dl>
      </div>
      <div class="hero-stage" id="hero-stage">
        <div class="stage-grid" aria-hidden="true"></div>
        <div class="stage-disc" aria-hidden="true"></div>
        ${fallback ? `<img class="stage-poster" src="${asset(fallback)}" alt="Cream companion robot floating above a dark disc" />` : ""}
        <div class="stage-tag mono"><span class="live-dot" aria-hidden="true"></span><span>Live glTF</span><span class="dim">01 / Companion</span></div>
        <a class="stage-link mono" href="${href("demo/three")}" data-link>Open 3D demo <span aria-hidden="true">&#8599;</span></a>
      </div>
    </section>

    ${ticker()}

    <section class="section work wrap" id="work">
      <div class="section-head">
        <div>
          <p class="eyebrow">Selected work</p>
          <h2>Worlds you can step into.</h2>
        </div>
        <p class="section-note">Loops, characters and a game. Each piece ships a rendered cut, and the interactive pieces carry a live lab you can play with right here.</p>
      </div>
      <div class="filters" role="group" aria-label="Filter work">
        <button type="button" data-filter="all" aria-pressed="true">All <span>${String(projects.length).padStart(2, "0")}</span></button>
        <button type="button" data-filter="film" aria-pressed="false">Film <span>${String(films).padStart(2, "0")}</span></button>
        <button type="button" data-filter="2d" aria-pressed="false">2D <span>${projects.filter((p) => p.type === "2d").length}</span></button>
        <button type="button" data-filter="3d" aria-pressed="false">3D <span>${projects.filter((p) => p.type === "3d").length}</span></button>
        <button type="button" data-filter="game" aria-pressed="false">Game <span>${projects.filter((p) => p.type === "game").length}</span></button>
        ${labs ? `<button type="button" data-filter="interactive" aria-pressed="false">Interactive <span>${labs}</span></button>` : ""}
      </div>
      <div class="grid">${ordered.map(card).join("")}</div>
    </section>

    <section class="section pipeline wrap">
      <div class="pipeline-head">
        <p class="eyebrow">How it works</p>
        <h2>The studio is<br /><em>a repository.</em></h2>
        <p>Every frame and build on this site can be traced back to a script, a manifest and a command. The repo is the portfolio piece.</p>
        <a class="text-link mono" href="${REPO}" target="_blank" rel="noreferrer">Read the source <span aria-hidden="true">&#8599;</span></a>
      </div>
      <ol class="steps">
        ${PIPELINE.map(
          (step) => `
          <li>
            <span class="step-no mono">${step.no}</span>
            <div><h3>${step.title}</h3><p>${step.body}</p></div>
          </li>`,
        ).join("")}
      </ol>
    </section>

    <div class="toolchain wrap">
      <span class="mono label">Tools in the pipeline</span>
      <ul>${TOOLS.map((tool) => `<li class="mono">${tool}</li>`).join("")}</ul>
    </div>
  </main>
  ${foot()}`;
}

function mediaStage(project: Project): string {
  if (project.type === "game") {
    const still = `<img src="${asset(project.poster)}" alt="${esc(project.title)} gameplay still" />`;
    if (project.play) {
      return `<a class="game-stage" href="${playHref(project)}" data-link>
        ${still}
        <span class="play-disc" aria-hidden="true"></span>
        <span class="play-label mono">Play in browser</span>
      </a>`;
    }
    return `<div class="game-stage static">${still}<span class="play-label mono">Web build coming soon</span></div>`;
  }
  return `<video class="reel" controls ${reducedMotion ? "" : "autoplay"} muted loop playsinline preload="metadata" poster="${asset(project.poster)}">
    ${project.webm ? `<source src="${asset(project.webm)}" type="video/webm" />` : ""}
    ${project.mp4 ? `<source src="${asset(project.mp4)}" type="video/mp4" />` : ""}
    Your browser does not support the video element.
  </video>`;
}

function modelSection(project: Project): string {
  if (!project.model) return "";
  return `
  <section class="model-section" id="model">
    <div class="section-head">
      <div><p class="eyebrow">Live model</p><h2>Take it for a spin.</h2></div>
      <p class="section-note">The exported glTF carries its animation baked in. Drag to orbit and scroll to zoom.</p>
    </div>
    <div class="model-stage" id="model-viewer">
      <img class="model-fallback" src="${asset(project.poster)}" alt="${esc(project.title)} studio render" />
      <div class="stage-tag mono"><span class="live-dot" aria-hidden="true"></span><span>Loading model</span></div>
    </div>
    <a class="btn btn-ink" href="${asset(project.model)}" download>Download GLB <span aria-hidden="true">&#8595;</span></a>
  </section>`;
}

function filmSection(film: FilmDetail): string {
  return `
  <section class="film-section" id="shots">
    <div class="section-head">
      <div><p class="eyebrow">The cut</p><h2>Shot by shot.</h2></div>
      <p class="section-note">Eight shots in seventy five seconds. Every set, light and camera move is scripted, so the cut can be rebuilt frame for frame.</p>
    </div>
    <ol class="shot-list">
      ${film.shotList
        .map(
          (shot) => `
      <li>
        <span class="mono shot-no">${shot.no}</span>
        <div><h3>${shot.title}</h3><p>${shot.body}</p></div>
        <span class="mono shot-time">${shot.time} / ${shot.length}</span>
      </li>`,
        )
        .join("")}
    </ol>
  </section>
  <section class="film-section">
    <div class="section-head">
      <div><p class="eyebrow">Care</p><h2>Face, score and consent.</h2></div>
    </div>
    <div class="care-grid">
      ${film.care.map((item) => `<article><h3>${item.label}</h3><p>${item.body}</p></article>`).join("")}
    </div>
  </section>`;
}

function projectPage(project: Project, index: number): string {
  const notes = NOTES[project.id];
  const film = FILM[project.id];
  const label = TYPE_LABEL[project.type] ?? project.type;
  const engine = ENGINE_LABEL[project.engine] ?? project.engine;
  const next = projects[(index + 1) % projects.length];
  const lengthLabel = project.duration ?? `${project.frames} frames`;
  return `
  ${head(project.type === "game" ? "play" : "work")}
  <main id="main" class="detail wrap">
    <a class="back mono" href="${href()}#work" data-link><span aria-hidden="true">&#8592;</span> All work</a>
    <header class="detail-head">
      <p class="eyebrow">${String(index + 1).padStart(2, "0")} / ${esc(label)}</p>
      <h1>${esc(project.title)}</h1>
      <p class="lede">${esc(project.summary)}</p>
      <ul class="tags">${project.tags.map((tag) => `<li>${esc(tag)}</li>`).join("")}</ul>
      <p class="own-line mono">Original work / Kone Tshivhinda / All rights reserved</p>
    </header>
    <div class="detail-stage">${mediaStage(project)}</div>
    <div class="detail-grid">
      <div class="detail-notes">
        <h2>How it was made</h2>
        <ol class="notes">${(notes?.notes ?? []).map((note) => `<li>${note}</li>`).join("")}</ol>
        <div class="made-with">
          <span class="mono label">Made with</span>
          <ul class="chips">${(notes?.madeWith ?? []).map((tool) => `<li class="mono">${tool}</li>`).join("")}</ul>
        </div>
      </div>
      <aside class="facts">
        <dl>
          <div><dt class="mono">Type</dt><dd>${esc(label)}</dd></div>
          <div><dt class="mono">Built with</dt><dd>${esc(engine)}</dd></div>
          <div><dt class="mono">Canvas</dt><dd>${project.resolution}</dd></div>
          <div><dt class="mono">Frame rate</dt><dd>${project.fps} fps</dd></div>
          <div><dt class="mono">${project.type === "game" ? "Build" : "Length"}</dt><dd>${project.type === "game" ? "Web / HTML5" : lengthLabel}</dd></div>
        </dl>
        <div class="fact-links">
          ${project.type === "game" && project.play ? `<a class="btn btn-glow" href="${playHref(project)}" data-link><span class="play-glyph" aria-hidden="true"></span>Play the build</a>` : ""}
          ${project.interactive ? `<a class="btn btn-ink" href="#lab" data-link>Try the lab</a>` : ""}
          ${project.model ? `<a class="btn btn-ink" href="#model">Orbit the model</a>` : ""}
          <a class="text-link mono" href="${sourceHref(project)}" target="_blank" rel="noreferrer">Source for this project <span aria-hidden="true">&#8599;</span></a>
        </div>
      </aside>
    </div>
    ${
      project.sheet
        ? `<figure class="sheet"><img src="${asset(project.sheet)}" alt="Contact sheet of frames from ${esc(project.title)}" loading="lazy" /><figcaption class="mono">Sampled frames from the final render</figcaption></figure>`
        : ""
    }
    ${film ? filmSection(film) : ""}
    ${modelSection(project)}
    ${labMarkup(project)}
    <nav class="next" aria-label="Next project">
      <span class="mono">Next</span>
      <a href="${projectHref(next)}" data-link>${esc(next.title)} <span aria-hidden="true">&#8594;</span></a>
    </nav>
  </main>
  ${foot()}`;
}

function playPage(project: Project): string {
  const available = Boolean(project.play);
  const play = PLAY[project.id];
  const help = play
    ? `<div class="wrap play-help play-help-game">
      <div>
        <p class="eyebrow">Controls</p>
        <ul class="play-controls">
          ${play.controls.map((item) => `<li><span class="mono">${esc(item.label)}</span>${esc(item.body)}</li>`).join("")}
        </ul>
      </div>
      <div><p class="eyebrow">The loop</p><p>${esc(play.loop)}</p></div>
      <div><p class="eyebrow">Credits</p><p>${esc(play.credits)}</p></div>
      <a class="btn btn-ink" href="${projectHref(project)}" data-link>How it was built</a>
    </div>`
    : `<div class="wrap play-help">
      <div><p class="eyebrow">Controls</p><p>Drag toward or away from the planet to change orbit, or use W and S with the arrow keys. Space, Enter, click or tap starts the run. C toggles calm mode.</p></div>
      <div><p class="eyebrow">The loop</p><p>Collect stars to build a combo, graze debris to fill the surge drive, and reach each milestone for a shield and a new sky. The best score stays on this device.</p></div>
      <a class="btn btn-ink" href="${projectHref(project)}" data-link>How it was built</a>
    </div>`;
  return `
  ${head("play")}
  <main id="main" class="play-view">
    <div class="wrap play-bar">
      <a class="back mono" href="${projectHref(project)}" data-link><span aria-hidden="true">&#8592;</span> Project notes</a>
      <span class="mono dim">${esc(project.title)} / ${esc(ENGINE_LABEL[project.engine] ?? project.engine)}</span>
      <button type="button" class="text-button mono" id="fullscreen">Fullscreen</button>
    </div>
    ${play ? `<p class="wrap play-hook">${esc(play.hook)}</p>` : ""}
    <p class="wrap play-mobile-hint mono">Rotate for a wider view. Fullscreen helps.</p>
    <p class="wrap play-load-note mono">First visit downloads the engine once. Later visits load from the browser cache.</p>
    <div class="wrap">
      <div class="play-frame">
        ${
          available
            ? `<iframe src="${asset(project.play)}" title="${esc(project.title)}, a playable browser game" allow="fullscreen; autoplay; gamepad; accelerometer; gyroscope" loading="eager"></iframe>`
            : `<div class="notice"><p>The web build is not published yet.</p><a class="btn btn-ink" href="${REPO}" target="_blank" rel="noreferrer">Open the repository</a></div>`
        }
        <button type="button" class="theatre-exit mono" id="theatre-exit" aria-label="Exit fullscreen">Exit fullscreen</button>
        ${
          available
            ? `<button type="button" class="play-launch mono" id="play-launch" aria-label="Play ${esc(project.title)} fullscreen">
          <span class="play-launch-title">Play fullscreen</span>
          <span class="play-launch-note">Tap to start</span>
        </button>`
            : ""
        }
      </div>
    </div>
    ${help}
  </main>
  ${foot()}`;
}

function demoPage(project: Project): string {
  return `
  ${head("demo")}
  <main id="main" class="demo">
    <div class="wrap demo-head">
      <div>
        <a class="back mono" href="${projectHref(project)}" data-link><span aria-hidden="true">&#8592;</span> Companion project</a>
        <h1>Orbit the companion.</h1>
        <p class="lede">The idle wave is baked into the glTF. Drag to rotate, scroll to zoom, or let it turn on its own.</p>
      </div>
      <div class="demo-actions">
        <button type="button" class="text-button mono" id="reset-view">Reset view</button>
        <button type="button" class="text-button mono" id="auto-rotate" aria-pressed="false">Auto rotate</button>
      </div>
    </div>
    <div class="demo-stage">
      <div id="demo-viewer">
        <img class="model-fallback" src="${asset(project.hero ?? project.poster)}" alt="Cream companion robot floating above a dark disc" />
      </div>
      <div class="demo-hint mono"><span>Drag</span><span>Scroll</span></div>
    </div>
    <div class="wrap demo-panel">
      <dl>
        <div><dt class="mono">Model</dt><dd>glTF binary</dd></div>
        <div><dt class="mono">Loop</dt><dd>8 seconds / 24 fps</dd></div>
        <div><dt class="mono">Renderer</dt><dd>Three.js</dd></div>
      </dl>
      <a class="btn btn-ink" href="${asset(project.model)}" download>Download GLB <span aria-hidden="true">&#8595;</span></a>
    </div>
  </main>
  ${foot()}`;
}

function missingPage(): string {
  return `
  ${head()}
  <main id="main" class="wrap detail">
    <a class="back mono" href="${href()}" data-link><span aria-hidden="true">&#8592;</span> Home</a>
    <header class="detail-head"><p class="eyebrow">404</p><h1>Not found.</h1><p class="lede">That page is not part of the studio. Try the work index.</p></header>
    <a class="btn btn-ink" href="${href()}#work" data-link>See the work</a>
  </main>
  ${foot()}`;
}

function destroyViewer() {
  viewer?.dispose();
  viewer = null;
}

function destroyLab() {
  labDispose?.();
  labDispose = null;
}

function mountHero() {
  const stage = document.getElementById("hero-stage");
  const project = heroProject;
  if (!stage || !project?.model) return;
  if (!window.matchMedia("(min-width: 900px)").matches || reducedMotion) return;
  const start = () => {
    mountTurntable(stage, asset(project.model), { interactive: true, zoom: false })
      .then((handle) => {
        viewer = handle;
        stage.classList.add("is-live");
      })
      .catch((error: unknown) => console.warn("3D hero unavailable", error));
  };
  const idle = (
    window as Window & {
      requestIdleCallback?: (callback: () => void, options?: { timeout: number }) => number;
    }
  ).requestIdleCallback;
  if (idle) idle(start, { timeout: 1800 });
  else window.setTimeout(start, 700);
}

function mountModel(project: Project) {
  const host = document.getElementById("model-viewer");
  if (!host || !project.model || reducedMotion) return;
  host.classList.add("is-loading");
  mountTurntable(host, asset(project.model), { interactive: true, zoom: true })
    .then((handle) => {
      viewer = handle;
      host.classList.add("is-live");
    })
    .catch((error: unknown) => console.warn("model viewer unavailable", error));
}

function mountDemo(project: Project) {
  const host = document.getElementById("demo-viewer");
  if (!host || !project.model) return;
  host.classList.add("is-loading");
  mountTurntable(host, asset(project.model), { interactive: true, zoom: true })
    .then((handle) => {
      viewer = handle;
      host.classList.add("is-live");
      document.getElementById("reset-view")?.addEventListener("click", () => handle.reset());
      const toggle = document.getElementById("auto-rotate") as HTMLButtonElement | null;
      toggle?.addEventListener("click", () => {
        if (!handle.controls) return;
        handle.controls.autoRotate = !handle.controls.autoRotate;
        toggle.setAttribute("aria-pressed", String(handle.controls.autoRotate));
      });
    })
    .catch((error: unknown) => console.warn("3D demo unavailable", error));
}

function bindAnnouncement() {
  const bar = document.getElementById("announcement");
  const close = document.getElementById("announce-close");
  if (!bar || !close) return;
  const key = "kone-announce-2026-11";
  let dismissed = false;
  try {
    dismissed = localStorage.getItem(key) === "1";
  } catch {
    dismissed = false;
  }
  if (dismissed) {
    bar.remove();
    return;
  }
  close.addEventListener("click", () => {
    bar.remove();
    try {
      localStorage.setItem(key, "1");
    } catch {
      /* storage can be blocked; the banner still closes for this visit */
    }
  });
}

function bindHome() {
  const buttons = Array.from(document.querySelectorAll<HTMLButtonElement>("[data-filter]"));
  const cards = Array.from(document.querySelectorAll<HTMLElement>(".card"));
  for (const button of buttons) {
    button.addEventListener("click", () => {
      const filter = button.dataset.filter ?? "all";
      buttons.forEach((item) => item.setAttribute("aria-pressed", String(item === button)));
      cards.forEach((item) => {
        if (filter === "all") item.hidden = false;
        else if (filter === "film") item.hidden = item.dataset.kind !== "film";
        else if (filter === "interactive") item.hidden = !item.dataset.interactive;
        else item.hidden = item.dataset.type !== filter;
      });
    });
  }

  if (reducedMotion) return;
  const previews = document.querySelectorAll<HTMLVideoElement>("video[data-preview]");
  previews.forEach((video) => {
    const card = video.closest<HTMLElement>(".card");
    if (!card) return;
    card.addEventListener("pointerenter", () => {
      void video.play().catch(() => undefined);
      card.classList.add("is-previewing");
    });
    card.addEventListener("pointerleave", () => {
      video.pause();
      card.classList.remove("is-previewing");
    });
  });
}

let fullscreenSync: (() => void) | null = null;

document.addEventListener("fullscreenchange", () => fullscreenSync?.());

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && document.body.classList.contains("is-theatre")) {
    document.body.classList.remove("is-theatre");
    fullscreenSync?.();
  }
});

function bindFullscreen() {
  const button = document.getElementById("fullscreen");
  const frame = document.querySelector<HTMLElement>(".play-frame");
  const close = document.getElementById("theatre-exit");
  if (!button || !frame) {
    fullscreenSync = null;
    return;
  }

  const isTheatre = () => document.body.classList.contains("is-theatre");

  const sync = () => {
    const active = Boolean(document.fullscreenElement) || isTheatre();
    button.textContent = active ? "Exit fullscreen" : "Fullscreen";
    button.setAttribute("aria-pressed", active ? "true" : "false");
  };

  const leave = () => {
    document.body.classList.remove("is-theatre");
    if (document.fullscreenElement) void document.exitFullscreen().catch(() => {});
    sync();
  };

  const enter = async () => {
    if (typeof frame.requestFullscreen !== "function") {
      document.body.classList.add("is-theatre");
      sync();
      return;
    }
    try {
      await frame.requestFullscreen();
    } catch {
      document.body.classList.add("is-theatre");
    }
    sync();
  };

  button.addEventListener("click", () => {
    if (document.fullscreenElement || isTheatre()) {
      leave();
      return;
    }
    void enter();
  });

  document.getElementById("play-launch")?.addEventListener("click", () => {
    void enter();
  });

  close?.addEventListener("click", leave);
  fullscreenSync = sync;
  sync();
}

function setMeta(title: string, description?: string) {
  document.title = title;
  const tag = document.querySelector<HTMLMetaElement>('meta[name="description"]');
  if (description && tag) tag.content = description;
}

function render() {
  destroyViewer();
  destroyLab();
  document.body.classList.remove("is-theatre");
  const route = parseRoute(location.pathname);
  let markup = "";
  document.body.dataset.route = route.name;

  if (route.name === "home") {
    markup = home();
    setMeta(
      "Kone Studio / Animation and Game Studio",
      "Original work by Kone Tshivhinda. 2D animation, 3D characters and playable games, generated from source in one studio pipeline.",
    );
  } else if (route.name === "project") {
    const index = projects.findIndex((project) => project.id === route.id);
    if (index < 0) {
      markup = missingPage();
      setMeta("Not found / Kone Studio");
    } else {
      const project = projects[index];
      markup = projectPage(project, index);
      setMeta(`${project.title} / Kone Studio`, project.summary);
    }
  } else if (route.name === "play") {
    const project = projects.find((item) => item.id === route.id);
    if (!project) {
      markup = missingPage();
      setMeta("Not found / Kone Studio");
    } else {
      markup = playPage(project);
      setMeta(`${project.title} play / Kone Studio`, project.summary);
    }
  } else if (route.name === "demo") {
    const project = projects.find((item) => item.interactive === "companion") ?? projects.find((item) => item.model);
    if (!project) {
      markup = missingPage();
      setMeta("Not found / Kone Studio");
    } else {
      markup = demoPage(project);
      setMeta("3D demo / Kone Studio", "Orbit the companion robot live in the browser.");
    }
  } else {
    markup = missingPage();
    setMeta("Not found / Kone Studio");
  }

  app.innerHTML = markup;
  bindAnnouncement();

  if (route.name === "home") {
    bindHome();
    mountHero();
  } else if (route.name === "project") {
    const project = projects.find((item) => item.id === route.id);
    if (project) {
      mountModel(project);
      if (project.interactive) labDispose = mountLab(project);
    }
  } else if (route.name === "play") {
    bindFullscreen();
  } else if (route.name === "demo") {
    const project = projects.find((item) => item.interactive === "companion") ?? projects.find((item) => item.model);
    if (project) mountDemo(project);
  }

  window.scrollTo({ top: 0, behavior: "instant" as ScrollBehavior });
  if (location.hash) {
    const target = document.querySelector(location.hash);
    if (target) requestAnimationFrame(() => target.scrollIntoView({ behavior: "smooth", block: "start" }));
  }
}

document.addEventListener("click", (event) => {
  if (
    event.defaultPrevented ||
    event.button !== 0 ||
    event.metaKey ||
    event.ctrlKey ||
    event.shiftKey ||
    event.altKey
  ) {
    return;
  }
  const anchor = (event.target as Element | null)?.closest<HTMLAnchorElement>("a[data-link]");
  if (!anchor) return;
  const url = new URL(anchor.href, location.href);
  if (url.origin !== location.origin) return;
  event.preventDefault();
  if (url.pathname === location.pathname && url.hash) {
    history.pushState({}, "", url.pathname + url.hash);
    document.querySelector(url.hash)?.scrollIntoView({ behavior: "smooth", block: "start" });
    return;
  }
  history.pushState({}, "", url.pathname + url.hash);
  render();
});

window.addEventListener("popstate", render);

render();
