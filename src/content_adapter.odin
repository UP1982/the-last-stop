package main

import c "../shared/content"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

DEV_TOOLS :: #config(DEV_TOOLS, false)

Launch_Options :: struct {
    project_root, preview_scene, preview_session, preview_entry, save_directory, autoplay: string,
    dump_scene: bool,
    error: string,
}

// This domain owns options, derived geometry, labels and diagnostics. The
// snapshot has its own domain, backed by this one, and is destroyed first.
Runtime_Content :: struct {
    owner: ^c.Owner,
    snapshot: ^c.Snapshot,
    scene: Runtime_Scene,
    root, preview_directory: string,
    options: Launch_Options,
    error_lines: [dynamic]cstring,
    textures: map[c.ID]rl.Texture2D,
    text: map[string]cstring,
}
Scene_Visual :: struct {
    id: c.ID,
    kind: c.Object_Kind,
    layer: c.Layer,
    rect: rl.Rectangle,
    interaction_index: int,
    asset: c.ID,
}
Runtime_Scene :: struct {
    world, camera_bounds: rl.Rectangle,
    spawn: rl.Vector2,
    solids: []rl.Rectangle,
    objects: []Interactable,
    visuals: []Scene_Visual,
    definition: ^c.Scene_Def, // borrowed, immutable; includes all named spawns
}

valid_preview_session :: proc(id: string) -> bool {
    if len(id) < 1 || len(id) > 64 { return false }
    for ch in id {
        if !(ch >= 'a' && ch <= 'z' || ch >= '0' && ch <= '9' || ch == '_' || ch == '-') { return false }
    }
    return true
}
parse_launch_options :: proc(args: []string) -> Launch_Options {
    o: Launch_Options
    seen := make(map[string]bool)
    defer delete(seen)
    for i := 0; i < len(args); i += 1 {
        flag := args[i]
        if seen[flag] { o.error = fmt.aprintf("argument: repeated option %s", flag); return o }
        seen[flag] = true
        development_option:=false
        when DEV_TOOLS {
            if flag=="--dump-scene" { o.dump_scene=true; continue }
            development_option=flag=="--preview-scene" || flag=="--preview-session" || flag=="--preview-entry" || flag=="--autoplay"
        }
        if flag=="--project-root" || flag=="--save-dir" || development_option {
            if i+1>=len(args) || args[i+1]=="" || strings.has_prefix(args[i+1],"--") {
                o.error=fmt.aprintf("argument: %s requires a value",flag); return o
            }
            i+=1
            switch flag {
            case "--project-root": o.project_root=strings.clone(args[i])
            case "--save-dir": o.save_directory=strings.clone(args[i])
            }
            when DEV_TOOLS {
                switch flag {
                case "--autoplay": o.autoplay=strings.clone(args[i])
                case "--preview-scene": o.preview_scene=strings.clone(args[i])
                case "--preview-session": o.preview_session=strings.clone(args[i])
                case "--preview-entry": o.preview_entry=strings.clone(args[i])
                }
            }
        } else { o.error=fmt.aprintf("argument: unsupported option %s",flag); return o }
    }
    if o.save_directory != "" && !filepath.is_abs(o.save_directory) { o.error="save: --save-dir requires an absolute path" }
    if o.autoplay != "" && o.save_directory == "" && o.preview_scene == "" { o.error="autoplay: requires explicit --save-dir or preview profile" }
    when DEV_TOOLS {
    if o.preview_scene != "" || o.preview_session != "" || o.preview_entry != "" {
        if o.preview_scene != "oliver_obstacle" || !valid_preview_session(o.preview_session) {
            o.error = "preview: requires --preview-scene oliver_obstacle and --preview-session [a-z0-9_-]{1,64}"
        }
    }
    if o.preview_entry != "" && o.preview_entry != "scene" && o.preview_entry != "chapter" { o.error="preview: --preview-entry must be chapter or scene" }
    }
    return o
}

