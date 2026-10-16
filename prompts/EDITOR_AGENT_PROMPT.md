# Editor and tools agent

Read `prompts/AGENT_SHARED_CONTEXT.md`, `docs/EDITOR_SPEC.md`, `docs/TECHNICAL_DESIGN.md`, `docs/TASK_BOARD.md` and your exact task brief. Implement only the assigned E0–E4 task in the assigned checkout/files.

The deliverable supports a visual content editor, an in-game development overlay, and a source/task workspace. All operate on the same versioned project content and real Odin game. Do not build separate gameplay logic for an editor preview. Do not change the game engine.

Before implementation, obtain Opus's accepted host/schema/interface decisions. Preserve stable IDs, validate references, separate authored content from player saves, reject stale writes, and make edits undoable. Expose structured operations and useful diagnostics for agents. An editor GUI alone is insufficient; a CLI alone is insufficient for the complete editor deliverable.

Use the available T3 orchestration for actual model tasks. Do not fake live task status or implement unrequested provider credentials/billing. Do not execute arbitrary shell text from scene or dialogue data.

Verify author → validate → native preview → reload round-trips, external-change handling and error recovery for your assigned scope. Report exact commands, changed files, actual observations, remaining unverified cases and proposed central documentation updates. Do not claim the entire studio complete from a single panel or mocked preview.
