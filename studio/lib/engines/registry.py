from __future__ import annotations

from .base import EngineAdapter, Probe, ProbeOnlyAdapter, UnityAdapter
from .blender import BlenderAdapter
from .godot import GodotAdapter
from .pillow import PythonAdapter

SPECS: dict[str, tuple[str, set[str]]] = {
    "unity": ("unity", {"film", "game"}),
    "unreal": ("unreal", {"film"}),
    "gdevelop": ("gdevelop", {"game"}),
    "love": ("love", {"game"}),
    "monogame": ("dotnet", {"game"}),
}

ADAPTERS: dict[str, EngineAdapter] = {
    adapter.name: adapter
    for adapter in (PythonAdapter(), BlenderAdapter(), GodotAdapter(), UnityAdapter("unity", "unity", {"film", "game"}))
}
ADAPTERS.update({
    name: ProbeOnlyAdapter(name, tool, kinds)
    for name, (tool, kinds) in SPECS.items()
    if name not in ADAPTERS
})


def get(name: str) -> EngineAdapter:
    try:
        return ADAPTERS[name]
    except KeyError:
        raise ValueError(f"unknown engine '{name}'") from None


def known(name: str) -> bool:
    return name in ADAPTERS


def supports(name: str, kind: str) -> bool:
    adapter = ADAPTERS.get(name)
    return bool(adapter and kind in adapter.kinds)


def names() -> list[str]:
    return sorted(ADAPTERS)


def probe_all() -> list[Probe]:
    return [ADAPTERS[name].probe() for name in names()]
