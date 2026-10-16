# The Last Stop — Odin + raylib agent handoff kit

**A cozy 2D pixel-art game about Milo the cat helping animal passengers reach their destinations.** Stations are cinematic; train travel is automatic; obstacles stop the train; Milo hops out to solve short environmental puzzles. Pause and resume at any time.

## Start here
1. Read `AGENTS.md` (instructions and priorities for all AI agents).
2. Read `docs/GAME_BIBLE.md` (creative source of truth).
3. Read `docs/TECHNICAL_DESIGN.md` and `docs/CHAPTER_01.md`.
4. Follow `docs/TASK_BOARD.md` in order. The first milestone is a working window, input, and pixel-perfect render loop.
5. Chapter 1 now plays the whole Oliver journey with placeholder staging; art, audio and fresh-player acceptance remain later work.

## Requirements
- An installed Odin compiler with bundled `vendor:raylib` support, a C toolchain/platform dependencies appropriate to your machine.
- Target initially macOS. Confirm other platforms separately.
- Check `odin version` and record the actual version in `docs/BUILD_NOTES.md` (currently unpinned).

## Run
Build and run from the checkout root (Odin + bundled raylib):

```sh
mkdir -p build
odin build src -out:build/the-last-stop
./build/the-last-stop
```

`odin run src` and `./scripts/run.sh` also work from the checkout root.
`./scripts/check.sh` runs compilation, content/editor tests, M0/M1 regressions,
runtime loading/allocation tests, and story convergence/reload tests.

The game validates the complete Chapter 1 graph before Start. Content locations,
in order: `data/` beside the executable; `Contents/Resources/data/` for an app
whose executable is in `Contents/MacOS`; then `--project-root <path>`. For an
unpackaged checkout executable inside `build/`, its parent's `data/` is the last
fallback. The first existing content location wins; malformed or missing files
within it block the chapter with a scrollable error screen and stderr diagnostics.
Esc/Enter returns to Title, where Quit remains available. There is no cwd search
or default chapter. Thus the absolute path to `build/the-last-stop` works from
another directory. A standalone distribution must include `data/` beside the
binary (and any referenced `assets/`), or package both beneath bundle Resources.
Relative `--project-root` values are explicitly relative to the launch directory.

Development scene preview:

```sh
odin build src -define:DEV_TOOLS=true -out:build/the-last-stop-dev
./build/the-last-stop-dev --project-root "$PWD" \
  --preview-scene oliver_obstacle --preview-session my-preview --dump-scene
```

Preview starts directly in the loaded scene with reset player/camera state.
Session IDs must match `[a-z0-9_-]{1,64}` and map only to
`~/Library/Caches/The Last Stop/preview/<session-id>/`. M2 saves only in this isolated preview path; it never accesses normal saves. `--dump-scene`
prints loaded geometry to stderr, and development builds outline interaction
rectangles. Release builds reject preview/debug flags and have no content-edit
imports or authored-content write path. M2 interactions use the loaded scene.

Controls: use Up/Down or W/S in menus, and Enter/Space/Z to confirm. In the loaded Chapter 1
scene, A/D or Left/Right walks Milo; Space/Z/W/Up jumps (hold for a higher hop).
E or Enter interacts with the nearest focused object; its outline, name and key
prompt identify the target. The authored scene has continuous ground and non-solid props. M1’s small-step
controller remains supported and regression-tested; no step is authored here.
During story scenes, **E / Enter** advances one page or beat; **X** skips the
current scene. **Esc only pauses**. Travel runs automatically, and skipping
travel still stops at the unsolved puzzle. Release an action before pressing it
again; held or simultaneous aliases never cascade into the next scene.
Escape pauses/resumes the exact scene, page and timers; the pause menu offers
Resume, Controls and Quit to Title.
Escape or a confirm key closes the Controls overlay back to the pause menu.
Release jump/interact keys after leaving menus before using them in play.
Escape on the title does not exit. F11 or Alt+Enter toggles fullscreen.
The window is resizable (minimum
640x360); the 640x360 canvas uses nearest-neighbour integer scaling and black
letterboxing. Close the window or choose Quit on the title to exit.

