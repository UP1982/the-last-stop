# The Last Stop — build strategy and model assignments

Prepared October 16, 2026. This is a proposed execution plan, not a record of completed gameplay. Existing source and milestone checkboxes have not been changed.

## Recommendation

**Approved scope addition:** build all three editor surfaces: visual content editing, in-game edit mode, and a coding/agent workspace. Follow `EDITOR_SPEC.md` and E0–E4 in TASK_BOARD alongside the game milestones. The editor is planned, not implemented. Opus owns orchestration/integration; Sol is the primary implementer.

Finish one delightful, resumable Oliver journey in Odin + raylib before producing the rest of the game. Use GPT-6.1 Sol for routine implementation, Opus 5.5 for creative direction and substantial independent review, GPT-6 Astra for architecture and difficult correctness problems, and Haiku 5.5 for small well-specified support tasks. One person/model owns integration. You own the final decisions about feel, art, writing, and scope.

## What exists and what needs reconciling

- Reviewed the standalone bible, extracted kit instructions, all kit design documents and agent prompts, source, shell scripts, content manifest, and asset register. The zip is a distribution artifact; work in the extracted kit.
- The actual game is currently one small `src/main.odin` drawing static shapes and text. No playable controller, puzzle, dialogue, save system, audio, or finished assets exists in that source. The JSON manifest is not loaded.
- Odin is installed at `/opt/homebrew/bin/odin`. Version: `dev-2026-10:84bc3fc21`. `odin check src` passed with exit code 0. No window/playtest or release packaging was performed during this planning task.
- Neither the workspace nor extracted kit is currently inside a Git repository. Set up local version control and a baseline before implementation; no remote publication is required to start.
- The standalone version 0.1 bible specifies Godot. The kit's canonical version 1.0 bible and AGENTS.md specify Odin + raylib. Follow the kit. Mark the standalone document historical during documentation cleanup so future agents do not switch engines.
- Chapter 1's detailed script and JSON agree on the flower-bloom arrival dialogue, while the canonical bible has a different farewell. Use `CHAPTER_01.md` for the exact implemented beats and reconcile the overview.
- Set the crank to press once to start, with no button mashing or sustained hold required. This resolves inconsistent hold/repeated-press descriptions in favor of the accessible option already proposed by the chapter document.
- Treat the 10–15-minute first chapter and 1.5–3-hour game as hypotheses. Six 3–7-minute journeys imply roughly 18–42 minutes plus prologue and transitions. Do not pad walking or add chapters merely to hit an unsupported duration.

## Model routing

These are starting assignments, not measured rankings on this repository. The live T3 catalog exposes all four models, but availability does not establish task quality or remaining subscription quota.

| Model | Default responsibility | Starting effort | Escalation/use limits |
| --- | --- | --- | --- |
| GPT-6.1 Sol | Primary implementer and integrator: rendering, input, movement, UI, dialogue plumbing, asset integration, ordinary fixes | Medium; high for multi-file/state changes | Escalate after two unsuccessful fixes or an unclear state contract. Avoid rewriting architecture to solve a local bug. |
| Claude Opus 5.5 | Creative lead: scene composition, puzzle readability, concise dialogue, visual polish; independent milestone/code review | Medium; high for difficult review | Also a credible coding substitute. Judge delivered builds, not a permanent creative-only label. |
| GPT-6 Astra | State architecture, persistence invariants, skip/reward edge cases, hard debugging, technical milestone review | High for these bounded tasks | Use on risky decisions or unresolved failures rather than every small implementation. |
| Claude Haiku 5.5 | Asset inventories, license records, dialogue/data formatting, focused documentation, reproducible test execution and small isolated fixes | Low/medium | Supply exact examples and acceptance criteria. Do not give sole ownership of save correctness, architecture, or release acceptance. |

Provider evidence supports Sol as a workhorse and Astra for complex reasoning; Anthropic positions Haiku for efficient high-volume work and reports strong coding/polish performance for Opus. None of those sources proves an Odin-specific winner. Sources checked October 16, 2026:

