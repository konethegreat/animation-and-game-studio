from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass, replace
from pathlib import Path

from .. import config

UNITY_LICENSES = Path(os.environ.get("PROGRAMDATA", "C:/ProgramData")) / "Unity" / "licenses"


@dataclass(frozen=True)
class Probe:
    name: str
    tool: str
    path: str
    version: str
    kinds: tuple[str, ...]
    ok: bool
    blockers: tuple[str, ...] = ()
    device: str = ""

    def as_dict(self) -> dict:
        return {
            "name": self.name,
            "tool": self.tool,
            "path": self.path,
            "version": self.version,
            "kinds": list(self.kinds),
            "ok": self.ok,
            "blockers": list(self.blockers),
            "device": self.device,
        }


def run_engine(cmd: list[str], label: str) -> None:
    print(f"[{label}] {' '.join(cmd[:5])} ...")
    result = subprocess.run(cmd)
    if result.returncode != 0:
        raise RuntimeError(f"{label} failed with exit code {result.returncode}")


def count_frames(path: Path) -> int:
    return sum(1 for frame in path.glob("frame_*.png") if frame.stat().st_size > 0)


class EngineAdapter:
    name = ""
    tool = ""
    kinds: frozenset[str] = frozenset()

    def probe(self) -> Probe:
        exe = config.find_tool(self.tool)
        kinds = tuple(sorted(self.kinds))
        device = config.gpu_name()
        if not exe:
            return Probe(
                self.name, self.tool, "", "", kinds, False,
                (f"{self.name} not found",), device,
            )
        return Probe(
            self.name, self.tool, str(exe), config.tool_version(self.tool, exe),
            kinds, True, (), device,
        )

    def prepare(self, project) -> None:
        return None

    def render(self, project, shot, out: Path) -> int:
        raise NotImplementedError(f"{self.name} cannot render yet")

    def build(self, project, out: Path) -> Path | None:
        return None

    def export(self, project, target: Path) -> Path | None:
        return None

    def verify(self, project) -> list[str]:
        return []


class ProbeOnlyAdapter(EngineAdapter):
    def __init__(self, name: str, tool: str, kinds: set[str]) -> None:
        self.name = name
        self.tool = tool
        self.kinds = frozenset(kinds)


class UnityAdapter(ProbeOnlyAdapter):
    def probe(self) -> Probe:
        probe = super().probe()
        if not probe.ok or any(UNITY_LICENSES.glob("*")):
            return probe
        return replace(
            probe,
            ok=False,
            blockers=("Unity licence not activated; sign in to Unity Hub",),
        )
