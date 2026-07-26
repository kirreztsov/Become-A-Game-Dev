"""
M7 plaza fixtures: a framed Welcome sign monument and an info Kiosk terminal.
The sign text (both faces) and the kiosk's "Go to My Studio" prompt are
re-attached in Lua to the named parts, so behaviour is unchanged.

Part names drive in-game colouring / GUI attachment:
  WelcomeSign -> SignPost (wood posts), SignBoard (the text face), SignTrim
                 (frame + pediment + finials).
  Kiosk       -> KioskBody (grey housing), KioskScreen (glowing screen; prompt
                 attaches here), KioskSign (topper; text attaches here),
                 KioskTrim.

Built Z-up, base at Z=0. WelcomeSign board faces +/-Y (both readable). Kiosk
screen faces -Y. 1 unit = 1 stud.

Run in Blender (Scripting -> Open -> Reload -> ▶ Run). Import each
blender/out/<Name>.fbx and Save assets/studio/<Name>.rbxm.
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


def join_bevel(parts, name, bevel=0.04):
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
        m.segments = 1
        bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_flat()


def export(filename):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, filename), use_selection=True,
                             apply_unit_scale=True, global_scale=1.0, object_types={"MESH"})
    print("Exported:", filename)


# ---------------------------------------------------------------- WelcomeSign
def build_welcome():
    clear_scene()
    post, board, trim = [], [], []
    # Two posts with finials.
    for sx in (-10, 10):
        box((1.4, 1.4, 9), (sx, 0, 4.5), post)
        box((2.0, 2.0, 0.6), (sx, 0, 9.1), trim)          # finial cap
        box((0.5, 0.5, 1.0), (sx, 0, 9.8), trim)          # finial spike
    # The sign board (text goes on its +/-Y faces).
    box((19, 0.7, 6), (0, 0, 9), board)
    # Frame around the board + a peaked pediment on top.
    box((20.4, 1.0, 0.6), (0, 0, 12.2), trim)             # top rail
    box((20.4, 1.0, 0.6), (0, 0, 5.8), trim)              # bottom rail
    box((0.7, 1.0, 6.8), (-9.7, 0, 9), trim)              # left frame
    box((0.7, 1.0, 6.8), (9.7, 0, 9), trim)               # right frame
    box((8, 1.1, 0.8), (0, 0, 12.9), trim)                # pediment base
    box((5, 1.1, 0.8), (0, 0, 13.6), trim)                # pediment step
    box((2, 1.1, 0.8), (0, 0, 14.3), trim)                # pediment top
    join_bevel(post, "SignPost")
    join_bevel(board, "SignBoard", bevel=0.0)
    join_bevel(trim, "SignTrim")
    export("WelcomeSign.fbx")


# ---------------------------------------------------------------- Kiosk
def build_kiosk():
    clear_scene()
    body, screen, sign, trim = [], [], [], []
    box((3.6, 2.6, 1.6), (0, 0, 0.8), body)               # base pedestal
    box((3.4, 1.8, 3.2), (0, 0.1, 2.7), body, rot=(-8, 0, 0))  # console (tilted back)
    box((2.7, 0.25, 2.1), (0, -0.85, 2.7), screen, rot=(-8, 0, 0))  # glowing screen (-Y)
    box((3.4, 1.9, 0.4), (0, 0, 4.5), trim)               # console top lip
    box((3.8, 0.5, 1.1), (0, 0, 5.2), sign)               # topper sign board
    box((0.4, 0.4, 1.0), (-1.7, 0, 5.2), trim)            # sign posts
    box((0.4, 0.4, 1.0), (1.7, 0, 5.2), trim)
    join_bevel(body, "KioskBody")
    join_bevel(screen, "KioskScreen", bevel=0.0)
    join_bevel(sign, "KioskSign", bevel=0.0)
    join_bevel(trim, "KioskTrim")
    export("Kiosk.fbx")


build_welcome()
build_kiosk()
print("Done. Import WelcomeSign.fbx + Kiosk.fbx -> Save assets/studio/<Name>.rbxm")
