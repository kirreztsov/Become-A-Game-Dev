"""
Tiered RAM (memory) display model -> PCRam.fbx, parts named T1_/T2_/T3_.

  T1 basic: bare green stick -- gold contacts + visible black memory chips.
  T2 RGB:   black heatspreader with a toothed top comb.
  T3 elite: heatspreader + a 4-segment multi-colour RGB diffuser bar on top.

Stood on its gold contacts, FRONT toward -Y, base at z = 0; the three looks
stacked at the origin. Run in Blender (Scripting -> Open -> Reload -> Run) ->
blender/out/PCRam.fbx; import + save assets/studio/PCRam.rbxm.
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


def stick(prefix, spreader, rgb):
    pcb, co, ch, sp = [], [], [], []
    box((1.0, 0.16, 2.5), (0, 0, 1.3), pcb)                    # PCB
    box((0.95, 0.22, 0.22), (0, 0, 0.16), co)                  # gold contacts
    box((0.14, 0.24, 0.24), (0.05, 0, 0.16), pcb)              # contact notch gap
    if not spreader:
        for k in range(4):
            box((0.66, 0.06, 0.32), (0, -0.1, 0.7 + k * 0.45), ch)   # visible memory chips (T1)
    else:
        box((1.06, 0.26, 2.0), (0, -0.06, 1.45), sp)           # heatspreader
        for k in range(5):
            box((0.14, 0.26, 0.3), (-0.42 + k * 0.21, -0.06, 2.55), sp)  # toothed top comb
    join_bevel(pcb, prefix + "PCB", 0.02)
    join_bevel(co, prefix + "Contacts", 0.02)
    join_bevel(ch, prefix + "Chip", 0.02)
    join_bevel(sp, prefix + "Spreader", 0.02)
    if rgb:
        for k in range(4):
            seg = []
            box((0.22, 0.34, 0.34), (-0.33 + k * 0.22, -0.04, 2.85), seg)  # RGB diffuser segment
            join_bevel(seg, prefix + "Accent" + str(k + 1), 0.02)


def build_ram():
    clear_scene()
    stick("T1_", spreader=False, rgb=False)
    stick("T2_", spreader=True, rgb=False)
    stick("T3_", spreader=True, rgb=True)
    export("PCRam.fbx")


build_ram()
print("Done. Import blender/out/PCRam.fbx and save assets/studio/PCRam.rbxm.")
