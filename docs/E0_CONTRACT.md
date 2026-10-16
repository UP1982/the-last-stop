# E0 content contract (accepted by Opus 2026-10-16)

Source: T-E0-A, GPT-6 Astra, read-only consultation at eb04e66. Accepted as written with these Opus amendments:

- A1. Player footprint 12x16 bottom-centre is accepted provisionally; M1 must confirm or propose a change before reachability checks are frozen.
- A2. E0 is split: **E0a** (shared/content, shared/content_edit, tools/content, data/ migration+schemas, tests/editor) may proceed while M0 awaits its human keyboard check because it does not touch src/. **E0b** (src/content_adapter.odin, DEV_TOOLS preview, native round-trip gate) starts only after M0 is accepted.
- A3. Dialogue text verified identical to docs/CHAPTER_01.md.
- A4. Web host (editor/server.py, editor/web/) is E1 work, not E0.

---

**Task / model / checkout / base:**  
T-E0-A / GPT-6 Astra / `/Users/finngilbert/Documents/The Last Stop/The_Last_Stop_Odin_Raylib_Kit` / `eb04e66408da8af74d1805b048ea8f152329e2a5`, branch `main`.

**Completed:**  
Read the shared context, mandatory references, editor prompt, existing manifest, and all five live Odin source files. Inspected the installed Odin JSON, filesystem, SHA-256, and POSIX locking APIs.

The following is my proposed E0 contract for Opus to accept and Sol to implement. It does **not** mark E0 implemented or accepted.

**1. Editor host decision**

Choose **a separate local web editor**, using:

- Static HTML/CSS/browser JavaScript in `editor/web/`.
- A small Python 3 standard-library development server in `editor/server.py`.
- A compiled Odin content CLI for authoritative inspection, validation, and authored-content writes.
- The actual Odin+raylib executable for native previews.
- A development-only overlay inside that executable for E2.

The web viewport is an **authoring approximation**, explicitly labeled as such. It may draw bounds, sprites, and selection handles; it must not simulate the puzzle or claim gameplay verification.

Rationale: the requested text editing, dialogue forms, project tree, diffs, and diagnostics fit browser controls without requiring a custom text editor in raylib. Keeping the in-game overlay small preserves the native renderer as the gameplay authority. Python is transport and process-launch plumbing; it contains no content validation or puzzle rules.

Environment evidence affects the choice: Python **3.9.6** and the required standard-library imports work. The installed Node executable aborts because `libsimdjson.29.dylib` is missing. Do not make E0 depend on repairing Node, npm, Electron, or adding a UI build system.

Required bridge boundaries:

- Bind to `127.0.0.1` on an allocated port.
- Require a per-launch token for API access; validate Host and Origin; disable permissive CORS.
- Use fixed command identifiers and argument arrays, never shell interpolation.
- Content writes go through the Odin CLI. Source writes, introduced in E3, use a separate restricted source-file endpoint.
- Pin the canonical project root at launch; reject traversal and symlink escapes.
- T3 remains the authentication/delegation system. Studio only displays actual task evidence.

Optional later: a packaged desktop wrapper, richer source editor, or TypeScript build pipeline. None is an E0 dependency.

**2. Authored-content layout and identity**

Use ordinary, versioned JSON files:

```text
data/
  chapters/chapter_01.json
  scenes/oliver_obstacle.json
  dialogue/oliver_intro.json
  dialogue/oliver_arrival.json
  assets/manifest.json
  schemas/
    chapter.v1.schema.json
    scene.v1.schema.json
    dialogue.v1.schema.json
    assets.v1.schema.json
    edit.v1.schema.json
  legacy/chapter_01.v0.json
```

Every active document has `kind`, integer `schema_version: 1`, and `id`. The legacy document is preserved reference material and excluded from runtime discovery.

Keep these separate:

```text
.studio/                         # gitignored editor state, drafts, history, lock
build/                           # generated tools/game/logs
~/Library/Application Support/The Last Stop/saves/
~/Library/Caches/The Last Stop/preview/<session-id>/
```

