"""
A premium retail DISPLAY COUNTER for the PC store (replaces the plain box
pedestal). One mesh, reused for all 7 counters. Built from boxes + a bevel so
the edges are rounded (not a hard cube) -- the SAME safe pattern as the other
props.

Part names drive in-game colour (Lobby.paintPCCounter):
  Body    -> rounded white plinth + top collar
  Chrome  -> metal kick-plate around the base
  Top     -> dark recessed display tray (the product sits on this)
  Accent  -> orange light strips on the front
  Screen  -> a small glowing info screen on the front

Built Z-up, 1 unit = 1 stud, FRONT toward -Y (the accent + screen face the
aisle; Lobby yaws it to face the walkway), base at z = 0 so it sits on the
floor. Run in Blender (Scripting -> Open -> Reload -> Run); it writes
blender/out/PCCounter.fbx. Import it and save assets/studio/PCCounter.rbxm.
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


def box(dims, loc, bucket, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = dims
    if rot != (0, 0, 0):
        o.rotation_euler = (math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bucket.append(o)
    return o


def join_bevel(parts, name, bevel=0.05, segs=2):
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
        m.segments = segs
        bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_flat()


def export(filename):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, filename), use_selection=True,
                             apply_unit_scale=True, global_scale=1.0, object_types={"MESH"})
    print("Exported:", filename)


def build_counter():
    clear_scene()
    body, chrome, top, accent, screen = [], [], [], [], []

    # Rounded white plinth + a top collar that frames the display tray.
    box((3.8, 3.4, 2.3), (0, 0, 1.25), body)
    box((3.55, 3.15, 0.22), (0, 0, 2.45), body)         # top collar
    # Metal kick-plate around the base.
    box((3.95, 3.55, 0.45), (0, 0, 0.22), chrome)
    # Dark recessed display tray (product sits here).
    box((3.25, 2.85, 0.3), (0, 0, 2.62), top)
    # Orange accent light strips on the front face (-Y), top and bottom.
    box((3.2, 0.14, 0.16), (0, -1.72, 2.15), accent)
    box((3.2, 0.14, 0.16), (0, -1.72, 0.55), accent)
    # A small glowing info screen on the front (dark bezel = body, teal face).
    box((2.0, 0.12, 1.25), (0, -1.7, 1.3), body)        # bezel
    box((1.7, 0.08, 0.95), (0, -1.77, 1.3), screen)     # screen face

    join_bevel(body, "Body", bevel=0.08)
    join_bevel(chrome, "Chrome", bevel=0.04)
    join_bevel(top, "Top", bevel=0.04)
    join_bevel(accent, "Accent", bevel=0.03)
    join_bevel(screen, "Screen", bevel=0.02)
    export("PCCounter.fbx")


build_counter()
print("Done. Import blender/out/PCCounter.fbx and save assets/studio/PCCounter.rbxm.")
