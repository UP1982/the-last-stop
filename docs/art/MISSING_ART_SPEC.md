# Chapter 1 missing-art commission spec — T-ART-2

2026-10-16. Native **640×360** game scale, as chosen in docs/art/DECISION.md. These dimensions supersede the historical half-scale proposal and the old 320×180 clause in STORY_CONTRACT section 6. All dimensions are **final exported pixels**, not generation-preview pixels. These are art commission targets, not changes to actor enums, collision, authored geometry or assets v1. None of this missing art has been generated or registered by this spec.

## Shared production rules

- Attach the relevant imported right-facing idle frame and build/art/palette_swatches.png to each prompt. For props attach Brass/station/forest references. Use animated frame 00 as character master, not the different static export. Milo has scarf/backpack and no cap; Oliver has scarf/bag and wrapped flowerpot; Rin has tool satchel.
- Palette swatches are measured 16-value RGB bin centers, not original palette indices. Sampled colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. New foreground working palette, pending final art approval: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Imported batch 1 is intentionally unquantized. Opaque scenery may retain richer twilight/forest ramps; simplify noise behind clues.
- Pivots are integer coordinates from cell top-left and strictly inside the frame. Standing actors use 96×96 cells, pivot (48,88); visible height about 48px for Milo/Rin, 66px for Oliver. Tiny-prop bottom pivots use last pixel row h−1 rather than the out-of-frame h used in older examples.
- Multi-frame output is ONE horizontal strip: width = cell width × frame count, unchanged cell height. Order below is left→right, no gutters, trim packing, extra borders or multirow atlases. No frame-specific crop, normalization or root motion. Runtime controls movement/jump height.
- Transparent foreground uses alpha 0/255, deliberate dark outline and consistent material ramps. Opaque means every pixel alpha 255. Hand-clean tiny holes/whiskers/spokes and compare black/white/night mattes. If generation ignores exact size, reject/re-author; do not resample a whole sprite or recenter each frame.
- All prompts below are complete and ready to paste after attaching references, modeled on source PROMPTS.json. Signs require manual spelling and bitmap lettering verification. Notices/timetables use exact authored UI text over blank art; never substitute generated pseudo-letters.
- Combined Oliver-with-pot and Rin-with-slat poses include exactly one prop and suppress standalone drawing. Milo held handle remains separate; fitted winch becomes its sole visual owner. Rear seat and foreground lip share origin and occlude actor in separate layers.
- Right poses mirror at runtime for left, including straps/bags; lettering never mirrors. Independent left art requires new IDs/review if a fixed anatomical side is needed. Suggested sockets and timings are commissioning metadata until later runtime integration; do not extend assets v1.
- Proposed fps never creates forced waits or mandatory hold input. Two or three still poses can convey the required story meanings.

## Priority and scope

P0: first puzzle/readable-train batch. P1: flower story, opening/location props and performances. P2: optional-player delight and bespoke presentation. Snail interaction is optional, but its art is still in the Chapter 1 content brief.

Flattened forest and station mattes imported in batch 1 are not finished gameplay staging. Continuous foreground must meet world floor y288; market needs deliberate dressing; second platform needs a distinct view. Source props/bench.png (96×48) and backgrounds/train_interior.png (640×360) exist but are **not imported in batch 1**: later import/adapt with their real hashes. Bench base needs no new generation; loose slat and interior layers do. Caption art, lettering and future fonts need actual readable coverage, not an image-generation promise.

| Priority | Planned ID | Cell px | Frames / strip px | Pivot | Alpha |
|---|---|---:|---:|---:|---|
| P0 | `tool_shelter` | 144×96 | 1 / 144×96 | (0,0) | transparent |
| P0 | `winch_empty` | 48×48 | 1 / 48×48 | (0,0) | transparent |
| P0 | `winch_fitted` | 48×48 | 1 / 48×48 | (0,0) | transparent |
| P0 | `crank_handle` | 16×16 | 1 / 16×16 | (8,15) | transparent |
| P0 | `branch_blocked` | 96×48 | 1 / 96×48 | (0,0) | transparent |
| P0 | `rope_segment` | 128×8 | 1 / 128×8 | (0,4) | transparent |
| P0 | `branch_support` | 112×32 | 1 / 112×32 | (0,0) | transparent |
| P0 | `forest_foreground` | 1280×120 | 1 / 1280×120 | (0,0) | transparent |
| P0 | `milo_carry_r` | 96×96 | 1 / 96×96 | (48,88) | transparent |
| P0 | `milo_interact_r` | 96×96 | 2 / 192×96 | (48,88) | transparent |
| P0 | `milo_crank_r` | 96×96 | 2 / 192×96 | (48,88) | transparent |
| P0 | `winch_turn` | 48×48 | 4 / 192×48 | (0,0) | transparent |
| P0 | `brass_door` | 32×64 | 2 / 64×64 | (16,62) | transparent |
| P0 | `brass_steam` | 64×48 | 3 / 192×48 | (32,46) | transparent |
| P1 | `flowerpot_bud` | 24×40 | 1 / 24×40 | (12,39) | transparent |
| P1 | `flowerpot_bloom` | 24×40 | 1 / 24×40 | (12,39) | transparent |
| P1 | `wrapping_paper` | 24×16 | 1 / 24×16 | (12,15) | transparent |
| P1 | `paper_flower` | 16×16 | 1 / 16×16 | (8,15) | transparent |
| P1 | `oliver_pot_idle_r` | 96×96 | 1 / 96×96 | (48,88) | transparent |
| P1 | `oliver_pot_walk_r` | 96×96 | 6 / 576×96 | (48,88) | transparent |
| P1 | `oliver_board_r` | 96×96 | 2 / 192×96 | (48,88) | transparent |
| P1 | `oliver_seated_r` | 96×96 | 2 / 192×96 | (48,88) | transparent |
| P1 | `oliver_pot_look_r` | 96×96 | 1 / 96×96 | (48,88) | transparent |
| P1 | `oliver_bloom_show_r` | 96×96 | 2 / 192×96 | (48,88) | transparent |
| P1 | `oliver_fold_r` | 96×96 | 3 / 288×96 | (48,88) | transparent |
| P1 | `oliver_place_r` | 96×96 | 2 / 192×96 | (48,88) | transparent |
| P1 | `milo_petal_tap_r` | 96×96 | 3 / 288×96 | (48,88) | transparent |
| P1 | `market_stall` | 192×128 | 1 / 192×128 | (0,0) | transparent |
| P1 | `market_awning` | 192×48 | 1 / 192×48 | (0,0) | transparent |
| P1 | `supper_notice` | 96×128 | 1 / 96×128 | (0,0) | opaque |
| P1 | `carriage_seat` | 128×96 | 1 / 128×96 | (0,0) | transparent |
| P1 | `carriage_seat_front` | 128×96 | 1 / 128×96 | (0,0) | transparent |
| P1 | `carriage_windowsill` | 160×32 | 1 / 160×32 | (0,0) | transparent |
| P1 | `bg_carriage_story` | 640×360 | 1 / 640×360 | (0,0) | opaque |
| P1 | `bg_clover_market` | 640×360 | 1 / 640×360 | (0,0) | opaque |
| P1 | `willow_creek_sign` | 128×32 | 1 / 128×32 | (0,0) | transparent |
| P1 | `last_stop_sign` | 128×32 | 1 / 128×32 | (0,0) | transparent |
| P1 | `bench_slat` | 48×8 | 1 / 48×8 | (24,7) | transparent |
| P1 | `timetable` | 48×64 | 1 / 48×64 | (0,0) | transparent |
| P1 | `bg_unused_platform` | 640×360 | 1 / 640×360 | (0,0) | opaque |
| P1 | `milo_nod_r` | 96×96 | 2 / 192×96 | (48,88) | transparent |
| P1 | `milo_point_r` | 96×96 | 1 / 96×96 | (48,88) | transparent |
| P1 | `milo_reach_catch_r` | 96×96 | 3 / 288×96 | (48,88) | transparent |
| P1 | `milo_wave_r` | 96×96 | 3 / 288×96 | (48,88) | transparent |
| P1 | `oliver_caught_ear_r` | 96×96 | 3 / 288×96 | (48,88) | transparent |
| P1 | `rin_satchel_r` | 96×96 | 1 / 96×96 | (48,88) | transparent |
| P1 | `rin_slat_hold_r` | 96×96 | 1 / 96×96 | (48,88) | transparent |
| P1 | `rin_slat_rest_r` | 96×96 | 1 / 96×96 | (48,88) | transparent |
| P1 | `rin_wave_r` | 96×96 | 3 / 288×96 | (48,88) | transparent |
| P2 | `snail_leaf_wave` | 24×16 | 3 / 72×16 | (12,15) | transparent |
| P2 | `ui_glyph_sheet` | 256×128 | 1 / 256×128 | (0,0) | transparent |

