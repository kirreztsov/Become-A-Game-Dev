"""
Tiered Storage display model -> PCStorage.fbx, parts named T1_/T2_/T3_.
Form-factor progression: HDD -> SSD -> NVMe.

  T1 basic: 3.5" HDD -- metal box, label, corner screws.
  T2 RGB:   2.5" SSD -- slim metal box, label, accent stripe.
  T3 elite: M.2 NVMe -- PCB + gold connector + finned heatsink + front RGB strip.

FRONT (label / heatsink face) toward -Y, base at z = 0; the three looks stacked
at the origin. Run in Blender (Scripting -> Open -> Reload -> Run) ->
blender/out/PCStorage.fbx; import + save assets/studio/PCStorage.rbxm.
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

    # ---- T1: 3.5" HDD ----
    bd, lb = [], []
    box((2.0, 0.62, 1.5), (0, 0, 0.8), bd)                     # metal body
    box((2.02, 0.64, 0.1), (0, 0, 1.5), bd)                    # top lid seam
    for sx in (-0.85, 0.85):                                    # corner screws
        for sz in (0.2, 1.4):
            box((0.14, 0.1, 0.14), (sx, -0.32, sz), bd)
    box((1.4, 0.06, 0.85), (0, -0.33, 0.85), lb)               # paper label
    join_bevel(bd, "T1_Body", 0.03)
    join_bevel(lb, "T1_Label", 0.02)

    # ---- T2: 2.5" SSD ----
    bd2, lb2, ac2 = [], [], []
    box((1.7, 0.32, 1.15), (0, 0, 0.65), bd2)                  # slim body
    box((1.2, 0.06, 0.6), (0, -0.17, 0.75), lb2)               # label
    box((1.2, 0.07, 0.1), (0, -0.17, 0.4), ac2)                # accent stripe
    join_bevel(bd2, "T2_Body", 0.03)
    join_bevel(lb2, "T2_Label", 0.02)
    join_bevel(ac2, "T2_Accent", 0.02)

    # ---- T3: M.2 NVMe with finned RGB heatsink ----
    pcb, co, ch, fn, ac3 = [], [], [], [], []
    box((0.72, 0.16, 2.5), (0, 0, 1.35), pcb)                  # PCB
    box((0.6, 0.22, 0.22), (0, 0, 0.15), co)                   # gold connector
    box((0.14, 0.24, 0.24), (0.02, 0, 0.15), pcb)              # connector notch
    box((0.5, 0.16, 0.32), (0, -0.1, 0.55), ch)                # exposed controller chip
    box((0.82, 0.3, 1.7), (0, -0.08, 1.65), fn)                # heatsink block
    for k in range(7):                                          # fin grooves
        box((0.86, 0.34, 0.06), (0, -0.08, 0.9 + k * 0.24), fn)
    box((0.12, 0.09, 1.4), (0, -0.26, 1.65), ac3)              # RGB strip on the FRONT
    join_bevel(pcb, "T3_PCB", 0.02)
    join_bevel(co, "T3_Contacts", 0.02)
    join_bevel(ch, "T3_Chip", 0.02)
    join_bevel(fn, "T3_Fins", 0.02)
    join_bevel(ac3, "T3_Accent", 0.02)

    export("PCStorage.fbx")


build_storage()
print("Done. Import blender/out/PCStorage.fbx and save assets/studio/PCStorage.rbxm.")
