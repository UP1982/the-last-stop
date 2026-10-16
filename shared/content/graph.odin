package content

import "core:fmt"

scene_validate :: proc(v: ^Validator, s: ^Scene_Def, assets: map[ID]Asset_Def) {
    w,g:=s.world_bounds,s.ground
    if !inside(g,w) || g.x!=w.x || g.w!=w.w { fail(v,"corridor","/ground","Ground must form one continuous world-width corridor") }
    if !inside(s.camera_bounds,w) || s.camera_bounds.w<VIEW_WIDTH || s.camera_bounds.h<VIEW_HEIGHT { fail(v,"camera","/camera_bounds","Camera must fit inside world and contain a 640x360 view") }
    counts: [Object_Kind]int
    for id,o in s.objects {
        p:=ptr("/objects",string(id)); counts[o.kind]+=1
        if !inside({o.position[0],o.position[1],o.size[0],o.size[1]},w) { fail(v,"geometry",p,"Object outside world bounds") }
        if o.has_asset { if _,ok:=assets[o.asset]; !ok { fail(v,"missing_asset",ptr(p,"asset"),"Asset ID not found") } }
        if o.has_collision {
            r:=o.collision; r.x+=o.position[0]; r.y+=o.position[1]
            if !inside(r,w) || intersects(r,{g.x,g.y-PLAYER_HEIGHT,g.w,PLAYER_HEIGHT}) { fail(v,"corridor",ptr(p,"collision"),"Collision obstructs walking corridor or escapes world") }
            if o.kind==.Shed { fail(v,"corridor",ptr(p,"collision"),"Shed must be non-solid") }
        }
        if o.has_interaction {
            r:=o.interaction; r.x+=o.position[0]; r.y+=o.position[1]
            // There must be a player position on the continuous ground corridor
            // intersecting the interaction. Player footprint matches scene-v2 movement.
            if !intersects(r,{g.x,g.y-PLAYER_HEIGHT,g.w,PLAYER_HEIGHT}) { fail(v,"unreachable",ptr(p,"interaction"),"Interaction does not reach walking corridor") }
        } else if o.kind!=.Shed { fail(v,"missing_interaction",ptr(p,"interaction"),"Interactive object requires bounds") }
    }
    for k in Object_Kind { if k!=.Snail && counts[k]!=1 || k==.Snail && counts[k]>1 { fail(v,"puzzle_cardinality","/objects","Exactly one of each required object kind; at most one snail") } }
    p:=s.puzzle
    roles:=[]ID{p.train,p.branch,p.winch,p.shed,p.handle}
    kinds:=[]Object_Kind{.Train,.Branch,.Winch,.Shed,.Handle}
    names:=[]string{"train","branch","winch","shed","handle"}
    for id,i in roles { o,ok:=s.objects[id]; if !ok || o.kind!=kinds[i] { fail(v,"object_link",ptr("/puzzle",names[i]),"Missing or wrong-kind object link") } }
    if p.snail!="" { if o,ok:=s.objects[p.snail]; !ok || o.kind!=.Snail { fail(v,"object_link","/puzzle/snail","Invalid optional snail link") } }
    if counts[.Snail]==1 && p.snail=="" { fail(v,"object_link","/puzzle/snail","Present snail requires its optional interaction link") }
    for id,spawn in s.spawns {
        width,height:i32=PLAYER_WIDTH,PLAYER_HEIGHT
        if spawn.kind==.Handle_Bottom_Center {
            if h,ok:=s.objects[p.handle]; ok { width,height=h.size[0],h.size[1] }
        }
        r:=Recti{spawn.position[0]-width/2,spawn.position[1]-height,width,height}
        if spawn.position[1]!=g.y || !inside(r,w) || r.x<g.x || r.x+r.w>g.x+g.w { fail(v,"spawn",ptr("/spawns",string(id)),"Spawn must be supported inside ground corridor") }
        for _,o in s.objects {
            if o.has_collision {
                c:=o.collision; c.x+=o.position[0]; c.y+=o.position[1]
                if intersects(c,r) { fail(v,"spawn",ptr("/spawns",string(id)),"Spawn obstructed") }
            }
        }
    }
    spawn_ids:=[]ID{p.player_spawn,p.return_spawn,p.handle_recovery_spawn}
    for id,i in spawn_ids {
        spawn,ok:=s.spawns[id]
        expected:=Spawn_Kind.Player_Feet; if i==2 { expected=.Handle_Bottom_Center }
        if !ok || spawn.kind!=expected { fail(v,"spawn_link","/puzzle","Missing or wrong-kind spawn link") }
    }
    winch:=s.objects[p.winch]; branch:=s.objects[p.branch]
    for anchor,i in ([]Vec2i{p.winch_socket,p.winch_rope_anchor,p.branch_rope_anchor}) {
        size:=winch.size; if i==2 { size=branch.size }
        if anchor[0]<0 || anchor[1]<0 || anchor[0]>=size[0] || anchor[1]>=size[1] { fail(v,"anchor","/puzzle","Socket and rope anchors must be within their objects") }
    }
    if branch.has_collision {
        cleared:=branch.collision; cleared.x+=p.branch_cleared_position[0]; cleared.y+=p.branch_cleared_position[1]
        if !inside(cleared,w) || intersects(cleared,{g.x,g.y-PLAYER_HEIGHT,g.w,PLAYER_HEIGHT}) { fail(v,"corridor","/puzzle/branch_cleared_position","Cleared branch collision obstructs corridor or escapes world") }
    }
    if !inside({p.branch_cleared_position[0],p.branch_cleared_position[1],branch.size[0],branch.size[1]},w) { fail(v,"geometry","/puzzle/branch_cleared_position","Cleared branch outside world") }
}
graph_validate :: proc(v: ^Validator,s: ^Snapshot) {
    c:=s.chapter; v.file=s.chapter_path
    if _,ok:=c.speakers[c.passenger]; !ok { fail(v,"speaker","/passenger","Passenger must resolve to a speaker") }
    if _,ok:=c.keepsakes[c.reward]; !ok || len(c.keepsakes)!=1 { fail(v,"reward","/reward","Chapter has exactly one declared keepsake reward") }
    if _,ok:=s.scenes[c.puzzle_scene]; !ok { fail(v,"scene_link","/puzzle_scene","Puzzle scene not referenced") }
    object_ids:=make(map[ID]bool); spawn_ids:=make(map[ID]bool); line_ids:=make(map[ID]bool)
    for doc in s.documents {
        v.file=doc.source.path
        if doc.kind=="scene" {
            scene:=&s.scenes[doc.id]
            for id in scene.objects { if object_ids[id] { fail(v,"duplicate_identity",ptr("/objects",string(id)),"Object ID duplicated chapter-wide") }; object_ids[id]=true }
            for id in scene.spawns { if spawn_ids[id] { fail(v,"duplicate_identity",ptr("/spawns",string(id)),"Spawn ID duplicated chapter-wide") }; spawn_ids[id]=true }
            scene_validate(v,scene,s.assets)
        }
        if doc.kind=="dialogue" {
            d:=s.dialogues[doc.id]
            seen:=make(map[ID]bool)
            for id in d.order {
                if seen[id] { fail(v,"order","/order","Repeated line ID") }; seen[id]=true
                if _,ok:=d.lines[id]; !ok { fail(v,"order","/order","Ordered line missing") }
            }
            if len(seen)!=len(d.lines) { fail(v,"order","/order","Order must contain every line exactly once") }
            for id,line in d.lines {
                if !seen[id] { fail(v,"order","/order","Unordered line") }
                if line_ids[id] { fail(v,"duplicate_identity",ptr("/lines",string(id)),"Line ID duplicated chapter-wide") }; line_ids[id]=true
                if _,ok:=c.speakers[line.speaker]; !ok { fail(v,"speaker",ptr(ptr("/lines",string(id)),"speaker"),"Unknown speaker") }
            }
        }
    }
    for role,ref in c.dialogues {
        d,ok:=s.dialogues[ref.id]
        v.file=ref.path
        action,destination:="board_oliver","train_travel"
        if role=="arrival" { action,destination="finish_oliver_journey","chapter_complete" }
        if !ok || d.action!=action || d.destination!=destination { fail(v,"completion","/completion",fmt.aprintf("%s requires %s -> %s",role,action,destination)) }
    }
    if c.dialogues["intro"].id==c.dialogues["arrival"].id { fail(v,"reward","/completion","Dialogue roles must have distinct documents; only arrival awards the reward") }
}