## 01. P0 — Open tool shelter / shed with low shelf

**Planned ID:** `tool_shelter` · **Cell:** 144×96 px · **Frame count:** 1 · **Strip:** 144×96 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One open-front timber railway tool shelter, unlocked, weathered roof, empty low shelf. Shelf top y64; separate handle pivot target (58,64). Warm station timber, quiet interior, no baked handle, closed door, collision or scenery.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 144x96 pixels, each frame 144x96 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One open-front timber railway tool shelter, unlocked, weathered roof, empty low shelf. Shelf top y64; separate handle pivot target (58,64). Warm station timber, quiet interior, no baked handle, closed door, collision or scenery. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 02. P0 — Winch with empty socket

**Planned ID:** `winch_empty` · **Cell:** 48×48 px · **Frame count:** 1 · **Strip:** 48×48 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One small fixed hand-cranked branch lift, dark iron housing, brass rim around conspicuously empty square socket. Socket center (24,20), rope anchor (8,8), base y46. Empty hole and outline explain missing handle without color-only clues.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 48x48 pixels, each frame 48x48 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One small fixed hand-cranked branch lift, dark iron housing, brass rim around conspicuously empty square socket. Socket center (24,20), rope anchor (8,8), base y46. Empty hole and outline explain missing handle without color-only clues. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 03. P0 — Winch fitted state

**Planned ID:** `winch_fitted` · **Cell:** 48×48 px · **Frame count:** 1 · **Strip:** 48×48 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** The exact winch_empty with ONE L-shaped removable handle installed. Housing pixels unchanged, socket (24,20), rope anchor (8,8), base y46. Runtime replaces standalone handle on install; no baked rope.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 48x48 pixels, each frame 48x48 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: The exact winch_empty with ONE L-shaped removable handle installed. Housing pixels unchanged, socket (24,20), rope anchor (8,8), base y46. Runtime replaces standalone handle on install; no baked rope. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 04. P0 — Unique crank handle master

**Planned ID:** `crank_handle` · **Cell:** 16×16 px · **Frame count:** 1 · **Strip:** 16×16 px · **Pivot:** (8,15) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One unmistakable L-shaped iron crank handle, brass edge, square connector, open grip cutout. Two-pixel negative grip gap, dark outline. Connector (4,4), bottom pivot (8,15) inside canvas. Same sprite for shelf/held/dropped; never make a second logical handle.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 16x16 pixels, each frame 16x16 pixels, pivot (8,15) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One unmistakable L-shaped iron crank handle, brass edge, square connector, open grip cutout. Two-pixel negative grip gap, dark outline. Connector (4,4), bottom pivot (8,15) inside canvas. Same sprite for shelf/held/dropped; never make a second logical handle. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 05. P0 — Fallen branch, reused when cleared

**Planned ID:** `branch_blocked` · **Cell:** 96×48 px · **Frame count:** 1 · **Strip:** 96×48 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One forked fallen branch, chunky dark bark, short twig tips, main trunk resting at y44, rope tie at (44,10). No rails or rope baked in. Runtime moves same branch into support when cleared; no duplicate branch or snapped-trunk state.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 96x48 pixels, each frame 96x48 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One forked fallen branch, chunky dark bark, short twig tips, main trunk resting at y44, rope tie at (44,10). No rails or rope baked in. Runtime moves same branch into support when cleared; no duplicate branch or snapped-trunk state. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 06. P0 — Rope texture and attachment reference

**Planned ID:** `rope_segment` · **Cell:** 128×8 px · **Frame count:** 1 · **Strip:** 128×8 px · **Pivot:** (0,4) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One straight horizontal tan braided rope, two-pixel readable core and dark lower edge, centerline y4, endpoints (0,4) and (127,4). No knots/coils. Runtime draws between authored anchors or tiles without resampling; 128px is a material strip, not fixed world distance.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 128x8 pixels, each frame 128x8 pixels, pivot (0,4) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One straight horizontal tan braided rope, two-pixel readable core and dark lower edge, centerline y4, endpoints (0,4) and (127,4). No knots/coils. Runtime draws between authored anchors or tiles without resampling; 128px is a material strip, not fixed world distance. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 07. P0 — Cleared-branch recess / support

