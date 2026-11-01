from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from studio.lib import config, godot, manifest, publish, render, sheet  # noqa: E402


def cmd_doctor(args: argparse.Namespace) -> int:
    rows = config.doctor()
    for row in rows:
        mark = "ok" if row["ok"] else "missing"
        print(f"{row['name']:8} {mark:8} {row['path']}")
        if row["version"]:
            print(f"         {row['version']}")
    ok = all(row["ok"] for row in rows)
    return 0 if ok or args.soft else 1


def cmd_validate(_: argparse.Namespace) -> int:
    failed = False
    for project in manifest.load_all():
        errors = manifest.validate(project)
        if errors:
            failed = True
            print(f"FAIL {project.id}")
            for error in errors:
                print(f"  - {error}")
        else:
            print(f"ok   {project.id}")
    return 1 if failed else 0


def cmd_render(args: argparse.Namespace) -> int:
    project = manifest.find(args.id)
    errors = manifest.validate(project)
    if errors:
        raise SystemExit("invalid project:\n  " + "\n  ".join(errors))
    render.run(project)
    return 0


def cmd_export(args: argparse.Namespace) -> int:
    project = manifest.find(args.id)
    if project.engine == "godot":
        godot.export_web(project.root, project.root / "build" / "web")
        print(f"web build -> {project.root / 'build' / 'web'}")
        return 0
    if project.engine == "blender":
        blender = config.find_tool("blender")
        if not blender:
            raise SystemExit("blender not found")
        declared = [ROOT / output for output in project.outputs if output.lower().endswith(".glb")]
        target = declared[0] if declared else project.root / "build" / f"{project.id}.glb"
        target.parent.mkdir(parents=True, exist_ok=True)
        import subprocess

        result = subprocess.run(
            [
                str(blender), "-b", "--python", str(project.root / project.entry),
                "--", "--export-glb", str(target),
            ]
        )
        if result.returncode != 0:
            raise SystemExit("glb export failed")
        print(f"glb -> {target}")
        return 0
    raise SystemExit(f"{project.id} has no export target")


def cmd_sheet(args: argparse.Namespace) -> int:
    sheet.contact_sheet(Path(args.input), Path(args.output))
    print(f"sheet -> {args.output}")
    return 0


def cmd_publish(_: argparse.Namespace) -> int:
    publish.run()
    return 0


def cmd_new(args: argparse.Namespace) -> int:
    template = ROOT / "studio" / "templates" / args.type
    if not template.is_dir():
        raise SystemExit(f"no template for {args.type}")
    dest = ROOT / "projects" / args.name
    if dest.exists():
        raise SystemExit(f"{dest} already exists")
    shutil.copytree(template, dest)
    for path in dest.rglob("*"):
        if path.is_file():
            text = path.read_text(encoding="utf-8")
            path.write_text(
                text.replace("__ID__", args.name).replace("__TITLE__", args.title),
                encoding="utf-8",
            )
    print(f"created {dest}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="studio", description="Animation and game studio")
    sub = parser.add_subparsers(dest="command", required=True)

    doctor = sub.add_parser("doctor", help="check installed tools")
    doctor.add_argument("--soft", action="store_true", help="exit 0 even if tools are missing")
    doctor.set_defaults(func=cmd_doctor)

    validate = sub.add_parser("validate", help="validate every project manifest")
    validate.set_defaults(func=cmd_validate)

    new = sub.add_parser("new", help="scaffold a project")
    new.add_argument("type", choices=["2d", "3d", "game"])
    new.add_argument("name")
    new.add_argument("--title", default="Untitled")
    new.set_defaults(func=cmd_new)

    render_cmd = sub.add_parser("render", help="render a project to media")
    render_cmd.add_argument("id")
    render_cmd.set_defaults(func=cmd_render)

    export = sub.add_parser("export", help="export GLB or web build")
    export.add_argument("id")
    export.set_defaults(func=cmd_export)

    sheet = sub.add_parser("sheet", help="make a contact sheet from a video")
    sheet.add_argument("input")
    sheet.add_argument("output")
    sheet.set_defaults(func=cmd_sheet)

    publish_cmd = sub.add_parser("publish", help="refresh showcase data")
    publish_cmd.set_defaults(func=cmd_publish)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except (ValueError, RuntimeError, KeyError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
