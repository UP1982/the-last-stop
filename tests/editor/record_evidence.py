#!/usr/bin/env python3
"""Record E0a acceptance checks and a reversible live edit in the real project.
Run only while managed writers are idle. Leaves history and restores scene via CLI.
"""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/evidence/e0a'
CLI=ROOT/'build/tls-content'
SCENE='data/scenes/oliver_obstacle.json'
OUT.mkdir(parents=True,exist_ok=True)
transcript=[]

def run(name,args,expected=0):
    p=subprocess.run(args,cwd=ROOT,capture_output=True,timeout=120)
    (OUT/(name+'.stdout.txt')).write_bytes(p.stdout)
    (OUT/(name+'.stderr.txt')).write_bytes(p.stderr)
    meta={'argv':list(map(str,args)),'exit_code':p.returncode,'expected':expected}
    (OUT/(name+'.command.json')).write_text(json.dumps(meta,indent=2)+'\n')
    transcript.append('$ '+' '.join(map(str,args))+'\n'+p.stdout.decode(errors='replace')+p.stderr.decode(errors='replace')+'\nexit '+str(p.returncode)+'\n')
    if p.returncode!=expected:
        (OUT/'transcript.txt').write_text('\n'.join(transcript))
        raise RuntimeError(name+' failed: '+str(p.returncode))
    return p

def cli(name,command,request=None,expected=0):
    args=[str(CLI),command,'--project-root',str(ROOT)]
    if command=='inspect-scene':args+=['--scene','oliver_obstacle']
    if request is not None:
        path=OUT/(name+'.request.json')
        path.write_bytes(request if isinstance(request,bytes) else (json.dumps(request,ensure_ascii=False,indent=2)+'\n').encode())
        args+=['--request',str(path)]
    return json.loads(run(name,args,expected).stdout)

def hashes():
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/'data').rglob('*')) if p.is_file()}

run('01-check-src',['odin','check','src'])
run('02-check-content',['odin','check','shared/content'])
run('03-build-cli',['odin','build','tools/content','-out:build/tls-content'])
run('04-allocation',['odin','run','tests/editor','-out:build/e0-allocation','--','.'])
run('05-behavior',['python3','-B','tests/editor/run.py'])
run('06-m0-regression',['odin','run','src','-define:M0_SELF_TEST=true','-out:build/selftest-e0a'])
initial_hashes=hashes()
scene_before=(ROOT/SCENE).read_bytes(); (OUT/'scene.before.json').write_bytes(scene_before)
valid=cli('07-validate','validate-content')
cli('08-inspect','inspect-scene')
request=json.loads((ROOT/'tests/editor/fixtures/move-handle.json').read_bytes())
request['expected_revision']=valid['graph_revision']
try:
    moved=cli('09-apply-move','apply-edit',request)
    assert moved['commit_state']=='committed'
    scene_after=(ROOT/SCENE).read_bytes(); (OUT/'scene.after.json').write_bytes(scene_after)
    (OUT/'scene.move.diff').write_text(''.join(difflib.unified_diff(scene_before.decode().splitlines(True),scene_after.decode().splitlines(True),fromfile=SCENE+' before',tofile=SCENE+' after')))
    before_reject=hashes()
    stale=cli('10-stale','apply-edit',request,3)
    assert stale['commit_state']=='not_committed' and hashes()==before_reject
    malformed=cli('11-malformed','apply-edit',(ROOT/'tests/editor/fixtures/trailing-comma.json').read_bytes(),2)
    assert malformed['commit_state']=='not_committed'
    after_reject=hashes()
    assert after_reject==before_reject
    (OUT/'rejection-byte-evidence.json').write_text(json.dumps({'before':before_reject,'after':after_reject,'all_data_bytes_identical':before_reject==after_reject},indent=2)+'\n')
    (OUT/'rejection.diff').write_text(''.join(difflib.unified_diff(json.dumps(before_reject,indent=2).splitlines(True),json.dumps(after_reject,indent=2).splitlines(True))))
    cli('12-inspect-moved','inspect-scene')
finally:
    current=cli('13-current-revision','validate-content')
    if (ROOT/SCENE).read_bytes()!=scene_before:
        restore=dict(request,request_id='restore_demo',expected_revision=current['graph_revision'],operations=[{'op':'restore_document','value':json.loads(scene_before)}])
        cli('14-restore-demo','apply-edit',restore)
final=cli('15-final-validate','validate-content')
assert hashes()==initial_hashes,'Live demo must leave all migrated content byte-identical to its initial state'
assert final['graph_revision']==valid['graph_revision']
(OUT/'restoration-byte-evidence.json').write_text(json.dumps({'before':initial_hashes,'after':hashes(),'all_data_bytes_identical':True},indent=2)+'\n')
run('16-src-unchanged',['git','diff','--exit-code','66eab13','--','src'])
run('17-no-staged-changes',['git','diff','--cached','--exit-code'])
(OUT/'transcript.txt').write_text('\n'.join(transcript))
print('PASS acceptance checks and live CLI demo; all authored data restored byte-identically. Evidence:',OUT)
