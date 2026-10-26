#!/usr/bin/env python3
"""python make_zpk.py /path/Hello.app /path/Hello.zpk. No executable manifest."""
import pathlib, re, sys
source=pathlib.Path(sys.argv[1]); destination=pathlib.Path(sys.argv[2])
name=source.name.removesuffix('.app')
assert re.fullmatch(r'[A-Za-z0-9 _-]{1,48}',name), 'ASCII app name required'
assert (source/'Main.lua').is_file(), 'Main.lua required'
files=sorted(p for p in source.rglob('*') if p.is_file())
assert 1<=len(files)<=256
assert sum(p.stat().st_size for p in files)<=4*1024*1024
with destination.open('wb') as out:
 out.write(f'ZPK1\n{name}\n{len(files)}\n'.encode())
 for p in files:
  relative=p.relative_to(source).as_posix()
  assert not p.is_symlink() and not any(c in relative for c in '\n\r\\:')
  data=p.read_bytes(); assert len(data)<=1024*1024
  out.write(f'{relative}\n{len(data)}\n'.encode());out.write(data)
print(destination)
