# E2 + E3 implementation contract (accepted by Opus 2026-10-16)

Source: T-E23-A, GPT-6 Astra, read-only at cd44403. Accepted as written with amendments:

- X1. Order: E3 (editor/ + tests/editor_ui only) runs in parallel with M4; E2 (src/ DEV_TOOLS) starts after M4 releases src/.
- X3. `--preview-entry chapter` (run-journey) needs src/ and lands in the E2 phase; E3 phase ships run-scene and shows run-journey as unavailable until then.
- X2. Task/ownership status reads real sources only (docs/ORCHESTRATION_LOG.md, git status/log); no fabricated provider state.

---

**Task / model / checkout / base:** T-E23-A / GPT-6 Astra / `/Users/finngilbert/Documents/The Last Stop/Game` / `cd44403a1dcd2bca6defe5b69b4a277a395b3578`.

**Recommendation:** Extend the existing Python/static-web editor for E3 first. Implement E2 after M4 releases ownership of `src/`. Keep the existing content protocol, schemas, CLI transaction system, and native renderer.

**Completed:** Read-only design consultation covering the requested contracts, committed editor/content/runtime code, and M4 audit task 7. The following is proposed addendum text for [EDITOR_SPEC.md](</Users/finngilbert/Documents/The Last Stop/Game/docs/EDITOR_SPEC.md>), subject to Opus acceptance. It does not mark E2/E3 implemented.

**Proposed EDITOR_SPEC addendum — scope and existing foundations**

Required implementation uses Python 3.9 standard library, static browser JavaScript/CSS/HTML, and Odin+raylib. No Node/npm dependency, additional engine, provider authentication, billing system, or arbitrary command terminal.

At `cd44403`:

- E1 exposes `GET /api/scene` and `POST /api/command`, with `inspect-scene`, `apply-edit`, `preview-scene`, `preview-status`, and `stop-preview`.
- The content CLI already supports `validate-content`, `inspect-scene`, `inspect-document`, and `apply-edit`.
- `apply-edit` targets one document, checks the **whole chapter graph revision**, validates the resulting graph, and retains transaction before/after images.
- Dialogue v2 supports `update_dialogue` for existing speaker/text changes. Structural changes require coherent `restore_document`; changed `set_order` alone is rejected.
- F3 outlines solids, visuals, interaction bounds, and the player. Camera bounds, stable-ID selection, editing, and Apply are still needed.
- Native scene previews already select an isolated save profile. E3 still needs a full-journey preview entry.
- E1 detects external graph revisions every two seconds but does not silently replace its draft.
- `undo_token` names transaction history. **There is no existing undo CLI command.**

Current units are 640×360 virtual pixels, scene v2, chapter/dialogue v2, and assets v1. Older examples mentioning 320×180 or scene v1 do not govern this implementation.

**Proposed addendum — E2 native edit mode**

Required E2 consists of a small development inspector over the actual game renderer.

1. **Entry and isolation.** F3 remains a read-only overlay toggle. Add F4 for edit mode, available only in a `DEV_TOOLS` build launched with a valid isolated preview session. A development game using the normal player profile may display overlays but cannot enter authoring mode. Its UI directs the user to launch a Studio preview.

2. **Overlays and selection.** Show collision, interaction, camera/world bounds, safe spawns, stable object IDs, and current puzzle/checkpoint state. Select objects/spawns through a list or hit-test transformed through the existing viewport and world camera. Ignore letterbox clicks. Label authored geometry separately from transient geometry; an installed handle must still expose its authored shelf position as an authored marker.

3. **Permitted properties.** The minimum native inspector edits object `position`, `size`, existing `collision` and `interaction` rectangles, and spawn `position`. Use integer virtual pixels. IDs, kinds, links, assets, layers, world/ground bounds, and camera limits are read-only in the minimum native inspector; E1 already provides broader scene editing. Adding those native controls is optional.

4. **Three separate owners.** Maintain an immutable loaded baseline, an editor-owned authored draft, and mutable gameplay state. Never derive an authoring document by serializing `Game_State`, runtime interaction rectangles, carried/dropped handle coordinates, or completed-puzzle visuals.

