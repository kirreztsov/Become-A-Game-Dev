"""
M7 Round 2 - Roof crown (parapet cap) for the top floor.

HOW TO RUN: Scripting tab -> Open this file -> (Text menu -> Reload if edited)
-> ▶ Run Script. Exports blender/out/RoofCrown.fbx. Then Import 3D into Studio
and Save to File as assets/studio/RoofCrown.rbxm.

A flat cap slab (~38 x 34) with a low parapet ring around the edge. Modelled at
1 unit = 1 stud, Z up, origin = the centre of the roof at wall-top level
(Z = 0 is where it sits on top of the walls). Pieces named for code colouring.
"""

import bpy
import os

PROJECT_DIR = r"/Users/kirill/projects/roblox game"
OUT_DIR = os.path.join(PROJECT_DIR, "blender", "out")
OUT_FILE = os.path.join(OUT_DIR, "RoofCrown.fbx")

HW = 18.0
HD = 16.0


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for item in list(block):
            block.remove(item)


def add_box(name, size, location):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0] / 2.0, size[1] / 2.0, size[2] / 2.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def build():
    clear_scene()
    # Flat cap slab sitting on the walls.
    add_box("RoofCap", (HW * 2 + 2, HD * 2 + 2, 0.6), (0.0, 0.0, 0.3))
    # Low parapet ring on top of the cap.
    add_box("ParapetF", (HW * 2 + 2, 1.0, 1.6), (0.0, -HD, 1.4))
    add_box("ParapetB", (HW * 2 + 2, 1.0, 1.6), (0.0, HD, 1.4))
    add_box("ParapetL", (1.0, HD * 2 + 2, 1.6), (-HW, 0.0, 1.4))
    add_box("ParapetR", (1.0, HD * 2 + 2, 1.6), (HW, 0.0, 1.4))


def export():
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(
        filepath=OUT_FILE,
        use_selection=True,
        apply_unit_scale=True,
        global_scale=1.0,
        object_types={"MESH"},
    )
    print("Exported:", OUT_FILE)


build()
export()
print("Done. Import blender/out/RoofCrown.fbx, then Save to File into assets/studio/.")
