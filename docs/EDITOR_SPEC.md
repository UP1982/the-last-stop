# The Last Stop Studio — editor requirements

Status: authorized scope and implementation specification, not an implemented editor.

The user requested all three: a visual game-content editor, an in-game editing mode, and a coding/agent workspace. These are three views of one project. This request supersedes the earlier exclusion of custom editor tooling. The game remains Odin + raylib.

## Product surfaces

### Visual content editor

Provide a scene viewport with pan/zoom, pixel grid, snapping, layer visibility, selection, placement, move/duplicate/delete and undo/redo. Include a scene tree and property inspector for stable object IDs, transforms, collision rectangles, interaction bounds, safe spawn markers, camera limits, asset references and named puzzle links.

Provide structured chapter/dialogue editing: speaker, text, ordered beats, allowed transition/action identifiers, and preview entry points. This is a form/list editor, not an unrestricted scripting language. Validate missing speakers, invalid destinations and duplicate rewards. Add an asset browser with sprite frames, preview and provenance. Use project-relative paths.

Save authored content, show dirty state, detect external changes, and offer explicit reload/conflict resolution. Do not silently overwrite an agent's newer edits. Preview by launching the actual Odin game with a specified chapter/scene and a temporary save profile. A viewport approximation must be labeled; it is not evidence that gameplay works.

### In-game edit mode

Expose a development-only toggle for collision/interaction overlays, camera bounds, object selection, position adjustment, safe spawn editing, and pause/step/reset. Display stable IDs and current puzzle state for debugging. Reuse the runtime renderer and shared authoring operations where practical.

Separate authored defaults from transient gameplay state. Playing the scene must not move its authored handle to the installed location or grant a permanent keepsake in content files. Applying a runtime adjustment to authored data must be an explicit action with undo and validation. Disable authoring writes in release builds. Test mode uses isolated saves and can reset deterministically.

### Coding and agent workspace

Provide a project tree, source/text editing with save and dirty-state feedback, search, diff inspection, diagnostics, build/check/run controls, logs, and task/ownership status. It should let agents use stable structured file/command interfaces while the user can inspect the same work visually. Do not force agents to perform every edit through mouse coordinates.

Keep T3 as the initial provider authentication and delegation system. The workspace displays an orchestration/task manifest and links or points to the active T3 work; it must not imply it launched a task unless the real delegation tool accepted it. No duplicate model billing/authentication system is required. The initial source editor can be modest; do not promise a full IDE or language server until implemented and tested.

Run only explicit project build/check/run actions through the command runner. Treat dialogue and asset metadata as data, never shell commands. Bind a web-based development bridge to localhost if one is selected; prevent arbitrary workspace/path escape and unrelated filesystem writes. Dirty source buffers must be saved explicitly before building, or clearly identify that the build uses the last saved version.

## Architecture and agent interface

Opus chooses the host implementation after a short Astra feasibility review of the installed environment. Prefer one editor application with panels and a native development overlay, not three separate engines. A web/desktop UI is permitted for development tooling if justified; the playable game and its rendering/input/audio remain Odin + raylib. Record the host choice and dependency tradeoffs before implementation.

The contract is more important than the editor framework:

- Versioned authored JSON documents for chapter/scene/dialogue definitions, with a checked schema and runtime validation. Keep the existing illustrative manifest until an explicit migration replaces it.
- Stable object IDs; explicit coordinates, collision, layers, references and spawn points. Unique IDs and references are validated across the relevant chapter.
- One shared Odin content loader/validator where feasible, exposed to tools through a small command entry point. UI-side checks can improve feedback but do not replace authoritative validation.
- Small semantic operations such as create/move/set-property/link-object/update-dialogue. Operations include expected document revision/hash, fail cleanly on stale data, and return machine-readable diagnostics. Persist atomically; never partially apply a failed batch.
- Deterministic formatting and minimal diffs. Reject unsafe asset paths, malformed numbers, unknown versions and unsupported actions with helpful diagnostics.
- Authored content, editor preferences/session state, and player saves are separate files/directories. Define migration and incompatible-load behavior before changing formats.
- An undoable transaction history for editing, external-change detection, and recoverable drafts. Conflict detection is required; simultaneous collaborative editing is not.

