package main

import c "../shared/content"
import "core:fmt"
import "core:os"
import rl "vendor:raylib"

when #config(ART3_SELF_TEST,false) {
run_art3_tests :: proc() {
    if len(os.args)>1 && os.args[1]=="resources" { art3_resource_tests(); return }
    assert(art_frame("milo_idle_r",0,6)==0)
    assert(art_frame("milo_idle_r",1.21,6)==0)
    assert(art_frame("milo_walk_r",0.34,6)==3)
    assert(art_frame("milo_jump_r",0.31,6)==3)
    assert(art_frame("milo_jump_r",9,6)==5) // Jump never loops.
    assert(art_frame("milo_jump_r",-1,6)==0)
    asset:=c.Asset_Def{frame_size={96,96},pivot={48,88},frame_count=6}
    src,dst:=art_rects(asset,3,{280.49,288.51},{x=12.51},false)
    assert(src==rl.Rectangle{288,0,96,96})
    assert(dst==rl.Rectangle{219,201,96,96}) // round(world)-round(camera)
    asset.pivot[0]=31
    src,dst=art_rects(asset,4,{280.49,288.51},{x=12.51},true)
    assert(src==rl.Rectangle{384,0,-96,96})
    assert(dst==rl.Rectangle{202,201,96,96}) // asymmetric pivot reflects as w-px
    assert(art_actor_asset("oliver_idle_r",.Board)=="oliver_walk_r")
    assert(art_actor_asset("oliver_idle_r",.Fold)=="oliver_idle_r")
    assert(art_actor_asset("rin_idle_r",.Wave)=="rin_idle_r")
    assert(art_actor_asset("milo_idle_r",.Walk)=="milo_idle_r")
    g:=Game_State{mode=.Playing,scene={world={0,0,1280,360},camera_bounds={0,0,1280,360},spawn={280,288},solids=[]rl.Rectangle{{0,288,1280,72}}}}
    start_scene(&g)
    update_game(&g,{move=1},0.1)
    assert(g.art.asset=="milo_walk_r")
    update_game(&g,{move=-1},0.1)
    assert(g.player.facing<0)
    update_game(&g,{jump_pressed=true,jump_down=true},FIXED_DT)
    assert(!g.player.grounded && g.art.asset=="milo_jump_r" && g.art.elapsed==0)
    for _ in 0..<20 { update_game(&g,{jump_down=true},FIXED_DT) }
    elapsed:=g.art.elapsed
    update_game(&g,{pause=true},0)
    for _ in 0..<40 { update_game(&g,{},0.1) }
    assert(g.mode==.Paused && g.art.elapsed==elapsed)
    update_game(&g,{pause=true},0)
    for _ in 0..<120 { update_game(&g,{},FIXED_DT) }
    assert(g.player.grounded && g.art.asset=="milo_idle_r")
    update_game(&g,{jump_pressed=true,jump_down=true},FIXED_DT)
    assert(g.art.asset=="milo_jump_r" && g.art.elapsed==0)
    fmt.println("PASS art3: frame timing/once, mirrored pivots, camera rounding, real input states, pause, landing and repeat jump")
}
art3_resource_tests :: proc() {
    when DEV_TOOLS {
        rl.InitWindow(1280,720,"The Last Stop")
        defer rl.CloseWindow()
        r:=load_runtime_content(os.args[2:],context.allocator)
        defer unload_runtime_content(&r)
        assert(stage_content_resources(&r))
        g:=Game_State{}; configure_content(&g,&r,true)
        for _ in 0..<8 {
            original:=r.snapshot
            count:=len(r.textures)
            assert(count==10)
            for _,texture in r.textures { assert(texture.mipmaps==1) }
            bad_root:=os.get_env("TLS_ART3_BAD_ROOT",context.temp_allocator)
            assert(bad_root!="")
            assert(!reload_runtime_content(&g,&r,[]string{"--project-root",bad_root}))
            assert(r.snapshot==original && len(r.textures)==count && g.content_ready)
            // A paused interaction response borrows its cstring from the old
            // content owner. Successful reload must discard it before free.
            g.mode=.Paused; g.pause_return_mode=.Playing
            g.response=r.text["snail"]; g.response_seconds=3
            assert(reload_runtime_content(&g,&r,os.args[2:]))
            assert(g.response==nil && g.response_seconds==0 && g.mode==.Paused)
            assert(r.snapshot!=original && len(r.textures)==count)
        }
        fmt.println("PASS art3: 8 native staged reloads, failed candidates retain active pair, point-filtered textures have no mipmaps")
    }
}
}
