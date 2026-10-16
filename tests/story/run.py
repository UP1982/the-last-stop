#!/usr/bin/env python3
"""M3a window-free acceptance; all edits use disposable project copies."""
import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
CLI = ROOT/'build/tls-content'
RUNTIME = ROOT/'build/m3a-runtime-test'
CHAPTER = 'data/chapters/chapter_01.json'
ROLES = ['intro','travel','obstacle','return','arrival','end_card']
PAIRS = [('board_oliver','train_travel'),('enter_obstacle','obstacle_arrival'),('begin_puzzle','puzzle'),('enter_arrival','station_outro'),('finish_oliver_journey','chapter_complete'),('show_title','title')]
# Independent screenplay ledger, including punctuation and the split call.
LEDGER = [
 ('prologue_rin_01','rin','First day on this line?'),
 ('prologue_rin_02','rin','Brass knows the way. You look after the passengers.'),
 ('prologue_rin_03','rin','The Last Stop. We used to have supper there when the lamps came on.'),
 ('prologue_rin_04','rin',"I thought I'd mend a few things. See who turns up."),
 ('prologue_rin_05','rin',"That's a start."),
 ('intro_call_01','oliver','Excuse me!'),
 ('intro_01','oliver','Does this one go to Clover Market?'),
 ('intro_02','oliver','Oh, good. My flowers are beginning to think I made it up.'),
 ('travel_01','oliver',"They've been on the kitchen table all week. I thought they might enjoy meeting other flowers."),
 ('obstacle_01','oliver','I can hold the flowers.'),
 ('obstacle_02','oliver',"I've had practice."),
 ('arrival_01','oliver',"I was worried they wouldn't bloom in time."),
 ('arrival_02','oliver','I suppose they just needed a little trip.'),
 ('arrival_03','oliver','For your window.'),
 ('arrival_04','oliver',"Oh. I'll take some flowers back for that. It's a lovely walk from here."),
]

def encode(x):return (json.dumps(x,ensure_ascii=False,indent=2,sort_keys=True)+'\n').encode()

class StoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='m3a-',dir=str(ROOT/'build'))
        self.root=Path(self.tmp.name)
        shutil.copytree(ROOT/'data',self.root/'data')
        shutil.copytree(ROOT/'assets',self.root/'assets')
        self.chapter=self.read(CHAPTER)
        self.paths={r:self.chapter['dialogues'][r]['path'] for r in ROLES}

    def tearDown(self):self.tmp.cleanup()
    def read(self,p):return json.loads((self.root/p).read_bytes())
    def write(self,p,x):(self.root/p).write_bytes(encode(x))
    def disk(self):return {str(p.relative_to(self.root)):p.read_bytes() for p in (self.root/'data').rglob('*') if p.is_file()}
    def invoke(self,command='validate-content',extra=(),expected=0):
        p=subprocess.run([str(CLI),command,'--project-root',str(self.root),*extra],capture_output=True,timeout=30)
        body=json.loads(p.stdout)
        self.assertEqual(p.returncode,expected,(p.stderr,body))
        return body
    def revision(self):return self.invoke()['graph_revision']
    def apply(self,document,ops,expected=0,revision=None):
        req=dict(protocol_version=1,request_id='story_test',chapter=self.chapter['id'],document=document,expected_revision=revision or self.revision(),operations=ops)
        (self.root/'request.json').write_bytes(encode(req))
        return self.invoke('apply-edit',['--request',str(self.root/'request.json')],expected)
    def invalid(self,path,mutation,code=None):
        old=(self.root/path).read_bytes();value=json.loads(old)
        mutation(value);self.write(path,value);before=self.disk()
        try:
            body=self.invoke(expected=2)
            self.assertTrue(body['diagnostics'])
            if code:self.assertIn(code,[d['code'] for d in body['diagnostics']],body)
            self.assertEqual(before,self.disk())
        finally:(self.root/path).write_bytes(old)
    def runtime(self):
        p=subprocess.run([str(RUNTIME),'--project-root',str(self.root)],cwd='/tmp',capture_output=True,timeout=30)
        self.assertEqual(p.returncode,0,p.stderr)
        return json.loads(p.stdout)

    def test_01_exact_screenplay_ledger_and_staging(self):
        actual=[];beat_ids=set()
        for role,pair in zip(ROLES,PAIRS):
            d=self.read(self.paths[role])
            self.assertEqual(d['schema_version'],2)
            self.assertEqual(d['completion'],dict(zip(['action','destination'],pair)))
            self.assertEqual(set(d['order']),set(d['lines']))
            self.assertEqual(set(d['beat_order']),set(d['beats']))
            self.assertEqual(len(d['beat_order']),len(set(d['beat_order'])))
            self.assertFalse(beat_ids.intersection(d['beats']));beat_ids.update(d['beats'])
            self.assertEqual([d['beats'][i]['line'] for i in d['beat_order'] if d['beats'][i]['kind']=='line'],d['order'])
            actual.extend((i,d['lines'][i]['speaker'],d['lines'][i]['text']) for i in d['order'])
            for b in d['beats'].values():
                # No imported sprite IDs means an intentional placeholder.
                for a in b['stage']['actors'].values():self.assertNotIn('asset',a)
                self.assertFalse(any(x['kind'] in ('branch','winch','rope') for x in b['stage']['props'].values()))
        self.assertEqual(actual,LEDGER)
        self.assertEqual(self.read(self.paths['intro'])['lines']['intro_call_01']['delivery'],'offscreen')
        screenplay=(ROOT/'docs/THE_LAST_STOP_SCREENPLAY.fountain').read_text().split('# Chapter Two')[0]
        for _,_,text in LEDGER:self.assertIn(text,screenplay)
        travel=self.read(self.paths['travel'])
        for b in travel['beats'].values():
            if b['stage']['set']=='carriage':
                self.assertIn('carriage_supper_notice',b['stage']['props'])
        runtime=self.runtime()
        observed=[]
        for r in ROLES:observed.extend((x['id'],x['speaker'],x['text']) for x in runtime['dialogues'][self.chapter['dialogues'][r]['id']]['order'])
        self.assertEqual(observed,LEDGER)
        self.assertTrue(runtime['guarded_complete'])

    def test_02_invalid_order_and_identities(self):
        path=self.paths['intro'];base=self.read(path);first=base['beat_order'][0]
        cases=[
            (lambda d:d['beats'].pop(first),'beat_order'),
            (lambda d:d['beat_order'].append(first),'beat_order'),
            (lambda d:d['beat_order'].pop(0),'beat_order'),
            (lambda d:d['beats'].update(extra_beat=copy.deepcopy(d['beats'][first])),'beat_order'),
            (lambda d:d['beat_order'].reverse(),'line_beats'),
            (lambda d:d['beats']['intro_01_beat'].update(line='missing'),'line'),
            (lambda d:d['beats']['intro_01_beat'].update(line='intro_02'),'line_beats'),
            (lambda d:d['lines']['intro_01'].update(speaker='missing'),'speaker'),
            (lambda d:d.update(order=[]),'order'),
            (lambda d:(d.update(order=[],lines={}),d['beats'].update({i:dict(kind='stage',duration_ms=0,stage=b['stage']) for i,b in d['beats'].items()})),'lines'),
        ]
        for mutation,code in cases:
            with self.subTest(code=code):self.invalid(path,mutation,code)
        # Beat IDs are chapter-wide, independent of line IDs.
        travel=self.paths['travel']
        def duplicate(d):
            key=d['beat_order'][0];d['beats'][first]=d['beats'].pop(key);d['beat_order'][0]=first
        self.invalid(travel,duplicate,'duplicate_identity')
        self.invalid(path,lambda d:d['beats'][first]['stage']['props'].update(fallen_branch= dict(kind='sign',state='faded',position=[0,0])),'stage_identity')
        self.invalid(path,lambda d:d['beats'][first]['stage']['actors'].update(stranger=dict(feet=[0,0],facing='left',pose='idle',emote='neutral')),'speaker')

    def test_03_exactly_six_completion_pairs(self):
        for role,pair in zip(ROLES,PAIRS):
            for action in [p[0] for p in PAIRS]:
                for dest in [p[1] for p in PAIRS]:
                    if (action,dest)==pair:continue
                    with self.subTest(role=role,action=action,dest=dest):
                        self.invalid(self.paths[role],lambda d:d.update(completion=dict(action=action,destination=dest)),'completion')
        self.invalid(CHAPTER,lambda d:d['dialogues'].update(extra=copy.deepcopy(d['dialogues']['intro'])),'unknown_field')
        self.invalid(CHAPTER,lambda d:d['dialogues'].pop('travel'),'missing_field')
        self.invalid(CHAPTER,lambda d:d['dialogues'].update(travel=d['dialogues']['intro']),'duplicate_identity')

    def test_04_closed_stage_values_and_text(self):
        path=self.paths['intro'];key=self.read(path)['beat_order'][0]
        def change_stage(k,val):return lambda d:d['beats'][key]['stage'].update({k:val})
        for k,val in [('cue','execute'),('set','moon'),('shot','free_camera'),('shot','winch_branch'),('mutate_checkpoint','complete')]:
            self.invalid(path,change_stage(k,val))
        for field,value in [('pose','dance'),('emote','angry'),('facing','up'),('feet',[1.5,2]),('feet',[1,2,3]),('asset','absent'),('collision',[0,0,20,20])]:
            self.invalid(path,lambda d:d['beats'][key]['stage']['actors']['milo'].update({field:value}))
        for field,value in [('kind','branch'),('state','bloom'),('asset','missing'),('position',[0,None])]:
            self.invalid(path,lambda d:d['beats'][key]['stage']['props']['platform_train'].update({field:value}))
        for duration in [-1,5001,1.0,'500',None]:
            self.invalid(path,lambda d:d['beats'][key].update(duration_ms=duration),'number_range')
        for duration in (0,5000):
            old=self.read(path);new=copy.deepcopy(old);new['beats'][key]['duration_ms']=duration
            self.write(path,new);self.invoke();self.write(path,old)
        self.invalid(path,lambda d:d['beats']['intro_01_beat'].update(duration_ms=50),'unknown_field')
        self.invalid(path,lambda d:d['lines']['intro_01'].update(delivery='whisper'),'enum')
        for value in ['',None,12,'x'*4097,'   \n\t','hidden\x00text','hidden\x1btext']:
            self.invalid(path,lambda d:d['lines']['intro_01'].update(text=value))
            self.invalid(CHAPTER,lambda d:d['strings'].update(needs_handle=value))
        self.invalid(CHAPTER,lambda d:d['speakers']['rin'].update(name='Rin\x00hidden'),'text')
        self.invalid(CHAPTER,lambda d:d.update(title='\x1bhidden'),'text')
        self.invalid(CHAPTER,lambda d:d['strings'].pop('drop'),'missing_field')
        self.invalid(CHAPTER,lambda d:d['strings'].update(extra='not allowed'),'unknown_field')
        self.invalid(self.paths['end_card'],lambda d:d['beats']['ending_text_card'].update(string='clear'),'enum')

    def test_05_v2_restore_edit_round_trip_and_guard(self):
        intro=self.read(self.paths['intro']);original=copy.deepcopy(intro)
        body=self.apply('intro',[dict(op='update_dialogue',id='intro_01',text='A café — 猫…')])
        self.assertEqual(body['commit_state'],'committed')
        after=self.read(self.paths['intro']);self.assertEqual(after['beat_order'],original['beat_order'])
        self.assertEqual(after['order'],original['order'])
        self.assertEqual(self.runtime()['dialogues']['intro']['order'][6]['text'],'A café — 猫…')
        # Restoring the whole snapshot permits intentional coherent restructuring.
        after['order'][0:2]=reversed(after['order'][0:2])
        a,b=after['beat_order'].index('prologue_rin_01_beat'),after['beat_order'].index('prologue_rin_02_beat')
        after['beat_order'][a],after['beat_order'][b]=after['beat_order'][b],after['beat_order'][a]
        self.apply('intro',[dict(op='restore_document',value=after)])
        before=(self.root/self.paths['intro']).read_bytes()
        self.apply('intro',[dict(op='restore_document',value=after)])
        self.assertEqual(before,(self.root/self.paths['intro']).read_bytes())
        for doc in [after,self.chapter]:
            target=doc['id'];before=self.disk()
            result=self.apply(target,[dict(op='restore_document',value=dict(doc,schema_version=1))],2)
            self.assertEqual(result['diagnostics'][0]['code'],'identity');self.assertEqual(before,self.disk())
        old_revision=self.revision()
        self.apply('intro',[dict(op='restore_document',value=original)])
        before=self.disk();self.apply('intro',[dict(op='restore_document',value=after)],3,old_revision);self.assertEqual(before,self.disk())
        # A valid first operation plus unsafe order change is one rejected batch.
        for op in [dict(op='set_order',order=list(reversed(original['order']))),dict(op='create',collection='lines',id='new_line',value=dict(speaker='rin',text='Hi')),dict(op='delete',collection='lines',id='intro_01')]:
            before=self.disk();body=self.apply('intro',[dict(op='update_dialogue',id='intro_01',text='must not persist'),op],2)
            self.assertEqual(body['diagnostics'][0]['code'],'beat_edit_required');self.assertEqual(before,self.disk())
        self.apply('intro',[dict(op='set_order',order=original['order'])])
        # Schema/version guard is unchanged for v2 chapter restore too.
        chapter=copy.deepcopy(self.chapter);chapter['strings']['needs_handle']='Changed through chapter restore.'
        self.apply(chapter['id'],[dict(op='restore_document',value=chapter)])
        self.assertEqual(self.runtime()['responses'][0],'Changed through chapter restore.')

    def test_06_runtime_strings_and_v1_in_memory_adapter(self):
        expected=['needs_handle','find_hint_gentle','find_hint_shelter','find_hint']
        base=self.runtime();self.assertEqual(base['responses'],[self.chapter['strings'][k] for k in expected])
        for key in expected:self.chapter['strings'][key]='Edited '+key+' — café…'
        self.write(CHAPTER,self.chapter);before=self.disk()
        self.assertEqual(self.runtime()['responses'],[self.chapter['strings'][k] for k in expected]);self.assertEqual(before,self.disk())
        # V1 remains readable to the content tool; gameplay explicitly requires
        # migration and is covered by runtime.py's startup/no-save regression.
        for name,path in [('chapter_01.json',CHAPTER),('oliver_intro.json',self.paths['intro']),('oliver_arrival.json',self.paths['arrival'])]:
            shutil.copyfile(ROOT/'tests/story/fixtures/v1'/name,self.root/path)
        before=self.disk();self.invoke()
        for document,path in [('oliver_flower_market',CHAPTER),('intro',self.paths['intro']),('arrival',self.paths['arrival'])]:
            doc=self.invoke('inspect-document',['--document',document])['authored']
            self.assertEqual(doc,self.read(path));self.assertEqual(doc['schema_version'],1)
        self.assertEqual(before,self.disk())

    def test_07_inspect_schema_generation_determinism_and_legacy(self):
        revision=self.revision()
        for role in ROLES:
            ref=self.chapter['dialogues'][role]
            body=self.invoke('inspect-document',['--document',ref['id']])
            self.assertEqual(body['authored'],self.read(ref['path']));self.assertEqual(body['graph_revision'],revision)
        self.invoke('inspect-document',['--document',self.chapter['id']])
        schemas={str(p):p.read_bytes() for p in (ROOT/'data/schemas').glob('*.json')}
        subprocess.run(['python3',str(ROOT/'tools/generate_story_schemas.py')],check=True)
        self.assertEqual(schemas,{str(p):p.read_bytes() for p in (ROOT/'data/schemas').glob('*.json')})
        self.assertEqual(hashlib.sha256((ROOT/'data/legacy/chapter_01.v0.json').read_bytes()).hexdigest(),hashlib.sha256(subprocess.check_output(['git','show','HEAD:data/legacy/chapter_01.v0.json'],cwd=ROOT)).hexdigest())
        scene=self.invoke('inspect-scene',['--scene','oliver_obstacle'])
        self.assertEqual(scene['authored']['schema_version'],2)

    def test_08_closed_single_line_ui_budgets(self):
        budgets={'advance':14,'skip_scene':10,'return_menu':14,
                 **dict.fromkeys(('pickup','drop','install','activate','inspect_winch',
                                  'inspect_branch','return_train','wave','turning','clear'),26)}
        self.invalid(CHAPTER,lambda d:d['strings'].update(advance='Continue through this quiet station scene whenever you are ready.'),'ui_text_budget')
        for key,limit in budgets.items():
            with self.subTest(key=key):
                self.invalid(CHAPTER,lambda d:d['strings'].update({key:'W'*(limit+1)}),'ui_text_budget')
                for control in ('\n','\t','\r'):
                    self.invalid(CHAPTER,lambda d:d['strings'].update({key:'a'+control+'b'}),'ui_text_layout')
                for character in ('W','Æ','é','猫'):
                    chapter=copy.deepcopy(self.chapter);chapter['strings'][key]=character*limit
                    self.write(CHAPTER,chapter);self.invoke()
                self.write(CHAPTER,self.chapter)
        self.invalid(CHAPTER,lambda d:d['speakers']['rin'].update(name='W'*21),'ui_text_budget')
        self.invalid(CHAPTER,lambda d:d['speakers']['rin'].update(name='Rin\nCat'),'ui_text_layout')
        chapter=copy.deepcopy(self.chapter);chapter['speakers']['rin']['name']='Æ'*20
        self.write(CHAPTER,chapter);self.invoke()

if __name__=='__main__':
    subprocess.run(['odin','build','tools/content','-out:'+str(CLI)],cwd=ROOT,check=True)
    subprocess.run(['odin','build','src','-define:M3A_SELF_TEST=true','-out:'+str(RUNTIME)],cwd=ROOT,check=True)
    unittest.main(verbosity=2)
