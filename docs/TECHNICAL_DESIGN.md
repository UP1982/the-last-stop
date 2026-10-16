# Technical design — Odin + raylib

## Verified external conventions
Odin organizes same-package `.odin` files by directory. `odin run src` compiles/runs that directory; `odin check src` checks compilation. Odin includes a `vendor:raylib` binding, typically imported as `import rl "vendor:raylib"`. Consult the current installed compiler's package documentation before assuming exact signatures.

References: https://odin-lang.org/docs/overview/ ; https://pkg.odin-lang.org/vendor/raylib/ ; https://pkg.odin-lang.org/examples/raylib/ports/core/core_basic_window/ . Version pin follows first successful local setup.

## Runtime target
- 320×180 internal canvas in an 1280×720 desktop window, integer or letterboxed nearest-neighbor scaling as window changes.
- Fixed logical coordinates; delta-time update clamped for accidental giant frames; target 60 fps. Avoid variable-framerate differences in movement.
- Pixel-accurate texture filtering: nearest neighbor, no subpixel texture smear.
- Logical controls: left/right, jump, interact/advance, pause, hint. A/D and arrows, Space, E or Enter, Esc/H. Gamepad support after keyboard slice is solid.
- Inputs route through centralized procedures. Support interaction prompts and cutscene skip.

## State flow
`TITLE -> STATION_INTRO -> TRAIN_TRAVEL -> OBSTACLE_ARRIVAL -> PUZZLE -> RETURN_TO_TRAIN -> TRAIN_TRAVEL_RESUME -> STATION_OUTRO -> CHAPTER_COMPLETE -> TITLE_OR_NEXT`. Use a `Game_Mode` enum and transition helper. Mode entry side effects (award keepsake, scene transition) must be idempotent. Cutscenes are deterministic dialogue beats, not free-roam stages.

## Suggested Odin types
- `Game_State`: current mode, chapter ID, scene, player, train, puzzle, dialogue, collected keepsakes, save version.
- `Player_State`: position, velocity, grounded, facing, held-object ID.
- `Puzzle_State`: handle picked, handle installed, crank rotation/progress, branch cleared; optional snail seen.
- `Dialogue_State`: scene beat index and animation timer.
- `Interactable`: ID, rectangular interaction bounds, verb, world state dependency.
- `Save_Data`: versioned serializable subset only. Never serialize pointers or raylib handles.

## Input and collision
Use raylib for keyboard/gamepad input and rendering. Simple AABB collision and basic gravity suffice for MVP. Use world-space rectangles and a short grounded collision pass. Favor forgiving proximity and short traversal distances. Don't use a full physics framework.

## Interactions
Single E/Enter interaction near the most appropriate object; screen prompt shows its verb. Carried handle is one held object, not an inventory system. Picking up, dropping, installing, and turning crank must be reversible or safely recoverable; no action can strand the handle outside reachable terrain.

## Puzzle state machine
`BLOCKED -> HANDLE_FOUND -> HANDLE_CARRIED -> HANDLE_INSTALLED -> CRANK_OPERATED -> CLEARED`. Nonlinear transitions are allowed (drop/pick), but only `CLEARED` triggers the route-opening sequence. Play completion animation/sound once, including after load. Save puzzle changes after meaningful state transitions.

## Persistence
- Versioned small save file in an application-specific user data directory, *not* a path dependent on current working directory. Confirm practical Odin filesystem API on installed version.
- Save atomically via temporary file and rename where supported. Handle corrupted/unknown version files gracefully.
- Persist current chapter/mode, safe player entry point, puzzle booleans, passenger progress and keepsakes; avoid serializing transient animation frames.
- On quit/pause/cutscene skip, checkpoint. When saving during transitions, resume at defined stable mode checkpoints to avoid stuck states.
- Test quit/resume at every puzzle state, before and after reward.

## Rendering architecture
Frame: gather input -> update current mode -> update camera/interactions -> render world to low-resolution target -> composite to window with letterboxing -> render UI (pixel font at virtual scale). Separate world camera from UI. Ensure close/unload operations for textures, audio, render textures.

## Audio
raylib `InitAudioDevice` only when needed; use `UpdateMusicStream` during playback; unload sound/music resources at shutdown. Allow music/SFX volume settings later. No licensed audio is bundled.

## Data authoring
`data/chapters/chapter_01.json` is currently a reference manifest, not loaded by starter code. The user has requested the full editor suite in `EDITOR_SPEC.md`. Implement E0 versioned content schemas, shared runtime validation/loading and structured agent operations during Chapter 1. Migrate the illustrative manifest explicitly; do not assume it is already a scene format. Visual editing, in-game development editing and the coding/task workspace must round-trip the same content. Keep authoring data, editor state and player saves separate. Do not create an unrestricted dialogue scripting language.

## Proposed eventual source split
`src/main.odin`, `src/game.odin`, `src/player.odin`, `src/render.odin`, `src/input.odin`, `src/puzzle.odin`, `src/dialogue.odin`, `src/save.odin`, `src/audio.odin`. All may begin as one package, split only as complexity requires. Code in `src` must use one consistent Odin package declaration.

## Build and release
`odin check src`, `odin run src`, `odin build src -out:build/the-last-stop`. Before shipping, record `odin version`, compiler flags, actual macOS architecture, licenses, and reproducible packaging instructions. Do not assert this kit compiles: authoring environment lacks Odin compiler.
