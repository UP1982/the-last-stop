package content_edit

import c "../content"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:sys/posix"

Commit_State :: enum { Not_Committed, Committed, Committed_Durability_Uncertain }
state_string :: proc(s:Commit_State) -> string {
    #partial switch s { case .Committed:return "committed"; case .Committed_Durability_Uncertain:return "committed_durability_uncertain" }
    return "not_committed"
}
Edit_Request :: struct {
    request_id:string,
    chapter,document:c.ID,
    expected_revision:string,
    operations:json.Array,
}
Request_Result :: struct { request:Edit_Request, diagnostics:[]c.Diagnostic, owner:^c.Owner }
Edit_Result :: struct {
    state:Commit_State,
    old_revision,new_revision:c.Revision,
    changed_document,undo_token:string,
    diagnostics:[]c.Diagnostic,
    exit_code:int,
    owner:^c.Owner,
}
Prepared_Edit :: struct {
    owner:^c.Owner,
    candidate:c.Load_Result,
    path:string,
    bytes,before:[]u8,
    noop:bool,
}
destroy_request_result :: proc(r:^Request_Result) { c.destroy_owner(r.owner); r^={} }
destroy_edit_result :: proc(r:^Edit_Result) { c.destroy_owner(r.owner); r^={} }
destroy_prepared_edit :: proc(p:^Prepared_Edit) {
    if p==nil { return }
    c.destroy_load_result(&p.candidate)
    c.destroy_owner(p.owner)
}
request_parse :: proc(bytes:[]u8,allocator:mem.Allocator) -> Request_Result {
    o:=c.new_owner(allocator); context.allocator=c.owner_allocator(o)
    val,d,ok:=c.parse_strict(bytes,"request")
    if !ok { ds:=make([]c.Diagnostic,1); ds[0]=d; return {diagnostics=ds,owner=o} }
    v:=c.Validator{file="request"}
    c.keys(&v,val,"","protocol_version|request_id|chapter|document|expected_revision|operations","")
    c.int_value(&v,c.get(val,"protocol_version"),"/protocol_version",1,1)
    r:=Edit_Request{request_id=string(c.id_value(&v,c.get(val,"request_id"),"/request_id")),chapter=c.id_value(&v,c.get(val,"chapter"),"/chapter"),document=c.id_value(&v,c.get(val,"document"),"/document"),expected_revision=c.str(&v,c.get(val,"expected_revision"),"/expected_revision",71)}
    if len(r.expected_revision)!=71 || !strings.has_prefix(r.expected_revision,"sha256:") || !c.valid_hex(r.expected_revision[7:]) { c.fail(&v,"revision","/expected_revision","Expected sha256:<64 lowercase hex digits>") }
    a,valid:=c.get(val,"operations").(json.Array)
    if !valid || len(a)<1 || len(a)>256 { c.fail(&v,"operations","/operations","Expected 1..256 operations targeting one document") }
    r.operations=a
    for op,i in a {
        p:=fmt.aprintf("/operations/%d",i)
        required,optional:string
        switch c.text(c.get(op,"op")) {
        case "create": required="op|collection|id|value"
        case "delete": required="op|collection|id"
        case "set_property": required="op|collection|id|property|value"
        case "link_object": required="op|role|target"
        case "update_dialogue": required="op|id"; optional="speaker|text"
        case "set_order": required="op|order"
        case "restore_document": required="op|value"
        case: c.fail(&v,"operation",ptr_op(i),"Unsupported operation"); continue
        }
        c.keys(&v,op,p,required,optional)
    }
    return {r,v.diagnostics[:],o}
}
ptr_op :: proc(i:int) -> string { return fmt.aprintf("/operations/%d",i) }
collection_allowed :: proc(kind,collection:string) -> bool {
    switch kind {
    case "scene":return c.member(collection,"objects|spawns")
    case "dialogue":return collection=="lines"
    case "chapter":return c.member(collection,"speakers|keepsakes")
    case "assets":return collection=="assets"
    }
    return false
}
property_allowed :: proc(collection,property:string) -> bool {
    switch collection {
    case "objects":return c.member(property,"position|size|layer|collision|interaction|asset")
    case "spawns":return property=="position"
    case "speakers":return c.member(property,"name|species")
    case "keepsakes":return property=="name"
    case "assets":return c.member(property,"frame_size|frame_count|pivot|provenance")
    }
    return false
}
apply_operations :: proc(value:json.Value,r:Edit_Request,v:^c.Validator) -> json.Value {
    root:=json.clone_value(value)
    kind,id:=c.text(c.get(root,"kind")),c.text(c.get(root,"id"))
    for op,i in r.operations {
        prior:=len(v.diagnostics); p:=ptr_op(i); name:=c.text(c.get(op,"op"))
        switch name {
        case "create","delete","set_property":
            collection:=c.str(v,c.get(op,"collection"),c.ptr(p,"collection"),64)
            key:=string(c.id_value(v,c.get(op,"id"),c.ptr(p,"id")))
            if !collection_allowed(kind,collection) { c.fail(v,"allowlist",p,"Collection not editable on this document"); break }
            records:=c.object(c.get(root,collection)); record,present:=records[key]
            if name=="create" {
                if present { c.fail(v,"duplicate_identity",p,"Create requires a fresh ID"); break }
                if _,ok:=c.get(op,"value").(json.Object); !ok { c.fail(v,"type",p,"Create requires a complete record"); break }
                records[strings.clone(key)]=json.clone_value(c.get(op,"value"))
            } else if !present { c.fail(v,"missing_record",p,"Record does not exist")
            } else if name=="delete" { delete_key(&records,key)
            } else {
                property:=c.str(v,c.get(op,"property"),c.ptr(p,"property"),64)
                if !property_allowed(collection,property) { c.fail(v,"allowlist",p,"Property not editable"); break }
                fields:=c.object(record); fields[strings.clone(property)]=json.clone_value(c.get(op,"value")); records[key]=fields
            }
            fields:=c.object(root); fields[collection]=records; root=fields
        case "link_object":
            role:=c.str(v,c.get(op,"role"),c.ptr(p,"role"),64)
            target:=string(c.id_value(v,c.get(op,"target"),c.ptr(p,"target")))
            if kind!="scene" || !c.member(role,"train|branch|winch|shed|handle|snail|player_spawn|return_spawn|handle_recovery_spawn") { c.fail(v,"allowlist",p,"Puzzle role not editable"); break }
            puzzle:=c.object(c.get(root,"puzzle")); puzzle[strings.clone(role)]=strings.clone(target)
            fields:=c.object(root); fields["puzzle"]=puzzle; root=fields
        case "update_dialogue":
            key:=string(c.id_value(v,c.get(op,"id"),c.ptr(p,"id")))
            lines:=c.object(c.get(root,"lines")); line,present:=lines[key]
            if kind!="dialogue" || !present { c.fail(v,"missing_record",p,"Dialogue line does not exist"); break }
            if !c.has(op,"speaker") && !c.has(op,"text") { c.fail(v,"operation",p,"Supply speaker and/or text"); break }
            fields:=c.object(line)
            for field in ([]string{"speaker","text"}) { if c.has(op,field) { fields[field]=json.clone_value(c.get(op,field)) } }
            lines[key]=fields
        case "set_order":
            if kind!="dialogue" { c.fail(v,"allowlist",p,"Only dialogue order is editable"); break }
            fields:=c.object(root); fields["order"]=json.clone_value(c.get(op,"order")); root=fields
        case "restore_document":
            replacement:=c.get(op,"value")
            if c.text(c.get(replacement,"kind"))!=kind || c.text(c.get(replacement,"id"))!=id || c.integer(c.get(replacement,"schema_version"))!=c.integer(c.get(value,"schema_version")) { c.fail(v,"identity",p,"Restore must preserve kind, ID and version"); break }
            root=json.clone_value(replacement)
        case: c.fail(v,"operation",p,"Unsupported operation")
        }
        for j in prior..<len(v.diagnostics) { v.diagnostics[j].op_index=i }
        if len(v.diagnostics)>prior { break }
    }
    return root
}
// prepare_edit never writes. Failure diagnostics use the supplied allocator;
// success owns its candidate and buffers until destroy_prepared_edit.
prepare_edit :: proc(s:^c.Snapshot,r:Edit_Request,allocator:mem.Allocator,project_root:string="",lock_fd:posix.FD=-1) -> (^Prepared_Edit,[]c.Diagnostic) {
    context.allocator=allocator
    v:=c.Validator{file="request"}
    if string(s.chapter.id)!=string(r.chapter) { c.fail(&v,"chapter","/chapter","Unknown chapter") }
    if c.revision_string(s.revision)!=r.expected_revision { c.fail(&v,"stale_revision","/expected_revision","Chapter graph revision is stale") }
    target:^c.Document
    for &d in s.documents { if d.id==r.document { target=&d; break } }
    if target==nil { c.fail(&v,"document","/document","Document not found in chapter graph") }
    if len(v.diagnostics)>0 { return nil,v.diagnostics[:] }
    o:=c.new_owner(allocator); context.allocator=c.owner_allocator(o)
    p:=new(Prepared_Edit); p.owner=o
    p.path=strings.clone(target.source.path); p.before=slice.clone(target.source.bytes)
    root:=apply_operations(target.value,r,&v)
    if len(v.diagnostics)>0 {
        // Copy diagnostics out of the candidate allocation domain.
        context.allocator=allocator
        ds:=make([]c.Diagnostic,len(v.diagnostics))
        for d,i in v.diagnostics { ds[i]=d; ds[i].pointer=strings.clone(d.pointer) }
        c.destroy_owner(o); return nil,ds
    }
    normalized_before:=c.serialize(target.value)
    p.bytes=c.serialize(root)
    if len(p.bytes)==0 {
        context.allocator=allocator
        ds:=make([]c.Diagnostic,1); ds[0]=c.diagnostic("serialization","request","","Failed serialization")
        c.destroy_owner(o); return nil,ds
    }
    p.noop=string(normalized_before)==string(p.bytes)
    sources:=make([]c.Document_Source,len(s.sources)); copy(sources,s.sources[:])
    for &src in sources { if src.path==p.path { src.bytes=p.bytes } }
    if project_root!="" && lock_fd>=0 {
        p.candidate=c.validate_candidate_sources(project_root,sources,s.chapter_path,context.allocator,lock_fd)
    } else { p.candidate=c.validate_sources(sources,s.chapter_path,context.allocator) }
    if p.candidate.snapshot==nil {
        context.allocator=allocator
        ds:=make([]c.Diagnostic,len(p.candidate.diagnostics))
        for d,i in p.candidate.diagnostics {
            ds[i]=d; ds[i].file=strings.clone(d.file); ds[i].pointer=strings.clone(d.pointer); ds[i].message=strings.clone(d.message)
        }
        destroy_prepared_edit(p); return nil,ds
    }
    return p,nil
}