**Planned ID:** `branch_support` · **Cell:** 112×32 px · **Frame count:** 1 · **Strip:** 112×32 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One shallow earth-and-timber recess with forked low support visibly cradling the lifted branch. Contact (56,14), lowest edge y30; center open for separate branch. Stable support, no branch baked in, walking corridor stays clear.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 112x32 pixels, each frame 112x32 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One shallow earth-and-timber recess with forked low support visibly cradling the lifted branch. Contact (56,14), lowest edge y30; center open for separate branch. Stable support, no branch baked in, walking corridor stays clear. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 08. P0 — Continuous gameplay ground

**Planned ID:** `forest_foreground` · **Cell:** 1280×120 px · **Frame count:** 1 · **Strip:** 1280×120 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One continuous side-view forest railway embankment, quiet soil, sparse moss, ties and level walking band. Place at world (0,240): local floor y48 becomes world y288. Transparent above ground, opaque below. No water crossing floor, actors, handle, shed, winch or branch. Single panorama, not a collision map.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 1280x120 pixels, each frame 1280x120 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One continuous side-view forest railway embankment, quiet soil, sparse moss, ties and level walking band. Place at world (0,240): local floor y48 becomes world y288. Transparent above ground, opaque below. No water crossing floor, actors, handle, shed, winch or branch. Single panorama, not a collision map. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 09. P0 — Milo carrying crank attachment pose

**Planned ID:** `milo_carry_r` · **Cell:** 96×96 px · **Frame count:** 1 · **Strip:** 96×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** Milo holds both paws at waist height to carry a crank; OMIT crank so it is separately rendered once. Grip/handle pivot socket (62,66). Keep scarf/backpack shape and feet fixed.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 96x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Milo, the imported ginger tabby cat with cream muzzle/belly/feet, red scarf and brown backpack, NO cap, upright on TWO legs facing RIGHT. Use milo_idle_r frame 00 as master, visible height about 48px, feet (48,88). Subject, ordered states and technical staging: Milo holds both paws at waist height to carry a crank; OMIT crank so it is separately rendered once. Grip/handle pivot socket (62,66). Keep scarf/backpack shape and feet fixed. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 10. P0 — Milo reach / install interaction

**Planned ID:** `milo_interact_r` · **Cell:** 96×96 px · **Frame count:** 2 · **Strip:** 192×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** 6 fps once.

**Style / staging:** Milo frame 0 reaches to winch, frame 1 gently presses handle into socket. Hand endpoints (68,66) then (70,66). Empty paws, no hardware; runtime owns handle transfer. Feet fixed, no forced movement lock.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 2 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 192x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Milo, the imported ginger tabby cat with cream muzzle/belly/feet, red scarf and brown backpack, NO cap, upright on TWO legs facing RIGHT. Use milo_idle_r frame 00 as master, visible height about 48px, feet (48,88). Subject, ordered states and technical staging: Milo frame 0 reaches to winch, frame 1 gently presses handle into socket. Hand endpoints (68,66) then (70,66). Empty paws, no hardware; runtime owns handle transfer. Feet fixed, no forced movement lock. Playback intent: 6 fps once. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 11. P0 — Milo cranking feedback

**Planned ID:** `milo_crank_r` · **Cell:** 96×96 px · **Frame count:** 2 · **Strip:** 192×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** 6 fps loop while operating.

**Style / staging:** Milo gentle two-phase crank arms: grip high (68,62), then low (68,70). No handle/winch baked in, tiny body motion. Feedback only, never requires held input or locks movement.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 2 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 192x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Milo, the imported ginger tabby cat with cream muzzle/belly/feet, red scarf and brown backpack, NO cap, upright on TWO legs facing RIGHT. Use milo_idle_r frame 00 as master, visible height about 48px, feet (48,88). Subject, ordered states and technical staging: Milo gentle two-phase crank arms: grip high (68,62), then low (68,70). No handle/winch baked in, tiny body motion. Feedback only, never requires held input or locks movement. Playback intent: 6 fps loop while operating. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 12. P0 — Winch turning strip

**Planned ID:** `winch_turn` · **Cell:** 48×48 px · **Frame count:** 4 · **Strip:** 192×48 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** 6 fps loop.

**Style / staging:** Same fitted winch in four quarter-turn handle angles 0/90/180/270 degrees left to right. Socket (24,20), rope anchor (8,8). Housing unchanged, all moving parts contained; no rope/glow/sparks or second handle.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 4 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 192x48 pixels, each frame 48x48 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: Same fitted winch in four quarter-turn handle angles 0/90/180/270 degrees left to right. Socket (24,20), rope anchor (8,8). Housing unchanged, all moving parts contained; no rope/glow/sparks or second handle. Playback intent: 6 fps loop. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 13. P0 — Passenger-car closed / open door

**Planned ID:** `brass_door` · **Cell:** 32×64 px · **Frame count:** 2 · **Strip:** 64×64 px · **Pivot:** (16,62) · **Alpha:** transparent · **Playback:** state-held frames.

**Style / staging:** Two matched burgundy timber entry-door states: closed amber-glass door, then open dark doorway with readable step. Step contact (16,62), identical trim. Runtime must mask/replace painted door area rather than stamp an open portal over intact source door.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 2 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 64x64 pixels, each frame 32x64 pixels, pivot (16,62) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: Two matched burgundy timber entry-door states: closed amber-glass door, then open dark doorway with readable step. Step contact (16,62), identical trim. Runtime must mask/replace painted door area rather than stamp an open portal over intact source door. Playback intent: state-held frames. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 14. P0 — Whistle / departure visual cue

**Planned ID:** `brass_steam` · **Cell:** 64×48 px · **Frame count:** 3 · **Strip:** 192×48 px · **Pivot:** (32,46) · **Alpha:** transparent · **Playback:** 5 fps once.

**Style / staging:** Three cream pixel-cluster steam puffs: compact, expanding, dispersing. Origin (32,46) aligns to chimney. No locomotive baked in, no glow, binary alpha. Visual cue works silently and never delays departure.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 3 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 192x48 pixels, each frame 64x48 pixels, pivot (32,46) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: Three cream pixel-cluster steam puffs: compact, expanding, dispersing. Origin (32,46) aligns to chimney. No locomotive baked in, no glow, binary alpha. Visual cue works silently and never delays departure. Playback intent: 5 fps once. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 15. P1 — Paper-wrapped pot, closed bud

