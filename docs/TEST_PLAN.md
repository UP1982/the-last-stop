# QA test plan

Log date, Odin version, platform, commit, PASS/FAIL, and evidence for each test; no unverified PASS labels.

1. Open title, start game with <=2 choices.
2. A/D and arrows walk; Space jumps; E/Enter interacts; Esc pauses; prompts readable.
3. Automatic train travels, stops at branch, and does not pass uncleared branch.
4. Inspect winch before finding handle; a useful clue appears.
5. Pick, drop, recover, carry, install handle. Repeat interactions cannot consume it or create two copies.
6. Activate crank; branch moves visibly, opens route, once only.
7. Leave the puzzle unsolved, quit, reload: valid state for each of (unfound/held/dropped/installed/operating/cleared).
8. Skip introductory cutscene before/after dialogue beat; passenger state identical.
9. Quit during arrival cutscene and reload; keepsake awarded exactly once.
10. Rapid pause/unpause, resizing window, minimize/restore, normal exit: no crashes or visual smear.
11. Retry all wrong-order actions: branch never softlocks and there is no timing pressure.
12. Keyboard-only accessibility and readable text at smallest supported display.
13. No undocumented external assets required to launch.
14. First-time player can explain why crank affects branch and finish without handholding.
15. Train cutscene skip cannot bypass gameplay-required puzzle.

## Editor coverage — E0–E4

Follow the end-to-end demonstration in `EDITOR_SPEC.md`. Record each result independently from gameplay results.

- Scene edit → validation → save → native preview preserves IDs, coordinates and references.
- Agent and visual edits share a format; stale revisions and external changes cannot silently overwrite newer work.
- Undo/redo and revert restore expected content; malformed input and interrupted writes retain recoverable good files.
- Dialogue edits appear in game and retain correct skip and reward behavior.
- In-game edits require explicit apply; test progress cannot leak into authored content or normal saves.
- Source dirty state, save, diff, check/build/run and diagnostics correspond to actual disk/compiler state.
- Task status distinguishes queued/running/reported/reviewed/accepted work and never fabricates provider activity.
- Release game launches with editor closed and cannot write authoring data.

## Repro report template
- Build and system:
- Steps:
- Actual:
- Expected:
- Severity:
- Screenshot/log:
- Owner/status:
