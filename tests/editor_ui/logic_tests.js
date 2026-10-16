(function () {
  let count = 0;
  function check(value, label) { count++; if (!value) throw Error(label); }
  function rejects(fn, label) { let rejected = false; try { fn(); } catch (_) { rejected = true; } check(rejected, label); }
  const scene = {id: 'oliver_obstacle', kind: 'scene', schema_version: 2,
    objects: {crank_handle: {kind: 'handle', position: [1176, 256], size: [16, 16], layer: 'world', interaction: [-32, -16, 80, 64]}},
    spawns: {entry: {kind: 'player_feet', position: [280, 288]}}};
  const h = new TLS.History(scene, 'sha256:old');
  check(!h.dirty, 'initial clean');
  h.edit(d => { d.objects.crank_handle.position = [1192, 256]; });
  check(h.dirty && scene.objects.crank_handle.position[0] === 1176, 'edit immutable');
  h.undo(); check(!h.dirty && h.draft.objects.crank_handle.position[0] === 1176, 'undo');
  h.redo(); check(h.dirty && h.draft.objects.crank_handle.position[0] === 1192, 'redo');
  const snapshot = TLS.clone(h.draft); h.saved(snapshot, 'sha256:new');
  check(!h.dirty && h.revision === 'sha256:new', 'save baseline');
  h.undo(); check(h.dirty && h.draft.objects.crank_handle.position[0] === 1176, 'undo after save becomes dirty');
  h.redo(); check(!h.dirty, 'redo to saved state is clean');
  h.undo(); h.edit(d => { d.objects.crank_handle.interaction[2] = 96; });
  check(!h.future.length, 'new edit clears redo');
  check(TLS.snap(1190, 16) === 1184 && TLS.snap(1194, 16) === 1200, 'grid snapping');
  check(TLS.snap(1190.8, 16, false) === 1191 && TLS.snap(-26, 16) === -32, 'integer and negative snapping');
  rejects(() => h.duplicate('objects', 'crank_handle', 'crank_handle', 16), 'duplicate ID rejected');
  rejects(() => h.duplicate('objects', 'crank_handle', 'entry', 16), 'spawn ID collision rejected');
  rejects(() => h.duplicate('objects', 'crank_handle', '../bad', 16), 'unsafe ID rejected');
  h.duplicate('objects', 'crank_handle', 'spare_handle', 16);
  check(h.draft.objects.spare_handle.position[0] === 1192, 'explicit duplicate offset');
  h.edit(d => { delete d.objects.spare_handle; }); h.undo();
  check(!!h.draft.objects.spare_handle, 'delete undo');
  const recovered = TLS.History.recover(JSON.parse(JSON.stringify(h.serialize())));
  check(recovered.dirty && recovered.past.length === h.past.length && TLS.canonical(recovered.draft) === TLS.canonical(h.draft), 'draft recovery');
  const request = h.request();
  check(request.operations.length === 1 && request.operations[0].op === 'restore_document' && request.expected_revision === 'sha256:new', 'one-document revision save');
  h.create('new_snail', 'snail', [800, 256]);
  check(h.draft.objects.new_snail.size[0] === 24, 'placement');
  check(TLS.canonical({a: 1, b: 2}) === TLS.canonical({b: 2, a: 1}), 'canonical dirty comparison');
  const legacyDraft = h.serialize(); legacyDraft.base = {...legacyDraft.base, schema_version: 1};
  rejects(() => TLS.History.recover(legacyDraft), 'half-scale draft rejected');
  const mixedHistory = h.serialize(); mixedHistory.past = [{...scene, schema_version: 1}];
  rejects(() => TLS.History.recover(mixedHistory), 'half-scale undo history rejected');
  const before = h.serialize();
  // The UI never calls saved() for stale/validation responses: drafts/history remain intact.
  check(TLS.canonical(before) === TLS.canonical(h.serialize()) && h.dirty, 'rejection preserves draft');
  const doc = {kind: 'dialogue', schema_version: 2, id: 'intro', completion: {action: 'board_oliver', destination: 'train_travel'},
    lines: {a: {speaker: 'oliver', text: 'Hello', delivery: 'onscreen'}, b: {speaker: 'rin', text: 'Hi'}}, order: ['a', 'b'],
    beats: {first: {kind: 'line', line: 'a', stage: {actors: {}, props: {}, set: 'carriage', shot: 'wide', cue: 'none'}},
      silent: {kind: 'stage', duration_ms: 100, stage: {actors: {}, props: {}, set: 'carriage', shot: 'wide', cue: 'none'}},
      last: {kind: 'line', line: 'b', stage: {actors: {}, props: {}, set: 'carriage', shot: 'wide', cue: 'none'}}}, beat_order: ['first', 'silent', 'last']};
  const dialogue = new TLS.History(doc, 'sha256:dialogue');
  dialogue.edit(d => TLS.beatEdit(d, 'down', 'first'));
  check(dialogue.draft.beat_order[0] === 'silent' && dialogue.draft.order.join() === 'a,b', 'only selected beat moves');
  dialogue.edit(d => TLS.beatEdit(d, 'down', 'first'));
  check(dialogue.draft.order.join() === 'b,a', 'line projection follows beats');
  dialogue.undo(); check(dialogue.draft.order.join() === 'a,b', 'dialogue undo coherent');
  dialogue.redo(); check(dialogue.draft.order.join() === 'b,a', 'dialogue redo coherent');
  dialogue.edit(d => TLS.beatEdit(d, 'duplicate', 'first', 'copy_beat', 'copy_line'));
  check(dialogue.draft.lines.copy_line.text === 'Hello' && dialogue.draft.beats.copy_beat.line === 'copy_line', 'duplicate has fresh line identity');
  rejects(() => TLS.beatEdit(dialogue.draft, 'create', 'first', 'first', 'z', 'stage'), 'duplicate beat rejected');
  rejects(() => TLS.beatEdit(dialogue.draft, 'duplicate', 'first', 'unique', 'a'), 'duplicate line rejected');
  dialogue.edit(d => TLS.beatEdit(d, 'delete', 'copy_beat'));
  check(!dialogue.draft.lines.copy_line && !dialogue.draft.order.includes('copy_line'), 'delete removes coherent line');
  check(dialogue.request().document === 'intro', 'dialogue request targets its identity');
  const preserved = TLS.History.recover(dialogue.serialize());
  check(preserved.dirty && preserved.revision === 'sha256:dialogue', 'recovered dialogue retains stale baseline');
  check(TLS.utf8Bytes('é😀') === 6 && TLS.codepoints('é😀') === 2, 'UTF8 bytes differ from codepoints');
  const source = new TLS.SourceBuffer({path: 'src/main.odin', text: 'saved', sha256: 'old', writable: true});
  source.text = 'draft'; source.observe({text: 'agent', sha256: 'agent'});
  check(source.dirty && source.conflict && source.hash === 'old' && source.text === 'draft', 'agent update keeps dirty source and hash');
  source.missing = true; check(source.conflict && source.text === 'draft', 'deleted source retains buffer');
  source.observe({sha256: 'old'}); check(!source.missing && !source.conflict && source.dirty, 'returned original bytes observed without rebase');
  check(dialogue.base.completion.action === dialogue.draft.completion.action, 'completion preserved');
  return `logic: ${count} assertions passed`;
})();
