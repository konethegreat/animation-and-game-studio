# Godot 4.7 web renderer research

Date: 2026-11-02
Purpose: decide which visual effects BIN CITY can use in the GL Compatibility
renderer and in a web export, and what each costs.

## Findings

### Environment effects

Supported in Compatibility and web:

- Tonemapping: Linear, Reinhard, Filmic, ACES, AgX. The project uses ACES.
- `adjustment_*` controls: brightness, contrast, saturation, colour correction.
- Glow: supported, but blend mode is forced to screen. Only `glow_strength`,
  `glow_intensity`, `glow_mix`, `glow_bloom`, `glow_hdr_threshold` and
  `glow_hdr_scale` matter. `glow_levels/*`, `glow_normalized`, `glow_map` and
  `glow_map_strength` are inert. Costs a full resolution mip chain.
- Depth fog and height fog: `fog_enabled`, `fog_mode`, `fog_light_colour`,
  `fog_density`, `fog_depth_begin`, `fog_depth_end`, `fog_height`, `fog_height_density`.
- Screen and depth textures.
- MSAA 3D and SSAA.
- SSAO is only a simplified version with `ssao_radius` and `ssao_intensity`,
  and on web it forces a per frame MSAA depth and stencil resolve. Do not use
  it in the web build.

Unsupported in Compatibility and web:

- Volumetric fog, SSIL, SDFGI, SSR, depth of field, debanding, auto exposure,
  TAA, FXAA, SMAA, decals, particle trails, HDR output, compositor effects.

The 3D buffer is RGBA8 with a 24 bit depth buffer. Tonemapping clips early, so
banding must be handled with grain or dither in the post shader. Do not expect
`use_debanding` to work.

### Full screen grade

A single `CanvasLayer` ColorRect with `hint_screen_texture` triggers the
automatic backbuffer copy. `BackBufferCopy` is only needed for overlapping
screen reading shaders. Use `filter_nearest` and `textureLod(..., 0.0)`.
Mipmapped screen reads are slow on weak integrated GPUs and broken on some web
browsers. Keep the grade as the only screen reading shader.

### Sky

Sky shaders work without renderer exclusions. A gradient `shader_type sky`
with uniforms for zenith, horizon and sun is enough. `ProceduralSkyMaterial`
also works with a sun disk.

### Lighting and toon shading

`light()` compiles and runs in Compatibility and on the web. Shadowed lights
are additive multi pass, so quantised toon bands add per pass. Keep exactly one
shadow casting directional light and use shadowless omni lights for lamps.
Never enable `vertex_lighting` or `force_vertex_shading`, because both skip
`light()`. `vertex_color_is_srgb` is ignored in Compatibility.

### Outlines

Inverted hull outlines work. Use a `next_pass` material with `grow = true`,
`grow_amount` and `cull_mode = CULL_FRONT`, or a small spatial shader that
pushes vertices along the normal and renders with `cull_front, unshaded`.
Growth cannot create vertices, so box primitives crack at the corners. Use
outlines on smooth meshes (characters, rounds) and skip boxes, or accept the
cracks only on heavy props where they read as thick ink lines.

Screen space edge detection needs the normal and roughness texture, which is
Forward+ only. A colour Sobel pass can run in a CanvasLayer shader but adds
another full screen read. Not worth it.

### Particles

`GPUParticles3D` works in Compatibility and web except for manual emit, trails
and SDF collision. Pipeline compilation at load can cost around two seconds per
emitter, so it is a poor fit for many small effects. Use `CPUParticles3D` for
small counts with `fixed_fps = 30` and `interpolate = true`. Use one shared
`ShaderMaterial` with `unshaded, blend_add, depth_draw_never` and keep effects
spatially separated because sorting is per emitter.

### Shadows and budget

One shadow casting `DirectionalLight3D` with a 2048 directional shadow atlas,
16 bit shadows and soft shadow filter quality 1. Keep lamp lights shadowless.
Draw calls dominate on web because each small mesh is a draw call and the
renderer supports at most eight lights per mesh. Mesh count matters more than
triangle count.

### Measuring

`Performance.get_monitor(Performance.TIME_FPS)`,
`Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` and
`Performance.RENDER_VIDEO_MEM_USED` give runtime numbers. Use Chrome DevTools
for the browser side. GL calls can be inspected with Spector.

## Decisions for BIN CITY

1. Sky gradient shader, ACES tonemap, depth fog, no volumetric fog, no DOF,
   no SSR, no SSAO, no debanding.
2. One shadow casting sun. Lamp light stays shadowless and relies on emissive
   pools and halos.
3. Toon `light()` with three bands and a rim on characters and key props.
4. Inverted hull outlines on the player, NPCs and round props only.
5. One CanvasLayer grade over the 3D view with a nearest screen read, vignette
   and grain. No BackBufferCopy.
6. `CPUParticles3D` at 30 fixed fps for dust, steam, rain and mist.
7. Glow only for the Neon Arcade and the boss, at low strength, because the
   mip chain costs and the blend is fixed to screen. Emissive materials and
   billboard halos carry the rest.
8. Measure in Chrome before raising any budget.

## Sources

- [Overview of renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- [Environment and post-processing](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html)
- [Environment class](https://docs.godotengine.org/en/stable/classes/class_environment.html)
- [Spatial shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)
- [Screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)
- [Sky shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html)
- [BaseMaterial3D](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html)
- [Exporting for the web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
- [3D rendering limitations](https://docs.godotengine.org/en/stable/tutorials/3d/3d_rendering_limitations.html)
- [Lights and shadows](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html)
- [Godot 4.7 release](https://godotengine.org/releases/4.7/)
