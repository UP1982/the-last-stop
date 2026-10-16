# THE LAST STOP — Canonical Game Bible
Version 1.0 | October 2026

> Every passenger has somewhere to go. Sometimes they just need a little help getting there.

**Implementation:** Odin + raylib, 2D side-view pixel art on macOS first. **This document controls creative scope.**

## 2. Player-facing pitch

An old train follows a railway through sleepy forests and strange little towns. Its conductor is a cat with a cap too big for his head. Every animal aboard has somewhere important to be, but the world keeps getting in the way: a fallen tree, a missing bridge plank, a flooded tunnel, a stubborn goat napping by the rails. Hop off, poke around, help the railway along, and return to your passengers. No one is counting the minutes. There's always time for one more stop.

**Genre:** Short-form, narrative environmental puzzle adventure with side-scrolling exploration.
**Camera:** 2D side view in journey and puzzle scenes. Stations are mostly staged cutscenes, not separate top-down levels.
**Audience:** Players looking for a cozy game they can pick up and put down freely.
**Target session:** 3–7 minutes for a standard passenger journey.
**Vertical slice target:** 10–15 minutes with a beginning, middle, and end.
**Full-game aspiration:** ~1.5–3 hours, subject to playtesting and resources. Never use this aspiration to justify feature creep during prototype work.

## 3. Core pillars and non-negotiables

1. **Simple to start, easy to stop.** A tiny set of controls, low reading burden, resumable interactions, fast boot-to-play, and automatic saves.
2. **An obstacle is a playful question.** All mandatory challenges are environmental, observable, reversible, and understandable without an inventory puzzle chain.
3. **Each passenger matters.** A distinctive personality, an understandable goal, and a brief arrival payoff.
4. **The train is a refuge.** Gentle sound and scenic transitions separate puzzles; no need to manually operate speed, fuel, timetables, or fares.
5. **Small handcrafted wonder.** Every scene earns its place through a clever interaction, expressive animation, hidden detail, or delightful character moment.

**Explicitly exclude from MVP:** combat, health, lives, fail states, time pressure, hunger meters, crafting, economies, giant hub worlds, quest logs, dialogue trees with irreversible consequences, collectible grinding, procedurally generated levels, platforming requiring tight timing, multiplayer, and complex AI.

**User-approved development tooling:** the visual content editor, in-game edit mode and coding/agent workspace described in `EDITOR_SPEC.md` are now included. This supersedes the original editor exclusion; it does not expand the Chapter 1 gameplay scope.

## 4. Story bible

### World

The railway winds through a gentle valley of little animal communities. Some stations have only a platform and a lamp. Others sit beside orchards, ponds, or misty woods. Trains are old and reliable, but the line is weathered, and nature keeps finding its way onto the tracks. Nothing supernatural needs to be explained; tiny dreamy events are accepted with a shrug. The animals are busy living their own small lives.

### Milo, the playable cat

Milo is a small ginger or cream-colored cat with an oversized navy conductor cap. Milo is observant, curious, expressive, and largely silent. Communication comes from ear movements, tail animation, blinking, chirps, and a few short reaction bubbles. Milo is helpful without being heroic or perfect. When a puzzle is solved, Milo pauses proudly and then returns to the train.

### Recurring supporting character

**Brass**, the train itself, is almost a character: a squat locomotive with glowing windows, a gentle whistle, and a slightly squeaky door. It need not speak. Its lights brighten when Milo returns. A small passenger carriage contains visible keepsakes from completed journeys, but interacting with this collection is optional and lightweight.

### Narrative arc

There is a thin through-line beneath self-contained passenger chapters. Milo is new to the route, and the station signs ahead are faded. At first, every trip is simply helping somebody. As Milo helps more passengers, they leave little thank-you notes or objects. The timetable gradually fills with destinations. In the finale, Milo reaches a neglected platform called **The Last Stop**, where several previous passengers happen to gather for a small celebration of the newly restored line. There is no villain or apocalypse. The emotional idea is that everyday kindness can reconnect a community.

Keep the finale understated and avoid implying that the player must rescue the entire world.

### Tone rules

Mix funny, cozy, slightly wistful, and joyful passenger stories. Not every character should have trauma or a dramatic revelation. Default lines should be short. Prefer character animation over lengthy exposition. All story sequences can be advanced quickly and safely skipped; replay from a story scrapbook is a stretch feature, not MVP.

## 5. Passenger roster and chapter outlines

### Prologue: The First Whistle

At Dawn Platform, Milo finds a conductor cap and a note: 'The train is yours today. Be kind to your passengers.' A simple prompt teaches movement, interacting, and boarding. The train gives a happy whistle. A timid rabbit steps forward.

### Chapter 1: Oliver and the Flower Market (prototype priority)

