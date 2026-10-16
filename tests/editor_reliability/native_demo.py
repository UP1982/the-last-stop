#!/usr/bin/env python3
"""E4 acceptance coordinator. Mutates one disposable integrated project only.
Browser actions use T3's collaborative browser externally. File commands are test
coordination, never a Studio API. Native actions are explicitly synthetic.
"""
import copy, hashlib, importlib.util, json, os, shutil, signal, subprocess, sys, tempfile, time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'editor_workspace'))
from common import ROOT, Client, project
spec=importlib.util.spec_from_file_location('e4_native',ROOT/'tests/dev_editor/native.py');native=importlib.util.module_from_spec(spec);spec.loader.exec_module(native)
OUT=ROOT/'build/evidence/e4';OUT.mkdir(parents=True,exist_ok=True);native.OUT=OUT
ROWS=[]
def record(name,value): (OUT/(name+'.json')).write_text(json.dumps(value,indent=2)+'\n')
def run(args,**kw):
    p=subprocess.run(list(map(str,args)),capture_output=True,timeout=180,**kw)
    ROWS.append(dict(argv=list(map(str,args)),exit=p.returncode,stderr=p.stderr.decode(errors='replace')[-2000:]));record('demo-commands',ROWS)
    assert p.returncode==0,(args,p.returncode,p.stderr.decode(errors='replace')[-3000:]);return p

def hashes(root):return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'data').rglob('*') if p.is_file() and not p.name.startswith('.tls-')}

