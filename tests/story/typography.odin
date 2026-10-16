package main

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"

// Independent reference: query the actual bundled font, rather than the
// renderer's headless table. This catches a raylib font/metric upgrade.
font_width :: proc(s:string,font:rl.Font) -> i32 {
    width:=i32(0)
    for ch in s {
        switch ch {
        case '\n','\r': continue
        case '…': width+=14
        case '—': width+=16
        case '\t': width+=6
        case:
            index:=rl.GetGlyphIndex(font,ch)
            glyph:=font.glyphs[index]
            advance:=glyph.advanceX
            if advance==0 { advance=i32(font.recs[index].width) }
            width+=advance*2
        }
        width+=2
    }
    return max(0,width-2)
}
main :: proc() {
    rl.SetConfigFlags({.WINDOW_HIDDEN})
    rl.InitWindow(640,360,"The Last Stop typography test")
    defer rl.CloseWindow()
    font:=rl.GetFontDefault()
    assert(font.baseSize==10)
    for ch:=rune(32);ch<256;ch+=1 {
        index:=rl.GetGlyphIndex(font,ch)
        assert(story_glyph_width(ch)==i32(font.recs[index].width)*2)
    }
    canvas:=rl.LoadRenderTexture(640,360)
    defer rl.UnloadRenderTexture(canvas)
    texts:=[]string{
        "First day on this line?",
        "The Last Stop. We used to have supper there when the lamps came on.",
        fmt.tprintf("%s next",strings.repeat("W",36)),
        "They've been on the kitchen table all week. I thought they might enjoy meeting other flowers.",
        "WILLOW CREEK PLATFORM SUPPER — ALL WELCOME",
        "A little further down the line…",
        strings.repeat("A quiet journey… — café 猫 ",100),
        strings.repeat("W",4096),
        strings.repeat("i ",2048),
        "line one\nline two\n\nlast\r\nline\tend",
    }
    pages,lines:=0,0
    for text in texts {
        ends,count:=story_line_ends(text)
        start:=0
        for page in 0..<story_page_count(text) {
            rl.BeginTextureMode(canvas)
            for row in 0..<STORY_ROWS {
                index:=page*STORY_ROWS+row
                if index>=count { break }
                end:=ends[index]
                assert(end>=start && end<=len(text))
                if end<len(text) { assert(text[end]&0xc0!=0x80) }
                line:=story_line(text,ends[:count],index)
                y:=264+i32(row)*STORY_LINE_HEIGHT
                measured:=story_text_width(line)
                drawn:=draw_story_glyphs(line,32,y,rl.WHITE)
                assert(measured==drawn && drawn==font_width(line,font))
                assert(32+drawn<=608 && y+STORY_FONT_SIZE<=336)
                // The supplementary supper panel uses the same page layout.
                assert(158+i32(row)*STORY_LINE_HEIGHT+STORY_FONT_SIZE<=230)
                start=end; lines+=1
            }
            rl.EndTextureMode()
            pages+=1
        }
        assert(start==len(text))
    }
    fmt.printf("PASS typography: live font metrics, measured == drawn width; %d lines / %d pages inside body box; UTF-8, ellipsis and em dash\n",lines,pages)
}
