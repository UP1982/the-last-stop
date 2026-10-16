'use strict';
(() => {
  const {History, clone, snap} = TLS;
  const $ = id => document.getElementById(id);
  const fragmentToken = new URLSearchParams(location.hash.slice(1)).get('token');
  let token = fragmentToken || '';
  try {
    if (fragmentToken) sessionStorage.setItem('tls-token', fragmentToken);
    else token = sessionStorage.getItem('tls-token') || '';
  } catch (_) { /* Fresh launch links still work when browser storage is disabled. */ }
  if (fragmentToken) history.replaceState(null, '', '/');
  let model, selected = {collection: 'objects', id: 'crank_handle'}, storageKey, busy = false;
  let external = false, drag = null, recordMode = 'place', pollActive = false;
  const canvas = $('viewport'), ctx = canvas.getContext('2d');
  const visible = new Set(['background', 'world', 'foreground']);
  const step = () => Number($('step').value);
  const snapped = value => snap(value, step(), $('snap').checked);
  const cameraX = () => Number($('camera').value);
  const setMessage = text => { $('message').textContent = text; };
  const diagnostics = response => {
    $('diagnostics').textContent = (response.diagnostics || []).map(d =>
      `${d.severity || 'error'} · ${d.code} · ${d.file || ''}${d.pointer || ''}\n${d.message}`).join('\n\n');
  };
  async function api(path, body) {
    const options = {headers: {'X-Editor-Token': token}, cache: 'no-store'};
    if (body) { options.method = 'POST'; options.headers['Content-Type'] = 'application/json'; options.body = JSON.stringify(body); }
    const response = await fetch(path, options);
    const value = await response.json();
    if (!response.ok) throw Error(value.error || `Bridge HTTP ${response.status}`);
    return value;
  }
  const command = (name, extra = {}) => api('/api/command', {command: name, ...extra});
  window.TLSStudio = {command, token, sceneDirty: () => !!model && model.dirty};
  function persist() {
    if (!storageKey || !model) return;
    try { localStorage.setItem(storageKey, JSON.stringify(model.serialize())); }
    catch (_) { setMessage('Draft is in memory only: browser storage is unavailable or full. Download it before closing.'); }
  }
  function current() { return model && selected.collection ? model.draft[selected.collection][selected.id] : null; }
  function controls() {
    $('save').disabled = !model || !model.dirty || busy;
    $('undo').disabled = !model || !model.past.length || busy;
    $('redo').disabled = !model || !model.future.length || busy;
    ['place', 'preview'].forEach(id => { $(id).disabled = !model || busy; });
    $('reload').disabled = busy;
    ['duplicate', 'delete'].forEach(id => { $(id).disabled = !current() || busy; });
    $('dirty').textContent = model ? (model.dirty ? '● Unsaved changes' : '✓ Saved') : 'Not loaded';
    $('dirty').classList.toggle('is-dirty', !!model && model.dirty);
    $('inspector').querySelectorAll('input,select,button').forEach(el => { el.disabled = busy; });
  }
  function changed(text) {
    if (!current() && selected.collection) selected = {collection: null, id: 'oliver_obstacle'};
    persist(); render(); if (text) setMessage(text);
  }
  function edit(fn, text) {
    if (!model || busy) return;
    try { model.edit(fn); changed(text); } catch (error) { setMessage(error.message); }
  }
  function showExternal(text) {
    external = true; $('external').hidden = false;
    $('external').textContent = text || 'Content changed on disk. Your draft is kept. Reload from disk to inspect the latest content; Save will check your original revision.';
  }
  function conflict(title, text) {
    $('conflict-title').textContent = title;
    $('conflict-text').textContent = text;
    if (!$('conflict-dialog').open) $('conflict-dialog').showModal();
  }
  async function load(discard = false) {
    busy = true; controls();
    try {
      const value = await api('/api/scene'), result = value.result;
      diagnostics(result);
      if (value.exit_code !== 0) { setMessage('Cannot load disk content. Existing draft is kept. Fix the diagnostics and reload.'); return; }
      storageKey = `tls-e1-scene-v2:${value.project_key}:oliver_obstacle`;
      model = new History(result.authored, result.graph_revision);
      external = false; $('external').hidden = true;
      let recovered = false;
      if (!discard) {
        try {
          const saved = JSON.parse(localStorage.getItem(storageKey) || 'null');
          if (saved) {
            const candidate = History.recover(saved);
            if (candidate.dirty) {
              model = candidate; recovered = true;
              if (model.revision !== result.graph_revision) showExternal('Recovered an unsaved draft based on older content. Download it or reload from disk before resolving the conflict.');
            }
          }
        } catch (_) { setMessage('An unreadable browser draft was ignored. Disk content is loaded.'); }
      }
      changed(recovered ? 'Recovered your unsaved browser draft. Disk was not changed.' : 'Scene loaded. Select an object, then drag or edit its properties.');
      frame();
    } catch (error) { setMessage(error.message); }
    finally { busy = false; controls(); }
  }
  async function save() {
    if (!model || busy || !model.dirty) return;
    const request = model.request(), snapshot = clone(request.operations[0].value);
    busy = true; controls();
    try {
      const value = await command('apply-edit', {request}), result = value.result;
      diagnostics(result);
      if (result.commit_state === 'committed' || result.commit_state === 'committed_durability_uncertain' ||
          (value.exit_code === 0 && result.new_revision)) {
        model.saved(snapshot, result.new_revision); external = false; $('external').hidden = true;
        changed(result.commit_state === 'committed_durability_uncertain'
          ? 'Saved, but durability is uncertain. Review the diagnostics and inspect disk before another write.'
          : 'Saved and validated. The native preview will use these authored values.');
      } else if (value.exit_code === 3) {
        showExternal();
        conflict('Save conflict — draft kept', 'The content tool rejected this revision (stale or busy). No edits were discarded. You can keep the draft and retry if the lock was busy, or download it and reload the latest content.');
        setMessage('Save rejected with exit 3. Your unsaved edits and undo history are kept.');
      } else {
        setMessage(`Save rejected (exit ${value.exit_code}). Your unsaved edits and undo history are kept.`);
      }
    } catch (error) { setMessage(error.message + '. Draft kept. Inspect disk before retrying after a lost response.'); }
    finally { busy = false; controls(); }
  }
  function element(tag, text, className) {
    const el = document.createElement(tag); if (text != null) el.textContent = text;
    if (className) el.className = className; return el;
  }
  function choose(collection, id) { selected = {collection, id}; render(); frame(); }
  function renderTree() {
    const tree = $('tree'); tree.replaceChildren();
    $('scene-root').classList.toggle('selected', !selected.collection);
    for (const [collection, label, marker] of [['objects', 'Objects', '■'], ['spawns', 'Safe spawns', '◇']]) {
      tree.append(element('div', label, 'tree-group'));
      for (const id of Object.keys(model.draft[collection]).sort()) {
        const button = element('button', `${marker}  ${id}`, 'tree-item');
        button.dataset.id = id; button.dataset.collection = collection;
        button.classList.toggle('selected', selected.collection === collection && selected.id === id);
        button.onclick = () => choose(collection, id); tree.append(button);
      }
    }
  }
  function vectorField(parent, label, values, write, optional) {
    const field = element('fieldset'), legend = element('legend', label), row = element('div', null, 'vector');
    field.append(legend, row);
    values.forEach((value, index) => {
      const wrap = element('label', ['x', 'y', 'width', 'height'][index]);
      const input = element('input'); input.type = 'number'; input.step = '1'; input.value = value;
      input.setAttribute('aria-label', `${label} ${['x', 'y', 'width', 'height'][index]}`);
      input.onchange = () => {
        if (input.value === '' || !Number.isSafeInteger(Number(input.value))) { setMessage('Enter a whole virtual pixel value.'); input.value = value; return; }
        const next = values.slice(); next[index] = Number(input.value); write(next);
      };
      wrap.append(input); row.append(wrap);
    });
    if (optional) { const remove = element('button', 'Remove ' + label.toLowerCase(), 'remove-field'); remove.onclick = () => write(null); field.append(remove); }
    parent.append(field);
  }
  function selectField(parent, label, value, choices, write) {
    const wrap = element('label', label, 'property'), input = element('select'); input.setAttribute('aria-label', label);
    choices.forEach(choice => { const option = element('option', choice); option.value = choice; input.append(option); });
    input.value = value; input.onchange = () => write(input.value); wrap.append(input); parent.append(wrap);
  }
  function renderInspector() {
    const parent = $('inspector'); parent.replaceChildren();
    parent.append(element('h2', selected.id));
    const record = current();
    if (!record) {
      parent.append(element('p', 'Scene bounds & named puzzle links', 'kind'));
      for (const key of ['world_bounds', 'camera_bounds', 'ground']) vectorField(parent, key.replaceAll('_', ' '), model.draft[key], value => edit(scene => { scene[key] = value; }));
      for (const key of ['train', 'branch', 'winch', 'shed', 'handle', 'snail', 'player_spawn', 'return_spawn', 'handle_recovery_spawn']) {
        const collection = key.includes('spawn') ? 'spawns' : 'objects';
        selectField(parent, key.replaceAll('_', ' '), model.draft.puzzle[key] || '', ['', ...Object.keys(model.draft[collection]).sort()], value => edit(scene => { if (value) scene.puzzle[key] = value; else delete scene.puzzle[key]; }));
      }
      return;
    }
    parent.append(element('p', `${record.kind} / ${selected.collection} · stable ID`, 'kind'));
    const target = {...selected};
    const set = (key, value) => edit(scene => { if (value === null) delete scene[target.collection][target.id][key]; else scene[target.collection][target.id][key] = value; });
    vectorField(parent, 'Position', record.position, value => set('position', value));
    if (selected.collection === 'spawns') return;
    vectorField(parent, 'Size', record.size, value => set('size', value));
    selectField(parent, 'Layer', record.layer, ['background', 'world', 'foreground'], value => set('layer', value));
    for (const key of ['interaction', 'collision']) {
      if (record[key]) vectorField(parent, key === 'interaction' ? 'Interaction bounds' : 'Collision bounds', record[key], value => set(key, value), true);
      else { const button = element('button', 'Add ' + key + ' bounds', 'remove-field'); button.onclick = () => set(key, [0, 0, ...record.size]); parent.append(button); }
    }
    const label = element('label', 'Asset reference (optional stable ID)', 'property'), input = element('input');
    input.value = record.asset || ''; input.setAttribute('aria-label', 'Asset reference');
    input.onchange = () => set('asset', input.value.trim() || null); label.append(input); parent.append(label);
  }
  function rect(values, fill, stroke) {
    const [x, y, w, h] = values;
    if (fill) { ctx.fillStyle = fill; ctx.fillRect(x - cameraX(), y, w, h); }
    if (stroke) { ctx.strokeStyle = stroke; ctx.strokeRect(x - cameraX() + .5, y + .5, w, h); }
  }
  function draw() {
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, 640, 360);
    ctx.fillStyle = '#34476a'; ctx.fillRect(0, 0, 640, 360);
    if (!model) return;
    const scene = model.draft;
    rect(scene.world_bounds, '#34476a', '#879bad');
    rect(scene.ground, '#627d6b');
    rect(scene.camera_bounds, null, '#7891a2');
    if ($('grid').checked) {
      ctx.beginPath(); ctx.strokeStyle = '#b7c7dd22'; ctx.lineWidth = 1;
      for (let x = Math.floor(cameraX() / step()) * step(); x <= cameraX() + 640; x += step()) { ctx.moveTo(x - cameraX(), 0); ctx.lineTo(x - cameraX(), 360); }
      for (let y = 0; y <= 360; y += step()) { ctx.moveTo(0, y); ctx.lineTo(640, y); } ctx.stroke();
    }
    ctx.lineWidth = 2; ctx.font = '10px monospace';
    const colors = {train: '#e8b96e', branch: '#665140', winch: '#a9d1bb', shed: '#837486', handle: '#f2dcca', snail: '#b9be94'};
    for (const layer of ['background', 'world', 'foreground']) {
      if (!visible.has(layer)) continue;
      for (const [id, source] of Object.entries(scene.objects)) {
        if (source.layer !== layer) continue;
        const record = clone(source);
        if (drag && drag.type === 'move' && drag.collection === 'objects' && drag.id === id) record.position = drag.position;
        const [x, y] = record.position, chosen = selected.collection === 'objects' && selected.id === id;
        rect([x, y, ...record.size], colors[record.kind] || '#a9d1bb', chosen ? '#fff0b6' : '#1c243b');
        if (record.collision) rect([x + record.collision[0], y + record.collision[1], ...record.collision.slice(2)], null, '#f79f9a');
        if (chosen && record.interaction) { ctx.setLineDash([4, 4]); rect([x + record.interaction[0], y + record.interaction[1], ...record.interaction.slice(2)], null, '#f6d599'); ctx.setLineDash([]); }
        if (chosen) { ctx.fillStyle = '#fff0cd'; ctx.fillText(id, Math.min(Math.max(4, x - cameraX()), 480), Math.max(14, y - 8)); }
      }
    }
    for (const [id, record] of Object.entries(scene.spawns)) {
      const position = drag && drag.type === 'move' && drag.collection === 'spawns' && drag.id === id ? drag.position : record.position;
      const [x, y] = position, sx = x - cameraX();
      ctx.strokeStyle = selected.collection === 'spawns' && selected.id === id ? '#fff0b6' : '#a9d1bb';
      ctx.beginPath(); ctx.moveTo(sx - 6, y); ctx.lineTo(sx, y - 8); ctx.lineTo(sx + 6, y); ctx.lineTo(sx, y + 8); ctx.closePath(); ctx.stroke();
    }
    $('coords').textContent = `x ${cameraX()}–${cameraX() + 640}`;
  }
  function render() { if (!model) return; renderTree(); renderInspector(); controls(); draw(); }
  function frame() {
    if (!model) return;
    const bounds = model.draft.camera_bounds;
    $('camera').min = bounds[0]; $('camera').max = Math.max(bounds[0], bounds[0] + bounds[2] - 640);
    const record = current();
    if (record) $('camera').value = record.position[0] + ((record.size || [0])[0] / 2) - 320;
    draw();
  }
  function point(event) { const r = canvas.getBoundingClientRect(); return [(event.clientX - r.left) * 640 / r.width + cameraX(), (event.clientY - r.top) * 360 / r.height]; }
  canvas.addEventListener('pointerdown', event => {
    if (!model || busy || (event.button !== 0 && event.button !== 1)) return;
    const p = point(event); canvas.focus();
    if (event.shiftKey || event.button === 1) drag = {type: 'pan', clientX: event.clientX, camera: cameraX()};
    else {
      const hit = (collection, id) => {
        const record = model.draft[collection][id];
        if (collection === 'objects' && !visible.has(record.layer)) return false;
        const [x, y] = record.position, size = record.size || [16, 16];
        return p[0] >= x - 6 && p[0] <= x + size[0] + 6 && p[1] >= y - 6 && p[1] <= y + size[1] + 6;
      };
      let target = current() && hit(selected.collection, selected.id) ? {...selected} : null;
      for (const collection of ['objects', 'spawns']) {
        if (target) break;
        const ids = Object.keys(model.draft[collection]).sort((a, b) => {
          const rank = r => ['background', 'world', 'foreground'].indexOf(r.layer);
          return rank(model.draft[collection][a]) - rank(model.draft[collection][b]);
        }).reverse();
        const id = ids.find(id => hit(collection, id)); if (id) target = {collection, id};
      }
      if (!target) { selected = {collection: null, id: 'oliver_obstacle'}; render(); return; }
      selected = target; const position = clone(current().position);
      drag = {type: 'move', ...target, start: p, origin: position, position}; render();
    }
    canvas.setPointerCapture(event.pointerId); event.preventDefault();
  });
  canvas.addEventListener('pointermove', event => {
    if (!drag) return;
    if (drag.type === 'pan') $('camera').value = drag.camera - (event.clientX - drag.clientX) * 640 / canvas.getBoundingClientRect().width;
    else { const p = point(event); drag.position = drag.origin.map((value, i) => snapped(value + p[i] - drag.start[i])); }
    draw();
  });
  canvas.addEventListener('pointerup', event => {
    if (!drag) return;
    const complete = drag; drag = null;
    if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
    if (complete.type === 'move') edit(scene => { scene[complete.collection][complete.id].position = complete.position; }, 'Position updated. Save to validate and preview.');
    else draw();
  });
  canvas.addEventListener('pointercancel', () => { drag = null; draw(); });
  canvas.addEventListener('keydown', event => {
    if (!current() || busy) return;
    const delta = {ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1]}[event.key];
    if (delta) { event.preventDefault(); edit(scene => { const p = scene[selected.collection][selected.id].position; delta.forEach((d, i) => { p[i] += d * ($('snap').checked ? step() : 1); }); }); }
  });
  $('scene-root').onclick = () => choose(null, 'oliver_obstacle');
  $('focus').onclick = frame; $('camera').oninput = draw;
  $('zoom').onchange = () => { canvas.style.width = `${640 * Number($('zoom').value)}px`; canvas.style.height = 'auto'; };
  ['grid', 'snap', 'step'].forEach(id => { $(id).onchange = draw; });
  document.querySelectorAll('[data-layer]').forEach(input => { input.onchange = () => { if (input.checked) visible.add(input.dataset.layer); else visible.delete(input.dataset.layer); draw(); }; });
  $('undo').onclick = () => { if (!busy && model) { model.undo(); changed('Undid the last edit.'); } };
  $('redo').onclick = () => { if (!busy && model) { model.redo(); changed('Redid the last edit.'); } };
  function openRecord(mode) {
    if (busy) return; recordMode = mode;
    $('record-title').textContent = mode === 'duplicate' ? 'Duplicate selection' : 'Place object';
    $('kind-label').hidden = mode === 'duplicate'; $('new-id').value = ''; $('record-error').textContent = '';
    $('record-dialog').showModal(); $('new-id').focus();
  }
  $('place').onclick = () => openRecord('place'); $('duplicate').onclick = () => openRecord('duplicate');
  $('cancel-record').onclick = () => $('record-dialog').close();
  $('record-form').onsubmit = event => {
    event.preventDefault(); if (!model || busy) return;
    try {
      const id = $('new-id').value.trim(), collection = recordMode === 'duplicate' ? selected.collection : 'objects';
      if (recordMode === 'duplicate') model.duplicate(collection, selected.id, id, step());
      else model.create(id, $('new-kind').value, [snapped(cameraX() + 280), 256]);
      selected = {collection, id}; $('record-dialog').close(); changed('Created ' + id + '. Save validates references and geometry.');
    } catch (error) { $('record-error').textContent = error.message; }
  };
  $('delete').onclick = () => {
    const target = {...selected};
    edit(scene => { delete scene[target.collection][target.id]; }, 'Deleted from draft. Linked puzzle objects must be relinked before Save can pass validation. Undo restores the record.');
  };
  $('save').onclick = save;
  $('reload').onclick = () => {
    if (model && model.dirty) conflict('Reload from disk?', 'Reload discards this unsaved draft and its undo history. Download the draft first if you want a recovery copy.');
    else load(true);
  };
  $('keep-draft').onclick = () => $('conflict-dialog').close();
  $('confirm-reload').onclick = () => { $('conflict-dialog').close(); load(true); };
  $('export-draft').onclick = () => {
    if (!model) return;
    const blob = new Blob([JSON.stringify(model.serialize(), null, 2)], {type: 'application/json'}), url = URL.createObjectURL(blob);
    const anchor = element('a'); anchor.href = url; anchor.download = 'oliver_obstacle-draft.json'; anchor.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  };
  $('preview').onclick = async () => {
    if (busy) return;
    try {
      const result = await command('preview-scene'); $('stop-preview').disabled = !result.running;
      setMessage(`Native preview started (${result.session}). ${model.dirty ? 'Unsaved edits are excluded; Save to include them.' : 'Uses saved content.'}`);
    } catch (error) { setMessage(error.message); }
  };
  $('stop-preview').onclick = async () => { try { await command('stop-preview'); $('stop-preview').disabled = true; setMessage('Native preview stopped.'); } catch (error) { setMessage(error.message); } };
  window.addEventListener('beforeunload', event => { if (model && model.dirty) { event.preventDefault(); event.returnValue = ''; } });
  setInterval(async () => {
    if (!model || busy || pollActive || drag) return;
    const polledRevision = model.revision;
    pollActive = true;
    try {
      const value = await api('/api/scene');
      if (busy || model.revision !== polledRevision) return;
      if (value.exit_code !== 0) { showExternal('Disk content is invalid or unavailable. Your draft is kept. Reload from disk to see diagnostics.'); }
      else if (value.result.graph_revision !== model.revision) showExternal();
    } catch (error) { showExternal('Cannot check disk changes: ' + error.message + '. Your draft is kept.'); }
    finally { pollActive = false; }
  }, 2000);
  load();
})();
