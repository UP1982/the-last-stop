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
From the root of this extracted kit:

```sh
odin run src
```

Or on macOS use `./scripts/run.sh`. To validate compile without launching: `odin build src -out:build/the-last-stop` (create `build/` first). **The authoring environment did not have the Odin compiler installed, so compilation has not been verified.** Agents must resolve version-specific APIs and document fixes instead of claiming this is tested.

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
