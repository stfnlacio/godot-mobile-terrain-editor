# Terrain Editor (Godot 4)

Lightweight 3D terrain sculpting plugin and demo for Godot 4 — tuned for the Godot Mobile Editor and low-spec Android.

**Author:** Stefan Lacio  
**Version:** 0.3  
**Engine:** Godot 4.x (32-bit and 64-bit Android)

## What's included

- `addons/terrain_editor/` — the plugin
- This project — test/demo scene setup

## Features

| Requirement | Implementation |
|---|---|
| Zero native deps | GDScript + one Godot shader — no GDExtension / C# / `.so` |
| Clockwise winding | Indices generated CW from above; `@export var flip_winding` escape hatch |
| Broad custom AABB | Prevents frustum culling when camera zooms / tilts |
| 16-bit heightmap | `Image.FORMAT_RH` (2 bytes/sample) |
| Adaptive physics | `StaticBody3D` + `HeightMapShape3D` only inside `collision_radius` |
| Localized sculpt | Brush footprint `Rect2i` — never walks the whole map |
| Frame-throttled mesh | Rebuild at most once every N frames per chunk |
| Splatmap paint | Up to 4 texture layers (L0–L3) with live GPU refresh |
| External tools API | `sample_height_at_global`, `sample_normal_at_global` |
| Proton Scatter | Optional “Project On Terrain Editor” modifier |
| Mobile sidebar | Large touch targets, thick sliders, collapsible sections |

## Install (into another project)

1. Copy `addons/terrain_editor/` into `res://addons/`
2. Project → Project Settings → Plugins → enable **Terrain Editor**
3. Add a **TerrainManager** node to a 3D scene

## Demo usage

1. Open this project in Godot 4
2. Open the terrain test scene
3. Select `TerrainManager` — sidebar appears on the right
4. Sculpt with touch / mouse (Raise / Lower / Smooth / Flatten / Paint)
5. For texture paint: enable **Splatmap**, assign textures 0–3, use **Paint** + **L0–L3**
6. **Save the scene** after sculpting so Play mode keeps the heightmap
7. Optional: Utility → Quick Save → `res://terrain_heightmap.exr`

## Proton Scatter (optional)

1. Install [Proton Scatter](https://store.godotengine.org/asset/hungryproton/protonscatter/)
2. Copy:
   `addons/terrain_editor/integrations/proton_scatter/project_on_terrain_editor.gd`
   → `addons/proton_scatter/src/modifiers/project_on_terrain_editor.gd`
3. Restart the editor
4. On a Scatter node, add modifier **Project On Terrain Editor**

See [addons/terrain_editor/integrations/proton_scatter/README.md](https://github.com/stfnlacio/godot-mobile-terrain-editor/blob/main/addons/terrain_editor/integrations/proton_scatter/README.md)

## Architecture

```
addons/terrain_editor/
├── plugin.cfg
├── plugin.gd                 # EditorPlugin – input, type registration
├── terrain_data.gd           # FORMAT_RH heightmap + RGBA8 splatmap
├── terrain_chunk.gd          # ArrayMesh (CW indices), AABB, collision, splat shader
├── terrain_manager.gd        # Chunk grid, undo, generate, sampling API
├── sculpt_brush.gd           # Localized height + splat paint math
├── shaders/
│   └── terrain_splat.gdshader
├── integrations/
│   └── proton_scatter/
│       ├── project_on_terrain_editor.gd
│       └── README.md
└── ui/
    ├── terrain_editor_overlay.gd
    └── terrain_editor_overlay.tscn
```

## Performance Notes (armv7)

- Heightmap 256×256 × 2 B = **128 KB** — well under 3–4 GB limit
- Splatmap 256×256 × 4 B = **256 KB** when enabled
- Only chunks inside the camera radius compile physics shapes
- Mesh rebuilds are capped (`mesh_rebuild_interval`, default 3 frames)
- No deep Node trees; chunks are flat MeshInstance3D children

## License

MIT — Stefan Lacio, 2026
