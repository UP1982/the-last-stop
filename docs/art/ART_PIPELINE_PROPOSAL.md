# T-ART-1 — Art direction audit and asset pipeline proposal

**Status: proposal for Opus approval; no production assets or content imported.**

Task/model: T-ART-1 / GPT-6.1 Sol / Art–Visuals. Checkout: `/Users/finngilbert/Documents/The Last Stop/Game`. Observed base: `977efc467429097411129a49b19f4af932a75520`. Audit date: 2026-10-16. Other agents' working changes were present and were not edited. All outputs from this task are under `build/art/`; this directory is generated/local evidence, not a delivery commit. Concurrent integration advanced checkout HEAD to `40160f4964714c316097c5311fa5b8506b392472` by the final inspection; this task made no commit. `build/art/` is ignored by Git, so retain these local artifacts explicitly for review.

## 1. Decision requested

**Keep the 320×180 virtual stage and the accepted 12×16 bottom-centre player collision footprint. Convert the current export pack at exactly 1/2 scale with nearest-neighbor sampling, then hand-clean characters and props at their final resolution.** Character cells become 48×48 with feet pivot **(24,44)**. Backgrounds become 320×180 mattes. Keep authored world geometry, interaction bounds, movement units and save coordinates unchanged during this import batch.

The 96×96 export canvas is padding, not Milo's visible size. Measured static Milo is 35×48 and his animated idle silhouette is 34–35×48. At half size he is about 17–18×24; his collision remains 12×16, with visual ears/head/tail overhang. This is a reasonable first presentation target for the forgiving, mostly level Chapter 1 corridor. It requires a visible-foot/contact and wall-overhang review; it does not establish gameplay acceptance. Keeping the full 96×96 export on the current stage would make Milo 48 pixels tall, three times the current collision height, and the locomotive 228 pixels wide.

**Do not fit a sprite's whole transparent canvas into the player's collision rectangle.** Do not independently normalize every animation frame to its own bounding box. Both approaches distort the character or make its size breathe.

### Alternatives and their costs

| Choice | Visible static Milo / Oliver | Consequences | Verdict |
| --- | --- | --- | --- |
| 320×180; all supplied art ×1/2 | About 18×24 / 16×33 | Characters in 48×48 cells, exact integer pivot (24,44); backgrounds fit one screen; collision remains 12×16; final pixel cleanup needed | **Recommended bounded Chapter 1 path** |
| 320×180; characters and props ×1/3, backgrounds ×1/2 | About 12×16 / 11×22 | 32×32 cells; source foot pivot becomes (16,29⅓), needing manual integer reanchoring; face/paws/scarf lose detail; sprite/background pixel density diverges unless redrawn | Useful fallback if playtesting rejects visual overhang; proof supplied |
| 640×360; native supplied exports, double all world units | 35×48 / 32×66 | Preserves more texture and similar screen composition, but doubles collision to 24×32, world to 1280×360, floor to y288, spawns/objects/interactions/anchors and camera deadzone; UI and tuning need coordinated review | Viable future art-first migration, **not** a render-constant-only fix |
| 640×360; native exports, keep existing world units | 35×48 / 32×66 | Existing 640-pixel-wide puzzle becomes one screen instead of two; player remains tiny collision inside large visual body; existing speeds look slower relative to screen; camera/validators and UI disagree | Reject as a partial migration |
| 320×180; crop native 640×360 scenery | Unchanged sprites | Shows only a quarter of the source area; requires deliberate new framing and ground alignment; does not fix sprite density | Only for intentional cutscene close-ups |

For a true 640 migration preserving the current motion in screen space: walk speed 72→144, gravity 300→600, jump speed 112→224, horizontal acceleration 480→960, braking 600→1200, terminal fall 180→360, step 4→8, camera deadzone 18→36. The 120 Hz timestep, 0.1 s coyote/buffer windows, jump-release ratio and crank duration stay in seconds unchanged. Update every view-size assumption in validation, mouse conversion, editor preview, overlays and tests, not just `VIRTUAL_WIDTH/HEIGHT`. Revalidate the ±16,384 authoring limits for any expanded content. Review saved dropped-handle coordinates and either migrate or safely recover them. These are proposed migration values, not implemented/tested tuning.

## 2. Evidence and reproducibility

Sources read: `AGENTS.md`, shared and art/audio prompts, README, game bible, technical design, Chapter 1, task board, build strategy/notes, test plan, editor spec, story/gameplay plan, E0/M2 contracts, art/audio guide, license register, asset schema and manifest, live renderer/player/camera/resource loader. Historical kit style reference was inspected visually. The external updated and old art folders were read only.

Reproduce from the Game checkout:

```sh
python3 -B build/art/audit_art.py
python3 -B build/art/verify_art.py
```

The script uses **Python standard library only** (`struct`, `zlib`, `hashlib`, `json`, etc.). Pillow is installed but was deliberately not used. It decodes the supplied 8-bit noninterlaced RGB/RGBA PNGs, verifies PNG chunk CRCs, and writes only beside itself. No AI generation, external image editor, package installation, game launch or production import was performed.

Outputs:

