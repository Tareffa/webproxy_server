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
    color-scheme: light;
    --page: #f9f9f7;
    --surface: #fcfcfb;
    --ink: #0b0b0b;
    --ink-2: #52514e;
    --ink-3: #6b6a65;
    --grid: #e1e0d9;
    --axis: #c3c2b7;
    --muted-mark: #cfcdc5;
    --series: #2a78d6;
    --series-strong: #1c5cab;
    --good: #0ca30c;
    --critical: #d03b3b;
    --border: rgba(11, 11, 11, 0.1);
    --wash: rgba(42, 120, 214, 0.08);
    --shadow: 0 2px 8px rgba(11, 11, 11, 0.08);
    --sans: system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
    --mono: ui-monospace, "SF Mono", "Cascadia Mono", Consolas, monospace;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      color-scheme: dark;
      --page: #0d0d0d;
      --surface: #1a1a19;
      --ink: #f0efec;
      --ink-2: #c3c2b7;
      --ink-3: #9a9890;
      --grid: #2c2c2a;
      --axis: #4a4a47;
      --muted-mark: #42423f;
      --series: #3987e5;
      --series-strong: #86b6ef;
      --border: rgba(255, 255, 255, 0.1);
      --wash: rgba(57, 135, 229, 0.14);
      --shadow: 0 2px 8px rgba(0, 0, 0, 0.4);
    }
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
  :focus-visible { outline: 2px solid var(--series); outline-offset: 2px; }

  .layout {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 360px;
    height: 100vh;
    height: 100dvh;
  }

  .viewport { position: relative; min-width: 0; background: var(--surface); }
  #scene { position: absolute; inset: 0; }
  #scene canvas { display: block; width: 100%; height: 100%; }

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
    min-width: 220px;
    padding: 10px 12px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 6px;
    box-shadow: var(--shadow);
    pointer-events: none;
  }
  .tooltip[hidden] { display: none; }
  .tooltip dl { display: grid; grid-template-columns: auto auto; gap: 2px 16px; margin: 0; }
  .tooltip dt { color: var(--ink-3); }
  .tooltip dd { margin: 0; text-align: right; font-variant-numeric: tabular-nums; }

  .panel {
    display: flex;
    flex-direction: column;
    min-height: 0;
    padding: 20px 20px 0;
    border-left: 1px solid var(--border);
  }
  .panel-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
  h1 { margin: 0; font-size: 15px; font-weight: 600; letter-spacing: 0; }

  button {
    font: inherit;
    font-size: 12.5px;
    color: var(--ink);
    background: transparent;
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 4px 10px;
    cursor: pointer;
  }
  button:hover { background: var(--wash); }

  .status { display: flex; align-items: center; gap: 8px; margin: 4px 0 0; color: var(--ink-2); font-size: 12.5px; }
  .status::before { content: ""; flex: none; width: 7px; height: 7px; border-radius: 50%; background: var(--axis); }
  .status[data-state="live"]::before { background: var(--good); }
  .status[data-state="down"]::before { background: var(--critical); }

  .summary { margin: 18px 0 0; font-size: 14px; color: var(--ink-2); }
  .summary strong { color: var(--ink); font-weight: 600; }
  .caption { margin: 6px 0 0; color: var(--ink-3); font-size: 12.5px; max-width: 60ch; }

  .table-wrap {
    flex: 1;
    min-height: 0;
    margin: 18px -20px 0;
    padding: 0 20px 20px;
    overflow: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--axis) transparent;
  }
  table { width: 100%; border-collapse: collapse; font-size: 12.5px; }
  caption { position: absolute; width: 1px; height: 1px; overflow: hidden; clip-path: inset(50%); white-space: nowrap; }
  th {
    position: sticky;
    top: 0;
    padding: 6px 8px;
    background: var(--page);
    border-bottom: 1px solid var(--axis);
    color: var(--ink-3);
    font-weight: 500;
    text-align: left;
  }
  td { padding: 6px 8px; border-bottom: 1px solid var(--grid); }
  th:first-child, td:first-child { padding-left: 0; }
  th:last-child, td:last-child { padding-right: 0; }
  .num { text-align: right; font-variant-numeric: tabular-nums; }
  .id { font-family: var(--mono); font-size: 12px; color: var(--ink-2); }
  tbody tr { cursor: pointer; }
  tbody tr:hover, tbody tr.is-active { background: var(--wash); }
  tbody tr.is-active .id:first-child { color: var(--ink); }
  tbody tr:focus-visible { outline-offset: -2px; }
  .no-rows { margin: 12px 0 0; color: var(--ink-3); }
  .no-rows[hidden] { display: none; }

  @media (max-width: 860px) {
    .layout { grid-template-columns: 1fr; grid-template-rows: 58vh auto; height: auto; }
    .viewport { min-height: 320px; }
    .panel { border-left: 0; border-top: 1px solid var(--border); }
    .table-wrap { overflow: visible; }
  }
