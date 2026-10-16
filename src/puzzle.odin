package main

import "core:math"
import rl "vendor:raylib"

Handle_Location :: enum { Shelf, Held, Dropped, Installed }
Puzzle_Phase :: enum { Blocked, Cranking, Cleared }
Puzzle_State :: struct {
    handle: Handle_Location,
    dropped_feet: [2]f32,
    phase: Puzzle_Phase,
    crank_progress: f32,
    snail_seen: bool,
}
Journey_Checkpoint :: enum { Chapter_Start, Boarded, Puzzle, Returned, Arrival, Complete }
Puzzle_Action :: enum { None, Pickup, Drop, Install, Activate, Inspect_Branch, Return, Snail }
CRANK_SECONDS :: f32(3)

marker_position :: proc(scene: Runtime_Scene, returning := false) -> rl.Vector2 {
    if scene.definition == nil { return scene.spawn }
    d := scene.definition
    id := d.puzzle.player_spawn
    if returning { id = d.puzzle.return_spawn }
    p := d.spawns[id].position
    return {f32(p[0]), f32(p[1])}
}
recovery_feet :: proc(scene: Runtime_Scene) -> [2]f32 {
    p := scene.definition.spawns[scene.definition.puzzle.handle_recovery_spawn].position
    return {f32(p[0]), f32(p[1])}
}
handle_rect :: proc(scene: Runtime_Scene, p: Puzzle_State, player: Player) -> rl.Rectangle {
    d := scene.definition
    h := d.objects[d.puzzle.handle]
    w, height := f32(h.size[0]), f32(h.size[1])
    switch p.handle {
    case .Shelf: return {f32(h.position[0]), f32(h.position[1]), w, height}
    case .Dropped: return {p.dropped_feet[0]-w/2, p.dropped_feet[1]-height, w, height}
    case .Held: return {player.position.x+f32(player.facing)*16-w/2, player.position.y-28, w, height}
    case .Installed:
        winch := d.objects[d.puzzle.winch]
        return {f32(winch.position[0]+d.puzzle.winch_socket[0])-w/2,
                f32(winch.position[1]+d.puzzle.winch_socket[1])-height/2, w, height}
    }
    return {}
}
branch_rect :: proc(scene: Runtime_Scene, p: Puzzle_State) -> rl.Rectangle {
    d := scene.definition
    b := d.objects[d.puzzle.branch]
    t := p.crank_progress
    if p.phase == .Blocked { t = 0 }
    if p.phase == .Cleared { t = 1 }
    return {f32(b.position[0])+(f32(d.puzzle.branch_cleared_position[0]-b.position[0]))*t,
        f32(b.position[1])+(f32(d.puzzle.branch_cleared_position[1]-b.position[1]))*t,
        f32(b.size[0]), f32(b.size[1])}
}

// The unique loose handle wins whenever it is within pickup reach. Optional
// scenery (and an overlapping winch/train) must never hide a required pickup.
// Once carried/installed, the actionable winch takes the same precedence so
// perturbed optional scenery cannot hide the remaining completion path either.
// Visuals have stable layer/id order; ordinary targets retain the nearest
// centre / stable-index tie-break from M1. Use this resolver for validation too.
focus_puzzle :: proc(player: Player, scene: Runtime_Scene, puzzle: Puzzle_State) -> int {
    if scene.definition != nil {
        priority_id := scene.definition.puzzle.handle
        loose := puzzle.handle == .Shelf || puzzle.handle == .Dropped
        if !loose { priority_id = scene.definition.puzzle.winch }
        actionable := loose || puzzle.handle == .Held || puzzle.handle == .Installed && puzzle.phase == .Blocked
        for v in scene.visuals {
            if !actionable || v.id != priority_id || v.interaction_index < 0 { continue }
            target := scene.objects[v.interaction_index]
            target.enabled = true
            if puzzle.handle == .Dropped { target.bounds = handle_rect(scene,puzzle,player) }
            if puzzle.handle == .Shelf || !loose {
                h := scene.definition.objects[v.id]
                target.bounds = local_rect(h.interaction,h.position)
            }
            if focus_nearest(player,[]Interactable{target}) == 0 { return v.interaction_index }
        }
    }
    return focus_nearest(player,scene.objects)
}

