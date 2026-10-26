#!/usr/bin/env python3
from pathlib import Path
import zlib, hashlib, json, re, base64
root=Path(__file__).resolve().parents[1]
system=root/'system'
logical={}
for p in sorted(system.rglob('*')):
 if not p.is_file():continue
 relative=p.relative_to(system).as_posix()
 if relative.endswith('.b64'):
  name=relative[:-4]
  data=base64.b64decode(p.read_bytes(),validate=True)
  if name in logical:assert logical[name]==data,'Conflicting binary transport: '+name
  logical[name]=data
 else:
  data=p.read_bytes()
  if relative in logical:assert logical[relative]==data,'Conflicting binary transport: '+relative
  logical[relative]=data
upstream={}
for match in re.finditer(r'\{\s*path\s*=\s*"([^"]+)"([^{}]*?)\}',(root/'tools/MineOS-Files.cfg').read_text(),re.S):
 item_id=re.search(r'\bid\s*=\s*(\d+)',match[2]);version=re.search(r'\bversion\s*=\s*(\d+)',match[2])
 if item_id:upstream[match[1]]=(int(item_id[1]),int(version[1]) if version else 1)
sourceConfig=json.loads((root/'tools/MineOS-source.json').read_text())
entries=[]
for relative,data in sorted(logical.items()):
 extra=''
 try:data.decode('utf8');binary=False
 except UnicodeDecodeError:binary=True
 officialPath=sourceConfig['files'].get(relative)
 if officialPath:
  extra=',source="mineos"'
  if officialPath!=relative:extra+=',upstreamPath='+json.dumps(officialPath,ensure_ascii=False)
 elif binary:
  (system/(relative+'.b64')).write_bytes(base64.b64encode(data))
  extra=',remotePath='+json.dumps(relative+'.b64')+',encoding="base64"'
 if relative in upstream: extra+=',id=%d,version=%d'%upstream[relative]
 entries.append('{path='+json.dumps(relative,ensure_ascii=False)+f',size={len(data)},adler={zlib.adler32(data)}'+extra+'}')
languages=sorted(p.stem for p in (root/'system/Localizations').glob('*.lang'))
(root/'Installer/Manifest.lua').write_text('return {version="0.1.0",mineosCommit='+json.dumps(sourceConfig['commit'])+',languages={'+','.join(json.dumps(s) for s in languages)+'},files={\n'+',\n'.join(entries)+'\n}}\n')
(root/'SHA256SUMS').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(root).as_posix()+'\n' for p in sorted(root.rglob('*')) if p.is_file() and p.name!='SHA256SUMS' and '__pycache__' not in str(p)))
print(len(logical),'logical system files;',sum(map(len,logical.values())),'decoded bytes')