// First available content location wins; invalid content there NEVER falls
// through to a different graph. No cwd search. The build/ parent rule is only
// for the unpackaged checkout, after the explicit project-root fallback.
resolve_content_root :: proc(executable, explicit_root: string) -> string {
    dir := filepath.dir(executable)
    if os.exists(fmt.aprintf("%s/data", dir)) { return strings.clone(dir) }
    if filepath.base(dir) == "MacOS" && filepath.base(filepath.dir(dir)) == "Contents" {
        resources := fmt.aprintf("%s/Resources", filepath.dir(dir))
        if os.exists(fmt.aprintf("%s/data", resources)) { return resources }
    }
    if explicit_root != "" {
        root, err := filepath.abs(explicit_root)
        if err == nil { return root }
        return strings.clone(explicit_root) // loader reports the failed root
    }
    if filepath.base(dir) == "build" && os.exists(fmt.aprintf("%s/data", filepath.dir(dir))) {
        return strings.clone(filepath.dir(dir))
    }
    return strings.clone(dir) // missing content gets normal loader diagnostics
}

content_error :: proc(r: ^Runtime_Content, message: string) {
    fmt.eprintln(message)
    // Pre-wrap once. Rendering never allocates or uses the temp allocator.
    for source_line in strings.split_lines(message) {
        line := source_line
        for len(line) > 48 {
            append(&r.error_lines, strings.clone_to_cstring(line[:48]))
            line = line[48:]
        }
        append(&r.error_lines, strings.clone_to_cstring(line))
    }
}
rect_from_content :: proc(r: c.Recti) -> rl.Rectangle { return {f32(r.x), f32(r.y), f32(r.w), f32(r.h)} }
local_rect :: proc(r: c.Recti, p: c.Vec2i) -> rl.Rectangle {
    return {f32(r.x+p[0]), f32(r.y+p[1]), f32(r.w), f32(r.h)}
}

adapt_scene :: proc(def: ^c.Scene_Def) -> Runtime_Scene {
    scene := Runtime_Scene{definition=def, world=rect_from_content(def.world_bounds), camera_bounds=rect_from_content(def.camera_bounds)}
    spawn := def.spawns[def.puzzle.player_spawn].position
    scene.spawn = {f32(spawn[0]), f32(spawn[1])}
    ordered := make([]c.Object_Def, len(def.objects))
    n := 0
    collisions, interactions := 1, 0
    for _, object in def.objects {
        ordered[n] = object; n += 1
        if object.has_collision { collisions += 1 }
        if object.has_interaction { interactions += 1 }
    }
    defer delete(ordered)
    slice.sort_by(ordered, proc(a, b: c.Object_Def) -> bool {
        if a.layer != b.layer { return a.layer < b.layer }
        return a.id < b.id
    })
    scene.solids = make([]rl.Rectangle, collisions)
    scene.objects = make([]Interactable, interactions)
    scene.visuals = make([]Scene_Visual, len(ordered))
    scene.solids[0] = rect_from_content(def.ground)
    si, ii := 1, 0
    for object, i in ordered {
        visual := rl.Rectangle{f32(object.position[0]), f32(object.position[1]), f32(object.size[0]), f32(object.size[1])}
        scene.visuals[i] = {object.id, object.kind, object.layer, visual, -1, object.asset}
        if object.has_collision { scene.solids[si] = local_rect(object.collision, object.position); si += 1 }
        if object.has_interaction {
            scene.objects[ii] = {local_rect(object.interaction, object.position), visual,
                strings.clone_to_cstring(string(object.id)), "", true}
            scene.visuals[i].interaction_index = ii
            ii += 1
        }
    }
    return scene
}

load_runtime_content :: proc(args: []string, allocator: mem.Allocator) -> Runtime_Content {
    r := Runtime_Content{owner=c.new_owner(allocator)}
    context.allocator = c.owner_allocator(r.owner)
    r.options = parse_launch_options(args)
    if r.options.error != "" { content_error(&r, r.options.error); return r }
    executable, err := os.get_executable_path(context.allocator)
    if err != nil { content_error(&r, "content_root: cannot locate executable"); return r }
    r.root = resolve_content_root(executable, r.options.project_root)
    when DEV_TOOLS {
        if r.options.preview_scene != "" {
            home, home_err := os.user_home_dir(context.allocator)
            if home_err != nil || home == "" { content_error(&r, "preview: cannot resolve home directory; no profile fallback"); return r }
            r.preview_directory = fmt.aprintf("%s/Library/Caches/The Last Stop/preview/%s", home, r.options.preview_session)
            // No files or saves exist in E0b. Reserve this path without writing
            // even the directory; M2 must use it and refuse normal-save fallback.
        }
    }
    loaded := c.load_chapter(r.root, c.CHAPTER_PATH, context.allocator)
    defer c.destroy_load_result(&loaded)
    if loaded.snapshot == nil {
        content_error(&r, fmt.aprintf("Content root: %s", r.root))
        for d in loaded.diagnostics {
            content_error(&r, fmt.aprintf("%s %s:%d:%d %s: %s", d.code, d.file, d.line, d.column, d.pointer, d.message))
        }
        return r
    }
    // The content tool may inspect/adapt v1 documents, but gameplay needs the
    // complete six-role v2 graph. Refuse before resources, menus or save setup.
    if loaded.snapshot.chapter.schema_version != 2 {
        content_error(&r, "story_migration_required: Chapter content is schema v1; migrate to v2 to play")
        return r
    }
    for _, dialogue in loaded.snapshot.dialogues {
        if dialogue.schema_version != 2 {
            content_error(&r, fmt.aprintf("story_migration_required: Dialogue %s is schema v1; migrate to v2 to play", dialogue.id))
            return r
        }
    }
    // Transfer only the complete, validated graph, never an intermediate DOM.
    r.snapshot = loaded.snapshot; loaded.snapshot = nil
    r.text=make(map[string]cstring)
    for key,value in r.snapshot.chapter.strings { r.text[key]=strings.clone_to_cstring(value) }
    def, ok := c.find_scene(r.snapshot, r.snapshot.chapter.puzzle_scene)
    assert(ok) // graph validation guarantees the link
    r.scene = adapt_scene(def)
    return r
}

