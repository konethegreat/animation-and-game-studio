import argparse
import ast
import sys
from pathlib import Path


BUILDER = Path(__file__).resolve().parents[1] / "tools" / "character" / "build_probe.py"


def test_reference_heads_require_explicit_opt_in(monkeypatch):
    tree = ast.parse(BUILDER.read_text(encoding="utf-8"))
    function = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "parse_args")
    namespace = {"argparse": argparse, "sys": sys}
    exec(compile(ast.Module(body=[function], type_ignores=[]), str(BUILDER), "exec"), namespace)
    monkeypatch.setattr(sys, "argv", ["blender", "--", "--source", "body.fbx", "--out", "probe.glb"])
    assert namespace["parse_args"]().heads is None
    monkeypatch.setattr(sys, "argv", [*sys.argv, "--heads", "local-research"])
    assert namespace["parse_args"]().heads == "local-research"