- `audit_report.json`: 412 primary-image measurements; all 64 clip summaries; 440 manifest checksum checks; common old/current PNG comparison.
- `bounding_boxes.csv`: every static character direction, prop, background and animation frame, including source hashes.
- `characters_contact.png`: all eight static characters against animation idle frame 00.
- `milo_animation_contact.png`, `oliver_animation_contact.png`: all six right-facing frames of all four actions, at the source export resolution.
- `environment_contact.png`: all six backgrounds at half size plus all six props at supplied size.
- `palette_swatches.png`: dominant sampled RGB bins, labelled with file and bin center.
- `alpha_matte_contact.png`: static/animated Milo against black, white and night, plus thresholded comparison.
- Three mock frames described below; nine **mechanical, uncleaned review candidates** in `candidates/`; `PROOF_milo_walk_r_48x48_6f.png` and `proposed_manifest.review.json`.

All **440/440** source PNG hashes match the updated pack's manifest. All **48/48** PNGs present at matching relative paths in both old and current packs are byte-identical. The updated pack adds the animation work; prefer it as the source of record. The declared 412 primary PNGs resolve to 384 animation frames + 16 static character directions + 6 props + 6 backgrounds. The other 28 manifest PNGs are original full-resolution sources/animation atlases. Do not feed those generation-size sources directly into runtime.

### Bounding boxes: what “opaque” means here

Boxes use `[left,top,right,bottom]` with **exclusive** right/bottom edges. The CSV reports alpha>0, alpha≥128 and alpha=255 separately. Strict alpha=255 gives a misleading result: static Milo has **no fully opaque pixel**. His useful silhouette still measures 35×48 because most interior alpha is 253. For the table below, “visible” means alpha≥128, not fully opaque.

| Static right-facing character | Visible bbox on 96×96 | Visible extent | Approximate half-size extent |
| --- | --- | --- | --- |
| Milo | [30,40,65,88] | 35×48 | 18×24 |
| Oliver | [32,22,64,88] | 32×66 | 16×33 |
| Hugo | [28,28,67,88] | 39×60 | 20×30 |
| Felix | [28,34,67,88] | 39×54 | 20×27 |
| Hazel | [32,42,64,88] | 32×46 | 16×23 |
| Pip | [33,50,63,88] | 30×38 | 15×19 |
| Elara | [31,18,64,88] | 33×70 | 17×35 |
| Rin | [28,40,68,88] | 40×48 | 20×24 |

Half extents are rounded descriptions; exact surviving pixels depend on decimation phase. The proof uses a fixed top-left sampling phase, source coordinate `(2x,2y)`. Final exports must lock the phase for the entire clip and hand-restore lost one-pixel features. Source bboxes and all resulting candidate dimensions are machine-readable in the reports.

All 64 clips have their alpha≥128 bottom edge at **88 in all six frames**. This supports the supplied foot anchor; it does not prove the painted feet have natural contact in every pose. Milo's animated idle remains 48 px tall, walk 47–48, run 41–44, jump 40–49. Oliver's idle is 65–66, walk 62–64, run 53–59, jump 50–63. Run lean and jump crouch explain some variation; preserve intentional pose differences and inspect anatomy rather than scaling them away. Other species' clip ranges are in the report; no further chapters are proposed.

Props at alpha≥128: locomotive **228×92** inside 240×96; passenger car **220×64** inside 224×96; bench 92×40; crate 28×28; lantern 13×28; signpost 41×68. At half size locomotive's full cell is **120×48**, passenger car **112×48**. These do **not** match the current authored train rectangle 96×32.

### The three visual proofs — mock composites, not game evidence

1. `mock_320_half.png`: **recommended 320×180**, sprites/locomotive/background ×1/2. Milo feet (159,144), Oliver feet (216,144); character draw origin feet−(24,44). Locomotive frame placed at (12,97), bottom pivot y47 on y144.
2. `mock_640_native.png`: **alternative 640×360**, native sprites/background, all proof positions doubled. Same relative composition, finer source texture; illustrates what a coordinated doubled-unit migration would buy.
3. `mock_320_third.png`: 320×180, background ×1/2, characters/locomotive ×1/3, provisional feet pivot (16,29). Illustrates the readability sacrificed to match the current collision silhouette.

Each image carries **MOCK / NOT IN GAME** lettering. All three include a simple **original procedural foreground staging band**, covering source scenery from y120 down (or y240 at 640), with a floor at y144/y288 and schematic rails. This band is an alignment aid, not finished environment art or a proposed new collision map. The raw forest's painted path is higher than the runtime floor and its lower section contains water/embankment, so an untouched matte is not a walkable level. These compositions do not use the authored train/branch positions and do not prove they fit together; they isolate scale. The raw backgrounds remain visible in `environment_contact.png`.

## 3. Style and animation audit

**Keep:** warm orange/cream animal silhouettes, dark indigo outlines, red scarves, earthy travel clothes, burgundy Brass and amber windows. Across all six backgrounds, autumn foliage, violet/coral sunsets, dark pine silhouettes and warm lanterns support a coherent illustrated world. The historical sheet supports that broad direction; use it as a reference, not something to extract or reproduce wholesale.

**Normalize:** characters are comparatively clean, bright chibi figures; backgrounds and the train contain very dense multicolored texture and finer apparent clusters. Half sampling reduces detail but does not turn an AI illustration into a controlled pixel grid. Redraw isolated highlights, simplify leaf/stone noise, make outlines a consistent final-resolution one pixel, and keep the walkable plane quieter than the scenery. Avoid more high-frequency detail in mandatory props than Milo's face can support.