**Planned ID:** `flowerpot_bud` · **Cell:** 24×40 px · **Frame count:** 1 · **Strip:** 24×40 px · **Pivot:** (12,39) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One terracotta flowerpot with cream paper wrap, asymmetric folded tie, green stem and warm pink closed bud. Base (12,39), pot body y24..38. Keep master paper/pot/stem identical to bloom; readable in Oliver paws without covering face.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 24x40 pixels, each frame 24x40 pixels, pivot (12,39) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One terracotta flowerpot with cream paper wrap, asymmetric folded tie, green stem and warm pink closed bud. Base (12,39), pot body y24..38. Keep master paper/pot/stem identical to bloom; readable in Oliver paws without covering face. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 16. P1 — Matching pot, open flower

**Planned ID:** `flowerpot_bloom` · **Cell:** 24×40 px · **Frame count:** 1 · **Strip:** 24×40 px · **Pivot:** (12,39) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** Exact flowerpot_bud master, change ONLY bud to open warm pink flower with cream center. Base (12,39), petals within x2..22,y2..18. Preserve paper/pot/stem pixels; no magic particles.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 24x40 pixels, each frame 24x40 pixels, pivot (12,39) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: Exact flowerpot_bud master, change ONLY bud to open warm pink flower with cream center. Base (12,39), petals within x2..22,y2..18. Preserve paper/pot/stem pixels; no magic particles. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 17. P1 — Spare wrapping paper

**Planned ID:** `wrapping_paper` · **Cell:** 24×16 px · **Frame count:** 1 · **Strip:** 24×16 px · **Pivot:** (12,15) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One cream wrapping-paper square with a folded corner, two deliberate crease lines and warm shadow, matching Oliver pot paper. Separate folding prop, no letters or preprinted flower.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 24x16 pixels, each frame 24x16 pixels, pivot (12,15) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One cream wrapping-paper square with a folded corner, two deliberate crease lines and warm shadow, matching Oliver pot paper. Separate folding prop, no letters or preprinted flower. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 18. P1 — Crooked paper-flower keepsake

**Planned ID:** `paper_flower` · **Cell:** 16×16 px · **Frame count:** 1 · **Strip:** 16×16 px · **Pivot:** (8,15) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One handmade crooked folded-paper flower, unequal cream/pale pink angular petals, short folded green stem. Clear dark outline at 1x; distinct from living flower. Separate reward sprite, never baked into carriage.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 16x16 pixels, each frame 16x16 pixels, pivot (8,15) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One handmade crooked folded-paper flower, unequal cream/pale pink angular petals, short folded green stem. Clear dark outline at 1x; distinct from living flower. Separate reward sprite, never baked into carriage. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 19. P1 — Oliver posed with closed-bud flowerpot

**Planned ID:** `oliver_pot_idle_r` · **Cell:** 96×96 px · **Frame count:** 1 · **Strip:** 96×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** Oliver gently cups ONE closed-bud wrapped pot, elbows tucked, shy attentive expression. Combined pot base (65,75), same flowerpot_bud design. Suppress standalone pot when this combined sprite is active.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 96x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Oliver, the imported cream rabbit with tall ears, green jacket, red scarf and brown bag/backpack strap, upright facing RIGHT. Use oliver_idle_r frame 00 as master, visible height about 66px, standing feet (48,88). Preserve ear/head/coat volume. Subject, ordered states and technical staging: Oliver gently cups ONE closed-bud wrapped pot, elbows tucked, shy attentive expression. Combined pot base (65,75), same flowerpot_bud design. Suppress standalone pot when this combined sprite is active. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 20. P1 — Oliver carrying flowerpot walk

**Planned ID:** `oliver_pot_walk_r` · **Cell:** 96×96 px · **Frame count:** 6 · **Strip:** 576×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** 9 fps loop.

**Style / staging:** Oliver carefully walks carrying ONE closed-bud pot: right contact/down/passing/opposite contact/down/passing. Pot base (65,75) steady; feet anchor fixed, no root motion. Combined pose replaces generic walk; no extra pot.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 6 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 576x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Oliver, the imported cream rabbit with tall ears, green jacket, red scarf and brown bag/backpack strap, upright facing RIGHT. Use oliver_idle_r frame 00 as master, visible height about 66px, standing feet (48,88). Preserve ear/head/coat volume. Subject, ordered states and technical staging: Oliver carefully walks carrying ONE closed-bud pot: right contact/down/passing/opposite contact/down/passing. Pot base (65,75) steady; feet anchor fixed, no root motion. Combined pose replaces generic walk; no extra pot. Playback intent: 9 fps loop. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 21. P1 — Oliver boarding with pot

**Planned ID:** `oliver_board_r` · **Cell:** 96×96 px · **Frame count:** 2 · **Strip:** 192×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** 6 fps once.

**Style / staging:** Oliver lifts front knee to train step then leans safely through entry, ONE pot base (65,75). Stage moves actor to step; feet anchor stays (48,88). No door baked in.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 2 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 192x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Oliver, the imported cream rabbit with tall ears, green jacket, red scarf and brown bag/backpack strap, upright facing RIGHT. Use oliver_idle_r frame 00 as master, visible height about 66px, standing feet (48,88). Preserve ear/head/coat volume. Subject, ordered states and technical staging: Oliver lifts front knee to train step then leans safely through entry, ONE pot base (65,75). Stage moves actor to step; feet anchor stays (48,88). No door baked in. Playback intent: 6 fps once. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 22. P1 — Oliver seated / window pose

**Planned ID:** `oliver_seated_r` · **Cell:** 96×96 px · **Frame count:** 2 · **Strip:** 192×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** state-held poses.

**Style / staging:** Oliver seated relaxed with ONE pot on lap, then slightly turns gaze toward window. Local seat contact (48,70), anchor (48,88), pot base (63,70). No furniture in actor; separate rear seat and front lip occlude lower body.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 2 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 192x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Oliver, the imported cream rabbit with tall ears, green jacket, red scarf and brown bag/backpack strap, upright facing RIGHT. Use oliver_idle_r frame 00 as master, visible height about 66px, standing feet (48,88). Preserve ear/head/coat volume. Subject, ordered states and technical staging: Oliver seated relaxed with ONE pot on lap, then slightly turns gaze toward window. Local seat contact (48,70), anchor (48,88), pot base (63,70). No furniture in actor; separate rear seat and front lip occlude lower body. Playback intent: state-held poses. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 23. P1 — Oliver looking down at pot

