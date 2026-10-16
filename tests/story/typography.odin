package main

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"

footer_tests :: proc(font:rl.Font,canvas:rl.RenderTexture2D) {
    exact:="Continue through this quiet station scene whenever you are ready."
    // This independently reproduces Astra's old single-line overflow.
    old_width:=rl.MeasureText(fmt.ctprintf("E/Enter: %s   X: Skip scene   Esc: pause",exact),16)
    assert(24+old_width>640)
    cases:=[?][2]string{
        {exact,"Skip scene"},
        {strings.repeat("W",14),strings.repeat("W",10)},
        {strings.repeat("Æ",14),strings.repeat("Æ",10)},
        {"Return to menu","Skip scene"},
        {strings.repeat("猫",4096),strings.repeat("é",4096)},
        {"continue\nelsewhere","skip\telsewhere"},
    }
    for labels,index in cases {
        controls:=story_footer_layout(labels[0],labels[1])
        assert(strings.has_prefix(controls[0].text,"E/Enter: "))
        assert(strings.has_prefix(controls[1].text,"X: "))
        assert(controls[2].text=="Esc: pause")
        if index==0 {
            assert(strings.has_suffix(controls[0].text,"..."))
            assert(controls[1].text=="X: Skip scene")
        }
        if index==1 || index==2 || index==3 {
            assert(controls[0].text==fmt.tprintf("E/Enter: %s",labels[0]))
            assert(controls[1].text==fmt.tprintf("X: %s",labels[1]))
        }
        rl.BeginTextureMode(canvas)
        draw_story_footer(labels[0],labels[1],rl.WHITE)
        for control,i in controls {
            text:=fmt.ctprintf("%s",control.text)
            measured:=rl.MeasureText(text,STORY_FOOTER_SIZE)
            // DrawText uses this same bundled font and integer spacing 16/10.
            actual:=rl.MeasureTextEx(font,text,STORY_FOOTER_SIZE,1)
            assert(i32(actual.x)==measured && measured<=control.width)
            assert(control.x>=24 && control.x+measured<=616)
            assert(STORY_FOOTER_Y+STORY_FOOTER_SIZE<=356)
            if i<2 { assert(control.x+control.width<controls[i+1].x) }
            for ch in control.text { assert(ch>=32 && ch!=127) }
            fmt.printf("footer case=%d control=%d x=%d width=%d reserved=%d text=%s\n",index,i,control.x,measured,control.width,control.text)
        }
        rl.EndTextureMode()
    }
    // Every glyph in the actual font fits at each maximum, without truncating
    // valid UI labels. Out-of-font codepoints use its narrower fallback glyph.
    for ch:=rune(32);ch<256;ch+=1 {
        if ch==127 { continue }
        character:=fmt.tprintf("%c",ch)
        labels:=story_footer_layout(strings.repeat(character,14),strings.repeat(character,10))
        assert(labels[0].text==fmt.tprintf("E/Enter: %s",strings.repeat(character,14)))
        assert(labels[1].text==fmt.tprintf("X: %s",strings.repeat(character,10)))
        assert(rl.MeasureText(fmt.ctprintf("%s",strings.repeat(character,26)),16)<600)
        speaker:=fmt.tprintf("%s (off screen)",strings.repeat(character,20))
        assert(rl.MeasureText(fmt.ctprintf("%s",speaker),18)<520)
    }
    fmt.printf("PASS footer: Astra exact old width %d; fixed regions, max-budget labels, overflow ellipsis, UTF-8 and every live font glyph\n",old_width)
}

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
    footer_tests(font,canvas)
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