**Creative discrepancies for Opus:** supplied Milo wears a red scarf/backpack and has no conductor cap, while the canonical bible requests a navy cap. The story/gameplay draft explicitly proposes scarf/backpack and defers a cap. That draft is marked a proposal; this audit does not silently accept it. Pick one model sheet before cleanup. Oliver is a scarf/backpack rabbit but lacks the Chapter 1 flowerpot and umbrella. Neither static poses nor the generic walk cycle supplies flowerpot-carrying performance. The station source has a blank/indistinct sign area; add legible authored “Willow Creek” only if the naming adaptation is accepted, otherwise keep the approved Chapter 1 location wording. Do not bake invented letters into the art.

Static and animation designs are recognizably related, but their head angle, muzzle, backpack straps, scarf contours, highlights and outline clusters drift. Milo's animation first frame differs from his static pose; choose **one approved animation master**, and derive idle/static portraits from that cleaned master instead of switching to the unrelated static image when stopped. Oliver's ear/face and bag shapes need the same treatment. Contact sheets show the six idle frames are broadly similar poses, yet surface detail changes enough to risk shimmer.

Quantitative support: unregistered exact RGBA differs on roughly 99–100% of visible-union pixels between many adjacent frames. That number includes tiny RGB/alpha noise and is **not** a useful standalone animation-quality verdict. With alpha thresholded and RGB grouped into 32-step bins, Milo idle still changes about **37–60%** of visible-union pixels while its silhouette changes about **2–7%**; Oliver idle changes about **42–60%** with about **2–7%** silhouette change. This supports a cleanup priority for material/color stability, not a claim that every changed pixel is wrong. Last→first transitions are included in the report even for jump; the jump wrap comparison is diagnostic only, never a runtime loop.

**Left frames:** all **32/32 right-facing clips** match their left files under exact decoded RGBA horizontal reflection. The export is mirrored, not separately animated. Import right strips only initially and flip at runtime. Backpacks, scarf overlap and any later flowerpot swap sides under this policy. If those details must remain on a fixed anatomical side, draw independent left frames and give them their own IDs; do not claim the current files solve that problem.

### Alpha remediation

| Sample | Alpha 1–127 | Alpha 128–249 | Alpha 250–254 | Alpha 255 |
| --- | ---: | ---: | ---: | ---: |
| Static Milo | 51 | 4 | 1,025 | 0 |
| Animated Milo idle 00 | 229 | 149 | 965 | 0 |
| Static Oliver | 65 | 20 | 1,320 | 14 |
| Locomotive | 832 | 362 | 14,774 | 25 |

Counts are source-resolution pixels. Near-opaque interiors usually have alpha 253, so “almost every sprite pixel has partial alpha” does not mean almost every pixel has a visible halo. The low/mid-alpha fringes are the more important contour problem. Runtime point filtering cannot remove authored transparency.

Review-only candidates snap alpha≥128 to 255 and everything else to 0; RGB of transparent pixels becomes zero. **This threshold is a proof operation, not final cleanup.** At final resolution restore holes, whiskers, paws, handle cutout and wheel spokes by hand. Inspect black/white/night mattes at 1× and 4×; remove bright/dark premultiplied-looking fringes without asserting that these files are premultiplied. Keep solid foreground sprites binary-alpha. Weather/smoke/glow may use a separately approved translucent layer; do not bake those effects into silhouette edges. Never alpha-threshold or color-key the opaque RGB backgrounds.

## 4. Palette extraction and proposed lock

The sources are not palette-indexed production pixel art. Static Milo has **726** distinct RGB colors among alpha≥128 pixels; animated idle 00 has **1,021**; the locomotive **9,074**. Forest has **101,802** distinct opaque RGB colors, station **97,276**, rivertown **125,686**, interior **76,159**. Counting only alpha 255 would wrongly report Milo as having zero colors.

The report groups qualifying pixels by 16-value RGB buckets; swatches use bucket centers. These are **sampled statistical bins**, not exact authored colors or a finished palette:

| Asset | Six most frequent sampled bins, descending |
| --- | --- |
| Static Milo | #E88838, #F8D8B8, #080818, #080828, #D86828, #B82838 |
| Animated Milo idle 00 | #080818, #F8D8B8, #E88828, #E88838, #080808, #F8D8A8 |
| Static Oliver | #181828, #F8D8C8, #F8E8C8, #E8A878, #F8E8D8, #F8D8B8 |
| Locomotive | #080818, #181828, #080828, #282838, #383848, #681838 |
| Forest | #080808, #080818, #081828, #181828, #283878, #181818 |
| Station | #080818, #080808, #081828, #181828, #180818, #181818 |
| Interior | #281818, #381818, #181818, #180818, #080818, #080808 |

**Proposed Chapter 1 foreground lock: 24 exact colors**, shared by Milo, Oliver, Brass, puzzle props and UI accents. Retain the six existing guide colors:

`#1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA`

Add 18 curated values informed by the samples, not claimed as extracted originals:

`#080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B`

`#452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE`

Map the cleaned master material ramps once; reuse those palette indices across a clip instead of independently quantizing each frame. No automatic dithering on characters or interactables. Use a dark outline and clear shape against both station and forest. Highlight the handle with outline/shape and an explicit interaction prompt, not hue alone.

