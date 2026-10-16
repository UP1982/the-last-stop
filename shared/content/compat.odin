#+feature dynamic-literals
package content

import "core:fmt"

// Only v1 chapters use these compatibility values. V2 requires the complete
// authored dictionary and never falls back to compiled player-facing prose.
default_chapter_strings :: proc() -> map[string]string {
    return map[string]string{
        "needs_handle"="It needs a handle.",
        "branch"="The rope leads to the winch.",
        "blocked"="The track is still blocked.",
        "turning"="It's turning.",
        "clear"="The track is clear.",
        "completion"="The branch is safely clear.",
        "snail"="The snail raises its feelers.",
        "pickup"="Pick up handle",
        "drop"="Put down handle",
        "install"="Install handle",
        "activate"="Start crank",
        "inspect_winch"="Inspect empty winch",
        "inspect_branch"="Inspect branch and rope",
        "return_train"="Return to train",
        "wave"="Wave to snail",
        "find_hint_gentle"="The rope leads from the branch to the winch.",
        "find_hint_shelter"="There may be something useful in the open tool shelter.",
        "find_hint"="Pick up the handle in the shelter and fit it into the winch.",
        "held_hint"="Carry the handle to the winch. Away from an object, you can put it down.",
        "dropped_hint"="Pick up the handle and carry it to the winch.",
        "installed_hint"="The handle is fitted. Press Interact once to start the winch.",
        "wait_hint"="The winch is working. Take your time.",
        "return_hint"="The track is clear. Return to Brass when you're ready.",
        "supper_card"="WILLOW CREEK PLATFORM SUPPER — ALL WELCOME",
        "end_card"="A little further down the line…",
        "advance"="Continue",
        "skip_scene"="Skip scene",
        "return_menu"="Return to menu",
    }
}
adapt_v1_dialogue :: proc(d: ^Dialogue_Def) {
    d.beats=make(map[ID]Story_Beat_Def); d.beat_order=make([]ID,len(d.order))
    set:=Story_Set.Willow_Platform
    if d.action=="finish_oliver_journey" { set=.Market_Platform }
    for line,i in d.order {
        id:=ID(fmt.aprintf("legacy_%s_%d",d.id,i))
        d.beat_order[i]=id
        actors:=make(map[ID]Actor_Def)
        actors["milo"]={feet={216,264},facing="right",pose=.Look}
        speaker:=d.lines[line].speaker
        if speaker!="milo" { actors[speaker]={feet={396,264},facing="left",pose=.Idle} }
        d.beats[id]={kind=.Line,line=line,stage={set=set,shot=.Passenger_Pair,
            actors=actors,props=make(map[ID]Prop_Def)}}
    }
}
