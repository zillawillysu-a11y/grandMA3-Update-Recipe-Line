"""Run read-only dependency probe fixtures; never connects to grandMA3."""
from pathlib import Path
import os
from lupa import LuaRuntime

root = Path(__file__).resolve().parents[1]
os.chdir(root)
LuaRuntime().execute((root / "tests/getdependencies_probe.lua").read_text(encoding="utf-8"))
