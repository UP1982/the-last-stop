# Story implementation contract (accepted by Opus 2026-10-16)

Source: T-STORY-1, GPT-6 Astra, read-only at 977efc4, from the user's screenplay (docs/THE_LAST_STOP_SCREENPLAY.fountain) and docs/STORY_GAMEPLAY_PLAN.md. Accepted with amendments:

- S1. This document supersedes conflicting passages in GAME_BIBLE.md, CHAPTER_01.md, TECHNICAL_DESIGN.md and the "Beyond slice" list until Opus applies the proposed edits to those files (done during M3 integration).
- S2. Opening is staged/advanceable (no free-walk at Willow Creek) for the slice; a playable opening is a user decision for later.
- S3. Order: M2 review fixes → T-M3a (chapter/dialogue v2 loader, validation, migration, B2 strings) → T-M3b (story player runtime). Same owner (Sol) sequentially; src/ and shared/content are single-writer.
- S4. Art scale must be resolved by the accepted art pipeline; coordinates in examples are illustrative.

---

**Task / model / checkout / base:**  
T-STORY-1, “Screenplay → implementation design” / GPT-6 Astra, Narrative/Story-systems / `/Users/finngilbert/Documents/The Last Stop/Game` / `977efc467429097411129a49b19f4af932a75520`.

**Completed:** Read the screenplay and HTML render, gameplay plan, requested contracts/content, shared-context references, asset README and filenames, and relevant current runtime code. Delivered the proposed Chapter 1 contract below.

**Files changed:** None. No staging, commits, delegation, builds, or game launches.

**Delivery commit or diff location:** This message is the handoff. Recommendations remain proposed until Opus accepts them.

**Recommendation:** Adopt the screenplay’s Chapter 1 story and dialogue, retain M2’s puzzle and save invariants, and add a small data-driven presentation layer. Keep `save_version: 1` and all six `Journey_Checkpoint` values. Later chapters remain planning-only.

---

**1. Reconciliation and exact proposed document edits**

The screenplay explicitly describes itself as a proposal; it has not already superseded the bible. Opus should record adoption before content implementation.

**Required — naming, setting, Milo, Rin and supper setup**

In [GAME_BIBLE.md](/Users/finngilbert/Documents/The%20Last%20Stop/Game/docs/GAME_BIBLE.md), replace the pitch sentence about the oversized cap with:

> Its conductor is Milo, a small ginger cat with a red scarf and a well-used backpack.

Replace the first sentence under “Milo, the playable cat” with:

> Milo is a small ginger cat wearing a red scarf and a well-used backpack. He keeps the backpack with him throughout Chapter 1; putting it down is reserved for the proposed finale.

Retain Milo’s existing largely silent, expressive characterization. Add beneath Brass:

> **Rin** is a raccoon with a tool satchel who remains at Willow Creek repairing its bench and disused second platform. She introduces the old platform-supper tradition. She is a supporting character, not Oliver’s replacement as the first passenger, and her repairs are staged story actions rather than Chapter 1 puzzles.

Replace “Narrative arc” with:

> Milo’s first circuit begins at Willow Creek in late afternoon. Its disused second platform is called The Last Stop. Rin repairs it while Milo helps passengers along the route. Supper notices and the passengers’ own plans establish their reasons for returning; no invitation quest or simulated offscreen travel is required. The proposed finale brings Milo back to this familiar platform, where he joins the meal himself. The emotional arc is belonging through ordinary kindness. Only Chapter 1 is authorized for implementation.

Replace the prologue paragraph with:

> At Willow Creek, Milo studies an unhelpful timetable. Rin explains that Brass knows the route and Milo looks after the passengers. She points out the old supper platform. Milo helps her catch a loose bench slat before Oliver calls from off screen. Chapter 1 presents this as a short, advanceable and skippable station sequence.

“Dawn Platform” becomes **Willow Creek Station** in player-facing text. Preserve existing technical IDs; this naming change requires no save migration. “Clover Market” remains the destination value; **Clover Market Halt** is the station’s display heading.

**Required — Oliver’s journey and dialogue**

Replace the bible’s Chapter 1 outline with:

> **Passenger:** Oliver, a rabbit wearing a scarf and carrying a paper-wrapped flowerpot and travel bag.  
> **Goal:** Take his flowers to Clover Market. The market is relaxed; there is no closing-time threat.  
> **Station:** Oliver’s ear catches in his bag strap. Milo frees it. Oliver boards sideways to protect the pot.  
> **Travel:** Oliver turns the pot toward the window and explains that his flowers might enjoy meeting other flowers.  
> **Obstacle:** A fallen branch blocks the rails. A visible rope connects it to a winch with an empty handle socket.  
> **Puzzle:** Retrieve the visible handle from the open tool shelter, carry it to the winch, install it with one interaction, then release and press Interact again to start automatic cranking. The branch moves clear; no holding, repeated tapping or precise jump is required.  
> **Optional discovery:** A snail beneath a leaf raises its feelers; Milo waves. This never gates progress.  
> **Return:** After clearance, walk to Brass or use Return to train. Both paths perform the same guarded transition.  
> **Arrival:** One flower has opened. Oliver folds spare wrapping paper into a paper flower for Milo’s window, then notices Rin’s supper card and plans to bring flowers back on foot.  
> **Keepsake:** Exactly one `paper_flower`, granted by arrival completion or arrival skip.  
> **Slice ending:** Hold on the paper flower, display “A little further down the line…”, then offer return to the menu.  
> **Dialogue:** Use the screenplay line ledger in CHAPTER_01.md. The former rainy-day farewell is superseded.

This removes the bible’s alternate “Does this train stop…” and rainy-day farewell. The two existing arrival lines and `intro_02` remain verbatim.

The plan’s claim that existing lines are simply retained needs precision. Replace it with:

> The existing introduction’s combined opening line is split into Oliver’s off-screen “Excuse me!” and his subsequent question. The question retains `intro_01`; the off-screen call receives `intro_call_01`. `intro_02`, `arrival_01` and `arrival_02` retain their text and IDs. New prologue, travel, obstacle and arrival lines follow the screenplay.

**Required — keepsakes and continuity**

Replace the bible’s general keepsake/timetable implication with:

> The proposed full story accumulates three keepsakes: Oliver’s paper flower, Hazel’s river stone and Felix’s opened invitation. Chapter 1 implements only the paper flower. Supper notices are fixed scene details, not collectible invitations or progression requirements. No timetable-unlock mechanic is required.

In Chapter 1, display the carriage supper card from its first interior shot. This makes its later appearance with Hazel continuous without adding a “card acquired” action.

**Required — crank, return and recovery**

M2 already supersedes the old hold/mash instructions. Replace the affected CHAPTER_01 paragraph with:

> One interaction installs the carried handle. A separate fresh interaction starts automatic cranking. Cranking continues while unpaused without further input, even if Milo walks away. Installation and clearance are irreversible safe progress. Before installation, the unique handle can be dropped and recovered. Invalid drops use the authored `handle_recovery` marker.

Replace the plan’s “nearest safe placement” sentence with:

> Drops project onto supported reachable ground; if that placement is invalid, the same handle returns to the authored `handle_recovery` marker.

Do not change recovery to a new nearest-point algorithm.

**Required — branch staging reconciliation**

The screenplay says the branch settles in a recess; current data moves it from `[96,120]` to `[96,88]`, visibly upward. Preserve M2 geometry initially and adapt the staging:

> The winch draws the branch up and aside into a supported trackside recess. Its final position visibly clears the rails and remains outside Milo’s walking corridor.

The art should show a support/recess at the authored endpoint. If that composition cannot read convincingly, propose a separate reviewed scene-geometry edit; do not silently move puzzle objects during story integration.

**Required adaptation — opening movement**

The screenplay includes a short playable platform walk, whereas current station requirements favor staged cutscenes and E0 only defines a puzzle scene.

Recommend this minimal slice adaptation:

> For Chapter 1, Milo’s short walk toward Brass and look toward the old platform are staged, advanceable beats. Advancing does not require a separate station-control mode. The bench catch remains staged. Free walking at Willow Creek is deferred.

This preserves every spoken line and the story setup. A literal playable opening is **optional**, not an M3 prerequisite. If retained later, it needs bounded walkable staging and explicit skip behavior—not a hub or repair puzzle.

**Required — timing and later outline**

Replace CHAPTER_01’s opening goal with:

> A complete, funny, gently sweet first journey. The 10–15-minute first-player duration is a playtest hypothesis, not a minimum enforced through reading, travel or backtracking. Oliver expresses concern about his flowers blooming; the market itself is not closing.

In TASK_BOARD’s “Beyond slice,” replace the old roster with:

> Planning only: Hazel’s waterwheel crossing and reunion; Felix and Hugo’s tunnel invitation and basket puzzle; Pip and Elara’s bridge-signal puzzle; return to Willow Creek for supper. These replace the draft Bea/Lumi chapter sequence. No later chapter implementation begins before the Chapter 1 gate.

The proposed full-story estimate is **26–46 minutes**, unverified. Remove any implication that the current screenplay supports 1.5–3 hours without additional design.

---

**2. Chapter 1 beat sheet, complete dialogue and checkpoints**

Use this section as the replacement implementation beat sheet for [CHAPTER_01.md](/Users/finngilbert/Documents/The%20Last%20Stop/Game/docs/CHAPTER_01.md).

There are **15 spoken lines including the prologue**. Milo and Brass have no spoken dialogue. IDs below remain stable when text or ordering changes.

**Beat A — Title → Willow Creek station**

Mode: `Station_Intro`.  
New Game initializes the initial puzzle state and writes `Chapter_Start` before entering the presentation.

Establish autumn leaves, amber carriage windows, Milo’s scarf/backpack, timetable and Rin’s loose bench slat.

- `prologue_rin_01`, speaker `rin`:  
  “First day on this line?”
- Milo nods.
- `prologue_rin_02`, speaker `rin`:  
  “Brass knows the way. You look after the passengers.”
- Brass gives a low whistle; Milo’s ears rise.
- Show the unused boarding place and faded sign; Milo points.
- `prologue_rin_03`, speaker `rin`:  
  “The Last Stop. We used to have supper there when the lamps came on.”
- Rin tests the slat against the bench.
- `prologue_rin_04`, speaker `rin`:  
  “I thought I'd mend a few things. See who turns up.”
- Milo catches the slipping end; they rest it safely.
- `prologue_rin_05`, speaker `rin`:  
  “That's a start.”
