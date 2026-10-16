#+feature dynamic-literals
package main

import c "../../shared/content"
import edit "../../shared/content_edit"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/posix"
import "core:c/libc"

output :: proc(v:json.Value) { fmt.print(string(c.serialize(v))) }
diags :: proc(ds:[]c.Diagnostic) -> json.Value {
    a:=make(json.Array,0,len(ds))
    for d in ds {
        append(&a,json.Object{"severity"="error" if d.severity==.Error else "warning","code"=d.code,"file"=d.file,"pointer"=d.pointer,"subject_id"=d.subject_id,"message"=d.message,"line"=i64(d.line),"column"=i64(d.column),"op_index"=i64(d.op_index)})
    }
    return a
}
error_response :: proc(code,message:string,exit_code:int) -> int {
    ds:=[]c.Diagnostic{c.diagnostic(code,"","",message)}
    output(json.Object{"protocol_version"=i64(1),"commit_state"="not_committed","diagnostics"=diags(ds)})
    return exit_code
}
run :: proc() -> int {
    if len(os.args)<2 { return error_response("arguments","Use validate-content, inspect-scene, inspect-document or apply-edit with --project-root",2) }
    command:=os.args[1]
    if !c.member(command,"validate-content|inspect-scene|inspect-document|apply-edit") { return error_response("arguments","Unknown command",2) }
    root,scene,document,request_path:string
    seen:=make(map[string]bool)
    for i:=2;i<len(os.args);i+=2 {
        if i+1>=len(os.args) || seen[os.args[i]] { return error_response("arguments","Missing option value or repeated option",2) }
        seen[os.args[i]]=true
        switch os.args[i] {
        case "--project-root":root=os.args[i+1]
        case "--scene":scene=os.args[i+1]
        case "--document":document=os.args[i+1]
        case "--request":request_path=os.args[i+1]
        case:return error_response("arguments","Unknown option",2)
        }
    }
    if command=="inspect-document" && document=="" || command!="inspect-document" && document!="" || root=="" || command=="inspect-scene" && scene=="" || command=="apply-edit" && request_path=="" || command!="inspect-scene" && scene!="" || command!="apply-edit" && request_path!="" { return error_response("arguments","Invalid command options",2) }
    canonical:=posix.realpath(strings.clone_to_cstring(root))
    if canonical==nil { return error_response("io_root","Project root does not exist",4) }
    root=strings.clone_from_cstring(canonical); libc.free(rawptr(canonical))
    if command=="apply-edit" {
        bytes,ok:=c.read_bounded(request_path,c.MAX_DOCUMENT_BYTES)
        if !ok { return error_response("request_read","Cannot read request (limit 256 KiB)",2) }
        parsed:=edit.request_parse(bytes,context.allocator); defer edit.destroy_request_result(&parsed)
        if len(parsed.diagnostics)>0 {
            output(json.Object{"protocol_version"=i64(1),"commit_state"="not_committed","diagnostics"=diags(parsed.diagnostics)})
            return 2
        }
        result:=edit.apply_edit(root,parsed.request,context.allocator); defer edit.destroy_edit_result(&result)
        output(json.Object{"protocol_version"=i64(1),"request_id"=parsed.request.request_id,"commit_state"=edit.state_string(result.state),"old_revision"=c.revision_string(result.old_revision),"new_revision"=c.revision_string(result.new_revision),"changed_document"=result.changed_document,"undo_token"=result.undo_token,"diagnostics"=diags(result.diagnostics)})
        return result.exit_code
    }
    loaded:=c.load_chapter(root,c.CHAPTER_PATH,context.allocator); defer c.destroy_load_result(&loaded)
    if loaded.snapshot==nil {
        output(json.Object{"protocol_version"=i64(1),"commit_state"="not_committed","diagnostics"=diags(loaded.diagnostics)})
        for d in loaded.diagnostics { if d.code=="io_read" { return 4 }; if d.code=="external_change" { return 3 } }
        return 2
    }
    s:=loaded.snapshot
    revisions:=make(json.Object)
    for src in s.sources { revisions[src.path]=c.revision_string(src.revision) }
    response:=json.Object{"protocol_version"=i64(1),"commit_state"="not_committed","chapter"=string(s.chapter.id),"graph_revision"=c.revision_string(s.revision),"document_revisions"=revisions,"diagnostics"=diags(nil)}
    if command=="inspect-scene" {
        found:=false
        for d in s.documents { if string(d.id)==scene && d.kind=="scene" {
            found=true; response["document"]=string(d.id); response["document_path"]=d.source.path
            response["authored"]=d.value; response["resolved_links"]=c.get(d.value,"puzzle")
            response["editable_fields"]=json.Object{
                "objects"=json.Array{"position","size","layer","collision","interaction","asset"},
                "spawns"=json.Array{"position"},
                "puzzle_roles"=json.Array{"train","branch","winch","shed","handle","snail","player_spawn","return_spawn","handle_recovery_spawn"},
            }
        } }
        if !found { return error_response("scene","Scene not found",2) }
    }
    if command=="inspect-document" {
        found:=false
        for d in s.documents { if string(d.id)==document {
            found=true; response["document"]=string(d.id); response["document_path"]=d.source.path
            response["authored"]=d.value
        } }
        if !found { return error_response("document","Document not found",2) }
    }
    output(response)
    return 0
}
main :: proc() {
    // Own even formatting/DOM scratch allocations, then release them before exit.
    o:=c.new_owner(context.allocator)
    context.allocator=c.owner_allocator(o)
    code:=run()
    c.destroy_owner(o)
    os.exit(code)
}