**Planned ID:** `oliver_pot_look_r` · **Cell:** 96×96 px · **Frame count:** 1 · **Strip:** 96×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** Oliver cradles ONE closed-bud pot and looks down with gentle curiosity. Pot base (65,75). Redraw head clusters, do not shrink or recenter whole body.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 96x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Oliver, the imported cream rabbit with tall ears, green jacket, red scarf and brown bag/backpack strap, upright facing RIGHT. Use oliver_idle_r frame 00 as master, visible height about 66px, standing feet (48,88). Preserve ear/head/coat volume. Subject, ordered states and technical staging: Oliver cradles ONE closed-bud pot and looks down with gentle curiosity. Pot base (65,75). Redraw head clusters, do not shrink or recenter whole body. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 24. P1 — Oliver notices / shows bloom

**Planned ID:** `oliver_bloom_show_r` · **Cell:** 96×96 px · **Frame count:** 2 · **Strip:** 192×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** state-held poses.

**Style / staging:** Oliver notices ONE open-bloom pot then lifts it to show Milo with quiet delight. Pot base (65,75) then (65,69), same flowerpot_bloom design, face unobscured, no duplicate pot.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 2 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 192x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Oliver, the imported cream rabbit with tall ears, green jacket, red scarf and brown bag/backpack strap, upright facing RIGHT. Use oliver_idle_r frame 00 as master, visible height about 66px, standing feet (48,88). Preserve ear/head/coat volume. Subject, ordered states and technical staging: Oliver notices ONE open-bloom pot then lifts it to show Milo with quiet delight. Pot base (65,75) then (65,69), same flowerpot_bloom design, face unobscured, no duplicate pot. Playback intent: state-held poses. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 25. P1 — Oliver folding paper flower

**Planned ID:** `oliver_fold_r` · **Cell:** 96×96 px · **Frame count:** 3 · **Strip:** 288×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** 5 fps once.

**Style / staging:** Oliver holds spare cream wrapping paper, folds inward, presents crooked paper flower. Hands around (64,65). Exactly one paper stage per cell, match separate masters. Pot sits separately in scene, not also in paws.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 3 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 288x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Oliver, the imported cream rabbit with tall ears, green jacket, red scarf and brown bag/backpack strap, upright facing RIGHT. Use oliver_idle_r frame 00 as master, visible height about 66px, standing feet (48,88). Preserve ear/head/coat volume. Subject, ordered states and technical staging: Oliver holds spare cream wrapping paper, folds inward, presents crooked paper flower. Hands around (64,65). Exactly one paper stage per cell, match separate masters. Pot sits separately in scene, not also in paws. Playback intent: 5 fps once. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 26. P1 — Oliver places paper flower

**Planned ID:** `oliver_place_r` · **Cell:** 96×96 px · **Frame count:** 2 · **Strip:** 192×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** 5 fps once.

**Style / staging:** Oliver extends paw holding crooked paper flower at pivot (72,64), then withdraws EMPTY paw. Runtime switches to separate windowsill keepsake at release, never duplicate reward. No windowsill baked in.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 2 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 192x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Oliver, the imported cream rabbit with tall ears, green jacket, red scarf and brown bag/backpack strap, upright facing RIGHT. Use oliver_idle_r frame 00 as master, visible height about 66px, standing feet (48,88). Preserve ear/head/coat volume. Subject, ordered states and technical staging: Oliver extends paw holding crooked paper flower at pivot (72,64), then withdraws EMPTY paw. Runtime switches to separate windowsill keepsake at release, never duplicate reward. No windowsill baked in. Playback intent: 5 fps once. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 27. P1 — Milo petal tap

**Planned ID:** `milo_petal_tap_r` · **Cell:** 96×96 px · **Frame count:** 3 · **Strip:** 288×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** 5 fps once.

**Style / staging:** Milo curious reach, gentle paw contact (70,64), withdraw with ears perked. No flower/pot/sill in actor. Separate keepsake and optional petal response.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 3 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 288x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Milo, the imported ginger tabby cat with cream muzzle/belly/feet, red scarf and brown backpack, NO cap, upright on TWO legs facing RIGHT. Use milo_idle_r frame 00 as master, visible height about 48px, feet (48,88). Subject, ordered states and technical staging: Milo curious reach, gentle paw contact (70,64), withdraw with ears perked. No flower/pot/sill in actor. Separate keepsake and optional petal response. Playback intent: 5 fps once. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 28. P1 — Flower-market stall

**Planned ID:** `market_stall` · **Cell:** 192×128 px · **Frame count:** 1 · **Strip:** 192×128 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One welcoming timber flower stall, three simple flower pots, quiet counter y80, feet y126. No awning, vendor or text. Center x56..136 stays open for actors; warm wood and broad clusters.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 192x128 pixels, each frame 192x128 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One welcoming timber flower stall, three simple flower pots, quiet counter y80, feet y126. No awning, vendor or text. Center x56..136 stays open for actors; warm wood and broad clusters. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 29. P1 — Market awning

**Planned ID:** `market_awning` · **Cell:** 192×48 px · **Frame count:** 1 · **Strip:** 192×48 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One muted burgundy-and-cream striped awning, slim timber crossbar and scalloped edge. Matches 192px stall, mounts at local y8 above it. No lettering or vivid carnival colors.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 192x48 pixels, each frame 192x48 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One muted burgundy-and-cream striped awning, slim timber crossbar and scalloped edge. Matches 192px stall, mounts at local y8 above it. No lettering or vivid carnival colors. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 30. P1 — Supper notice with Rin portrait

**Planned ID:** `supper_notice` · **Cell:** 96×128 px · **Frame count:** 1 · **Strip:** 96×128 px · **Pivot:** (0,0) · **Alpha:** opaque · **Playback:** still.

**Style / staging:** Warm cream rectangular supper notice, worn corners, portrait of gray masked raccoon Rin in charcoal coat within x36..59,y12..35 (24x24). Leave x8..87,y44..115 plain for exact authored text overlay. No generated prose. Semantic notice text remains in content/UI.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 96x128 pixels, each frame 96x128 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: Warm cream rectangular supper notice, worn corners, portrait of gray masked raccoon Rin in charcoal coat within x36..59,y12..35 (24x24). Leave x8..87,y44..115 plain for exact authored text overlay. No generated prose. Semantic notice text remains in content/UI. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully opaque rectangular image. No presentation border or typography unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 31. P1 — Carriage seat rear layer

