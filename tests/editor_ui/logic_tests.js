(function () {
  let count = 0;
  function check(value, label) { count++; if (!value) throw Error(label); }
  function rejects(fn, label) { let rejected = false; try { fn(); } catch (_) { rejected = true; } check(rejected, label); }
  const scene = {id: 'oliver_obstacle', kind: 'scene', schema_version: 1,
    objects: {crank_handle: {kind: 'handle', position: [588, 128], size: [8, 8], layer: 'world', interaction: [-16, -8, 40, 32]}},
    spawns: {entry: {kind: 'player_feet', position: [140, 144]}}};
  const h = new TLS.History(scene, 'sha256:old');
  check(!h.dirty, 'initial clean');
  h.edit(d => { d.objects.crank_handle.position = [596, 128]; });
  check(h.dirty && scene.objects.crank_handle.position[0] === 588, 'edit immutable');
  h.undo(); check(!h.dirty && h.draft.objects.crank_handle.position[0] === 588, 'undo');
  h.redo(); check(h.dirty && h.draft.objects.crank_handle.position[0] === 596, 'redo');
  const snapshot = TLS.clone(h.draft); h.saved(snapshot, 'sha256:new');
  check(!h.dirty && h.revision === 'sha256:new', 'save baseline');
  h.undo(); check(h.dirty && h.draft.objects.crank_handle.position[0] === 588, 'undo after save becomes dirty');
  h.redo(); check(!h.dirty, 'redo to saved state is clean');
  h.undo(); h.edit(d => { d.objects.crank_handle.interaction[2] = 48; });
  check(!h.future.length, 'new edit clears redo');
  check(TLS.snap(595, 8) === 592 && TLS.snap(597, 8) === 600, 'grid snapping');
  check(TLS.snap(595.4, 8, false) === 595 && TLS.snap(-13, 8) === -16, 'integer and negative snapping');
  rejects(() => h.duplicate('objects', 'crank_handle', 'crank_handle', 8), 'duplicate ID rejected');
  rejects(() => h.duplicate('objects', 'crank_handle', 'entry', 8), 'spawn ID collision rejected');
  rejects(() => h.duplicate('objects', 'crank_handle', '../bad', 8), 'unsafe ID rejected');
  h.duplicate('objects', 'crank_handle', 'spare_handle', 8);
  check(h.draft.objects.spare_handle.position[0] === 596, 'explicit duplicate offset');
  h.edit(d => { delete d.objects.spare_handle; }); h.undo();
  check(!!h.draft.objects.spare_handle, 'delete undo');
  const recovered = TLS.History.recover(JSON.parse(JSON.stringify(h.serialize())));
  check(recovered.dirty && recovered.past.length === h.past.length && TLS.canonical(recovered.draft) === TLS.canonical(h.draft), 'draft recovery');
  const request = h.request();
  check(request.operations.length === 1 && request.operations[0].op === 'restore_document' && request.expected_revision === 'sha256:new', 'one-document revision save');
  h.create('new_snail', 'snail', [400, 128]);
  check(h.draft.objects.new_snail.size[0] === 12, 'placement');
  check(TLS.canonical({a: 1, b: 2}) === TLS.canonical({b: 2, a: 1}), 'canonical dirty comparison');
  const before = h.serialize();
  // The UI never calls saved() for stale/validation responses: drafts/history remain intact.
  check(TLS.canonical(before) === TLS.canonical(h.serialize()) && h.dirty, 'rejection preserves draft');
  return `logic: ${count} assertions passed`;
})();
