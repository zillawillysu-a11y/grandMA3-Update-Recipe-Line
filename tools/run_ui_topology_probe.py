"""Run bounded UI topology mocks without connecting to grandMA3."""
from pathlib import Path
import os
from lupa import LuaRuntime
root = Path(__file__).resolve().parents[1]
os.chdir(root)
LuaRuntime().execute((root / "tests/ui_topology_probe.lua").read_text(encoding="utf-8"))
