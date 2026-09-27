"""Execute child enumeration mocks without connecting to grandMA3."""
from pathlib import Path
import os
from lupa import LuaRuntime
root = Path(__file__).resolve().parents[1]
os.chdir(root)
LuaRuntime().execute((root / "tests/child_enumeration_probe.lua").read_text(encoding="utf-8"))