Player saves get their own `save_version`. Neither content schema versions nor editor revisions are save versions.

Required identity/reference rules:

- IDs match `[a-z][a-z0-9_]{0,63}` and are case-sensitive.
- IDs survive movement, reordering, text changes, and display-name changes.
- Document IDs are unique within the chapter graph. Object IDs, spawn IDs, and line IDs are unique within their respective chapter-wide namespaces.
- Map keys are the identity; do not repeat a second potentially inconsistent `id` inside each map value.
- Ordered content uses an explicit ID array, never map iteration order.
- Duplicate creates require an explicit fresh ID. E0 has no implicit rename or reference-repair operation.
- Document references contain both `id` and project-relative `path`; the loaded ID and expected kind must match.
- Object links resolve within the named scene and must have the required object kind.
- Missing references, wrong-kind references, and deletion of required/referenced records fail validation.
- Paths use `/`, remain beneath the expected `data/` or `assets/` subtree, and cannot be absolute, contain `..`, or escape through symlinks.
- Unknown fields are errors. This avoids silently discarding future fields during edits.

All authored geometry uses **integer virtual pixels**. Origin is top-left; +x right, +y down. Runtime movement may use floating point. Drawing rounds independently.

Object positions are world-space top-left coordinates. Object collision and interaction rectangles are local offsets. Spawn markers specify their anchor explicitly. World and camera bounds use world-space rectangles. No authored rotation or scaling in v1.

Example replacement chapter:

```json
{
  "kind": "chapter",
  "schema_version": 1,
  "id": "oliver_flower_market",
  "title": "Oliver and the Flower Market",
  "speakers": {
    "milo": {"name": "Milo", "species": "cat"},
    "oliver": {"name": "Oliver", "species": "rabbit"}
  },
  "passenger": "oliver",
  "destination": "Clover Market",
  "keepsakes": {
    "paper_flower": {"name": "Paper flower"}
  },
  "reward": "paper_flower",
  "assets": {
    "id": "chapter_01_assets",
    "path": "data/assets/manifest.json"
  },
  "scenes": [
    {
      "id": "oliver_obstacle",
      "path": "data/scenes/oliver_obstacle.json"
    }
  ],
  "puzzle_scene": "oliver_obstacle",
  "dialogues": {
    "intro": {
      "id": "intro",
      "path": "data/dialogue/oliver_intro.json"
    },
    "arrival": {
      "id": "arrival",
      "path": "data/dialogue/oliver_arrival.json"
    }
  }
}
```

Dialogue documents contain ordered lines and a **closed completion action**, not executable expressions:

```json
{
  "kind": "dialogue",
  "schema_version": 1,
  "id": "intro",
  "order": ["intro_01", "intro_02"],
  "lines": {
    "intro_01": {
      "speaker": "oliver",
      "text": "Excuse me! Does this one go to Clover Market?"
    },
    "intro_02": {
      "speaker": "oliver",
      "text": "Oh, good. My flowers are beginning to think I made it up."
    }
  },
  "completion": {
    "action": "board_oliver",
    "destination": "train_travel"
  }
}
```

```json
{
  "kind": "dialogue",
  "schema_version": 1,
  "id": "arrival",
  "order": ["arrival_01", "arrival_02"],
  "lines": {
    "arrival_01": {
      "speaker": "oliver",
      "text": "I was worried they wouldn't bloom in time."
    },
    "arrival_02": {
      "speaker": "oliver",
      "text": "I suppose they just needed a little trip."
    }
  },
  "completion": {
    "action": "finish_oliver_journey",
    "destination": "chapter_complete"
  }
}
```

For v1, those two action/destination pairs are the only valid combinations, constrained to their chapter roles. Both normal completion and skipping call the same idempotent Odin transition. `finish_oliver_journey` grants the chapter’s declared reward once. Individual dialogue lines cannot award rewards or execute actions.

The manifest can initially be:

```json
{
  "kind": "assets",
  "schema_version": 1,
  "id": "chapter_01_assets",
  "assets": {}
}
```