- [OpenAI model guidance](https://developers.openai.com/api/docs/models)
- [Claude Opus 5.5 release and evaluations](https://www.anthropic.com/claude-opus-5-5)
- [Claude Haiku 5.5 release](https://www.anthropic.com/claude-haiku-5-5)

Calibrate with real work: log first-pass compile success, acceptance failures, rework, elapsed time, and available usage/cost for the first few tasks. If Sol struggles with Odin, give Opus the next similarly scoped task and compare reviewed outcomes. Reserve a same-task isolated comparison for persistent uncertainty; four duplicate implementations are unnecessary overhead. Do not default every task to maximum effort or fast/premium mode.

## Build order and acceptance gates

### 0. Make the foundation trustworthy — Sol, then a focused review

Preserve the original files, establish Git, record the installed toolchain and repeatable commands. Complete existing M0 before parallel implementation: launch and inspect the starter; implement a 320×180 render texture, nearest-neighbor integer scaling/letterboxing, and a minimal Start/Quit title with game-mode transitions. Define the minimum supported window size. Keep an initial plain title; animated title art comes later.

Explicitly disable raylib's default Escape-to-close behavior when Esc becomes pause. Make close/quit pass through the game's shutdown/save path once saving exists. Use a stable resource root so launching a packaged executable from another directory will work.

Gate: actual native window opens, resizes without blurry pixels or clipped UI, transitions correctly, and exits cleanly. `odin check src` alone cannot prove this. Record the compiler version, actual architecture and results in BUILD_NOTES.md.

### 1. Make Milo enjoyable to control — Sol; you playtest

Complete M1 with rectangles: left/right movement, forgiving ground collision and small jump, camera limits, one clear interaction focus, pause/resume/quit and readable prompts. Separate input collection from game updates. Keep the route short and all mandatory areas reachable without precision jumps. Use a fixed simulation step for movement/collision, or validate a simpler clamped-delta implementation across different frame rates before retaining it. Round drawing positions without rounding physics state.

Gate: five minutes of keyboard play at different window sizes; no camera jitter, stuck terrain, ambiguous focus or movement during pause. You judge whether movement feels gentle and responsive.

### 2. Make one complete puzzle and its saved state — Sol with Astra reviewing the state contract

Complete M2: train/branch, visibly connected rope and winch, shed, handle, installation, crank activation, branch movement, return affordance. Add the optional snail and hints after the required puzzle works.

Bring the persistence design and a first save/load implementation forward from M4. M4 remains the comprehensive resilience gate. Define state before tying behavior to animations: handle location is an enum such as shelf/held/dropped/installed, with a valid dropped position where applicable. Avoid contradictory booleans that allow a carried and installed handle simultaneously. Validate loaded positions and recover unreachable items at a safe marker.

Persist meaningful state transitions and restore defined stable checkpoints. Keep the handle unique, branch completion monotonic, and return unavailable while blocked. Make route-opening effects occur once; loading a cleared branch must not repeatedly trigger its sound or animation.

Gate: three clean completions; wrong-order interactions; pick/drop/recover; quit/reload with handle unfound, held, dropped, installed, crank operating and branch cleared. No lost handle, duplicated item or blocked exit. Add automated state-transition and save round-trip tests for these risks.

### 3. Wrap it in Oliver's complete journey — Sol implements; Opus edits the experience

Complete M3: title → short introduction → automatic travel → obstacle reveal → puzzle → return → arrival → one paper flower → end card. Use the shared E0 versioned content loader and E3 structured dialogue authoring. Do not build an unrestricted scripting language or duplicate the dialogue in hardcoded arrays.

All routes through a cutscene—normal finish, skip, reload—must converge on the same durable passenger/reward state. Put side effects in explicit transition functions, not draw calls or dialogue line rendering. Make reward granting idempotent by keepsake ID. Prevent a held interaction key from skipping multiple screens or activating the next scene accidentally.

Gate: a whole journey works both watched and skipped; skipping travel never bypasses the unsolved puzzle; reload around the farewell grants exactly one flower. Have someone unfamiliar with the game attempt it without instructions from you. Record where they hesitate before adding features.

### 4. Prove stopping and resuming is safe — Sol fixes; Astra independently reviews

Finish M4's versioned save file, atomic temporary-write/rename flow, app-specific user data location, corrupt/unknown-version handling, and stable checkpoint normalization. Serialize no pointers, textures, audio objects or transient renderer state. Preserve a last-known-good save where practical and report failed writes rather than claiming progress was saved. New Game must not silently destroy an existing run.

Test actual process restarts, pause during transitions, repeated skip, missing save, truncated save, unknown version, failed write, and launch from a different working directory. A simulation test does not replace native restart testing.

Gate: TEST_PLAN.md results have dated evidence, failures are fixed or explicitly block the milestone, and no known progress-loss or duplicate-reward bug remains. Compilation, automated checks, native behavior and fresh-player completion are separate evidence categories.

### 5. Make the proven chapter look and sound finished — Opus directs; Sol integrates

Complete M5 in small asset batches. Start with a style reference showing Milo, Brass, Oliver, branch/winch/handle, and one forest screen at actual game resolution. Lock sprite scale, palette, readable silhouettes, animation pivots and atlas/frame naming before producing more art.

Production order: Milo idle/walk/interact; train/door/windows; puzzle props and clear completion animation; Oliver and two station vignettes; parallax/rain; optional snail; title polish. Use a pixel editor or dedicated image tool plus manual cleanup/export for final assets. A coding model can specify, integrate and critique assets; text-model access alone does not supply finished consistent sprite animation or music. Keep original placeholders until replacements are usable.

Add sparse audio: tactile pickup/crank/branch sounds, wheels/whistle, rain, then one music loop. Integrate separate music/SFX levels and silence support. Record source, creator, license, changes and attribution for every asset/font/audio file. Check sprite sheets for frame dimensions, pivots, transparency and consistent pixel density; listen for loop seams and harsh transients.

Gate: readable text and clues, no required color-only information, no mandatory hold/mash, understandable hints, comfortable audio, correct pause behavior, and a new player completes the chapter without coaching. Your approval of feel and presentation is necessary; an AI screenshot critique is supporting evidence.

### 6. Expand only after the slice passes — one chapter at a time

Recommended production order differs from narrative order: Bea first (reuse carry-and-place), Hazel (discrete water/sluice states), Lumi (two-lever alignment), Felix last (positioning and light-direction readability), then finale. Keep the original story order in the released game if desired. If story dependencies make that awkward, use original chapter order while keeping Felix's technical scope small.

Use state-based water visuals rather than fluid simulation. Use discrete mirror angles and readable beam segments rather than a general optics engine. Give every chapter one main insight and one new variation, with existing controls. The finale combines learned ideas and reuses passengers/environments where appropriate.

The editor requires validated data loading during Chapter 1. On the second chapter, extend only demonstrated common structures: chapter identity, scene beats, interaction definitions, checkpoint state and reward ID; keep unique puzzle rules explicit in Odin. Each chapter repeats the graybox → readable puzzle → save tests → story → presentation → fresh playtest cycle.

Gate: no next chapter until the current one can be completed and resumed reliably. Measure median first-time completion and confusion points to set the final game length. Consider a shorter polished release before expanding toward 1.5–3 hours.

### 7. Package a game other people can run — Sol; independent QA

Build a macOS application bundle with bundled assets, stable resource paths, icon, licenses, version and reproducible release instructions. Verify on a clean user environment without your compiler or development folder. Verify supported architectures individually; do not assume a universal binary. Add signing/notarization according to the chosen distribution channel and available credentials when ready to distribute.

Test title/continue/new game, settings, saves across updates, audio, keyboard/controller if advertised, window handling and the whole story. Other OS builds and store integration are separate later work. Prepare screenshots/trailer from the actual build, set price/platform decisions after playtest evidence, and keep an explicit known-issues list.

## Architecture to keep the game manageable

Use one Odin package with small files as needed: main, game/state, input, player, puzzle, dialogue, save, render, audio. Keep game updates separate from rendering and file I/O so puzzle logic can be exercised without a graphical window. Consult the installed `vendor:raylib` bindings and [Odin docs](https://odin-lang.org/docs/overview/) for real signatures. Build the bounded editor suite described in EDITOR_SPEC. Do not add an ECS, physics engine, networking, economy or generalized quest system.

Define who may change shared types before parallel work. Keep resource loading/unloading centralized. A small number of scene modes and explicit transition functions is sufficient; a visual state-machine editor is not needed.

## How to work with the models in T3

Start sequentially: one Sol implementation task, followed by one bounded review where appropriate. Do not launch four agents against today's single source file. After M0 and shared-state contracts stabilize, narrative/spec work and asset work may proceed alongside a gameplay implementation, each with distinct files.

Use one integration owner. Separate code-producing tasks into worktrees after committing the baseline; worktrees start from committed state and will not receive uncommitted parent edits. Supply each task its base commit, context, allowed files, interfaces, acceptance checks and excluded work. A reviewer normally reports findings without editing. The integrator applies/fixes, checks and playtests the combined result before accepting it.

Use at most two concurrent implementation streams initially. More agents are worthwhile only when tasks are independent and integration is cheap. Keep a handoff describing changed files, commands actually run, remaining unverified behavior, bugs and next task. Update TASK_BOARD and BUILD_NOTES after accepted milestones. Do not use recurring unattended work or automatic publication just to speed up development.

Task template:

> Read AGENTS.md and the canonical design documents. Implement only [specific milestone/task] in Odin + vendor:raylib. Starting commit: [hash]. Allowed files: [list]. Preserve [interfaces/invariants]. Required behavior: [concrete player actions and results]. Run [checks] and inspect [native behavior]. Do not implement [excluded systems]. Report completed work, changed files, actual evidence, unverified items, bugs and next task. Stop at this acceptance gate.

Independent review template:

> Review [commit/diff] against [acceptance criteria]. Focus on [specific risks]. Do not edit files. Give reproducible findings with severity and source locations, distinguish tested failures from hypotheses, and identify missing evidence. Do not approve based solely on the author's report.

## First implementation assignment

Select GPT-6.1 Sol at medium effort in this kit directory. Give it the existing `prompts/MASTER_AGENT_PROMPT.md` plus: record the already discovered Odin version, recheck compilation, set up a local Git baseline, complete only M0, and verify a real native window. Preserve the planning documents. End with the build command, native observations, and next milestone. Then play the foundation yourself before M1.

The first deliverable is a working scaled window and state flow. The first meaningful game deliverable is Milo retrieving and installing the handle, clearing the branch, and safely resuming after quitting. Finished art and additional passengers follow that evidence.
