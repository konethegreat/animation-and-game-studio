from __future__ import annotations

from ..config import ROOT

MAX_BUILD_MB = 25.0


def check(project) -> list[str]:
    problems: list[str] = []
    for output in project.outputs:
        path = ROOT / output
        if path.name != "index.html" or not path.exists():
            continue
        total = sum(item.stat().st_size for item in path.parent.rglob("*") if item.is_file())
        total_mb = total / (1024 * 1024)
        if total_mb > MAX_BUILD_MB:
            problems.append(f"{path.parent.name} build is {total_mb:.1f} MB, budget {MAX_BUILD_MB:g} MB")
    return problems