// Validate full object + player bounds and pickup reach on ground that can
// actually be walked to with M1's controller, without any jump input.
safe_handle_feet :: proc(scene: Runtime_Scene, feet: [2]f32) -> bool {
    if scene.definition == nil { return false }
    for n in feet { if math.is_nan(n) || math.is_inf(n) { return false } }
    p := Player{position={feet[0], feet[1]}, grounded=true, facing=1}
    body := player_rect(p)
    h := handle_rect(scene, {handle=.Dropped, dropped_feet=feet}, p)
    w := scene.world
    for r in ([2]rl.Rectangle{body,h}) {
        if r.x < w.x || r.y < w.y || r.x+r.width > w.x+w.width || r.y+r.height > w.y+w.height { return false }
        for s in scene.solids { if overlaps(r,s) { return false } }
    }
    supported := false
    for s in scene.solids {
        if abs(feet[1]-s.y)<0.02 && body.x>=s.x && body.x+body.width<=s.x+s.width && h.x>=s.x && h.x+h.width<=s.x+s.width { supported=true }
    }
    if !supported { return false }
    handle_index := -1
    for v in scene.visuals {
        if v.id == scene.definition.puzzle.handle { handle_index = v.interaction_index; break }
    }
    if handle_index < 0 { return false }
    walker := Player{position=scene.spawn, grounded=true, facing=1}
    for _ in 0..<20000 {
        delta := feet[0]-walker.position.x
        if abs(delta)<2 && abs(walker.position.y-feet[1])<0.2 {
            // Test the real competing-target resolver at the reachable player
            // position, rather than testing a handle in isolation.
            return focus_puzzle(walker,scene,{handle=.Dropped,dropped_feet=feet}) == handle_index
        }
        move: f32 = 1; if delta<0 { move=-1 }
        step_player(&walker, {move=move}, scene.solids, scene.world)
    }
    return false
}
project_drop :: proc(scene: Runtime_Scene, player: Player) -> [2]f32 {
    // Project airborne drops onto the authored continuous corridor, never onto
    // props or the moving branch. Invalid/headroom/edge cases use recovery.
    ground := scene.solids[0]
    feet := [2]f32{player.position.x, ground.y}
    if safe_handle_feet(scene,feet) { return feet }
    fallback := recovery_feet(scene)
    assert(safe_handle_feet(scene,fallback), "invalid authored handle_recovery must block chapter loading")
    return fallback
}
puzzle_invariant :: proc(p: Puzzle_State, checkpoint: Journey_Checkpoint, scene: Runtime_Scene) -> bool {
    if p.phase != .Blocked && p.handle != .Installed { return false }
    if math.is_nan(p.crank_progress) || math.is_inf(p.crank_progress) || p.crank_progress<0 || p.crank_progress>1 { return false }
    if p.phase == .Blocked && p.crank_progress != 0 { return false }
    if p.phase == .Cleared && p.crank_progress != 1 { return false }
    if p.handle != .Dropped && p.dropped_feet != ([2]f32{}) { return false }
    if p.handle == .Dropped && !safe_handle_feet(scene,p.dropped_feet) { return false }
    if checkpoint < .Puzzle && (p.handle != .Shelf || p.phase != .Blocked || p.snail_seen) { return false }
    if checkpoint >= .Returned && (p.handle != .Installed || p.phase != .Cleared) { return false }
    return true
}
normalize_puzzle :: proc(p: ^Puzzle_State, scene: Runtime_Scene) {
    if p.handle == .Held { p.handle=.Dropped; p.dropped_feet=recovery_feet(scene) }
    if p.handle == .Dropped && !safe_handle_feet(scene,p.dropped_feet) { p.dropped_feet=recovery_feet(scene) }
    if p.handle != .Dropped { p.dropped_feet={} }
    p.crank_progress=0
    if p.phase == .Cleared { p.crank_progress=1 }
}
respond :: proc(g: ^Game_State, message: cstring) { g.response=message; g.response_seconds=3; g.text_page=0 }

