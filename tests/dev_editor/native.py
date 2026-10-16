#!/usr/bin/env python3
"""Real E2 renderer/CLI demo, with explicitly synthetic native action dispatch.
PID/window verified window-only captures; disposable content and temporary HOME.
--serve retains a local Studio and paused native inspector for browser reflection.
"""
import argparse, hashlib, importlib.util, json, os, shutil, signal, struct, subprocess, tempfile, threading, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/evidence/e2';OUT.mkdir(parents=True,exist_ok=True)
CHILDREN=[];ROWS=[]
def record(name,value):
    (OUT/(name+'.json')).write_text(json.dumps(value,indent=2)+'\n')
def run(args,**kw):
    p=subprocess.run(list(map(str,args)),cwd=ROOT,capture_output=True,timeout=120,**kw)
    ROWS.append(dict(argv=list(map(str,args)),exit=p.returncode,stderr=p.stderr.decode(errors='replace')[-1000:]));record('native-commands',ROWS)
    assert p.returncode==0,p.stderr.decode(errors='replace');return p.stdout

def capture(name,pid,helper):
    path=OUT/(name+'.png')
    for attempt in range(3):
        w=json.loads(run([helper,pid]));assert len(w)==1,w;w=w[0]
        assert w['kCGWindowOwnerPID']==pid and w['kCGWindowName']=='The Last Stop' and w['kCGWindowLayer']==0,w
        try:
            run(['/usr/sbin/screencapture','-x','-o','-l'+str(w['kCGWindowNumber']),path])
            after=json.loads(run([helper,pid]));assert len(after)==1 and after[0]['kCGWindowNumber']==w['kCGWindowNumber']
            png=path.read_bytes();assert png[:8]==b'\x89PNG\r\n\x1a\n';width,height=struct.unpack('>II',png[16:24]);b=w['kCGWindowBounds']
            assert any(abs(int(b['Width'])*s-width)<=4*s and abs(int(b['Height'])*s-height)<=4*s for s in (1,2)),((width,height),b)
            record(name+'-window',dict(before=w,after=after[0],attempt=attempt));return
        except BaseException:
            path.unlink(missing_ok=True)
            if attempt==2:raise
            time.sleep(.2)