**Passenger:** Oliver, a rabbit with a scarf and a paper-wrapped flower pot.
**Goal:** Reach Clover Market before the flower stalls close, although there is no in-game countdown.
**Station cutscene:** Oliver is trying to keep his flower pot upright in the rain. 'Does this train stop at Clover Market?' Milo nods. Oliver boards.
**Obstacle:** A fallen branch is lying across the tracks. An old hand-cranked lift and a rope can pull it aside, but the lift handle is missing.
**Environmental puzzle:** Follow a short path to a tool shed; find the handle visible on a nearby shelf; carry it back; insert it into the lift; hold interact to crank; branch rolls away. There is only one carried item and no inventory menu.
**Optional discovery:** A tiny snail under a leaf waves at Milo. This is purely delightful, not required.
**Arrival cutscene:** Oliver buys the first flowers of the morning, then gives Milo a little paper flower. He says: 'I think I like rainy days better when I'm not spending them alone.' The flower appears on the carriage windowsill.
**Mechanics proven:** Move, jump over tiny terrain bumps, interact, pick up/drop a single object, operate a mechanism, obstacle state changes, board, cinematic sequence, save/resume.

### Chapter 2: Hazel and the Quiet Crossing

**Passenger:** Hazel, an old tortoise returning to a familiar village.
**Obstacle:** The crossing gate is locked in the lowered position because a waterwheel no longer turns.
**Puzzle:** Remove debris blocking a stream, then move a wooden sluice panel so flowing water spins the wheel and raises the crossing arm.
**Optional story:** Hazel recognizes an old stone marker beside the track and shares a two-line memory.
**Payoff:** Someone at the destination recognizes her immediately and runs to say hello.
**New twist:** One reversible state-based water puzzle, not a new core control scheme.

### Chapter 3: Felix and the Fog

**Passenger:** Felix, a fox carrying an unsent letter.
**Obstacle:** Fog has hidden the rail signal; the train cannot move until the signal lamp is visible.
**Puzzle:** Push a wheeled mirror into position and rotate it to reflect light from a lantern onto the signal reflector.
**Payoff:** Felix finally hands over the letter. It turns out to be an invitation to share tea.
**New twist:** Positioning and light reflection.

### Chapter 4: Bea and the Sleepy Tunnel

**Passenger:** Bea, a little hedgehog trying to attend her friend's picnic.
**Obstacle:** A friendly bear has fallen asleep in the tunnel entrance.
**Puzzle:** Discover that the bear's picnic basket has rolled downhill; return it beside a shaded bench. The bear moves willingly to investigate, clearing the tunnel.
**Payoff:** A picnic with more friends than Bea expected.
**New twist:** Observe a character's needs rather than moving machinery. No cruelty to animals.

### Chapter 5: Lumi and the Hill of Lights

**Passenger:** Lumi, a moth who wants to see the valley lights from the highest platform.
**Obstacle:** An old turntable points the train toward a closed track.
**Puzzle:** Use two nearby levers to power and align the turntable. Environmental indicators show the correct direction.
**Payoff:** From the hill, Milo and Lumi see all the stations glowing across the valley.
**New twist:** Combining two learned interactions without dexterity pressure.

### Finale: The Last Stop

**Obstacle:** A small final route puzzle combining one familiar mechanism and one observation clue. Keep it approachable.
**Arrival:** At an old platform, several animals Milo helped are there. They have fixed the station sign and planted flowers along the tracks. The sign reads 'THE LAST STOP', but as the train slows, another small destination lights up on the timetable. The train whistles. Ending implies more gentle adventures ahead.

## 6. The moment-to-moment loop

1. **Station scene, 20–45 seconds.** New passenger introduced. A one- or two-line request, a funny or touching beat, a clear destination. Skip/advance supported.
2. **Train travel, 10–25 seconds.** Train moves on its own; camera shows parallax trees, weather, small scenic details. Let the player interact with a couple of optional objects only if implementation remains simple. Never make passengers wait in a simulated real-time system.
3. **Obstacle discovery, ~10 seconds.** Train slows, whistle sounds, camera gently frames the blockade, Milo disembarks automatically or with one prompt.
4. **Side-scrolling puzzle scene, 2–5 minutes.** Small left-right environment; 2–4 interesting interactive elements, plus one optional micro-secret. Prefer fewer meaningful interactions to large empty stretches.
5. **Resolution, 10–20 seconds.** Immediate visible reaction: gate rises, log moves, lights glow, signal changes. Route clearly opens. Player can walk back or choose an optional 'Return to train' prompt when puzzle is complete.
6. **Arrival scene, 20–45 seconds.** Passenger thanks Milo in an individual way. A small keepsake can appear in the train. Autosave.

The game must tolerate pausing or quitting in any step without losing completed puzzle actions.

## 7. Controls and accessibility

