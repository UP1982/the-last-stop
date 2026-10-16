# Art pipeline decision (Opus, 2026-10-16)

- **User chose 640x360** (native supplied art scale). The 320x180 half-scale recommendation in ART_PIPELINE_PROPOSAL.md section 1 is superseded; use its "true 640 migration" values: walk 72→144, gravity 300→600, jump 112→224, accel 480→960, brake 600→1200, terminal fall 180→360, step 4→8, deadzone 18→36; collision 12x16→24x32; world/scene/spawn/object/interaction/anchor coordinates doubled; seconds-based timings unchanged.
- Milo model: red scarf + backpack (per STORY_CONTRACT); no cap.
- Source of record: ../the-last-stop-assets-sprits-images-Updated (read-only; copy into assets/ via pipeline only).
- Provenance: AI-generated with an image_gen tool; user must confirm tool/terms/rights before any release.
- Sequence: M2 review fixes → T-RES-640 migration (Sol, Astra review) → M3a/M3b → art import batches.
