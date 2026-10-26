#!/usr/bin/env python3
"""Restore exact binary files after cloning/downloading the GitHub source tree."""
from pathlib import Path
import base64
root=Path(__file__).resolve().parents[1]/'system'
restored=0
for source in sorted(root.rglob('*.b64')):
 target=source.with_suffix('')
 data=base64.b64decode(source.read_bytes(),validate=True)
 if target.exists():
  assert target.read_bytes()==data,f'Different existing file; inspect it first: {target}'
 else:
  target.write_bytes(data);restored+=1
print(f'Restored {restored} binary assets. Existing identical files were left unchanged.')
