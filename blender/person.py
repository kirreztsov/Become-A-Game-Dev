"""
M7 visual polish: a friendly low-poly pedestrian to replace the blocky
procedural NPC. Built to the SAME proportions the walk loop expects: feet at
Z=0, torso centre at Z=3.9 (the loop pivots the model's Torso to ground+3.9),
front faces -Y. Rounded (beveled) so it reads as a cute character, not boxes.

Part names drive per-NPC colouring:
  Torso (shirt) -- also the model's PrimaryPart in-game
  Pants (legs), Skin (arms + head), Hair, Eyes (dark)

1 unit = 1 stud. Run in Blender (Scripting -> Open -> Reload -> ▶ Run), then
import blender/out/Person.fbx and Save assets/studio/Person.rbxm.
"""

import bpy
import os
import math

OUT = r"/Users/kirill/projects/roblox game/blender/out"


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for item in list(coll):
            coll.remove(item)


def box(dims, loc, bucket):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bucket.append(o)
    return o


def join_bevel(parts, name, bevel):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    if bevel > 0:
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = 2
        bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_smooth()
    return o


def build_person():
    clear_scene()
    pants, shirt, skin, hair, eyes = [], [], [], [], []
    for sx in (-0.45, 0.45):
        box((0.72, 0.72, 2.6), (sx, 0, 1.3), pants)          # legs (feet at 0)
    box((2.0, 1.1, 2.7), (0, 0, 3.95), shirt)                # torso (centre ~3.9)
    for sx in (-1.35, 1.35):
        box((0.58, 0.62, 2.4), (sx, 0, 3.9), skin)           # arms
    box((1.35, 1.3, 1.35), (0, 0, 5.85), skin)               # head
    box((1.5, 1.5, 0.6), (0, -0.05, 6.5), hair)              # hair cap
    for sx in (-0.3, 0.3):
        box((0.22, 0.12, 0.22), (sx, -0.66, 5.95), eyes)     # eyes on -Y (front)
    join_bevel(pants, "Pants", 0.16)
    join_bevel(shirt, "Torso", 0.18)
    join_bevel(skin, "Skin", 0.16)
    join_bevel(hair, "Hair", 0.12)
    join_bevel(eyes, "Eyes", 0.0)

    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "Person.fbx"), use_selection=True,
                             apply_unit_scale=True, global_scale=1.0, object_types={"MESH"})
    print("Exported Person.fbx")


build_person()
print("Done. Import blender/out/Person.fbx -> Save assets/studio/Person.rbxm")