// One guarded action per edge. Caller validates spatial focus; no action can
// cascade into a second action, including install -> activate.
puzzle_action :: proc(g: ^Game_State, action: Puzzle_Action) -> bool {
    if g.checkpoint != .Puzzle { return false }
    changed := false
    p := &g.puzzle
    switch action {
    case .None:
    case .Pickup:
        if p.handle == .Shelf || p.handle == .Dropped { p.handle=.Held; p.dropped_feet={}; changed=true }
    case .Drop:
        if p.handle == .Held { p.handle=.Dropped; p.dropped_feet=project_drop(g.scene,g.player); changed=true }
    case .Install:
        if p.handle == .Held && p.phase == .Blocked { p.handle=.Installed; changed=true }
        else { respond(g, phase_response(g^)) }
    case .Activate:
        if p.handle == .Installed && p.phase == .Blocked { p.phase=.Cranking; p.crank_progress=0; changed=true }
        else { respond(g,phase_response(g^)) }
    case .Inspect_Branch:
        if p.phase == .Blocked { respond(g,chapter_text(g^,"branch")) } else { respond(g,phase_response(g^)) }
    case .Return:
        if p.phase == .Cleared {
            g.checkpoint=.Returned
            g.player={position=marker_position(g.scene,true),grounded=true,facing=1}
            g.camera={}; follow_camera(&g.camera,g.player.position.x,g.scene.camera_bounds,g.player.position.y)
            story_begin(g,.Return); changed=true
        } else if p.phase == .Cranking { respond(g,chapter_text(g^,"turning")) }
        else { respond(g,chapter_text(g^,"blocked")) }
    case .Snail:
        if !p.snail_seen { p.snail_seen=true; changed=true }
        respond(g,chapter_text(g^,"snail"))
    }
    assert(puzzle_invariant(p^,g.checkpoint,g.scene))
    if changed { persist_game(g) }
    return changed
}
advance_crank :: proc(g: ^Game_State, dt: f32) {
    if g.checkpoint != .Puzzle || g.puzzle.phase != .Cranking { return }
    g.puzzle.crank_progress=min(1,g.puzzle.crank_progress+dt/CRANK_SECONDS)
    if g.puzzle.crank_progress>=1 {
        g.puzzle.phase=.Cleared
        g.completion_cues += 1 // observable single cue, never serialized/replayed
        respond(g,chapter_text(g^,"completion"))
        persist_game(g)
    }
    assert(puzzle_invariant(g.puzzle,g.checkpoint,g.scene))
}
refresh_puzzle_objects :: proc(g: ^Game_State) {
    if g.scene.definition == nil { return }
    d := g.scene.definition
    for v in g.scene.visuals {
        if v.interaction_index<0 { continue }
        o := &g.scene.objects[v.interaction_index]
        o.enabled=true
        switch v.kind {
        case .Handle:
            o.enabled=g.puzzle.handle==.Shelf || g.puzzle.handle==.Dropped
            o.visual=handle_rect(g.scene,g.puzzle,g.player)
            o.bounds=o.visual
            if g.puzzle.handle==.Shelf { o.bounds=local_rect(d.objects[v.id].interaction,d.objects[v.id].position) }
            o.label=chapter_text(g^,"pickup")
        case .Winch:
            o.label=chapter_text(g^,"inspect_winch")
            if g.puzzle.handle==.Held { o.label=chapter_text(g^,"install") }
            else if g.puzzle.handle==.Installed && g.puzzle.phase==.Blocked { o.label=chapter_text(g^,"activate") }
            else if g.puzzle.phase==.Cranking { o.label=chapter_text(g^,"turning") }
            else if g.puzzle.phase==.Cleared { o.label=chapter_text(g^,"clear") }
        case .Train: o.label=chapter_text(g^,"return_train")
        case .Branch: o.label=chapter_text(g^,"inspect_branch"); o.visual=branch_rect(g.scene,g.puzzle)
        case .Snail: o.label=chapter_text(g^,"wave")
        case .Shed:
        }
    }
    g.focus=focus_puzzle(g.player,g.scene,g.puzzle)
}
interact_puzzle :: proc(g: ^Game_State) {
    if g.scene.definition==nil { // preserve the M1 synthetic fixture
        if g.focus>=0 { respond(g,g.scene.objects[g.focus].response) }
        return
    }
    if g.focus<0 { _=puzzle_action(g,.Drop); return }
    for v in g.scene.visuals {
        if v.interaction_index!=g.focus { continue }
        #partial switch v.kind {
        case .Handle: _=puzzle_action(g,.Pickup)
        case .Winch:
            if g.puzzle.handle==.Held { _=puzzle_action(g,.Install) }
            else { _=puzzle_action(g,.Activate) }
        case .Branch: _=puzzle_action(g,.Inspect_Branch)
        case .Train: _=puzzle_action(g,.Return)
        case .Snail: _=puzzle_action(g,.Snail)
        }
        break
    }
}
// Compiled journey boundaries. These also guard direct calls independently of
// the content validator and never manufacture puzzle progress.
board_oliver :: proc(g: ^Game_State) {
    if g.checkpoint==.Chapter_Start && puzzle_invariant(g.puzzle,g.checkpoint,g.scene) {
        g.checkpoint=.Boarded; persist_game(g)
    }
}
enter_obstacle :: proc(g: ^Game_State) {
    if g.checkpoint==.Boarded && puzzle_invariant(g.puzzle,g.checkpoint,g.scene) {
        g.checkpoint=.Puzzle; persist_game(g)
    }
}
begin_puzzle :: proc(g: ^Game_State) {
    if g.mode!=.Obstacle_Arrival || g.checkpoint!=.Puzzle || !puzzle_invariant(g.puzzle,g.checkpoint,g.scene) { return }
    start_scene(g); refresh_puzzle_objects(g); persist_game(g); enter_mode(g,.Playing)
}
enter_arrival :: proc(g: ^Game_State) {
    if g.checkpoint==.Returned && puzzle_invariant(g.puzzle,g.checkpoint,g.scene) {
        g.checkpoint=.Arrival; persist_game(g)
    }
}
finish_oliver_journey :: proc(g: ^Game_State) {
    if g.checkpoint==.Arrival && puzzle_invariant(g.puzzle,g.checkpoint,g.scene) {
        g.checkpoint=.Complete; persist_game(g)
    }
}
show_title :: proc(g: ^Game_State) {
    if g.checkpoint==.Complete && g.mode!=.Title && puzzle_invariant(g.puzzle,g.checkpoint,g.scene) {
        persist_game(g); enter_mode(g,.Title)
    }
}
owns_paper_flower :: proc(g: Game_State) -> bool { return g.checkpoint==.Complete }

// E0 validates authored geometry; M2 adds the confirmed M1 footprint and pickup
// requirement at the recovery marker. Invalid authoring blocks the whole run.
validate_runtime_puzzle :: proc(scene:Runtime_Scene) -> bool {
    if scene.definition==nil { return true } // M1-only synthetic test fixture
    return safe_handle_feet(scene,recovery_feet(scene))
}
