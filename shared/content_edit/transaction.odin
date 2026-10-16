#+feature dynamic-literals
package content_edit

import c "../content"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "core:sys/posix"
import "core:time"

// Faults exist only in binaries compiled with -define:E0_TEST_HOOKS=true.
// Production builds do not read these environment variables.
TEST_HOOKS :: #config(E0_TEST_HOOKS,false)
hook :: proc(name:string) -> bool {
    when TEST_HOOKS { return os.get_env("TLS_E0_FAULT",context.allocator)==name }
    return false
}
checkpoint :: proc(name:string) {
    when TEST_HOOKS {
        if os.get_env("TLS_E0_PAUSE",context.allocator)==name {
            marker:=os.get_env("TLS_E0_MARKER",context.allocator)
            if marker!="" { _ = os.write_entire_file(marker,name) }
            // Bounded test rendezvous. Test runner terminates or releases us.
            for _ in 0..<3000 {
                if _,e:=os.stat(fmt.aprintf("%s.release",marker),context.allocator); e==nil { break }
                time.sleep(10*time.Millisecond)
            }
        }
    }
}
result_error :: proc(r:^Edit_Result,exit_code:int,code,file,message:string) {
    r.exit_code=exit_code
    ds:=make([]c.Diagnostic,1); ds[0]=c.diagnostic(code,strings.clone(file),"",strings.clone(message)); r.diagnostics=ds
}
secure_directory :: proc(root,relative:string) -> bool {
    current:=root
    for part in strings.split(relative,"/") {
        if part=="" || part==".." || part=="." { return false }
        parent:=current
        current=fmt.aprintf("%s/%s",current,part)
        e:=os.mkdir(current,{.Read_User,.Write_User,.Execute_User})
        if e!=nil && e!=.Exist { return false }
        if e==nil && !sync_directory(parent) { return false }
        info,se:=os.lstat(current,context.allocator)
        if se!=nil { return false }
        ok:=info.type==.Directory; os.file_info_delete(info,context.allocator)
        if !ok { return false }
    }
    return true
}
sync_directory :: proc(path:string) -> bool {
    fd:=posix.open(strings.clone_to_cstring(path),{.DIRECTORY,.NOFOLLOW},{})
    if fd<0 { return false }
    synced:=posix.fsync(fd)==nil; closed:=posix.close(fd)==nil
    return synced && closed
}
write_synced :: proc(f:^os.File,bytes:[]u8,inject:=false) -> bool {
    payload:=bytes
    if inject && hook("short_write") { payload=bytes[:len(bytes)/2] }
    n,e:=os.write(f,payload)
    wrote:=e==nil && n==len(bytes)
    synced:=false
    if wrote { synced=os.sync(f)==nil; if inject && hook("sync") { synced=false } }
    closed:=os.close(f)==nil
    if inject && hook("close") { closed=false }
    return wrote && synced && closed
}
exclusive_history_file :: proc(path:string,bytes:[]u8) -> bool {
    f,e:=os.open(path,{.Write,.Create,.Excl},{.Read_User,.Write_User})
    if e!=nil { return false }
    return write_synced(f,bytes)
}
apply_edit :: proc(project_root:string,request:Edit_Request,allocator:mem.Allocator) -> Edit_Result {
    owner:=c.new_owner(allocator); context.allocator=c.owner_allocator(owner)
    r:=Edit_Result{owner=owner}
    if !secure_directory(project_root,".studio") { result_error(&r,4,"io_lock",".studio","Cannot create safe Studio directory"); return r }
    lock_path:=fmt.aprintf("%s/.studio/content.lock",project_root)
    fd:=posix.open(strings.clone_to_cstring(lock_path),{.RDWR,.CREAT,.NOFOLLOW},{.IRUSR,.IWUSR})
    if fd<0 { result_error(&r,4,"io_lock",".studio/content.lock","Cannot open permanent lock"); return r }
    defer posix.close(fd)
    lock:=posix.flock{l_type=.WRLCK,l_whence=0}
    if posix.fcntl(fd,.SETLK,&lock)<0 {
        errno:=posix.errno()
        if errno==.EACCES || errno==.EAGAIN { result_error(&r,3,"busy",".studio/content.lock","Writer lock busy; retry after inspecting revision") }
        else { result_error(&r,4,"io_lock",".studio/content.lock","Cannot acquire writer lock") }
        return r
    }
    checkpoint("locked")
    loaded:=c.load_chapter(project_root,c.CHAPTER_PATH,context.allocator)
    defer c.destroy_load_result(&loaded)
    if loaded.snapshot==nil {
        // Copy diagnostics into this result's domain before the load is destroyed.
        r.diagnostics=clone_diagnostics(loaded.diagnostics)
        r.exit_code=2
        for d in r.diagnostics {
            if d.code=="external_change" { r.exit_code=3 }
            if d.code=="io_read" { r.exit_code=4 }
        }
        return r
    }
    s:=loaded.snapshot; r.old_revision=s.revision; r.new_revision=s.revision
    if c.revision_string(s.revision)!=request.expected_revision { result_error(&r,3,"stale_revision",s.chapter_path,"Chapter graph changed; inspect before retrying"); return r }
    prepared,ds:=prepare_edit(s,request,context.allocator)
    if prepared==nil { r.diagnostics=ds; r.exit_code=2; return r }
    defer destroy_prepared_edit(prepared)
    r.changed_document=strings.clone(prepared.path)
    if prepared.noop { return r }
    if hook("history") || !secure_directory(project_root,".studio/history") { result_error(&r,4,"io_history",prepared.path,"Cannot persist recovery history"); return r }
    history:=fmt.aprintf("%s/.studio/history",project_root)
    transaction,e:=os.mkdir_temp(history,"txn-*",context.allocator)
    if e!=nil { result_error(&r,4,"io_history",prepared.path,"Cannot allocate transaction directory"); return r }
    _,token:=os.split_path(transaction)
    r.undo_token=strings.clone(token)
    new_revision:=prepared.candidate.snapshot.revision
    record:=json.Object{
        "protocol_version"=i64(1),"request_id"=request.request_id,
        "document"=string(request.document),"path"=prepared.path,
        "old_revision"=c.revision_string(s.revision),"new_revision"=c.revision_string(new_revision),
        "before_sha256"=c.hex_digest(c.hash_bytes(prepared.before)),
        "after_sha256"=c.hex_digest(c.hash_bytes(prepared.bytes)),
        "commit_state"="prepared",
    }
    if !exclusive_history_file(fmt.aprintf("%s/before.json",transaction),prepared.before) || !exclusive_history_file(fmt.aprintf("%s/after.json",transaction),prepared.bytes) || !exclusive_history_file(fmt.aprintf("%s/prepared.json",transaction),c.serialize(record)) || !sync_directory(transaction) || !sync_directory(history) {
        result_error(&r,4,"io_history",prepared.path,"Before-image and prepared record must be durable before commit"); return r
    }
    destination:=fmt.aprintf("%s/%s",project_root,prepared.path)
    dir,_:=os.split_path(destination)
    if hook("temp") { result_error(&r,4,"io_temp",prepared.path,"Injected temp creation failure"); return r }
    temp,te:=os.create_temp_file(dir,".tls-content-*")
    if te!=nil { result_error(&r,4,"io_temp",prepared.path,"Cannot create exclusive temporary file beside destination"); return r }
    temporary:=strings.clone(os.name(temp))
    defer os.remove(temporary)
    if !write_synced(temp,prepared.bytes,true) { result_error(&r,4,"io_write",prepared.path,"Temporary write/sync/close failed; old document remains authoritative"); return r }
    checkpoint("before_recheck")
    // Hash all dependencies under the lock, immediately before replacement.
    current:=c.load_chapter(project_root,c.CHAPTER_PATH,context.allocator)
    changed:=current.snapshot==nil || current.snapshot.revision!=s.revision
    c.destroy_load_result(&current)
    if changed { result_error(&r,3,"external_change",prepared.path,"Dependency changed during transaction; no replacement performed"); return r }
    checkpoint("before_rename")
    if hook("rename") || os.rename(temporary,destination)!=nil { result_error(&r,4,"io_rename",prepared.path,"Atomic replacement failed"); return r }
    // COMMIT POINT. All later failures must report a committed state and the
    // candidate revision, never old bytes or a promise of rollback.
    r.state=.Committed; r.new_revision=new_revision
    checkpoint("after_rename")
    durable:=!hook("directory_sync") && sync_directory(dir)
    record["commit_state"]="committed"
    finalized:=false
    if !hook("finalize_history") {
        finalized=exclusive_history_file(fmt.aprintf("%s/committed.json",transaction),c.serialize(record)) && sync_directory(transaction)
    }
    if !durable || !finalized { r.state=.Committed_Durability_Uncertain; result_error(&r,5,"durability_uncertain",prepared.path,"Replacement committed; directory sync or history finalization failed. Inspect transaction and revision before retrying") }
    return r
}
clone_diagnostics :: proc(ds:[]c.Diagnostic) -> []c.Diagnostic {
    result:=make([]c.Diagnostic,len(ds))
    for d,i in ds {
        result[i]=d; result[i].file=strings.clone(d.file); result[i].pointer=strings.clone(d.pointer)
        result[i].code=strings.clone(d.code); result[i].message=strings.clone(d.message); result[i].subject_id=strings.clone(d.subject_id)
    }
    return result
}