// Resource creation is staged after InitWindow, from validated snapshot bytes
// (never a second unvalidated disk read). Any failure blocks the whole chapter.
stage_content_resources :: proc(r: ^Runtime_Content) -> bool {
    if r.snapshot == nil { return false }
    context.allocator = c.owner_allocator(r.owner)
    // Stage in a separate map. Failure releases every uploaded candidate and
    // leaves the active texture map untouched (including explicit reloads).
    staged:=make(map[c.ID]rl.Texture2D)
    m4_resource_balance(0)
    success:=false
    defer {
        if !success {
            for _,texture in staged { rl.UnloadTexture(texture); m4_resource_balance(-1) }
            delete(staged)
        }
    }
    for id, asset in r.snapshot.assets {
        bytes: []u8
        for source in r.snapshot.sources { if source.path == asset.path { bytes = source.bytes; break } }
        ext := strings.clone_to_cstring(filepath.ext(asset.path))
        image := rl.LoadImageFromMemory(ext, raw_data(bytes), i32(len(bytes)))
        if !rl.IsImageValid(image) { content_error(r, fmt.aprintf("resource_decode %s: cannot decode image", asset.path)); return false }
        dimensions_ok := image.width == asset.frame_size[0]*asset.frame_count && image.height == asset.frame_size[1]
        if !dimensions_ok {
            rl.UnloadImage(image)
            content_error(r, fmt.aprintf("resource_size %s: image differs from declared sprite strip", asset.path)); return false
        }
        when #config(M4_TEST_HOOKS,false) {
            if os.get_env("TLS_M4_UPLOAD_FAIL",context.temp_allocator)=="1" && len(staged)>=3 {
                rl.UnloadImage(image); content_error(r,"resource_upload: injected after three uploads"); return false
            }
        }
        texture := rl.LoadTextureFromImage(image)
        rl.UnloadImage(image)
        if !rl.IsTextureValid(texture) { content_error(r, fmt.aprintf("resource_upload %s: cannot create texture", asset.path)); return false }
        rl.SetTextureFilter(texture, .POINT)
        staged[id] = texture
        m4_resource_balance(1)
    }
    for _,texture in r.textures { rl.UnloadTexture(texture); m4_resource_balance(-1) }
    delete(r.textures)
    r.textures=staged
    success=true
    return true
}
// DEV F5: validate the complete candidate plus GPU resources before publishing.
// A rejected reload keeps the previous snapshot/resources and gameplay active.
when DEV_TOOLS {
reload_runtime_content :: proc(g:^Game_State,r:^Runtime_Content,args:[]string=nil) -> bool {
    args:=args; if args==nil { args=os.args[1:] }
    candidate:=load_runtime_content(args,context.allocator)
    if candidate.snapshot==nil || !stage_content_resources(&candidate) || !validate_runtime_puzzle(candidate.scene) {
        fmt.eprintln("reload rejected: retaining active content/resources")
        unload_runtime_content(&candidate)
        return false
    }
    puzzle:=g.puzzle
    if puzzle.handle==.Dropped && !safe_handle_feet(candidate.scene,puzzle.dropped_feet) { puzzle.dropped_feet=recovery_feet(candidate.scene) }
    if !puzzle_invariant(puzzle,g.checkpoint,candidate.scene) {
        unload_runtime_content(&candidate); return false
    }
    old:=r^
    r^=candidate
    changed:=puzzle!=g.puzzle
    g.content=r; g.content_ready=true; g.scene=r.scene; g.puzzle=puzzle
    // Clear every borrowed render label/response before destroying the old
    // owner, including while paused. Reload restarts placement, not progress.
    start_scene(g)
    refresh_puzzle_objects(g)
    g.art.asset=""; g.art.elapsed=0
    unload_runtime_content(&old)
    if changed && g.save.active { _=persist_game(g) }
    return true
}
}
unload_runtime_content :: proc(r: ^Runtime_Content) {
    for _, texture in r.textures { rl.UnloadTexture(texture); m4_resource_balance(-1) }
    c.destroy_snapshot(r.snapshot)
    c.destroy_owner(r.owner)
    r^ = {}
}
configure_content :: proc(game: ^Game_State, r: ^Runtime_Content, ready: bool) {
    game.content = r
    game.content_ready = ready
    if !ready { enter_mode(game, .Content_Error); return }
    game.scene = r.scene
    if !validate_runtime_puzzle(game.scene) {
        content_error(r,"M2 handle_recovery is not walkable/pickup-focusable with the M1 footprint and scene targets; chapter blocked")
        game.content_ready=false; enter_mode(game,.Content_Error); return
    }
    when DEV_TOOLS {
        if r.options.preview_scene != "" { start_scene(game); enter_mode(game, .Playing) }
        if r.options.dump_scene { dump_runtime_scene(r) }
    }
}
when DEV_TOOLS {
    dump_runtime_scene :: proc(r: ^Runtime_Content) {
        def := r.scene.definition
        fmt.eprintf("E0B scene=%s root=%s preview_directory=%s world=%v camera=%v ground=%v spawn=%v\n", def.id, r.root, r.preview_directory, def.world_bounds, def.camera_bounds, def.ground, r.scene.spawn)
        for v in r.scene.visuals {
            object := def.objects[v.id]
            fmt.eprintf("E0B object=%s position=%v size=%v interaction_local=%v interaction_world=%v\n", object.id, object.position, object.size, object.interaction, local_rect(object.interaction, object.position))
        }
    }
}
