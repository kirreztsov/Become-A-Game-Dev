"""
Tiered CPU (processor) display model -> PCCpu.fbx, parts named T1_/T2_/T3_.
Reads clearly as a CPU chip: green PCB substrate, a metal heatspreader (IHS)
with engraving + brand, a gold contact frame, a corner notch, and (elite) a
gold pin grid on the back + an RGB base glow.

  T1 basic: small chip, IHS + green notch, no gold/RGB.
  T2 RGB:   gold contact frame + brand square.
  T3 elite: bigger, + RGB base glow + gold pin grid on the back.

Stood upright on a stand, FRONT (IHS face) toward -Y, base at z = 0; the three
looks stacked at the origin. Run in Blender (Scripting -> Open -> Reload ->
Run) -> blender/out/PCCpu.fbx; import + save assets/studio/PCCpu.rbxm.
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


def chip(prefix, w, cz, gold, rgb, pins):
    pcb, ihs, gld, ac, stand = [], [], [], [], []
    half = w / 2.0
    # Chunky pedestal whose top OVERLAPS the chip's bottom (so it's one connected
    # piece, not a chip floating above a stand), plus a front lip that grips it.
    box((w * 0.8, 1.0, 1.1), (0, 0, 0.55), stand)                      # pedestal (top ~1.1)
    box((w * 0.9, 0.5, 0.35), (0, -0.15, 1.0), stand)                  # front mount lip
    box((w, 0.24, w), (0, 0, cz), pcb)                                 # PCB substrate
    box((w * 0.74, 0.18, w * 0.74), (0, -0.2, cz), ihs)                # heatspreader
    box((w * 0.45, 0.05, 0.04), (0, -0.31, cz + 0.22), ihs)            # engraving line
    box((w * 0.45, 0.05, 0.04), (0, -0.31, cz + 0.02), ihs)            # engraving line
    if gold:
        box((0.4, 0.07, 0.4), (-w * 0.18, -0.31, cz - 0.3), gld)       # brand square
        box((w - 0.2, 0.06, 0.08), (0, -0.14, cz + (half - 0.12)), gld)   # frame top
        box((w - 0.2, 0.06, 0.08), (0, -0.14, cz - (half - 0.12)), gld)   # frame bottom
        box((0.08, 0.06, w - 0.2), (half - 0.12, -0.14, cz), gld)         # frame right
        box((0.08, 0.06, w - 0.2), (-(half - 0.12), -0.14, cz), gld)      # frame left
    # corner notch marker (gold on gold-tiers, else part of the board)
    box((0.24, 0.26, 0.24), (-(half - 0.02), 0, cz - (half - 0.02)), gld if gold else pcb)
    if pins:  # gold pin grid on the back (+Y)
        n = 6
        for ix in range(n):
            for iz in range(n):
                px = -half * 0.7 + ix * (w * 0.7 / (n - 1))
                pz = cz - half * 0.7 + iz * (w * 0.7 / (n - 1))
                box((0.08, 0.1, 0.08), (px, 0.16, pz), gld)
    if rgb:
        box((w + 0.05, 0.16, 0.16), (0, -0.18, cz - half + 0.12), ac)  # RGB glow hugging the chip base
    join_bevel(pcb, prefix + "PCB", 0.02)
    join_bevel(ihs, prefix + "IHS", 0.03)
    join_bevel(gld, prefix + "Gold", 0.02)
    join_bevel(ac, prefix + "Accent", 0.02)
    join_bevel(stand, prefix + "Stand", 0.03)


def build_cpu():
    clear_scene()
    chip("T1_", 1.6, 1.65, gold=False, rgb=False, pins=False)
    chip("T2_", 1.8, 1.75, gold=True, rgb=False, pins=False)
    chip("T3_", 2.0, 1.85, gold=True, rgb=True, pins=True)
    export("PCCpu.fbx")


build_cpu()
print("Done. Import blender/out/PCCpu.fbx and save assets/studio/PCCpu.rbxm.")