5. **Live changes.** A completed drag/numeric edit creates a candidate document and validates it through `shared/content` against the captured graph. Stage native resources and runtime geometry before publication. An invalid candidate retains the last valid preview and shows diagnostics.

   For the smallest implementation, each accepted geometry edit **resets the isolated sandbox to unsolved puzzle state and pauses it**. Display this behavior beside the inspector. This avoids inventing rules for carrying arbitrary transient state across geometry edits. Preserving in-progress state across edits is optional and must reuse the corrected M4 reload normalization.

6. **Pause/step/reset.** Editor pause is separate from the game’s pause menu. Paused authoring consumes editing keys and freezes simulation, story timers, fades, and animation. Step advances exactly one existing `FIXED_DT` tick—currently 1/120 second—then pauses again. Do not release a backlog from the frame accumulator. Reset reconstructs deterministic unsolved sandbox state from the current validated draft without changing that draft or authored files. “Discard draft & reload disk” is a separate explicit action.

7. **Input boundaries.** Selecting, typing, applying, or closing the inspector cannot also interact, skip a scene, or move Milo. Require fresh gameplay input when resuming. While an Apply process is pending, keep rendering/status responsive and disable conflicting mutations.

Use these native action identifiers for UI dispatch and repeatable tests:

```text
toggle-overlays
enter-edit-mode
select-record       {collection, id}
set-property        {collection, id, property, value}
pause-preview
resume-preview
step-preview
reset-sandbox
discard-draft
apply-to-content
undo-applied
```

These are native actions, not proposed public network endpoints.

**Apply data flow**

```text
loaded authored baseline + graph revision
→ explicit draft edits
→ candidate validation/native preview
→ user selects Apply to content
→ fixed content CLI invocation
→ inspect commit_state and exit_code
→ re-inspect disk
→ publish confirmed baseline or show conflict/uncertainty
```

The native client invokes only the pinned project content executable:

```text
<root>/build/tls-content apply-edit
    --project-root <canonical-root>
    --request <private-generated-request-file>
```

Use an argument array, a private generated request file, bounded output, and a timeout. No shell, client-selected executable, or content-supplied arguments. Validate the executable’s confinement before launching it.

The request retains the baseline `expected_revision`, targets `oliver_obstacle`, and contains only explicit inspector changes:

```json
{
  "protocol_version": 1,
  "request_id": "native_edit_unique_id",
  "chapter": "oliver_flower_market",
  "document": "oliver_obstacle",
  "expected_revision": "sha256:<captured graph hash>",
  "operations": [
    {
      "op": "set_property",
      "collection": "objects",
      "id": "crank_handle",
      "property": "position",
      "value": [1200, 256]
    }
  ]
}
```

The coordinates above illustrate the request shape; validation determines whether a placement is acceptable.

Required result handling:

- Exit `0`: distinguish no-op from committed replacement; re-inspect before reporting the new baseline.
- Exit `2`: retain draft and display schema/reference/geometry diagnostics.
- Exit `3`: distinguish `busy`, `stale_revision`, and `external_change`. Never automatically replace `expected_revision` and replay the edit.
- Exit `4`: retain draft and report the I/O failure.
- Exit `5` / `committed_durability_uncertain`: report that replacement happened but durability/finalization is uncertain. Inspect disk and history before another mutation.
- Timeout, lost response, or invalid CLI output: outcome unknown until inspected. `request_id` is correlation, **not an existing idempotency guarantee**.
- If disk committed successfully but native reloading fails, say “Saved; preview still shows previous content.” Do not report rollback.

**Undo and web-editor reflection**

Required native “Undo applied” restores the last confirmed before-image through a new `apply-edit` containing `restore_document`. It preserves kind/ID/version, uses the known post-apply graph revision, and undergoes full validation. If another writer has changed the graph, undo conflicts rather than overwriting that work.

Keep draft undo separate from applied undo. Retain transaction tokens and before/after images; crash recovery uses existing `.studio/history/` evidence. Redo uses the same guarded restoration pattern. A browsable cross-session history UI is optional; recoverable committed changes are required.

No native-to-browser event channel is necessary. After Apply, E1’s revision polling displays “Content changed on disk.” Explicit Reload reads the committed scene; dirty browser drafts remain available for keep/download/discard. A newly opened editor reads disk immediately. The acceptance demonstration must verify both clean and dirty browser cases.

**Save and release invariants**

