'use strict';
(() => {
  const {command} = window.TLSStudio, {clone, History, SourceBuffer} = TLS;
  const $ = id => document.getElementById(id);
  const el = (tag, text) => { const node = document.createElement(tag); if (text != null) node.textContent = text; return node; };
  const message = (id, text) => { $(id).textContent = text; };
  const safe = (id, fn) => async () => { try { await fn(); } catch (error) { message(id, error.message + ' · Existing drafts kept.'); } };
  let chapter, assets, projectKey, dialogueId, beatId, dialogueBusy = false, initialized = false;
  let currentPath, job, cursor = 0, jobBusy = false, pollBusy = false, fieldTyping = false, previewMeta = null;
  const dialogues = new Map(), buffers = new Map();
  const model = () => dialogues.get(dialogueId);
  const buffer = () => buffers.get(currentPath);
  const key = (type, id) => `tls-e3:${projectKey}:${type}:${id}`;
  function store(type, id, value) {
    try { localStorage.setItem(key(type, id), JSON.stringify(value)); }
    catch (_) { message(type === 'dialogue' ? 'dialogue-status' : 'source-state', 'Browser storage unavailable; download drafts before closing.'); }
  }
  function retrieve(type, id) { try { return JSON.parse(localStorage.getItem(key(type, id)) || 'null'); } catch (_) { return null; } }
  function download(name, data) {
    const url = URL.createObjectURL(new Blob([data], {type: 'text/plain;charset=utf-8'}));
    const link = el('a'); link.href = url; link.download = name; link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  function conflict(text, saveCopy, reload) {
    message('studio-conflict-text', text);
    $('studio-download').onclick = saveCopy;
    $('studio-keep').onclick = () => $('studio-conflict').close();
    $('studio-discard').onclick = safe('source-state', async () => { $('studio-conflict').close(); await reload(); });
    if (!$('studio-conflict').open) $('studio-conflict').showModal();
  }
  async function inspect(id) {
    const response = await command('inspect-document', {document: id});
    if (response.exit_code !== 0) throw Error(JSON.stringify(response.result.diagnostics));
    return response;
  }
  async function initialize() {
    if (initialized) return;
    const response = await inspect('oliver_flower_market'); chapter = response.result.authored; projectKey = response.project_key;
    assets = (await inspect(chapter.assets.id)).result.authored.assets;
    for (const [role, ref] of Object.entries(chapter.dialogues)) {
      const option = el('option', `${role} / ${ref.id}`); option.value = ref.id; $('dialogue-document').append(option);
    }
    const option = el('option', 'Chapter text / speaker names'); option.value = chapter.id; $('dialogue-document').append(option);
    Object.keys(assets).sort().forEach(id => { const option = el('option', id); option.value = id; $('asset-select').append(option); });
    initialized = true;
  }
  document.querySelectorAll('#studio-nav button').forEach(button => {
    const feedback = {'scene-panel': 'message', 'dialogue-panel': 'dialogue-status', 'assets-panel': 'asset-status', 'code-panel': 'source-state', 'tasks-panel': 'tasks-state'}[button.dataset.panel];
    button.onclick = safe(feedback, async () => {
      document.querySelectorAll('.studio-panel').forEach(panel => { panel.hidden = panel.id !== button.dataset.panel; });
      document.querySelectorAll('#studio-nav button').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
      if (['dialogue-panel', 'assets-panel'].includes(button.dataset.panel)) await initialize();
      if (button.dataset.panel === 'dialogue-panel' && !model()) await loadDialogue($('dialogue-document').value);
      if (button.dataset.panel === 'assets-panel') await loadAsset();
      if (button.dataset.panel === 'code-panel') await tree();
      if (button.dataset.panel === 'tasks-panel') await tasks();
    });
  });
  function select(parent, label, value, options, write) {
    const wrap = el('label', label), input = el('select'); input.setAttribute('aria-label', label);
    options.forEach(choice => { const option = el('option', choice || '(placeholder / none)'); option.value = choice; input.append(option); });
    input.value = value || ''; input.onchange = () => write(input.value); wrap.append(input); parent.append(wrap); return input;
  }
  function input(parent, label, value, write, numeric = false) {
    const wrap = el('label', label), field = el('input'); field.value = value; field.type = numeric ? 'number' : 'text';
    field.setAttribute('aria-label', label);
    field.oninput = () => {
      if (numeric && !Number.isSafeInteger(Number(field.value))) { message('dialogue-status', 'Use an integer value.'); return; }
      fieldTyping = true;
      try { write(numeric ? Number(field.value) : field.value); } finally { fieldTyping = false; }
    };
    wrap.append(field); parent.append(wrap); return field;
  }
  function text(parent, label, value, write, maxBytes = 4096, maxPoints = null, singleLine = false) {
    const wrap = el('label', label), field = el(singleLine ? 'input' : 'textarea'), counter = el('span'); counter.className = 'budget';
    field.value = value; field.setAttribute('aria-label', label);
    function count() {
      const bytes = TLS.utf8Bytes(field.value), points = TLS.codepoints(field.value);
      counter.textContent = `${bytes}/${maxBytes} UTF-8 bytes · ${points}${maxPoints ? '/' + maxPoints : ''} codepoints`;
      counter.classList.toggle('invalid', bytes > maxBytes || (maxPoints && points > maxPoints) || (singleLine && /[\r\n\t]/.test(field.value)));
    }
    field.oninput = () => { count(); write(field.value, true); };
    count(); wrap.append(field, counter); parent.append(wrap);
  }
  async function loadDialogue(id, discard = false) {
    const response = await inspect(id), disk = response.result;
    if (!dialogues.has(id) || discard) {
      let next = new History(disk.authored, disk.graph_revision);
      if (!discard) {
        try { const saved = retrieve('dialogue', id); if (saved) { const recovered = History.recover(saved); if (recovered.dirty && recovered.draft.id === id) next = recovered; } } catch (_) { /* Disk remains authoritative. */ }
      }
      dialogues.set(id, next);
    }
    dialogueId = id; $('dialogue-document').value = id;
    beatId = model().draft.beat_order ? model().draft.beat_order[0] : null;
    renderDialogue();
    message('dialogue-status', model().revision !== disk.graph_revision ? 'Disk graph changed. Recovered draft and original revision kept; Save will conflict.' : 'Loaded validated saved document. Browser text wrapping is an approximation of native wrapping.');
    persistDialogue();
  }
  function persistDialogue() { if (model()) store('dialogue', dialogueId, model().serialize()); }
  function editDialogue(change, quiet = false) {
    if (dialogueBusy) return;
    model().edit(change); persistDialogue();
    if (quiet || fieldTyping) dialogueControls(); else renderDialogue();
  }
  function dialogueControls() {
    $('dialogue-dirty').textContent = model().dirty ? '● Unsaved document' : '✓ Saved document';
    $('dialogue-save').disabled = dialogueBusy || !model().dirty;
    $('dialogue-undo').disabled = dialogueBusy || !model().past.length;
    $('dialogue-redo').disabled = dialogueBusy || !model().future.length;
    $('dialogue-document').disabled = dialogueBusy;
    $('dialogue-reload').disabled = dialogueBusy;
    $('dialogue-download').disabled = false;
    $('beat-form').querySelectorAll('input,select,textarea,button').forEach(node => { node.disabled = dialogueBusy; });
    ['beat-create', 'beat-duplicate', 'beat-delete', 'beat-up', 'beat-down'].forEach(id => { $(id).disabled = dialogueBusy || !beatId; });
  }
  const shots = {willow_platform: ['wide', 'passenger_pair', 'old_platform'], carriage: ['wide', 'passenger_pair', 'flower', 'supper_card'], forest_travel: ['wide'], forest_obstacle: ['wide', 'passenger_pair', 'winch_branch'], market_platform: ['wide', 'passenger_pair', 'flower', 'supper_card'], flower_window: ['flower']};
  const states = {train: ['waiting', 'moving', 'stopped'], door: ['open', 'closed'], bag: ['ear_caught', 'free', 'aboard'], flowerpot: ['bud', 'bloom'], paper_flower: ['paper', 'folding', 'folded', 'spring'], slat: ['loose', 'slipping', 'caught', 'resting'], bench: ['unrepaired', 'supported'], timetable: ['unhelpful'], sign: ['faded'], notice: ['supper'], market_dressing: ['open']};
  function renderDialogue() {
    const doc = model().draft, list = $('beat-list'), form = $('beat-form'); list.replaceChildren(); form.replaceChildren();
    if (doc.kind === 'chapter') {
      message('completion', 'Chapter identity, references and completion routing remain unchanged. Names and text use one guarded chapter transaction.');
      for (const [id, speaker] of Object.entries(doc.speakers)) text(form, `Speaker name / ${id}`, speaker.name, (value, quiet) => editDialogue(d => { d.speakers[id].name = value; }, quiet), 4096, 20, true);
      const budgets = {advance: 14, return_menu: 14, skip_scene: 10};
      const labels = ['pickup', 'drop', 'install', 'activate', 'inspect_winch', 'inspect_branch', 'return_train', 'wave', 'turning', 'clear'];
      for (const [id, value] of Object.entries(doc.strings)) {
        const budget = budgets[id] || (labels.includes(id) ? 26 : null);
        text(form, `Text / ${id}`, value, (value, quiet) => editDialogue(d => { d.strings[id] = value; }, quiet), 4096, budget, !!budget);
      }
      beatId = null; dialogueControls(); return;
    }
    message('completion', `Completion (read-only): ${doc.completion.action} → ${doc.completion.destination}. Beats cannot award rewards or change checkpoints.`);
    doc.beat_order.forEach((id, index) => {
      const button = el('button', `${index + 1}. ${id} · ${doc.beats[id].kind}`); button.classList.toggle('selected-tab', id === beatId);
      button.onclick = () => { beatId = id; renderDialogue(); }; list.append(button);
    });
    if (!doc.beats[beatId]) beatId = doc.beat_order[0];
    const beat = doc.beats[beatId]; if (!beat) { dialogueControls(); return; }
    form.append(el('h2', `${beatId} / ${beat.kind}`));
    if (beat.kind === 'line') {
      const line = doc.lines[beat.line]; form.append(el('p', `Stable line ID: ${beat.line}`));
      select(form, 'Speaker', line.speaker, Object.keys(chapter.speakers), value => editDialogue(d => { d.lines[beat.line].speaker = value; }));
      select(form, 'Delivery', line.delivery || 'onscreen', ['onscreen', 'offscreen'], value => editDialogue(d => { d.lines[beat.line].delivery = value; }));
      text(form, 'Line text', line.text, (value, quiet) => editDialogue(d => { d.lines[beat.line].text = value; }, quiet));
    }
    if (beat.kind === 'stage') input(form, 'Stage duration (0–5000 ms; 0 waits for advance)', beat.duration_ms, value => editDialogue(d => { d.beats[beatId].duration_ms = value; }), true);
    if (beat.kind === 'card') select(form, 'Card key', beat.string, ['supper_card', 'end_card'], value => editDialogue(d => { d.beats[beatId].string = value; }));
    const stage = beat.stage, changeStage = change => editDialogue(d => change(d.beats[beatId].stage));
    select(form, 'Set', stage.set, Object.keys(shots), value => changeStage(s => { s.set = value; if (!shots[value].includes(s.shot)) s.shot = shots[value][0]; }));
    select(form, 'Shot', stage.shot, shots[stage.set], value => changeStage(s => { s.shot = value; }));
    select(form, 'Cue', stage.cue, ['none', 'whistle_low', 'door_squeak', 'wheels', 'brake_soft', 'paper_rustle', 'whistle_depart'], value => changeStage(s => { s.cue = value; }));
    form.append(el('h3', 'Actors · complete snapshot'));
    for (const [id, actor] of Object.entries(stage.actors)) {
      const box = el('div'); box.className = 'record-card'; box.append(el('h3', id));
      const set = (property, value) => changeStage(s => { s.actors[id][property] = value; });
      ['x', 'y'].forEach((axis, index) => input(box, `${id} feet ${axis}`, actor.feet[index], value => changeStage(s => { s.actors[id].feet[index] = value; }), true));
      select(box, `${id} facing`, actor.facing, ['left', 'right'], value => set('facing', value));
      select(box, `${id} pose`, actor.pose, ['idle', 'walk', 'nod', 'point', 'reach', 'wave', 'carry', 'sit', 'look', 'board', 'fold', 'tap', 'dust_paws'], value => set('pose', value));
      select(box, `${id} emote`, actor.emote, ['neutral', 'curious', 'smile', 'blink', 'ears_up'], value => set('emote', value));
      select(box, `${id} asset`, actor.asset, ['', ...Object.keys(assets)], value => changeStage(s => { if (value) s.actors[id].asset = value; else delete s.actors[id].asset; }));
      const remove = el('button', `Remove actor ${id}`); remove.onclick = () => changeStage(s => { delete s.actors[id]; }); box.append(remove); form.append(box);
    }
    const actorSelect = select(form, 'Add actor from speakers', '', ['', ...Object.keys(chapter.speakers).filter(id => !stage.actors[id])], value => { if (value) changeStage(s => { s.actors[value] = {feet: [320, 224], facing: 'right', pose: 'idle', emote: 'neutral'}; }); });
    actorSelect.setAttribute('aria-label', 'Add actor');
    form.append(el('h3', 'Props · complete snapshot'));
    for (const [id, prop] of Object.entries(stage.props)) {
      const box = el('div'); box.className = 'record-card'; box.append(el('h3', id));
      select(box, `${id} kind`, prop.kind, Object.keys(states), value => changeStage(s => { s.props[id].kind = value; s.props[id].state = states[value][0]; }));
      select(box, `${id} state`, prop.state, states[prop.kind], value => changeStage(s => { s.props[id].state = value; }));
      ['x', 'y'].forEach((axis, index) => input(box, `${id} position ${axis}`, prop.position[index], value => changeStage(s => { s.props[id].position[index] = value; }), true));
      select(box, `${id} asset`, prop.asset, ['', ...Object.keys(assets)], value => changeStage(s => { if (value) s.props[id].asset = value; else delete s.props[id].asset; }));
      const remove = el('button', `Remove prop ${id}`); remove.onclick = () => changeStage(s => { delete s.props[id]; }); box.append(remove); form.append(box);
    }
    const propId = input(form, 'New visual prop ID', '', () => {}), propKind = select(form, 'New prop kind', 'sign', Object.keys(states), () => {});
    const addProp = el('button', 'Add visual prop'); addProp.onclick = safe('dialogue-status', () => {
      const id = propId.value;
      if (!/^[a-z][a-z0-9_]{0,63}$/.test(id) || stage.props[id]) throw Error('Enter a fresh stable prop ID');
      changeStage(s => { s.props[id] = {kind: propKind.value, state: states[propKind.value][0], position: [320, 200]}; });
    }); form.append(addProp); dialogueControls();
  }
  async function saveDialogue() {
    if (!model() || !model().dirty || dialogueBusy) return;
    const target = model(), id = dialogueId, request = target.request(), snapshot = clone(target.draft);
    dialogueBusy = true; dialogueControls();
    try {
      const response = await command('apply-edit', {request});
      message('dialogue-diagnostics', JSON.stringify(response, null, 2));
      if (response.exit_code === 0 || response.result.commit_state === 'committed_durability_uncertain') {
        const disk = await inspect(id);
        if (TLS.canonical(disk.result.authored) === TLS.canonical(snapshot)) {
          target.saved(snapshot, disk.result.graph_revision);
          message('dialogue-status', response.exit_code === 0 ? 'Saved and re-inspected through the real CLI.' : 'Replacement happened; durability uncertain. Disk re-inspected; inspect transaction history before another write.');
        } else throw Error('Disk differs after response; outcome requires inspection');
      } else {
        message('dialogue-status', `Save rejected (exit ${response.exit_code}). Original revision, draft and undo kept.`);
        if (response.exit_code === 3) conflict('Chapter graph changed or is busy. No automatic replay; your document draft is kept.', () => download(id + '-draft.json', JSON.stringify(target.serialize(), null, 2)), () => loadDialogue(id, true));
      }
    } catch (error) { message('dialogue-status', error.message + ' · Draft kept. Inspect disk before retrying an unknown outcome.'); }
    finally { dialogueBusy = false; persistDialogue(); dialogueControls(); }
  }
  $('dialogue-document').onchange = safe('dialogue-status', () => loadDialogue($('dialogue-document').value));
  $('dialogue-save').onclick = saveDialogue;
  $('dialogue-reload').onclick = safe('dialogue-status', () => model().dirty ? conflict('Reload will discard this document draft.', () => $('dialogue-download').click(), () => loadDialogue(dialogueId, true)) : loadDialogue(dialogueId, true));
  $('dialogue-download').onclick = () => download(dialogueId + '-draft.json', JSON.stringify(model().serialize(), null, 2));
  for (const action of ['undo', 'redo']) $('dialogue-' + action).onclick = () => { model()[action](); persistDialogue(); renderDialogue(); };
  for (const action of ['create', 'duplicate', 'delete', 'up', 'down']) $('beat-' + action).onclick = safe('dialogue-status', () => {
    editDialogue(doc => TLS.beatEdit(doc, action, beatId, $('beat-new-id').value, $('line-new-id').value, $('beat-new-kind').value));
  });
  $('validate-saved').onclick = safe('dialogue-status', async () => {
    const response = await command('validate-content'); message('dialogue-diagnostics', JSON.stringify(response, null, 2));
    message('dialogue-status', `Saved content validation exit ${response.exit_code}. Unsaved drafts were excluded.`);
  });
  let assetURL;
  async function loadAsset() {
    if (assetURL) URL.revokeObjectURL(assetURL);
    $('asset-image').removeAttribute('src'); $('asset-frame').getContext('2d').clearRect(0, 0, 240, 160);
    message('asset-status', 'Verifying registered bytes…');
    const id = $('asset-select').value;
    try {
      const response = await command('read-asset', {asset_id: id});
      const bytes = Uint8Array.from(atob(response.base64), c => c.charCodeAt(0));
      assetURL = URL.createObjectURL(new Blob([bytes], {type: response.mime_type}));
      $('asset-image').onload = () => { message('asset-status', 'Hash verified; PNG decoded by this browser.'); drawFrame(); };
      $('asset-image').onerror = () => { message('asset-status', 'Registered bytes could not be decoded as an image.'); URL.revokeObjectURL(assetURL); };
      $('asset-image').src = assetURL;
      $('asset-frame-number').max = response.asset.frame_count - 1; $('asset-frame-number').value = 0;
      message('asset-metadata', JSON.stringify({asset_id: id, ...response.asset, decoded_dimensions: [response.width, response.height]}, null, 2));
    } catch (error) { message('asset-status', error.message); }
    try { message('asset-licenses', (await command('read-file', {path: 'assets/ASSET_LICENSES.md'})).text); }
    catch (error) { message('asset-licenses', 'Provenance register unavailable: ' + error.message); }
  }
  function drawFrame() {
    const image = $('asset-image'), asset = assets[$('asset-select').value], index = Number($('asset-frame-number').value);
    if (!image.complete || !image.naturalWidth || !Number.isInteger(index) || index < 0 || index >= asset.frame_count) return;
    const canvas = $('asset-frame'), ctx = canvas.getContext('2d'), [w, h] = asset.frame_size, scale = Math.min(canvas.width / w, canvas.height / h);
    ctx.clearRect(0, 0, canvas.width, canvas.height); ctx.imageSmoothingEnabled = false;
    ctx.drawImage(image, index * w, 0, w, h, 0, 0, w * scale, h * scale);
  }
  $('asset-select').onchange = safe('asset-status', loadAsset); $('asset-frame-number').oninput = drawFrame;
  function persistBuffer(b) { store('source', b.path, b); }
  function renderBuffer() {
    const tabs = $('source-tabs'); tabs.replaceChildren();
    for (const b of buffers.values()) {
      const button = el('button', `${b.path}${b.dirty ? ' ●' : ''}${b.conflict ? ' ⚠' : ''}`); button.classList.toggle('selected-tab', b.path === currentPath);
      button.onclick = () => { currentPath = b.path; renderBuffer(); }; tabs.append(button);
    }
    const b = buffer();
    $('source-editor').disabled = !b; $('source-save').disabled = !b || !b.writable || !b.dirty;
    if (!b) return;
    $('source-editor').value = b.text; $('source-editor').readOnly = !b.writable;
    message('source-state', `${b.path} · ${b.writable ? 'editable' : 'read-only'} · ${b.dirty ? 'unsaved buffer' : 'saved'} · loaded SHA-256 ${b.hash}${b.conflict ? ' · Disk changed/deleted: draft and original hash retained; reload explicitly.' : ''}`);
  }
  async function openFile(path, line = null, column = 1, discard = false) {
    if (!buffers.has(path) || discard) {
      const file = await command('read-file', {path}); let b = new SourceBuffer(file);
      if (!discard) {
        const recovered = retrieve('source', path);
        if (recovered && recovered.path === path && typeof recovered.text === 'string' && recovered.text !== recovered.base) {
          Object.assign(b, recovered); b.writable = file.writable; b.observe(file);
        }
      }
      buffers.set(path, b);
    }
    currentPath = path; renderBuffer();
    if (line) {
      const editor = $('source-editor'), lines = buffer().text.split('\n');
      const start = lines.slice(0, line - 1).reduce((sum, text) => sum + text.length + 1, 0) + column - 1;
      editor.focus(); editor.setSelectionRange(start, start); editor.scrollTop = Math.max(0, line - 4) * 22;
    }
  }
  async function tree() {
    const response = await command('list-project'); projectKey = response.project_key; $('project-tree').replaceChildren();
    response.files.forEach(file => { const button = el('button', `${file.writable ? '✎' : '·'} ${file.path}`); button.onclick = safe('source-state', () => openFile(file.path)); $('project-tree').append(button); });
  }
  $('project-refresh').onclick = safe('source-state', tree);
  $('source-editor').oninput = () => { const b = buffer(); if (!b) return; b.text = $('source-editor').value; persistBuffer(b); $('source-save').disabled = !b.writable || !b.dirty; message('source-state', `${b.path} · ${b.dirty ? '● unsaved buffer; commands use saved bytes' : 'saved'}${b.conflict ? ' · Disk changed; original hash retained' : ''}`); };
  async function saveBuffer(b) {
    if (!b || !b.dirty || !b.writable) return;
    const snapshot = b.text;
    const response = await command('write-source', {path: b.path, text: snapshot, expected_sha256: b.hash, request_id: 'studio_' + Date.now().toString(36)});
    // Preserve typing that occurred while the request was in flight.
    b.base = snapshot; b.hash = response.sha256; b.observed = response.sha256; persistBuffer(b);
    message('source-state', `${response.commit_state} · ${response.transaction_id || 'no replacement'} · ${b.path}`);
    if (response.commit_state === 'committed_durability_uncertain') throw Error('Replacement happened; durability uncertain. Inspect disk and source-history before retrying');
  }
  $('source-save').onclick = safe('source-state', async () => { const b = buffer(); await saveBuffer(b); renderBuffer(); });
  $('source-reload').onclick = safe('source-state', () => {
    const b = buffer(); if (!b) return;
    const reload = async () => { await openFile(b.path, null, 1, true); persistBuffer(buffer()); };
    if (b.dirty) conflict('This source buffer has unsaved changes. Keep/download or explicitly discard to read disk.', () => download(b.path.split('/').pop(), b.text), reload); else return reload();
  });
  $('source-download').onclick = () => { const b = buffer(); if (b) download(b.path.split('/').pop(), b.text); };
  $('source-diff').onclick = safe('source-state', async () => { const response = await command('diff-head', {path: currentPath}); message('source-diff-output', response.available ? response.diff || 'No saved-byte differences from HEAD.' : 'Diff unavailable: ' + response.reason); });
  $('search-project').onclick = safe('source-state', async () => {
    const response = await command('search-project', {text: $('project-search').value, limit: 100}); $('search-results').replaceChildren();
    response.matches.forEach(match => { const button = el('button', `${match.path}:${match.line}:${match.column} ${match.text}`); button.onclick = safe('source-state', () => openFile(match.path, match.line, match.column)); $('search-results').append(button); });
  });
  async function withSavedChoice(action) {
    if (![...buffers.values()].some(b => b.dirty) && ![...dialogues.values()].some(h => h.dirty) && !TLSStudio.sceneDirty()) return action();
    $('choice-cancel').onclick = () => $('saved-choice').close();
    $('choice-disk').onclick = safe('job-state', async () => { $('saved-choice').close(); await action(); });
    $('choice-save').onclick = safe('job-state', async () => {
      for (const b of buffers.values()) { if (b.dirty) { if (!b.writable) throw Error('Dirty read-only buffer; download/reload or use saved bytes'); await saveBuffer(b); } }
      renderBuffer(); $('saved-choice').close(); await action();
    });
    $('saved-choice').showModal();
  }
  async function start(name) {
    if (name === 'run-scene') { const response = await command(name); job = null; previewMeta = response; message('job-state', response.running ? `Native preview running · PID ${response.pid}` : `Native preview exit ${response.exit_code}`); message('job-metadata', JSON.stringify(response, null, 2)); return; }
    previewMeta = null;
    const response = await command(name); job = response.job_id; cursor = 0; message('job-log', ''); await pollJob();
  }
  document.querySelectorAll('[data-job]').forEach(button => { button.onclick = safe('job-state', () => withSavedChoice(() => start(button.dataset.job))); });
  async function pollJob() {
    if (!job || jobBusy) return;
    jobBusy = true;
    try {
      const response = await command('job-status', {job_id: job, cursor}); cursor = response.cursor;
      message('job-log', ($('job-log').textContent + (response.truncated ? '\n[earlier output truncated]\n' : '') + response.log).slice(-100000));
      const {log, diagnostics, ...metadata} = response; message('job-metadata', JSON.stringify(metadata, null, 2));
      message('job-state', `${response.command} · ${response.state} · exit ${response.exit_code == null ? 'pending' : response.exit_code} · ${response.current_source ? 'matches saved source at completion' : 'not verified against current saved source'}`);
      $('job-diagnostics').replaceChildren(); diagnostics.forEach(d => { const button = el('button', `${d.path}:${d.line}:${d.column} ${d.severity}: ${d.message}`); button.onclick = safe('source-state', () => openFile(d.path, d.line, d.column)); $('job-diagnostics').append(button); });
    } finally { jobBusy = false; }
  }
  $('job-stop').onclick = safe('job-state', async () => { if (job) { await command('stop-job', {job_id: job}); await pollJob(); } });
  $('code-stop-preview').onclick = safe('job-state', async () => { const response = await command('stop-preview'); previewMeta = null; message('job-state', `Native preview stopped · exit ${response.exit_code}`); });
  async function tasks() {
    const response = await command('task-status'); message('tasks-state', `Observed local evidence ${response.observed_at} · ${response.ownership_resolution}`); $('task-list').replaceChildren();
    response.tasks.forEach(task => {
      const row = el('div'); row.className = 'task-row'; row.append(el('strong', task.id));
      const body = el('div'); body.append(el('div', `${task.scope} · ${task.model} · ${task.checkout_base}`), el('div', `Recorded: ${task.recorded_status}`), el('small', `${task.source} · read ${task.observed_at} · provider ${task.provider_state}`)); row.append(body); $('task-list').append(row);
    });
    message('task-owners', JSON.stringify(response.ownership_claims, null, 2)); message('task-provider', JSON.stringify(response.provider_observation, null, 2));
    message('task-git', JSON.stringify(response.git, null, 2)); message('task-transactions', JSON.stringify(response.managed_source_transactions, null, 2));
    message('task-log', `SHA-256 ${response.orchestration_log.sha256}\n${response.orchestration_log.text}`);
  }
  $('tasks-refresh').onclick = safe('tasks-state', tasks);
  setInterval(async () => {
    if ((!initialized && !buffers.size && !job && !previewMeta) || pollBusy) return; pollBusy = true;
    try {
      for (const b of buffers.values()) {
        try { b.observe(await command('read-file', {path: b.path})); } catch (_) { b.missing = true; }
        if (b.conflict && b.path === currentPath) message('source-state', `${b.path} · External writer changed/deleted disk bytes. Buffer and original save hash kept; Reload offers keep/download/discard.`);
      }
      if (model() && !dialogueBusy) {
        try { const disk = await inspect(dialogueId); if (disk.result.graph_revision !== model().revision) message('dialogue-status', 'Chapter graph changed externally. Draft and original revision kept. Reload explicitly; Save may conflict.'); }
        catch (error) { message('dialogue-status', 'Saved graph invalid/unavailable: ' + error.message + ' · Draft kept.'); }
      }
      if (job) await pollJob();
      if (previewMeta) {
        const response = await command('preview-status');
        message('job-state', `Native preview ${response.running ? 'running' : 'exited'} · PID ${response.pid} · exit ${response.exit_code == null ? 'pending' : response.exit_code}`);
        message('job-metadata', JSON.stringify({...previewMeta, ...response, log: undefined}, null, 2));
        message('job-log', response.log);
      }
    } finally { pollBusy = false; }
  }, 1500);
  window.addEventListener('beforeunload', event => { if ([...buffers.values()].some(b => b.dirty) || [...dialogues.values()].some(h => h.dirty)) { event.preventDefault(); event.returnValue = ''; } });
})();
