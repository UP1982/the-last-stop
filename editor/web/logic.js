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
        chapter: 'oliver_flower_market', document: 'oliver_obstacle', expected_revision: this.revision,
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
  root.TLS = {clone, canonical, snap, freshId, History};
})(globalThis);
