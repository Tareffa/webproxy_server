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
    --bg: #05070d;
    --panel: rgba(11, 15, 27, 0.68);
    --panel-border: rgba(150, 175, 255, 0.13);
    --panel-border-strong: rgba(150, 175, 255, 0.32);
    --text: #e8ecf6;
    --muted: #8d97ad;
    --live: #4ade80;
    --down: #f87171;
    --focus: #8fb0ff;
    --radius: 12px;
    color-scheme: dark;
  }
  * { box-sizing: border-box; }
  html, body {
    margin: 0;
    height: 100%;
    overflow: hidden;
    background: var(--bg);
    color: var(--text);
    font: 14px/1.4 ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  #scene, #scene canvas { position: fixed; inset: 0; display: block; }
  .panel {
    background: var(--panel);
    border: 1px solid var(--panel-border);
    border-radius: var(--radius);
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
  }

  .masthead {
    position: fixed;
    top: 16px;
    left: 16px;
    width: min(360px, calc(100vw - 32px));
    padding: 14px 16px;
  }
  .masthead h1 { margin: 0; font-size: 15px; font-weight: 600; letter-spacing: 0.01em; }
  .masthead p { margin: 6px 0 0; color: var(--muted); font-size: 12.5px; }
  .masthead .row { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-top: 12px; }

  .status { display: inline-flex; align-items: center; gap: 8px; font-size: 12px; color: var(--muted); }
  .status::before { content: ""; flex: none; width: 8px; height: 8px; border-radius: 50%; background: var(--muted); }
  .status[data-state="live"]::before { background: var(--live); animation: pulse 2s infinite; }
  .status[data-state="down"] { color: var(--down); }
  .status[data-state="down"]::before { background: var(--down); }
  @keyframes pulse {
    0% { box-shadow: 0 0 0 0 rgba(74, 222, 128, 0.55); }
    70% { box-shadow: 0 0 0 7px rgba(74, 222, 128, 0); }
    100% { box-shadow: 0 0 0 0 rgba(74, 222, 128, 0); }
  }

  button {
    font: inherit;
    font-size: 12px;
    color: var(--text);
    background: rgba(150, 175, 255, 0.08);
    border: 1px solid var(--panel-border);
    border-radius: 8px;
    padding: 6px 10px;
    cursor: pointer;
  }
  button:hover { border-color: var(--panel-border-strong); }
  button:focus-visible { outline: 2px solid var(--focus); outline-offset: 2px; }

  .stats {
    position: fixed;
    left: 16px;
    right: 16px;
    bottom: 16px;
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 160px));
    gap: 8px;
    pointer-events: none;
  }
  .stat { padding: 10px 12px; }
  .stat .value { display: block; font-size: 22px; font-weight: 600; font-variant-numeric: tabular-nums; }
  .stat .label { display: block; margin-top: 2px; font-size: 11.5px; color: var(--muted); }
  @media (max-width: 720px) {
    .stats { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    .stat .value { font-size: 18px; }
  }

  .tooltip {
    position: fixed;
    left: 0;
    top: 0;
    min-width: 200px;
    padding: 10px 12px;
    font-size: 12.5px;
    pointer-events: none;
    z-index: 10;
  }
  .tooltip[hidden] { display: none; }
  .tooltip .title { display: flex; align-items: center; gap: 8px; font-weight: 600; margin-bottom: 6px; }
  .tooltip .swatch { flex: none; width: 9px; height: 9px; border-radius: 50%; }
  .tooltip dl { display: grid; grid-template-columns: auto 1fr; gap: 3px 14px; margin: 0; }
  .tooltip dt { color: var(--muted); }
  .tooltip dd { margin: 0; text-align: right; font-variant-numeric: tabular-nums; }
  code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 12px; }

  .empty {
    position: fixed;
    inset: 0;
    display: grid;
    place-items: center;
    padding: 16px;
    text-align: center;
    pointer-events: none;
  }
  .empty[hidden] { display: none; }
  .empty strong { display: block; font-size: 16px; font-weight: 600; }
  .empty span { display: block; margin-top: 4px; color: var(--muted); font-size: 13px; }

  @media (prefers-reduced-motion: reduce) {
    .status[data-state="live"]::before { animation: none; }
  }
