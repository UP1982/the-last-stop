# M2 puzzle state + save v1 contract (accepted by Opus 2026-10-16)

Source: T-M2-A, GPT-6 Astra, read-only consultation at ef3c593. Accepted with amendments:

- B1. Player footprint and focus/interaction interface come from accepted M1 code; if M1 diverges from 12x16, M1's value wins and reachability checks use it.
- B2. Wrong-order response strings are placeholders. The user will supply the story later; keep these strings in the dialogue/content data, not hardcoded literals, once E0b lands.
- B3. Order of work: M1 → E0b (runtime content loading) → M2 implemented on the loaded `oliver_obstacle` scene.
- B4. Older CHAPTER_01/TECHNICAL_DESIGN text about hold/mash cranks and handle booleans is superseded by this contract and E0_CONTRACT.

---

## Runtime types

Use the accepted `oliver_obstacle` content snapshot unchanged.

```odin
Handle_Location :: enum { Shelf, Held, Dropped, Installed }
Puzzle_Phase    :: enum { Blocked, Cranking, Cleared }

Puzzle_State :: struct {
    handle:         Handle_Location,
    dropped_feet:   [2]f32, // bottom-centre; meaningful only when Dropped
    phase:          Puzzle_Phase,
    crank_progress: f32,    // transient 0..1
    snail_seen:     bool,
}

// Durable journey checkpoints, separate from menus, pause and fades.
Journey_Checkpoint :: enum { Chapter_Start, Boarded, Puzzle, Returned, Arrival, Complete }
```

Initial: `Shelf`, `Blocked`, progress 0, snail unseen. Derive held object, branch cleared, puzzle solved and return permission from these fields (`phase == Cleared`). No duplicate booleans.

## Actions

- Pickup: `Shelf/Dropped → Held`.
- Drop: `Held → Dropped` on supported reachable ground; airborne drops project to safe ground; failed validation uses authored `handle_recovery`.
- Install: winch interaction while `Held` → `Installed` only. That press does not also start the crank.
- Activate: fresh press with `Installed + Blocked` → `Cranking`, progress 0; advances automatically while unpaused regardless of key release or walking away.
- Finish: progress reaches 1 → `Cleared`, save, one completion cue. Branch interpolates between authored blocked/cleared positions.
- Return: after clearing, interact with Brass or use the remote "Return to train" affordance; both call one idempotent transition to `Returned`, placing Milo at `train_return`. M2 may end at a returned-to-train placeholder.
- Snail: first interaction sets `snail_seen`; repeats harmless; never gates anything.

Wrong-order actions keep state and give a short response (placeholder text, see B2): empty winch "It needs a handle."; blocked branch points to rope/winch; early return "The track is still blocked."; while cranking "It's turning." (no restart/accelerate); cleared "The track is clear."; pickup/drop of installed handle no-op; absent/out-of-range targets no-op.

One interaction target per fresh press, matching the displayed prompt. Carrying + unfocused press may drop; focused winch press installs. No cascading pickup/install/activate in one press; never carry across a scene transition. Hints derive from state: find handle → carry → install → start crank → wait → return.

## Invariants

- Exactly one logical handle, rendered/interactable only at its enum location.
- `Cranking/Cleared` require `Installed`; clearance never reverses.
- Every loose handle reachable without jumping (full bounds + pickup reach, same footprint as M1).
- Installed handle needs no removal: installation can't softlock.
- Train departure requires clearance; branch never blocks Milo's walking corridor.
- Gameplay, loading and preview never mutate authored content.
- Intro finish/skip → same idempotent `board_oliver`; arrival finish/skip → same guarded `finish_oliver_journey`; travel advance cannot bypass the puzzle.
- Load never replays clearance/reward effects; normalization is idempotent and preserves a completion path.

## Save v1

