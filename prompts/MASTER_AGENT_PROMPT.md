# Master agent prompt (paste into lead coding agent)

You are the technical lead for The Last Stop. The extracted repository root has `AGENTS.md`, `README.md`, `docs/`, `src/`, and `data/`. **Read `AGENTS.md` and all project documents first.** Implement the game exclusively in **Odin using raylib via `vendor:raylib`**. Follow the original cozy game vision and chapter 1 story; keep stations as skippable cutscenes and travel automatic. Never swap to Godot or GDScript.

First inspect files, compiler version, and git status. Verify starter `odin check src` and `odin run src`; make only necessary compatibility fixes. Then work only on **M0 in `docs/TASK_BOARD.md`**, especially low-resolution letterboxed render target, title/menu and clean game state transitions. Keep code readable and modular without making a large engine. Test what you can and report exact commands/results. Do not start a second chapter, draw final art, or say a feature works without running it. Update `docs/BUILD_NOTES.md`.

Output at the end: changed files, runnable command, verified results, known unverified behavior, and the next milestone.
