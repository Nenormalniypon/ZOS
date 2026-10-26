#!/usr/bin/env python3
"""Lua 5.3 parser + mocked OpenComputers runtime tests. Linux liblua required."""
from pathlib import Path
import ctypes, ctypes.util, sys
ROOT=Path(__file__).resolve().parents[1]
lua=ctypes.CDLL(ctypes.util.find_library('lua5.3') or 'liblua-5.3.so')
P=ctypes.c_void_p
lua.luaL_newstate.restype=P
lua.luaL_openlibs.argtypes=[P]
lua.luaL_loadfilex.argtypes=[P,ctypes.c_char_p,ctypes.c_char_p];lua.luaL_loadfilex.restype=ctypes.c_int
lua.luaL_loadstring.argtypes=[P,ctypes.c_char_p];lua.luaL_loadstring.restype=ctypes.c_int
lua.lua_pcallk.argtypes=[P,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,P];lua.lua_pcallk.restype=ctypes.c_int
lua.lua_tolstring.argtypes=[P,ctypes.c_int,P];lua.lua_tolstring.restype=ctypes.c_char_p
lua.lua_settop.argtypes=[P,ctypes.c_int];lua.lua_close.argtypes=[P]
L=lua.luaL_newstate();lua.luaL_openlibs(L)
def error():return (lua.lua_tolstring(L,-1,None) or b'?').decode(errors='replace')
def run(code):
 if lua.luaL_loadstring(L,code.encode()) or lua.lua_pcallk(L,0,0,0,0,None): raise AssertionError(error())
 lua.lua_settop(L,0)
files=[p for p in ROOT.rglob('*.lua') if p.is_file()]
for path in files:
 data=path.read_bytes()
 if data.lstrip().startswith(b'{'):
  result=lua.luaL_loadstring(L,b'return '+data)
 else:
  result=lua.luaL_loadfilex(L,str(path).encode(),b't')
 if result:raise AssertionError(str(path)+': '+error())
 lua.lua_settop(L,0)
print(f'PASS: Lua 5.3 syntax, {len(files)} Lua files')
for path in list((ROOT/'system').rglob('*.lang'))+list((ROOT/'system/Themes').glob('*.thm')):
 if not path.is_file(): continue
 text=path.read_text()
 if lua.luaL_loadstring(L,('return '+text).encode()):raise AssertionError(str(path)+': '+error())
 lua.lua_settop(L,0)
print('PASS: localization and theme table syntax')
run('ROOT='+repr(str(ROOT)).replace("'",'"'))
run((ROOT/'tests/runtime.lua').read_text())
lua.lua_close(L)
print('All automated tests passed. Real OpenComputers testing remains required.')