An omitted object asset means an intentional built-in placeholder. A supplied but unresolved asset ID is an error.

For v1 sprite entries, define: project-relative `path`, `sha256`, `frame_size`, positive `frame_count`, integer `pivot`, and `provenance` containing creator, source, license, and attribution strings. Use a single horizontal strip initially. Do not add an atlas packer or animation graph. E0 can ship with the empty manifest; asset-browser UI belongs to E3.

**Explicit migration of `chapter_01.json`:**

1. Copy its exact original bytes to `data/legacy/chapter_01.v0.json`.
2. Preserve `oliver_flower_market`, `oliver`, `fallen_branch`, `paper_flower`, and the existing `intro`/`arrival` identities.
3. Move the four dialogue strings verbatim into the two dialogue documents above.
4. Preserve the puzzle identifier `install_crank_handle`.
5. Map `snail_waves` to the optional snail interaction implemented in Odin.
6. Treat legacy interaction names as documented mappings to compiled handlers—not content scripts.
7. Retire the illustrative `flags` list. It is not saved progress and must not become three contradictory runtime booleans.
8. Create and validate the new referenced documents before replacing the chapter root.
9. Deliver this as one reviewed repository migration, with the original bytes retained.

Runtime loading never automatically migrates or rewrites authored files. A versionless legacy root produces `migration_required`; an unsupported version produces `unsupported_version`.

**3. Minimal M2 scene contract**

This is a concrete initial graybox, not a claim that the layout has been playtested:

```json
{
  "kind": "scene",
  "schema_version": 1,
  "id": "oliver_obstacle",
  "scene_type": "oliver_puzzle",
  "world_bounds": [0, 0, 640, 180],
  "camera_bounds": [0, 0, 640, 180],
  "ground": [0, 144, 640, 36],
  "spawns": {
    "puzzle_entry": {
      "kind": "player_feet",
      "position": [140, 144]
    },
    "train_return": {
      "kind": "player_feet",
      "position": [140, 144]
    },
    "handle_recovery": {
      "kind": "handle_bottom_center",
      "position": [592, 144]
    }
  },
  "objects": {
    "brass": {
      "kind": "train",
      "position": [16, 112],
      "size": [96, 32],
      "layer": "world",
      "interaction": [88, -8, 48, 40]
    },
    "fallen_branch": {
      "kind": "branch",
      "position": [96, 120],
      "size": [48, 24],
      "layer": "world",
      "interaction": [-8, -8, 64, 32]
    },
    "winch": {
      "kind": "winch",
      "position": [224, 120],
      "size": [24, 24],
      "layer": "world",
      "interaction": [-16, -8, 56, 40]
    },
    "snail": {
      "kind": "snail",
      "position": [400, 136],
      "size": [12, 8],
      "layer": "world",
      "interaction": [-12, -16, 36, 32]
    },
    "shed": {
      "kind": "shed",
      "position": [552, 96],
      "size": [72, 48],
      "layer": "background"
    },
    "crank_handle": {
      "kind": "handle",
      "position": [588, 128],
      "size": [8, 8],
      "layer": "world",
      "interaction": [-16, -8, 40, 32]
    }
  },
  "puzzle": {
    "kind": "install_crank_handle",
    "train": "brass",
    "branch": "fallen_branch",
    "winch": "winch",
    "shed": "shed",
    "handle": "crank_handle",
    "snail": "snail",
    "player_spawn": "puzzle_entry",
    "return_spawn": "train_return",
    "handle_recovery_spawn": "handle_recovery",
    "winch_socket": [12, 10],
    "winch_rope_anchor": [4, 4],
    "branch_rope_anchor": [24, 4],
    "branch_cleared_position": [96, 88]
  }
}
```

Rectangles are `[x,y,width,height]`; pairs are `[x,y]`. Socket and rope anchors are local to their respective objects; the cleared branch position is world-space.

Required M2 invariants:

- Exactly one linked handle, winch, branch, shed, and train.
- Snail is optional; its interaction never gates completion.
- A continuous ground corridor keeps all required interactions reachable without jumping. The shed is unlocked and non-solid.
- Ground is the initial collision surface. Props above have no collision. If optional object collision rectangles are supported, reject placements that obstruct the required walking corridor.
- Freeze the initial player collision footprint at **12×16 virtual pixels**, bottom-center anchored, or agree on a replacement with M1 before integration. Loader safety checks and movement must use the same dimensions.
- Player spawns and handle recovery are supported, unobstructed, and inside bounds.
- Camera bounds contain a 320×180 view. They describe allowable visible world extents: the camera origin clamps to `[x, x+w-320]` and `[y, y+h-180]`.
- Numeric geometry is bounded, for example to ±16,384 pixels; widths/heights are positive and checked before arithmetic.
- Layer order is `background`, `world`, `foreground`; ties sort by stable ID.
- Crank activation is **press once to start**. No hold/mash configuration is needed.

Authored defaults must remain immutable during gameplay. M2 runtime state uses a handle-location enum:

```odin
Handle_Location :: enum { Shelf, Held, Dropped, Installed }
```

Dropped position, crank progress/checkpoint, branch completion, and snail interaction belong to runtime/save state. Loading invalid dropped positions recovers the same unique handle at `handle_recovery`. Installing or moving the runtime handle never edits `crank_handle.position`.

**4. Shared Odin loader and validation**

Create a raylib-free package at `shared/content/`. Both `src/` and `tools/content/` import it. Use a separate `shared/content_edit/` package for mutation and persistence; release gameplay does not import it.

The following are proposed public interfaces, not compiled implementation:

```odin
// shared/content
package content

import "core:mem"

ID       :: distinct string
Revision :: [32]u8

Vec2i :: [2]i32
Recti :: struct { x, y, w, h: i32 }

Object_Kind :: enum { Train, Branch, Winch, Shed, Handle, Snail }
Layer       :: enum { Background, World, Foreground }
Spawn_Kind  :: enum { Player_Feet, Handle_Bottom_Center }

Object_Def :: struct {
    id:              ID,
    kind:            Object_Kind,
    position:        Vec2i,
    size:            Vec2i,
    layer:           Layer,
    has_collision:   bool,
    collision:       Recti,
    has_interaction: bool,
    interaction:     Recti,
    has_asset:       bool,
    asset:           ID,
}

Spawn_Def :: struct {
    id:       ID,
    kind:     Spawn_Kind,
    position: Vec2i,
}

Severity :: enum { Error, Warning }

Diagnostic :: struct {
    severity:   Severity,
    code:       string,
    file:       string, // project-relative
    pointer:    string, // JSON Pointer
    subject_id: string,
    message:    string,
    line:       int,    // 1-based; 0 when unavailable
    column:     int,    // 1-based; 0 when unavailable
    op_index:   int,    // -1 when unrelated to an operation
}

Document_Source :: struct {
    path:     string,
    bytes:    []u8,
    revision: Revision,
}

// Snapshot owns the complete validated graph and its allocations.
// Chapter_Def, Scene_Def, Dialogue_Def and Asset_Def mirror the v1 contract.

Load_Result :: struct {
    snapshot:    ^Snapshot, // nil on any error
    diagnostics: []Diagnostic,
}

load_chapter :: proc(
    project_root, chapter_path: string,
    allocator: mem.Allocator,
) -> Load_Result

validate_sources :: proc(
    sources: []Document_Source,
    chapter_path: string,
    allocator: mem.Allocator,
) -> Load_Result

find_scene :: proc(
    snapshot: ^Snapshot,
    scene_id: ID,
) -> (scene: ^Scene_Def, ok: bool)

destroy_load_result :: proc(result: ^Load_Result)
destroy_snapshot :: proc(snapshot: ^Snapshot)
```

Ownership contract: a successful result owns its snapshot until explicitly transferred to the runtime; all returned strings/maps live with that snapshot. Failure owns only diagnostics. Destruction procedures must document and implement transfer/clearing so callers cannot double-free. No snapshot memory comes from a per-frame temporary allocator.