Run the window-free foundation checks with:

```sh
odin run src -define:M0_SELF_TEST=true
```

Verified compiler for this foundation: Odin `dev-2026-10:84bc3fc21` on macOS arm64.

## Package map
- `AGENTS.md` project-wide instructions for every agent
- `prompts/` ready-to-paste agent briefs
- `docs/GAME_BIBLE.md` world, narrative, characters, puzzles
- `docs/CHAPTER_01.md` detailed first journey script/level plan
- `docs/TECHNICAL_DESIGN.md` Odin+raylib implementation architecture
- `docs/TASK_BOARD.md` phased milestones, deliverables and test gates
- `docs/TEST_PLAN.md` manual automated testing expectations
- `docs/ART_AUDIO_GUIDE.md` assets and atmosphere
- `data/chapters/chapter_01.json` illustrative content manifest, not wired to runtime yet
- `src/main.odin` minimal rendering shell
- `scripts/` launch/build helpers

## Definition of done for vertical slice
Title → Oliver station cutscene → automatic scenic travel → blocked tracks → cat explores → recover crank handle → clear branch → return → Oliver arrival and keepsake → end card. Saving in mid-puzzle, cutscene skipping, and no softlocks are required.

## Key decisions
- No Godot, GDScript, engine scenes, or Unity. Use Odin + raylib.
- Prioritize original placeholder shapes over finding assets.
- No combat, timers, health, economy, complex inventory, or procedural level generation.
- Do not hand-build a fully generic engine before demonstrating the first puzzle.

M2 puzzle: find the handle on the shed shelf, E/Enter to pick it up, then
E/Enter at the winch to install it. Release and press again to start the automatic
crank. Away from a focused object, E/Enter drops a carried handle safely onto the
walking ground. Once the branch lifts, R returns to Brass from anywhere; E/Enter
at Brass also returns. State-derived hints appear at the top. The returned screen
is the M2 endpoint; Chapter 1 story presentation remains for M3.

Save v2 uses `~/Library/Application Support/The Last Stop/saves/chapter_01.json`,
independent of launch directory. `--save-dir /absolute/directory` overrides
`TLS_SAVE_DIR` (which must also be absolute). Continue resumes valid progress;
a held handle returns to the authored recovery marker. New Game asks Keep or
Replace when a run exists. Malformed/unknown saves are kept in place, Continue
is disabled, and only an explicitly confirmed reset replaces them. Write errors
remain visible; pause or quit retries dirty progress.

DEV_TOOLS preview always starts fresh and writes only to
`~/Library/Caches/The Last Stop/preview/<session-id>/`, even when a save override
is also supplied. Runtime tests always require explicit temporary save profiles.
Run `python3 -B tests/runtime/m2.py` for window-free M2 checks, or
`python3 -B tests/runtime/m2_native.py` for three scripted native completions and
PID-verified game-window screenshots in `build/evidence/m2/`.

T-RES-640 units: scene schema v2 uses integer pixels on a 640x360 virtual canvas.
All original scene coordinates, extents, local rectangles and anchors were doubled
in one repository migration; IDs are unchanged. The world is 1280x360, ground y288,
and Milo's bottom-centre collision footprint is 24x32. Movement, pickup reach,
steps and camera deadzone use doubled units; seconds-based timings are unchanged.
Chapter, dialogue, assets and edit protocol remain v1. Scene v1 is rejected with
`unsupported_version`; runtime/editor never infer or rewrite old authored units.
The historical `scene.v1.schema.json` is retained for reference; active authoring
uses `scene.v2.schema.json`. The ±16,384 geometry bounds remain unchanged.

