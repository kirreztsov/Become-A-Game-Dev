"""
Tiered RAM (memory) display model -> PCRam.fbx, parts named T1_/T2_/T3_.

  T1 basic: bare green stick with gold contacts + a few chips.
  T2 RGB:   stick with a black heatspreader + toothed top.
  T3 elite: heatspreader stick with a glowing RGB light bar on top (gamer RAM).

Stood on its short end (tall) so it reads on the counter, FRONT toward -Y, base
at z = 0, the three looks stacked at the origin. Run in Blender (Scripting ->
Open -> Reload -> Run) -> blender/out/PCRam.fbx; import + save
assets/studio/PCRam.rbxm.
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


def build_ram():
    clear_scene()

    # ---- T1 basic: bare green stick ----
    pcb, co, ch = [], [], []
    box((1.0, 0.14, 2.4), (0, 0, 1.3), pcb)
    box((0.95, 0.18, 0.2), (0, 0, 0.15), co)           # gold contacts
    for k in range(4):
        box((0.72, 0.06, 0.34), (0, -0.1, 0.8 + k * 0.48), ch)  # chips
    join_bevel(pcb, "T1_PCB", 0.02)
    join_bevel(co, "T1_Contacts", 0.02)
    join_bevel(ch, "T1_Chip", 0.02)

    # ---- T2: heatspreader stick ----
    pcb2, co2, sp2 = [], [], []
    box((1.05, 0.16, 2.9), (0, 0, 1.55), pcb2)
    box((1.0, 0.2, 0.2), (0, 0, 0.15), co2)
    box((1.05, 0.26, 2.3), (0, -0.06, 1.75), sp2)      # heatspreader face
    for k in range(5):                                  # toothed top comb
        box((0.14, 0.26, 0.3), (-0.42 + k * 0.21, -0.06, 3.0), sp2)
    join_bevel(pcb2, "T2_PCB", 0.02)
    join_bevel(co2, "T2_Contacts", 0.02)
    join_bevel(sp2, "T2_Spreader", 0.02)

    # ---- T3 elite: heatspreader + glowing RGB bar ----
    pcb3, co3, sp3, ac3 = [], [], [], []
    box((1.1, 0.18, 3.1), (0, 0, 1.65), pcb3)
    box((1.05, 0.22, 0.2), (0, 0, 0.15), co3)
    box((1.1, 0.3, 2.4), (0, -0.07, 1.8), sp3)         # heatspreader
    box((0.9, 0.34, 0.4), (0, -0.05, 3.25), ac3)       # RGB diffuser bar on top
    join_bevel(pcb3, "T3_PCB", 0.02)
    join_bevel(co3, "T3_Contacts", 0.02)
    join_bevel(sp3, "T3_Spreader", 0.02)
    join_bevel(ac3, "T3_Accent", 0.02)

    export("PCRam.fbx")


build_ram()
print("Done. Import blender/out/PCRam.fbx and save assets/studio/PCRam.rbxm.")
