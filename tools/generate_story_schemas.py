#!/usr/bin/env python3
"""Regenerate the bounded chapter/dialogue-v2 schemas and edit restore union."""
import copy
import json
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'data/schemas'
def write(name, value):
    (OUT/name).write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True)+'\n')
def obj(properties, required=None):
    return dict(type='object', additionalProperties=False, properties=properties,
                required=list(properties) if required is None else required)
def enum(values): return {'enum': values.split('|')}
def const(value): return {'const': value}
def bounded(lo, hi):return dict(type='integer', minimum=lo, maximum=hi)
def array(item, minimum=0):return dict(type='array',items=item,minItems=minimum,maxItems=1024,uniqueItems=True)
def mapping(value):return dict(type='object', propertyNames=ID, additionalProperties=value,maxProperties=1024)
source=(ROOT/'shared/content/story.odin').read_text()
constants=dict(re.findall(r'^(\w+) :: "([^"]+)"',source,re.M))
ID=dict(type='string',pattern='^[a-z][a-z0-9_]{0,63}$')
TEXT=dict(type='string',minLength=1,maxLength=4096,pattern=r'[^ \t\r\n]',allOf=[{'not':{'pattern':r'[\x00-\x08\x0b-\x1f\x7f]'}}])
VEC=dict(type='array',minItems=2,maxItems=2,prefixItems=[bounded(-16384,16384)]*2,items=False)
actor=obj(dict(feet=VEC,facing=enum('left|right'),pose=enum(constants['POSES']),emote=enum(constants['EMOTES']),asset=ID),['feet','facing','pose','emote'])
states={'train':'waiting|moving|stopped','door':'open|closed','bag':'ear_caught|free|aboard','flowerpot':'bud|bloom','paper_flower':'paper|folding|folded|spring','slat':'loose|slipping|caught|resting','bench':'unrepaired|supported','timetable':'unhelpful','sign':'faded','notice':'supper','market_dressing':'open'}
prop={'oneOf':[obj(dict(kind=const(kind),position=VEC,state=enum(state),asset=ID),['kind','position','state']) for kind,state in states.items()]}
shots={'willow_platform':'wide|passenger_pair|old_platform','carriage':'wide|passenger_pair|flower|supper_card','forest_travel':'wide','forest_obstacle':'wide|passenger_pair|winch_branch','market_platform':'wide|passenger_pair|flower|supper_card','flower_window':'flower'}
stage=obj(dict(set=enum(constants['SETS']),shot=enum(constants['SHOTS']),actors=mapping(actor),props=mapping(prop),cue=enum(constants['CUES'])))
stage['allOf']=[{'if':{'properties':{'set':const(s)}},'then':{'properties':{'shot':enum(sh)}}} for s,sh in shots.items()]
# Cross-document speaker/asset resolution and equality of projected line order
# are authoritative graph checks (JSON Schema cannot express these references).
beats={'oneOf':[obj(dict(kind=const('line'),line=ID,stage=stage)),obj(dict(kind=const('stage'),duration_ms=bounded(0,5000),stage=stage)),obj(dict(kind=const('card'),string=enum(constants['CARD_KEYS']),stage=stage))]}
pairs=[('board_oliver','train_travel'),('enter_obstacle','obstacle_arrival'),('begin_puzzle','puzzle'),('enter_arrival','station_outro'),('finish_oliver_journey','chapter_complete'),('show_title','title')]
completion={'oneOf':[obj(dict(action=const(a),destination=const(d))) for a,d in pairs]}
dialogue=obj(dict(kind=const('dialogue'),schema_version=dict(type='integer',const=2),id=ID,lines=mapping(obj(dict(speaker=ID,text=TEXT,delivery=enum('onscreen|offscreen')),['speaker','text'])),order=array(ID),beats=mapping(beats),beat_order=array(ID,1),completion=completion))
dialogue['allOf']=[{'if':{'properties':{'completion':{'properties':{'action':{'enum':[a for a,_ in pairs if a not in ('enter_arrival','show_title')]}}}}},'then':{'properties':{'order':{'minItems':1},'lines':{'minProperties':1}}}}]
chapter=json.loads((OUT/'chapter.v1.schema.json').read_text());chapter.pop('$id',None)
chapter['properties']['schema_version']['const']=2
for field in ('title','destination'):chapter['properties'][field]=TEXT
for field in ('name','species'):chapter['properties']['speakers']['additionalProperties']['properties'][field]=TEXT
chapter['properties']['keepsakes']['additionalProperties']['properties']['name']=TEXT
ref=copy.deepcopy(chapter['properties']['dialogues']['properties']['intro'])
chapter['properties']['dialogues']=obj({role:copy.deepcopy(ref) for role in constants['STORY_ROLES'].split('|')})
chapter['properties']['strings']=obj({key:TEXT for key in constants['STRING_KEYS'].split('|')});chapter['required'].append('strings')
for name,value in [('chapter',chapter),('dialogue',dialogue)]:
 value['$schema']='https://json-schema.org/draft/2020-12/schema';value['$id']=f'{name}.v2.schema.json'
 value['$comment']='Integer bounds and structure are mirrored by shared/content. Cross-document identities, references, and ordered line-beat projection are checked by the Odin graph validator. Text is bounded to 4096 UTF-8 bytes there.'
 write(name+'.v2.schema.json',value)
edit=json.loads((OUT/'edit.v1.schema.json').read_text())
restore=next(x for x in edit['properties']['operations']['items']['oneOf'] if x['properties']['op'].get('const')=='restore_document')
union=restore['properties']['value']['oneOf']
union[:]=[x for x in union if not (x['properties']['kind'].get('const') in ('chapter','dialogue') and x['properties']['schema_version'].get('const')==2)]
for schema in (chapter,dialogue):
 embedded=copy.deepcopy(schema)
 for k in ('$schema','$id'):embedded.pop(k,None)
 union.append(embedded)
write('edit.v1.schema.json',edit)
