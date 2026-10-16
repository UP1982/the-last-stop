package main

import rl "vendor:raylib"

STORY_ROWS :: 3
STORY_FONT_SIZE :: 20 // 2x the bundled 10px bitmap: integral glyph pixels.
STORY_SPACING :: 2   // Same proportional spacing as raylib DrawText at 20px.
STORY_LINE_HEIGHT :: 22
STORY_TEXT_WIDTH :: 576 // x32..608, inside both story panels.
// raylib 6.0 rtext.c LoadFontDefault's bitmap widths (codepoints 32..255).
// Kept available without a graphics context for playback/pagination tests.
// tests/story/typography.py checks every entry against the live bundled font.
STORY_GLYPH_WIDTHS := [?]i32{ 3, 1, 4, 6, 5, 7, 6, 2, 3, 3, 5, 5, 2, 4, 1, 7, 5, 2, 5, 5, 5, 5, 5, 5, 5, 5, 1, 1, 3, 4, 3, 6,
                            7, 6, 6, 6, 6, 6, 6, 6, 6, 3, 5, 6, 5, 7, 6, 6, 6, 6, 6, 6, 7, 6, 7, 7, 6, 6, 6, 2, 7, 2, 3, 5,
                            2, 5, 5, 5, 5, 5, 4, 5, 5, 1, 2, 5, 2, 5, 5, 5, 5, 5, 5, 5, 4, 5, 5, 5, 5, 5, 5, 3, 1, 3, 4, 4,
                            1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
                            1, 1, 5, 5, 5, 7, 1, 5, 3, 7, 3, 5, 4, 1, 7, 4, 3, 5, 3, 3, 2, 5, 6, 1, 2, 2, 3, 5, 6, 6, 6, 6,
                            6, 6, 6, 6, 6, 6, 7, 6, 6, 6, 6, 6, 3, 3, 3, 3, 7, 6, 6, 6, 6, 6, 6, 5, 6, 6, 6, 6, 6, 6, 4, 6,
                            5, 5, 5, 5, 5, 5, 9, 5, 5, 5, 5, 5, 2, 2, 3, 3, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 3, 5 }

story_glyph_width :: proc(ch:rune) -> i32 {
    switch ch {
    case '…': return 14
    case '—': return 16
    case '\n','\r': return 0
    case '\t': return 6
    }
    index:=int(ch)-32
    if index<0 || index>=len(STORY_GLYPH_WIDTHS) { index=int('?')-32 }
    return STORY_GLYPH_WIDTHS[index]*2
}
story_text_width :: proc(s:string) -> i32 {
    width:=i32(0)
    for ch in s {
        if ch=='\n' || ch=='\r' { continue }
        width+=story_glyph_width(ch)+STORY_SPACING
    }
    return max(0,width-STORY_SPACING)
}
story_line_ends :: proc(s: string) -> (ends: [4097]int, count: int) {
    start,space:=0,-1
    width:=i32(0)
    seen:=false // a visible glyph precedes the candidate space on this row
    // Range supplies UTF-8 byte offsets; a long word can only break at a rune.
    for ch,i in s {
        if ch=='\n' {
            ends[count]=i+1; count+=1; start=i+1; width=0; space=-1; seen=false; continue
        }
        if ch=='\r' { continue }
        if ch==' ' || ch=='\t' { if seen { space=i } } else { seen=true }
        next:=width+story_glyph_width(ch)+STORY_SPACING
        if next-STORY_SPACING>STORY_TEXT_WIDTH {
            end:=i
            // Break after a space only if visible text precedes it on this
            // row (space is only recorded then); else hard-break before ch.
            if space>=start { end=space+1 }
            ends[count]=end; count+=1; start=end; space=-1; seen=false
            // Include the partial word after the chosen space, including ch.
            width=0
            if end<=i {
                for tail in s[start:i] {
                    width+=story_glyph_width(tail)+STORY_SPACING
                    if tail!=' ' && tail!='\t' { seen=true }
                }
                width+=story_glyph_width(ch)+STORY_SPACING
                if ch!=' ' && ch!='\t' { seen=true }
                // The carried word may itself be too wide: hard-break before ch.
                if width-STORY_SPACING>STORY_TEXT_WIDTH && i>start {
                    ends[count]=i; count+=1; start=i
                    width=story_glyph_width(ch)+STORY_SPACING
                    seen=ch!=' ' && ch!='\t'
                }
            }
        } else { width=next }
    }
    if start<len(s) || count==0 { ends[count]=len(s); count+=1 }
    return
}
story_page_count :: proc(s: string) -> int {
    _,count:=story_line_ends(s)
    return (count+STORY_ROWS-1)/STORY_ROWS
}
// The bundled font lacks these two glyphs; retain authored Unicode and draw
// integer pixel strokes. All other glyphs use that font's proportional width.
// Return the drawn extent so native tests can compare drawing with wrapping.
draw_story_glyphs :: proc(s: string, x,y:i32, color:rl.Color) -> i32 {
    px:=x
    for ch in s {
        switch ch {
        case '…':
            for dot in 0..<3 { rl.DrawRectangle(px+i32(dot)*6,y+14,2,2,color) }
        case '—': rl.DrawRectangle(px,y+8,16,2,color)
        case '\n','\r': continue
        case '\t':
        case: rl.DrawTextCodepoint(rl.GetFontDefault(),ch,{f32(px),f32(y)},STORY_FONT_SIZE,color)
        }
        px+=story_glyph_width(ch)+STORY_SPACING
    }
    return max(0,px-x-STORY_SPACING)
}
story_line :: proc(s:string,ends:[]int,index:int) -> string {
    start:=0
    if index>0 { start=ends[index-1] }
    end:=ends[index]
    for end>start && (s[end-1]=='\n' || s[end-1]=='\r' || s[end-1]==' ' || s[end-1]=='\t') { end-=1 }
    return s[start:end]
}
draw_story_page :: proc(s:string,page:int,y:i32,color:rl.Color) {
    ends,count:=story_line_ends(s)
    first:=page*STORY_ROWS
    for row:=0;row<STORY_ROWS && first+row<count;row+=1 {
        draw_story_glyphs(story_line(s,ends[:count],first+row),32,y+i32(row)*STORY_LINE_HEIGHT,color)
    }
}
