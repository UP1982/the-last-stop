/* Pure authoring state, shared by the browser and JavaScriptCore tests. */
(function (root) {
  'use strict';
  const clone = value => JSON.parse(JSON.stringify(value));
  function canonical(value) {
    if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
    if (value && typeof value === 'object') return '{' + Object.keys(value).sort().map(k => JSON.stringify(k) + ':' + canonical(value[k])).join(',') + '}';
    return JSON.stringify(value);
  }
  function snap(value, step, enabled = true) {
    return enabled ? Math.round(value / step) * step : Math.round(value);
  }
  function freshId(scene, id) {
    if (!/^[a-z][a-z0-9_]{0,63}$/.test(id)) throw Error('Use a stable ID: lowercase letter, then up to 63 lowercase letters, digits or underscores.');
    if (Object.prototype.hasOwnProperty.call(scene.objects, id) || Object.prototype.hasOwnProperty.call(scene.spawns, id)) throw Error('That ID already exists. Enter a new ID.');
  }
  class History {
    constructor(scene, revision) { this.load(scene, revision); }
    load(scene, revision) {
      this.base = clone(scene); this.draft = clone(scene); this.revision = revision;
      this.past = []; this.future = [];
    }
    get dirty() { return canonical(this.base) !== canonical(this.draft); }
    edit(change) {
      const next = clone(this.draft); change(next);
      if (canonical(next) === canonical(this.draft)) return false;
      this.past.push(clone(this.draft)); this.past = this.past.slice(-100);
      this.draft = next; this.future = []; return true;
    }
    undo() {
      if (!this.past.length) return false;
      this.future.push(this.draft); this.draft = this.past.pop(); return true;
    }
    redo() {
      if (!this.future.length) return false;
      this.past.push(this.draft); this.draft = this.future.pop(); return true;
    }
    saved(snapshot, revision) { this.base = clone(snapshot); this.revision = revision; }
    duplicate(collection, source, id, step) {
      freshId(this.draft, id);
      if (!this.draft[collection][source]) throw Error('Select a record first.');
      this.edit(scene => {
        const record = clone(scene[collection][source]);
        record.position[0] += step;
        scene[collection][id] = record;
      });
    }
    create(id, kind, position) {
      freshId(this.draft, id);
      const templates = {train: [192, 64], branch: [96, 48], winch: [48, 48], shed: [144, 96], handle: [16, 16], snail: [24, 16]};
      if (!templates[kind]) throw Error('Choose a Chapter 1 object kind.');
      this.edit(scene => { scene.objects[id] = {kind, position: clone(position), size: templates[kind], layer: kind === 'shed' ? 'background' : 'world'}; });
    }
    request() {
      return {protocol_version: 1, request_id: 'editor_' + Date.now().toString(36),
        chapter: 'oliver_flower_market', document: this.draft.id, expected_revision: this.revision,
        operations: [{op: 'restore_document', value: clone(this.draft)}]};
    }
    serialize() { return {base: this.base, draft: this.draft, revision: this.revision, past: this.past, future: this.future}; }
    static recover(value) {
      if (!value || !value.base || !value.draft || !Array.isArray(value.past) || !Array.isArray(value.future) || typeof value.revision !== 'string' || value.base.schema_version !== 2 || value.draft.schema_version !== 2 || [...value.past, ...value.future].some(scene => scene.schema_version !== 2)) throw Error('Invalid draft');
      const history = new History(value.base, value.revision);
      history.draft = clone(value.draft); history.past = clone(value.past.slice(-100)); history.future = clone(value.future.slice(-100));
      return history;
    }
  }
  const utf8Bytes = text => unescape(encodeURIComponent(text)).length;
  const codepoints = text => Array.from(text).length;
  function projectOrder(doc) {
    doc.order = doc.beat_order.filter(id => doc.beats[id].kind === 'line').map(id => doc.beats[id].line);
  }
  function beatEdit(doc, action, id, newId, lineId, kind) {
    if (action === 'up' || action === 'down') {
      const at = doc.beat_order.indexOf(id), to = at + (action === 'up' ? -1 : 1);
      if (at >= 0 && to >= 0 && to < doc.beat_order.length) [doc.beat_order[at], doc.beat_order[to]] = [doc.beat_order[to], doc.beat_order[at]];
    } else if (action === 'delete') {
      const beat = doc.beats[id];
      delete doc.beats[id]; doc.beat_order = doc.beat_order.filter(value => value !== id);
      if (beat.kind === 'line') delete doc.lines[beat.line];
    } else {
      if (!/^[a-z][a-z0-9_]{0,63}$/.test(newId) || doc.beats[newId]) throw Error('Enter a fresh stable beat ID.');
      const source = doc.beats[id] || doc.beats[doc.beat_order[0]];
      const beat = action === 'duplicate' ? clone(source) : {kind, stage: clone(source.stage)};
      if (beat.kind === 'line') {
        if (!/^[a-z][a-z0-9_]{0,63}$/.test(lineId) || doc.lines[lineId]) throw Error('Enter a fresh line ID.');
        doc.lines[lineId] = action === 'duplicate' ? clone(doc.lines[source.line]) : {speaker: Object.keys(source.stage.actors)[0] || 'oliver', text: 'New line', delivery: 'onscreen'};
        beat.line = lineId;
      }
      if (action !== 'duplicate' && kind === 'stage') beat.duration_ms = 0;
      if (action !== 'duplicate' && kind === 'card') beat.string = 'supper_card';
      doc.beats[newId] = beat; doc.beat_order.splice(doc.beat_order.indexOf(id) + 1, 0, newId);
    }
    projectOrder(doc);
  }
  class SourceBuffer {
    constructor(file) { this.path = file.path; this.base = file.text; this.text = file.text; this.hash = file.sha256; this.observed = file.sha256; this.writable = file.writable; this.missing = false; }
    get dirty() { return this.text !== this.base; }
    observe(file) { this.observed = file.sha256; this.missing = false; }
    get conflict() { return this.missing || this.observed !== this.hash; }
    saved(result) { this.base = this.text; this.hash = result.sha256; this.observed = result.sha256; }
  }
  root.TLS = {clone, canonical, snap, freshId, History, utf8Bytes, codepoints, projectOrder, beatEdit, SourceBuffer};
})(globalThis);