**Planned ID:** `carriage_seat` · **Cell:** 128×96 px · **Frame count:** 1 · **Strip:** 128×96 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One burgundy upholstered passenger bench, timber back and amber highlights, no people/pot. Seat surface y62. Place oliver_seated_r anchor (64,80) so local seat contact y70 lands on seat y62. Rear layer behind actor, no front lip.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 128x96 pixels, each frame 128x96 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One burgundy upholstered passenger bench, timber back and amber highlights, no people/pot. Seat surface y62. Place oliver_seated_r anchor (64,80) so local seat contact y70 lands on seat y62. Rear layer behind actor, no front lip. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 32. P1 — Carriage foreground seat lip

**Planned ID:** `carriage_seat_front` · **Cell:** 128×96 px · **Frame count:** 1 · **Strip:** 128×96 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** ONLY the nearest armrest and lower front lip of carriage_seat, identical full canvas/origin. Above y62 transparent except nearest armrest. Separate layer masks seated actor naturally; no duplicated back upholstery.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 128x96 pixels, each frame 128x96 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: ONLY the nearest armrest and lower front lip of carriage_seat, identical full canvas/origin. Above y62 transparent except nearest armrest. Separate layer masks seated actor naturally; no duplicated back upholstery. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 33. P1 — Windowsill / supper-card place

**Planned ID:** `carriage_windowsill` · **Cell:** 160×32 px · **Frame count:** 1 · **Strip:** 160×32 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One worn timber carriage sill with amber reflection and small brass card clip. Ledge y12, separate flower bottom pivot target (52,12), card mounting point (126,8). No flower or notice baked in.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 160x32 pixels, each frame 160x32 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One worn timber carriage sill with amber reflection and small brass card clip. Ledge y12, separate flower bottom pivot target (52,12), card mounting point (126,8). No flower or notice baked in. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 34. P1 — Carriage story interior adaptation

**Planned ID:** `bg_carriage_story` · **Cell:** 640×360 px · **Frame count:** 1 · **Strip:** 640×360 px · **Pivot:** (0,0) · **Alpha:** opaque · **Playback:** still.

**Style / staging:** One side-view Brass interior matching user-owned backgrounds/train_interior.png palette. Amber windows, burgundy timber, quiet forest outside. Clear actor zone x180..430,y160..288 and mounting space for separate seat/sill/card. No actors/pot/keepsake. Source interior exists but needs adaptation/layers and later import.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 640x360 pixels, each frame 640x360 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One side-view Brass interior matching user-owned backgrounds/train_interior.png palette. Amber windows, burgundy timber, quiet forest outside. Clear actor zone x180..430,y160..288 and mounting space for separate seat/sill/card. No actors/pot/keepsake. Source interior exists but needs adaptation/layers and later import. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully opaque rectangular image. No presentation border or typography unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 35. P1 — Dressed Clover Market vignette

**Planned ID:** `bg_clover_market` · **Cell:** 640×360 px · **Frame count:** 1 · **Strip:** 640×360 px · **Pivot:** (0,0) · **Alpha:** opaque · **Playback:** still.

**Style / staging:** One cozy railway flower-market arrival with warm lamps. Deliberately adapt Willow Creek: remove Willow plaque, change roofline and flower displays. Feet plane y288, clear actor corridor x200..430. Stall/awning/notice stay separate. Unchanged station matte is not finished market.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 640x360 pixels, each frame 640x360 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One cozy railway flower-market arrival with warm lamps. Deliberately adapt Willow Creek: remove Willow plaque, change roofline and flower displays. Feet plane y288, clear actor corridor x200..430. Stall/awning/notice stay separate. Unchanged station matte is not finished market. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully opaque rectangular image. No presentation border or typography unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 36. P1 — Willow Creek station sign

**Planned ID:** `willow_creek_sign` · **Cell:** 128×32 px · **Frame count:** 1 · **Strip:** 128×32 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One weathered timber plaque with brass rim and exact readable lettering "Willow Creek" centered within x8..119,y8..23. No extra words. Manual spelling/bitmap-type cleanup required; separate from blank source plaque.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 128x32 pixels, each frame 128x32 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One weathered timber plaque with brass rim and exact readable lettering "Willow Creek" centered within x8..119,y8..23. No extra words. Manual spelling/bitmap-type cleanup required; separate from blank source plaque. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 37. P1 — Faded The Last Stop sign

**Planned ID:** `last_stop_sign` · **Cell:** 128×32 px · **Frame count:** 1 · **Strip:** 128×32 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One old timber railway sign with exact faded but decipherable lettering "The Last Stop", sparse paint gaps and ivy at one edge. Text x8..119,y8..23; manually verify spelling. No glow or finale decorations.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 128x32 pixels, each frame 128x32 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One old timber railway sign with exact faded but decipherable lettering "The Last Stop", sparse paint gaps and ivy at one edge. Text x8..119,y8..23; manually verify spelling. No glow or finale decorations. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 38. P1 — Loose bench slat

**Planned ID:** `bench_slat` · **Cell:** 48×8 px · **Frame count:** 1 · **Strip:** 48×8 px · **Pivot:** (24,7) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One horizontal weathered wooden bench slat with chipped ends and two empty nail holes, dark lower edge. Match supplied props/bench.png. Same physical slat in Rin held/rest poses; no bench/paws baked in.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 48x8 pixels, each frame 48x8 pixels, pivot (24,7) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One horizontal weathered wooden bench slat with chipped ends and two empty nail holes, dark lower edge. Match supplied props/bench.png. Same physical slat in Rin held/rest poses; no bench/paws baked in. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 39. P1 — Station timetable

**Planned ID:** `timetable` · **Cell:** 48×64 px · **Frame count:** 1 · **Strip:** 48×64 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One timber-framed timetable board with cream paper, three understated route rows and simple icons. Leave x5..42,y8..56 flat for authored exact text. No pseudo-letters; row rules/icons support color-independent meaning.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 48x64 pixels, each frame 48x64 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One timber-framed timetable board with cream paper, three understated route rows and simple icons. Leave x5..42,y8..56 flat for authored exact text. No pseudo-letters; row rules/icons support color-independent meaning. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 40. P1 — Unused second-platform view

