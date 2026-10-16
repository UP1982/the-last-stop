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

## Open issues
- None confirmed.