Required load sequence:

1. Bound input sizes/depth/counts before unbounded allocation.
2. Validate UTF-8 and strict JSON syntax, including the entire input.
3. Check document envelope/version before interpreting its body.
4. Check required/allowed keys and exact value types.
5. Decode into isolated candidate structures.
6. Resolve the entire chapter graph and validate semantic invariants.
7. Confirm dependency bytes did not change while reading.
8. Return one complete immutable snapshot, or no snapshot.

At startup, bad content produces clear diagnostics and prevents starting the chapter. During an explicit development reload, bad content leaves the current validated snapshot active. Disk bytes remain untouched. Do not silently substitute default content or start a partially loaded chapter.

Runtime texture/resource creation is a second staging step: load all required resources successfully before swapping the content/resources pair.

Important installed-library findings:

- `core:encoding/json` defaults to **JSON5**. Pass `.JSON` explicitly.
- `json.parse` produces `json.Value`; object parsing rejects duplicate keys.
- `json.is_valid` explicitly does **not** check duplicate keys.
- Typed `json.unmarshal` skips unknown struct fields.
- The convenience parse/validate entry points return after the first value; E0 must require EOF.
- The inspected comma loop also requires a regression test for strict rejection of trailing commas.
- Numeric conversion in `parse_value` discards conversion success flags. Validate numeric token range before trusting the decoded integer.

Consequently, use a small **strict token-validation adapter** over the installed tokenizer, followed by DOM parsing and typed schema checks. It must check token errors, JSON number grammar/range, delimiter sequencing, trailing commas, duplicate keys, and complete input consumption. This is a bounded JSON adapter, not a new language.

Keep JSON Schema files synchronized with the authoritative Odin checks. UI schema validation is supplementary.

**5. Inspection and transactional edits**

Use a separate executable:

```sh
odin build tools/content -out:build/tls-content

build/tls-content validate-content --project-root "$PROJECT_ROOT"
build/tls-content inspect-scene --project-root "$PROJECT_ROOT" --scene oliver_obstacle
build/tls-content apply-edit --project-root "$PROJECT_ROOT" --request edit.json
```

`inspect-scene` returns protocol version, chapter/document IDs, document path, graph revision, document revisions, normalized authored values, resolved links, editable fields, and diagnostics. It does not include mutable gameplay state.

A request targets **one document** and contains an atomic batch:

```json
{
  "protocol_version": 1,
  "request_id": "move_handle_001",
  "chapter": "oliver_flower_market",
  "document": "oliver_obstacle",
  "expected_revision": "sha256:<64 lowercase hex digits>",
  "operations": [
    {
      "op": "set_property",
      "collection": "objects",
      "id": "crank_handle",
      "property": "position",
      "value": [596, 128]
    },
    {
      "op": "set_property",
      "collection": "objects",
      "id": "crank_handle",
      "property": "interaction",
      "value": [-20, -8, 48, 32]
    }
  ]
}
```

The revision is the **chapter graph revision**, so edits to another referenced document also invalidate the request. Compute it from sorted project-relative dependency paths and exact-byte SHA-256 digests, using unambiguous length-prefixed encoding. Include referenced asset bytes when assets exist. Do not use mtimes or an independently updated revision counter.

Required operations:

- `create`: collection, fresh ID, complete record.
- `delete`: collection and ID.
- `set_property`: stable ID plus an allowlisted property.
- `link_object`: allowlisted puzzle role and target ID.
- `update_dialogue`: line ID plus allowed speaker/text fields.
- `set_order`: complete ordered line-ID list.
- `restore_document`: validated whole-document replacement for undo/recovery, with unchanged document identity/version and the same revision precondition.

No arbitrary JSON Pointer mutation, executable code, ID assignment, or path mutation through `set_property`. Validation runs after the whole batch, allowing a line create and order update in one transaction.

**E0 deliberately rejects multi-document edit batches before writing anything.** Scene edits and dialogue edits are separate requests. Creating/removing linked documents and coordinated schema migrations remain reviewed repository operations. This avoids claiming that several filesystem renames are one atomic transaction.