Backgrounds remain provisional rich-color mattes in the first import review. Manually simplify critical ground/clue areas; do not run a blanket 24-color quantizer over the six backgrounds. If a later restricted background palette is desired, Opus should approve a shared atmospheric extension after comparing a cleaned forest screen; additional colors must be recorded deliberately. This is an explicit difference between the foreground lock and the unapproved background palette, not a claim the whole pack already meets the lock.

## 5. Chapter 1 production list

| Priority | Asset / state | Supplied? | Required work / target |
| --- | --- | --- | --- |
| P0 | Milo idle/walk/jump | Six frames each, plus unnecessary run | Approve cap/scarf model; clean 48×48 cells, pivot 24,44; same silhouette/material ramps; no run mechanic needed |
| P0 | Milo carrying/install/crank | Missing | Original carrying paw pose or overlay; simple install/crank pose; held handle must attach to an explicit hand socket, never appear twice |
| P0 | Oliver idle/walk + flowerpot | Generic cycles exist; flowerpot carry missing | Clean 48×48; add readable paper-wrapped pot and carrying stance; umbrella only if rainy intro retained |
| P0 | Brass locomotive + passenger car | 240×96 and 224×96 | Half-size 120×48 and 112×48; simplify windows/wheels; add door-open cue, simple wheel loop/puff if needed for travel; staging/coupling pass |
| P0 | Fallen branch blocked/cleared | Missing | New48×24 cell, top-left pivot 0,0 to match current object; keep rope anchor meaningful as branch moves |
| P0 | Winch / empty socket / installed / turning | Missing | New24×24 cell per state; socket(12,10), rope anchor(4,4); four turning frames initially proposed at 6 fps |
| P0 | Crank handle shelf/held/dropped/installed | Missing | New8×8 silhouette; bottom-centre pivot 4,8; distinctive cutout/highlight; use one logical object and render at its state |
| P0 | Shed + low shelf | Missing | New72×48 non-solid background object; shelf is visibly low and handle unobstructed; handle recovery marker remains reachable |
| P0 | Rope | No standalone sprite | Prefer existing procedural line from authored anchors; add a second shadow pixel only if legibility needs it; never infer puzzle linkage from baked background |
| P0 | Forest gameplay ground / background | Flattened640×360 forest exists | Half matte 320×180; original continuous 640-wide foreground corridor, grounded at 144; quiet clue area; remove/cover conflicting baked path/water |
| P0 | Opening station | Flattened station exists | Half matte; align train/passenger foot line; sign/name decision; staging independent of painted perspective |
| P0 | Clover Market destination | **No dedicated market** | Station-derived short vignette with original flower stall/awning and flower display; label as adaptation until distinct enough; do not rename untouched station art “finished market” |
| P0 | Paper flower keepsake | Missing | New8×8 world icon, optionally 16×16 display cell; distinct folded-paper silhouette on carriage sill; reward logic unchanged |
| P1 | Snail + leaf, wave | Missing | New12×8 snail plus leaf or combined clear states; 2–3 original frames proposed at 4 fps; optional and never gates route |
| P1 | Rain, train light/door/wheel states | Not separate assets | Sparse separate overlays; remove if they obscure handle/rope; no forced animation wait |
| Conditional | Rin intro pose | Rin supplied | Import one cleaned idle only if Opus accepts screenplay intro; do not require full cast for this slice |
| P2 / defer | Bench/crate/lantern/signpost; later passengers and four later environments | Supplied | Use only if a concrete Chapter 1 composition needs them; no later-chapter production or seating system now |

The pack contains no audio files in the inspected inventory. Rain/forest ambience, train idle/wheels/whistle, pickup, crank/branch cues and sparse music still need an original or documented licensed source. This task does not generate audio or license a font. Keep quiet/silent behavior valid while those sources are pending.

## 6. Import and naming pipeline

1. **Freeze evidence.** Keep both user source folders and the historical style reference read only. Record original relative path + SHA-256 in an import receipt. Preserve README, PROMPTS, animation metadata and generation evidence outside the runtime manifest; machine-specific source paths are evidence, not distributable dependencies.
2. **Approve master and rights status.** Opus approves this scale/palette/character direction; user confirms the provenance facts in section 8 before shipping. A schema-valid provenance string is not evidence of permission.
3. **Derive a working copy under scratch.** Use supplied 96×96 frames, common half-scale and fixed nearest sampling phase. Do not re-crop/recenter each frame; do not upscale the earlier pack or generation-size atlases to invent detail. Keep originals immutable.
4. **Hand-clean at 48×48.** Snap binary alpha deliberately; establish one approved head/body/outline/material model, restore lost features, keep feet anchored 24,44. Clean idle first, then walk/jump; compare adjacent frames and loop seam at recorded speed. Export a static idle from the cleaned sequence.
5. **Pack one horizontal strip per action.** Six48×48 frames → **288×48** image. No gutters, rotation, trim packing, extra transparent border or multirow atlas. Character pivot applies to each cell. Separate prop state strips likewise. Background single frame count 1.
6. **Review at actual resolution.** Render at 320×180 then integer 2× minimum-window and 4× desktop scaling. Check feet, focus outline, handle, rope, branch, sprite/collision overlay and UI; test against dark forest and bright market accents. Our composites are supporting art proofs only.
7. **After approval only**, copy cleaned exports into `assets/characters/`, `assets/props/`, `assets/backgrounds/`; compute SHA-256 of the **exact exported bytes**, then create manifest entries and provenance records. Rehash whenever the PNG is edited or recompressed. No generated scratch candidate is production-ready merely because it hashes correctly.
8. Validate and launch through the existing content pipeline. Inspect missing/hash/size failure diagnostics and release packaging from another working directory. Run the relevant M0/M1/M2 native checks after integration. Do not declare a milestone accepted from import success alone.

