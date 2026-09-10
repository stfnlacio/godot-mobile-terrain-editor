# Terrain Editor – Pure GDScript Mobile Plugin

Lightweight 3D terrain sculpting addon for **Godot 4.x Mobile Editor**, engineered for 32-bit (armv7) Android hardware.

## Features

| Requirement | Implementation |
|---|---|
| Zero binary deps | 100 % GDScript 2.0 – no GDExtension / C# / .so |
| Clockwise winding | Indices generated CW from above; `@export var flip_winding` escape hatch |
| Broad custom AABB | Prevents frustum culling when camera zooms / tilts |
| 16-bit heightmap | `Image.FORMAT_RH` (2 bytes/sample) |
| Adaptive physics | `StaticBody3D` + `HeightMapShape3D` only inside `collision_radius` |
| Localized sculpt | Brush footprint `Rect2i` – never walks the whole map |
| Frame-throttled mesh | Rebuild at most once every N frames per chunk |
| Mobile sidebar | 88–96 px touch targets, thick sliders, collapsible sections |

## Install

1. Copy the entire `terrain_editor/` folder into your project’s `res://addons/`.
2. Project → Project Settings → Plugins → enable **Terrain Editor**.
3. In a 3D scene add a **TerrainManager** node (Create New Node → search “TerrainManager”).

## Usage

- Select the `TerrainManager` – the right-side sidebar appears.
- Touch-drag (or left-mouse-drag) on the terrain to sculpt.
- Brush modes: Raise / Lower / Smooth / Flatten.
- Adjust radius, strength, falloff, world scale and collision radius from the panel.
- Albedo texture: assign via the Inspector on the TerrainManager (propagates to all chunks).
- Quick Save writes an EXR heightmap (`res://terrain_heightmap.exr`).

## Architecture

```
addons/terrain_editor/
├── plugin.cfg
├── plugin.gd              # EditorPlugin – input forwarding, type registration
├── terrain_data.gd        # FORMAT_RH Image storage & bulk blit helpers
├── terrain_chunk.gd       # ArrayMesh builder (CW indices), AABB, collision
├── terrain_manager.gd     # Chunk grid, dirty-set, frame throttle, radius culling
├── sculpt_brush.gd        # Localized pixel math (Raise/Lower/Smooth/Flatten)
└── ui/
    ├── terrain_editor_overlay.gd
    └── terrain_editor_overlay.tscn
```

## Performance Notes (armv7)

- Heightmap 256×256 × 2 B = **128 KB** – well under 3–4 GB limit.
- Only chunks inside the camera radius compile physics shapes.
- Mesh rebuilds are capped (`mesh_rebuild_interval`, default 3 frames).
- No deep Node trees; chunks are flat MeshInstance3D children.

## License

Free to use and modify.