Proposed mutation API:

```odin
// shared/content_edit
package content_edit

import "../content"
import "core:mem"

Commit_State :: enum {
    Not_Committed,
    Committed,
    Committed_Durability_Uncertain,
}

Edit_Result :: struct {
    state:            Commit_State,
    old_revision:     content.Revision,
    new_revision:     content.Revision,
    changed_document: string,
    undo_token:       string,
    diagnostics:     []content.Diagnostic,
}

// Edit_Request is the strictly decoded protocol-v1 envelope.
// Prepared_Edit owns the validated candidate and inverse/before-image data.

prepare_edit :: proc(
    snapshot: ^content.Snapshot,
    request: Edit_Request,
    allocator: mem.Allocator,
) -> (prepared: ^Prepared_Edit, diagnostics: []content.Diagnostic)

apply_edit :: proc(
    project_root: string,
    request: Edit_Request,
    allocator: mem.Allocator,
) -> Edit_Result
```

Required commit procedure:

1. Acquire a project-wide lock on a permanent `.studio/content.lock` file.
2. Re-read the chapter graph under the lock and compare the expected revision.
3. Apply all operations to a candidate; validate the complete resulting graph.
4. Serialize deterministically: strict JSON, two spaces, sorted map keys, meaningful array order, one trailing newline.
5. Reparse/revalidate the serialized candidate.
6. Persist a before-image and prepared transaction record under `.studio/history/`; stop if this fails.
7. Create an exclusive temporary file **in the destination directory**.
8. Write all bytes, checking short writes; sync and close successfully.
9. Recheck dependency hashes immediately before replacement.
10. Rename the temporary file over the destination. **This is the commit point.**
11. Sync the parent directory where supported, finalize history, release the lock, and return the new revision.

Installed APIs supporting this:

```odin
os.read_entire_file(path, allocator) -> ([]byte, os.Error)
os.create_temp_file(dir, pattern, additional_flags) -> (^os.File, os.Error)
os.write(file, bytes) -> (int, os.Error)
os.sync(file) -> os.Error
os.close(file) -> os.Error
os.rename(old_path, new_path) -> os.Error
```

Also available: `os.fd`, `os.name`, `os.args`, `core:crypto/sha2`, and Darwin `core:sys/posix.fcntl` locking.

Use a POSIX `F_SETLK` write lock for CLI writers. Keep its descriptor open until completion; never unlink/replace the lock file. A busy lock returns a retryable diagnostic. Process termination releases the kernel lock.

`os.flush` is **not** a substitute for `os.sync`; the installed implementation can return `Unsupported` for ordinary files.

Failure semantics:

- Before rename: old authored bytes remain authoritative; return `Not_Committed`.
- After rename: do not claim rollback or “nothing changed.” A later sync/history failure returns `Committed_Durability_Uncertain` with the new revision.
- Retain before-images and recoverable drafts. Never automatically prune the only recovery copy.
- After a crash/lost response, inspect the current revision and transaction record before retrying; do not blindly replay `create` or `delete`.
- No-op edits preserve original bytes and revision.
- Undo and redo are new validated transactions with current revision checks.

The concurrency guarantee applies to writers using this interface and lock. External file changes made before a transaction are detected by hashing. An unrelated process deliberately ignoring the lock can race the final check/rename; ordinary files do not provide atomic compare-and-swap. Require all Studio/agent authored-content writes to use this interface, and document that direct external editing must occur while managed writes are idle.

Use JSON on stdout and human logs on stderr. Suggested exit codes: `0` success, `2` malformed/schema/reference failure, `3` stale/busy conflict, `4` I/O failure, `5` committed but durability uncertain. Responses include `commit_state`; exit status alone is insufficient.

**Native preview entry point**

Build development support explicitly:

```sh
odin build src -define:DEV_TOOLS=true -out:build/the-last-stop-dev

build/the-last-stop-dev \
  --project-root "$PROJECT_ROOT" \
  --preview-scene oliver_obstacle \
  --preview-session "$SESSION_ID"
```