- Preview save selection takes precedence over `--save-dir` and `TLS_SAVE_DIR`, with no normal-profile fallback.
- Failure to establish a safe isolated profile blocks preview startup.
- Bridge Reset stops its owned process and starts a fresh generated session. It does not recursively delete a client-selected directory.
- Native Reset affects only its sandbox/session.
- Playing, stepping, picking up/installing the handle, clearing the branch, and earning the flower never modify authored defaults.
- Preview progress never reads or writes normal saves. Ordinary released gameplay continues to save its legitimate player progress.
- Release builds reject authoring/preview flags and contain no reachable authoring subprocess/write path. Test this with Studio closed and the content CLI unavailable.

**Proposed addendum — E3 dialogue and asset panels**

Keep one guarded `POST /api/command` surface. Extend its strict per-command schemas:

```text
inspect-document    {document}
validate-content    {}
apply-edit          {request}        # existing command, expanded target allowlist
read-asset          {asset_id}
```

`inspect-document` accepts only IDs found in the validated Chapter 1 graph. `apply-edit` permits the scene and referenced dialogue documents; chapter text/speaker editing may use a separately bounded form. It never accepts a filesystem destination. The CLI remains authoritative.

Required dialogue UI:

- Document/role selector; stable line and beat IDs.
- Speaker, text, and onscreen/offscreen delivery controls.
- Ordered beat list with create, duplicate, delete, and reorder.
- Structured fields for line/stage/card beats and their complete presentation snapshots.
- Closed controls for set/shot, actor facing/pose/emote, prop kind/state, cue, registered asset, card key, and stage duration.
- Dirty state, undo/redo, explicit Save, conflict handling, and recovery/download behavior per document.

Treat `beat_order` as the editable sequence. Derive `order` by projecting its line beats. Do not offer an independent reorder control that can make the arrays disagree. Moving a beat moves only that beat; grouping adjacent nonverbal beats is optional.

Existing text/speaker edits can use `update_dialogue`. Delivery, insertion/deletion, stage changes, and reordering use **one** `restore_document` containing coherent `lines`, `order`, `beats`, and `beat_order`. Preserve identity/version. Creating speakers in the chapter and referencing them from dialogue requires separate validated document transactions.

Completion action/destination is displayed read-only for the document’s role. All six existing pairs remain authoritative. Individual beats cannot award rewards, change checkpoints, clear the puzzle, or execute expressions.

Enforce current budgets:

- General story text: at most 4,096 UTF-8 bytes, with visible content and permitted control characters.
- Speaker display names: 20 Unicode codepoints.
- `advance` / `return_menu`: 14 codepoints; `skip_scene`: 10.
- Existing bounded interaction-label keys: 26 codepoints.
- UI chrome is single-line without tabs.
- Stage duration: integer 0–5,000 ms.
- Existing 256 KiB document/request and 1,024-record/order limits remain.

Show byte/codepoint counters where relevant; browser string length alone is insufficient. Preview labels must distinguish browser approximation from native text wrapping. “Validate saved content” runs the real CLI; it must not imply that an unsaved draft was validated.

Required asset browser reads the validated `data/assets/manifest.json` and displays `assets/ASSET_LICENSES.md` as provenance evidence. Show asset ID, strip/frame preview, dimensions, frame count, pivot, path, hash, creator, source, license, and attribution. Preserve uncertainty in the register; an entry is not an independently verified legal clearance.

`read-asset` resolves an asset ID through the manifest, confines its path, bounds the read, and verifies its declared hash. It returns image bytes with an explicit MIME type or a bounded encoded response. Render fetched bytes through a browser blob URL; add only the necessary `img-src blob:` CSP allowance. Never serve arbitrary paths, SVG/HTML execution, or remote metadata URLs automatically. Missing, changed, or undecodable assets show errors. Asset import/editing and an atlas tool are optional.

**Proposed addendum — E3 coding workspace and commands**

Required workspace is a modest text editor: project tree, tabs, dirty buffers, explicit save/reload, literal search, Git HEAD diff, diagnostics, command controls, and live logs. A textarea is sufficient; syntax highlighting, LSP, completion, terminal emulation, and Git mutation controls are optional.

Add these fixed commands to `/api/command`:

```text
list-project        {}
read-file           {path}
write-source        {path, expected_sha256, text, request_id}
search-project      {text, limit}
diff-head           {path}
check-game          {}
check-dev           {}
build-content       {}
build-dev           {}
build-release       {}
run-scene           {}
run-journey         {}
job-status          {job_id, cursor}
stop-job            {job_id}
task-status         {}
```

These are proposed Studio command IDs; `task-status` here is a local read-only status view, not an invented provider endpoint.

Required executable mappings use pinned executable paths and fixed argument arrays:

```text
check-game     → odin check src
check-dev      → odin check src -define:DEV_TOOLS=true
build-content  → odin build tools/content -out:<owned-job-output>
build-dev      → odin build src -define:DEV_TOOLS=true -out:<owned-job-output>
build-release  → odin build src -out:<owned-job-output>
```

Build into bridge-owned output locations and publish a successful artifact only after checking the actual process result. Do not overwrite the executable currently running. No API accepts additional compiler flags, environment assignments, shell text, arbitrary working directories, or executable paths.

`run-scene` uses the verified development artifact and existing preview scene/session flags. `run-journey` requires a small new development-only launch option:

```text
--preview-entry chapter|scene
```

It is valid only with the existing preview scene/session identity. `scene` preserves current behavior; `chapter` initializes a fresh isolated Chapter_Start journey and enters the normal introduction. It does not read normal saves or bypass puzzle/story guards. Arbitrary checkpoint/beat jumps are optional.

Run requires a successful build matching the current relevant source inputs. A failed or stale build must not silently launch an older executable. Display the artifact, source fingerprint, and loaded content revision.

**Source write boundary**

Minimum editable roots/extensions:

```text
src/       *.odin
shared/    *.odin
tools/     *.odin, *.py
editor/    *.py, *.js, *.css, *.html
tests/     *.odin, *.py, *.js, *.json, *.swift
```

Initially support existing regular UTF-8 files only. File creation, rename, deletion, and executable permission changes are optional.

Content under `data/` always uses the content CLI. `assets/`, central `docs/`, `prompts/`, `scripts/`, `.git/`, `.studio/`, generated `build/` files, credentials, and unrelated filesystem locations are not writable through `write-source`. Read-only tree/view roots are separately allowlisted; listing the project does not authorize reading hidden files.

All file endpoints require:

- Canonical launch root; normalized project-relative paths.
- Rejection of absolute paths, traversal, NUL/control characters, backslashes, symlink components, nonregular files, and hardlinked writable targets.
- Descriptor-relative traversal with no-follow checks, bounded reads, and parent identity checks around replacement.
- Exact-byte SHA-256 precondition; stale saves retain the buffer and return conflict.
- Serialized managed writes, an atomic same-directory temporary replacement, and truthful pre/post-rename failure reporting.
- A durable before-image and transaction metadata before source replacement.
- No automatic format conversion on read; no-op saves retain bytes.
- Server-configured read-only ownership reservations that API clients cannot override.

Unmanaged writers can still race a final check/rename; document the same limitation as E0. All managed agent source writes should use this endpoint. Ownership badges alone are not filesystem locks.

Keep token, exact Host/Origin, cross-site, bounded JSON, duplicate-key, finite-number, and no-CORS checks on every new endpoint. Render filenames, source, diagnostics, logs, and task text using text nodes. No `eval`, executable Markdown, or shell interpolation.

**Buffers, diff, diagnostics, and jobs**

Each open buffer records disk hash, loaded text, draft text, dirty state, and latest observed disk hash. Poll open files, with explicit conflict handling when disk changes. A clean-buffer Reload is straightforward; a dirty-buffer reload requires a keep/download/discard choice. Never silently rebase its save precondition.

Build/check uses saved disk files. With dirty buffers, present explicit “Save selected files” and “Use saved files” choices. Do not autosave as a side effect of Run.

`diff-head` compares the allowed file with actual Git HEAD, including both staged and unstaged differences. Disable external diff/textconv and literalize the path argument. Untracked files display as added; a missing HEAD produces an honest unavailable result. An optional separate diff compares buffer against disk.

Jobs return a generated ID and real state: starting/running/exited/failed-to-start/stopped. Include exact argv, cwd, PID, timestamps, compiler version, source fingerprints, exit code, and bounded log chunks with cursors/truncation markers. Polling is sufficient; WebSockets are optional.

