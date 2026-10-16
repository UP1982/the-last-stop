package content

import "core:encoding/json"
import "core:crypto/sha2"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"
import "core:sys/posix"

hash_bytes :: proc(b: []u8) -> Revision { c:sha2.Context_256; sha2.init_256(&c); sha2.update(&c,b); r:Revision; sha2.final(&c,r[:]); return r }
hex_digest :: proc(r: Revision) -> string {
    b:=make([]u8,64); chars:="0123456789abcdef"
    for x,i in r { b[i*2]=chars[x>>4]; b[i*2+1]=chars[x&15] }
    return string(b)
}
revision_string :: proc(r: Revision) -> string { return fmt.aprintf("sha256:%s",hex_digest(r)) }
// Wire revision v1: sort paths bytewise; for each append u64 big-endian path
// byte length, UTF-8 path bytes, u64 big-endian digest length (32), raw SHA-256.
// There is no mtime, filename separator ambiguity, or independently stored epoch.
graph_revision :: proc(sources: []Document_Source) -> Revision {
    ordered:=make([]Document_Source,len(sources)); copy(ordered,sources)
    defer delete(ordered)
    slice.sort_by(ordered,proc(a,b:Document_Source)->bool{return a.path<b.path})
    c:sha2.Context_256; sha2.init_256(&c)
    for &s in ordered {
        length:[8]u8
        for i in 0..<8 { length[7-i]=u8(u64(len(s.path))>>u64(i*8)) }
        sha2.update(&c,length[:])
        sha2.update(&c,transmute([]u8)s.path)
        b:[8]u8; b[7]=32; sha2.update(&c,b[:]); sha2.update(&c,s.revision[:])
    }
    r:Revision; sha2.final(&c,r[:]); return r
}
// Reject symlink components rather than following them. This guarantees subtree
// confinement for ordinary external editing too; managed writes must be idle
// while an unmanaged process changes files (POSIX has no file compare-and-swap).
confined :: proc(root,path,prefix: string) -> bool {
    if !valid_path(path,prefix) { return false }
    current:=root
    for part in strings.split(path,"/") {
        current=fmt.aprintf("%s/%s",current,part)
        info,e:=os.lstat(current,context.allocator)
        if e!=nil { return false }
        bad:=info.type==.Symlink
        os.file_info_delete(info,context.allocator)
        if bad { return false }
    }
    return true
}
// Bounded before allocation, and rechecked after reading to catch growing files.
read_bounded :: proc(path: string,limit: int,lock_fd:posix.FD=-1) -> ([]u8,bool) {
    info,ie:=os.stat(path,context.allocator)
    if ie!=nil { return nil,false }
    regular:=info.type==.Regular; os.file_info_delete(info,context.allocator)
    if !regular { return nil,false }
    f,e:=os.open(path); if e!=nil { return nil,false }; defer os.close(f)
    // Closing ANY descriptor for the locked inode drops this process's POSIX
    // record locks. Reject aliases before reading, and abort the transaction.
    if lock_fd>=0 {
        dependency,lock:posix.stat_t
        if posix.fstat(posix.FD(os.fd(f)),&dependency)!=nil || posix.fstat(lock_fd,&lock)!=nil ||
           !posix.S_ISREG(lock.st_mode) || lock.st_nlink!=1 ||
           dependency.st_dev==lock.st_dev && dependency.st_ino==lock.st_ino { return nil,false }
    }
    n,se:=os.file_size(f); if se!=nil || n<0 || n>i64(limit) { return nil,false }
    b:=make([]u8,int(n)); total:=0
    for total<len(b) {
        got,re:=os.read(f,b[total:]); if re!=nil || got<=0 { return nil,false }; total+=got
    }
    extra:[1]u8; got,_:=os.read(f,extra[:]); if got!=0 { return nil,false }
    return b,true
}
Loader :: struct { s:^Snapshot, v:Validator, root:string, inputs:[]Document_Source, disk:bool, total:int, lock_fd:posix.FD }
source_get :: proc(l:^Loader,path,prefix:string,binary:=false) -> (Document_Source,bool) {
    for src in l.s.sources { if src.path==path { return src,true } }
    if len(l.s.sources)>=MAX_SOURCES { fail(&l.v,"count_limit","","Too many dependencies"); return {},false }
    if !valid_path(path,prefix) { fail(&l.v,"unsafe_path","","Unsafe dependency path"); return {},false }
    limit:=MAX_DOCUMENT_BYTES; if binary { limit=MAX_ASSET_BYTES }
    limit=min(limit,MAX_GRAPH_BYTES-l.total)
    b:[]u8
    found:=false
    if !l.disk { for src in l.inputs { if src.path==path { b=src.bytes; found=true; break } } }
    // A candidate may introduce binary assets, but its JSON documents must
    // still come from the supplied snapshot/serialized replacement. This is
    // read-only and uses the same confinement and bounds as ordinary loading.
    if l.disk || !found && binary && l.root!="" {
        if !confined(l.root,path,prefix) { l.v.file=path; fail(&l.v,"unsafe_path","","Missing file or symlink dependency"); return {},false }
        info,ie:=os.stat(fmt.aprintf("%s/%s",l.root,path),context.allocator)
        if ie==nil {
            too_big:=info.size>i64(limit); os.file_info_delete(info,context.allocator)
            if too_big { l.v.file=path; fail(&l.v,"size_limit","","Dependency size bound exceeded"); return {},false }
        }
        ok:bool
        b,ok=read_bounded(fmt.aprintf("%s/%s",l.root,path),limit,l.lock_fd)
        if !ok { l.v.file=path; fail(&l.v,"io_read","","Cannot read bounded dependency"); return {},false }
    } else {
        if !found { l.v.file=path; fail(&l.v,"missing_reference","","Dependency source missing"); return {},false }
        if len(b)>limit { l.v.file=path; fail(&l.v,"size_limit","","Dependency size bound exceeded"); return {},false }
        b=slice.clone(b)
    }
    l.total+=len(b)
    if len(b)>limit || l.total>MAX_GRAPH_BYTES { fail(&l.v,"size_limit","","Dependency size bound exceeded"); return {},false }
    src:=Document_Source{strings.clone(path),b,hash_bytes(b)}
    append(&l.s.sources,src); return src,true
}
load_document :: proc(l:^Loader,ref:Reference,kind,prefix:string) -> (json.Value,bool) {
    l.v.file=ref.path
    for d in l.s.documents { if d.id==ref.id && ref.id!="" || d.source.path==ref.path { fail(&l.v,"duplicate_identity","/id","Document ID or path referenced twice"); return {},false } }
    src,ok:=source_get(l,ref.path,prefix); if !ok { return {},false }
    value,d,valid:=parse_strict(src.bytes,ref.path)
    if !valid { append(&l.v.diagnostics,d); return {},false }
    id:=envelope(&l.v,value,kind)
    if ref.id!="" && id!=ref.id { fail(&l.v,"reference_identity","/id","Loaded ID differs from reference") }
    if len(l.v.diagnostics)>0 { return {},false }
    append(&l.s.documents,Document{src,value,id,kind})
    return value,true
}
build_graph :: proc(root,path:string,inputs:[]Document_Source,disk:bool,allocator:mem.Allocator,lock_fd:posix.FD=-1) -> Load_Result {
    o:=new_owner(allocator); context.allocator=owner_allocator(o)
    path:=strings.clone(path)
    if !disk {
        paths:=make(map[string]bool)
        for src in inputs {
            if paths[src.path] {
                ds:=make([]Diagnostic,1); ds[0]=diagnostic("duplicate_source",strings.clone(src.path),"","Supplied source paths must be unique")
                return {diagnostics=ds,owner=o}
            }
            paths[src.path]=true
        }
    }
    s:=new(Snapshot); s.owner=o; s.chapter_path=strings.clone(path)
    s.scenes=make(map[ID]Scene_Def); s.dialogues=make(map[ID]Dialogue_Def)
    l:=Loader{s=s,root=root,inputs=inputs,disk=disk,lock_fd=lock_fd}
    x,ok:=load_document(&l,{path=path},"chapter","data/chapters/")
    if ok {
        s.chapter=chapter_decode(&l.v,x)
        if len(l.v.diagnostics)==0 {
            if a,valid:=load_document(&l,s.chapter.assets,"assets","data/assets/"); valid { s.assets=assets_decode(&l.v,a) }
            for ref in s.chapter.scenes { if val,valid:=load_document(&l,ref,"scene","data/scenes/"); valid { sc:=scene_decode(&l.v,val); s.scenes[sc.id]=sc } }
            for role in ([]string{"intro","arrival"}) {
                ref:=s.chapter.dialogues[role]
                if val,valid:=load_document(&l,ref,"dialogue","data/dialogue/"); valid { d:=dialogue_decode(&l.v,val); s.dialogues[d.id]=d }
            }
        }
    }
    if len(l.v.diagnostics)==0 {
        for _,a in s.assets {
            l.v.file=s.chapter.assets.path
            if src,valid:=source_get(&l,a.path,"assets/",true); valid && hex_digest(src.revision)!=a.sha256 { fail(&l.v,"asset_hash","/assets","Asset bytes do not match declared SHA-256") }
        }
        if len(l.v.diagnostics)==0 { graph_validate(&l.v,s) }
    }
    if len(l.v.diagnostics)==0 && disk {
        for src in s.sources {
            prefix:="data/"; limit:=MAX_DOCUMENT_BYTES
            if strings.has_prefix(src.path,"assets/") { prefix="assets/"; limit=MAX_ASSET_BYTES }
            b,valid:=read_bounded(fmt.aprintf("%s/%s",root,src.path),limit,lock_fd)
            if !valid || !confined(root,src.path,prefix) || hash_bytes(b)!=src.revision { l.v.file=src.path; fail(&l.v,"external_change","","Dependency changed during load") }
        }
    }
    if len(l.v.diagnostics)>0 { return {diagnostics=l.v.diagnostics[:],owner=o} }
    s.revision=graph_revision(s.sources[:])
    return {snapshot=s}
}
load_chapter :: proc(project_root,chapter_path:string,allocator:mem.Allocator,lock_fd:posix.FD=-1) -> Load_Result { return build_graph(project_root,chapter_path,nil,true,allocator,lock_fd) }
// Writer-only candidate validation: resolve newly referenced asset files while
// its permanent lock is held. Successful sources include them in the revision.
validate_candidate_sources :: proc(project_root:string,sources:[]Document_Source,chapter_path:string,allocator:mem.Allocator,lock_fd:posix.FD) -> Load_Result {
    return build_graph(project_root,chapter_path,sources,false,allocator,lock_fd)
}
validate_sources :: proc(sources:[]Document_Source,chapter_path:string,allocator:mem.Allocator) -> Load_Result {
    if len(sources)>MAX_SOURCES { o:=new_owner(allocator); context.allocator=owner_allocator(o); ds:=make([]Diagnostic,1); ds[0]=diagnostic("count_limit",chapter_path,"","Too many supplied sources"); return {diagnostics=ds,owner=o} }
    return build_graph("",chapter_path,sources,false,allocator)
}
serialize :: proc(value:json.Value) -> []u8 {
    s,e:=json.unparse(value,{spec=.JSON,pretty=true,use_spaces=true,spaces=2,sort_maps_by_key=true})
    if e!=nil { return nil }
    return transmute([]u8)fmt.aprintf("%s\n",s)
}
