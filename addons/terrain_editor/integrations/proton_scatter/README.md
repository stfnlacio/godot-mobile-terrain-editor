# Proton Scatter + Terrain Editor

Project scattered instances onto **Godot Mobile Terrain Editor** heightmaps without physics raycasts.

## Install

1. Install both addons:
   - `addons/terrain_editor/`
   - `addons/proton_scatter/`
2. **Copy** this modifier into Proton Scatter’s discovery folder:

```text
addons/terrain_editor/integrations/proton_scatter/project_on_terrain_editor.gd
  →  addons/proton_scatter/src/modifiers/project_on_terrain_editor.gd
```

Proton Scatter only auto-lists scripts inside its own `src/modifiers/` folder.

3. Restart the editor (or disable/enable Proton Scatter).

## Usage

1. Add a **TerrainManager** and sculpt/generate terrain.
2. Add a **ProtonScatter** node with shapes + a Create modifier (e.g. Create Inside Random).
3. Add modifier **Project On Terrain Editor** (category: Edit).
4. Optional: set **Terrain Manager** NodePath (auto-finds if empty).
5. Enable **Align With Normal** if you want grass/rocks to follow slopes.

## Why this exists

Terrain Editor only builds collision near the camera (`collision_radius`).  
Proton’s built-in **Project On Colliders** can miss where collision is off.  
This modifier samples the heightmap directly via `TerrainManager.sample_height_at_global()`.

## Requirements

- terrain_editor **v0.2.1+** (sampling API)
- proton_scatter installed
