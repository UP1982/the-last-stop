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

## Open issues
- None confirmed.
