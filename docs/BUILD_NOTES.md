# Build notes

## Environment (verified 2026-10-16)
macOS 27.2 arm64; Odin `dev-2026-10:84bc3fc21`; bundled vendor:raylib 6.0. No extra deps.

## Commands
- `odin check src` — exit 0
- `odin build src -out:build/the-last-stop` — exit 0
- `odin run src -define:M0_SELF_TEST=true -out:build/selftest` — exit 0 (viewport, mouse bounds, mode transitions, fade input isolation, quit)

## M0 evidence (T-M0-1, Sol; re-run by Opus)
- Native: window launches and stays up; resize shows integer-scaled 320x180 with centred letterbox; minimum 640x360 client enforced; close button exits 0 with render-texture unload. Screenshots in `build/evidence/` (gitignored, local only).
- Automated: state machine/transition self-tests above.
- **Unverified natively:** keyboard menu/Enter/Escape pause, visible fade, F11/Alt+Enter fullscreen, measured 60 FPS. Synthetic keystrokes via osascript did not reach the window (2 attempts: Sol, Opus) — needs human check.

## E0a evidence (T-E0a-1, Sol; re-run by Opus)
- `./scripts/check.sh` exit 0; `python3 -B tests/editor/run.py` 9 groups OK; CLI validate/inspect/edit/stale(3)/malformed(2) demo with byte-identical rejection evidence in `build/evidence/e0a/`. Legacy manifest byte-exact. Native integration unverified (E0b).
- Env: Python 3.9.6 OK; Node broken (missing libsimdjson) — not a dependency.

## E0a review
- Astra R1: 2 P2 (aliased lock lost update; new-asset deps) → fixed ae3448f. Astra R2: verified fixes + 279 malformed inputs, 100 asset txn alloc cycles; 1 P2 exit code → fixed by Opus with regression test_13. check.sh exit 0, 13 test groups OK. E0a accepted.
- Documented limitation: unmanaged writers ignoring the lock can race the final recheck/rename.

## M1 evidence (T-M1-1, Sol; re-run by Opus)
- `odin run src -define:M1_SELF_TEST=true` exit 0 (coyote/buffer, variable jump, walls/ceiling/step, world clamp, camera deadzone/clamps, nearest focus, pause isolation, fixed 120 Hz step). check.sh exit 0.
- Native: launches to title (build/evidence/m1/). Keyboard feel/readability/fullscreen unverified — needs human.

## E0b evidence (T-E0b-1, Sol; re-run by Opus)
- Release + DEV_TOOLS builds, M0/M1 self-tests, 7 runtime test groups, 13 editor groups: all exit 0. Release has no content_edit import. data/ byte-identical to dacc96b after round-trip.
- Native: CLI-moved crank_handle visible in game + `--dump-scene` (build/evidence/e0b/).
- Run dev preview: `odin build src -define:DEV_TOOLS=true -out:build/the-last-stop-dev && build/the-last-stop-dev --project-root "$PWD" --preview-scene oliver_obstacle --preview-session test`.

## M2 evidence (T-M2-1, Sol; check.sh re-run by Opus)
- Release/dev builds, M0/M1, 7 E0b + 7 M2 + 13 editor groups, check.sh exit 0. 3 scripted native completions with PID-verified screenshots, 5 kill/relaunch checkpoints. data/ and real saves untouched (no ~/Library save dir created). See build/evidence/m2/HANDOFF.md.
- Saves: `~/Library/Application Support/The Last Stop/saves/chapter_01.json`; override `--save-dir` / `TLS_SAVE_DIR`.

## 640x360 migration (T-RES-640, Sol)
- Canvas 640x360, window 1280x720 default / 640x360 min. Physics/collision/world doubled (footprint 24x32). Scene schema v2 (v1 old-unit scenes rejected). Save v2: v1 dropped_feet doubled then safety-checked. All suites + check.sh exit 0; 3,000-tick normalized trace matches pre-migration baseline; native captures at both sizes (build/evidence/res640/).

## Open issues
- Multiple simultaneous game instances aren't coordinated on the save file (out of contract scope).
- B2: hint/response strings live in one marked table in src/hints.odin pending a content-schema extension (fold into story schema v2).
- Debug labels overlap at puzzle entry (branch/Milo/brass) — dev overlay readability, revisit in M5.
- None confirmed.
