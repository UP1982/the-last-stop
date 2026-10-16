#!/usr/bin/env python3
"""Apply only batch-1 asset refs through real, revision-checked single-doc edits.
Receipts/requests are kept under build/evidence/art3/content-transactions/.
"""
import copy
import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/evidence/art3/content-transactions'
CLI=ROOT/'build/tls-content'
ACTORS={'milo':'milo_idle_r','oliver':'oliver_idle_r','rin':'rin_idle_r'}

def invoke(*args):
    p=subprocess.run([str(CLI),*args,'--project-root',str(ROOT)],capture_output=True,check=True)
    return json.loads(p.stdout)

def apply(doc,ops):
    before=invoke('validate-content')
    req=dict(protocol_version=1,request_id='art3_'+doc,chapter=before['chapter'],document=doc,
             expected_revision=before['graph_revision'],operations=ops)
    path=OUT/(doc+'.request.json');path.write_text(json.dumps(req,indent=2)+'\n')
    result=invoke('apply-edit','--request',str(path))
    (OUT/(doc+'.receipt.json')).write_text(json.dumps(result,indent=2)+'\n')
    assert result['commit_state']=='committed',result

if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    scene=invoke('inspect-scene','--scene','oliver_obstacle')['authored']
    if scene['objects']['brass'].get('asset')!='brass_locomotive':
        apply(scene['id'],[dict(op='set_property',collection='objects',id='brass',property='asset',value='brass_locomotive')])
    for path in sorted((ROOT/'data/dialogue').glob('*.json')):
        source=json.loads(path.read_text());doc=copy.deepcopy(source)
        for beat in doc['beats'].values():
            for key,actor in beat['stage']['actors'].items():
                if key in ACTORS: actor['asset']=ACTORS[key]
            for prop in beat['stage']['props'].values():
                if prop['kind']=='train': prop['asset']='brass_locomotive'
        if doc!=source:
            apply(doc['id'],[dict(op='restore_document',value=doc)])
    print('PASS batch-1 refs authored by CLI; one document per transaction')
