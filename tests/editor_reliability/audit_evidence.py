#!/usr/bin/env python3
"""Collate only this verification's fresh window captures and machine summaries."""
import json, shutil, struct, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/evidence/e4'
# The first E4 capture is earlier than the native regression run, so include it.
cutoff=(OUT/'demo-state.json').stat().st_mtime-120
rows=[];removed=[]
for name in ('e4','e2','e3','m2','m3b','m4','art3'):
    folder=ROOT/'build/evidence'/name
    for path in folder.glob('*.png'):
        if path.stat().st_mtime<cutoff:continue
        metadata=next((p for p in (path.with_name(path.stem+'-window.json'),path.with_suffix('.window.json')) if p.exists()),None)
        try:
            assert metadata is not None,'missing window identity'
            value=json.loads(metadata.read_text());window=value.get('before',value)
            assert window['kCGWindowName']=='The Last Stop' and window['kCGWindowLayer']==0
            assert int(window['kCGWindowOwnerPID'])>0 and int(window['kCGWindowNumber'])>0
            png=path.read_bytes();assert png[:8]==b'\x89PNG\r\n\x1a\n';width,height=struct.unpack('>II',png[16:24]);b=window['kCGWindowBounds']
            assert any(abs(int(b['Width'])*s-width)<=4*s and abs(int(b['Height'])*s-height)<=4*s for s in (1,2)),((width,height),b)
            rows.append(dict(path=str(path),identity=str(metadata),pid=window['kCGWindowOwnerPID'],window_id=window['kCGWindowNumber'],width=width,height=height))
            if name!='e4':
                destination=OUT/'regression'/name;destination.mkdir(parents=True,exist_ok=True)
                shutil.copy2(path,destination/path.name);shutil.copy2(metadata,destination/metadata.name)
        except BaseException as error:
            removed.append(dict(path=str(path),reason=repr(error)));path.unlink(missing_ok=True)
    if name!='e4':
        destination=OUT/'regression'/name;destination.mkdir(parents=True,exist_ok=True)
        for path in folder.glob('*.json'):
            if path.stat().st_mtime>=cutoff:shutil.copy2(path,destination/path.name)
report=dict(cutoff_unix=cutoff,verified=rows,deleted_invalid=removed,all_captures_game_windows=not removed)
(OUT/'window-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print('Window audit:',len(rows),'verified;',len(removed),'invalid captures deleted')
