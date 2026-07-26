"""
M7 Map batch - a detailed low-poly bush / shrub.

Run in Blender (Scripting -> Open -> Reload if edited -> ▶ Run). Exports
blender/out/Bush.fbx. Import 3D into Studio, Save to File as assets/studio/Bush.rbxm.
(Colours set in game: all pieces green.)

1 unit = 1 stud, Z up, origin (0,0,0) = base on the ground. ~4.5 wide, ~3 tall.
"""

import bpy
import os

PROJECT_DIR = r"/Users/kirill/projects/roblox game"
OUT_FILE = os.path.join(PROJECT_DIR, "blender", "out", "Bush.fbx")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for item in list(block):
            block.remove(item)


def blob(name, radius, location):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius,
                                           location=location)
    bpy.context.active_object.name = name


def build():
    clear_scene()
    # A low, rounded, slightly irregular clump of leafy blobs.
    blob("Leaf1", 1.7, (0.0, 0.0, 1.5))
    blob("Leaf2", 1.35, (1.3, 0.3, 1.7))
    blob("Leaf3", 1.35, (-1.2, -0.4, 1.6))
    blob("Leaf4", 1.15, (0.2, 1.2, 1.9))
    blob("Leaf5", 1.15, (0.3, -1.1, 1.6))
    blob("Leaf6", 1.0, (0.0, 0.0, 2.6))


def export():
    os.makedirs(os.path.dirname(OUT_FILE), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=OUT_FILE, use_selection=True,
                             apply_unit_scale=True, global_scale=1.0,
                             object_types={"MESH"})
    print("Exported:", OUT_FILE)


build()
export()
print("Done. Import blender/out/Bush.fbx -> Save to File assets/studio/Bush.rbxm")
