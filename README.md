# Terrain Editor (Godot 4)

Pure GDScript 3D terrain sculpting plugin and demo.

**Author:** Stefan Lacio  
**Version:** 0.1  
**Engine:** Godot 4.x (works on Godot Mobile / Android)

## What’s included

- `addons/terrain_editor/` — the plugin
- This project — test/demo scene setup

## Features

- 100% GDScript (no GDExtension / C# / .so)
- Half-float heightmaps (`FORMAT_RH`) for low RAM
- Clockwise winding + broad custom AABB
- Adaptive collision (only near camera)
- Localized brush sculpt + frame-throttled mesh rebuild
- Undo / Redo (16 steps)
- Procedural FBM terrain generation
- Full **Material** override (Standard, Shader, ORM, …)
- UV scale / offset
- Mobile-first sidebar UI

## Install (into another project)

1. Copy `addons/terrain_editor/` into `res://addons/`
2. Project → Project Settings → Plugins → enable **Terrain Editor**
3. Add a **TerrainManager** node to a 3D scene

## Demo usage

1. Open this project in Godot 4
2. Open the terrain test scene
3. Select `TerrainManager` — sidebar appears on the right
4. Sculpt with touch / mouse
5. **Save the scene** after sculpting so Play mode keeps the heightmap
6. Optional: Utility → Quick Save → `res://terrain_heightmap.exr`

## Plugin docs

See [addons/terrain_editor/README.md](addons/terrain_editor/README.md)

## License

MIT — Stefan Lacio, 2026
