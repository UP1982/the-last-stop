'use strict';
globalThis.draftTestResult = null;
(async () => {
  const assert = (ok, message) => { if (!ok) throw Error(message); };
  let writes = [], status = '';
  const service = TLSDrafts.create(async (command, args) => {
    if (command === 'read-draft') return {sha256: null, value: null};
    writes.push(args); return {sha256: 'r' + writes.length, value: args.value};
  }, text => { status = text; });
  await service.read('scene', 'a');
  const snapshot = {draft: 'one'}; service.store('scene', 'a', snapshot); snapshot.draft = 'two';
  service.store('scene', 'a', snapshot); service.store('scene', 'a', {draft: 'three'});
  await service.flush();
  assert(JSON.stringify(writes.map(w => w.expected_sha256)) === '[null,"r1","r2"]', 'queued writes keep successive revisions');
  assert(writes[0].value.draft === 'one' && writes[2].value.draft === 'three', 'snapshots do not alias typing');
  assert(status.includes('saved in this project'), 'acknowledged saves report success');
  let release; const gate = new Promise(resolve => { release = resolve; }); writes = [];
  const failed = TLSDrafts.create(async (command, args) => {
    if (command === 'read-draft') return {sha256: null, value: null};
    writes.push(args);
    if (args.id === 'bad') throw Error('stale recovery record');
    await gate; return {sha256: 'good', value: args.value};
  }, text => { status = text; });
  await failed.read('scene', 'bad'); await failed.read('source', 'good');
  failed.store('scene', 'bad', {draft: 'retained'});
  await Promise.resolve(); await Promise.resolve();
  failed.store('source', 'good', {draft: 'later successful write'}); release();
  let rejected = false; try { await failed.flush(); } catch (_) { rejected = true; }
  assert(rejected && status.includes('stale recovery record'), 'later success cannot hide another draft failure');
  failed.store('scene', 'bad', {draft: 'no automatic retry/rebase'});
  try { await failed.flush(); } catch (_) {}
  assert(writes.filter(w => w.id === 'bad').length === 1, 'unknown outcomes never replay automatically');
  writes = [];
  const unavailable = TLSDrafts.create(async (command, args) => {
    if (command === 'read-draft') throw Error('recovery drive unavailable');
    writes.push(args);
  }, text => { status = text; });
  assert(await unavailable.read('scene', 'a') === null, 'unavailable recovery permits browser/disk fallback');
  unavailable.store('scene', 'a', {draft: 'in memory only'});
  try { await unavailable.flush(); } catch (_) {}
  assert(!writes.length && status.includes('recovery drive unavailable'), 'unknown baseline cannot be overwritten');
  globalThis.draftTestResult = {ok: true, assertions: 7};
})().catch(error => { globalThis.draftTestResult = {ok: false, error: String(error)}; });