</style>
</head>
<body>
<main class="layout">
  <section class="viewport" id="viewport" aria-label="3D view of the clusters">
    <div id="scene"></div>
    <p id="empty" class="empty" hidden><span><strong>No live sessions</strong>Clusters appear here as clients connect.</span></p>
  </section>

  <aside class="panel" aria-labelledby="title">
    <div class="panel-head">
      <h1 id="title">WebProxy clusters</h1>
      <button id="reset" type="button" title="Reset view (Esc)">Reset view</button>
    </div>
    <p id="status" class="status" role="status">Connecting…</p>
    <p id="summary" class="summary">Waiting for data…</p>
    <p class="caption">Each column is a cluster and each dot one live session. Columns on the same ground ring belong to the same organization. Drag to rotate, scroll or pinch to zoom, select a cluster to focus it.</p>
    <div class="table-wrap">
      <table>
        <caption>Clusters by live sessions</caption>
        <thead>
          <tr><th scope="col">Cluster</th><th scope="col">Organization</th><th scope="col" class="num">Sessions</th></tr>
        </thead>
        <tbody id="rows"></tbody>
      </table>
      <p id="no-rows" class="no-rows" hidden>No clusters.</p>
    </div>
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

  const POLL_MS = 2000;
  const HIDDEN_POLL_MS = 15000;
  const MAX_DOTS = 150;        // per column; past this, each dot stands for several sessions
  const BASE_STEP = 1.5;       // vertical spacing between session dots
  const MAX_COLUMN = 48;       // height of the tallest column, in world units
  const CLUSTER_GAP = 3.6;     // spacing between the columns of one organization
  const GOLDEN_ANGLE = Math.PI * (3 - Math.sqrt(5));
  // Works whether the page was opened as /info/visual or /info/visual/.
  const DATA_URL = location.pathname.replace(/\/+$/, '') + '/data';
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const stacked = matchMedia('(max-width: 860px)');

  const $ = (id) => document.getElementById(id);
  const fmt = new Intl.NumberFormat();

  // ------------------------------------------------------------------- theme

  const theme = {};
  function readTheme() {
    const css = getComputedStyle(document.documentElement);
    for (const name of ['surface', 'grid', 'axis', 'muted-mark', 'series', 'series-strong']) {
      theme[name] = new THREE.Color(css.getPropertyValue(`--${name}`).trim());
    }
  }
  readTheme();

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

  const scene = new THREE.Scene();
  scene.fog = new THREE.Fog(0xffffff, 200, 600);
  scene.add(new THREE.HemisphereLight(0xffffff, 0x9a988f, 1.9));
  const sun = new THREE.DirectionalLight(0xffffff, 1.3);
  sun.position.set(40, 90, 30);
  scene.add(sun);

  const camera = new THREE.PerspectiveCamera(40, 1, 0.5, 4000);
  camera.position.set(70, 75, 95);

  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.08;
  controls.maxPolarAngle = Math.PI * 0.47;
  controls.minDistance = 8;
  controls.maxDistance = 800;

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
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }).observe(host);

  // ------------------------------------------------------------ scene parts

  // A floor bounded to the layout, with cells sized to it, reads as a plot area
  // rather than an endless plane that aliases toward the horizon.
  let grid = null;
  let gridKey = '';
  function ensureGrid(radius) {
    const extent = radius + 12;
    const cell = [5, 10, 20, 25, 50, 100].find((c) => (extent * 2) / c <= 16) ?? 200;
    const size = Math.ceil((extent * 2) / cell) * cell;
    const key = `${size}/${cell}`;
    if (key === gridKey) return;
    if (grid) { scene.remove(grid); grid.geometry.dispose(); grid.material.dispose(); }
    grid = new THREE.GridHelper(size, size / cell, theme.grid, theme.grid);
    gridKey = key;
    scene.add(grid);
  }

  const dotGeometry = new THREE.SphereGeometry(1, 16, 12);
  const dotMaterial = new THREE.MeshLambertMaterial();
  let dots = makeDots(512);
  function makeDots(capacity) {
    const mesh = new THREE.InstancedMesh(dotGeometry, dotMaterial, capacity);
    mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    mesh.setColorAt(0, theme.series);
    mesh.count = 0;
    mesh.frustumCulled = false;
    scene.add(mesh);
    return mesh;
  }
  function ensureDots(needed) {
    if (needed <= dots.instanceMatrix.count) return;
    let capacity = dots.instanceMatrix.count;
    while (capacity < needed) capacity *= 2;
    scene.remove(dots);
    dots.dispose();
    dots = makeDots(capacity);
  }

  const stemMaterial = new THREE.LineBasicMaterial({ color: theme.axis });
  let stems = makeStems(128);
  function makeStems(capacity) {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(capacity * 6), 3).setUsage(THREE.DynamicDrawUsage));
    geometry.userData.capacity = capacity;
    const lines = new THREE.LineSegments(geometry, stemMaterial);
    lines.frustumCulled = false;
    scene.add(lines);
    return lines;
  }
  function ensureStems(needed) {
    let capacity = stems.geometry.userData.capacity;
    if (needed <= capacity) return;
    while (capacity < needed) capacity *= 2;
    scene.remove(stems);
    stems.geometry.dispose();
    stems = makeStems(capacity);
  }

  const ringGeometry = new THREE.BufferGeometry().setFromPoints(
    Array.from({ length: 96 }, (_, i) => {
      const a = (i / 96) * Math.PI * 2;
      return new THREE.Vector3(Math.cos(a), 0, Math.sin(a));
    }),
  );
  const ringMaterial = new THREE.LineBasicMaterial({ color: theme.axis });
  const ringActiveMaterial = new THREE.LineBasicMaterial({ color: theme.series });

  const hitGeometry = new THREE.CylinderGeometry(1, 1, 1, 12);
  const hitMaterial = new THREE.MeshBasicMaterial({ visible: false });

  function applyTheme() {
    readTheme();
    scene.background = theme.surface;
    scene.fog.color = theme.surface;
    stemMaterial.color = theme.axis;
    ringMaterial.color = theme.axis;
    ringActiveMaterial.color = theme.series;
    gridKey = '';
  }
  applyTheme();
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', applyTheme);

  // ------------------------------------------------------------------- model

  const orgs = new Map();       // anonymized organization id -> org
  const orgOrder = [];          // first-seen order, so existing orgs keep their place
  const clusters = new Map();   // anonymized cluster id -> column
  const hitTargets = [];
  let totalSessions = 0;
  let maxSessions = 1;
  let step = BASE_STEP;

  function hash01(text) {
    let h = 2166136261;
    for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619);
    return (h >>> 0) / 4294967296;
  }

  function createOrg(key) {
    const ring = new THREE.LineLoop(ringGeometry, ringMaterial);
    scene.add(ring);
    const org = {
      key, ring,
      center: new THREE.Vector3(),
      target: new THREE.Vector3(),
      phase: hash01(key) * Math.PI * 2,
      radius: 0,
      footprint: 0,
      clusters: [],
      dying: false,
      fresh: true,
    };
    orgs.set(key, org);
    orgOrder.push(org);
    return org;
  }

  function createCluster(key, org) {
    const hit = new THREE.Mesh(hitGeometry, hitMaterial);
    scene.add(hit);
    const view = {
      key, org, hit,
      sessions: 0,
      shown: 0,
      height: 0,
      pos: new THREE.Vector3(),
      color: theme.series.clone(),
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
    scene.remove(view.hit);
    hitTargets.splice(hitTargets.indexOf(view.hit), 1);
    view.org.clusters.splice(view.org.clusters.indexOf(view), 1);
    clusters.delete(view.key);
    if (hovered === view) setHovered(null);
    if (focus === view) focus = null;
  }

  function applySnapshot(data) {
    const list = Array.isArray(data.clusters) ? data.clusters : [];
    const seenClusters = new Set();
    const seenOrgs = new Set();

    for (const entry of list) {
      seenClusters.add(entry.id);
      seenOrgs.add(entry.organization);
      const org = orgs.get(entry.organization) ?? createOrg(entry.organization);
      org.dying = false;
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

    totalSessions = data.sessionCount ?? list.reduce((n, c) => n + c.sessions, 0);
    maxSessions = Math.max(1, ...list.map((c) => c.sessions));

    $('summary').innerHTML = list.length
      ? `<strong>${fmt.format(totalSessions)}</strong> ${totalSessions === 1 ? 'session' : 'sessions'} in `
        + `<strong>${fmt.format(list.length)}</strong> ${list.length === 1 ? 'cluster' : 'clusters'} across `
        + `<strong>${fmt.format(seenOrgs.size)}</strong> ${seenOrgs.size === 1 ? 'organization' : 'organizations'}`
      : 'No live sessions.';
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

  function makeRow(key) {
    const tr = document.createElement('tr');
    tr.dataset.key = key;
    tr.tabIndex = 0;
    tr.innerHTML = '<td class="id"></td><td class="id"></td><td class="num"></td>';
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

  function renderTable(list) {
    const sorted = [...list].sort((a, b) => b.sessions - a.sessions || a.id.localeCompare(b.id));
    const keep = new Set(sorted.map((c) => c.id));
    for (const [key, tr] of rows) {
      if (!keep.has(key)) { tr.remove(); rows.delete(key); if (rowHovered === key) rowHovered = null; }
    }
    for (const c of sorted) {
      const cells = (rows.get(c.id) ?? makeRow(c.id)).children;
      cells[0].textContent = c.id;
      cells[1].textContent = c.organization;
      cells[2].textContent = fmt.format(c.sessions);
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
      pollTimer = setTimeout(poll, document.hidden ? HIDDEN_POLL_MS : POLL_MS);
    }
  }
  function setStatus(ok) {
    const el = $('status');
    el.dataset.state = ok ? 'live' : 'down';
    el.textContent = ok
      ? `Live, updated ${new Date().toLocaleTimeString()}`
      : 'Connection lost, retrying';
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
    tip.innerHTML = '<dl><dt>Cluster</dt><dd class="id"></dd><dt>Organization</dt><dd class="id"></dd>'
      + '<dt>Live sessions</dt><dd></dd><dt>Share of sessions</dt><dd></dd></dl>';
    const values = tip.querySelectorAll('dd');
    values[0].textContent = view.key;
    values[1].textContent = view.org.key;
    values[2].textContent = fmt.format(view.sessions);
    values[3].textContent = `${share}%`;
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
  const matrix = new THREE.Matrix4();
  const dotScale = new THREE.Vector3();
  const noRotation = new THREE.Quaternion();

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

  function frame() {
    const dt = Math.min(clock.getDelta(), 0.1);
    const k = (rate) => (reducedMotion ? 1 : 1 - Math.exp(-dt * rate));

    // One vertical scale for every column, so heights stay comparable.
    step += (Math.min(BASE_STEP, MAX_COLUMN / maxSessions) - step) * k(3);

    let maxHeight = 0;
    for (const view of clusters.values()) {
      view.shown += (view.sessions - view.shown) * k(4);
      if (Math.abs(view.sessions - view.shown) < 0.01) view.shown = view.sessions;
      view.height = view.shown * step;
      maxHeight = Math.max(maxHeight, view.height);
    }

    // Each organization stands its columns on a ring sized to fit them.
    let maxFootprint = 0;
    for (const org of orgOrder) {
      const m = org.clusters.length;
      const radius = m <= 1 ? 0 : Math.max(CLUSTER_GAP, (m * CLUSTER_GAP) / (2 * Math.PI));
      org.radius += (radius - org.radius) * k(3);
      org.footprint = org.radius + 2.6;
      maxFootprint = Math.max(maxFootprint, org.footprint);
    }

    // Organizations sit on a sunflower spiral; first-seen order keeps existing ones in place.
    const spacing = Math.max(10, maxFootprint * 1.3 + 3);
    orgOrder.forEach((org, i) => {
      const r = spacing * Math.sqrt(i);
      const a = i * GOLDEN_ANGLE;
      org.target.set(Math.cos(a) * r, 0, Math.sin(a) * r);
      if (org.fresh) { org.center.copy(org.target); org.fresh = false; }
      else org.center.lerp(org.target, k(2.5));
    });

    const emphasis = hovered ?? (rowHovered && clusters.get(rowHovered)) ?? focus;
    markActiveRow(emphasis);

    for (const org of orgOrder) {
      const m = org.clusters.length;
      org.ring.position.set(org.center.x, 0.02, org.center.z);
      org.ring.scale.setScalar(org.footprint);
      org.ring.material = emphasis && emphasis.org === org ? ringActiveMaterial : ringMaterial;
      org.clusters.forEach((view, idx) => {
        if (m <= 1) {
          scratch.copy(org.center);
        } else {
          const a = org.phase + (idx / m) * Math.PI * 2;
          scratch.set(org.center.x + Math.cos(a) * org.radius, 0, org.center.z + Math.sin(a) * org.radius);
        }
        if (view.fresh) { view.pos.copy(scratch); view.fresh = false; }
        else view.pos.lerp(scratch, k(3));

        const color = !emphasis ? theme.series
          : view === emphasis ? theme['series-strong']
          : view.org === emphasis.org ? theme.series
          : theme['muted-mark'];
        view.color.lerp(color, k(12));

        view.hit.position.set(view.pos.x, (view.height + 2) / 2, view.pos.z);
        view.hit.scale.set(1.8, view.height + 2, 1.8);
      });
    }

    // Session dots: one per session up to MAX_DOTS, evenly spaced up the column.
    let needed = 0;
    for (const view of clusters.values()) needed += Math.ceil(Math.min(view.shown, MAX_DOTS));
    ensureDots(needed);
    ensureStems(clusters.size);
    const stemPositions = stems.geometry.attributes.position.array;
    let di = 0;
    let si = 0;
    for (const view of clusters.values()) {
      const count = Math.min(view.shown, MAX_DOTS);
      const gap = count > 0 ? view.height / count : step;
      const radius = THREE.MathUtils.clamp(gap * 0.36, 0.3, 0.55);
      for (let i = 0; i < Math.ceil(count); i++) {
        const grow = Math.min(1, count - i);
        dotScale.setScalar(radius * grow);
        scratch.set(view.pos.x, gap * (i + 0.5), view.pos.z);
        dots.setMatrixAt(di, matrix.compose(scratch, noRotation, dotScale));
        dots.setColorAt(di, view.color);
        di++;
      }
      stemPositions.set([view.pos.x, 0, view.pos.z, view.pos.x, Math.max(view.height, 0.6), view.pos.z], si * 6);
      si++;
    }
    dots.count = di;
    dots.instanceMatrix.needsUpdate = true;
    if (dots.instanceColor) dots.instanceColor.needsUpdate = true;
    stems.geometry.setDrawRange(0, si * 2);
    stems.geometry.attributes.position.needsUpdate = true;

    // Retire columns and organizations that have finished shrinking away.
    for (const view of [...clusters.values()]) {
      if (view.dying && view.shown < 0.02) disposeCluster(view);
    }
    for (let i = orgOrder.length - 1; i >= 0; i--) {
      const org = orgOrder[i];
      if (org.dying && org.clusters.length === 0) {
        scene.remove(org.ring);
        orgOrder.splice(i, 1);
        orgs.delete(org.key);
      }
    }

    // Camera: follow the focused column, or keep the whole layout framed.
    const layoutRadius = spacing * Math.sqrt(Math.max(orgOrder.length - 1, 0)) + maxFootprint;
    if (focus) {
      moveTarget(scratch.set(focus.pos.x, focus.height / 2, focus.pos.z), k(4));
      if (focusArriving && easeDistance(Math.max(24, focus.height * 1.4 + 18), k(2)) < 0.02) focusArriving = false;
    } else if (autoFit) {
      moveTarget(scratch.set(0, maxHeight * 0.4, 0), k(2));
      // Project the layout as seen from the current elevation: the floor's depth
      // foreshortens, the columns' height does not.
      offset.subVectors(camera.position, controls.target).normalize();
      const elevation = Math.asin(THREE.MathUtils.clamp(offset.y, 0, 1));
      const halfHeight = (maxHeight * Math.cos(elevation) + 2 * layoutRadius * Math.sin(elevation)) / 2;
      const vertical = THREE.MathUtils.degToRad(camera.fov) / 2;
      const horizontal = Math.atan(Math.tan(vertical) * camera.aspect);
      const fit = Math.max(layoutRadius / Math.tan(horizontal), halfHeight / Math.tan(vertical));
      easeDistance(Math.max(30, fit * 1.12 + 6), k(1.5));
    }
    controls.update();

    const distance = camera.position.distanceTo(controls.target);
    scene.fog.near = distance * 1.2;
    scene.fog.far = distance * 3.2;
    ensureGrid(layoutRadius);

    if (pointerInside && !pointerDown) setHovered(pick());

    renderer.render(scene, camera);
  }

  renderer.setAnimationLoop(frame);
  poll();
</script>
</body>
</html>
""".
