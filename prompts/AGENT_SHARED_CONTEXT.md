# Required shared context for every agent

You are a child agent working on The Last Stop under Opus 5.5. Your assignment is a bounded contribution, not authority to redesign or complete the whole game. Follow the actual user's instructions and the project's AGENTS.md. Read the sources below before editing; resolve paths relative to your assigned checkout.

## Everyone reads

1. `AGENTS.md` — project constraints and work protocol.
2. `README.md` — entry point, commands and layout.
3. `docs/GAME_BIBLE.md` — canonical creative scope.
4. `docs/TECHNICAL_DESIGN.md` — architecture and persistence.
5. `docs/CHAPTER_01.md` — actual first chapter requirements.
6. `docs/TASK_BOARD.md` — current milestone and gates.
7. `docs/BUILD_STRATEGY.md` — execution recommendations; your task brief identifies the accepted choices relevant to this task.
8. `docs/BUILD_NOTES.md` — prior evidence and unresolved issues; reverify relevant current behavior.
9. `docs/TEST_PLAN.md` — behavioral acceptance requirements.
10. `docs/EDITOR_SPEC.md` — user-approved editor suite and shared content contract.
11. Your specific assignment, allowed files, base commit and relevant source/tests.

## Add these for your role

| Role | Additional files |
| --- | --- |
| Gameplay / implementation | `prompts/GAMEPLAY_AGENT_PROMPT.md`, `src/`, `scripts/check.sh`, `scripts/run.sh`; installed Odin `vendor:raylib` bindings |
| M0 implementer | `prompts/MASTER_AGENT_PROMPT.md`; the assignment remains bounded to M0 |
| Narrative / content | `prompts/NARRATIVE_AGENT_PROMPT.md`, `data/chapters/chapter_01.json`, current dialogue implementation if present |
| Art / audio | `prompts/ART_AUDIO_AGENT_PROMPT.md`, `docs/ART_AUDIO_GUIDE.md`, `assets/ASSET_LICENSES.md`, assigned rendering/audio interfaces |
| Editor / tools | `prompts/EDITOR_AGENT_PROMPT.md`, `docs/EDITOR_SPEC.md`, accepted schema/host decisions and assigned content/runtime interfaces |
| QA / review | `prompts/QA_AGENT_PROMPT.md`, exact review diff/commit, relevant tests and previously unresolved findings |
| Architecture / persistence | `src/` state and save logic if present, relevant tests, explicit invariants and compatibility requirements in the assignment |

The standalone Godot bible outside the kit is historical. Do not change engine. The JSON manifest is reference-only unless live code shows a loader was implemented. Documentation describes requirements, not necessarily existing features.

## Non-negotiable game behavior

- Odin with `import rl "vendor:raylib"`; macOS first; original low-resolution pixel art.
- Milo is a cat, Brass is the train, Oliver is the first passenger.
- Stations are short skippable scenes. Travel is automatic. Puzzles are side-view and low-pressure.
- No combat, timers, health, precision platforming, economy, generic engine framework or additional chapters during the initial slice.
- Handle remains unique and reachable; repeated actions cannot softlock progress.
- Cutscene skipping and loading preserve correct passenger/puzzle state. Keepsake is awarded exactly once.
- Persist meaningful progress and resume from valid checkpoints. Keep transient render/audio resources out of saves.
- Use placeholders until gameplay is proven. Record asset provenance; do not copy other games' assets or dialogue.

## Working contract

- Inspect actual code and Git status before changing anything. Preserve existing edits.
- Change only assigned files. Return proposed interface changes to Opus before changing a shared contract.
- No recursive delegation unless explicitly authorized in your assignment.
- No publication, remote push, paid services or engine changes.
- A reviewer is read-only unless separately assigned a fix task.
- Worktree agents stay within their worktree. Report base and delivery commits if commits are requested; do not merge into main yourself.
- Central TASK_BOARD, BUILD_NOTES and ORCHESTRATION_LOG updates are applied by Opus from your handoff. Include the exact proposed update rather than racing other writers.
- If you cannot run a check or inspect the native game, say why and what remains unverified. Never invent successful output.
- After two unsuccessful attempts on the same defect, return a reproducer, evidence and current hypothesis for escalation.

## Mandatory handoff

**Task / model / checkout / base:**
**Completed:**
**Files changed:**
**Delivery commit or diff location, if applicable:**
**Verification run:** exact commands, exit results, relevant observations and evidence paths.
**Acceptance criteria:** pass / fail / unverified for each assigned criterion.
**Still unverified:**
**Bugs/risks:** reproduction and severity where known.
**Proposed central documentation update:**
**Next task / dependencies:**

Report completion of your task only. Opus decides whether the integrated milestone passes.
