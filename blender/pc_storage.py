"""
Tiered Storage display model -> PCStorage.fbx, parts named T1_/T2_/T3_.

  T1 basic: chunky 3.5" HDD (metal box + label) on a stand.
  T2 RGB:   slim 2.5" SSD (flatter box + label + brand accent) on a stand.
  T3 elite: M.2 NVMe stick with a finned RGB heatsink.

Drives stand upright on a small stand so they read on the counter, FRONT (label
face) toward -Y, base at z = 0, the three looks stacked at the origin. Run in
Blender (Scripting -> Open -> Reload -> Run) -> blender/out/PCStorage.fbx;
import + save assets/studio/PCStorage.rbxm.
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


def join_bevel(parts, name, bevel=0.02, segs=2):
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


def build_storage():
    clear_scene()

    # ---- T1 basic: 3.5" HDD on a stand ----
    st, bd, lb = [], [], []
    box((1.1, 0.7, 0.45), (0, 0, 0.22), st)             # stand
    box((2.4, 0.55, 1.55), (0, 0, 1.25), bd)            # HDD metal body (standing)
    for sx in (-1.0, 1.0):                               # corner screws
        for sz in (0.6, 1.9):
            box((0.14, 0.1, 0.14), (sx, -0.28, sz), bd)
    box((1.8, 0.06, 1.0), (0, -0.3, 1.35), lb)          # label
    join_bevel(st, "T1_Stand", 0.03)
    join_bevel(bd, "T1_Body", 0.03)
    join_bevel(lb, "T1_Label", 0.02)

    # ---- T2: slim 2.5" SSD on a stand ----
    st2, bd2, lb2, ac2 = [], [], [], []
    box((1.1, 0.7, 0.45), (0, 0, 0.22), st2)
    box((2.0, 0.32, 1.35), (0, 0, 1.15), bd2)           # slim body
    box((1.6, 0.06, 0.9), (0, -0.19, 1.25), lb2)        # label
    box((1.6, 0.07, 0.12), (0, -0.19, 0.7), ac2)        # brand accent strip
    join_bevel(st2, "T2_Stand", 0.03)
    join_bevel(bd2, "T2_Body", 0.03)
    join_bevel(lb2, "T2_Label", 0.02)
    join_bevel(ac2, "T2_Accent", 0.02)

    # ---- T3 elite: M.2 NVMe stick + finned RGB heatsink ----
    st3, bd3, fn3, ac3 = [], [], [], []
    box((0.9, 0.6, 0.4), (0, 0, 0.2), st3)              # small stand
    box((0.75, 0.14, 2.6), (0, 0.06, 1.4), bd3)         # NVMe PCB stick
    box((0.8, 0.3, 2.1), (0, -0.08, 1.55), fn3)         # heatsink block
    for k in range(6):                                   # heatsink fin grooves
        box((0.82, 0.32, 0.06), (0, -0.08, 0.7 + k * 0.32), st3)
    box((0.6, 0.34, 0.35), (0, -0.06, 2.75), ac3)       # RGB strip on top
    join_bevel(st3, "T3_Stand", 0.02)
    join_bevel(bd3, "T3_Body", 0.02)
    join_bevel(fn3, "T3_Fins", 0.02)
    join_bevel(ac3, "T3_Accent", 0.02)

    export("PCStorage.fbx")


build_storage()
print("Done. Import blender/out/PCStorage.fbx and save assets/studio/PCStorage.rbxm.")