Naming: stable lowercase snake-case IDs within 64 chars, e.g. `milo_walk_r`, `oliver_idle_r`, `brass_locomotive`, `bg_forest_track`, `winch_turn`. Paths use forward slashes and remain under `assets/`; example `assets/characters/milo_walk_r.png`. Frame ordering is always source 00→05. If individually maintained working frames are needed, keep `milo/walk/r/00.png` etc. in the art working source, not as six separate v1 runtime entries. Never use filenames with “final_final” or generated UUIDs as gameplay identities.

### Clip conventions

| Action | Source fps | Loop | Runtime use |
| --- | ---: | --- | --- |
| idle | 5 | yes | Subtle breathe/blink; pause freezes animation |
| walk | 9 | yes | Physics moves feet; no root motion |
| run | 13 | yes | Present in pack; defer because Chapter 1 has no run control |
| jump | 10 | no | Six phases: crouch, takeoff, rise, apex, descent, landing; physics owns vertical motion |

Use the exact clip metadata from `animations.json`. A literal six-frame jump lasts 0.6s; the current full-hold ballistic arc is approximately 0.75s (112×2/300), with shorter released hops. Do not delay a responsive jump for the crouch drawing or let the six-frame timer loop/land early while airborne. Map takeoff/rise/apex/descent to actual motion, freeze or select an appropriate airborne pose as necessary, then use landing compression on contact; retain 10 fps for local phase transitions where applicable. This is an animation integration choice to verify, not a change to M1 physics. Clean idle/walk frames can be held longer if less motion reads better, but record any approved deviation from source fps explicitly.

**Manifest v1 has no fps, loop, state graph or per-object sprite transform fields.** Do not add those keys to manifest entries: the validator rejects unknown fields. Use a small compiled clip table keyed by stable asset ID for the bounded slice, preserving the fps/loop values above. If editable clip metadata becomes a real requirement, propose a separate versioned extension for Opus; do not silently change the shared contract.

## 7. Proposed manifest entries

`proposed_manifest.review.json` is a full **review specimen** containing nine v1-shaped entries for assets that have supplied sources. It references intended future `assets/` destinations that **do not exist**. Do not replace `data/assets/manifest.json` with it. Its SHA values are real hashes of the corresponding mechanical candidate PNGs under `build/art/candidates/`; they will be obsolete after cleanup. All provenance is explicitly **UNCONFIRMED**. The specimen intentionally has no fps/loop/custom approval fields.

| ID | Future path | Frame size / count | Pivot | Scratch candidate |
| --- | --- | --- | --- | --- |
| milo_idle_r | assets/characters/milo_idle_r.png | 48×48 /6 | 24,44 | candidates/milo_idle_r.png |
| milo_walk_r | assets/characters/milo_walk_r.png | 48×48 /6 | 24,44 | candidates/milo_walk_r.png |
| milo_jump_r | assets/characters/milo_jump_r.png | 48×48 /6 | 24,44 | candidates/milo_jump_r.png |
| oliver_idle_r | assets/characters/oliver_idle_r.png | 48×48 /6 | 24,44 | candidates/oliver_idle_r.png |
| oliver_walk_r | assets/characters/oliver_walk_r.png | 48×48 /6 | 24,44 | candidates/oliver_walk_r.png |
| brass_locomotive | assets/props/locomotive.png | 120×48 /1 | 60,47 | candidates/locomotive.png |
| brass_passenger_car | assets/props/passenger_car.png | 112×48 /1 | 56,47 | candidates/passenger_car.png |
| bg_forest_track | assets/backgrounds/forest_track_matte.png | 320×180 /1 | 0,0 | candidates/forest_track_matte.png |
| bg_willow_creek_station | assets/backgrounds/willow_creek_station_matte.png | 320×180 /1 | 0,0 | candidates/willow_creek_station_matte.png |

Example with the actual uncleaned walk-proof hash (a review example, not an approval to import):

```json
{
  "milo_walk_r": {
    "path": "assets/characters/milo_walk_r.png",
    "sha256": "06cff60c6c11fa24427eaedbbb2e0046285974f708a6d9c9518d8bf4635217be",
    "frame_size": [48, 48],
    "frame_count": 6,
    "pivot": [24, 44],
    "provenance": {
      "creator": "User-supplied generated collection; generating operator and rights holder unconfirmed",
      "source": "Updated pack animations/milo/walk/right/00.png..05.png; nearest 1/2, alpha128, horizontal strip; source hashes in build/art/audit_report.json; NOT hand-cleaned",
      "license": "UNCONFIRMED - confirm tool, applicable terms and reference rights before shipping",
      "attribution": "Unconfirmed; record applicable requirements after rights review"
    }
  }
}
```

New-art entries must be completed from real exports, never invented checksums:

| Planned ID | Proposed future path | Cell/count; pivot | Hash/provenance state |
| --- | --- | --- | --- |
| milo_carry_r | assets/characters/milo_carry_r.png | 48×48 /1;24,44 | Not drawn; record real creator/permissions and final hash |
| milo_crank_r | assets/characters/milo_crank_r.png | 48×48 /2;24,44 | Not drawn; proposed 6 fps loop while Cranking |
| oliver_pot_idle_r | assets/characters/oliver_pot_idle_r.png | 48×48 /1;24,44 | Not drawn; pot/carry model review |
| branch_blocked | assets/props/branch_blocked.png | 48×24 /1;0,0 | Missing; blocked/cleared position comes from runtime, no duplicate object |
| winch_empty | assets/props/winch_empty.png | 24×24 /1;0,0 | Missing |
| winch_installed | assets/props/winch_installed.png | 24×24 /1;0,0 | Missing; use same socket/anchors |
| winch_turn | assets/props/winch_turn.png | 24×24 /4;0,0 | Missing; proposed 6 fps loop |
| crank_handle | assets/props/crank_handle.png | 8×8 /1;4,8 | Missing; attach to socket by pivot or explicit offset |
| tool_shed | assets/props/tool_shed.png | 72×48 /1;0,0 | Missing |
| snail_wave | assets/props/snail_wave.png | 12×8 /3;0,0 | Missing; proposed 4 fps once |
| paper_flower | assets/props/paper_flower.png | 8×8 /1;4,8 | Missing |
| bg_clover_market | assets/backgrounds/clover_market.png | 320×180 /1;0,0 | Missing; station adaptation plus original stall, exact derivation logged |
| forest_foreground | assets/backgrounds/forest_foreground.png | 640×60 /1;0,0 | Missing; original continuous ground strip, top y120, walking plane y144 |

A 640×60 single-frame foreground remains a single horizontal strip with frame_count 1. These rows are planning metadata, not valid manifest entries until actual bytes, hashes and truthful provenance exist. Umbrella, leaf and flower-stall parts can be folded into approved combined compositions to avoid unnecessary runtime entities. No absent-source hash has been fabricated.

## 8. Provenance and release questions

**Known from local evidence:** README says the collection was generated individually using a “built-in image_gen tool,” guided by user-supplied cat/world sheets, and is reference-guided regeneration rather than exact extraction. PROMPTS records generated character/prop/background and animation requests. Manifest records generation-source paths, dimensions and hashes. Source-resolution images and animation atlases are present. Left frames are mirrors, confirmed by decoded comparison. Neither a license grant nor applicable provider terms is included in these records. The prompt's requested style and originality are not a license.

**User must confirm before shipping:**

1. Exact generating tool/provider/product and, if available, model/version; generation dates; operator/account that generated or commissioned the output. “image_gen” alone does not establish those facts.
2. Applicable terms/version at those dates and for that account/product, including the relevant commercial distribution, modification, attribution and other conditions. Keep a source URL or retained terms/permission record; this audit has not identified or verified those terms.
3. Ownership or permission for the supplied cat/world sheets and other visual references, including the historical kit sheet; whether all third-party inputs may be used for the intended game and derivatives. We cannot infer that from possession of the files.
4. Who may authorize distributing the generated outputs and cleaned derivatives; any collaborator/artist agreement and required credits. Record the human cleanup artist and change history separately.
5. Any publication or storefront disclosure required by the applicable terms/platform for this release. Do not invent a universal disclosure requirement or assert an exemption.

No MIT, CC0, public-domain, royalty-free, “commercial rights confirmed” or exclusive-ownership claim is made here. Tool names and local hashes establish traceability, not licensing. Keep the external materials out of the shipping asset set until the relevant permission record is settled. This is the requested provenance accounting, not a legal conclusion about their eligibility.

### Proposed `assets/ASSET_LICENSES.md` text — for Opus to apply

> # Asset provenance register
>
> Runtime prototype graphics are procedural raylib shapes. The external `the-last-stop-assets-sprits-images-Updated` collection was audited as source material; an audit or scratch derivative does not mean it is bundled or approved for distribution.
>
> The collection README describes reference-guided generation using a built-in `image_gen` tool and user-supplied character/world sheets. Exact provider/product, operator, generation date, applicable terms and reference permissions remain unconfirmed. No open-source or public-domain license is assigned by this project. Confirm and retain the relevant permission/terms record before shipping any derived assets.
>
> For each imported file, record: runtime path and final SHA-256; human creator/operator and cleanup artist; original source path/hash; generating tool/product/model/date where known; applicable license/permission with evidence location; modifications; required attribution/disclosure. Preserve unknown values explicitly and block release use until resolved. Source metadata may live in a retained import receipt; runtime manifest provenance remains the four v1 strings.
>
> No external audio or font license is established by the art pack. Register audio/fonts separately. Never infer a license from a generation prompt or from the file being user-supplied.

Suggested first register row **after an actual import**, completed with real facts:

`assets/characters/milo_walk_r.png | [final exported SHA-256] | [operator; cleanup artist] | updated pack walk/right/00..05 + original hashes | [confirmed terms/permission evidence, or UNCONFIRMED / DO NOT SHIP] | 1/2 nearest, palette/alpha/pixel cleanup, strip export | [confirmed attribution requirement]`

Do not paste this placeholder row as if it describes a completed import.

### Proposed `docs/ART_AUDIO_GUIDE.md` text — for Opus to apply

