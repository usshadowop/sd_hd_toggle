#!/usr/bin/env python3
"""Runs the headless Quick Toggle tests under Lua 5.1 (the game's Lua version).

Needs either a `lua5.1` binary on PATH or the `lupa` Python package (pip install lupa).
    python3 tests/run.py
"""
import os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.join(os.path.dirname(HERE), "QuickToggle")

if shutil.which("lua5.1"):
    sys.exit(subprocess.call(["lua5.1", os.path.join(HERE, "run_tests.lua"), HERE, ADDON]))

try:
    from lupa import lua51
except ImportError:
    sys.exit("need lua5.1 on PATH or `pip install lupa`")

L = lua51.LuaRuntime()
run = L.eval('function(h, a) local f, err = loadfile(h .. "/run_tests.lua"); if not f then error(err) end; return f(h, a) end')
sys.exit(1 if run(HERE, ADDON) else 0)