- Stage the short walk/look described above.
- `intro_call_01`, speaker `oliver`, delivery `offscreen`:  
  “Excuse me!”

Checkpoint remains `Chapter_Start`. Individual lines do not change durable state.

**Beat B — Oliver boards**

Continue the same `intro` sequence. Show the flowerpot balanced on Oliver’s bag and his caught ear.

- `intro_01`, speaker `oliver`:  
  “Does this one go to Clover Market?”
- Milo nods and frees the ear.
- `intro_02`, speaker `oliver`:  
  “Oh, good. My flowers are beginning to think I made it up.”
- Oliver boards sideways; bag follows; Rin and Milo wave.

Normal completion and **Skip scene** both call `board_oliver`, writing `Boarded`, then enter outbound travel. Skipping anywhere in Beats A–B completes this whole station introduction.

**Beat C — Automatic outbound travel**

Mode: `Train_Travel`; checkpoint `Boarded`.

Begin with moving train/forest scenery, then the carriage interior. Oliver sits with the pot and turns it toward the window.

- `travel_01`, speaker `oliver`:  
  “They've been on the kitchen table all week. I thought they might enjoy meeting other flowers.”

Milo blinks; the bud does nothing; Oliver turns the pot farther.

Travel animation is automatic. Dialogue waits for the player. Advance/skip never routes directly to arrival.

At travel completion or skip, call `enter_obstacle`, write `Puzzle`, and enter the obstacle-reveal presentation.

**Beat D — Obstacle reveal**

Mode: `Obstacle_Arrival`; checkpoint already `Puzzle`.

Brass stops short of the branch. Frame branch, rope and bare winch socket together where possible. Milo steps down; Oliver leans out.

- `obstacle_01`, speaker `oliver`:  
  “I can hold the flowers.”
- Oliver looks at the pot already in his paws.
- `obstacle_02`, speaker `oliver`:  
  “I've had practice.”

Normal completion or skip enables puzzle control at `puzzle_entry`; checkpoint remains `Puzzle`. A quit/reload during this reveal resumes directly into the unsolved puzzle. This is intentional checkpoint-based resume, not lost gameplay.

**Beat E — Puzzle**

Mode: existing `Playing`; checkpoint `Puzzle`.

Inspect → retrieve → carry → install → fresh press to crank → clear.

Write `Puzzle` after each existing meaningful change:

- Handle pickup, drop and installation.
- Crank activation.
- Branch clearance.
- First snail interaction.

No dialogue scene or skip action solves the puzzle. Do not require inspection before pickup: the sequence is explanatory, not a hidden action checklist.

The optional snail has no spoken line. Its interaction can show feelers and Milo’s wave; repeating it is harmless.

**Beat F — Return and resumed travel**

On clearance, play the single M2 completion cue: branch settles and Brass gives two pleased notes.

Keep control available. The player may walk back or use Return to train.

Both return paths use M2’s guarded transition, write `Returned`, put Milo at `train_return`, and start `Train_Travel_Resume`. Stage dusting paws, checking the clear track and boarding. Then show brief automatic travel. There are no spoken lines.

Do not replay the branch-clearance cue in this sequence or on load.

Completion/skip requires the cleared puzzle, calls `enter_arrival`, writes `Arrival`, and enters the market sequence.

**Beat G — Clover Market arrival**

Mode: `Station_Outro`; checkpoint `Arrival`.

Show an open, unhurried market stall. Oliver lifts the pot; one flower is already open before his first line.

- `arrival_01`, speaker `oliver`:  
  “I was worried they wouldn't bloom in time.”
- Oliver shows Milo the blossom.
- `arrival_02`, speaker `oliver`:  
  “I suppose they just needed a little trip.”
- Oliver folds spare wrapping paper and places the paper flower on the windowsill.
- `arrival_03`, speaker `oliver`:  
  “For your window.”
- Milo taps a petal; it springs back.
- Show the notice, with Rin’s small portrait:

  **WILLOW CREEK PLATFORM SUPPER — ALL WELCOME**

- `arrival_04`, speaker `oliver`:  
  “Oh. I'll take some flowers back for that. It's a lovely walk from here.”

Milo looks between notice and flower; Brass whistles.

The flower visible during this sequence is presentation state. It does **not** independently grant ownership.

**Beat H — Keepsake commit**

Normal arrival completion and arrival skip call the same `finish_oliver_journey`.

Precondition: `Arrival`, handle installed, branch cleared.  
Result: `Complete`, with exactly one paper flower owned.

Keep the current derivation `owns_paper_flower == checkpoint == Complete` for this slice. Do not introduce a reward counter or a second saved ownership boolean.

Write `Complete` before entering the end card.

**Beat I — End card → Title**

Mode: `Chapter_Complete`; checkpoint `Complete`.

Show the paper flower and:

> A little further down the line…

Advance or Skip returns to Title. No second reward action occurs. Continue from `Complete` opens this completed end card, not Oliver’s reward sequence.

All pause, quit and skip operations persist the stable underlying checkpoint. No save contains a fade, line index, camera tween or render mode.

**Pacing**

Required:

- Entire spoken text appears immediately by default.
- Fresh E/Enter advances one page or beat.
- A separate visible Skip scene action skips the current sequence.
- Esc pauses; it never doubles as an undocumented skip.
- Quiet holds and movement animations can always be advanced.
- No auto-expiring spoken lines or timed choices.

