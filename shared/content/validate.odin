package content

import "core:encoding/json"
import "core:strings"
import "core:fmt"

Validator :: struct { diagnostics: [dynamic]Diagnostic, file: string }
fail :: proc(v: ^Validator, code, pointer, message: string) {
    if len(v.diagnostics) < 128 { append(&v.diagnostics, diagnostic(code, v.file, pointer, message)) }
}
ptr :: proc(base, key: string) -> string {
    escaped, _ := strings.replace_all(key, "~", "~0")
    escaped, _ = strings.replace_all(escaped, "/", "~1")
    return fmt.aprintf("%s/%s", base, escaped)
}
get :: proc(v: json.Value, key: string) -> json.Value { o, _ := v.(json.Object); return o[key] }
text :: proc(v: json.Value) -> string { s, _ := v.(string); return s }
integer :: proc(v: json.Value) -> i64 { n, _ := v.(i64); return n }
object :: proc(v: json.Value) -> json.Object { o, _ := v.(json.Object); return o }
array :: proc(v: json.Value) -> json.Array { a, _ := v.(json.Array); return a }
has :: proc(v: json.Value, key: string) -> bool { o, _ := v.(json.Object); _, ok := o[key]; return ok }
member :: proc(s, options: string) -> bool {
    if options == "" { return false }
    for x in strings.split(options, "|") { if s == x { return true } }
    return false
}
valid_id :: proc(s: string) -> bool {
    if len(s) < 1 || len(s) > 64 || s[0] < 'a' || s[0] > 'z' { return false }
    for c in s { if !(c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '_') { return false } }
    return true
}
valid_path :: proc(s, prefix: string) -> bool {
    if !strings.has_prefix(s, prefix) || len(s) > 240 || strings.contains(s, "\\") || strings.contains(s, ":") { return false }
    for c in s { if c < 32 || c == 127 { return false } }
    for part in strings.split(s, "/") { if part == "" || part == "." || part == ".." { return false } }
    return true
}
keys :: proc(v: ^Validator, value: json.Value, p, required, optional: string) -> bool {
    o, ok := value.(json.Object)
    if !ok { fail(v, "type", p, "Expected object"); return false }
    if len(o) > 1024 { fail(v, "count_limit", p, "Too many map entries"); return false }
    if required != "" {
        for k in strings.split(required, "|") { if _, present := o[k]; !present { fail(v, "missing_field", ptr(p,k), "Required field missing") } }
    }
    for k in o { if !member(k, required) && !member(k, optional) { fail(v, "unknown_field", ptr(p,k), "Unknown field") } }
    return true
}
str :: proc(v: ^Validator, x: json.Value, p: string, max_len := 4096, nonempty := true) -> string {
    s, ok := x.(string)
    if !ok || len(s) > max_len || nonempty && len(s) == 0 { fail(v, "type", p, "Expected bounded string"); return "" }
    return s
}
id_value :: proc(v: ^Validator, x: json.Value, p: string) -> ID {
    s := str(v,x,p,64)
    if !valid_id(s) { fail(v,"invalid_id",p,"Expected [a-z][a-z0-9_]{0,63}") }
    return ID(s)
}
choice :: proc(v: ^Validator, x: json.Value, p, options: string) -> string {
    s := str(v,x,p)
    if !member(s,options) { fail(v,"enum",p,"Unsupported value") }
    return s
}
int_value :: proc(v: ^Validator, x: json.Value, p: string, low, high: i64) -> i32 {
    n, ok := x.(i64)
    if !ok || n < low || n > high { fail(v,"number_range",p,"Expected bounded integer"); return 0 }
    return i32(n)
}
vector :: proc(v: ^Validator, x: json.Value, p: string, positive := false) -> Vec2i {
    a, ok := x.(json.Array)
    if !ok || len(a) != 2 { fail(v,"geometry",p,"Expected [x,y]"); return {} }
    lo: i64 = -16384; if positive { lo = 1 }
    return {int_value(v,a[0],ptr(p,"0"),lo,16384),int_value(v,a[1],ptr(p,"1"),lo,16384)}
}
rectangle :: proc(v: ^Validator, x: json.Value, p: string) -> Recti {
    a, ok := x.(json.Array)
    if !ok || len(a) != 4 { fail(v,"geometry",p,"Expected [x,y,width,height]"); return {} }
    return {int_value(v,a[0],ptr(p,"0"),-16384,16384),int_value(v,a[1],ptr(p,"1"),-16384,16384),int_value(v,a[2],ptr(p,"2"),1,16384),int_value(v,a[3],ptr(p,"3"),1,16384)}
}
inside :: proc(inner, outer: Recti) -> bool {
    return inner.x >= outer.x && inner.y >= outer.y && inner.x+inner.w <= outer.x+outer.w && inner.y+inner.h <= outer.y+outer.h
}
intersects :: proc(a,b: Recti) -> bool { return a.x < b.x+b.w && b.x < a.x+a.w && a.y < b.y+b.h && b.y < a.y+a.h }
reference :: proc(v: ^Validator, x: json.Value, p, prefix: string) -> Reference {
    keys(v,x,p,"id|path","")
    r := Reference{id_value(v,get(x,"id"),ptr(p,"id")), str(v,get(x,"path"),ptr(p,"path"),240)}
    if !valid_path(r.path,prefix) || !strings.has_suffix(r.path,".json") { fail(v,"unsafe_path",ptr(p,"path"),"Reference must stay in its expected data subtree") }
    return r
}
envelope :: proc(v: ^Validator, x: json.Value, kind: string) -> ID {
    if !has(x,"schema_version") { fail(v,"migration_required","/schema_version","Versionless content requires explicit migration"); return "" }
    n, ok := get(x,"schema_version").(i64)
    if !ok || n != 1 { fail(v,"unsupported_version","/schema_version","Only schema_version 1 is supported") }
    if text(get(x,"kind")) != kind { fail(v,"wrong_kind","/kind","Wrong document kind") }
    return id_value(v,get(x,"id"),"/id")
}
chapter_decode :: proc(v: ^Validator, x: json.Value) -> Chapter_Def {
    c: Chapter_Def
    c.id = envelope(v,x,"chapter")
    keys(v,x,"","kind|schema_version|id|title|speakers|passenger|destination|keepsakes|reward|assets|scenes|puzzle_scene|dialogues","")
    c.title = str(v,get(x,"title"),"/title")
    c.destination = str(v,get(x,"destination"),"/destination")
    c.passenger = id_value(v,get(x,"passenger"),"/passenger")
    c.reward = id_value(v,get(x,"reward"),"/reward")
    c.puzzle_scene = id_value(v,get(x,"puzzle_scene"),"/puzzle_scene")
    c.speakers = make(map[ID]Speaker_Def)
    speakers := get(x,"speakers")
    for k, val in map_check(v,speakers,"/speakers") {
        p := ptr("/speakers",k); keys(v,val,p,"name|species","")
        c.speakers[ID(k)] = {str(v,get(val,"name"),ptr(p,"name")),str(v,get(val,"species"),ptr(p,"species"))}
    }
    c.keepsakes = make(map[ID]Keepsake_Def)
    for k,val in map_check(v,get(x,"keepsakes"),"/keepsakes") {
        p := ptr("/keepsakes",k); keys(v,val,p,"name","")
        c.keepsakes[ID(k)] = {str(v,get(val,"name"),ptr(p,"name"))}
    }
    c.assets = reference(v,get(x,"assets"),"/assets","data/assets/")
    scenes, ok := get(x,"scenes").(json.Array)
    if !ok || len(scenes) == 0 || len(scenes) > 16 { fail(v,"count_limit","/scenes","Expected 1..16 scene references") }
    c.scenes = make([]Reference,len(scenes))
    for val,i in scenes { c.scenes[i] = reference(v,val,fmt.aprintf("/scenes/%d",i),"data/scenes/") }
    d := get(x,"dialogues"); keys(v,d,"/dialogues","intro|arrival","")
    c.dialogues = make(map[string]Reference)
    for role in ([]string{"intro","arrival"}) { c.dialogues[role] = reference(v,get(d,role),ptr("/dialogues",role),"data/dialogue/") }
    return c
}
map_check :: proc(v: ^Validator, x: json.Value, p: string) -> json.Object {
    o, ok := x.(json.Object)
    if !ok || len(o) > 1024 { fail(v,"type",p,"Expected map with at most 1024 entries"); return nil }
    for k in o { if !valid_id(k) { fail(v,"invalid_id",ptr(p,k),"Invalid map identity") } }
    return o
}
scene_decode :: proc(v: ^Validator, x: json.Value) -> Scene_Def {
    s: Scene_Def
    s.id = envelope(v,x,"scene")
    keys(v,x,"","kind|schema_version|id|scene_type|world_bounds|camera_bounds|ground|spawns|objects|puzzle","")
    s.scene_type = choice(v,get(x,"scene_type"),"/scene_type","oliver_puzzle")
    s.world_bounds = rectangle(v,get(x,"world_bounds"),"/world_bounds")
    s.camera_bounds = rectangle(v,get(x,"camera_bounds"),"/camera_bounds")
    s.ground = rectangle(v,get(x,"ground"),"/ground")
    s.spawns = make(map[ID]Spawn_Def)
    for k,val in map_check(v,get(x,"spawns"),"/spawns") {
        p := ptr("/spawns",k); keys(v,val,p,"kind|position","")
        kind := choice(v,get(val,"kind"),ptr(p,"kind"),"player_feet|handle_bottom_center")
        s.spawns[ID(k)] = {ID(k), .Player_Feet if kind == "player_feet" else .Handle_Bottom_Center,vector(v,get(val,"position"),ptr(p,"position"))}
    }
    s.objects = make(map[ID]Object_Def)
    for k,val in map_check(v,get(x,"objects"),"/objects") {
        p := ptr("/objects",k); keys(v,val,p,"kind|position|size|layer","collision|interaction|asset")
        kind := choice(v,get(val,"kind"),ptr(p,"kind"),"train|branch|winch|shed|handle|snail")
        layer := choice(v,get(val,"layer"),ptr(p,"layer"),"background|world|foreground")
        o := Object_Def{id=ID(k),position=vector(v,get(val,"position"),ptr(p,"position")),size=vector(v,get(val,"size"),ptr(p,"size"),true)}
        switch kind { case "train": o.kind=.Train; case "branch": o.kind=.Branch; case "winch": o.kind=.Winch; case "shed": o.kind=.Shed; case "handle": o.kind=.Handle; case "snail": o.kind=.Snail }
        switch layer { case "background": o.layer=.Background; case "world": o.layer=.World; case "foreground": o.layer=.Foreground }
        if has(val,"collision") { o.has_collision=true; o.collision=rectangle(v,get(val,"collision"),ptr(p,"collision")) }
        if has(val,"interaction") { o.has_interaction=true; o.interaction=rectangle(v,get(val,"interaction"),ptr(p,"interaction")) }
        if has(val,"asset") { o.has_asset=true; o.asset=id_value(v,get(val,"asset"),ptr(p,"asset")) }
        s.objects[ID(k)] = o
    }
    p := get(x,"puzzle")
    keys(v,p,"/puzzle","kind|train|branch|winch|shed|handle|player_spawn|return_spawn|handle_recovery_spawn|winch_socket|winch_rope_anchor|branch_rope_anchor|branch_cleared_position","snail")
    s.puzzle.kind=choice(v,get(p,"kind"),"/puzzle/kind","install_crank_handle")
    s.puzzle.train=id_value(v,get(p,"train"),"/puzzle/train")
    s.puzzle.branch=id_value(v,get(p,"branch"),"/puzzle/branch")
    s.puzzle.winch=id_value(v,get(p,"winch"),"/puzzle/winch")
    s.puzzle.shed=id_value(v,get(p,"shed"),"/puzzle/shed")
    s.puzzle.handle=id_value(v,get(p,"handle"),"/puzzle/handle")
    if has(p,"snail") { s.puzzle.snail=id_value(v,get(p,"snail"),"/puzzle/snail") }
    s.puzzle.player_spawn=id_value(v,get(p,"player_spawn"),"/puzzle/player_spawn")
    s.puzzle.return_spawn=id_value(v,get(p,"return_spawn"),"/puzzle/return_spawn")
    s.puzzle.handle_recovery_spawn=id_value(v,get(p,"handle_recovery_spawn"),"/puzzle/handle_recovery_spawn")
    s.puzzle.winch_socket=vector(v,get(p,"winch_socket"),"/puzzle/winch_socket")
    s.puzzle.winch_rope_anchor=vector(v,get(p,"winch_rope_anchor"),"/puzzle/winch_rope_anchor")
    s.puzzle.branch_rope_anchor=vector(v,get(p,"branch_rope_anchor"),"/puzzle/branch_rope_anchor")
    s.puzzle.branch_cleared_position=vector(v,get(p,"branch_cleared_position"),"/puzzle/branch_cleared_position")
    return s
}
dialogue_decode :: proc(v: ^Validator, x: json.Value) -> Dialogue_Def {
    d: Dialogue_Def; d.id=envelope(v,x,"dialogue")
    keys(v,x,"","kind|schema_version|id|order|lines|completion","")
    d.lines=make(map[ID]Line_Def)
    for k,val in map_check(v,get(x,"lines"),"/lines") {
        p:=ptr("/lines",k); keys(v,val,p,"speaker|text","")
        d.lines[ID(k)]={id_value(v,get(val,"speaker"),ptr(p,"speaker")),str(v,get(val,"text"),ptr(p,"text"))}
    }
    a,ok:=get(x,"order").(json.Array)
    if !ok || len(a)==0 || len(a)>1024 { fail(v,"order","/order","Expected 1..1024 line IDs") }
    d.order=make([]ID,len(a))
    for val,i in a { d.order[i]=id_value(v,val,fmt.aprintf("/order/%d",i)) }
    c:=get(x,"completion"); keys(v,c,"/completion","action|destination","")
    d.action=str(v,get(c,"action"),"/completion/action")
    d.destination=str(v,get(c,"destination"),"/completion/destination")
    return d
}
assets_decode :: proc(v: ^Validator, x: json.Value) -> map[ID]Asset_Def {
    envelope(v,x,"assets"); keys(v,x,"","kind|schema_version|id|assets","")
    assets:=make(map[ID]Asset_Def)
    for k,val in map_check(v,get(x,"assets"),"/assets") {
        p:=ptr("/assets",k); keys(v,val,p,"path|sha256|frame_size|frame_count|pivot|provenance","")
        a:=Asset_Def{id=ID(k),path=str(v,get(val,"path"),ptr(p,"path"),240),sha256=str(v,get(val,"sha256"),ptr(p,"sha256"),64),frame_size=vector(v,get(val,"frame_size"),ptr(p,"frame_size"),true),frame_count=int_value(v,get(val,"frame_count"),ptr(p,"frame_count"),1,1024),pivot=vector(v,get(val,"pivot"),ptr(p,"pivot"))}
        if !valid_path(a.path,"assets/") { fail(v,"unsafe_path",ptr(p,"path"),"Asset must stay beneath assets/") }
        if !valid_hex(a.sha256) { fail(v,"asset_hash",ptr(p,"sha256"),"Expected 64 lowercase hex digits") }
        pr:=get(val,"provenance"); keys(v,pr,ptr(p,"provenance"),"creator|source|license|attribution","")
        a.provenance={str(v,get(pr,"creator"),ptr(p,"provenance/creator")),str(v,get(pr,"source"),ptr(p,"provenance/source")),str(v,get(pr,"license"),ptr(p,"provenance/license")),str(v,get(pr,"attribution"),ptr(p,"provenance/attribution"),4096,false)}
        assets[ID(k)]=a
    }
    return assets
}
valid_hex :: proc(s: string) -> bool {
    if len(s)!=64 { return false }
    for c in s { if !(c>='0' && c<='9' || c>='a' && c<='f') { return false } }
    return true
}