Proposed tool operations (names are a contract to implement, not commands currently available): `validate-content`, `inspect-scene`, `apply-edit`, `preview-scene`, and `reset-preview`. Accept structured arguments or JSON files; return nonzero on failure and machine-readable results for agents. Do not expose arbitrary shell execution through content operations.

Suggested locations, to finalize before coding: `editor/` for editor UI/host, `tools/content/` for the tool entry point, a shared Odin content package for runtime/tool validation, `data/scenes/`, `data/chapters/`, `data/dialogue/`, `data/schemas/`, and `tests/editor/` for meaningful round-trip/conflict tests. Keep generated output and machine-specific settings out of source control.

## Delivery sequence and ownership

**E0 — Shared contract, after M0 and before editor-dependent M2 work.** Astra proposes the schema, invariants, load/error strategy and tool interface; Opus accepts a bounded design. Sol implements loader, validator and agent-readable inspection/edit operations. Haiku prepares fixtures and reference/provenance inventories. Gate: a valid scene loads in the actual game; invalid data is rejected clearly; edits round-trip without losing IDs or references; stale edits cannot overwrite newer content.

**E1 — Visual scene editor, alongside M1/M2 once contracts stabilize.** Sol implements viewport, tree, inspector, placement, undo/redo, save and native preview. Opus owns usability and file allocation. Gate: place/move the handle, change an interaction bound, save, launch the real game and observe the authored change. Undo/redo and external-change handling must work.

**E2 — In-game editing, with M2.** Sol adds the development overlay and explicit apply/reset flow. Astra reviews the boundary between runtime and authored state. Gate: adjust an object in paused playtest, explicitly apply/save, reopen the visual editor and observe the same value; playing/clearing the puzzle never silently changes the authored scene or real player save.

**E3 — Dialogue, assets, code/task workspace, with M3–M4.** Sol implements structured dialogue editing and coding/build/log panels; Haiku contributes validated metadata and test fixtures. Opus coordinates task manifest integration and creative review. Gate: an agent performs a structured edit, the user sees it, validation/build output identifies errors, and a dialogue change appears in the native game with correct skip/reward behavior. Source edits are saved, diffable and compiled by the actual toolchain.

**E4 — Reliability and usability, before M5 acceptance.** Test malformed files, incompatible versions, missing assets, unsaved buffers, external edits, conflicts, interrupted writes, undo boundaries and preview save isolation. Gate: a fresh user can edit a scene and dialogue, build/play, undo or revert, and reopen with changes intact. Release gameplay works without the editor running and cannot write authoring data.

Do not let editor development require later chapters. Build only the object types, dialogue actions and source operations needed for Chapter 1. Defer terrain generators, physics editors, shader graphs, plugins, cloud collaboration and a generic engine SDK.

## Minimum end-to-end acceptance demonstration

1. Open Oliver's scene in the visual editor; select the shed handle by stable ID.
2. Move it to another reachable position, adjust its interaction bounds, save and inspect the diff.
3. Agent validates and changes a dialogue line through the structured/file interface; the editor detects and displays the update.
4. Build/launch the actual Odin game from the workspace. Observe the new placement and dialogue.
5. Enter development edit mode, adjust a permitted property, explicitly apply it, and reopen it in the visual editor.
6. Complete the puzzle, quit, resume and verify the keepsake once. Verify test saves did not replace normal player saves.
7. Undo/revert authoring changes. Deliberately submit a stale edit and malformed content; both fail without destroying the last good files.
8. Launch the release game with the editor closed. It loads authored content and plays normally.

Record automated, native and human verification separately. None of the above is implemented merely by writing this specification.