> # Pixel art, animation and audio guide
>
> Use a 320×180 logical stage, nearest/point filtering, no mipmaps, integer window scaling and integer draw positions. Physics remains floating point with a 12×16 bottom-centre Milo collision box. Art bounds may extend beyond collision; verify floor contact and wall/head overhang in the native game.
>
> Updated source characters are 96×96 with feet at 48,88. Production character cells are 48×48, pivot 24,44, derived by a fixed 1/2 nearest sample and hand-cleaned at final resolution. Pack each action as a single horizontal strip; never normalize individual frame bboxes or stretch the full transparent canvas into collision bounds. Source idle 5 fps, walk 9 fps, run 13 fps are looping; jump 10 fps is non-looping and must follow actual jump phases without delaying physics. Do not add run gameplay for the sake of an available clip. Initially flip right-facing art at runtime; independently drawn left art is required if equipment must retain handedness.
>
> Lock foreground materials to the 24-color palette in the approved T-ART-1 proposal. Reuse cleaned material ramps across frames. Solid sprites use binary alpha; inspect against black, white and night. Backgrounds are provisional rich-color mattes until a separate palette/cleanup pass is approved. Favor quiet ground, clear silhouettes and readable shape/outline clues over texture density.
>
> Flattened640×360 backgrounds become 320×180 mattes; they are neither collision maps, repeatable tiles nor separated parallax layers. Author the puzzle foreground for the actual 640×180 world and y144 floor. Do not stretch a single screen to fill two screens. First integration may use a stationary distant matte and an original continuous foreground. Add parallax only to genuinely separated/redrawn layers with repaired occlusion holes.
>
> Chapter 1 priority: cleaned Milo/Oliver, Brass/boarding cue, branch/winch/socket/handle/shed, forest ground, opening station, distinct market stall and paper-flower payoff; snail/leaf is optional. Preserve unique handle state and press-once cranking. Resolve the cap/scarf design and opening location wording with Opus before creating model sheets. Later cast/environments are deferred.
>
> Keep UI text at the established readable virtual sizes and contrast; do not shrink text to accommodate art. Check the minimum 640×360 window and integer scaling. Use explicit prompts and shape changes in addition to color. Pause freezes animation. No mandatory animation delay, flicker or button mashing.
>
> Quiet audio priorities remain rain/forest, train rhythm/whistle, pickup/crank/branch cues, then sparse music. The supplied art pack establishes no audio/font rights. Keep silent operation valid until recorded original/licensed sources exist, and retain provenance for every external asset.

## 9. Runtime/editor integration tasks for the implementer

These are proposed interface/implementation tasks; none was applied here.

1. **Preserve current coordinate contract.** Keep VIRTUAL_WIDTH320/VIRTUAL_HEIGHT180, player 12×16, world/camera `[0,0,640,180]`, ground `[0,144,640,36]`, spawns, interactions and M1 tuning. Camera x range remains 0..320 and vertical origin 0. Artwork changes must not alter reachability or M2 save normalization. A later layout change requires normal validation and retesting.
2. **Use existing staged texture loader.** Live `src/content_adapter.odin` already decodes validated snapshot bytes after window creation, checks `image.width == frame_width * frame_count` and `image.height == frame_height`, uploads textures, applies `.POINT`, and unloads resources. Live shared loader verifies SHA-256. Extend/reuse this path; do not duplicate it with cwd-relative texture loads. Keep no-mipmap textures and render target point-filtered. Failed resources must not produce a partial chapter or replace the active validated content/resources pair.
3. **Add a native-size pivot draw helper.** Select source rectangle `(frame_index*frame_w,0,frame_w,frame_h)`. Draw exactly one cell at integer pixel size, anchored by pivot to rounded feet/object anchor minus rounded camera; do not stretch a 48×48 character cell over 12×16. Match the existing `pixel(world)-pixel(camera)` convention to avoid sprite/rope/collision jitter. For Milo: top-left = rounded feet−(24,44)−rounded camera. Rendering does not modify physics.
4. **Implement mirroring carefully.** Flip source U coordinates (the raylib negative-source-width convention, verified against installed bindings/native output during implementation). Keep the geometric feet anchor at 24,44. For independently authored asymmetric pivots, mirror continuous pivot x to `frame_w−pivot_x`; do not mix this with the pixel-index formula `frame_w−1−x`. The export's mirrored sampled silhouette can differ by one pixel under decimation; final left/right footprint must be reviewed. Do not both load the mirrored left frame and flip it again.
5. **Introduce a bounded clip table/timer.** Stable asset ID→fps/loop/frame count; advance only during active play/cutscene time and freeze on pause. Frame index is clamped for nonlooping actions; save durable gameplay state, not texture pointers/timers. Select idle/walk from movement and grounded state, jump by motion phase; keep gestures subordinate to interaction results. No animation graph/ECS needed.
6. **Remove visible placeholder fills only when replacement draws.** Current draw_scene draws graybox rectangles before textures and always draws rectangle Milo. Transparent padding must not reveal a debug rectangle behind production art. Keep collision/focus overlays under DEV_TOOLS and preserve clear fallback/error behavior for intentional absent assets. Handle rendering currently remains procedural; replace it by enum location, with one drawing only, while rope remains anchored to runtime branch/winch.
7. **Respect actual layer order.** Background matte → shed/ground → train/branch/winch/loose handle/NPC → Milo with held handle → approved foreground occluders → focus affordance/UI. Honor authored `background/world/foreground` and stable-ID ties. Do not allow a last-drawn flattened foreground to hide the handle or rope. If Milo must pass behind carriage windows/furniture, separate/redraw the occluding layer first; the current exterior/interior art cannot expose arbitrary passengers through baked pixels.
8. **Resolve train visual bounds and boarding legibility before acceptance.** A120×48 cell with pivot 60,47 is not a 96×32 authored object. A bottom-centre anchor on the current train rectangle yields frame left 4/top 97 and visible art extending toward the branch, whose current rectangle startsx 96. The graybox train/branch already overlap in x. Do not nonuniformly squash the locomotive or silently change its interaction box. Choose an explicitly reviewed render placement/partial offscreen train composition, or deliberately re-stage non-solid train/branch art through content edits with preserved IDs and validated anchors. Show where boarding happens; a focus rectangle at the locomotive nose does not prove a painted cab door is usable. Passenger car coupling and total length need a separate staging pass. The mock isolates scale and does not resolve this layout.
9. **Treat scenery as art, not navigation.** The half-size forest matte covers one 320-pixel view, while the puzzle spans 640 world pixels. For the first batch, use it as a fixed screen-space distant matte with no claimed parallax; author one continuous 640×60 world-space foreground starting at y120, with contact at 144. This is a restrained staging compromise and still needs visual review at both camera clamps. Do not stretch 320→640 or butt-repeat a nonseamless image. True scrolling/parallax needs separated sky/mountains/trees and repaired holes, or new scene-wide background art. Moving the entire flattened image at multiple depths duplicates baked tracks/lamps and is not separation.
10. **Keep text and screen furniture readable.** Current top 28 px hint area, bottom interaction panel beginning at y 151, response area near 33, and save message near y 137 constrain staging. Milo at ground 144 has a roughly 120..144 silhouette, but carry art and focus prompts may collide with the save line. Plan overlays deliberately; do not reduce font sizes to squeeze them around art. At minimum window 640×360 current 10 virtual-pixel text becomes 20 screen pixels. Do not bake UI labels into backgrounds.
11. **Share the draw semantics with the editor.** Editor previews need source-frame dimensions, transparent padding, pivot, mirror and native display size; selection/collision geometry stays distinct from art bounds. Do not implement an editor-only fit-to-rectangle convention that disagrees with native output. Keep fps out of v1 manifest and retain truthful preview labeling.
12. **Verify the integration as a separate task.** Validate exact hashes/strip dimensions/pivots and provenance; check loops at source speeds; inspect at 320×180,640×360 and 1280×720; run both camera clamps, wall/step/jump/held-handle poses, all handle states, branch movement and return. Run current compilation/content tests and relevant M1/M2 regressions after edits. Native screenshot and human feel/readability checks remain distinct. Verify packaged resources and unload/reload behavior. No such runtime acceptance is claimed by this audit.

