# The Last Stop — Odin + raylib agent handoff kit

**A cozy 2D pixel-art game about Milo the cat helping animal passengers reach their destinations.** Stations are cinematic; train travel is automatic; obstacles stop the train; Milo hops out to solve short environmental puzzles. Pause and resume at any time.

## Start here
1. Read `AGENTS.md` (instructions and priorities for all AI agents).
2. Read `docs/GAME_BIBLE.md` (creative source of truth).
3. Read `docs/TECHNICAL_DESIGN.md` and `docs/CHAPTER_01.md`.
4. Follow `docs/TASK_BOARD.md` in order. The first milestone is a working window, input, and pixel-perfect render loop.
5. The project includes an intentionally small **starter shell**, not a completed prototype.

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
and runtime loading/allocation tests.

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
`~/Library/Caches/The Last Stop/preview/<session-id>/`. E0b reserves this path;
it creates no saves or session files and never accesses normal saves. `--dump-scene`
prints loaded geometry to stderr, and development builds outline interaction
rectangles. Release builds reject preview/debug flags and have no content-edit
imports or authored-content write path. Interactions are placeholders until M2.

Controls: use Up/Down or W/S in menus, and Enter/Space/Z to confirm. In the loaded Chapter 1
scene, A/D or Left/Right walks Milo; Space/Z/W/Up jumps (hold for a higher hop).
E or Enter interacts with the nearest focused object; its outline, name and key
prompt identify the target. The authored scene has continuous ground and non-solid props. M1’s small-step
controller remains supported and regression-tested; no step is authored here.
Escape pauses/resumes; the pause menu offers Resume, Controls and Quit to Title.
Escape or a confirm key closes the Controls overlay back to the pause menu.
Release jump/interact keys after leaving menus before using them in play.
Escape on the title does not exit. F11 or Alt+Enter toggles fullscreen.
The window is resizable (minimum
640x360); the 320x180 canvas uses nearest-neighbour integer scaling and black
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
