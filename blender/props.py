"""
M7 props batch: detailed street-furniture + beach models to replace the
procedural versions in Lobby.luau. Builds FIVE props and exports each to its
own FBX in blender/out/, so one Blender run gives you all of them.

Props (part names drive in-game colouring):
  StreetLamp  -> LampMetal (dark), LampLantern (warm glow)
  Bench       -> BenchWood (planks), BenchFrame (dark metal)
  TrashCan    -> CanBody, CanLid (dark)
  PalmTree    -> PalmTrunk, PalmFrond, PalmCoconut
  Umbrella    -> UmbPole (+knob), UmbCanopyA, UmbCanopyB (stripes)

Built Z-up, base at Z=0 (sits on the ground after import), 1 unit = 1 stud.
Proportions matter; final size is set in-game via a target height.

Run in Blender (Scripting -> Open -> Reload -> ▶ Run). Then in Studio import
each blender/out/<Name>.fbx and Save assets/studio/<Name>.rbxm.
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


def cyl(r, depth, loc, bucket, rot=(0, 0, 0), verts=18):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    return _finish(bpy.context.active_object, rot, bucket)


def cone(r1, r2, depth, loc, bucket, rot=(0, 0, 0), verts=18):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc)
    return _finish(bpy.context.active_object, rot, bucket)


def ball(r, loc, bucket):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=loc)
    return _finish(bpy.context.active_object, (0, 0, 0), bucket)


def join_bevel(parts, name, bevel=0.03):
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
    out = os.path.join(OUT, filename)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True,
                             apply_unit_scale=True, global_scale=1.0,
                             object_types={"MESH"})
    print("Exported:", out)


# ---------------------------------------------------------------- StreetLamp
def build_streetlamp():
    clear_scene()
    metal, glow = [], []
    box((1.7, 1.7, 0.4), (0, 0, 0.2), metal)          # foot
    box((1.2, 1.2, 0.4), (0, 0, 0.55), metal)         # step
    cyl(0.34, 0.4, (0, 0, 1.0), metal)                # collar
    cone(0.30, 0.20, 7.6, (0, 0, 4.9), metal)         # tapered post
    cyl(0.34, 0.35, (0, 0, 8.75), metal)              # top collar
    # Lantern cage: 4 dark corner posts + a glowing glass core.
    box((1.15, 1.15, 1.7), (0, 0, 9.75), glow)        # glass housing (glow)
    for sx in (-0.55, 0.55):
        for sy in (-0.55, 0.55):
            box((0.14, 0.14, 1.8), (sx, sy, 9.75), metal)  # cage edges
    box((1.35, 1.35, 0.18), (0, 0, 8.9), metal)       # lantern floor
    box((1.35, 1.35, 0.18), (0, 0, 10.6), metal)      # lantern ceiling
    cone(1.0, 0.05, 0.9, (0, 0, 11.1), metal)         # peaked cap
    ball(0.18, (0, 0, 11.7), metal)                   # finial
    join_bevel(metal, "LampMetal")
    join_bevel(glow, "LampLantern", bevel=0.0)
    export("StreetLamp.fbx")


# ---------------------------------------------------------------- Bench
def build_bench():
    clear_scene()
    wood, frame = [], []
    # Seat: 4 planks running along X (length 5), spaced along Y.
    for i, sy in enumerate((-0.75, -0.25, 0.25, 0.75)):
        box((5.0, 0.42, 0.32), (0, sy, 1.35), wood)
    # Back: 3 planks, tilted back, behind the seat (-Y).
    for i, sz in enumerate((2.1, 2.65, 3.2)):
        box((5.0, 0.32, 0.42), (0, -0.95 - (sz - 2.1) * 0.18, sz), wood, rot=(18, 0, 0))
    # Frame: legs, seat rails, armrests (dark metal).
    for sx in (-2.2, 2.2):
        box((0.34, 0.34, 1.35), (sx, 0.6, 0.68), frame)     # front leg
        box((0.34, 0.34, 1.35), (sx, -0.9, 0.68), frame)    # back leg
        box((0.34, 1.9, 0.34), (sx, -0.15, 1.9), frame)     # armrest top
        box((0.34, 0.34, 0.9), (sx, 0.75, 2.05), frame)     # arm front support
    box((4.7, 0.3, 0.3), (0, 0.7, 1.05), frame)             # front rail
    box((4.7, 0.3, 0.3), (0, -0.85, 1.05), frame)           # back rail
    join_bevel(wood, "BenchWood")
    join_bevel(frame, "BenchFrame")
    export("Bench.fbx")


# ---------------------------------------------------------------- TrashCan
def build_trashcan():
    clear_scene()
    body, lid = [], []
    cone(0.7, 0.82, 2.0, (0, 0, 1.0), body, verts=20)   # flared bin
    for k in range(8):                                   # vertical ribs
        a = math.radians(k * 45)
        box((0.1, 0.12, 1.7), (math.cos(a) * 0.78, math.sin(a) * 0.78, 1.05), body)
    cyl(0.9, 0.2, (0, 0, 2.05), lid, verts=20)          # rim
    cone(0.92, 0.42, 0.5, (0, 0, 2.4), lid, verts=20)   # domed lid
    ball(0.16, (0, 0, 2.75), lid)                        # knob
    join_bevel(body, "CanBody")
    join_bevel(lid, "CanLid")
    export("TrashCan.fbx")


# ---------------------------------------------------------------- PalmTree
def build_palmtree():
    clear_scene()
    trunk, leaves, coco = [], [], []
    # Curved trunk: stacked segments drifting in +X as they rise.
    x, z = 0.0, 0.0
    n = 7
    for i in range(n):
        r = 0.46 - i * 0.035
        h = 1.7
        cyl(r, h, (x, 0, z + h / 2), trunk, verts=12)
        x += 0.30 + i * 0.03
        z += h - 0.15
    crown = (x, 0.0, z + 0.2)
    ball(0.5, crown, trunk)                               # crown knot

    # Fronds: blades that DROOP down (rotate +about Y so the +X end dips) and
    # radiate around the crown (rotate about Z). Two rings for a full head.
    def add_frond(a, droop, length, width, out, drop):
        blade = box((length, width, 0.16), (crown[0], crown[1], crown[2]), leaves,
                    rot=(0, droop, a))
        ang = math.radians(a)
        blade.location = (crown[0] + math.cos(ang) * out,
                          crown[1] + math.sin(ang) * out,
                          crown[2] + drop)
        bpy.context.view_layer.objects.active = blade
        blade.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
        blade.select_set(False)

    for k in range(6):
        add_frond(k * 60, 24, 5.4, 1.15, 2.4, 0.05)       # upper ring, gentle droop
    for k in range(6):
        add_frond(k * 60 + 30, 46, 4.7, 1.0, 2.0, -0.55)  # lower ring, steeper droop

    for dx, dy in ((0.4, 0.3), (-0.35, 0.25), (0.1, -0.4)):   # coconuts
        ball(0.32, (crown[0] + dx, crown[1] + dy, crown[2] - 0.6), coco)
    join_bevel(trunk, "PalmTrunk")
    join_bevel(leaves, "PalmFrond", bevel=0.0)
    join_bevel(coco, "PalmCoconut")
    export("PalmTree.fbx")


# ---------------------------------------------------------------- Umbrella
def build_umbrella():
    clear_scene()
    pole, ca, cb = [], [], []
    cyl(0.16, 8.0, (0, 0, 4.0), pole, verts=12)          # pole
    ball(0.24, (0, 0, 8.1), pole)                         # top knob
    apex_z = 7.7
    for k in range(8):                                    # 8 canopy panels
        a = k * 45
        bucket = ca if k % 2 == 0 else cb
        panel = box((4.3, 1.75, 0.12), (0, 0, apex_z), bucket, rot=(0, 20, a))
        ang = math.radians(a)
        panel.location = (math.cos(ang) * 1.9, math.sin(ang) * 1.9, apex_z - 0.75)
        bpy.context.view_layer.objects.active = panel
        panel.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
        panel.select_set(False)
    join_bevel(pole, "UmbPole")
    join_bevel(ca, "UmbCanopyA", bevel=0.0)
    join_bevel(cb, "UmbCanopyB", bevel=0.0)
    export("Umbrella.fbx")


build_streetlamp()
build_bench()
build_trashcan()
build_palmtree()
build_umbrella()
print("Done. Import each blender/out/*.fbx -> Save assets/studio/<Name>.rbxm "
      "(StreetLamp, Bench, TrashCan, PalmTree, Umbrella).")
