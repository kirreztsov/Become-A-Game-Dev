"""
Tiered CPU (processor) display model: 3 looks packed into one PCCpu.fbx, named
T1_/T2_/T3_ so the game shows the one matching the player's tier and swaps it on
upgrade (same system as the GPU/Monitor/Tower).

  T1 basic: bare chip on a stand -- dark substrate + small silver heatspreader.
  T2 RGB:   bigger chip, gold contact edge, a low heatsink behind it.
  T3 elite: big gold-heatspreader chip with an RGB ring + finned heatsink.

Built Z-up, 1 unit = 1 stud, FRONT (the chip face + heatspreader) toward -Y,
base at z = 0. The three looks are stacked at the origin (they overlap in
Blender -- expected; only one shows in-game). Run in Blender (Scripting -> Open
-> Reload -> Run); writes blender/out/PCCpu.fbx. Import + save
assets/studio/PCCpu.rbxm.
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


def join_bevel(parts, name, bevel=0.03, segs=2):
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


def build_cpu():
    clear_scene()

    # ---- T1 basic: bare chip on a small stand ----
    st, ch, ih = [], [], []
    box((1.2, 0.7, 0.45), (0, 0, 0.22), st)            # stand
    box((1.3, 0.26, 1.3), (0, 0, 1.25), ch)            # chip substrate (standing)
    box((0.95, 0.12, 0.95), (0, -0.19, 1.25), ih)      # silver heatspreader (front)
    join_bevel(st, "T1_Stand", 0.03)
    join_bevel(ch, "T1_Chip", 0.03)
    join_bevel(ih, "T1_IHS", 0.02)

    # ---- T2: bigger chip, gold edge, low heatsink behind ----
    st2, ch2, ih2, ac2, fn2 = [], [], [], [], []
    box((1.4, 0.8, 0.45), (0, 0, 0.22), st2)
    box((1.6, 0.28, 1.6), (0, 0, 1.5), ch2)
    box((1.15, 0.14, 1.15), (0, -0.2, 1.5), ih2)
    box((1.62, 0.06, 0.12), (0, -0.02, 0.75), ac2)     # gold contact edge
    for k in range(5):                                  # low heatsink fins behind (+Y)
        box((1.2, 0.5, 0.08), (0, 0.5, 1.0 + k * 0.24), fn2)
    join_bevel(st2, "T2_Stand", 0.03)
    join_bevel(ch2, "T2_Chip", 0.03)
    join_bevel(ih2, "T2_IHS", 0.02)
    join_bevel(ac2, "T2_Accent", 0.02)
    join_bevel(fn2, "T2_Fins", 0.02)

    # ---- T3 elite: big gold chip + RGB ring + finned heatsink ----
    st3, ch3, ih3, ac3, fn3 = [], [], [], [], []
    box((1.6, 0.9, 0.5), (0, 0, 0.25), st3)
    box((1.9, 0.3, 1.9), (0, 0, 1.75), ch3)
    box((1.35, 0.16, 1.35), (0, -0.22, 1.75), ih3)     # gold IHS
    # RGB ring framing the heatspreader (4 thin bars on the front face)
    box((1.7, 0.08, 0.12), (0, -0.26, 1.75 + 0.78), ac3)
    box((1.7, 0.08, 0.12), (0, -0.26, 1.75 - 0.78), ac3)
    box((0.12, 0.08, 1.7), (0.78, -0.26, 1.75), ac3)
    box((0.12, 0.08, 1.7), (-0.78, -0.26, 1.75), ac3)
    for k in range(6):                                  # taller finned heatsink behind
        box((1.5, 0.6, 0.08), (0, 0.55, 1.05 + k * 0.28), fn3)
    join_bevel(st3, "T3_Stand", 0.03)
    join_bevel(ch3, "T3_Chip", 0.03)
    join_bevel(ih3, "T3_IHS", 0.02)
    join_bevel(ac3, "T3_Accent", 0.02)
    join_bevel(fn3, "T3_Fins", 0.02)

    export("PCCpu.fbx")


build_cpu()
print("Done. Import blender/out/PCCpu.fbx and save assets/studio/PCCpu.rbxm.")