Optional: typewriter text, gentle camera movement and longer scenic holds. If typewriter is added, the first advance reveals the current page; the next advances. No action requires holding a button.

---

**3. Smallest content-schema extension**

**What E0 v1 already supports**

- Multiple named speakers: adding `rin` is structurally supported.
- Ordered, stable dialogue line IDs and editable text.
- Intro and arrival completion actions.
- Chapter/reward identity and a paper-flower definition.
- Puzzle geometry, links, safe spawns and cleared branch position.
- Sprite strips, provenance, immutable snapshots and graph validation.
- Single-document transactions with stale-revision rejection.

**What it does not support**

The current validator explicitly allows only `intro` and `arrival` roles. It also lacks:

- Travel and obstacle dialogue.
- Nonverbal beats between lines.
- Stage composition, camera shots, actor positions/facing and expressions.
- Sound-cue references.
- Puzzle responses and hints required by M2 B2.
- End-card and notice text.
- Dialogue documents containing only visual beats.

These cannot be added as unchecked v1 fields: unknown fields and versions correctly fail today.

**Required proposal: chapter v2 and dialogue v2; retain scene v1, assets v1 and save v1**

Version documents individually. The approved graph may contain chapter/dialogue v2 with the unchanged puzzle scene and sprite manifest v1.

Chapter v2 retains all existing fields and IDs, adding:

1. Four additional closed dialogue roles: `travel`, `obstacle`, `return`, `end_card`.
2. A `strings` dictionary with a closed set of Chapter 1 presentation/response keys.

Add:

```json
"rin": {"name": "Rin", "species": "raccoon"}
```

Keep `passenger: "oliver"`.

New role references:

```json
{
  "travel": {
    "id": "oliver_travel",
    "path": "data/dialogue/oliver_travel.json"
  },
  "obstacle": {
    "id": "oliver_obstacle_reveal",
    "path": "data/dialogue/oliver_obstacle_reveal.json"
  },
  "return": {
    "id": "oliver_return",
    "path": "data/dialogue/oliver_return.json"
  },
  "end_card": {
    "id": "oliver_end_card",
    "path": "data/dialogue/oliver_end_card.json"
  }
}
```

Preserve document IDs `intro` and `arrival`, their paths, and the four existing line IDs. Preserve all puzzle/object/spawn/reward IDs and the legacy v0 file byte-for-byte.

**Dialogue v2**

Retain `lines`, `order` and one sequence-level `completion`. Add:

- `beats`: map of stable beat IDs.
- `beat_order`: explicit ordered beat IDs.
- Optional line `delivery`: `onscreen` or `offscreen`; default `onscreen`.

A beat has closed `kind`:

- `line`: references exactly one line.
- `stage`: a visual beat, optionally auto-advancing after a bounded presentation duration.
- `card`: displays one allowed chapter string, such as `end_card`.

Each beat contains a complete presentation snapshot rather than gameplay commands:

- `set`: `willow_platform`, `carriage`, `forest_travel`, `forest_obstacle`, `market_platform`, `flower_window`.
- `shot`: `wide`, `passenger_pair`, `old_platform`, `winch_branch`, `flower`, `supper_card`; validate compatible set/shot pairs.
- `actors`: speaker-ID map with integer `feet`, `facing`, `pose`, `emote`, and optional registered sprite asset.
- `props`: stable visual-prop IDs with integer position, closed kind/state and optional registered sprite asset.
- `cue`: one of `none`, `whistle_low`, `door_squeak`, `wheels`, `brake_soft`, `paper_rustle`, `whistle_depart`.

Use a small shared pose enum: `idle`, `walk`, `nod`, `point`, `reach`, `wave`, `carry`, `sit`, `look`, `board`, `fold`, `tap`, `dust_paws`. Expressions: `neutral`, `curious`, `smile`, `blink`, `ears_up`. Static poses are valid implementations.

For props, initially allow only the Chapter 1 needs: train, door, bag, flowerpot, paper flower, slat, bench, timetable, sign, notice and market dressing. Validate each kind’s allowed states—for example `flowerpot: bud|bloom`. These are visual states, never puzzle-state mutations.

`forest_obstacle` renders the actual loaded puzzle snapshot. It must not contain a second authored branch, winch or rope definition. Its `winch_branch` shot derives framing from the linked objects and clamps to the authored camera bounds.

Example complete travel document using built-in placeholders:

```json
{
  "kind": "dialogue",
  "schema_version": 2,
  "id": "oliver_travel",
  "order": ["travel_01"],
  "lines": {
    "travel_01": {
      "speaker": "oliver",
      "text": "They've been on the kitchen table all week. I thought they might enjoy meeting other flowers."
    }
  },
  "beat_order": ["travel_pot_line", "travel_pot_pause"],
  "beats": {
    "travel_pot_line": {
      "kind": "line",
      "line": "travel_01",
      "stage": {
        "set": "carriage",
        "shot": "passenger_pair",
        "actors": {
          "milo": {
            "feet": [108, 132],
            "facing": "right",
            "pose": "look",
            "emote": "curious"
          },
          "oliver": {
            "feet": [198, 132],
            "facing": "left",
            "pose": "sit",
            "emote": "neutral"
          }
        },
        "props": {
          "travel_flowerpot": {
            "kind": "flowerpot",
            "position": [224, 104],
            "state": "bud"
          }
        },
        "cue": "none"
      }
    },
    "travel_pot_pause": {
      "kind": "stage",
      "duration_ms": 1200,
      "stage": {
        "set": "carriage",
        "shot": "passenger_pair",
        "actors": {
          "milo": {
            "feet": [108, 132],
            "facing": "right",
            "pose": "look",
            "emote": "blink"
          },
          "oliver": {
            "feet": [198, 132],
            "facing": "left",
            "pose": "reach",
            "emote": "neutral"
          }
        },
        "props": {
          "travel_flowerpot": {
            "kind": "flowerpot",
            "position": [224, 104],
            "state": "bud"
          }
        },
        "cue": "none"
      }
    }
  },
  "completion": {
    "action": "enter_obstacle",
    "destination": "obstacle_arrival"
  }
}
```

Coordinates are illustrative staging values, not approved art placement.

There are **exactly six valid role/action/destination combinations**:

- `intro`: `board_oliver` → `train_travel`.
- `travel`: `enter_obstacle` → `obstacle_arrival`.
- `obstacle`: `begin_puzzle` → `puzzle`.
- `return`: `enter_arrival` → `station_outro`.
- `arrival`: `finish_oliver_journey` → `chapter_complete`.
- `end_card`: `show_title` → `title`.

`begin_puzzle` and `show_title` have no gameplay reward effects. Actions remain compiled Odin handlers, not executable content.

**Required B2 text**

Move the following authored strings into chapter v2. Existing `M2_Strings` names are retained where practical; key badges are rendered separately from prose.

```json
{
  "needs_handle": "It needs a handle.",
  "branch": "The rope leads to the winch.",
  "blocked": "The track is still blocked.",
  "turning": "It's turning.",
  "clear": "The track is clear.",
  "completion": "The branch is safely clear.",
  "snail": "The snail raises its feelers.",
  "pickup": "Pick up handle",
  "drop": "Put down handle",
  "install": "Install handle",
  "activate": "Start crank",
  "inspect_winch": "Inspect empty winch",
  "inspect_branch": "Inspect branch and rope",
  "return_train": "Return to train",
  "wave": "Wave to snail",
  "find_hint_gentle": "The rope leads from the branch to the winch.",
  "find_hint_shelter": "There may be something useful in the open tool shelter.",
  "find_hint": "Pick up the handle in the shelter and fit it into the winch.",
  "held_hint": "Carry the handle to the winch. Away from an object, you can put it down.",
  "dropped_hint": "Pick up the handle and carry it to the winch.",
  "installed_hint": "The handle is fitted. Press Interact once to start the winch.",
  "wait_hint": "The winch is working. Take your time.",
  "return_hint": "The track is clear. Return to Brass when you're ready.",
  "supper_card": "WILLOW CREEK PLATFORM SUPPER — ALL WELCOME",
  "end_card": "A little further down the line…",
  "advance": "Continue",
  "skip_scene": "Skip scene",
  "return_menu": "Return to menu"
}
```

These responses are UI/inspection text, not new spoken screenplay lines.

Hints derive from puzzle state. For the unfound handle, explicit H presses progress through gentle → shelter → direct. Other states immediately offer their relevant hint. Hint tier is transient and need not be saved. No inactivity timer is required.

**Validation rules**

Required:

- Keep E0 strict JSON, unknown-field rejection, bounded input, confined paths and graph hashing.
- Every line appears once in `order`; projecting line beats from `beat_order` must yield exactly `order`.
- Every beat appears exactly once in `beat_order`.
- Beat IDs are unique chapter-wide; actor/visual-prop identities are separate from puzzle-object identities.
- Only `return` and `end_card` may have no lines.
- Line beats reference existing speakers/lines; card beats reference allowed string keys.
- Actor positions use integer virtual pixels and bottom-centre anchors; stage actors never participate in collision.
- Poses, expressions, prop states, shots, cues and completion pairs use closed enums.
- Stage durations are integers from 0–5,000 ms. Zero waits for advance; positive values are skippable presentation durations. Spoken lines never expire.
- Supplied asset IDs must resolve. An omitted asset explicitly selects a placeholder; a broken reference does not.
- No beat can change checkpoints, award rewards, install handles, clear obstacles or execute expressions.
- Completion guards remain authoritative even after content validation.
- All strings must wrap/page without clipping at 320×180. Apply the existing bounded text limits and test Unicode punctuation.

**Migration and editor implications**

1. Implement v1/v2 loader support first; preserve existing v1 behavior through an in-memory presentation adapter.
2. Migrate Chapter 1 and its dialogue documents in one reviewed repository change. Multi-document migration is not an E0 atomic edit transaction.
3. Keep scene v1 and save v1 unchanged.
4. Update JSON schemas, shared validation and runtime types together.
5. Initially edit complete v2 beat structures using the existing validated `restore_document` transaction, with unchanged identity/version and graph-revision precondition. Extend its supported document-schema union accordingly.
6. Existing line edits still work, but reorder operations must update the line and beat orders coherently within one document transaction.
7. Runtime loading never rewrites old content or saves.

