# Development milestones — complete in order

Game milestones M0–M5 remain ordered. The user also authorized all editor surfaces in `EDITOR_SPEC.md`. Complete M0 first, then interleave E0–E4 at the dependencies below. Initial delivery now includes Chapter 1 and the editor suite; all boxes remain unverified until supported by evidence.

## M0: Build foundation
- [x] Record `odin version`, platform, and dependency setup in BUILD_NOTES.md.
- [x] Verify `odin check src` then `odin run src` and starter window.
- [x] Replace direct window drawing with low-resolution render target + scaled letterbox.
- [~] Add simple game mode enum + title menu, scene transitions. (implemented + self-tested; native keyboard check pending)
**Gate:** Running at 60fps, pixel-perfect scale and quit works. No branch work before M0.
**Status:** implemented, awaiting human keyboard/fullscreen check (see BUILD_NOTES).

## M1: Milo controls
- [x] Move left/right, jump with forgiving collision and interact prompt. (self-tested)
- [x] Camera follow and accessible interaction radius. (self-tested)
- [x] Pause menu (including quit) and simple controls overlay. (self-tested)
**Gate:** Five-minute keyboard playtest with no jitter or confusing focus.
**Status:** implemented + automated tests pass; human keyboard playtest pending (combined with M0 check).

## M2: Puzzle vertical slice
- [x] Branch visibly blocks route; empty winch + rope points to branch.
- [x] Shed handle pick/drop/carry/install, crank activation, branch-clear animation.
- [x] Optional snail micro-secret and hint progression.
**Gate:** Three clean puzzle completions and deliberate wrong-order interactions without softlock.
**Status:** automated/contract scope ACCEPTED (Astra R2 at 39f52ac; R1 P1 softlock + P3 input fixed). B2 strings deferred to M3a. Human playtest (feel, readability, 3 hand completions) pending.

## M3: Story loop
- [ ] Oliver introduction as short skip-safe cutscene.
- [ ] Automatic train movement and obstacle reveal.
- [ ] Return-to-train and Oliver arrival farewell.
- [ ] Single paper-flower keepsake award.
**Gate:** Title-to-end journey in one playthrough.

## M4: Saving and resilience
- [ ] Versioned save representation and atomic write.
- [ ] Load stable checkpoints from every meaningful puzzle state.
- [ ] Resume after scene skip, quit, and reward replay.
**Gate:** Tests in TEST_PLAN.md all pass, no duplicate keepsakes or unreachable handle.

## M5: Presentation + playtest
- [ ] Original pixel art replacements and cozy animations.
- [ ] Ambient sound/music with volume settings.
- [ ] UX polish, hints, accessibility and tutorial cues.
- [ ] Fresh-player playtest and improvements.
**Gate:** A stranger can complete chapter without external explanation; session can end anytime.

## Beyond slice (do not start before gate)
Hazel/waterwheel; Felix/mirror signal; Bea/sleepy bear; Lumi/turntable; cozy understated finale. Author additional chapters once shared systems prove valuable.

## E0: Editor content contract — after M0, before editor-dependent M2 work
- [x] Record accepted host, schema, shared-loader and operation-interface decisions. (docs/E0_CONTRACT.md)
- [x] Implement versioned scene/chapter/dialogue validation and runtime loading. (E0a + E0b)
- [x] Provide agent-readable inspection and transactional edits with stale-write rejection. (E0a; Astra review pending)
- [~] Explicitly migrate the reference manifest and isolate authored content from saves. (migrated; save isolation verified with saves in M2/M4)
**Gate:** Valid content loads in the actual game; malformed/stale edits fail without data loss; stable IDs/references survive round-trip.
**Status:** gate met (native round-trip: CLI handle move → dump + window screenshot → restore byte-identical). Save isolation re-checked when saves exist (M2).

## E1: Visual scene editor — after E0, alongside M1/M2
- [x] Viewport, grid/snap, scene tree, selection and property inspector.
- [x] Placement/move/duplicate/delete, undo/redo, dirty state and save.
- [x] External-change/conflict handling and actual native game preview.
**Gate:** Move the handle and alter its bounds visually; save and observe the same authored values in the native game.
**Status:** gate demonstrated via API-driven browser flow + native dump/screenshot (build/evidence/e1/). Physical mouse-drag and accessibility unverified — human check.

## E2: In-game edit mode — after E0, with M2
- [ ] Development overlays for collision/interactions/camera and stable IDs.
- [ ] Pause/step/reset, permitted property changes and explicit apply-to-content.
- [ ] Isolated preview saves and release-disabled authoring writes.
**Gate:** Applied changes reopen correctly in the visual editor; ordinary play never alters authored defaults or real player saves.

## E3: Dialogue, assets and coding/agent workspace — after E1, with M3/M4
- [ ] Structured dialogue/beat editing and asset/provenance browser.
- [ ] Project tree, source editor, search, diff, dirty-buffer handling and diagnostics.
- [ ] Actual check/build/run actions, logs, and truthful task/file-ownership status.
- [ ] Structured agent edits visible in the workspace; T3 remains the delegation provider.
**Gate:** Edit dialogue and source, validate/build, and observe the change in the actual game; logs reflect real commands and task status reflects real orchestration.

## E4: Editor reliability — before final M5 acceptance
- [ ] Run editor acceptance demonstration in EDITOR_SPEC.md.
- [ ] Test malformed content, unknown versions, missing assets, conflicts and interrupted writes.
- [ ] Verify undo/revert, restart persistence, preview isolation and release independence.
- [ ] Fresh-user editor-to-game walkthrough with recorded evidence.
**Gate:** Visual authoring, agent editing, in-game editing and code/build workflow all work on the same project without data loss; release game runs with editor closed.
