package main

import "core:fmt"
import rl "vendor:raylib"

STORY_FOOTER_SIZE :: 16
STORY_FOOTER_Y :: 336
Story_UI_Control :: struct { text:string, x,width:i32 }

// Use the actual drawing font/size, and only cut at UTF-8 rune boundaries.
// Content validation keeps normal labels short; this also contains stale or
// otherwise unvalidated text without letting one control displace another.
story_ui_fit :: proc(s:string,width,size:i32) -> string {
    end:=len(s)
    for ch,i in s { if ch<32 || ch==127 { end=i; break } }
    if end==len(s) && rl.MeasureText(fmt.ctprintf("%s",s),size)<=width { return s }
    suffix:="..."
    if rl.MeasureText("...",size)>width { return "" }
    cut:=0
    for _,i in s[:end] {
        if rl.MeasureText(fmt.ctprintf("%s%s",s[:i],suffix),size)>width { break }
        cut=i
    }
    if rl.MeasureText(fmt.ctprintf("%s%s",s[:end],suffix),size)<=width { cut=end }
    return fmt.tprintf("%s%s",s[:cut],suffix)
}

story_footer_layout :: proc(action,skip:string) -> [3]Story_UI_Control {
    controls:=[3]Story_UI_Control{
        {fmt.tprintf("E/Enter: %s",action),24,292},
        {fmt.tprintf("X: %s",skip),328,184},
        {"Esc: pause",524,92},
    }
    for &control in controls { control.text=story_ui_fit(control.text,control.width,STORY_FOOTER_SIZE) }
    return controls
}
draw_story_footer :: proc(action,skip:string,color:rl.Color) {
    for control in story_footer_layout(action,skip) {
        rl.DrawText(fmt.ctprintf("%s",control.text),control.x,STORY_FOOTER_Y,STORY_FOOTER_SIZE,color)
    }
}