def main():
    root=Path(tempfile.mkdtemp(prefix='tls-e4-acceptance-',dir='/tmp')).resolve();project(root)
    home=root/'home';home.mkdir();os.environ['HOME']=str(home)
    sentinel=home/'Library/Application Support/The Last Stop/saves/chapter_01.json';sentinel.parent.mkdir(parents=True);sentinel.write_bytes(b'E4_NORMAL_SAVE_SENTINEL\n')
    override=root/'override';override.mkdir();(override/'sentinel').write_text('untouched');os.environ['TLS_SAVE_DIR']=str(override)
    pristine=hashes(root);record('pristine-hashes',pristine)
    original_scene=json.loads((root/'data/scenes/oliver_obstacle.json').read_text());original_intro=json.loads((root/'data/dialogue/oliver_intro.json').read_text())
    helper=OUT/'window-info';run(['swiftc',ROOT/'tests/runtime/window_info.swift','-o',helper]);control=OUT/'window-control';run(['swiftc',ROOT/'tests/resilience/window_control.swift','-o',control])
    client=Client(root);binary=root/'build/native-inspector';alive=[True];sequence=0
    signal.signal(signal.SIGTERM,lambda *_:alive.__setitem__(0,False))
    def state():record('demo-state',dict(root=str(root),home=str(home),pid=os.getpid(),url='http://127.0.0.1:%d/#token=%s'%(client.server.server_port,client.bridge.token),sequence=sequence))
    def capture(name,pid):time.sleep(.3);native.capture(name,pid,helper)
    def assert_isolation():assert sentinel.read_bytes()==b'E4_NORMAL_SAVE_SENTINEL\n';assert sorted(p.name for p in override.iterdir())==['sentinel']
    def journeys(artifact):
        before=hashes(root)
        for route in ('advance','skip','restart'):
            rendezvous=root/('journey-'+route);rendezvous.mkdir();profile=root/('profile-'+route);profile.mkdir()
            stages=set();starts=0;reload_label=''
            while True:
                starts+=1;argv=[artifact,'--project-root',str(root),'--save-dir',str(profile),'--autoplay','story-skip' if route=='skip' else 'story-advance']
                with (OUT/('edited-'+route+'-'+str(starts)+'.log')).open('wb') as log:
                    process=subprocess.Popen(argv,cwd='/tmp',env=dict(os.environ,TLS_M2_EVIDENCE=str(rendezvous),TLS_M3B_RELOAD_LABEL=reload_label),stdout=log,stderr=log)
                    killed=False
                    try:
                        deadline=time.monotonic()+120
                        while process.poll() is None and time.monotonic()<deadline:
                            ready=next((p for p in sorted(rendezvous.glob('*.ready')) if not p.with_suffix('.release').exists()),None)
                            if ready:
                                name=ready.stem;stages.add(name)
                                if name in ('prologue','arrival','title_end'):capture('edited-'+route+'-'+name,process.pid)
                                if route=='restart' and name in ('prologue','cranking','arrival'):
                                    reload_label={'prologue':'intro','cranking':'crank','arrival':'farewell'}[name];process.kill();process.wait(timeout=5);killed=True
                                ready.with_suffix('.release').write_text('E4 synthetic input observed\n')
                                if killed:break
                            time.sleep(.02)
                        if not killed:process.wait(timeout=5);assert process.returncode==0
                    finally:
                        if process.poll() is None:process.kill();process.wait(timeout=5)
                        ROWS.append(dict(argv=argv,pid=process.pid,exit=process.returncode,intentional_sigkill=killed));record('demo-commands',ROWS)
                if not killed:break
            final=json.loads((profile/'chapter_01.json').read_text());assert final['checkpoint']=='complete' and final['puzzle']['phase']=='cleared'
            record('edited-'+route,dict(starts=starts,stages=sorted(stages),save=final,synthetic_input=True))
        assert hashes(root)==before;assert_isolation();record('journey-isolation',dict(authored_hashes_unchanged=True,normal_save_unchanged=True,override_unchanged=True,hashes=before))
    state();print('E4 disposable project ready',flush=True)
    try:
        deadline=time.monotonic()+2400
        while alive[0] and time.monotonic()<deadline:
            request=root/'demo-command.json'
            if not request.exists():time.sleep(.05);continue
            body=json.loads(request.read_text());request.unlink();action=body['action'];sequence+=1
            try:
                if action=='restart-bridge':client.close();client=Client(root);state();result={'new_port':client.server.server_port}
                elif action=='agent-dialogue':
                    before=client.inspect();line=before['authored']['order'][0]
                    # Use the exact public structured operation shape from the active CLI contract.
                    operation=dict(op='update_dialogue',id=line,text='E4 Studio: the flowers are ready.')
                    payload=dict(protocol_version=1,request_id='e4_agent_dialogue',chapter='oliver_flower_market',document='intro',expected_revision=before['graph_revision'],operations=[operation])
                    path=root/'agent-edit.json';path.write_text(json.dumps(payload));p=run([root/'build/tls-content','apply-edit','--project-root',root,'--request',path],cwd='/tmp');result=dict(cli=json.loads(p.stdout),after=client.inspect());record('structured-agent-dialogue',result)
                elif action=='native-apply':
                    before=hashes(root);run(['odin','build','src','-define:DEV_TOOLS=true','-define:DEV_EDITOR_TEST_HOOKS=true','-define:M4_TEST_HOOKS=true','-out:'+str(binary)],cwd=root)
                    game=native.Game(root,home,binary,'e4-native-apply');game.cmd('enter-edit-mode');game.cmd('select-record',dict(collection='objects',id='crank_handle'))
                    assert game.state()['authored']['objects']['crank_handle']['position']==[1192,256]
                    game.cmd('set-property',dict(collection='objects',id='crank_handle',property='position',value=[1208,256]));capture('native-draft',game.p.pid)
                    assert hashes(root)==before;result=game.apply();capture('native-applied',game.p.pid);game.cmd('quit');game.stop();assert_isolation();record('native-apply',result)
                    assert client.api('inspect-scene')['result']['authored']['objects']['crank_handle']['position']==[1208,256]
                elif action=='capture-preview':
                    status=client.api('preview-status');assert status['running'];capture(body.get('name','workspace-preview'),status['pid']);result=status
                    if body.get('chapter'):
                        save=home/('Library/Caches/The Last Stop/preview/'+status['session']+'/chapter_01.json');assert json.loads(save.read_text())['checkpoint']=='chapter_start'
                    assert_isolation();record(body.get('name','workspace-preview'),result)
                elif action=='journeys':
                    artifact=client.bridge.workspace.artifact_path('build-dev')['artifact'];journeys(artifact);result={'routes':['advance','skip','restart']}
                elif action=='revert':
                    for id,doc in [('oliver_obstacle',original_scene),('intro',original_intro)]:
                        current=client.inspect(id);assert client.restore(current,doc)['exit_code']==0
                    result={'restored_scene_dialogue':True};record('revert',result)
                elif action=='release':
                    release=client.job('build-release');assert release['exit_code']==0;record('release-build',release)
                    client.close();client=None;shutil.rmtree(root/'.studio');assert not (root/'.studio').exists();before=hashes(root)
                    with (OUT/'release.log').open('wb') as log:
                        process=subprocess.Popen([release['artifact'],'--project-root',str(root),'--save-dir',str(root/'release-profile')],cwd='/tmp',stdout=log,stderr=log)
                        try:
                            capture('release-without-studio',process.pid);run([control,process.pid,'close']);process.wait(timeout=10);assert process.returncode==0
                        finally:
                            if process.poll() is None:process.kill();process.wait(timeout=5)
                    assert hashes(root)==before and not (root/'.studio').exists();assert_isolation();result=dict(editor_closed=True,studio_absent=True,authored_hashes_unchanged=True,exit=process.returncode,pid=process.pid);record('release-independence',result);alive[0]=False
                else:raise AssertionError('Unknown demo action '+action)
                record('demo-result',dict(sequence=sequence,action=action,ok=True,result=result));print('PASS',action,flush=True)
            except BaseException as error:
                record('demo-result',dict(sequence=sequence,action=action,ok=False,error=repr(error)));raise
    finally:
        if client:client.close()
        for game in native.CHILDREN:game.stop()
        assert_isolation();record('demo-cleanup',dict(root=str(root),coordinator_pid=os.getpid(),native_pids=[g.p.pid for g in native.CHILDREN],all_owned_games_stopped=all(g.p.poll() is not None for g in native.CHILDREN),normal_save_unchanged=True))

if __name__=='__main__':main()
