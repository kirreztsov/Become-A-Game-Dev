"""
A game controller mesh for the plaza hologram (replaces the blocky procedural
one). Built from plain boxes / cylinders / balls + a bevel -- the SAME pattern
as props1-4 that imported cleanly. No lathe, no subdivision-surface, no 3D text
(those were what broke the trophy import).

Part names drive in-game colour (the hologram paints Body translucent glass +
the rest as neon accents):
  Body  -> shell + grips + bumpers + centre logo
  Dpad  -> the d-pad cross
  Btn1..Btn4 -> the four face buttons (distinct colours)
  Stick -> the two thumbsticks

Built Z-up, buttons on the +Z (top) face, front toward -Y, 1 unit = 1 stud
(~6 studs wide). Run in Blender (Scripting -> Open -> Reload -> Run), then
Import blender/out/Controller.fbx and Save assets/studio/Controller.rbxm.
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


def _finish(o, rot, bucket):
    if rot != (0, 0, 0):
        o.rotation_euler = (math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bucket.append(o)
    return o


def box(dims, loc, bucket, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = dims
    return _finish(o, rot, bucket)


def cyl(r, depth, loc, bucket, rot=(0, 0, 0), verts=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    return _finish(bpy.context.active_object, rot, bucket)


def ball(r, loc, bucket):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=loc)
    return _finish(bpy.context.active_object, (0, 0, 0), bucket)


def join_bevel(parts, name, bevel=0.05):
    if not parts:
        return
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
    bpy.ops.object.shade_flat()


def export(filename):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, filename), use_selection=True,
                             apply_unit_scale=True, global_scale=1.0, object_types={"MESH"})
    print("Exported:", filename)


def build_controller():
    clear_scene()
    body, dpad, stick = [], [], []
    b1, b2, b3, b4 = [], [], [], []

    TOP = 2.05  # top face height (buttons sit here)

    # main body slab + two grips angled down/out + two shoulder bumpers
    box((5.4, 3.0, 1.1), (0, 0, 1.5), body)
    box((1.7, 2.6, 1.25), (-2.35, -1.0, 0.95), body, rot=(16, 0, 20))
    box((1.7, 2.6, 1.25), (2.35, -1.0, 0.95), body, rot=(16, 0, -20))
    box((1.7, 0.6, 0.5), (-1.6, 1.45, 1.95), body)
    box((1.7, 0.6, 0.5), (1.6, 1.45, 1.95), body)
    cyl(0.32, 0.12, (0, 0.85, TOP), body)  # centre logo disc

    # d-pad cross (left)
    box((1.05, 0.3, 0.26), (-1.75, 0.2, TOP), dpad)
    box((0.3, 1.05, 0.26), (-1.75, 0.2, TOP), dpad)

    # four face buttons (right) -- each its own part for distinct colours
    cyl(0.3, 0.26, (1.75, 0.85, TOP), b1)  # top
    cyl(0.3, 0.26, (2.35, 0.2, TOP), b2)   # right
    cyl(0.3, 0.26, (1.75, -0.45, TOP), b3)  # bottom
    cyl(0.3, 0.26, (1.15, 0.2, TOP), b4)   # left

    # two thumbsticks (base disc + rounded cap)
    for sx in (-0.7, 0.75):
        cyl(0.38, 0.42, (sx, -0.75, TOP + 0.05), stick)
        ball(0.42, (sx, -0.75, TOP + 0.4), stick)

    join_bevel(body, "Body", bevel=0.09)
    join_bevel(dpad, "Dpad", bevel=0.03)
    join_bevel(b1, "Btn1", bevel=0.02)
    join_bevel(b2, "Btn2", bevel=0.02)
    join_bevel(b3, "Btn3", bevel=0.02)
    join_bevel(b4, "Btn4", bevel=0.02)
    join_bevel(stick, "Stick", bevel=0.03)
    export("Controller.fbx")


build_controller()
print("Done. Import blender/out/Controller.fbx -> Save assets/studio/Controller.rbxm")