Keyboard: A/D or Left/Right to walk; Space to jump; E or Enter to interact; Esc to pause. Gamepad: left stick/D-pad to move; south face button to jump; west face button to interact; menu button to pause. Avoid requiring double taps, precise timing, or simultaneous button chords. Interactions use proximity prompts. Make controls remappable later if MVP scope allows; keyboard plus controller support is a post-core priority.

Accessibility: readable pixel font, UI scaling, adjustable music/SFX, optional screen shake disabled by default, no mandatory color-only clues, clear focus prompts, skippable dialogue, hint button or progressive hint after inactivity, and forgiving collision/interaction ranges. No blinking or intense flashing effects.

Save behavior: autosave on arrival/departure, important puzzle state changes, and quit. Persist current chapter and scene, Milo position or a safe entry marker, puzzle element states, passenger state, and completed keepsakes. Resume at a safe state without duplicated rewards or softlocks. Pause and quit are always available, including dialogue and puzzles.

## 8. Environmental puzzle framework

Puzzle design checklist:
- **Readability:** The blocked track and relevant mechanism can be understood within one screen or one short walk.
- **Causality:** Player action immediately changes the environment in a predictable way.
- **Reversibility:** Experimenting should never permanently break the puzzle.
- **Low action load:** One main insight plus a few physical steps; no pixel hunting.
- **Hint hierarchy:** First a gentle visual cue, then an optional Milo thought, then an explicit next-step hint.
- **Completion clarity:** Distinct sound and animation, train whistle, unobstructed track.
- **Save safety:** Every puzzle state serializable and reloadable.

Common mechanics, introduced one by one: pushing/light carrying objects, levers, cranks, movable bridges, water valves, mirror angle switches, switches with visual indicators, and NPC-lure placement. Do not design new mechanics for each chapter if reuse will suffice.

Bad puzzle example: find six keys hidden in random scenes to unlock a gate. Good puzzle example: the gate motor is dry; opening a nearby water channel makes the wheel turn, which visibly raises the gate.

## 9. Art and audio direction

**Visual:** Handcrafted 2D pixel art with cozy silhouettes and restrained detail. Warm amber interior highlights against dusky blue and muted forest green. Aim for 16x16 or 32x32 environment grid modules, consistent sprite density, and a 320x180 virtual resolution scaled by integer factors when possible. Pixel-perfect rendering; avoid unintended sprite filtering. Character sprite size may differ from tiles, but proportions must be consistent. Use layered parallax backdrops sparingly.

**Palette starter:** Midnight #1C243B, twilight #34476A, lavender #766793, lantern gold #E8B96E, moonmint #A9D1BB, cream #F2DCCA. These are starting colors, not hard constraints.

**Animation priorities:** Milo idle blink/tail, walk, jump, interact, paw-push; train gentle bob, wheels turn, whistle puff, opening door; one expressive idle per passenger; a few world animations such as swaying grass and rain. Do not require huge sprite sheets.

**Audio:** Soft piano, light acoustic guitar or mellow synth, gentle wheels-on-track rhythm, low railway whistle, rain, birds, insects, leaves, and subtle tactile puzzle sound effects. Music should have space and periods of quiet. Source or create properly licensed original assets; never copy copyrighted game audio.


## 11. First playable vertical slice: deliverable definition

Scope: Title/menu -> prologue station scene -> Oliver boards -> animated train travel -> fallen-branch route -> carry handle / crank puzzle -> return to train -> arrival cutscene -> thank-you flower appears -> end-card -> return to menu. Expected 10–15 minutes for first-time players, potentially shorter for experienced players.

**Required content:** One route environment with no more than three puzzle-relevant interactables, two short station cutscenes, one passenger, one optional secret, one train travel shot, save/load, pause and resume, and a gentle hint. Use temporary shapes and prototype sounds until flow is tested. Stations should not require walkable top-down maps.

**Acceptance tests:**
1. New Game starts within two selections.
2. Player can move, jump, interact, and pause with clear prompts.
3. Blocking branch visibly prevents train passage until crank puzzle is solved.
4. Player can pick up, drop, and insert handle without softlocking.
5. A solution triggers one completion event, not repeated events.
6. Player can quit during the puzzle and resume with intact state.
7. After solving, the train resumes and the correct passenger arrives.
8. Cutscenes can be advanced or skipped without breaking game state.
9. Keepsake is granted exactly once and survives saving/reloading.
10. There is no timer, combat, death, or dexterity-sensitive obstacle.
11. Game plays with placeholder assets and no required external accounts.
12. Input instructions, fonts, and object silhouettes remain readable at typical desktop display sizes.


## Creative guardrails
The Last Stop is original. Draw inspiration from the *feeling* of cozy indie adventures without imitating CAT & ONION assets, layouts, characters, exact writing, or music. Keep the overall arc gentle and not overly tragic. Stations are short staged cutscenes, not fully explorable 3D/overhead hubs. Train advances automatically. A playable journey usually takes 3–7 minutes, while the first-time vertical slice may take 10–15 minutes.
