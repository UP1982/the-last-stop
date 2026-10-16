package main

// TODO(B2): user supplies story later. E0 dialogue schema has only ordered story
// lines + one sequence action, no response/hint lookup. Propose a versioned
// response dictionary in handoff; do not change shared/content schemas here.
M2_Strings :: struct {
    needs_handle: cstring,
    branch: cstring,
    blocked: cstring,
    turning: cstring,
    clear: cstring,
    completion: cstring,
    snail: cstring,
    pickup: cstring,
    install: cstring,
    activate: cstring,
    inspect_winch: cstring,
    inspect_branch: cstring,
    return_train: cstring,
    wave: cstring,
    find_hint: cstring,
    held_hint: cstring,
    dropped_hint: cstring,
    installed_hint: cstring,
    wait_hint: cstring,
    return_hint: cstring,
}
M2_TEXT :: M2_Strings{
    needs_handle="It needs a handle.",
    branch="The rope leads to the winch.",
    blocked="The track is still blocked.",
    turning="It's turning.",
    clear="The track is clear.",
    completion="Track clear! Brass gives a happy toot.",
    snail="The little snail waves back.",
    pickup="Pick up handle",
    install="Install handle",
    activate="Start crank",
    inspect_winch="Inspect empty winch",
    inspect_branch="Inspect branch / rope",
    return_train="Return to train",
    wave="Wave to snail",
    find_hint="Find the handle in the shed to the right.",
    held_hint="Carry it to the winch. E away: drop.",
    dropped_hint="Pick up the handle, then find the winch.",
    installed_hint="Handle installed. Press E to start.",
    wait_hint="The winch is working. Take your time.",
    return_hint="[R] Return to train, or walk to Brass.",
}
phase_response :: proc(p: Puzzle_State) -> cstring {
    if p.phase==.Cranking { return M2_TEXT.turning }
    if p.phase==.Cleared { return M2_TEXT.clear }
    return M2_TEXT.needs_handle
}
puzzle_hint :: proc(p: Puzzle_State) -> cstring {
    if p.phase==.Cleared { return M2_TEXT.return_hint }
    if p.phase==.Cranking { return M2_TEXT.wait_hint }
    switch p.handle {
    case .Shelf: return M2_TEXT.find_hint
    case .Held: return M2_TEXT.held_hint
    case .Dropped: return M2_TEXT.dropped_hint
    case .Installed: return M2_TEXT.installed_hint
    }
    return nil
}
