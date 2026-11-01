from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from studio.lib import assets, config, cut, engines, manifest, publish, render, sheet, verify  # noqa: E402


def cmd_doctor(args: argparse.Namespace) -> int:
    rows = config.doctor()
    for row in rows:
        mark = "ok" if row["ok"] else "missing"
        print(f"{row['name']:10} {mark:8} {row['path']}")
        if row["version"]:
            print(f"           {row['version']}")
    if args.deep:
        print("\nadapters")
        for probe in engines.probe_all():
            mark = "ok" if probe.ok else "blocked"
            kinds = ",".join(probe.kinds)
            print(f"{probe.name:10} {mark:8} {kinds:10} {probe.path}")
            if probe.version:
                print(f"           {probe.version}")
            for blocker in probe.blockers:
                print(f"           {blocker}")
        gpu = config.gpu_name()
        if gpu:
            print(f"\ngpu        {gpu}")
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
    shot_ids = [args.shot] if args.shot else None
    resume = args.resume or project.kind == "film"
    render.run(project, shot_ids=shot_ids, preview=args.preview, resume=resume)
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    project = manifest.find(args.id)
    checks = verify.run(project, stage="all")
    failed = False
    for check in checks:
        mark = "ok  " if check.ok else "FAIL"
        print(f"{mark} {check.name:8} {check.detail}")
        failed = failed or not check.ok
    return 1 if failed else 0


def cmd_build(args: argparse.Namespace) -> int:
    project = manifest.find(args.id)
    if project.kind != "game":
        raise SystemExit(f"{project.id} is not a game; use studio render")
    adapter = engines.get(project.engine)
    out = project.root / "build" / "web"
    target = adapter.build(project, out)
    if not target:
        raise SystemExit(f"{project.engine} has no build target")
    print(f"web build -> {target}")
    return 0


def cmd_export(args: argparse.Namespace) -> int:
    project = manifest.find(args.id)
    adapter = engines.get(project.engine)
    if project.engine == "blender":
        target = project.output_path(".glb") or project.root / "build" / f"{project.id}.glb"
        result = adapter.export(project, target)
        print(f"glb -> {result}")
        return 0
    if project.kind == "game":
        return cmd_build(args)
    raise SystemExit(f"{project.id} has no export target")


def cmd_cut(args: argparse.Namespace) -> int:
    project = manifest.find(args.id)
    shots = [part.strip() for part in args.shots.split(",") if part.strip()]
    audio = Path(args.audio).resolve() if args.audio else None
    cut.cut(project, shots, Path(args.out).resolve(), audio=audio)
    return 0


def cmd_sheet(args: argparse.Namespace) -> int:
    sheet.contact_sheet(Path(args.input), Path(args.output))
    print(f"sheet -> {args.output}")
    return 0


def cmd_publish(_: argparse.Namespace) -> int:
    publish.run()
    return 0


def cmd_assets(args: argparse.Namespace) -> int:
    if args.action == "fetch":
        problems = assets.fetch()
    elif args.action == "verify":
        problems = assets.verify(offline=args.offline)
    else:
        path = assets.write_credits()
        print(f"credits -> {path}")
        return 0
    for problem in problems:
        print(f"FAIL {problem}")
    return 1 if problems else 0


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
    doctor.add_argument("--deep", action="store_true", help="also probe engine adapters")
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
    render_cmd.add_argument("--shot", default="", help="render one shot")
    render_cmd.add_argument("--resume", action="store_true", help="skip completed shots")
    render_cmd.add_argument("--preview", action="store_true", help="half resolution preview")
    render_cmd.set_defaults(func=cmd_render)

    export = sub.add_parser("export", help="export GLB or web build")
    export.add_argument("id")
    export.set_defaults(func=cmd_export)

    build_cmd = sub.add_parser("build", help="build a playable game")
    build_cmd.add_argument("id")
    build_cmd.set_defaults(func=cmd_build)

    verify_cmd = sub.add_parser("verify", help="verify rendered outputs")
    verify_cmd.add_argument("id")
    verify_cmd.set_defaults(func=cmd_verify)

    sheet_cmd = sub.add_parser("sheet", help="make a contact sheet from a video")
    sheet_cmd.add_argument("input")
    sheet_cmd.add_argument("output")
    sheet_cmd.set_defaults(func=cmd_sheet)

    cut_cmd = sub.add_parser("cut", help="assemble a review cut from rendered shots")
    cut_cmd.add_argument("id")
    cut_cmd.add_argument("--shots", required=True, help="comma separated shot ids")
    cut_cmd.add_argument("--out", required=True)
    cut_cmd.add_argument("--audio", default="")
    cut_cmd.set_defaults(func=cmd_cut)

    publish_cmd = sub.add_parser("publish", help="refresh showcase data")
    publish_cmd.set_defaults(func=cmd_publish)

    assets_cmd = sub.add_parser("assets", help="fetch, verify or credit assets")
    assets_cmd.add_argument("action", choices=["fetch", "verify", "credits"])
    assets_cmd.add_argument("--offline", action="store_true", help="skip missing embed and private files")
    assets_cmd.set_defaults(func=cmd_assets)
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