## 10. Handoff and proposed central update

**Completed:** source/style/scale/provenance audit; measured inventory and alpha/palette/animation reports; recommended 320×180 half-scale pipeline and alternatives; three labelled mock composites; review-only strips and v1 manifest specimen; Chapter 1 missing-art priorities; proposed guide/license text and integration tasks.

**Verification:** `python3 -B build/art/audit_art.py` and `python3 -B build/art/verify_art.py` both exited 0. It decoded all 412 primary PNGs, verified PNG CRCs, matched 440/440 manifest hashes, confirmed 48/48 common old/current PNG bytes and 32/32 mirrored right/left clips. Contact sheets, palette/alpha sheets and all three composites were visually inspected. Review candidate dimension/hash/alpha verification is recorded in `verification.json` after the final audit. No game code/content edit, native run, compile, human playtest, shipping-rights confirmation or Opus acceptance occurred.

**Acceptance:** PASS for bounded proposal/evidence delivery and read-only source handling; PASS for inventory, measured scale alternatives, palette/alpha/animation audit, Chapter 1 gap list, v1 pipeline/manifest examples and runtime task list. UNVERIFIED for hand-cleaned production quality, final train/branch/boarding layout, in-game readability, legal permission and approval. Proposed central status: “T-ART-1 delivered for review; no assets imported; M5 presentation remains unaccepted.”

**Risks:** high release impact—unconfirmed generation/reference permissions; high presentation impact—missing required puzzle/market art and art-vs-floor mismatch; medium—generated frame shimmer/alpha fringes, train/branch visual overlap, mirrored equipment and unreadable small features. These are reproducible in the source sheets/reports or live renderer geometry; no crash or gameplay regression is asserted.

**Exact proposed central log/build-note update for Opus:**

> T-ART-1 / GPT-6.1 Sol / Game at 977efc4: delivered `build/art/ART_PIPELINE_PROPOSAL.md`, reproducible stdlib audit, three labelled mock composites, contacts/palettes/alpha evidence and review-only candidate strips/manifest. Recommended 320×180 with fixed 1/2 nearest conversion plus final-resolution hand cleanup; retain 12×16 physics and current geometry. 440/440 source checksums match; supplied left clips are mirrors. No production imports, runtime edits, compile/native playtest or release-rights approval. Await Opus scale/model/palette decision; then assign bounded cleanup of Milo/Oliver/Brass and original Chapter 1 puzzle/market art, followed by coordinated renderer/editor integration. M5 remains open.

**Next/dependencies:** Opus approves or amends scale, cap/scarf/location direction, foreground palette and staging approach. Confirm rights evidence before shipping. Assign cleanup/new-art work first, then coordinated runtime/editor integration; preserve current M1/M2 acceptance boundaries. Do not bulk-import all 440 sources or start later chapters.