The session ID maps to the dedicated preview directory; do not accept arbitrary save destinations from content. Preview initializes deterministic unsolved state and never reads normal player saves.

For E0, scene preview may render validated placeholders in the existing Playing state. It does not imply M1 movement or M2 gameplay is implemented. Retain M0’s Title/Playing/Paused behavior.

Expose `preview-scene` and `reset-preview` through the host’s fixed process actions. Reset operates only on its owned, stopped preview session. No live authoring reload is required in E0.

**Files changed:**  
None by me. An unrelated untracked `The Last Stop_ A Cozy Pixel Journey.png` appeared during inspection; I left it untouched.

**Delivery commit or diff location, if applicable:**  
None. This message is the design handoff.

**Verification run:**

- `git rev-parse HEAD` — exit 0; requested full commit confirmed.
- `git branch --show-current` — exit 0; `main`.
- `odin version` — exit 0; `dev-2026-10:84bc3fc21`.
- `odin root` — exit 0; `/opt/homebrew/Cellar/odin/2026-10/libexec/`.
- `odin check src` — exit 0.
- `uname -sm` — exit 0; `Darwin arm64`.
- `python3 --version` — exit 0; `Python 3.9.6`.
- `python3 -B -c 'import http.server, subprocess, json, pathlib, hashlib, secrets; print("Python stdlib host imports OK")'` — exit 0.
- `node --version` — exit 134; missing `/opt/homebrew/opt/simdjson/lib/libsimdjson.29.dylib`.
- `git diff --exit-code` and `git diff --cached --exit-code` — exit 0.
- Source inspection confirmed M0-only runtime and no existing content loader. Library signatures above were inspected locally, not inferred from online documentation.

No application launch, file-writing probe, migration, new code compilation, or transactional failure test was performed.

**Acceptance criteria:**

- **PASS — consultation:** host selection and dependency rationale supplied.
- **PASS — consultation:** versioned layout, identities, references, units, and explicit legacy migration specified.
- **PASS — consultation:** shared loader, diagnostics, allocation ownership, and failure behavior specified.
- **PASS — consultation:** inspection/edit protocol, stale rejection, commit boundary, and CLI specified.
- **PASS — consultation:** minimal M2 content and runtime/authored-state boundary specified.
- **PASS — read-only scope:** no edits, commits, or delegation performed.
- **UNVERIFIED — implementation:** E0 runtime/tool behavior does not yet exist.
- **UNVERIFIED — acceptance:** Opus has not accepted this proposal in this task.

**Still unverified:**

Sol’s E0 gate must cover:

1. **Strict parsing:** truncation, duplicate keys, trailing garbage/second root, trailing commas, comments, invalid UTF-8, invalid/overflowing numbers, excessive depth/size, missing fields, unknown fields and versions.
2. **Graph validation:** missing/wrong-kind references, duplicate identities, invalid speaker/action/destination, repeated/missing line-order entries, duplicate reward paths, invalid geometry and unsafe paths.
3. **Migration:** exact original-byte retention; all four dialogue lines preserved; original meaningful IDs retained; versionless content never silently rewritten.
4. **Round-trip:** scene and dialogue edits preserve IDs, references, Unicode text, and untouched documents; serialization is deterministic; no-op edits do not rewrite files.
5. **Transaction failure:** an invalid final operation leaves the entire batch unapplied; multi-document requests fail before writes.
6. **Concurrency:** two requests from one revision yield one winner and one stale failure; external pre-save changes are detected; a killed writer releases its lock.
7. **I/O/crash recovery:** injected short write, temp creation failure, sync/close/rename failures, and termination before/after rename leave old or new complete content recoverable, with truthful commit status.
8. **Undo/recovery:** before-image restoration goes through validation and stale checks; history failure cannot silently bypass recovery requirements.
9. **Runtime loading:** malformed reload preserves the active snapshot; failed startup cannot enter a partial chapter; repeated load/unload releases allocations.
10. **Native integration:** move the handle and change its interaction bounds through the CLI, launch the actual game, and observe the authored values. Capture evidence independently from `odin check`.
11. **Isolation:** preview/reset never touches normal saves; completing a preview never changes authored bytes; release gameplay works with Studio closed and has no authoring-write path.
12. **Regression:** existing M0 self-tests pass; native keyboard/fullscreen checks remain separately recorded.