Parse actual Odin diagnostics into file/line/column/severity/message while retaining raw output. Unparseable output remains visible. Missing compiler, timeout, signal termination, and nonzero exit are never success. Detect source changes during a command and mark its result as not verifying the current source state.

Build/check jobs cannot hold the bridge’s global lock for their entire duration: status polling, log reads, and cancellation must remain responsive. Stop only owned processes/process groups, with bounded termination escalation.

**Proposed addendum — structured agent edits and T3 evidence**

Agents and humans share the same content requests and restricted source-save requests. UI polling reveals externally applied changes and identifies conflicts with dirty buffers. Correlate requests through transaction IDs; a client-supplied author label is descriptive, not authenticated identity. Unmanaged disk changes must be labeled “external writer,” not attributed to a model.

Required task panel displays:

- Actual `git status --porcelain=v1 -z` results for the pinned checkout.
- The current bytes/hash of `docs/ORCHESTRATION_LOG.md`.
- Recorded task labels, scope, checkout/base, delivery/review evidence, and ownership claims.
- Source and observation time for every status claim.

The committed log already contains stale “File owners now” text alongside newer tasks. Display contradictory ownership as unresolved; do not silently treat the last-looking paragraph as a lease.

T3 capabilities and `task_status` are real orchestration tools available to the agent context. The Python bridge does **not** thereby gain an HTTP API or access to those tools.

For the minimum integration, Opus uses actual T3 tools with retained task IDs and exports a bounded observation snapshot to a fixed local path such as `build/studio/orchestration.json`. The bridge reads this file only; it cannot accept an arbitrary status-file path or manufacture observations. Each entry includes the task ID, provider-returned raw state, observation time, and evidence reference. Human review/acceptance is separate recorded evidence.

Display:

- **Queued/running:** only when supported by a provider observation, labeled with its observation time.
- **Reported:** a delivered result/handoff exists.
- **Reviewed:** an identified review exists.
- **Accepted:** explicit integration-owner acceptance exists.
- **Unknown/unavailable:** no usable observation, permission to query it, or task ID.

Git changes do not prove a task is running; process completion does not prove acceptance. Old observations remain “last observed,” never silently live. Automatic T3 refresh/delegation controls are optional. At least one real orchestration observation must be demonstrated for the E3 task-status gate; a fabricated fixture cannot satisfy it.

**Proposed addendum — ownership and sequence**

Assign Sol bounded implementation phases:

1. **E3 web/bridge phase:** `editor/`, `tests/editor_ui/`, and new `tests/editor_workspace/`. Use existing content CLI capabilities. No `src/`, `shared/`, production `data/`, M4 tests, or shared build-script edits. Test source writes in disposable projects.
2. **E2/runtime phase after M4 lands:** new `src/dev_editor.odin` and coordinated hooks in `src/main.odin`, `src/content_adapter.odin`, input/render code, plus new `tests/dev_editor/`. Integrate preview-entry initialization with M4’s final save-profile API. Do not replace its repaired persistence or reload logic.
3. **Integration phase:** Opus assigns shared `scripts/check.sh`/README changes after both phases are ready, then runs the combined suite and native demonstrations.

Opus retains `docs/EDITOR_SPEC.md`, `TASK_BOARD.md`, `TEST_PLAN.md`, `BUILD_NOTES.md`, and `ORCHESTRATION_LOG.md`. Implementers return proposed updates. No shared schema/CLI expansion is required for basic dialogue edits; any later change to shared contracts receives a separate allocation.

**Proposed addendum — acceptance tests**

The following numbering maps to the eight existing “Editor coverage — E0–E4” bullets in TEST_PLAN; it does not rename gameplay cases.

1. **Scene round-trip — E2 gate, editor bullet 1.** In a disposable project, select the handle by ID, change position and interaction bounds in paused native edit mode, Apply through the real CLI, reopen/reload the browser, and verify identical authored values. Record request/result, revisions, disk diff, native dump, and PID-scoped screenshot.

2. **Shared edits/conflicts — E2/E3, bullet 2.** Submit browser/native/agent edits from one revision; verify stale rejection preserves the loser’s draft. Exercise dirty browser buffers during native Apply, dirty source buffers during agent writes, unrelated graph changes, deleted files, and invalid external content.