</style>
</head>
<body>
<div id="scene" aria-hidden="true"></div>

<header class="masthead panel">
  <h1>WebProxy · Live clusters</h1>
  <p>Each glow is a cluster: one organization on one network. Color marks the organization, and the orbiting points are live sessions.</p>
  <p>Drag to orbit, scroll to zoom, click a cluster to follow it.</p>
  <div class="row">
    <span id="status" class="status" role="status">Connecting…</span>
    <button id="reset" type="button" title="Reset view (Esc)">Reset view</button>
  </div>
</header>

<section class="stats" aria-label="Totals">
  <div class="stat panel"><span class="value" id="stat-sessions">–</span><span class="label">Live sessions</span></div>
  <div class="stat panel"><span class="value" id="stat-clusters">–</span><span class="label">Clusters</span></div>
  <div class="stat panel"><span class="value" id="stat-orgs">–</span><span class="label">Organizations</span></div>
  <div class="stat panel"><span class="value" id="stat-largest">–</span><span class="label">Largest cluster</span></div>
</section>

<div id="tooltip" class="tooltip panel" hidden></div>

<div id="empty" class="empty" hidden>
  <div><strong>No live sessions</strong><span>Clusters appear here as clients connect.</span></div>
</div>

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
  const MAX_PARTICLES_PER_CLUSTER = 400;
  const GOLDEN_ANGLE = Math.PI * (3 - Math.sqrt(5));
  // Works whether the page was opened as /info/visual or /info/visual/.
  const DATA_URL = location.pathname.replace(/\/+$/, '') + '/data';
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

  const $ = (id) => document.getElementById(id);
  const fmtInt = new Intl.NumberFormat();

  function showEmpty(title, detail) {
    const el = $('empty');
    el.querySelector('strong').textContent = title;
    el.querySelector('span').textContent = detail;
    el.hidden = false;
  }

  // ---------------------------------------------------------------- renderer

  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({ antialias: true });
  } catch (err) {
    showEmpty('3D view unavailable', 'This browser could not start WebGL.');
    throw err;
  }
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(window.innerWidth, window.innerHeight);
  $('scene').appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x05070d);

  const camera = new THREE.PerspectiveCamera(55, window.innerWidth / window.innerHeight, 0.1, 6000);
  camera.position.set(0, 85, 115);

  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.06;
  controls.autoRotate = !reducedMotion;
  controls.autoRotateSpeed = 0.35;
  controls.minDistance = 6;
  controls.maxDistance = 2000;

  // Until the viewer touches the camera, it keeps everything in frame.
  let autoFit = true;
  let focus = null;
  let focusArriving = false;
  controls.addEventListener('start', () => {
    autoFit = false;
    focusArriving = false;
  });

  const WHITE = new THREE.Color(0xffffff);
  const UP = new THREE.Vector3(0, 1, 0);
  const RIGHT = new THREE.Vector3(1, 0, 0);
  const ORIGIN = new THREE.Vector3();

  function makeGlowTexture() {
    const size = 128;
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = size;
    const ctx = canvas.getContext('2d');
    const g = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
    g.addColorStop(0, 'rgba(255,255,255,1)');
    g.addColorStop(0.18, 'rgba(255,255,255,0.8)');
    g.addColorStop(0.45, 'rgba(255,255,255,0.2)');
    g.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, size, size);
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    return texture;
  }
  const glow = makeGlowTexture();

  // A distant star shell that travels with the camera, so it reads as infinitely far away.
  const stars = (() => {
    const count = 2400;
    const positions = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) {
      const r = 1200 + Math.random() * 1200;
      const y = Math.random() * 2 - 1;
      const theta = Math.random() * Math.PI * 2;
      const s = Math.sqrt(1 - y * y);
      positions[i * 3] = r * s * Math.cos(theta);
      positions[i * 3 + 1] = r * y;
      positions[i * 3 + 2] = r * s * Math.sin(theta);
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    const points = new THREE.Points(geometry, new THREE.PointsMaterial({
      color: 0x8ea2c8, size: 1.3, sizeAttenuation: false, transparent: true, opacity: 0.5, depthWrite: false,
    }));
    scene.add(points);
    return points;
  })();

  // Session particles and organization links live in two shared, growable buffers.
  function makeDynamicGeometry(capacity) {
    const geometry = new THREE.BufferGeometry();
    for (const name of ['position', 'color']) {
      const attribute = new THREE.BufferAttribute(new Float32Array(capacity * 3), 3);
      attribute.setUsage(THREE.DynamicDrawUsage);
      geometry.setAttribute(name, attribute);
    }
    geometry.userData.capacity = capacity;
    geometry.setDrawRange(0, 0);
    return geometry;
  }
  function ensureCapacity(object, needed) {
    let capacity = object.geometry.userData.capacity;
    if (needed <= capacity) return;
    while (capacity < needed) capacity *= 2;
    object.geometry.dispose();
    object.geometry = makeDynamicGeometry(capacity);
  }

  const sessionPoints = new THREE.Points(makeDynamicGeometry(1024), new THREE.PointsMaterial({
    size: 2.6, map: glow, vertexColors: true, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
  }));
  sessionPoints.frustumCulled = false;
  scene.add(sessionPoints);

  const links = new THREE.LineSegments(makeDynamicGeometry(256), new THREE.LineBasicMaterial({
    vertexColors: true, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
  }));
  links.frustumCulled = false;
  scene.add(links);

  // ------------------------------------------------------------------- model

  const orgs = new Map();       // anonymized organization id -> org
  const orgOrder = [];          // first-seen order, so existing orgs keep their slot
  const clusters = new Map();   // anonymized cluster id -> cluster view
  const hitTargets = [];
  const sphere = new THREE.SphereGeometry(1, 24, 16);
  const hitMaterial = new THREE.MeshBasicMaterial({ visible: false });
  let totalSessions = 0;

  function hash01(text, seed) {
    let h = 2166136261 ^ seed;
    for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619);
    return (h >>> 0) / 4294967296;
  }

  const coreRadius = (sessions) => 1.1 + 0.6 * Math.log2(1 + sessions);
  const shellRadius = (core) => core * 2.3 + 2.5;
  const easeOut = (x) => 1 - (1 - x) * (1 - x);

  function createOrg(key) {
    const org = {
      key,
      color: new THREE.Color().setHSL(hash01(key, 1), 0.72, 0.6),
      center: new THREE.Vector3(),
      target: new THREE.Vector3(),
      yOffset: (hash01(key, 2) - 0.5) * 16,
      tilt: new THREE.Quaternion().setFromEuler(new THREE.Euler(
        (hash01(key, 3) - 0.5) * 1.1, 0, (hash01(key, 4) - 0.5) * 1.1,
      )),
      phase: hash01(key, 5) * Math.PI * 2,
      ring: 0,
      extent: 0,
      clusters: [],
      dying: false,
      fresh: true,
    };
    orgs.set(key, org);
    orgOrder.push(org);
    return org;
  }

  function createCluster(key, org) {
    const group = new THREE.Group();
    const core = new THREE.Mesh(sphere, new THREE.MeshBasicMaterial({ color: org.color.clone().lerp(WHITE, 0.6) }));
    const halo = new THREE.Sprite(new THREE.SpriteMaterial({
      map: glow, color: org.color, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    }));
    const hit = new THREE.Mesh(sphere, hitMaterial);
    group.add(core, halo, hit);
    group.scale.setScalar(0.0001);
    scene.add(group);

    const view = {
      key, org, group, core, halo, hit,
      pos: group.position,
      sessions: 0,
      coreR: coreRadius(0),
      shell: shellRadius(coreRadius(0)),
      scale: 0,
      pulse: Math.random() * Math.PI * 2,
      particles: [],
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
    scene.remove(view.group);
    view.core.material.dispose();
    view.halo.material.dispose();
    hitTargets.splice(hitTargets.indexOf(view.hit), 1);
    view.org.clusters.splice(view.org.clusters.indexOf(view), 1);
    clusters.delete(view.key);
    if (hovered === view) setHovered(null);
    if (focus === view) focus = null;
  }

  function newParticle() {
    const normal = new THREE.Vector3().randomDirection();
    const u = new THREE.Vector3().crossVectors(normal, Math.abs(normal.y) < 0.9 ? UP : RIGHT).normalize();
    const v = new THREE.Vector3().crossVectors(normal, u);
    const rFrac = 0.5 + Math.random() * 0.5;
    const direction = Math.random() < 0.5 ? -1 : 1;
    const speed = ((0.35 + Math.random() * 0.5) / Math.sqrt(rFrac)) * direction * (reducedMotion ? 0.15 : 1);
    return { u, v, rFrac, speed, phase: Math.random() * Math.PI * 2, life: 0, dying: false };
  }

  function setSessions(view, sessions) {
    view.sessions = sessions;
    const wanted = Math.min(sessions, MAX_PARTICLES_PER_CLUSTER);
    let alive = view.particles.reduce((n, p) => n + (p.dying ? 0 : 1), 0);
    for (const p of view.particles) {
      if (alive >= wanted) break;
      if (p.dying) { p.dying = false; alive++; }
    }
    while (alive < wanted) { view.particles.push(newParticle()); alive++; }
    for (let i = view.particles.length - 1; i >= 0 && alive > wanted; i--) {
      if (!view.particles[i].dying) { view.particles[i].dying = true; alive--; }
    }
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
      setSessions(view, entry.sessions);
    }
    for (const view of clusters.values()) {
      if (!seenClusters.has(view.key)) { view.dying = true; setSessions(view, 0); }
    }
    for (const org of orgs.values()) {
      if (!seenOrgs.has(org.key)) org.dying = true;
    }

    totalSessions = data.sessionCount ?? list.reduce((n, c) => n + c.sessions, 0);
    const largest = list.reduce((max, c) => Math.max(max, c.sessions), 0);
    $('stat-sessions').textContent = fmtInt.format(totalSessions);
    $('stat-clusters').textContent = fmtInt.format(list.length);
    $('stat-orgs').textContent = fmtInt.format(seenOrgs.size);
    $('stat-largest').textContent = list.length ? fmtInt.format(largest) : '–';
    if (list.length) $('empty').hidden = true;
    else showEmpty('No live sessions', 'Clusters appear here as clients connect.');
    if (hovered) renderTooltip(hovered);
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
      ? `Live · updated ${new Date().toLocaleTimeString()}`
      : 'Connection lost · retrying';
  }
  document.addEventListener('visibilitychange', () => { if (!document.hidden) poll(); });

  // ------------------------------------------------------------- interaction

  const raycaster = new THREE.Raycaster();
  const pointer = new THREE.Vector2();
  let pointerInside = false;
  let pointerClient = { x: 0, y: 0 };
  let pointerDown = null;
  let hovered = null;

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
    tip.innerHTML = `
      <div class="title"><span class="swatch"></span>Cluster <code></code></div>
      <dl>
        <dt>Organization</dt><dd><code></code></dd>
        <dt>Live sessions</dt><dd></dd>
        <dt>Share of all sessions</dt><dd></dd>
      </dl>`;
    tip.querySelector('.swatch').style.background = `#${view.org.color.getHexString()}`;
    tip.querySelector('.title code').textContent = view.key;
    const values = tip.querySelectorAll('dd');
    values[0].querySelector('code').textContent = view.org.key;
    values[1].textContent = fmtInt.format(view.sessions);
    values[2].textContent = `${share}%`;
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
    pointer.set((event.clientX / window.innerWidth) * 2 - 1, -(event.clientY / window.innerHeight) * 2 + 1);
    positionTooltip();
  });
  canvas.addEventListener('pointerleave', () => { pointerInside = false; setHovered(null); });
  canvas.addEventListener('pointerdown', (event) => { pointerDown = { x: event.clientX, y: event.clientY }; });
  canvas.addEventListener('pointerup', (event) => {
    if (!pointerDown) return;
    const moved = Math.hypot(event.clientX - pointerDown.x, event.clientY - pointerDown.y);
    pointerDown = null;
    if (moved > 5) return;
    pointer.set((event.clientX / window.innerWidth) * 2 - 1, -(event.clientY / window.innerHeight) * 2 + 1);
    const view = pick();
    if (view) { focus = view; focusArriving = true; autoFit = false; }
    else focus = null;
  });

  function resetView() {
    focus = null;
    focusArriving = false;
    autoFit = true;
  }
  $('reset').addEventListener('click', resetView);
  window.addEventListener('keydown', (event) => { if (event.key === 'Escape') resetView(); });

  function pick() {
    raycaster.setFromCamera(pointer, camera);
    const hits = raycaster.intersectObjects(hitTargets, false);
    for (const hit of hits) {
      const view = hit.object.userData.view;
      if (!view.dying) return view;
    }
    return null;
  }

  window.addEventListener('resize', () => {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
  });

  // ---------------------------------------------------------------- animation

  const clock = new THREE.Clock();
  const scratch = new THREE.Vector3();
  const offset = new THREE.Vector3();
  const before = new THREE.Vector3();

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
    const t = clock.elapsedTime;
    const k = (rate) => 1 - Math.exp(-dt * rate);

    // Cluster size follows its session count; new clusters grow in, removed ones shrink away.
    for (const view of clusters.values()) {
      view.scale += ((view.dying ? 0 : 1) - view.scale) * k(view.dying ? 4 : 3);
      view.coreR += (coreRadius(view.sessions) - view.coreR) * k(3);
      view.shell = shellRadius(view.coreR);
    }

    // Each organization arranges its clusters on a tilted ring sized to fit them.
    let maxExtent = 0;
    for (const org of orgOrder) {
      const m = org.clusters.length;
      let maxShell = 0;
      for (const view of org.clusters) maxShell = Math.max(maxShell, view.shell);
      const ringTarget = m <= 1 ? 0 : Math.max(10, (m * (maxShell * 2 + 4)) / (2 * Math.PI));
      org.ring += (ringTarget - org.ring) * k(3);
      org.extent = org.ring + maxShell;
      maxExtent = Math.max(maxExtent, org.extent);
    }

    // Organizations sit on a sunflower spiral; first-seen order keeps existing ones in place.
    const spacing = Math.max(18, maxExtent * 1.25 + 6);
    orgOrder.forEach((org, i) => {
      const r = spacing * Math.sqrt(i);
      const a = i * GOLDEN_ANGLE;
      org.target.set(Math.cos(a) * r, i === 0 ? 0 : org.yOffset, Math.sin(a) * r);
      if (org.fresh) { org.center.copy(org.target); org.fresh = false; }
      else org.center.lerp(org.target, k(2));
    });

    for (const org of orgOrder) {
      const m = org.clusters.length;
      org.clusters.forEach((view, idx) => {
        if (m <= 1) {
          scratch.copy(org.center);
        } else {
          const a = org.phase + (idx / m) * Math.PI * 2 + (reducedMotion ? 0 : t * 0.04);
          scratch.set(Math.cos(a) * org.ring, 0, Math.sin(a) * org.ring).applyQuaternion(org.tilt).add(org.center);
        }
        if (view.fresh) { view.pos.copy(scratch); view.fresh = false; }
        else view.pos.lerp(scratch, k(3));

        const active = view === hovered || view === focus;
        const breathe = reducedMotion ? 1 : 1 + Math.sin(t * 1.6 + view.pulse) * 0.04;
        view.group.scale.setScalar(Math.max(view.scale, 0.0001));
        view.core.scale.setScalar(view.coreR * breathe);
        view.halo.scale.setScalar(view.coreR * (active ? 13 : 10) * breathe);
        view.halo.material.opacity = active ? 1 : 0.8;
        view.hit.scale.setScalar(view.shell);
      });
    }

    // Session particles: drop the ones that finished fading, then write the rest.
    let particleCount = 0;
    for (const view of clusters.values()) {
      view.particles = view.particles.filter((p) => !(p.dying && p.life < 0.02));
      particleCount += view.particles.length;
    }
    ensureCapacity(sessionPoints, particleCount);
    const pPos = sessionPoints.geometry.attributes.position.array;
    const pCol = sessionPoints.geometry.attributes.color.array;
    let pi = 0;
    for (const view of clusters.values()) {
      const c = view.org.color;
      for (const p of view.particles) {
        p.life += ((p.dying ? 0 : 1) - p.life) * k(p.dying ? 3 : 1.5);
        const r = view.shell * p.rFrac * easeOut(Math.min(p.life, 1)) * view.scale;
        const a = p.phase + t * p.speed;
        const ca = Math.cos(a);
        const sa = Math.sin(a);
        pPos[pi * 3] = view.pos.x + (p.u.x * ca + p.v.x * sa) * r;
        pPos[pi * 3 + 1] = view.pos.y + (p.u.y * ca + p.v.y * sa) * r;
        pPos[pi * 3 + 2] = view.pos.z + (p.u.z * ca + p.v.z * sa) * r;
        const b = p.life * view.scale;
        pCol[pi * 3] = (c.r * 0.7 + 0.3) * b;
        pCol[pi * 3 + 1] = (c.g * 0.7 + 0.3) * b;
        pCol[pi * 3 + 2] = (c.b * 0.7 + 0.3) * b;
        pi++;
      }
    }
    sessionPoints.geometry.setDrawRange(0, pi);
    sessionPoints.geometry.attributes.position.needsUpdate = true;
    sessionPoints.geometry.attributes.color.needsUpdate = true;

    // Faint spokes tie the clusters of a multi-network organization together.
    let segmentCount = 0;
    for (const org of orgOrder) if (org.clusters.length > 1) segmentCount += org.clusters.length;
    ensureCapacity(links, segmentCount * 2);
    const lPos = links.geometry.attributes.position.array;
    const lCol = links.geometry.attributes.color.array;
    let li = 0;
    for (const org of orgOrder) {
      if (org.clusters.length < 2) continue;
      const c = org.color;
      for (const view of org.clusters) {
        lPos.set([org.center.x, org.center.y, org.center.z], li * 3);
        lCol.set([0, 0, 0], li * 3);
        li++;
        lPos.set([view.pos.x, view.pos.y, view.pos.z], li * 3);
        lCol.set([c.r * 0.45 * view.scale, c.g * 0.45 * view.scale, c.b * 0.45 * view.scale], li * 3);
        li++;
      }
    }
    links.geometry.setDrawRange(0, li);
    links.geometry.attributes.position.needsUpdate = true;
    links.geometry.attributes.color.needsUpdate = true;

    // Retire clusters and organizations that have finished fading out.
    for (const view of [...clusters.values()]) {
      if (view.dying && view.scale < 0.02 && view.particles.length === 0) disposeCluster(view);
    }
    for (let i = orgOrder.length - 1; i >= 0; i--) {
      const org = orgOrder[i];
      if (org.dying && org.clusters.length === 0) { orgOrder.splice(i, 1); orgs.delete(org.key); }
    }

    // Camera: follow the focused cluster, or keep the whole scene framed.
    if (focus) {
      moveTarget(focus.pos, k(4));
      if (focusArriving && easeDistance(focus.shell * 4 + 14, k(2)) < 0.02) focusArriving = false;
    } else if (autoFit) {
      moveTarget(ORIGIN, k(2));
      // The layout is a flat disc seen from above at an angle, so it needs its full
      // radius across the screen but only part of it from top to bottom.
      const radius = spacing * Math.sqrt(Math.max(orgOrder.length - 1, 0)) + maxExtent + 6;
      const vertical = THREE.MathUtils.degToRad(camera.fov) / 2;
      const horizontal = Math.atan(Math.tan(vertical) * camera.aspect);
      const fit = Math.max(radius / Math.tan(horizontal), (radius * 0.8) / Math.tan(vertical));
      easeDistance(Math.max(50, fit * 1.1), k(1.5));
    }
    controls.update();
    stars.position.copy(camera.position);

    if (pointerInside && !pointerDown) setHovered(pick());

    renderer.render(scene, camera);
  }

  renderer.setAnimationLoop(frame);
  poll();
</script>
</body>
</html>
""".