**Planned ID:** `bg_unused_platform` · **Cell:** 640×360 px · **Frame count:** 1 · **Strip:** 640×360 px · **Pivot:** (0,0) · **Alpha:** opaque · **Playback:** still.

**Style / staging:** One distinct quiet unused platform across tracks, weathered empty bench, overgrown edge, unlit lamp, same violet sunset world. Different camera composition from main station. Sign mount x400..527,y128..159 for separate faded sign. No playable siding apparatus, levers or later-chapter props.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 640x360 pixels, each frame 640x360 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One distinct quiet unused platform across tracks, weathered empty bench, overgrown edge, unlit lamp, same violet sunset world. Different camera composition from main station. Sign mount x400..527,y128..159 for separate faded sign. No playable siding apparatus, levers or later-chapter props. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully opaque rectangular image. No presentation border or typography unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 41. P1 — Milo nod

**Planned ID:** `milo_nod_r` · **Cell:** 96×96 px · **Frame count:** 2 · **Strip:** 192×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** 5 fps once.

**Style / staging:** Milo head dips then returns, small affirmative expression and relaxed ears. Torso/feet/backpack pixels stable; no exaggerated squash or cap.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 2 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 192x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Milo, the imported ginger tabby cat with cream muzzle/belly/feet, red scarf and brown backpack, NO cap, upright on TWO legs facing RIGHT. Use milo_idle_r frame 00 as master, visible height about 48px, feet (48,88). Subject, ordered states and technical staging: Milo head dips then returns, small affirmative expression and relaxed ears. Torso/feet/backpack pixels stable; no exaggerated squash or cap. Playback intent: 5 fps once. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 42. P1 — Milo point

**Planned ID:** `milo_point_r` · **Cell:** 96×96 px · **Frame count:** 1 · **Strip:** 96×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** Milo relaxed open-paw point toward right, curious ears. Paw inside x74. No arrow, bubble or prop; shape must read when mirrored.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 96x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Milo, the imported ginger tabby cat with cream muzzle/belly/feet, red scarf and brown backpack, NO cap, upright on TWO legs facing RIGHT. Use milo_idle_r frame 00 as master, visible height about 48px, feet (48,88). Subject, ordered states and technical staging: Milo relaxed open-paw point toward right, curious ears. Paw inside x74. No arrow, bubble or prop; shape must read when mirrored. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 43. P1 — Milo reach / catch

**Planned ID:** `milo_reach_catch_r` · **Cell:** 96×96 px · **Frame count:** 3 · **Strip:** 288×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** 6 fps once.

**Style / staging:** Milo notices slipping object, reaches both paws, catches and settles. Catch point (67,64); OMIT object for separate single-prop staging. Fixed feet and stable volume.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 3 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 288x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Milo, the imported ginger tabby cat with cream muzzle/belly/feet, red scarf and brown backpack, NO cap, upright on TWO legs facing RIGHT. Use milo_idle_r frame 00 as master, visible height about 48px, feet (48,88). Subject, ordered states and technical staging: Milo notices slipping object, reaches both paws, catches and settles. Catch point (67,64); OMIT object for separate single-prop staging. Fixed feet and stable volume. Playback intent: 6 fps once. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 44. P1 — Milo wave

**Planned ID:** `milo_wave_r` · **Cell:** 96×96 px · **Frame count:** 3 · **Strip:** 288×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** 5 fps once.

**Style / staging:** Milo friendly small wave: raised paw, outward paw tilt, return. Stable backpack and face, no extra hands/streaks/text.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 3 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 288x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Milo, the imported ginger tabby cat with cream muzzle/belly/feet, red scarf and brown backpack, NO cap, upright on TWO legs facing RIGHT. Use milo_idle_r frame 00 as master, visible height about 48px, feet (48,88). Subject, ordered states and technical staging: Milo friendly small wave: raised paw, outward paw tilt, return. Stable backpack and face, no extra hands/streaks/text. Playback intent: 5 fps once. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 45. P1 — Oliver caught-ear staging

**Planned ID:** `oliver_caught_ear_r` · **Cell:** 96×96 px · **Frame count:** 3 · **Strip:** 288×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** 5 fps once.

**Style / staging:** Oliver gently bends one ear backward as if lightly caught, glances toward it, straightens ear in relief. ONE closed-bud pot base (65,75) all frames. No violence/pain; no door baked in. Stage aligns ear to separate door trim.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 3 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 288x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Oliver, the imported cream rabbit with tall ears, green jacket, red scarf and brown bag/backpack strap, upright facing RIGHT. Use oliver_idle_r frame 00 as master, visible height about 66px, standing feet (48,88). Preserve ear/head/coat volume. Subject, ordered states and technical staging: Oliver gently bends one ear backward as if lightly caught, glances toward it, straightens ear in relief. ONE closed-bud pot base (65,75) all frames. No violence/pain; no door baked in. Stage aligns ear to separate door trim. Playback intent: 5 fps once. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 46. P1 — Rin with tool satchel

**Planned ID:** `rin_satchel_r` · **Cell:** 96×96 px · **Frame count:** 1 · **Strip:** 96×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** Rin rests paw on open tool-satchel flap, small generic tool tip peeks out. Keep tools secondary, NO unique puzzle crank in bag. Preserve mask/tail stripes.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 96x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Rin, the imported gray raccoon with dark face mask, charcoal jacket and brown tool satchel, upright on TWO legs facing RIGHT. Use rin_idle_r frame 00 as master, visible height about 48px, feet (48,88). Preserve mask and tail stripes. Subject, ordered states and technical staging: Rin rests paw on open tool-satchel flap, small generic tool tip peeks out. Keep tools secondary, NO unique puzzle crank in bag. Preserve mask/tail stripes. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 47. P1 — Rin slat-holding

**Planned ID:** `rin_slat_hold_r` · **Cell:** 96×96 px · **Frame count:** 1 · **Strip:** 96×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** Rin holds ONE loose 48x8 wooden slat horizontally in both paws at waist, slat center (53,68). Match bench_slat; combined slat suppresses standalone slat draw.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 96x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Rin, the imported gray raccoon with dark face mask, charcoal jacket and brown tool satchel, upright on TWO legs facing RIGHT. Use rin_idle_r frame 00 as master, visible height about 48px, feet (48,88). Preserve mask and tail stripes. Subject, ordered states and technical staging: Rin holds ONE loose 48x8 wooden slat horizontally in both paws at waist, slat center (53,68). Match bench_slat; combined slat suppresses standalone slat draw. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 48. P1 — Rin resting on slat

