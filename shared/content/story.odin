package content

import "core:encoding/json"
import "core:fmt"
import "core:strings"

STORY_ROLES :: "intro|travel|obstacle|return|arrival|end_card"
STRING_KEYS :: "needs_handle|branch|blocked|turning|clear|completion|snail|pickup|drop|install|activate|inspect_winch|inspect_branch|return_train|wave|find_hint_gentle|find_hint_shelter|find_hint|held_hint|dropped_hint|installed_hint|wait_hint|return_hint|supper_card|end_card|advance|skip_scene|return_menu"
SETS :: "willow_platform|carriage|forest_travel|forest_obstacle|market_platform|flower_window"
SHOTS :: "wide|passenger_pair|old_platform|winch_branch|flower|supper_card"
POSES :: "idle|walk|nod|point|reach|wave|carry|sit|look|board|fold|tap|dust_paws"
EMOTES :: "neutral|curious|smile|blink|ears_up"
CUES :: "none|whistle_low|door_squeak|wheels|brake_soft|paper_rustle|whistle_depart"
PROP_KINDS :: "train|door|bag|flowerpot|paper_flower|slat|bench|timetable|sign|notice|market_dressing"

// Shared by strict decoder and the schema conformance tests. Only these visual
// states exist; no prop is a second definition of a puzzle object.
prop_states :: proc(kind: Prop_Kind) -> string {
    switch kind {
    case .Train: return "waiting|moving|stopped"
    case .Door: return "open|closed"
    case .Bag: return "ear_caught|free|aboard"
    case .Flowerpot: return "bud|bloom"
    case .Paper_Flower: return "paper|folding|folded|spring"
    case .Slat: return "loose|slipping|caught|resting"
    case .Bench: return "unrepaired|supported"
    case .Timetable: return "unhelpful"
    case .Sign: return "faded"
    case .Notice: return "supper"
    case .Market_Dressing: return "open"
    }
    return ""
}
shot_options :: proc(set: Story_Set) -> string {
    switch set {
    case .Willow_Platform: return "wide|passenger_pair|old_platform"
    case .Carriage: return "wide|passenger_pair|flower|supper_card"
    case .Forest_Travel: return "wide"
    case .Forest_Obstacle: return "wide|passenger_pair|winch_branch"
    case .Market_Platform: return "wide|passenger_pair|flower|supper_card"
    case .Flower_Window: return "flower"
    }
    return ""
}
// A card is legible UI text, never arbitrary response text on a story card.
CARD_KEYS :: "supper_card|end_card"
choice_index :: proc(v: ^Validator,x: json.Value,p,options: string) -> int {
    s:=choice(v,x,p,options)
    for item,i in strings.split(options,"|") { if item==s { return i } }
    return 0
}
story_text :: proc(v: ^Validator,x: json.Value,p: string) -> string {
    s:=str(v,x,p)
    visible:=false
    for ch in s {
        if ch<32 && ch!='\n' && ch!='\t' || ch==127 { fail(v,"text",p,"Text contains an unsupported control character") }
        if ch!=' ' && ch!='\n' && ch!='\t' && ch!='\r' { visible=true }
    }
    if !visible { fail(v,"text",p,"Text must contain visible characters") }
    return s
}
stage_decode :: proc(v: ^Validator,x: json.Value,p: string) -> Story_Stage_Def {
    keys(v,x,p,"set|shot|actors|props|cue","")
    s:Story_Stage_Def
    s.set=Story_Set(choice_index(v,get(x,"set"),ptr(p,"set"),SETS))
    s.shot=Story_Shot(choice_index(v,get(x,"shot"),ptr(p,"shot"),SHOTS))
    if !member(text(get(x,"shot")),shot_options(s.set)) { fail(v,"shot",ptr(p,"shot"),"Shot is not compatible with this set") }
    s.cue=Story_Cue(choice_index(v,get(x,"cue"),ptr(p,"cue"),CUES))
    s.actors=make(map[ID]Actor_Def)
    for id,val in map_check(v,get(x,"actors"),ptr(p,"actors")) {
        q:=ptr(ptr(p,"actors"),id); keys(v,val,q,"feet|facing|pose|emote","asset")
        actor:=Actor_Def{feet=vector(v,get(val,"feet"),ptr(q,"feet")),facing=choice(v,get(val,"facing"),ptr(q,"facing"),"left|right"),
            pose=Story_Pose(choice_index(v,get(val,"pose"),ptr(q,"pose"),POSES)),emote=Story_Emote(choice_index(v,get(val,"emote"),ptr(q,"emote"),EMOTES))}
        if has(val,"asset") { actor.asset=id_value(v,get(val,"asset"),ptr(q,"asset")) }
        s.actors[ID(id)]=actor
    }
    s.props=make(map[ID]Prop_Def)
    for id,val in map_check(v,get(x,"props"),ptr(p,"props")) {
        q:=ptr(ptr(p,"props"),id); keys(v,val,q,"kind|position|state","asset")
        prop:=Prop_Def{kind=Prop_Kind(choice_index(v,get(val,"kind"),ptr(q,"kind"),PROP_KINDS)),position=vector(v,get(val,"position"),ptr(q,"position"))}
        prop.state=choice(v,get(val,"state"),ptr(q,"state"),prop_states(prop.kind))
        if has(val,"asset") { prop.asset=id_value(v,get(val,"asset"),ptr(q,"asset")) }
        s.props[ID(id)]=prop
    }
    return s
}
dialogue_decode :: proc(v: ^Validator,x: json.Value) -> Dialogue_Def {
    d:Dialogue_Def; d.id=envelope(v,x,"dialogue"); d.schema_version=int(integer(get(x,"schema_version")))
    required:="kind|schema_version|id|order|lines|completion"
    if d.schema_version==2 { required=strings.concatenate({required,"|beats|beat_order"}) }
    keys(v,x,"",required,"")
    d.lines=make(map[ID]Line_Def)
    for id,val in map_check(v,get(x,"lines"),"/lines") {
        p:=ptr("/lines",id); optional:=""; if d.schema_version==2 { optional="delivery" }
        keys(v,val,p,"speaker|text",optional)
        line:=Line_Def{speaker=id_value(v,get(val,"speaker"),ptr(p,"speaker")),text=story_text(v,get(val,"text"),ptr(p,"text"))}
        if has(val,"delivery") { line.delivery=Line_Delivery(choice_index(v,get(val,"delivery"),ptr(p,"delivery"),"onscreen|offscreen")) }
        d.lines[ID(id)]=line
    }
    d.order=id_order(v,get(x,"order"),"/order",d.schema_version==1)
    completion:=get(x,"completion"); keys(v,completion,"/completion","action|destination","")
    d.action=str(v,get(completion,"action"),"/completion/action")
    d.destination=str(v,get(completion,"destination"),"/completion/destination")
    if d.schema_version==1 { adapt_v1_dialogue(&d); return d }
    d.beat_order=id_order(v,get(x,"beat_order"),"/beat_order",true)
    d.beats=make(map[ID]Story_Beat_Def)
    for id,val in map_check(v,get(x,"beats"),"/beats") {
        p:=ptr("/beats",id)
        kind:=choice(v,get(val,"kind"),ptr(p,"kind"),"line|stage|card")
        required:="kind|stage"
        switch kind { case "line":required=strings.concatenate({required,"|line"}); case "stage":required=strings.concatenate({required,"|duration_ms"}); case "card":required=strings.concatenate({required,"|string"}) }
        keys(v,val,p,required,"")
        b:=Story_Beat_Def{stage=stage_decode(v,get(val,"stage"),ptr(p,"stage"))}
        switch kind {
        case "line": b.kind=.Line; b.line=id_value(v,get(val,"line"),ptr(p,"line"))
        case "stage": b.kind=.Stage; b.duration_ms=int_value(v,get(val,"duration_ms"),ptr(p,"duration_ms"),0,5000)
        case "card": b.kind=.Card; b.string_key=choice(v,get(val,"string"),ptr(p,"string"),CARD_KEYS)
        }
        d.beats[ID(id)]=b
    }
    return d
}
id_order :: proc(v: ^Validator,x: json.Value,p: string,nonempty: bool) -> []ID {
    a,ok:=x.(json.Array)
    if !ok || nonempty && len(a)==0 || len(a)>1024 { fail(v,"order",p,"Expected bounded array of IDs") }
    result:=make([]ID,len(a))
    for val,i in a { result[i]=id_value(v,val,fmt.aprintf("%s/%d",p,i)) }
    return result
}
completion_pair :: proc(role: string) -> (string,string) {
    switch role {
    case "intro":return "board_oliver","train_travel"
    case "travel":return "enter_obstacle","obstacle_arrival"
    case "obstacle":return "begin_puzzle","puzzle"
    case "return":return "enter_arrival","station_outro"
    case "arrival":return "finish_oliver_journey","chapter_complete"
    case "end_card":return "show_title","title"
    }
    return "",""
}
story_validate :: proc(v: ^Validator,s: ^Snapshot,d: Dialogue_Def,role: string,beat_ids: ^map[ID]bool,object_ids,spawn_ids: map[ID]bool) {
    seen:=make(map[ID]bool); projection:=make([dynamic]ID)
    for id in d.beat_order {
        if seen[id] { fail(v,"beat_order","/beat_order","Repeated beat ID") }; seen[id]=true
        b,ok:=d.beats[id]
        if !ok { fail(v,"beat_order","/beat_order","Ordered beat is missing"); continue }
        if b.kind==.Line { append(&projection,b.line) }
    }
    if len(seen)!=len(d.beats) { fail(v,"beat_order","/beat_order","Every beat must appear exactly once") }
    for id,b in d.beats {
        p:=ptr("/beats",string(id))
        if !seen[id] { fail(v,"beat_order",p,"Unordered beat") }
        if beat_ids^[id] { fail(v,"duplicate_identity",p,"Beat ID duplicated chapter-wide") }; beat_ids^[id]=true
        if b.kind==.Line { if _,ok:=d.lines[b.line]; !ok { fail(v,"line",ptr(p,"line"),"Beat line does not exist") } }
        if b.kind==.Card { if _,ok:=s.chapter.strings[b.string_key]; !ok { fail(v,"string",ptr(p,"string"),"Card string is missing") } }
        for actor,a in b.stage.actors {
            q:=ptr(ptr(ptr(p,"stage"),"actors"),string(actor))
            if _,ok:=s.chapter.speakers[actor]; !ok { fail(v,"speaker",q,"Stage actor must resolve to a speaker") }
            if object_ids[actor] || spawn_ids[actor] { fail(v,"stage_identity",q,"Stage actors cannot share puzzle object/spawn identities") }
            if a.asset!="" { if _,ok:=s.assets[a.asset]; !ok { fail(v,"missing_asset",ptr(q,"asset"),"Stage actor asset ID not found") } }
        }
        for prop,a in b.stage.props {
            q:=ptr(ptr(ptr(p,"stage"),"props"),string(prop))
            _,actor:=s.chapter.speakers[prop]
            if object_ids[prop] || spawn_ids[prop] || actor { fail(v,"stage_identity",q,"Visual prop identities must be separate from actors and puzzle identities") }
            if a.asset!="" { if _,ok:=s.assets[a.asset]; !ok { fail(v,"missing_asset",ptr(q,"asset"),"Stage prop asset ID not found") } }
        }
    }
    if len(projection)!=len(d.order) { fail(v,"line_beats","/beat_order","Line-beat projection must equal line order")
    } else { for id,i in d.order { if projection[i]!=id { fail(v,"line_beats","/beat_order","Line-beat projection must equal line order"); break } } }
    if len(d.lines)==0 && role!="return" && role!="end_card" { fail(v,"lines","/lines","Only return and end_card roles may have no lines") }
}