Save v2 writes current world units. Strictly valid save v1 records load through
explicit conversion: dropped feet are doubled in f64 before narrowing and spatial
validation; unsafe positions recover to `handle_recovery`. Held items recover as
before, and contradictory states remain rejected. Reading a v1 save preserves its
bytes; the next normal checkpoint writes v2. V2 coordinates are never doubled.
The editor uses a 640x360 backing canvas, default 16-pixel snap, doubled placement
defaults, and a new draft-storage namespace; old-unit drafts/history are rejected.

## Story runtime (M3b)

New Game follows Willow Creek (Rin and Oliver) → outbound travel → obstacle
reveal → the handle/winch puzzle → return travel → Clover Market → paper flower
→ end card → Title. Continue restarts the sequence at the saved checkpoint;
a Puzzle checkpoint restores the puzzle directly. Complete opens the end card.
The paper flower is owned exactly when the checkpoint is Complete. Saves retain
the existing v2 format and v1 migration from the 640×360 change.

Story text wraps and paginates on the 640×360 UI. The bundled raylib font supplies
letters; small pixel-stroke glyphs supply its missing em dash (—) and ellipsis (…).
Stored content strings remain unchanged. Cue labels are silent visual placeholders.
No new font, art or audio files are imported.

```sh
python3 -B tests/story/runtime.py  # window-free checkpoint/input/skip tests
python3 -B tests/story/native.py   # macOS native windows; isolated temporary saves
```

DEV_TOOLS autoplay supports `--autoplay story-advance` and `--autoplay story-skip`;
use an explicit temporary `--save-dir` and `TLS_M2_EVIDENCE` rendezvous directory.
The native runner verifies each game PID/window ID before window-only captures,
checks minimum-size text, and kills/relaunches at intro, crank and farewell.
Evidence and the M3b handoff are under `build/evidence/m3b/` (generated, untracked).

## M4 save resilience

A save profile has one write owner for the process lifetime. Another window
shows “Another copy of The Last Stop is open” and cannot start or continue a run;
use the first window so progress never accumulates in an unsavable second run.
The permanent `.write-owner.lock` uses POSIX `F_SETLK`; do not remove it while
playing. Static directory symlinks are supported. Replacing/retargeting the
profile directory or its lock reports a visible failure and keeps progress dirty.
The directory is anchored by device/inode and a held descriptor; temporary write,
rename and fsync use that descriptor. This detects changes during saving, and
cannot prevent an external program deleting a successfully saved file later.

Quit to Title, the end card and native window close retry the current checkpoint.
A failed/uncertain save keeps the run open with **Retry save / Return to game**.
Return preserves the current scene and any pending fade. Continue reads the
file again when pressed; a missing or rejected file never resumes a cached run.
The schema remains `save_version: 2` (including the existing v1 unit migration).

SIGTERM and SIGKILL deliberately remain abrupt: restart restores the **last
successfully saved checkpoint**, with held handles safely recovered and no reward
or completion cue replay. Unsaved progress cannot survive an abrupt kill. No
filesystem or rendering work runs inside a signal handler.

Maintained resilience checks (all profiles and probes under `/tmp`):

```sh
python3 -B tests/resilience/run.py --quick       # also in scripts/check.sh
python3 -B tests/resilience/run.py --disk-full   # full crash/reload/assets + real ENOSPC
python3 -B tests/resilience/native.py            # macOS; Pillow, Swift, Accessibility
```

The native runner drives logical Input through release-disabled hooks and uses
PID-scoped Accessibility for actual close/minimize/restore/focus and resize.
It verifies the exact game PID/title/window ID before window-only screenshots;
invalid captures are deleted. It does not establish physical keyboard feel or
subjective readability. Results, seeds, process exits and handoff are retained
under `build/evidence/m4/`; verbose probe logs and temporary profiles are retained
at the `/tmp` paths recorded there. `M4_TEST_HOOKS` and `M4_SELF_TEST` are absent
from ordinary release builds. Live content reload recovers unsafe dropped-handle
placement transactionally while preserving Held state, crank progress and story.
