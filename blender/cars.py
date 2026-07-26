"""
M7 visual polish: three distinct car body types (Van, Truck, SportsCar) so the
traffic isn't one mesh rescaled. Same part-name convention as the base Car so
the game paints them: Body (per-instance colour), Trim (bumpers/skirt/spoiler),
Window (glass), Wheel (dark).

Built Z-up, base at Z=0, FRONT faces +X (headlights/bumper at +X) to match the
base Car so the traffic code faces them correctly. 1 unit = 1 stud.

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


def wheel(x, y, r, bucket):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=r, depth=0.5, location=(x, y, r))
    o = bpy.context.active_object
    o.rotation_euler = (math.radians(90), 0, 0)  # axis along Y so it rolls along X
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


# ---------------------------------------------------------------- Van (tall, boxy)
def build_van():
    clear_scene()
    body, trim, window, wheels = [], [], [], []
    box((6.6, 2.6, 2.6), (0, 0, 1.7), body)                 # tall body
    box((6.7, 2.7, 0.4), (0, 0, 0.55), trim)                # rocker skirt
    box((0.25, 2.2, 1.2), (3.15, 0, 2.25), window)          # windshield (+X)
    box((0.25, 2.2, 1.0), (-3.25, 0, 2.25), window)         # rear glass
    for sy in (-1.31, 1.31):
        box((3.4, 0.12, 1.0), (-0.3, sy, 2.25), window)     # side glass
    box((0.5, 2.6, 0.7), (3.4, 0, 1.0), trim)               # front bumper
    box((0.5, 2.6, 0.7), (-3.4, 0, 1.0), trim)              # rear bumper
    for sy in (-0.85, 0.85):
        box((0.2, 0.5, 0.45), (3.42, sy, 1.35), trim)       # headlights
    for sx in (-2.2, 2.2):
        for sy in (-1.35, 1.35):
            wheel(sx, sy, 0.75, wheels)
    join_bevel(body, "Body")
    join_bevel(trim, "Trim")
    join_bevel(window, "Window", bevel=0.0)
    join_bevel(wheels, "Wheel")
    export("Van.fbx")


# ---------------------------------------------------------------- Truck (pickup)
def build_truck():
    clear_scene()
    body, trim, window, wheels = [], [], [], []
    box((6.8, 2.6, 0.6), (0, 0, 0.9), trim)                 # chassis
    box((2.8, 2.5, 2.0), (1.6, 0, 2.1), body)               # cab (front)
    box((3.6, 2.5, 1.2), (-1.6, 0, 1.7), body)              # bed sides base
    box((3.6, 2.5, 0.8), (-1.6, 0, 1.5), trim)              # bed floor (lower, open top)
    for sy in (-1.15, 1.15):
        box((3.6, 0.25, 1.3), (-1.6, sy, 2.0), body)        # bed walls
    box((0.2, 2.4, 1.3), (-3.35, 0, 2.0), body)             # bed tailgate
    box((0.25, 2.2, 1.0), (3.0, 0, 2.6), window)            # windshield (+X)
    for sy in (-1.26, 1.26):
        box((2.4, 0.12, 0.9), (1.6, sy, 2.6), window)       # cab side glass
    box((0.5, 2.6, 0.8), (3.5, 0, 1.1), trim)               # front bumper
    for sy in (-0.9, 0.9):
        box((0.2, 0.5, 0.5), (3.52, sy, 1.5), trim)         # headlights
    for sx in (-2.0, 2.0):
        for sy in (-1.35, 1.35):
            wheel(sx, sy, 0.85, wheels)                     # big wheels
    join_bevel(body, "Body")
    join_bevel(trim, "Trim")
    join_bevel(window, "Window", bevel=0.0)
    join_bevel(wheels, "Wheel")
    export("Truck.fbx")


# ---------------------------------------------------------------- SportsCar (low, sleek)
def build_sports():
    clear_scene()
    body, trim, window, wheels = [], [], [], []
    box((7.2, 2.4, 1.2), (0, 0, 1.1), body)                 # long low body
    box((3.0, 2.2, 1.0), (-0.3, 0, 2.0), body)              # low cabin
    box((0.3, 2.0, 0.9), (1.15, 0, 2.0), window)            # windshield (+X)
    for sy in (-1.11, 1.11):
        box((2.4, 0.12, 0.7), (-0.3, sy, 2.05), window)     # side glass
    box((0.25, 2.0, 0.7), (-1.75, 0, 2.05), window)         # rear glass
    box((0.5, 2.5, 0.4), (3.6, 0, 0.85), trim)              # front splitter
    box((0.3, 2.6, 0.25), (-3.4, 0, 1.9), trim)             # rear spoiler wing
    for sy in (-1.0, 1.0):
        box((0.3, 0.2, 0.7), (-3.3, sy, 1.55), trim)        # spoiler supports
    for sy in (-0.75, 0.75):
        box((0.2, 0.5, 0.3), (3.62, sy, 1.15), window)      # sleek headlights
    for sx in (-2.4, 2.4):
        for sy in (-1.28, 1.28):
            wheel(sx, sy, 0.72, wheels)
    join_bevel(body, "Body")
    join_bevel(trim, "Trim")
    join_bevel(window, "Window", bevel=0.0)
    join_bevel(wheels, "Wheel")
    export("SportsCar.fbx")


build_van()
build_truck()
build_sports()
print("Done. Import Van.fbx, Truck.fbx, SportsCar.fbx -> Save assets/studio/<Name>.rbxm")
