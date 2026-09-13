# Terrain Editor (Godot 4)

Lightweight 3D terrain sculpting plugin and demo for Godot 4 — tuned for the Godot Mobile Editor and low-spec Android.

**Author:** Stefan Lacio  
**Version:** 0.3  
**Engine:** Godot 4.x (32-bit and 64-bit Android)

## What’s included

- `addons/terrain_editor/` — the plugin
- This project — test/demo scene setup

## Features

- No GDExtension, C#, or native `.so` libraries (GDScript + one Godot shader)
- Half-float heightmaps (`FORMAT_RH`) for low RAM
- Clockwise mesh winding + broad custom AABB (top-down friendly)
- Adaptive collision (only near the camera)
- Localized brush sculpt + frame-throttled mesh rebuild
- Undo / Redo (16 steps)
- Procedural FBM terrain generation
- Full **material** override (StandardMaterial3D, ShaderMaterial, ORM, …)
- UV scale / offset
- **Splatmap texture painting** (up to 4 layers, L0–L3)
- **Proton Scatter** integration (project instances onto heightmap)
- Height / normal sampling API for external tools
- Mobile-first sidebar UI

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

See [integrations/proton_scatter/README.md](addons/terrain_editor/integrations/proton_scatter/README.md)

## Plugin docs

See [addons/terrain_editor/README.md](addons/terrain_editor/README.md)

## License

MIT — Stefan Lacio, 2026