```json
{
  "save_version": 1,
  "chapter_id": "oliver_flower_market",
  "scene_id": "oliver_obstacle",
  "checkpoint": "puzzle",
  "player_spawn": "puzzle_entry",
  "puzzle": {"handle_location": "installed", "dropped_feet": null, "phase": "cranking", "snail_seen": false}
}
```

Lowercase snake-case enums. `dropped_feet` is a finite pair only when `dropped`, else null. `player_spawn` is `puzzle_entry`, or `train_return` after return.

Checkpoints: `chapter_start` (replay intro), `boarded` (outbound travel), `puzzle`, `returned` (requires cleared), `arrival` (requires cleared; reward pending), `complete` (exactly one paper_flower owned — ownership, never a counter). Pre-puzzle checkpoints require initial puzzle state; returned/arrival/complete require `Installed + Cleared`.

Write at every CHAPTER_01 boundary (new run, boarded, travel-to-obstacle, handle picked/dropped/installed, crank activated, cleared, returned, reward) plus arrival entry, first snail interaction, pause, quit and scene skip. Store the stable underlying checkpoint, never a menu/fade mode.

Load normalization: `Held → Dropped` at validated `handle_recovery`; valid dropped positions survive, unsafe ones recover to the marker; `Cranking` restarts at progress 0 automatically; `Cleared` restores final branch with no cues; Milo at saved marker, zero velocity, camera reset. Invalid authored content blocks loading (never "repaired" via the save). Reject other contradictory combinations.

Location: `~/Library/Application Support/The Last Stop/saves/chapter_01.json`, independent of cwd. `--save-dir <abs>` overrides `TLS_SAVE_DIR`, then default. Tests use fresh temp dirs; preview uses `~/Library/Caches/The Last Stop/preview/<session-id>/`; test/preview must refuse normal-save fallback.

Atomic write: serialize/validate → exclusive temp in destination dir → write all → sync → close → rename → sync dir. Reuse the algorithm without importing authoring mutation code into release gameplay. Pre-rename failure keeps the old save; post-rename sync failure reports durability uncertainty. Keep state dirty and report failures.

Missing save → no Continue. Strictly reject malformed/truncated JSON, duplicate keys, bad types/enums, wrong IDs, unknown versions; preserve rejected bytes, disable auto-overwrite, offer explicit new-run/reset. New Game must explicitly replace or keep an existing run. Rolling backups optional.

## Required tests

1. Three independent completions: direct; repeated drop/recover + wrong-order actions; repeated restarts throughout, snail omitted.
2. Every invalid action in every reachable phase; repeated/held E, simultaneous inputs, pause/unpause, repeat-return cannot duplicate, restart crank or bypass branch.
3. Invariants asserted after each transition; completion path exists from every reachable abstract state.
4. Fresh-process save/reload at every checkpoint (shelf, held, dropped, installed, cranking, cleared, returned), each resumed to completion; double normalization unchanged.
5. Airborne drops, both world edges, invalid loaded coordinates, authored geometry moved between launches → safe recovery, no content edits.
6. Truncated/unknown-version saves, injected write/sync/rename failures, kill before/after rename → complete old or new record only.
7. Launch from another cwd → same save location; preview/test runs leave normal saves and authored files byte-identical.
8. (With M3) normal/skip/reload converge at each dialogue boundary; one paper flower; travel skip can't bypass an uncleared puzzle.

Automated results don't replace three native completions, visible branch movement, readable prompts and real quit/relaunch checks.

## Milestone boundary

- **M2:** transitions, hints, snail, return affordance, versioned atomic saves, profile isolation, normalization, Continue, errors, checkpoint/restart tests.
- **M3:** intro/travel/arrival and reward using reserved checkpoints and idempotent transitions.
- **M4:** full integrated resilience, native restart coverage, skip/reward stress, TEST_PLAN gate. Core save correctness cannot wait for M4.
- **Optional:** rolling backups, exact mid-crank persistence, arbitrary player-position restore. No generic save migration or puzzle engine.
