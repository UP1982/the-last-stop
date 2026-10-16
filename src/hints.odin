package main

import rl "vendor:raylib"

// Runtime strings are owned by Runtime_Content, cloned once from the validated
// chapter dictionary. Synthetic M1 fixtures have no chapter and return empty UI.
chapter_text :: proc(g: Game_State, key: string) -> cstring {
    if g.content==nil { return "" }
    return g.content.text[key]
}
phase_response :: proc(g: Game_State) -> cstring {
    if g.puzzle.phase==.Cranking { return chapter_text(g,"turning") }
    if g.puzzle.phase==.Cleared { return chapter_text(g,"clear") }
    return chapter_text(g,"needs_handle")
}
puzzle_hint :: proc(g: Game_State) -> cstring {
    p:=g.puzzle
    if p.phase==.Cleared { return chapter_text(g,"return_hint") }
    if p.phase==.Cranking { return chapter_text(g,"wait_hint") }
    switch p.handle {
    case .Shelf:
        if g.hint_tier==0 { return chapter_text(g,"find_hint_gentle") }
        if g.hint_tier==1 { return chapter_text(g,"find_hint_shelter") }
        return chapter_text(g,"find_hint")
    case .Held: return chapter_text(g,"held_hint")
    case .Dropped: return chapter_text(g,"dropped_hint")
    case .Installed: return chapter_text(g,"installed_hint")
    }
    return ""
}
request_hint :: proc(g: ^Game_State) {
    respond(g,puzzle_hint(g^))
    if g.puzzle.handle==.Shelf && g.puzzle.phase==.Blocked { g.hint_tier=min(2,g.hint_tier+1) }
}

// Conservative fixed columns keep even the default font's widest glyph inside
// 600 pixels at size 20. UTF-8 codepoints are never split. A fresh T press pages
// long edited responses/labels; this is UI text, not story playback.
content_line_ends :: proc(s: string) -> (ends: [4097]int, count: int) {
    start, columns, space := 0, 0, -1
    i:=0
    for i<len(s) {
        if s[i]=='\n' { ends[count]=i+1; count+=1; start=i+1; columns=0; space=-1; i+=1; continue }
        if s[i]==' ' || s[i]=='\t' { space=i }
        if s[i]&0xc0!=0x80 { columns+=1 }
        if columns>30 {
            end:=i
            if space>=start { end=space+1 }
            ends[count]=end; count+=1; start=end; i=end; columns=0; space=-1; continue
        }
        i+=1
    }
    if start<len(s) || count==0 { ends[count]=len(s); count+=1 }
    return
}
draw_content_text :: proc(message: cstring, y, size: i32, color: rl.Color, page: int=0, max_lines: int=3) {
    if message==nil { return }
    s:=string(message)
    ends,count:=content_line_ends(s)
    pages:=(count+max_lines-1)/max_lines
    first:=(page%pages)*max_lines
    for row:=0;row<max_lines && first+row<count;row+=1 {
        index:=first+row; start:=0
        if index>0 { start=ends[index-1] }
        end:=ends[index]
        for end>start && (s[end-1]=='\n' || s[end-1]==' ' || s[end-1]=='\t') { end-=1 }
        buffer:[4097]u8
        copy(buffer[:],transmute([]u8)s[start:end])
        center_text(cstring(raw_data(buffer[:])),y+i32(row)*(size+2),size,color)
    }
}