3. **Undo/failure recovery — E2/E3/E4, bullet 3.** Undo an applied native change using a real restoration transaction; verify semantic restoration and revision changes. Reject stale undo. Exercise malformed requests, failed history/temp/write/sync/rename, lost responses, and termination on both sides of rename. Preserve old/new complete files and report uncertainty accurately.

4. **Dialogue/native behavior — E3 gate, bullet 4.** Through the web forms and a structured agent request, edit text, delivery, a stage, and beat order. Reject dangling/duplicate IDs, inconsistent orders, bad completion pairs, over-budget text, invalid durations/assets, and unsupported fields. Run the edited dialogue in the real game; verify visible text plus advance/skip/restart convergence and one derived flower. Cover gameplay cases 8, 9, 12, and 15.

5. **Explicit Apply/isolation — E2 gate, bullet 5.** Hash authored files and seed a sentinel normal save in a temporary HOME. Pick up/install/drop, crank, clear, finish, step, reset, and quit previews without Apply: authored hashes and normal-save sentinel must remain unchanged. Apply changes only its document plus editor history. Test invalid/symlinked preview destinations, failed profile creation, and attempted CLI/environment save overrides.

6. **Source/compiler truth — E3 gate, bullet 6.** Dirty a buffer; show that check uses saved bytes. Save a deliberate Odin syntax/type error in a disposable checkout; run real `odin check`, display actual nonzero exit and diagnostic navigation. Fix/save, build, and launch the actual game. Verify HEAD diff, stale hashes, failed/stale builds, live log cursors, cancellation, source changes during builds, and all confinement/allowlist attacks.

7. **Task truth — E3 gate, bullet 7.** Display a real T3 observation and corresponding recorded handoff/review/acceptance evidence. Verify unavailable/old observations and conflicting ownership remain explicit. Confirm Git status does not promote task lifecycle state and a reported result does not become accepted automatically.

8. **Release independence — E2/E4, bullet 8.** Build release without DEV_TOOLS; close Studio and remove access to its CLI in the disposable environment. Launch and complete the game. Reject editor flags and demonstrate unchanged authored bytes. Legitimate release progress saves remain functional.

Additional automated checks cover exact one-tick stepping, frozen timers, input leakage, viewport hit-testing, candidate/resource rollback, deterministic reset, and repeated draft ownership cleanup. Extend existing Python unittest and JavaScriptCore tests without Node. Reuse existing native autoplay/rendezvous infrastructure while identifying synthetic-input evidence correctly.

Native automated evidence must include real processes/windows and rendered changed content; CLI output alone does not prove rendering. Physical mouse/keyboard selection, minimum-window readability, pause/step usability, and conflict/undo comprehensibility require human checks. E4 additionally requires the fresh-user editor→dialogue→build→play→undo→reopen walkthrough.

**Files changed:** None. No edits, staging, commits, worktree creation, or delegation.

**Delivery commit or diff location:** None; this response is the proposed contract and documentation text.

**Verification run:** Used `git show cd44403:<path>`, `git grep`, and `git ls-tree` for committed inspection. `git rev-parse cd44403` confirmed the full base above. Initial/final `git status --porcelain=v1` showed only the pre-existing modification to `docs/ORCHESTRATION_LOG.md`. The audit handoff is not tracked at `cd44403`; read its supplied local evidence copy. A read-only `orchestrator_capabilities` call succeeded and confirmed actual T3 capabilities. No compiler, application, mutation, or acceptance tests were run in this consultation.

**Acceptance criteria:** PASS for read-only contract, endpoint/command definitions, ownership split, invariants/failure handling, test mapping, and proposed documentation. Implementation, Opus acceptance, and E2/E3/E4 gates remain UNVERIFIED.

**Bugs/risks:** The pinned runtime still contains the pre-M4 reload path implicated by audit F2; E2 must integrate against M4’s delivered correction. E1 draft recovery is origin/port-dependent, so durable cross-launch recovery remains an E4 requirement. Current documentation and ownership statements contain drift; neither should override inspected code or explicit allocation.

**Next task / dependencies:** Opus accepts/amends this addendum and allocates the E3 web phase. E2 runtime integration waits for M4 delivery. Keep M4’s recorded scope amendment: audit task 7 remains required under E2–E4 and is not waived by M4 acceptance.


