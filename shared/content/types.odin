package content

import "core:encoding/json"
import "core:mem"

ID :: distinct string
Revision :: [32]u8
Vec2i :: [2]i32
Recti :: struct { x, y, w, h: i32 }
Object_Kind :: enum { Train, Branch, Winch, Shed, Handle, Snail }
Layer :: enum { Background, World, Foreground }
Spawn_Kind :: enum { Player_Feet, Handle_Bottom_Center }
Object_Def :: struct {
    id: ID,
    kind: Object_Kind,
    position, size: Vec2i,
    layer: Layer,
    has_collision: bool,
    collision: Recti,
    has_interaction: bool,
    interaction: Recti,
    has_asset: bool,
    asset: ID,
}
Spawn_Def :: struct { id: ID, kind: Spawn_Kind, position: Vec2i }
Reference :: struct { id: ID, path: string }
Speaker_Def :: struct { name, species: string }
Keepsake_Def :: struct { name: string }
Chapter_Def :: struct {
    id: ID,
    title, destination: string,
    passenger, reward, puzzle_scene: ID,
    speakers: map[ID]Speaker_Def,
    keepsakes: map[ID]Keepsake_Def,
    assets: Reference,
    scenes: []Reference,
    dialogues: map[string]Reference,
}
Puzzle_Def :: struct {
    kind: string,
    train, branch, winch, shed, handle, snail: ID,
    player_spawn, return_spawn, handle_recovery_spawn: ID,
    winch_socket, winch_rope_anchor, branch_rope_anchor, branch_cleared_position: Vec2i,
}
Scene_Def :: struct {
    id: ID,
    scene_type: string,
    world_bounds, camera_bounds, ground: Recti,
    spawns: map[ID]Spawn_Def,
    objects: map[ID]Object_Def,
    puzzle: Puzzle_Def,
}
Line_Def :: struct { speaker: ID, text: string }
Dialogue_Def :: struct {
    id: ID,
    order: []ID,
    lines: map[ID]Line_Def,
    action, destination: string,
}
Provenance :: struct { creator, source, license, attribution: string }
Asset_Def :: struct {
    id: ID,
    path, sha256: string,
    frame_size, pivot: Vec2i,
    frame_count: i32,
    provenance: Provenance,
}
Severity :: enum { Error, Warning }
Diagnostic :: struct {
    severity: Severity,
    code, file, pointer, subject_id, message: string,
    line, column: int,
    op_index: int,
}
Document_Source :: struct { path: string, bytes: []u8, revision: Revision }
Document :: struct { source: Document_Source, value: json.Value, id: ID, kind: string }
// A snapshot and its DOM/typed strings are one owned allocation domain. Treat all
// fields as immutable. No strings borrow request buffers or temporary allocators.
Snapshot :: struct {
    owner: ^Owner,
    chapter: Chapter_Def,
    chapter_path: string,
    documents: [dynamic]Document,
    sources: [dynamic]Document_Source, // Includes referenced binary assets.
    scenes: map[ID]Scene_Def,
    dialogues: map[ID]Dialogue_Def,
    assets: map[ID]Asset_Def,
    revision: Revision,
}
Load_Result :: struct {
    snapshot: ^Snapshot,
    diagnostics: []Diagnostic,
    owner: ^Owner,
}
// Allocation domain backed exclusively by the caller's allocator, including its
// bookkeeping. Destruction frees every live allocation, even on parse failure.
Owner :: struct { backing: mem.Allocator, tracker: mem.Tracking_Allocator }
new_owner :: proc(allocator: mem.Allocator) -> ^Owner {
    o := new(Owner, allocator)
    o.backing = allocator
    mem.tracking_allocator_init(&o.tracker, allocator, allocator)
    return o
}
owner_allocator :: proc(o: ^Owner) -> mem.Allocator { return mem.tracking_allocator(&o.tracker) }
destroy_owner :: proc(o: ^Owner) {
    if o == nil { return }
    a := o.backing
    for p in o.tracker.allocation_map { mem.free(p, a) }
    mem.tracking_allocator_destroy(&o.tracker)
    free(o, a)
}
// Transfer a successful snapshot by setting result.snapshot=nil before calling
// destroy_load_result. Its owner transfers with it. Destruction clears handles.
destroy_load_result :: proc(r: ^Load_Result) {
    if r.snapshot != nil { destroy_snapshot(r.snapshot) }
    else if r.owner != nil { destroy_owner(r.owner) }
    r^ = {}
}
destroy_snapshot :: proc(s: ^Snapshot) { if s != nil { destroy_owner(s.owner) } }
find_scene :: proc(s: ^Snapshot, id: ID) -> (^Scene_Def, bool) {
    if s == nil { return nil, false }
    p := &s.scenes[id]
    return p, p != nil
}
diagnostic :: proc(code, file, pointer, message: string, op_index := -1) -> Diagnostic {
    return {code=code, file=file, pointer=pointer, message=message, op_index=op_index}
}
MAX_DOCUMENT_BYTES :: 262144
MAX_ASSET_BYTES :: 16777216
MAX_GRAPH_BYTES :: 33554432
MAX_SOURCES :: 64
MAX_DEPTH :: 32
MAX_TOKENS :: 65536
CHAPTER_PATH :: "data/chapters/chapter_01.json"
// Allows the contract's `odin check shared/content` package check. Imported
// packages never execute this entry point; runtime callers use load_chapter.
@(private)
main :: proc() {}

// Scene v2: one authored unit is one pixel of the 640x360 virtual canvas.
// Scene v1 used half-sized units and must never be interpreted as v2.
SCENE_VERSION :: 2
VIEW_WIDTH :: 640
VIEW_HEIGHT :: 360
PLAYER_WIDTH :: 24
PLAYER_HEIGHT :: 32
