package editor_tests

import c "../../shared/content"
import edit "../../shared/content_edit"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"

main :: proc() {
    root:="."; if len(os.args)>1 { root=os.args[1] }
    tracker:mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracker,context.allocator)
    defer mem.tracking_allocator_destroy(&tracker)
    a:=mem.tracking_allocator(&tracker)
    for i in 0..<100 {
        r:=c.load_chapter(root,c.CHAPTER_PATH,a)
        assert(r.snapshot!=nil,"valid graph must load")
        scene,ok:=c.find_scene(r.snapshot,"oliver_obstacle")
        assert(ok && scene.objects[c.ID("crank_handle")].kind==.Handle)
        _,missing:=c.find_scene(r.snapshot,"absent_scene"); assert(!missing)
        // Transfer snapshot; clearing/destroying the result must not free it.
        s:=r.snapshot; r.snapshot=nil; c.destroy_load_result(&r)
        assert(s.chapter.id=="oliver_flower_market")
        c.destroy_snapshot(s)
        assert(len(tracker.allocation_map)==0,"load/unload leaked allocations")
        bad:=transmute([]u8)string(`{"kind":"chapter","kind":"chapter"}`)
        src:=[]c.Document_Source{{path=c.CHAPTER_PATH,bytes=bad}}
        failed:=c.validate_sources(src,c.CHAPTER_PATH,a)
        assert(failed.snapshot==nil && len(failed.diagnostics)>0)
        c.destroy_load_result(&failed); c.destroy_load_result(&failed)
        assert(len(tracker.allocation_map)==0,"failure/destruction leaked allocations")
        parsed:=edit.request_parse(transmute([]u8)string(`{"protocol_version":1}`),a)
        assert(len(parsed.diagnostics)>0)
        edit.destroy_request_result(&parsed)
        assert(len(tracker.allocation_map)==0,"request parse leaked allocations")
    }
    // Deterministic serializer and strict adapter agree for escaped Unicode.
    o:=c.new_owner(a); context.allocator=c.owner_allocator(o)
    v,d,ok:=c.parse_strict(transmute([]u8)string(`{"x":"é 猫 \ud83d\ude80\n\t\u0001"}`),"test")
    assert(ok,d.message)
    first:=c.serialize(v); second:=c.serialize(v)
    assert(string(first)==string(second))
    _,_,valid:=c.parse_strict(first,"test"); assert(valid)
    c.destroy_owner(o)
    assert(len(tracker.allocation_map)==0)
    fmt.println("PASS allocation: 100 successful loads, ownership transfers, failed loads and request teardown; deterministic Unicode serialization")
}