Tests of native puzzle completion, actual handle recovery, skip convergence, and exactly-once rewards remain M2–M4 responsibilities. E0 must supply the contract and fixtures without pretending those systems exist.

**Bugs/risks:**

- **Confirmed tooling issue:** Node aborts on launch due to missing `simdjson`; chosen host avoids that dependency.
- **Implementation risk:** using default JSON settings or typed unmarshalling alone would accept or discard content outside this contract.
- **Implementation risk:** rename provides atomic single-file visibility, not a multi-file transaction or an unconditional power-loss guarantee.
- **Concurrency limitation:** unmanaged writers ignoring the lock cannot be given a truthful stale-write guarantee.
- **Existing verification gap:** M0 native keyboard/fullscreen behavior is still pending in project notes.
- **Documentation drift:** BUILD_STRATEGY still describes a single-file, non-Git starter; TECHNICAL_DESIGN still says compilation was unverified. Current checkout evidence supersedes those statements.

**Proposed central documentation update:**

Apply these text changes only after Opus accepts the decisions:

- **EDITOR_SPEC.md:**  
  “Studio uses a local Python-standard-library bridge and static browser UI. All authoritative content validation and writes use the Odin content CLI. Native Odin+raylib execution is the gameplay preview. E0 transactions modify one document, validate the complete chapter graph, and reject stale graph revisions. Multi-document transactions are deferred.”

- **TECHNICAL_DESIGN.md:**  
  “Authored content v1 resides in chapter, scene, dialogue, and asset-manifest JSON documents. `shared/content` owns strict parsing, typed validation and immutable snapshots. `shared/content_edit` owns semantic operations and atomic persistence. Runtime state and player saves never mutate authored defaults.”

- **CHAPTER_01.md and GAME_BIBLE.md:**  
  “The crank uses press-once automatic operation. Exact Chapter 1 dialogue follows CHAPTER_01 and the migrated dialogue documents. Initial graybox geometry uses virtual pixels and a continuously walkable corridor.”

- **TASK_BOARD.md:**  
  Record the architecture proposal as reviewed/accepted only when Opus decides. Leave loader, operations, migration, and E0 gate checkboxes open until implementation evidence exists.

- **BUILD_NOTES.md:**  
  Record this checkout/compiler/check evidence, working Python version, Node failure, and that no native or transactional E0 verification occurred.

- **ORCHESTRATION_LOG.md:**  
  “T-E0-A, GPT-6 Astra, read-only architecture consultation at eb04e66. Delivered host/schema/loader/edit/M2 contract. No files changed or commit produced. Integration acceptance pending.”

**Next task / dependencies:**

Opus accepts or amends the contract, then assigns Sol the bounded E0 implementation with this split:

- `shared/content/*.odin`: types, strict JSON adapter, decoding, graph validation, deterministic encoding, revisions.
- `shared/content_edit/*.odin`: operation application, locking, before-images, atomic commit.
- `tools/content/main.odin`: CLI parsing and machine-readable responses.
- `data/schemas/`, active JSON documents, legacy fixture: schema and explicit migration.
- `src/content_adapter.odin` plus coordinated edits to `main.odin`, `game.odin`, and `render.odin`: native loading and placeholder scene preview.
- `tests/editor/`: strict parsing, graph, round-trip, conflict, and fault-injection tests.
- `editor/server.py`, `editor/web/`: E1 host/UI work after E0; not a prerequisite for the CLI gate.

Opus retains central-document ownership. Sol should freeze the player footprint with M1 before implementing reachability checks. No additional chapter, ECS, scripting runtime, or full IDE is needed.
