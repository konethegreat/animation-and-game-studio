from __future__ import annotations

from .base import EngineAdapter, Probe, ProbeOnlyAdapter

SPECS: dict[str, tuple[str, set[str]]] = {
    "python": ("python", {"film"}),
    "blender": ("blender", {"film"}),
    "godot": ("godot", {"game"}),
    "unity": ("unity", {"film", "game"}),
    "unreal": ("unreal", {"film"}),
    "gdevelop": ("gdevelop", {"game"}),
    "love": ("love", {"game"}),
    "monogame": ("dotnet", {"game"}),
}

ADAPTERS: dict[str, EngineAdapter] = {
    name: ProbeOnlyAdapter(name, tool, kinds)
    for name, (tool, kinds) in SPECS.items()
}


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