**Planned ID:** `rin_slat_rest_r` · **Cell:** 96×96 px · **Frame count:** 1 · **Strip:** 96×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** Rin easy patient lean, one paw resting on ONE slat angled to ground, lower slat contact (67,87). Satchel visible, whole slat/body contained; no bench.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 96x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Rin, the imported gray raccoon with dark face mask, charcoal jacket and brown tool satchel, upright on TWO legs facing RIGHT. Use rin_idle_r frame 00 as master, visible height about 48px, feet (48,88). Preserve mask and tail stripes. Subject, ordered states and technical staging: Rin easy patient lean, one paw resting on ONE slat angled to ground, lower slat contact (67,87). Satchel visible, whole slat/body contained; no bench. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 49. P1 — Rin wave

**Planned ID:** `rin_wave_r` · **Cell:** 96×96 px · **Frame count:** 3 · **Strip:** 288×96 px · **Pivot:** (48,88) · **Alpha:** transparent · **Playback:** 5 fps once.

**Style / staging:** Rin friendly wave: raised paw, outward tilt, return; other paw beside satchel. No slat in waving hand; stage places slat separately. Stable mask/coat/tail stripes.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 3 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 288x96 pixels, each frame 96x96 pixels, pivot (48,88) in every frame. Character master: Rin, the imported gray raccoon with dark face mask, charcoal jacket and brown tool satchel, upright on TWO legs facing RIGHT. Use rin_idle_r frame 00 as master, visible height about 48px, feet (48,88). Preserve mask and tail stripes. Subject, ordered states and technical staging: Rin friendly wave: raised paw, outward tilt, return; other paw beside satchel. No slat in waving hand; stage places slat separately. Stable mask/coat/tail stripes. Playback intent: 5 fps once. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 50. P2 — Snail + leaf / feeler wave

**Planned ID:** `snail_leaf_wave` · **Cell:** 24×16 px · **Frame count:** 3 · **Strip:** 72×16 px · **Pivot:** (12,15) · **Alpha:** transparent · **Playback:** 4 fps once.

**Style / staging:** One tiny brown snail under broad mint-green leaf: resting feelers, raised greeting feeler, rest. Shell/leaf identical across frames, only head/feeler moves. Readable spiral and outline. No reward/icon. Optional discovery never gates route.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create precisely 3 ordered frames in ONE horizontal row, no gutters or borders. Exact exported canvas 72x16 pixels, each frame 24x16 pixels, pivot (12,15) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One tiny brown snail under broad mint-green leaf: resting feelers, raised greeting feeler, rest. Shell/leaf identical across frames, only head/feeler moves. Readable spiral and outline. No reward/icon. Optional discovery never gates route. Playback intent: 4 fps once. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## 51. P2 — Optional bespoke UI icon reference

**Planned ID:** `ui_glyph_sheet` · **Cell:** 256×128 px · **Frame count:** 1 · **Strip:** 256×128 px · **Pivot:** (0,0) · **Alpha:** transparent · **Playback:** still.

**Style / staging:** One restrained original UI symbol reference sheet, fixed 16x16 cells, 16 columns by 8 rows, containing advance/skip/pause/interact/notice symbols only. No prose/logos. Split to individual assets before registration. Bundled runtime font and em-dash/ellipsis coverage already exist; any replacement must preserve labels, pagination, notices/end-card Unicode and separate license/metrics QA.

**Ready-to-paste ChatGPT image prompt**

```text
Use case: stylized-concept. Asset type: production pixel-art game asset for The Last Stop at native 640x360 game scale. Attached user-owned pack images and palette_swatches.png are style/design references ONLY; never reproduce their sheets, labels or presentation. Create ONE isolated usable asset. Exact exported canvas 256x128 pixels, each frame 256x128 pixels, pivot (0,0) in every frame. Character master: Match supplied Brass, forest and station world scale; no characters unless requested. Subject, ordered states and technical staging: One restrained original UI symbol reference sheet, fixed 16x16 cells, 16 columns by 8 rows, containing advance/skip/pause/interact/notice symbols only. No prose/logos. Split to individual assets before registration. Bundled runtime font and em-dash/ellipsis coverage already exist; any replacement must preserve labels, pagination, notices/end-card Unicode and separate license/metrics QA. Playback intent: still. Match charming detailed 16-bit adventure pixel art, crisp deliberate pixel clusters, dark navy outlines, warm earthy colors, amber highlights, consistent side-view orthographic scale and lighting. Sampled reference colors: #E88838 #F8D8B8 #080818 #181828 #681838 #E8A878. Foreground working palette: #1C243B #34476A #766793 #E8B96E #A9D1BB #F2DCCA #080B1C #142A36 #28454B #456253 #77826B #334E7A #58678D #A9899B #452436 #702D3E #9D3944 #6E4330 #A3673B #D06C2E #E78B36 #F6D5AD #D48E73 #F6E5CE. Opaque scenery may retain richer reference ramps. Keep material ramps, outline clusters and subject scale stable across states. No smooth gradients, anti-aliasing, blur, pseudo-pixel filters, photographic texture, watermark or decorative mockup. Fully transparent empty pixels, binary alpha, no ground/scene/cast shadow/text/labels/extra objects unless explicitly requested in Subject. Keep whole subject inside each cell; no trimming, resampling or frame-specific recentering. Output the usable PNG itself.
```

## Acceptance before future import

Check final dimensions/count/pivot, silhouette on black/white/forest, fixed feet and clip seam at native 1× and integer enlargement. Compose pot/sill/door/seat at 640×360 before approving sockets; these are proposals, not verified runtime positions. Inspect every sign letter and Rin portrait. Validate single-handle and single-flower draw ownership.

Record real source/export hashes, creator, generation tool, reference rights and transformations. Register existing bytes through revision-guarded tls-content create operations. Never invent checksums or paths for art that does not exist. Preserve assets v1; scene/actor links belong to later integration.

Audio is outside this image commission: wheel rhythm, low/departure whistle, two-note clearance, door, pickup/install, crank, branch settle and paper rustle still need original/licensed sources. Rain/music/parallax/wheel loops, full ear-release/folding/petal-spring and dusting-paws animation are optional polish. The short strips/still poses above cover section 6 without expanded animation systems. No cap, umbrella or later-chapter apparatus is commissioned.
