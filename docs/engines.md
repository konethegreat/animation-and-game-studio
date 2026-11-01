# Engine capability matrix

Measured on 2026-11-01 on the studio machine: Ryzen 5 5600H (12 threads), 11.4 GB RAM, RTX 3050 Laptop with 4 GB VRAM, 243 GB free on C, Windows 11.

Every row was probed, not assumed. `studio doctor --deep` prints the same data plus adapter kinds.

## Matrix

| Tool | Version | Path | Adapter | Status |
| --- | --- | --- | --- | --- |
| Python | 3.15.2 | `.venv/Scripts/python.exe` | `python`, film | ok, renders with Pillow |
| Blender | 4.5.10 LTS | `C:/Users/Konet/Tools/blender-4.5.10-windows-x64/blender.exe` | `blender`, film | ok, Cycles OptiX devices listed |
| Godot | 4.7.2 stable | `C:/Users/Konet/Tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe` | `godot`, game | ok, web export produces 38 MB wasm |
| FFmpeg | 9.0.2 essentials | `C:/Users/Konet/Tools/ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe` | none, media backend | ok |
| .NET SDK | 10.0.403 | `C:/Program Files/dotnet/dotnet.exe` | `monogame`, game | ok, templates installed |
| MonoGame templates | 3.8.6 | `~/.templateengine/packages` | `monogame`, game | ok, `mgdesktopgl` and friends listed |
| LÖVE | 11.5 | `C:/Program Files/LOVE/love.exe` | `love`, game | ok, PNG capture proven |
| GDevelop | 5.6.285 | `C:/Users/Konet/AppData/Local/Programs/GDevelop/GDevelop.exe` | `gdevelop`, game | installed, headless export unproven |
| Unity | 6.3 LTS 6000.3.27f2 | `C:/Program Files/Unity/Hub/Editor/6000.3.27f2/Editor/Unity.exe` | `unity`, film and game | ok, Personal licence active and batch mode runs; adapter is probe only until 005 lands |
| Unity Hub | 3.22.5 (MSIX) | `C:/Program Files/WindowsApps/UnityTechnologies.UnityHub_3.22.5.65535_x64__2vrhnee42bhxm` | none, sign-in gateway | ok, found through the AppX package query |
| Unreal | 5.8 target | not installed | `unreal`, film | blocked, see below |

## Verified probes

- **Blender Cycles GPU**: `OPTIX` and `CUDA` both list `NVIDIA GeForce RTX 3050 Laptop GPU`. The 004 scene currently sets `device = CPU`; the film plan switches it to GPU.
- **Cycles timing**, default scene, 960x540 at 64 samples with denoising off: GPU 0.88 s and 0.85 s on two warm runs, CPU 3.01 s. At 320x180 and 16 samples the first GPU run took 2.22 s because OptiX compiled kernels, then the CPU took 0.25 s. Small resolutions are dominated by setup, so the film benchmarks at 1080p on a real scene before locking sample counts.
- **LÖVE capture**: a 320x180 probe wrote a valid PNG through `love.graphics.captureScreenshot`, then quit. Frames land in `%APPDATA%/LOVE/<identity>/`, so the adapter must copy from there.
- **Godot web export**: `studio build 003-micro-game` regenerated `index.wasm` at 38 MB, 39 MB for the whole folder. The verification ceiling is 40 MB per build because the engine, not our content, sets that floor.
- **Unity batch mode**: `Unity.exe -batchmode -quit -nographics` connects to the licensing client, resolves the entitlement and quits cleanly. Unity 6 stores the entitlement at `%LOCALAPPDATA%/Unity/licenses/UnityEntitlementLicense.xml`; the older `%PROGRAMDATA%/Unity/licenses` layout is checked too, so the probe covers both.
- **Unity WebGL**: `WebGLSupport` is present next to `windowsstandalonesupport` in the editor playback engines.
- **MonoGame**: `dotnet new list` shows `mgdesktopgl`, `mgwindowsdx`, `mgdesktopvk`, `mgblank2dstartkit` and the content builder templates. NuGet had no sources configured, so `https://api.nuget.org/v3/index.json` was added as `nuget.org`.
- **GDevelop**: the executable has file version 5.6.285.40859. It did not answer `--version` within 45 seconds, so the probe skips version calls for GUI tools and reports the file version through the matrix only.
- **Unreal**: no Epic Games directory exists. The launcher needs an Epic account, and a UE 5.8 install is roughly 120 GB with a 32 GB RAM recommendation against our 11.4 GB. The adapter stays registered and reports the missing tool.

## Blockers

1. **Unity licence**: resolved on 2026-11-01. The owner signed in through Unity Hub, the Personal entitlement landed in the user profile, and the adapter now reports `unity ok`. No owner action left.
2. **Unreal 5.8**: needs an Epic account, the launcher, a 120 GB download and more RAM than the machine has. The 009 artifact becomes a capability report with measured numbers, which is already the spec fallback.
3. **GDevelop headless export**: 006 must prove a command line export path. If none is reliable, the project file and the export recipe are committed and the artifact ships as video under the web build rule.

## Install record

```bash
# Unity 6.3 LTS editor, direct installer, elevated
https://download.unity3d.com/download_unity/22188f149405/Windows64EditorInstaller/UnitySetup64-6000.3.27f2.exe
# WebGL support module for the same build
https://download.unity3d.com/download_unity/22188f149405/TargetSupportInstaller/UnitySetup-WebGL-Support-for-Editor-6000.3.27f2.exe

# MonoGame templates, user scope
"C:/Program Files/dotnet/dotnet.exe" nuget add source https://api.nuget.org/v3/index.json -n nuget.org
"C:/Program Files/dotnet/dotnet.exe" new install MonoGame.Templates.CSharp
```

The Unity installers were run with `/S` and `/D=C:\Program Files\Unity\Hub\Editor\6000.3.27f2`, which needs an elevation prompt. Unity Hub is a Store MSIX package under `WindowsApps`, which `glob` cannot list, so `find_tool` falls back to `Get-AppxPackage` when the normal paths miss.

## Reproduce

```bash
./.venv/Scripts/python studio/studio.py doctor --deep
./.venv/Scripts/python studio/studio.py validate
```
