-module(webproxy_server_visual_page).

%% The `/info/visual` page, embedded verbatim so it ships inside the compiled
%% module. A file in `priv/` would need a symlink in the build directory, which
%% `gleam build` cannot create on Windows without developer mode.
%%
%% The `~B"""` sigil (OTP 27+) keeps the content byte-for-byte: no escaping is
%% needed, so the page can be edited as plain HTML. It must not contain `"""`.

-export([html/0]).

html() ->
    ~B"""
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>WebProxy Clusters</title>
<style>
  :root {
    color-scheme: dark;
    --space: #080b13;
    --page: #0c1019;
    --ink: #e8ebf2;
    --ink-2: #b3bacb;
    --ink-3: #8b93a7;
    --hairline: rgba(255, 255, 255, 0.07);
    --border: rgba(255, 255, 255, 0.11);
    --grid: #161d2c;
    --accent: #3987e5;
    --wash: rgba(57, 135, 229, 0.16);
    --star: #e9edf6;
    --link: #55688f;
    --orbit: #33405e;
    --good: #0ca30c;
    --critical: #e66767;
    --shadow: 0 6px 20px rgba(0, 0, 0, 0.5);
    --sans: system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
    --mono: ui-monospace, "SF Mono", "Cascadia Mono", Consolas, monospace;
  }

  * { box-sizing: border-box; }
  html, body { margin: 0; height: 100%; }
  body {
    background: var(--page);
    color: var(--ink);
    font: 13px/1.5 var(--sans);
    -webkit-font-smoothing: antialiased;
  }
  ::selection { background: var(--wash); color: var(--ink); }
  :focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }

  .layout {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 380px;
    height: 100vh;
    height: 100dvh;
  }

  /* ---- figure ---- */

  .viewport { display: flex; flex-direction: column; min-width: 0; margin: 0; overflow: hidden; background: var(--space); }
  .stage { position: relative; flex: 1; min-height: 0; }
  #scene { position: absolute; inset: 0; }
  #scene canvas { display: block; width: 100%; height: 100%; }
  .labels { position: absolute; inset: 0; pointer-events: none; }

  .tag {
    padding: 1px 0 1px 7px;
    border-left: 1px solid var(--ink-3);
    font: 11px/1.35 var(--mono);
    color: var(--ink-3);
    white-space: nowrap;
  }
  .tag b { display: block; font-weight: 400; color: var(--ink-2); }
  .tag.is-active { border-left-color: var(--accent); color: var(--ink-2); }
  .tag.is-active b { color: var(--ink); }

  .figure-bar {
    flex: none;
    display: flex;
    flex-wrap: wrap;
    justify-content: space-between;
    gap: 4px 16px;
    min-height: 37px;
    padding: 9px 16px;
    border-top: 1px solid var(--border);
    background: var(--page);
    color: var(--ink-3);
    font-size: 12px;
  }
  .figure-bar strong { color: var(--ink-2); font-weight: 500; }

  .empty {
    position: absolute;
    inset: 0;
    display: grid;
    place-content: center;
    margin: 0;
    padding: 16px;
    text-align: center;
    color: var(--ink-2);
    pointer-events: none;
  }
  .empty[hidden] { display: none; }
  .empty strong { display: block; color: var(--ink); font-weight: 600; font-size: 14px; }

  .tooltip {
    position: fixed;
    left: 0;
    top: 0;
    z-index: 10;
    min-width: 240px;
    padding: 10px 12px;
    background: var(--page);
    border: 1px solid var(--border);
    border-radius: 4px;
    box-shadow: var(--shadow);
    pointer-events: none;
  }
  .tooltip[hidden] { display: none; }
  .tooltip dl { display: grid; grid-template-columns: auto auto; gap: 2px 16px; margin: 0; }
  .tooltip dt { color: var(--ink-3); }
  .tooltip dd { margin: 0; text-align: right; font-variant-numeric: tabular-nums; }

  /* ---- data sheet ---- */

  .panel {
    display: flex;
    flex-direction: column;
    min-height: 0;
    padding: 20px 20px 0;
    border-left: 1px solid var(--border);
  }
  .panel-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; }
  h1 { margin: 0; font-size: 16px; font-weight: 600; letter-spacing: 0; }
  .subtitle { margin: 2px 0 0; color: var(--ink-2); }

  button {
    flex: none;
    font: inherit;
    font-size: 12.5px;
    color: var(--ink);
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 4px;
    padding: 4px 10px;
    cursor: pointer;
  }
  button:hover { background: var(--wash); }

  .status { display: flex; align-items: center; gap: 8px; margin: 10px 0 0; color: var(--ink-2); font-size: 12.5px; }
  .status::before { content: ""; flex: none; width: 7px; height: 7px; border-radius: 50%; background: var(--ink-3); }
  .status[data-state="live"]::before { background: var(--good); }
  .status[data-state="down"]::before { background: var(--critical); }

  .sheet { margin-top: 16px; padding-top: 12px; border-top: 1px solid var(--border); }
  h2 {
    margin: 0 0 6px;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--ink-3);
  }

  table { width: 100%; border-collapse: collapse; font-size: 12.5px; }
  caption { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap; }
  td, th { padding: 5px 8px; border-bottom: 1px solid var(--hairline); }
  td:first-child, th:first-child { padding-left: 0; }
  td:last-child, th:last-child { padding-right: 0; }
  .num { text-align: right; font-variant-numeric: tabular-nums; }

  .spec th { color: var(--ink-2); font-weight: 400; text-align: left; }
  .spec td { color: var(--ink); text-align: right; font-variant-numeric: tabular-nums; }
  .spec td small { color: var(--ink-3); font-size: 12px; }

  .legend { display: grid; grid-template-columns: 28px 1fr; gap: 8px 10px; margin: 8px 0 0; align-items: start; }
  .legend dt { padding-top: 3px; line-height: 0; }
  .legend dd { margin: 0; color: var(--ink-2); }
  .legend dd strong { color: var(--ink); font-weight: 500; }
  .legend svg { display: block; width: 28px; height: 14px; overflow: visible; }

  .clusters { display: flex; flex-direction: column; flex: 1; min-height: 0; }
  .table-wrap {
    flex: 1;
    min-height: 0;
    margin: 0 -20px;
    padding: 0 20px 20px;
    overflow: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--orbit) transparent;
  }
  .rows th {
    position: sticky;
    top: 0;
    background: var(--page);
    border-bottom: 1px solid var(--border);
    color: var(--ink-3);
    font-weight: 500;
    text-align: left;
  }
  .rows th.num { text-align: right; }
  .rows th[aria-sort="ascending"], .rows th[aria-sort="descending"] { color: var(--ink); }

  .sort {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    margin: 0;
    padding: 0;
    border: 0;
    background: none;
    color: inherit;
    font: inherit;
    cursor: pointer;
  }
  .sort:hover { background: none; color: var(--ink); }
  .sort svg { width: 10px; height: 10px; opacity: 0.35; transition: transform 120ms ease-out; }
  th[aria-sort="ascending"] .sort svg, th[aria-sort="descending"] .sort svg { opacity: 1; }
  th[aria-sort="ascending"] .sort svg { transform: rotate(180deg); }

  .section-head { display: flex; align-items: baseline; justify-content: space-between; gap: 12px; }
  .sort-note { margin: 0 0 6px; color: var(--ink-3); font-size: 12px; text-align: right; }

  .credit {
    flex: none;
    margin: 0 -20px;
    padding: 10px 20px 12px;
    border-top: 1px solid var(--border);
    color: var(--ink-3);
    font-size: 12px;
  }
  .credit a {
    color: var(--ink-2);
    text-decoration: underline;
    text-decoration-color: var(--ink-3);
    text-underline-offset: 2px;
  }
  .credit a:hover { color: var(--ink); text-decoration-color: var(--ink); }
  .id { font-family: var(--mono); font-size: 12px; color: var(--ink-2); }
  .rows tbody tr { cursor: pointer; }
  .rows tbody tr:hover, .rows tbody tr.is-active { background: var(--wash); }
  .rows tbody tr.is-active .id:first-child { color: var(--ink); }
  .rows tbody tr:focus-visible { outline-offset: -2px; }
  .no-rows { margin: 10px 0 0; color: var(--ink-3); }
  .no-rows[hidden] { display: none; }

  @media (max-width: 900px) {
    .layout { grid-template-columns: 1fr; grid-template-rows: 60vh auto; height: auto; }
    .viewport { min-height: 340px; }
    .panel { border-left: 0; border-top: 1px solid var(--border); }
    .table-wrap { overflow: visible; }
  }
</style>
</head>
<body>
<main class="layout">
  <figure class="viewport" id="viewport" aria-label="3D view of the clusters">
    <div class="stage">
      <div id="scene"></div>
      <p id="empty" class="empty" hidden><span><strong>No live sessions</strong>Clusters appear here as clients connect.</span></p>
    </div>
    <figcaption class="figure-bar">
      <span><strong>Live cluster topology.</strong> Largest organizations labeled.</span>
      <span>Drag to rotate · scroll or pinch to zoom · select a cluster to follow it · Esc resets</span>
    </figcaption>
  </figure>

  <aside class="panel" aria-labelledby="title">
    <header class="panel-head">
      <div>
        <h1 id="title">WebProxy clusters</h1>
        <p class="subtitle">Peer-to-peer cache topology</p>
      </div>
      <button id="reset" type="button" title="Reset view (Esc)">Reset view</button>
    </header>
    <p id="status" class="status" role="status">Connecting…</p>

    <section class="sheet" aria-labelledby="h-figures">
      <h2 id="h-figures">Key figures</h2>
      <table class="spec">
        <caption>Key figures</caption>
        <tbody>
          <tr><th scope="row">Live sessions</th><td id="f-sessions">–</td></tr>
          <tr><th scope="row">Clusters</th><td id="f-clusters">–</td></tr>
          <tr><th scope="row">Organizations</th><td id="f-orgs">–</td></tr>
          <tr><th scope="row">Largest cluster</th><td id="f-largest">–</td></tr>
          <tr><th scope="row">Mean sessions per cluster</th><td id="f-mean">–</td></tr>
          <tr><th scope="row">Refresh interval</th><td>60 s</td></tr>
        </tbody>
      </table>
    </section>

    <section class="sheet" aria-labelledby="h-legend">
      <h2 id="h-legend">Legend</h2>
      <dl class="legend">
        <dt><svg viewBox="0 0 28 14" aria-hidden="true"><circle cx="14" cy="7" r="2.6" fill="var(--star)"/></svg></dt>
        <dd><strong>Session.</strong> One live client connection.</dd>
        <dt><svg viewBox="0 0 28 14" aria-hidden="true"><line x1="5" y1="10" x2="23" y2="4" stroke="var(--link)" stroke-width="1.2"/><circle cx="5" cy="10" r="2.2" fill="var(--star)"/><circle cx="23" cy="4" r="2.2" fill="var(--star)"/></svg></dt>
        <dd><strong>Peer link.</strong> Sessions of one cluster share cached responses directly.</dd>
        <dt><svg viewBox="0 0 28 14" aria-hidden="true"><ellipse cx="14" cy="7" rx="12" ry="5" fill="none" stroke="var(--ink-3)" stroke-width="1"/><circle cx="14" cy="7" r="2.2" fill="var(--star)"/><circle cx="25.4" cy="5.4" r="1.6" fill="var(--star)"/></svg></dt>
        <dd><strong>Orbit.</strong> An organization's smaller clusters circle its largest one.</dd>
      </dl>
    </section>

    <section class="sheet clusters" aria-labelledby="h-clusters">
      <div class="section-head">
        <h2 id="h-clusters">Clusters</h2>
        <p id="sort-note" class="sort-note" aria-live="polite"></p>
      </div>
      <div class="table-wrap">
        <table class="rows">
          <caption id="rows-caption">Clusters</caption>
          <thead>
            <tr>
              <th scope="col" data-sort="cluster" aria-sort="descending">
                <button type="button" class="sort" data-key="cluster" title="Sort by cluster sessions">Cluster<svg viewBox="0 0 10 10" aria-hidden="true"><path d="M2 3.5l3 3 3-3" fill="none" stroke="currentColor" stroke-width="1.4"/></svg></button>
              </th>
              <th scope="col" data-sort="organization" aria-sort="none">
                <button type="button" class="sort" data-key="organization" title="Sort by organization sessions">Organization<svg viewBox="0 0 10 10" aria-hidden="true"><path d="M2 3.5l3 3 3-3" fill="none" stroke="currentColor" stroke-width="1.4"/></svg></button>
              </th>
              <th scope="col" class="num">Sessions</th>
              <th scope="col" class="num" title="Sessions across the whole organization">Org. total</th>
            </tr>
          </thead>
          <tbody id="rows"></tbody>
        </table>
        <p id="no-rows" class="no-rows" hidden>No clusters.</p>
      </div>
    </section>

    <footer class="credit">
      Maintained by <a href="https://rhm.dev" target="_blank" rel="noopener">Rodrigo Heinzen de Moraes</a>, <span id="years">2025</span>
    </footer>
  </aside>
</main>

<div id="tooltip" class="tooltip" role="tooltip" hidden></div>

<script type="importmap">
  {
    "imports": {
      "three": "https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js",
      "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/"
    }
  }
</script>
<script type="module">
  import * as THREE from 'three';
  import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
  import { CSS2DRenderer, CSS2DObject } from 'three/addons/renderers/CSS2DRenderer.js';

  const POLL_MS = 60000;
  const MAX_STARS = 240;     // per cluster; past this, each star stands for several sessions
  const FULL_MESH = 12;      // clusters up to this size link every pair of sessions
  const NEIGHBOURS = 3;      // larger ones link each session to its nearest peers, plus one far peer
  const ORBIT_GAP = 4;       // clearance between neighbouring orbits
  const ORG_MARGIN = 10;     // clearance between neighbouring organizations
  const LABELLED_ORGS = 8;   // organizations labeled in the figure, largest first
  const LABEL_BOX = { width: 190, height: 32 };
  const GOLDEN_ANGLE = Math.PI * (3 - Math.sqrt(5));
  // Works whether the page was opened as /info/visual or /info/visual/.
  const DATA_URL = location.pathname.replace(/\/+$/, '') + '/data';
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const stacked = matchMedia('(max-width: 900px)');

  const $ = (id) => document.getElementById(id);
  const fmt = new Intl.NumberFormat();
  const fmt1 = new Intl.NumberFormat(undefined, { minimumFractionDigits: 1, maximumFractionDigits: 1 });

  const css = getComputedStyle(document.documentElement);
  const token = (name) => new THREE.Color(css.getPropertyValue(`--${name}`).trim());
  const palette = {
    space: token('space'),
    grid: token('grid'),
    star: token('star'),
    link: token('link'),
    orbit: token('orbit'),
    accent: token('accent'),
    warm: new THREE.Color('#f6e5c8'),
    cool: new THREE.Color('#cddcff'),
  };

  // Deterministic randomness, so a cluster's stars keep their places between updates.
  function hashString(text) {
    let h = 2166136261;
    for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619);
    return h >>> 0;
  }
  function random(seed) {
    let a = seed >>> 0;
    return () => {
      a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  // ---------------------------------------------------------------- renderer

  const host = $('scene');
  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ antialias: true });
  } catch (err) {
    showEmpty('3D view unavailable', 'This browser could not start WebGL. The table lists every cluster.');
    throw err;
  }
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  host.appendChild(renderer.domElement);

  const labelRenderer = new CSS2DRenderer();
  labelRenderer.domElement.className = 'labels';
  host.appendChild(labelRenderer.domElement);

  const scene = new THREE.Scene();
  scene.background = palette.space;

  const camera = new THREE.PerspectiveCamera(42, 1, 0.5, 6000);
  camera.position.set(60, 80, 100);

  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.08;
  controls.minDistance = 8;
  controls.maxDistance = 1200;

  // Until the viewer moves the camera, it keeps everything in frame.
  let autoFit = true;
  let focus = null;
  let focusArriving = false;
  controls.addEventListener('start', () => {
    autoFit = false;
    focusArriving = false;
  });

  new ResizeObserver(() => {
    const { clientWidth: w, clientHeight: h } = host;
    if (!w || !h) return;
    renderer.setSize(w, h);
    labelRenderer.setSize(w, h);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }).observe(host);

  // ------------------------------------------------------------ scene parts

  function makeStarTexture() {
    const size = 64;
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = size;
    const ctx = canvas.getContext('2d');
    const g = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
    g.addColorStop(0, 'rgba(255,255,255,1)');
    g.addColorStop(0.3, 'rgba(255,255,255,0.9)');
    g.addColorStop(0.55, 'rgba(255,255,255,0.12)');
    g.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, size, size);
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    return texture;
  }

  // A sparse, faint background field that travels with the camera.
  const backdrop = (() => {
    const count = 900;
    const rand = random(7);
    const positions = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) {
      const r = 2000 + rand() * 1500;
      const y = rand() * 2 - 1;
      const a = rand() * Math.PI * 2;
      const s = Math.sqrt(1 - y * y);
      positions.set([r * s * Math.cos(a), r * y, r * s * Math.sin(a)], i * 3);
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    const points = new THREE.Points(geometry, new THREE.PointsMaterial({
      color: 0x8391b3, size: 1, sizeAttenuation: false, transparent: true, opacity: 0.25, depthWrite: false,
    }));
    scene.add(points);
    return points;
  })();

  // A polar reference grid on the plane the organizations sit on, like a star chart.
  let polar = null;
  let polarRadius = 0;
  function ensurePolar(radius) {
    const wanted = Math.ceil((radius + 12) / 10) * 10;
    if (polar && Math.abs(wanted - polarRadius) <= polarRadius * 0.15) return;
    if (polar) { scene.remove(polar); polar.geometry.dispose(); polar.material.dispose(); }
    const rings = THREE.MathUtils.clamp(Math.round(wanted / 30), 3, 6);
    polar = new THREE.PolarGridHelper(wanted, 12, rings, 128, palette.grid, palette.grid);
    polarRadius = wanted;
    scene.add(polar);
  }

  function makeDynamic(capacity, build) {
    const geometry = new THREE.BufferGeometry();
    for (const name of ['position', 'color']) {
      geometry.setAttribute(name, new THREE.BufferAttribute(new Float32Array(capacity * 3), 3).setUsage(THREE.DynamicDrawUsage));
    }
    geometry.setDrawRange(0, 0);
    const object = build(geometry);
    object.userData.capacity = capacity;
    object.frustumCulled = false;
    scene.add(object);
    return object;
  }
  function grow(object, needed, build) {
    let capacity = object.userData.capacity;
    if (needed <= capacity) return object;
    while (capacity < needed) capacity *= 2;
    scene.remove(object);
    object.geometry.dispose();
    return makeDynamic(capacity, build);
  }

  // Stars keep a constant on-screen size, like dots on a chart, whatever the zoom.
  const starMaterial = new THREE.PointsMaterial({
    size: 6 * renderer.getPixelRatio(), sizeAttenuation: false, map: makeStarTexture(), vertexColors: true,
    transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
  });
  const buildStars = (geometry) => new THREE.Points(geometry, starMaterial);
  let stars = makeDynamic(2048, buildStars);

  const linkMaterial = new THREE.LineBasicMaterial({
    vertexColors: true, transparent: true, opacity: 0.75, depthWrite: false,
  });
  const buildLinks = (geometry) => new THREE.LineSegments(geometry, linkMaterial);
  let links = makeDynamic(4096, buildLinks);

  const circle = new THREE.BufferGeometry().setFromPoints(
    Array.from({ length: 160 }, (_, i) => {
      const a = (i / 160) * Math.PI * 2;
      return new THREE.Vector3(Math.cos(a), 0, Math.sin(a));
    }),
  );
  const orbitMaterial = new THREE.LineBasicMaterial({ color: palette.orbit });
  const orbitActiveMaterial = new THREE.LineBasicMaterial({ color: palette.accent, transparent: true, opacity: 0.7 });

  const hitGeometry = new THREE.SphereGeometry(1, 12, 8);
  const hitMaterial = new THREE.MeshBasicMaterial({ visible: false });

  // ------------------------------------------------------------------- model

  const orgs = new Map();       // anonymized organization id -> org
  const orgOrder = [];          // first-seen order, so existing orgs keep their place
  const clusters = new Map();   // anonymized cluster id -> cluster view
  const hitTargets = [];
  let totalSessions = 0;

  const constellationRadius = (sessions) => 2.4 + 2.6 * Math.cbrt(Math.max(sessions, 1));
  // Roughly Kepler: further orbits are slower.
  const orbitalSpeed = (radius) => 4 / Math.pow(Math.max(radius, 4), 1.5);

  function createOrg(key) {
    const rand = random(hashString(key));
    const el = document.createElement('div');
    el.className = 'tag';
    el.innerHTML = '<b></b><span></span>';
    el.querySelector('b').textContent = key;
    const label = new CSS2DObject(el);
    label.center.set(0, 1);
    label.visible = false;
    scene.add(label);
    const org = {
      key, label,
      center: new THREE.Vector3(),
      target: new THREE.Vector3(),
      yOffset: (rand() - 0.5) * 8,
      tilt: new THREE.Quaternion().setFromEuler(new THREE.Euler((rand() - 0.5) * 0.4, 0, (rand() - 0.5) * 0.4)),
      clusters: [],
      sun: null,
      extent: 0,
      sessions: 0,
      rank: Infinity,
      dying: false,
      fresh: true,
    };
    orgs.set(key, org);
    orgOrder.push(org);
    return org;
  }

  function createCluster(key, org) {
    const rand = random(hashString(key));
    const hit = new THREE.Mesh(hitGeometry, hitMaterial);
    const orbit = new THREE.LineLoop(circle, orbitMaterial);
    orbit.visible = false;
    scene.add(hit, orbit);
    const view = {
      key, org, hit, orbit,
      sessions: 0,
      shown: 0,
      radius: constellationRadius(1),
      pos: new THREE.Vector3(),
      angle: rand() * Math.PI * 2,
      orbitRadius: 0,
      orbitTarget: 0,
      spinAxis: new THREE.Vector3(rand() - 0.5, 1, rand() - 0.5).normalize(),
      spin: rand() * Math.PI * 2,
      spinRate: (0.02 + rand() * 0.03) * (rand() < 0.5 ? -1 : 1),
      level: 1,
      accent: 0,
      stars: [],
      world: new Float32Array(0),
      edges: [],
      edgeCount: -1,
      dying: false,
      fresh: true,
    };
    hit.userData.view = view;
    hitTargets.push(hit);
    org.clusters.push(view);
    clusters.set(key, view);
    return view;
  }

  function disposeCluster(view) {
    scene.remove(view.hit, view.orbit);
    hitTargets.splice(hitTargets.indexOf(view.hit), 1);
    view.org.clusters.splice(view.org.clusters.indexOf(view), 1);
    if (view.org.sun === view) view.org.sun = null;
    clusters.delete(view.key);
    if (hovered === view) setHovered(null);
    if (focus === view) focus = null;
  }

  // A cluster's stars sit at fixed spots inside a slightly flattened ball.
  function ensureStars(view, count) {
    while (view.stars.length < count) {
      const i = view.stars.length;
      const rand = random(hashString(`${view.key}:${i}`));
      const y = rand() * 2 - 1;
      const a = rand() * Math.PI * 2;
      const s = Math.sqrt(1 - y * y);
      const r = 0.25 + 0.75 * Math.cbrt(rand());
      view.stars.push({
        p: new THREE.Vector3(s * Math.cos(a) * r, y * r * 0.7, s * Math.sin(a) * r),
        color: palette.star.clone().lerp(rand() < 0.5 ? palette.warm : palette.cool, rand() * 0.5),
      });
    }
    if (view.world.length < count * 3) view.world = new Float32Array(Math.max(count, 16) * 3 * 2);
  }

  // Every peer can answer every other peer's request. Small clusters show that
  // as a full mesh; bigger ones as a web of near neighbours plus a long link each.
  function linkStars(view, count) {
    const edges = [];
    if (count <= FULL_MESH) {
      for (let i = 0; i < count; i++) for (let j = i + 1; j < count; j++) edges.push(i, j);
    } else {
      const seen = new Set();
      const add = (a, b) => {
        const lo = Math.min(a, b);
        const hi = Math.max(a, b);
        const key = lo * 4096 + hi;
        if (lo === hi || seen.has(key)) return;
        seen.add(key);
        edges.push(lo, hi);
      };
      for (let i = 0; i < count; i++) {
        const p = view.stars[i].p;
        const best = Array.from({ length: NEIGHBOURS }, () => [Infinity, -1]);
        for (let j = 0; j < count; j++) {
          if (j === i) continue;
          const d = p.distanceToSquared(view.stars[j].p);
          if (d >= best[NEIGHBOURS - 1][0]) continue;
          let slot = NEIGHBOURS - 1;
          while (slot > 0 && best[slot - 1][0] > d) { best[slot] = best[slot - 1]; slot--; }
          best[slot] = [d, j];
        }
        for (const [, j] of best) if (j >= 0) add(i, j);
        add(i, Math.floor(random(hashString(`${view.key}:far:${i}`))() * count));
      }
    }
    view.edges = edges;
    view.edgeCount = count;
  }

  function applySnapshot(data) {
    const list = Array.isArray(data.clusters) ? data.clusters : [];
    const seenClusters = new Set();
    const seenOrgs = new Set();

    for (const org of orgs.values()) org.sessions = 0;
    for (const entry of list) {
      seenClusters.add(entry.id);
      seenOrgs.add(entry.organization);
      const org = orgs.get(entry.organization) ?? createOrg(entry.organization);
      org.dying = false;
      org.sessions += entry.sessions;
      const view = clusters.get(entry.id) ?? createCluster(entry.id, org);
      view.dying = false;
      view.sessions = entry.sessions;
    }
    for (const view of clusters.values()) {
      if (!seenClusters.has(view.key)) { view.dying = true; view.sessions = 0; }
    }
    for (const org of orgs.values()) {
      if (!seenOrgs.has(org.key)) org.dying = true;
    }

    // Label the largest organizations.
    [...orgs.values()]
      .filter((org) => !org.dying)
      .sort((a, b) => b.sessions - a.sessions || a.key.localeCompare(b.key))
      .forEach((org, rank) => {
        org.rank = rank;
        const count = list.filter((c) => c.organization === org.key).length;
        org.label.element.querySelector('span').textContent =
          `${fmt.format(org.sessions)} sessions · ${count} ${count === 1 ? 'cluster' : 'clusters'}`;
      });

    totalSessions = data.sessionCount ?? list.reduce((n, c) => n + c.sessions, 0);
    const largest = list.reduce((max, c) => Math.max(max, c.sessions), 0);
    $('f-sessions').textContent = fmt.format(totalSessions);
    $('f-clusters').textContent = fmt.format(list.length);
    $('f-orgs').textContent = fmt.format(seenOrgs.size);
    $('f-largest').textContent = list.length ? `${fmt.format(largest)} sessions` : '–';
    $('f-mean').textContent = list.length ? fmt1.format(totalSessions / list.length) : '–';

    if (list.length) $('empty').hidden = true;
    else showEmpty('No live sessions', 'Clusters appear here as clients connect.');
    renderTable(list);
    if (hovered) renderTooltip(hovered);
  }

  function showEmpty(title, detail) {
    const el = $('empty');
    el.querySelector('strong').textContent = title;
    el.querySelector('strong').nextSibling.textContent = detail;
    el.hidden = false;
  }

  // ------------------------------------------------------------------- table

  const rows = new Map();
  let rowHovered = null;
  let lastList = [];

  // The table sorts by the sessions of either the cluster or its whole
  // organization, in either direction. The choice is remembered per viewer.
  const SORT_STORAGE = 'webproxy-visual-sort';
  const sort = { key: 'cluster', dir: 'desc' };
  try {
    const saved = JSON.parse(localStorage.getItem(SORT_STORAGE) ?? 'null');
    if (saved && ['cluster', 'organization'].includes(saved.key) && ['asc', 'desc'].includes(saved.dir)) {
      Object.assign(sort, saved);
    }
  } catch (err) { /* storage unavailable: keep the default */ }

  function showSort() {
    for (const th of document.querySelectorAll('th[data-sort]')) {
      th.setAttribute('aria-sort', th.dataset.sort !== sort.key ? 'none' : sort.dir === 'asc' ? 'ascending' : 'descending');
    }
    const text = `By ${sort.key} sessions, ${sort.dir === 'desc' ? 'highest' : 'lowest'} first`;
    $('sort-note').textContent = text;
    $('rows-caption').textContent = `Clusters, sorted ${text.toLowerCase()}`;
  }

  for (const button of document.querySelectorAll('.sort')) {
    button.addEventListener('click', () => {
      if (sort.key === button.dataset.key) sort.dir = sort.dir === 'desc' ? 'asc' : 'desc';
      else Object.assign(sort, { key: button.dataset.key, dir: 'desc' });
      try { localStorage.setItem(SORT_STORAGE, JSON.stringify(sort)); } catch (err) { /* not persisted */ }
      showSort();
      renderTable();
    });
  }
  showSort();

  const year = new Date().getFullYear();
  $('years').textContent = year > 2025 ? `2025–${year}` : '2025';

  function makeRow(key) {
    const tr = document.createElement('tr');
    tr.dataset.key = key;
    tr.tabIndex = 0;
    tr.innerHTML = '<td class="id"></td><td class="id"></td><td class="num"></td><td class="num"></td>';
    const enter = () => { rowHovered = key; };
    const leave = () => { if (rowHovered === key) rowHovered = null; };
    tr.addEventListener('mouseenter', enter);
    tr.addEventListener('mouseleave', leave);
    tr.addEventListener('focus', enter);
    tr.addEventListener('blur', leave);
    tr.addEventListener('click', () => focusCluster(clusters.get(key)));
    tr.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        focusCluster(clusters.get(key));
      }
    });
    rows.set(key, tr);
    return tr;
  }

  function renderTable(list = lastList) {
    lastList = list;
    const orgTotals = new Map();
    for (const c of list) orgTotals.set(c.organization, (orgTotals.get(c.organization) ?? 0) + c.sessions);
    const sign = sort.dir === 'asc' ? 1 : -1;
    const byCluster = (a, b) => sign * (a.sessions - b.sessions) || a.id.localeCompare(b.id);
    // Sorting by organization keeps each organization's clusters together.
    const byOrganization = (a, b) =>
      sign * (orgTotals.get(a.organization) - orgTotals.get(b.organization))
      || a.organization.localeCompare(b.organization)
      || byCluster(a, b);
    const sorted = [...list].sort(sort.key === 'organization' ? byOrganization : byCluster);
    const keep = new Set(sorted.map((c) => c.id));
    for (const [key, tr] of rows) {
      if (!keep.has(key)) { tr.remove(); rows.delete(key); if (rowHovered === key) rowHovered = null; }
    }
    for (const c of sorted) {
      const cells = (rows.get(c.id) ?? makeRow(c.id)).children;
      cells[0].textContent = c.id;
      cells[1].textContent = c.organization;
      cells[2].textContent = fmt.format(c.sessions);
      cells[3].textContent = fmt.format(orgTotals.get(c.organization));
    }
    const tbody = $('rows');
    const current = [...tbody.children];
    if (current.length !== sorted.length || current.some((tr, i) => tr.dataset.key !== sorted[i].id)) {
      const active = document.activeElement;
      for (const c of sorted) tbody.appendChild(rows.get(c.id));
      if (active && tbody.contains(active)) active.focus({ preventScroll: true });
    }
    $('no-rows').hidden = sorted.length > 0;
  }

  let activeRow = null;
  function markActiveRow(view) {
    const tr = view ? rows.get(view.key) : null;
    if (tr === activeRow) return;
    activeRow?.classList.remove('is-active');
    tr?.classList.add('is-active');
    activeRow = tr ?? null;
  }

  // ----------------------------------------------------------------- polling

  let pollTimer = null;
  async function poll() {
    clearTimeout(pollTimer);
    try {
      const response = await fetch(DATA_URL, { cache: 'no-store' });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      applySnapshot(await response.json());
      setStatus(true);
    } catch (err) {
      setStatus(false);
    } finally {
      pollTimer = setTimeout(poll, POLL_MS);
    }
  }
  function setStatus(ok) {
    const el = $('status');
    el.dataset.state = ok ? 'live' : 'down';
    el.textContent = ok
      ? `Live, updated ${new Date().toLocaleTimeString()}`
      : 'Connection lost, retrying in a minute';
  }
  document.addEventListener('visibilitychange', () => { if (!document.hidden) poll(); });

  // ------------------------------------------------------------- interaction

  const raycaster = new THREE.Raycaster();
  const pointer = new THREE.Vector2();
  let pointerInside = false;
  let pointerClient = { x: 0, y: 0 };
  let pointerDown = null;
  let hovered = null;

  function setPointer(event) {
    const rect = renderer.domElement.getBoundingClientRect();
    pointer.set(((event.clientX - rect.left) / rect.width) * 2 - 1, -((event.clientY - rect.top) / rect.height) * 2 + 1);
  }

  function setHovered(view) {
    if (hovered === view) return;
    hovered = view;
    renderer.domElement.style.cursor = view ? 'pointer' : '';
    if (view) renderTooltip(view);
    else $('tooltip').hidden = true;
  }

  function renderTooltip(view) {
    const tip = $('tooltip');
    const share = totalSessions ? Math.round((view.sessions / totalSessions) * 100) : 0;
    const sun = view.org.sun;
    tip.innerHTML = '<dl><dt>Cluster</dt><dd class="id"></dd><dt>Organization</dt><dd class="id"></dd>'
      + '<dt>Live sessions</dt><dd></dd><dt>Share of sessions</dt><dd></dd><dt>Orbits</dt><dd></dd></dl>';
    const values = tip.querySelectorAll('dd');
    values[0].textContent = view.key;
    values[1].textContent = view.org.key;
    values[2].textContent = fmt.format(view.sessions);
    values[3].textContent = `${share}%`;
    if (!sun || sun === view) {
      values[4].textContent = 'None, largest of its organization';
    } else {
      values[4].textContent = sun.key;
      values[4].className = 'id';
    }
    tip.hidden = false;
    positionTooltip();
  }

  function positionTooltip() {
    const tip = $('tooltip');
    if (tip.hidden) return;
    const pad = 14;
    const { width, height } = tip.getBoundingClientRect();
    let x = pointerClient.x + pad;
    let y = pointerClient.y + pad;
    if (x + width > window.innerWidth - 8) x = pointerClient.x - width - pad;
    if (y + height > window.innerHeight - 8) y = pointerClient.y - height - pad;
    tip.style.transform = `translate(${Math.max(8, x)}px, ${Math.max(8, y)}px)`;
  }

  const canvas = renderer.domElement;
  canvas.addEventListener('pointermove', (event) => {
    pointerInside = true;
    pointerClient = { x: event.clientX, y: event.clientY };
    setPointer(event);
    positionTooltip();
  });
  canvas.addEventListener('pointerleave', () => { pointerInside = false; setHovered(null); });
  canvas.addEventListener('pointerdown', (event) => { pointerDown = { x: event.clientX, y: event.clientY }; });
  canvas.addEventListener('pointerup', (event) => {
    if (!pointerDown) return;
    const moved = Math.hypot(event.clientX - pointerDown.x, event.clientY - pointerDown.y);
    pointerDown = null;
    if (moved > 5) return;
    setPointer(event);
    const view = pick();
    if (view) focusCluster(view, false);
    else focus = null;
  });

  function focusCluster(view, reveal = true) {
    if (!view || view.dying) return;
    focus = view;
    focusArriving = true;
    autoFit = false;
    if (reveal && stacked.matches) {
      $('viewport').scrollIntoView({ block: 'start', behavior: reducedMotion ? 'auto' : 'smooth' });
    }
  }

  function resetView() {
    focus = null;
    focusArriving = false;
    autoFit = true;
  }
  $('reset').addEventListener('click', resetView);
  window.addEventListener('keydown', (event) => { if (event.key === 'Escape') resetView(); });

  function pick() {
    raycaster.setFromCamera(pointer, camera);
    for (const hit of raycaster.intersectObjects(hitTargets, false)) {
      const view = hit.object.userData.view;
      if (!view.dying) return view;
    }
    return null;
  }

  // --------------------------------------------------------------- animation

  const clock = new THREE.Clock();
  const scratch = new THREE.Vector3();
  const offset = new THREE.Vector3();
  const before = new THREE.Vector3();
  const spin = new THREE.Quaternion();
  const tint = new THREE.Color();

  function moveTarget(to, rate) {
    before.copy(controls.target);
    controls.target.lerp(to, rate);
    camera.position.add(offset.subVectors(controls.target, before));
  }
  function easeDistance(wanted, rate) {
    offset.subVectors(camera.position, controls.target);
    const distance = offset.length();
    offset.setLength(distance + (wanted - distance) * rate);
    camera.position.copy(controls.target).add(offset);
    return Math.abs(wanted - distance) / wanted;
  }

  // Labels go to the largest organizations first (the highlighted one always
  // wins); a label that would overlap one already placed stays hidden.
  const placed = [];
  function placeLabels(emphasis) {
    const width = host.clientWidth;
    const height = host.clientHeight;
    const highlighted = emphasis?.org;
    placed.length = 0;
    for (const org of orgOrder) {
      org.label.visible = false;
      org.label.element.classList.toggle('is-active', org === highlighted);
    }
    const candidates = orgOrder
      .filter((org) => !org.dying && org.clusters.length > 0 && (org.rank < LABELLED_ORGS || org === highlighted))
      .sort((a, b) => (b === highlighted) - (a === highlighted) || a.rank - b.rank);
    for (const org of candidates) {
      org.label.position.set(org.center.x, org.center.y + (org.sun ? org.sun.radius : 2) + 1.5, org.center.z);
      scratch.copy(org.label.position).project(camera);
      if (scratch.z > 1) continue;
      const x = ((scratch.x + 1) / 2) * width;
      const y = ((1 - scratch.y) / 2) * height;
      const box = [x, y - LABEL_BOX.height, x + LABEL_BOX.width, y];
      if (placed.some((p) => box[0] < p[2] && box[2] > p[0] && box[1] < p[3] && box[3] > p[1])) continue;
      placed.push(box);
      org.label.visible = true;
    }
  }

  function frame() {
    const dt = Math.min(clock.getDelta(), 0.1);
    const k = (rate) => (reducedMotion ? 1 : 1 - Math.exp(-dt * rate));
    const motion = reducedMotion ? 0 : dt;

    // Constellations grow and shrink with their session counts.
    for (const view of clusters.values()) {
      const target = view.dying ? 0 : view.sessions;
      view.shown += (target - view.shown) * k(3);
      if (Math.abs(target - view.shown) < 0.01) view.shown = target;
      view.radius += (constellationRadius(view.sessions || view.shown) - view.radius) * k(2);
      const count = Math.min(MAX_STARS, Math.ceil(Math.max(view.shown, view.sessions)));
      ensureStars(view, count);
      if (count !== view.edgeCount) linkStars(view, count);
    }

    // Each organization's largest cluster sits at its center; the rest orbit it.
    for (const org of orgOrder) {
      let sun = org.sun && !org.sun.dying ? org.sun : null;
      for (const view of org.clusters) {
        if (!view.dying && (!sun || view.sessions > sun.sessions)) sun = view;
      }
      org.sun = sun ?? org.clusters[0] ?? null;
      let r = (org.sun ? org.sun.radius : 0) + ORBIT_GAP;
      for (const view of org.clusters) {
        if (view === org.sun) { view.orbitTarget = 0; continue; }
        r += view.radius;
        view.orbitTarget = r;
        r += view.radius + ORBIT_GAP;
      }
      org.extent = org.clusters.length > 1 ? r - ORBIT_GAP : (org.sun?.radius ?? 0);
    }

    // Organizations sit on a sunflower spiral that gives each one room for its own
    // size (first-seen order keeps existing ones in place), then any overlaps are
    // pushed apart. Both steps are deterministic, so the layout holds still.
    let area = 0;
    orgOrder.forEach((org, i) => {
      const room = org.extent + ORG_MARGIN;
      const r = Math.sqrt(area) * 1.1;
      area += room * room;
      const a = i * GOLDEN_ANGLE;
      org.target.set(Math.cos(a) * r, i === 0 ? 0 : org.yOffset, Math.sin(a) * r);
    });
    for (let pass = 0; pass < 8; pass++) {
      for (let i = 0; i < orgOrder.length; i++) {
        for (let j = i + 1; j < orgOrder.length; j++) {
          const a = orgOrder[i].target;
          const b = orgOrder[j].target;
          const dx = b.x - a.x;
          const dz = b.z - a.z;
          const d = Math.hypot(dx, dz) || 0.001;
          const needed = orgOrder[i].extent + orgOrder[j].extent + ORG_MARGIN;
          if (d >= needed) continue;
          const push = (needed - d) / 2 / d;
          a.x -= dx * push; a.z -= dz * push;
          b.x += dx * push; b.z += dz * push;
        }
      }
    }
    let layoutRadius = 0;
    for (const org of orgOrder) {
      if (org.fresh) { org.center.copy(org.target); org.fresh = false; }
      else org.center.lerp(org.target, k(2));
      layoutRadius = Math.max(layoutRadius, Math.hypot(org.target.x, org.target.z) + org.extent);
    }

    const emphasis = hovered ?? (rowHovered && clusters.get(rowHovered)) ?? focus;
    markActiveRow(emphasis);

    placeLabels(emphasis);

    for (const org of orgOrder) {
      const active = Boolean(emphasis && emphasis.org === org);

      for (const view of org.clusters) {
        if (view === org.sun) {
          scratch.copy(org.center);
          view.orbit.visible = false;
        } else {
          if (view.fresh) view.orbitRadius = view.orbitTarget;
          view.orbitRadius += (view.orbitTarget - view.orbitRadius) * k(2);
          view.angle += motion * orbitalSpeed(view.orbitRadius);
          scratch.set(Math.cos(view.angle) * view.orbitRadius, 0, Math.sin(view.angle) * view.orbitRadius)
            .applyQuaternion(org.tilt)
            .add(org.center);
          view.orbit.visible = true;
          view.orbit.position.copy(org.center);
          view.orbit.quaternion.copy(org.tilt);
          view.orbit.scale.setScalar(Math.max(view.orbitRadius, 0.01));
          view.orbit.material = active ? orbitActiveMaterial : orbitMaterial;
        }
        if (view.fresh) { view.pos.copy(scratch); view.fresh = false; }
        else view.pos.lerp(scratch, k(4));
        view.spin += motion * view.spinRate;

        view.level += ((!emphasis || view === emphasis ? 1 : active ? 0.75 : 0.25) - view.level) * k(8);
        view.accent += ((view === emphasis ? 1 : active ? 0.4 : 0) - view.accent) * k(8);

        view.hit.position.copy(view.pos);
        view.hit.scale.setScalar(view.radius + 1.5);
      }
    }

    // Stars and the peer-to-peer links between them.
    let starCount = 0;
    let linkCount = 0;
    for (const view of clusters.values()) {
      starCount += Math.ceil(Math.min(view.shown, MAX_STARS));
      linkCount += view.edges.length;
    }
    stars = grow(stars, starCount, buildStars);
    links = grow(links, linkCount, buildLinks);
    const sPos = stars.geometry.attributes.position.array;
    const sCol = stars.geometry.attributes.color.array;
    const lPos = links.geometry.attributes.position.array;
    const lCol = links.geometry.attributes.color.array;
    let si = 0;
    let li = 0;
    for (const view of clusters.values()) {
      const visible = Math.min(view.shown, MAX_STARS);
      const n = Math.ceil(visible);
      spin.setFromAxisAngle(view.spinAxis, view.spin);
      for (let i = 0; i < n; i++) {
        const star = view.stars[i];
        scratch.copy(star.p).multiplyScalar(view.radius).applyQuaternion(spin).add(view.pos);
        view.world[i * 3] = scratch.x;
        view.world[i * 3 + 1] = scratch.y;
        view.world[i * 3 + 2] = scratch.z;
        const b = Math.min(1, visible - i) * view.level;
        sPos.set([scratch.x, scratch.y, scratch.z], si * 3);
        sCol.set([star.color.r * b, star.color.g * b, star.color.b * b], si * 3);
        si++;
      }
      tint.copy(palette.link).lerp(palette.accent, view.accent);
      const strength = view.level * (view.edgeCount <= FULL_MESH ? 1 : 0.75);
      for (let e = 0; e < view.edges.length; e += 2) {
        const a = view.edges[e];
        const b = view.edges[e + 1];
        if (a >= n || b >= n) continue;
        const alpha = Math.min(1, visible - a, visible - b) * strength;
        for (const index of [a, b]) {
          lPos.set([view.world[index * 3], view.world[index * 3 + 1], view.world[index * 3 + 2]], li * 3);
          lCol.set([tint.r * alpha, tint.g * alpha, tint.b * alpha], li * 3);
          li++;
        }
      }
    }
    stars.geometry.setDrawRange(0, si);
    stars.geometry.attributes.position.needsUpdate = true;
    stars.geometry.attributes.color.needsUpdate = true;
    links.geometry.setDrawRange(0, li);
    links.geometry.attributes.position.needsUpdate = true;
    links.geometry.attributes.color.needsUpdate = true;

    // Retire clusters and organizations that have faded out.
    for (const view of [...clusters.values()]) {
      if (view.dying && view.shown < 0.02) disposeCluster(view);
    }
    for (let i = orgOrder.length - 1; i >= 0; i--) {
      const org = orgOrder[i];
      if (org.dying && org.clusters.length === 0) {
        scene.remove(org.label);
        orgOrder.splice(i, 1);
        orgs.delete(org.key);
      }
    }

    // Camera: follow the focused cluster, or keep every organization in frame.
    if (focus) {
      moveTarget(focus.pos, k(4));
      if (focusArriving && easeDistance(Math.max(20, focus.radius * 4 + 10), k(2)) < 0.02) focusArriving = false;
    } else if (autoFit) {
      moveTarget(scratch.set(0, 0, 0), k(2));
      offset.subVectors(camera.position, controls.target).normalize();
      const elevation = Math.asin(THREE.MathUtils.clamp(Math.abs(offset.y), 0, 1));
      const halfHeight = layoutRadius * Math.sin(elevation) + 12 * Math.cos(elevation);
      const vertical = THREE.MathUtils.degToRad(camera.fov) / 2;
      const horizontal = Math.atan(Math.tan(vertical) * camera.aspect);
      const fit = Math.max(layoutRadius / Math.tan(horizontal), halfHeight / Math.tan(vertical));
      easeDistance(Math.max(30, fit * 1.08 + 6), k(1.5));
    }
    controls.update();
    backdrop.position.copy(camera.position);
    ensurePolar(layoutRadius);

    if (pointerInside && !pointerDown) setHovered(pick());

    renderer.render(scene, camera);
    labelRenderer.render(scene, camera);
  }

  renderer.setAnimationLoop(frame);
  poll();
</script>
</body>
</html>
""".
