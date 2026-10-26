#!/usr/bin/env python3
from pathlib import Path
import zlib, hashlib, json, re
root=Path(__file__).resolve().parents[1]
files=sorted(p for p in (root/'system').rglob('*') if p.is_file())
upstream={}
for match in re.finditer(r'\{\s*path\s*=\s*"([^"]+)"([^{}]*?)\}',(root/'tools/MineOS-Files.cfg').read_text(),re.S):
 item_id=re.search(r'\bid\s*=\s*(\d+)',match[2]);version=re.search(r'\bversion\s*=\s*(\d+)',match[2])
 if item_id:upstream[match[1]]=(int(item_id[1]),int(version[1]) if version else 1)
entries=[]
for p in files:
 data=p.read_bytes()
 relative=p.relative_to(root/'system').as_posix()
 extra=''
 if relative in upstream: extra=',id=%d,version=%d'%upstream[relative]
 entries.append('{path='+json.dumps(relative,ensure_ascii=False)+f',size={len(data)},adler={zlib.adler32(data)}'+extra+'}')
languages=sorted(p.stem for p in (root/'system/Localizations').glob('*.lang'))
(root/'Installer/Manifest.lua').write_text('return {version="0.1.0",languages={'+','.join(json.dumps(s) for s in languages)+'},files={\n'+',\n'.join(entries)+'\n}}\n')
(root/'SHA256SUMS').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(root).as_posix()+'\n' for p in sorted(root.rglob('*')) if p.is_file() and p.name!='SHA256SUMS' and '__pycache__' not in str(p)))
print(len(files),'system files;',sum(p.stat().st_size for p in files),'bytes')
