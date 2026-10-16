package main

import rl "vendor:raylib"

// A conservative fixed-cell layout is independent of GPU/font initialization,
// so tests use exactly the renderer's pagination. Content is never rewritten.
STORY_COLUMNS :: 36
STORY_ROWS :: 3
STORY_CELL :: 16
story_line_ends :: proc(s: string) -> (ends: [4097]int, count: int) {
    start,columns,space:=0,0,-1
    i:=0
    for i<len(s) {
        if s[i]=='\n' { ends[count]=i+1; count+=1; start=i+1; columns=0; space=-1; i+=1; continue }
        if s[i]==' ' || s[i]=='\t' { space=i }
        if s[i]&0xc0!=0x80 { columns+=1 }
        if columns>STORY_COLUMNS {
            end:=i; if space>=start { end=space+1 }
            ends[count]=end; count+=1; start=end; i=end; columns=0; space=-1; continue
        }
        i+=1
    }
    if start<len(s) || count==0 { ends[count]=len(s); count+=1 }
    return
}
story_page_count :: proc(s: string) -> int {
    _,count:=story_line_ends(s)
    return (count+STORY_ROWS-1)/STORY_ROWS
}
// raylib's bundled default font does not include U+2026/U+2014. Draw those
// two glyphs as pixel strokes in the SAME cell/scale as the bundled font.
// No OS font lookup, new font asset, ASCII substitution or stored-string edit.
draw_story_glyphs :: proc(s: string, x,y:i32, color:rl.Color) {
    col:=i32(0)
    for ch in s {
        px:=x+col*STORY_CELL
        switch ch {
        case '…':
            for dot in 0..<3 { rl.DrawRectangle(px+i32(dot)*5,y+12,2,2,color) }
        case '—': rl.DrawRectangle(px,y+7,15,2,color)
        case '\n','\r':
        case '\t':
        case: rl.DrawTextCodepoint(rl.GetFontDefault(),ch,{f32(px),f32(y)},16,color)
        }
        col+=1
    }
}
draw_story_page :: proc(s:string,page:int,y:i32,color:rl.Color) {
    ends,count:=story_line_ends(s)
    first:=page*STORY_ROWS
    for row:=0;row<STORY_ROWS && first+row<count;row+=1 {
        index:=first+row; start:=0
        if index>0 { start=ends[index-1] }
        end:=ends[index]
        for end>start && (s[end-1]=='\n' || s[end-1]==' ' || s[end-1]=='\t') { end-=1 }
        draw_story_glyphs(s[start:end],32,y+i32(row)*20,color)
    }
}
