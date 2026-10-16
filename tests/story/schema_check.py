#!/usr/bin/env python3
"""Independent Draft 2020-12 structural validation (requires jsonschema)."""
import copy
import json
from pathlib import Path
import unittest
from jsonschema import Draft202012Validator

ROOT=Path(__file__).resolve().parents[2]
SCHEMAS=ROOT/'data/schemas'

class SchemaTests(unittest.TestCase):
    def validator(self,name):
        schema=json.loads((SCHEMAS/name).read_text());Draft202012Validator.check_schema(schema)
        return Draft202012Validator(schema)

    def test_v2_roundtrip_and_restore_union(self):
        chapter=json.loads((ROOT/'data/chapters/chapter_01.json').read_text())
        values=[chapter]+[json.loads((ROOT/ref['path']).read_text()) for ref in chapter['dialogues'].values()]
        edit=self.validator('edit.v1.schema.json')
        for value in values:
            v=self.validator(value['kind']+'.v2.schema.json')
            v.validate(value)
            v.validate(json.loads(json.dumps(value,ensure_ascii=False,sort_keys=True)))
            request=dict(protocol_version=1,request_id='schema_check',chapter=chapter['id'],document=value['id'],expected_revision='sha256:'+'0'*64,operations=[dict(op='restore_document',value=value)])
            edit.validate(request)
            bad=copy.deepcopy(value);bad['schema_version']=3
            self.assertTrue(list(v.iter_errors(bad)))
            bad=copy.deepcopy(value);bad['extra']=True
            self.assertTrue(list(v.iter_errors(bad)))

    def test_stage_constraints_and_empty_roles(self):
        value=json.loads((ROOT/'data/dialogue/oliver_intro.json').read_text())
        v=self.validator('dialogue.v2.schema.json');key=value['beat_order'][0]
        for field,data in [('duration_ms',-1),('duration_ms',5001),('duration_ms',None)]:
            bad=copy.deepcopy(value);bad['beats'][key][field]=data;self.assertTrue(list(v.iter_errors(bad)))
        for field,data in [('cue','exec'),('shot','winch_branch'),('set','moon')]:
            bad=copy.deepcopy(value);bad['beats'][key]['stage'][field]=data;self.assertTrue(list(v.iter_errors(bad)))
        for text in ['','\x00hidden','   \n\t',123,None]:
            bad=copy.deepcopy(value);bad['lines']['intro_01']['text']=text;self.assertTrue(list(v.iter_errors(bad)))
        bad=copy.deepcopy(value);bad['lines']={};bad['order']=[];self.assertTrue(list(v.iter_errors(bad)))
        for filename in ('oliver_return','oliver_end_card'):
            d=json.loads((ROOT/('data/dialogue/'+filename+'.json')).read_text());v.validate(d)
        # Original schemas continue to describe the frozen compatible inputs.
        self.validator('chapter.v1.schema.json').validate(json.loads((ROOT/'tests/story/fixtures/v1/chapter_01.json').read_text()))
        for file in ('oliver_intro','oliver_arrival'):
            self.validator('dialogue.v1.schema.json').validate(json.loads((ROOT/('tests/story/fixtures/v1/'+file+'.json')).read_text()))

    def test_ui_budgets_match_runtime_and_restore_union(self):
        chapter=json.loads((ROOT/'data/chapters/chapter_01.json').read_text())
        schema=self.validator('chapter.v2.schema.json')
        edit=self.validator('edit.v1.schema.json')
        budgets={'advance':14,'skip_scene':10,'return_menu':14,
                 **dict.fromkeys(('pickup','drop','install','activate','inspect_winch',
                                  'inspect_branch','return_train','wave','turning','clear'),26)}
        limited={k:v['maxLength'] for k,v in schema.schema['properties']['strings']['properties'].items() if v['maxLength']<4096}
        self.assertEqual(limited,budgets)
        def request(value):
            return dict(protocol_version=1,request_id='ui_budget',chapter=chapter['id'],document=chapter['id'],expected_revision='sha256:'+'0'*64,operations=[dict(op='restore_document',value=value)])
        for key,limit in budgets.items():
            for text in ('Æ'*limit,'猫'*limit):
                value=copy.deepcopy(chapter);value['strings'][key]=text
                schema.validate(value);edit.validate(request(value))
            for text in ('W'*(limit+1),'a\nb','a\tb','a\rb'):
                value=copy.deepcopy(chapter);value['strings'][key]=text
                self.assertTrue(list(schema.iter_errors(value)))
                self.assertTrue(list(edit.iter_errors(request(value))))
        for length in (20,21):
            value=copy.deepcopy(chapter);value['speakers']['rin']['name']='Æ'*length
            self.assertEqual(bool(list(schema.iter_errors(value))),length==21)
            self.assertEqual(bool(list(edit.iter_errors(request(value)))),length==21)

if __name__=='__main__':unittest.main(verbosity=2)
