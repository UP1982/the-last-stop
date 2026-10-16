package main

import c "../shared/content"
import rl "vendor:raylib"

// BATCH-1 RUNTIME BRIDGE. Assets v1 has no timing, pose map, player asset,
// set backdrop or composite attachment fields. Values match the import sidecar
// assets/characters/animation_clips.json; tests compare it against this table.
// Keep these out of saves. Replace with validated authored fields in assets v2.
Art_Clip :: struct { asset: c.ID, fps: f32, loop: bool }
ART_CLIPS := [?]Art_Clip{
    {"milo_idle_r",5,true}, {"milo_walk_r",9,true}, {"milo_jump_r",10,false},
    {"oliver_idle_r",5,true}, {"oliver_walk_r",9,true}, {"rin_idle_r",5,true},
}
PUZZLE_PLAYER_ASSET :: c.ID("milo_idle_r")
FOREST_RAIL_OFFSET :: f32(56) // Source rail y232 -> authored walking floor y288.
Art_Playback :: struct { asset: c.ID, elapsed: f32, debug_boxes: bool }

art_clip :: proc(id:c.ID) -> Art_Clip {
    for clip in ART_CLIPS { if clip.asset==id { return clip } }
    return {id,0,false}
}
art_frame :: proc(id:c.ID,elapsed:f32,count:i32) -> i32 {
    if count<=1 { return 0 }
    clip:=art_clip(id)
    frame:=i32(max(0,elapsed)*clip.fps)
    if clip.loop { return frame%count }
    return min(count-1,frame)
}
art_player_asset :: proc(base:c.ID,p:Player) -> c.ID {
    if base=="milo_idle_r" {
        if !p.grounded { return "milo_jump_r" }
        if abs(p.velocity.x)>1 { return "milo_walk_r" }
    }
    return base
}
art_actor_asset :: proc(base:c.ID,pose:c.Story_Pose) -> c.ID {
    if base=="oliver_idle_r" && (pose==.Walk || pose==.Board) { return "oliver_walk_r" }
    return base // Unavailable gestures deliberately retain authored idle art.
}
art_step_player :: proc(g:^Game_State,dt:f32) {
    id:=art_player_asset(PUZZLE_PLAYER_ASSET,g.player)
    if g.art.asset!=id { g.art.asset=id; g.art.elapsed=0 }
    else { g.art.elapsed+=dt }
}
// Round world and camera independently, exactly like collision placeholders.
// Flip UVs, reflecting the continuous pivot rather than its pixel index.
art_rects :: proc(asset:c.Asset_Def,frame:i32,anchor:rl.Vector2,camera:Camera,left:bool) -> (source,dest:rl.Rectangle) {
    w,h:=f32(asset.frame_size[0]),f32(asset.frame_size[1])
    px:=f32(asset.pivot[0]); if left { px=w-px }
    source={f32(frame)*w,0,w,h}; if left { source.width = -w }
    dest={f32(pixel(anchor.x)-pixel(camera.x))-px,f32(pixel(anchor.y)-pixel(camera.y)-asset.pivot[1]),w,h}
    return
}
art_draw :: proc(r:^Runtime_Content,id:c.ID,anchor:rl.Vector2,camera:Camera,elapsed:f32=0,left:=false) -> bool {
    if r==nil || r.snapshot==nil || id=="" { return false }
    asset,has_asset:=r.snapshot.assets[id]
    texture,has_texture:=r.textures[id]
    if !has_asset || !has_texture { return false } // No asset means intentional placeholder.
    source,dest:=art_rects(asset,art_frame(id,elapsed,asset.frame_count),anchor,camera,left)
    rl.DrawTexturePro(texture,source,dest,{},0,rl.WHITE)
    return true
}
// The matte is a fixed 640x360 view, not a tile or a 1280-wide texture. It has
// baked landmarks and foreground, so never repeat/stretch/parallax it. The
// forest is shifted down 56px to align its painted rail with floor y288;
// puzzle HUD covers the exposed top, and the canvas crops the lower edge.
art_backdrop :: proc(r:^Runtime_Content,id:c.ID,y:f32=0) -> bool {
    return art_draw(r,id,{0,y},{})
}
// Locomotive uses the object's bottom-centre anchor; carriage is coupled at
// its rear at native size. In the puzzle much of the train is intentionally
// offscreen to the left. Geometry/focus/boarding bounds stay authored.
art_train :: proc(r:^Runtime_Content,id:c.ID,anchor:rl.Vector2,camera:Camera) -> bool {
    if r==nil || r.snapshot==nil { return false }
    if id=="brass_locomotive" {
        loco,ok:=r.snapshot.assets[id]; if !ok { return false }
        car,has_car:=r.snapshot.assets["brass_passenger_car"]
        if has_car {
            rear:=anchor; rear.x-=f32(loco.pivot[0]+car.frame_size[0]-car.pivot[0])
            _=art_draw(r,"brass_passenger_car",rear,camera)
        }
    }
    return art_draw(r,id,anchor,camera)
}
art_outline :: proc(rect:rl.Rectangle,camera:Camera,color:rl.Color) {
    rl.DrawRectangleLinesEx({f32(pixel(rect.x)-pixel(camera.x)),f32(pixel(rect.y)-pixel(camera.y)),rect.width,rect.height},1,color)
}