**Optional:** dedicated beat-edit operations, per-line saved resume, unrestricted camera paths, timeline tooling and presentation interpolation.

**Audio limitation:** assets v1 is sprite-only. Semantic cue IDs can exist now with silent/visual fallback. When real audio is imported, use a small assets-v2 tagged union, `sprite|sound`, with path/hash/provenance for both and sprite fields only for sprites. Do not pretend WAV files are sprite strips or introduce arbitrary audio paths into dialogue.

**Continuity flags:** none required for Chapter 1. Supper cards are fixed scenery; paper-flower visibility after completion derives from ownership. A future campaign save can add explicit passenger/keepsake state when later chapters are authorized.

---

**4. M3 runtime design**

The current working tree contains M2 integration work, not a story loop. In particular:

- [save.odin](/Users/finngilbert/Documents/The%20Last%20Stop/Game/src/save.odin:204) currently bypasses intro/travel for M2.
- [game.odin](/Users/finngilbert/Documents/The%20Last%20Stop/Game/src/game.odin:134) resumes pause directly to `Playing`.
- [puzzle.odin](/Users/finngilbert/Documents/The%20Last%20Stop/Game/src/puzzle.odin:210) already contains the guarded journey transitions and derived paper-flower ownership.
- [hints.odin](/Users/finngilbert/Documents/The%20Last%20Stop/Game/src/hints.odin:3) explicitly records the unresolved B2 content-schema dependency.

These are integration points, not defects claimed against unfinished M3.

**Required state model**

Extend modes without changing durable checkpoints:

```odin
Story_Role :: enum {
    Intro, Travel, Obstacle, Return, Arrival, End_Card,
}

Story_Finish_Reason :: enum { Normal, Skip }

Story_Player :: struct {
    role:          Story_Role,
    beat_index:    int,
    page_index:    int,
    elapsed:       f32,
    finished:      bool,
    input_latched: bool,
}

// Add to Game_State:
// story: Story_Player
// pause_return_mode: GameMode
```

Add modes corresponding to `Station_Intro`, `Train_Travel`, `Obstacle_Arrival`, `Train_Travel_Resume`, `Station_Outro`, `Chapter_Complete`. Keep existing `Playing` for the puzzle.

Suggested interfaces, to compile against the actual project types:

```odin
story_begin         :: proc(g: ^Game_State, role: Story_Role)
story_update        :: proc(g: ^Game_State, input: Input, dt: f32)
story_advance       :: proc(g: ^Game_State)
story_finish        :: proc(g: ^Game_State, reason: Story_Finish_Reason)
story_apply_stage   :: proc(g: ^Game_State, beat: ^Story_Beat_Def)
story_draw          :: proc(g: ^Game_State)
resume_checkpoint   :: proc(g: ^Game_State)
```

`Story_Beat_Def` belongs to the validated content model. `Story_Player` contains only transient playback state. No renderer-owned pointer, texture or sound belongs in saves.

**Completion and skip**

`story_finish` must:

1. Return immediately if the sequence already finished.
2. Check the expected current role/checkpoint and required puzzle state.
3. Mark the sequence finished.
4. Invoke the one allowed completion handler.
5. Persist the resulting stable checkpoint.
6. Begin the appropriate next presentation/mode with input blocked until release.

Normal and skip routes use this same function. Skip does not loop through all remaining beats, play their sounds or execute synthetic interactions.

Applying a stage is presentation-only. Drawing never calls transition or reward procedures.

On arrival skip, render the end card’s flower from `Complete`; do not depend on having run the paper-fold animation.

**Checkpoint restoration**

- `Chapter_Start` → restart station introduction.
- `Boarded` → restart outbound travel.
- `Puzzle` → restore normalized puzzle directly, including automatic crank restart if applicable.
- `Returned` → restart return travel; no clearance cue.
- `Arrival` → restart market farewell, reward still pending.
- `Complete` → completed end card, flower already owned.

Loading itself does not award anything or emit completion cues.

For failed saves, retain the existing visible error/dirty-state behavior. Do not call progress durable until the write succeeds. A retry serializes current state; it does not rerun a reward event.

**Input, pause and text box**

Required:

- One input edge causes one action, including when E and Enter are pressed together.
- Drain gameplay/dialogue edges on transitions; held input must not advance the next scene.
- Pause stores the exact underlying mode; Resume returns there without calling `story_begin`.
- Freeze story timers and automatic travel while paused.
- Preserve page/beat position during an in-process pause. Quit/reload uses the checkpoint policy above.
- Text box uses speaker name plus wrapped text, outside the world camera.
- Long lines paginate without altering the stored string or line ID.
- The supper-card text must be available in legible UI; miniature baked lettering alone is insufficient.
- Support the ellipsis and em dash in the actual selected font.
- Window close, quit-to-title and normal exit use the same save path.

**Automatic travel and obstacle reveal**

Travel is a visual animation, not locomotive physics. No train speed, collision simulation, timetable clock or passenger patience is needed.

Outbound completion enters the obstacle sequence only. It writes `Puzzle` and leaves the branch blocked. The reveal temporarily owns camera/input; finishing it restores the normal puzzle camera and fresh-input gate.

After return, travel requires `Installed + Cleared`. No story action can manufacture those conditions.

**Required tests**

Automated:

1. Advance and skip at every beat/page in all six roles; compare final durable state.
2. Fresh-process reload at all six checkpoints, including every existing puzzle state.
3. Arrival finish/skip called repeatedly: one derived flower, no duplicated reward cue.
4. Save/quit immediately before and after arrival completion.
5. Travel skip and obstacle skip cannot reach arrival with an uncleared branch.
6. Simultaneous/held advance, skip and pause inputs cause at most one transition.
7. Pause/resume from every story mode preserves the current beat/page and freezes timers.
8. Reloading cleared/complete state emits no clearance or reward cue.
9. Intro first-line split, all 15 exact lines, line/beat ordering and speaker resolution.
10. Missing/duplicate beats, invalid completion pairs, unknown cues/poses, dangling assets and malformed text fail validation.
11. Existing save v1 fixtures remain readable; authored data and normal saves remain untouched by preview tests.
12. Failed save retries do not replay story side effects.
13. Editing a dialogue string produces the edited text in the actual runtime, preserving skip semantics.

Native/manual:

- Watched and fully skipped title-to-end runs.
- Readable longest line and supper card at minimum supported window size.
- Visible stop before branch, handle installation, branch clearance and paper-flower ending.
- Real quit/relaunch during intro, crank and farewell.
- Fresh-player puzzle completion without external explanation.

These checks are proposed, not run in this consultation.

---

**5. Later chapters: constraints to anticipate, not implement**

**Hazel**

Her puzzle contains two independently reversible states before departure: leaf blockage and sluice position. Setting the sluice first must work once leaves are removed.

Do not generalize Oliver’s monotonic `Blocked → Cranking → Cleared` state machine into a universal puzzle engine. Later puzzle state should be a chapter-specific tagged payload. Include room for a second staged speaker, Hazel’s sister, without making every speaker a passenger.

**Felix and Hugo**

The tunnel chapter boards two passengers and awards an opened invitation during a conversation before the final homecoming. Avoid spreading assumptions that “chapter completion always disembarks the only passenger” or “every keepsake is awarded at a destination platform.”

Reuse safe carrying principles, but keep the basket’s state separate from Oliver’s handle. No basket code or data belongs in Chapter 1.

**Pip and Elara**

Two newcomers share the carriage with Felix and Hugo. Stage actors must be keyed by identity rather than fixed “player + one passenger” slots.

Later mirror state is discrete position and angle, with a readable beam and symbols. Do not build free-angle optics now. Background walkers are staged imagery, not simulated NPC journeys.

There is no screenplay requirement for a fourth keepsake. A future chapter contract must allow no reward.

**Finale**

The lever reuses the learned install/press interaction, but does not reuse Oliver’s unique handle instance or save fields. Distinct object IDs are essential.

Clarify the screenplay’s broad “Skipping the finale…” wording before that chapter is built:

> Skipping the final gathering completes the ending and bypasses the optional epilogue. Skipping the approach dialogue does not solve the playable siding puzzle.

This resolves the conflict with “no cutscene skip auto-solves a playable puzzle.”

A future campaign checkpoint must distinguish completed ending from the optional gathering epilogue. Continue-after-ending returning to that epilogue is different from the slice’s Continue-to-end-card policy.

**Potential rework if ignored now**

- Hardcoded two-character scene rendering.
- Reward or passenger changes hidden inside line playback.
- Treating every chapter as one passenger who disembarks.
- Treating every chapter as exactly one reward.
- Reusing puzzle object identities across chapters.
- Serializing transient beat indices as progression authority.
- Baking Milo’s backpack permanently into every future performance pose.

No campaign schema, extra chapter JSON, additional puzzle handler or finale scene is required now.

---

**6. Chapter 1 dependencies for the art/audio agent**

**Required for representative story presentation; placeholders acceptable during M3**

- **Milo:** ginger cat, red scarf, backpack; idle/walk plus readable nod, point, reach/catch, wave, carry/interact and petal-tap poses. Cranking must not require locking the player to an animation.
- **Oliver:** scarf, bag/strap and paper-wrapped flowerpot; caught-ear staging, carrying/boarding, seated/window pose, looking down at pot, showing bloom and folding/placing paper flower.
- **Rin:** tool satchel, loose-slat holding/resting and wave. Rin is required by the supplied opening even though the draft plan’s minimum-art list omits her.
- **Brass:** locomotive/carriage silhouette, amber windows, readable boarding door and whistle/steam cue.
- **Willow Creek:** main platform, bench and loose slat, timetable, distinct view of the unused second platform and faded The Last Stop sign. No playable siding apparatus.
- **Travel/interior:** forest movement composition and carriage seating/windowsill; a visible supper-card position.
- **Puzzle:** branch, rope, empty/fitted winch, unique handle, open shelter/low shelf, supported cleared-branch recess and readable return door.
- **Market:** flower stall, awning, flowers and supper notice with Rin portrait. A deliberately dressed crop of station art is acceptable; the untouched Willow Creek background is not a finished market.
- **Flower states:** closed bud, opened flower, spare wrapping paper and crooked paper-flower keepsake. Keep the keepsake separate from the background.
- **UI/font:** speaker labels, long-line pagination, controls and notice/end-card glyph coverage.
- **Snail:** small original snail/leaf composition and feeler/wave response. Optional for the player, but still part of the existing slice content brief.

**Optional polish**

