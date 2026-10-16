#!/usr/bin/env python3
"""E4 evidence runner: explicit exit codes, temp HOME, serialized native suites."""
import argparse, json, os, subprocess, tempfile, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/evidence/e4';OUT.mkdir(parents=True,exist_ok=True)
p=argparse.ArgumentParser();p.add_argument('--python',default='python3');p.add_argument('--resume-from');args=p.parse_args()
tmp=Path(tempfile.mkdtemp(prefix='tls-e4-verification-',dir='/tmp'));(tmp/'home').mkdir();(tmp/'tmp').mkdir()
env=dict(os.environ,HOME=str(tmp/'home'),TMPDIR=str(tmp/'tmp'));env.pop('TLS_SAVE_DIR',None)
commands=[('odin-check',['odin','check','src']),('odin-check-dev',['odin','check','src','-define:DEV_TOOLS=true']),('release-build',['odin','build','src','-out:build/the-last-stop-e4-release']),('dev-build',['odin','build','src','-define:DEV_TOOLS=true','-out:build/the-last-stop-e4-dev']),('check-final',['./scripts/check.sh']),('schema',[args.python,'-B','tests/story/schema_check.py']),('typography',['python3','-B','tests/story/typography.py']),('resilience-full',[args.python,'-B','tests/resilience/run.py','--disk-full']),('dev-editor-native',['python3','-B','tests/dev_editor/native.py']),('workspace-native',['python3','-B','tests/editor_workspace/native_demo.py','--journeys']),('m2-native',[args.python,'-B','tests/runtime/m2_native.py']),('story-native',[args.python,'-B','tests/story/native.py']),('assets-native',[args.python,'-B','tests/assets/native.py']),('resilience-native',[args.python,'-B','tests/resilience/native.py'])]
if args.resume_from:
    names=[name for name,_ in commands]
    if args.resume_from not in names:p.error('Unknown verification step')
    commands=commands[names.index(args.resume_from):]
rows=[]
for name,argv in commands:
    started=time.time();print('START',name,flush=True)
    with (OUT/(name+'.log')).open('wb') as log:
        child=subprocess.Popen(argv,cwd=ROOT,env=env,stdout=log,stderr=log)
        try:exit_code=child.wait(timeout=1800)
        except BaseException:
            child.kill();child.wait(timeout=10);raise
    rows.append(dict(name=name,argv=argv,pid=child.pid,exit=exit_code,seconds=round(time.time()-started,3),home=env['HOME'],log=str(OUT/(name+'.log'))))
    (OUT/('verification-resume.json' if args.resume_from else 'verification.json')).write_text(json.dumps(dict(temp_root=str(tmp),rows=rows),indent=2)+'\n')
    print('EXIT',name,exit_code,flush=True)
    if exit_code:raise SystemExit(exit_code)
print('PASS all maintained compile/headless/native suites',flush=True)