class Game:
    def __init__(self,root,home,binary,name,entry='scene'):
        self.dir=root/name;self.dir.mkdir();self.control=self.dir/'input';self.status=self.dir/'status';self.log=(OUT/(name+'.log')).open('wb')
        self.argv=[str(binary),'--project-root',str(root),'--preview-scene','oliver_obstacle','--preview-session',name,'--preview-entry',entry,'--dump-scene']
        self.p=subprocess.Popen(self.argv,cwd='/tmp',env=dict(os.environ,HOME=str(home),TLS_E2_CONTROL=str(self.control),TLS_E2_STATUS=str(self.status)),stdout=self.log,stderr=self.log)
        CHILDREN.append(self);self.wait(lambda s:True)
    def state(self):
        try:return json.loads(self.status.read_text())
        except (FileNotFoundError,json.JSONDecodeError):return None
    def wait(self,pred):
        end=time.monotonic()+20
        while time.monotonic()<end:
            assert self.p.poll() is None,(self.p.returncode,self.argv)
            s=self.state()
            if s and pred(s):return s
            time.sleep(.02)
        raise AssertionError(('native action timeout',self.state()))
    def cmd(self,action,args=None):
        generation=self.state()['generation'];temporary=self.control.with_suffix('.next');temporary.write_text(json.dumps(dict(action=action,args=args)));temporary.replace(self.control)
        if action=='quit':self.p.wait(timeout=10);assert self.p.returncode==0;self.log.close();return
        return self.wait(lambda s:s['generation']>generation)
    def apply(self):
        self.cmd('apply-to-content');s=self.wait(lambda s:not s['pending']);assert not s['dirty'] and not s['uncertain'],s;return s
    def stop(self):
        if self.p.poll() is None:self.p.terminate();self.p.wait(timeout=5)
        if not self.log.closed:self.log.close()
        record(self.dir.name+'-process',dict(pid=self.p.pid,argv=self.argv,exit=self.p.returncode,synthetic_native_actions=True))

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--serve',action='store_true');args=parser.parse_args()
    # Preserve disposable artifacts after the run for independent inspection.
    root=Path(tempfile.mkdtemp(prefix='tls-e2-native-',dir='/tmp')).resolve();home=root/'home';home.mkdir()
    for name in ('data','assets','src','shared','tools'):shutil.copytree(ROOT/name,root/name)
    (root/'build').mkdir();binary=root/'build/dev-e2';helper=OUT/'window-info'
    sentinel=home/'Library/Application Support/The Last Stop/saves/chapter_01.json';sentinel.parent.mkdir(parents=True);sentinel.write_bytes(b'E2_NATIVE_NORMAL_SENTINEL\n')
    before={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'data').rglob('*') if p.is_file()}
    run(['odin','build','tools/content','-out:'+str(root/'build/tls-content')]);run(['odin','build','src','-define:DEV_TOOLS=true','-define:DEV_EDITOR_TEST_HOOKS=true','-define:M4_TEST_HOOKS=true','-out:'+str(binary)])
    run(['swiftc','tests/runtime/window_info.swift','-o',helper])
    game=Game(root,home,binary,'native-edit')
    game.cmd('enter-edit-mode');game.cmd('select-record',dict(collection='objects',id='crank_handle'))
    # A real failed upload must retain geometry and release all staged textures.
    revision=game.state()['revision'];textures=game.state()['live_textures'];assert textures==10
    game.cmd('upload-failure')
    game.cmd('set-property',dict(collection='objects',id='crank_handle',property='position',value=[1192,256]))
    assert game.state()['revision']==revision and game.state()['live_textures']==textures and not game.state()['dirty']
    record('native-resource-rollback',game.state());game.cmd('upload-recovery')
    game.cmd('set-property',dict(collection='objects',id='crank_handle',property='position',value=[1192,256]))
    game.cmd('set-property',dict(collection='objects',id='crank_handle',property='interaction',value=[-40,-20,96,68]))
    assert game.state()['dirty'] and game.state()['paused'];capture('native-draft',game.p.pid,helper)
    # Before Apply, neither authored content nor the sentinel has changed.
    assert before=={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'data').rglob('*') if p.is_file()}
    state=game.apply();record('native-apply',state);capture('native-applied',game.p.pid,helper);game.cmd('quit');game.stop()
    changed=[str(p.relative_to(root)) for p in (root/'data').rglob('*') if p.is_file() and before[str(p.relative_to(root))]!=hashlib.sha256(p.read_bytes()).hexdigest()];assert changed==['data/scenes/oliver_obstacle.json'],changed
    game=Game(root,home,binary,'native-relaunch');game.cmd('enter-edit-mode');game.cmd('select-record',dict(collection='objects',id='crank_handle'))
    state=game.state();assert state['authored']['objects']['crank_handle']['position']==[1192,256] and state['authored']['objects']['crank_handle']['interaction']==[-40,-20,96,68]
    time.sleep(.25);capture('native-relaunch',game.p.pid,helper);record('native-relaunch',state)
    resize=OUT/'resize-window';run(['swiftc','tests/runtime/res640_window.swift','-o',resize]);run([resize,game.p.pid,640,360,720]);time.sleep(.3);capture('native-minimum-inspector',game.p.pid,helper)
    run([resize,game.p.pid,1280,720,360]);time.sleep(.2)
    # The relaunch log independently dumps the on-disk authored geometry.
    text=(OUT/'native-relaunch.log').read_text();assert 'object=crank_handle position=[1192, 256]' in text and 'interaction_local=Recti{x = -40, y = -20, w = 96, h = 68}' in text,text[-2000:]
    journey=Game(root,home,binary,'native-journey','chapter');journey.wait(lambda s:s['mode']=='Station_Intro');time.sleep(.3);capture('native-journey',journey.p.pid,helper);record('native-journey',journey.state());journey.cmd('quit');journey.stop()
    preview=home/'Library/Caches/The Last Stop/preview'
    (preview/'native-blocked').symlink_to(sentinel.parent,target_is_directory=True)
    blocked=Game(root,home,binary,'native-blocked');assert blocked.state()['mode']=='Content_Error';record('native-blocked-profile',blocked.state());blocked.cmd('quit');blocked.stop()
    assert sentinel.read_bytes()==b'E2_NATIVE_NORMAL_SENTINEL\n'
    server=None
    if args.serve:
        spec=importlib.util.spec_from_file_location('e2_editor_server',ROOT/'editor/server.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        server=module.make_server(root);threading.Thread(target=server.serve_forever,daemon=True).start()
        state=dict(root=str(root),home=str(home),url='http://127.0.0.1:%d/#token=%s'%(server.server_port,server.bridge.token),pid=game.p.pid,control=str(game.control),status=str(game.status),helper=str(helper),sentinel=str(sentinel))
        record('demo-state',state);print(json.dumps(state),flush=True)
        end=time.monotonic()+1200
        try:
            while time.monotonic()<end and not (root/'finish-demo').exists():time.sleep(.2)
        finally:server.shutdown();server.server_close();server.bridge.close()
    game.cmd('quit');game.stop();assert sentinel.read_bytes()==b'E2_NATIVE_NORMAL_SENTINEL\n'
    record('native-summary',dict(root=str(root),changed_documents=changed,normal_save_unchanged=True,all_processes_reaped=True,synthetic_native_actions=True,physical_input='human check required'))
    print('PASS E2 real native draft/Apply/relaunch/preview-entry chapter; verified window captures',root)

if __name__=='__main__':
    try:main()
    finally:
        for game in CHILDREN:game.stop()