Dedicated seated sheets, full ear-release/flower-fold animation, smooth petal spring, dusting-paws animation, layered parallax, leaf motion, animated wheels and bespoke market background. Required visual meanings may initially use two or three still poses.

**Audio dependency**

Original/licensed wheel rhythm, low/departure whistle, two-note clearance cue, door, pickup/install, crank, branch settle and paper rustle. Music and layered ambience can follow. No audio files are established by the supplied pack.

**Asset integration constraints**

The README reports 96×96 character frames with pivot `(48,88)`, six 640×360 flattened backgrounds, mirrored left views, and idle/walk/run/jump cycles. It does not supply the required acting poses, collision maps, seamless scenery or working native integration.

The art agent must:

- Establish readable scale at the actual 320×180 canvas.
- Check mirrored backpack/strap consistency.
- Supply separate layers where a character sits behind carriage furniture.
- Convert imported frames to the supported sprite-strip format or propose a separately reviewed extension.
- Register imported files and provenance under project `assets/`; do not reference the external pack by absolute path.
- Keep generated-art provenance distinct from a claim that every frame has been visually verified.

---

**Proposed central documentation update**

Opus can apply the following after accepting or amending this proposal.

**E0_CONTRACT.md — append:**

> T-STORY-1 proposes chapter/dialogue schema v2 for Chapter 1 presentation. Existing scene/assets v1 and save v1 remain valid. Dialogue gains ordered visual/line/card beats with closed presentation enums and one guarded sequence completion. Individual beats cannot mutate gameplay state. The six role/action/destination pairs and migration requirements are specified in the accepted T-STORY-1 handoff. This addendum does not mark v2 implemented.

**M2_CONTRACT.md — append:**

> M3 retains the six Journey_Checkpoint values and save v1. Outbound travel writes Puzzle on obstacle-reveal entry; loading Puzzle resumes directly into normalized puzzle control. Arrival stages the paper flower visually but grants ownership only through finish_oliver_journey. Complete derives exactly one paper_flower. Supper notices are authored scenery, not saved flags. B2 responses and hints move into validated chapter content.

**TECHNICAL_DESIGN.md — replace stale state/persistence descriptions:**

> Puzzle state follows M2_CONTRACT.md: one handle-location enum, one puzzle-phase enum and optional snail state. Story playback uses transient beat/page state over immutable content. Saves persist Journey_Checkpoint and puzzle state; they do not persist render modes, presentation timers or duplicated passenger/reward booleans. Pause resumes the exact underlying mode. Normal scene completion and skipping invoke the same guarded completion handler.

**TASK_BOARD.md — add under M3, unchecked:**

> - [ ] Adopt Chapter 1 screenplay reconciliation and exact dialogue ledger.  
> - [ ] Implement validated presentation content and B2 response/hint strings.  
> - [ ] Present Rin/Oliver opening, travel conversation and obstacle reveal.  
> - [ ] Integrate return travel, market farewell, exactly-once flower and end card.  
> - [ ] Verify advance/skip/pause/reload convergence across every story boundary.

**BUILD_NOTES.md / ORCHESTRATION_LOG.md:**

> T-STORY-1 — GPT-6 Astra, read-only design consultation at 977efc467429097411129a49b19f4af932a75520. Read full screenplay/HTML, story plan, required project references, content schemas/data and relevant in-progress runtime. Delivered reconciliation, 15-line slice ledger, checkpoint mapping, minimal presentation-schema proposal, M3 design, future compatibility constraints and art dependencies. No files changed, tests/builds launched or commits produced. Implementation and native acceptance remain unverified.

**Verification run:**

- `git rev-parse HEAD` — exit 0; requested base confirmed.
- `git status --short` — exit 0; existing concurrent changes observed and left untouched.
- `cat`, `sed`, `rg` and Python HTML extraction — exit 0 for completed reads.
- Read-only `python3 -B` content inspection — exit 0:
  - Parsed all 11 JSON documents under `data/`.
  - Extracted 15 slice spoken lines.
  - Confirmed all 15 appear in the HTML render.
  - Confirmed the existing combined `intro_01` is not a verbatim individual screenplay line; the other three existing dialogue strings are retained.
- Memory lookup found no relevant entry; no memory-derived project claims used.

Parsing JSON is not schema or runtime validation.

**Acceptance criteria:**

- **PASS — design:** reconciliation and exact proposed document/data text.
- **PASS — design:** complete slice dialogue, stable IDs, modes and checkpoint boundaries.
- **PASS — design:** bounded schema extension, migration and validation requirements.
- **PASS — design:** M3 state/input/save design and test plan.
- **PASS — design:** later-chapter compatibility constraints without implementation.
- **PASS — design:** required/optional asset dependencies.
- **PASS — read-only scope:** no modifications, staging, commits or delegation.
- **UNVERIFIED:** Opus acceptance, implementation, compilation, schema tests, native play and asset readability.

**Bugs/risks:** No executed runtime defect reproduction. Principal integration risks are schema drift, current pause behavior assuming `Playing`, M2’s deliberate story bypass, premature reward effects, and art that fails at internal resolution.

**Next task / dependencies:** Opus accepts the canonical/adaptation choices and freezes the shared v2 contract; then assign bounded content/loader and M3 runtime work with explicit shared-file ownership. Keep later chapters unimplemented.
