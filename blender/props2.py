"""
M7 props batch 2: a two-tier plaza fountain, a cute parked car, and a beach
lounge chair -- Blender meshes to replace/augment procedural bits in Lobby.luau.

Props (part names drive in-game colouring):
  Fountain     -> FountainStone (basin/tiers/column), FountainWater (pools)
  Car          -> CarBody (per-instance colour), CarWheel (dark), CarWindow
                  (tinted glass), CarTrim (bumpers/lights)
  LoungeChair  -> LoungeFrame (cream slats), LoungeLeg (wood)

Built Z-up, base at Z=0, 1 unit = 1 stud. Final size set in-game.

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


def cyl(r, depth, loc, bucket, rot=(0, 0, 0), verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    return _finish(bpy.context.active_object, rot, bucket)


def cone(r1, r2, depth, loc, bucket, rot=(0, 0, 0), verts=24):
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


# ---------------------------------------------------------------- Fountain
def build_fountain():
    clear_scene()
    stone, water = [], []
    # Lower basin: stone ring wall + a wide water pool inside.
    cyl(6.2, 1.4, (0, 0, 0.7), stone)                 # basin body
    cyl(6.4, 0.5, (0, 0, 1.35), stone)                # basin rim lip
    cyl(5.5, 0.4, (0, 0, 1.25), water)                # lower water pool
    # Central pedestal + upper tier bowl + upper pool.
    cyl(1.3, 3.0, (0, 0, 2.9), stone)                 # pedestal column
    cone(2.9, 2.4, 0.7, (0, 0, 4.4), stone)           # upper bowl underside
    cyl(2.6, 0.5, (0, 0, 4.8), stone)                 # upper bowl rim
    cyl(2.2, 0.35, (0, 0, 4.85), water)               # upper water pool
    cyl(0.55, 1.7, (0, 0, 5.7), stone)                # top stem
    ball(0.7, (0, 0, 6.6), stone)                     # top finial
    # A little water jet spouting from the top.
    cone(0.35, 0.12, 1.1, (0, 0, 6.6), water)
    join_bevel(stone, "FountainStone")
    join_bevel(water, "FountainWater", bevel=0.0)
    export("Fountain.fbx")


# ---------------------------------------------------------------- Car
def build_car():
    clear_scene()
    body, wheel, window, trim = [], [], [], []
    # Lower body + rounded-ish cabin (front is -Y).
    box((6.4, 2.6, 1.3), (0, 0, 1.05), body)          # main body
    box((3.4, 2.4, 1.15), (-0.2, 0, 2.15), body)      # cabin
    box((6.5, 2.5, 0.35), (0, 0, 0.5), trim)          # rocker / lower trim
    # Windows: windshield, rear, and side glass on the cabin.
    box((0.25, 2.1, 0.95), (1.5, 0, 2.15), window)    # windshield (front)
    box((0.25, 2.1, 0.95), (-1.9, 0, 2.15), window)   # rear glass
    for sy in (-1.21, 1.21):
        box((2.6, 0.12, 0.9), (-0.2, sy, 2.15), window)  # side windows
    # Bumpers + headlights + taillights.
    box((0.4, 2.5, 0.6), (3.25, 0, 0.9), trim)        # front bumper
    box((0.4, 2.5, 0.6), (-3.25, 0, 0.9), trim)       # rear bumper
    for sy in (-0.85, 0.85):
        box((0.15, 0.5, 0.4), (3.35, sy, 1.2), trim)  # headlight
    # Wheels: axis along Y so they roll along X.
    for sx in (-2.2, 2.2):
        for sy in (-1.35, 1.35):
            cyl(0.75, 0.55, (sx, sy, 0.75), wheel, rot=(90, 0, 0), verts=16)
    join_bevel(body, "CarBody")
    join_bevel(trim, "CarTrim")
    join_bevel(window, "CarWindow", bevel=0.0)
    join_bevel(wheel, "CarWheel")
    export("Car.fbx")


# ---------------------------------------------------------------- LoungeChair
def build_lounge():
    clear_scene()
    frame, leg = [], []
    # Flat seat slats + a reclined back, on short wooden legs. Long axis = Y.
    for sy in (-1.6, -0.8, 0.0, 0.8, 1.6):
        box((2.4, 0.5, 0.16), (0, sy, 1.05), frame)          # seat slats
    for i, sy in enumerate((2.1, 2.7, 3.3)):
        box((2.4, 0.5, 0.16), (0, sy - (sy - 2.1) * 0.0, 1.05 + (sy - 2.1) * 0.62), frame, rot=(38, 0, 0))
    box((2.5, 0.28, 0.28), (0, -1.7, 1.05), frame)           # front rail
    box((2.5, 0.28, 0.28), (0, 1.7, 1.05), frame)            # mid rail
    for sx in (-1.05, 1.05):
        for sy in (-1.5, 1.5):
            box((0.26, 0.26, 1.0), (sx, sy, 0.5), leg)       # legs
    join_bevel(frame, "LoungeFrame")
    join_bevel(leg, "LoungeLeg")
    export("LoungeChair.fbx")


build_fountain()
build_car()
build_lounge()
print("Done. Import each blender/out/*.fbx -> Save assets/studio/<Name>.rbxm "
      "(Fountain, Car, LoungeChair).")
