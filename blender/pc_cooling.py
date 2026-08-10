"""
Tiered Cooling display model -> PCCooling.fbx, parts named T1_/T2_/T3_.

  T1 basic: small heatsink tower + one plain fan.
  T2 RGB:   taller tower heatsink + one RGB-ring fan.
  T3 elite: big dual-fan tower cooler with RGB rings + a lit top cap.

Stands as a tower, fans toward -Y, base at z = 0, the three looks stacked at
the origin. Run in Blender (Scripting -> Open -> Reload -> Run) ->
blender/out/PCCooling.fbx; import + save assets/studio/PCCooling.rbxm.
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


def cyl(r, depth, loc, bucket, rot=(0, 0, 0), verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    o = bpy.context.active_object
    if rot != (0, 0, 0):
        o.rotation_euler = (math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bucket.append(o)
    return o


def basic_fan(center, r, body):
    cx, cy, cz = center
    t = 0.14
    box((2 * r + 2 * t, 0.28, t), (cx, cy, cz + r + t / 2), body)
    box((2 * r + 2 * t, 0.28, t), (cx, cy, cz - r - t / 2), body)
    box((t, 0.28, 2 * r), (cx + r + t / 2, cy, cz), body)
    box((t, 0.28, 2 * r), (cx - r - t / 2, cy, cz), body)
    cyl(r * 0.9, 0.12, (cx, cy - 0.1, cz), body, rot=(90, 0, 0))
    for k in range(7):
        a = k * 2 * math.pi / 7
        box((r * 0.5, 0.04, 0.1), (cx + math.cos(a) * r * 0.4, cy - 0.16, cz + math.sin(a) * r * 0.4), body, rot=(0, 0, math.degrees(a) + 22))
    cyl(0.15, 0.2, (cx, cy - 0.18, cz), body, rot=(90, 0, 0))


def ring_fan(center, r, body, ring):
    cx, cy, cz = center
    t = 0.14
    box((2 * r + 2 * t, 0.30, t), (cx, cy, cz + r + t / 2), body)
    box((2 * r + 2 * t, 0.30, t), (cx, cy, cz - r - t / 2), body)
    box((t, 0.30, 2 * r), (cx + r + t / 2, cy, cz), body)
    box((t, 0.30, 2 * r), (cx - r - t / 2, cy, cz), body)
    cyl(r * 0.92, 0.10, (cx, cy - 0.10, cz), ring, rot=(90, 0, 0))
    cyl(r * 0.72, 0.14, (cx, cy - 0.16, cz), body, rot=(90, 0, 0))
    for k in range(7):
        a = k * 2 * math.pi / 7
        box((r * 0.55, 0.04, 0.12), (cx + math.cos(a) * r * 0.36, cy - 0.22, cz + math.sin(a) * r * 0.36), body, rot=(0, 0, math.degrees(a) + 22))
    cyl(0.16, 0.22, (cx, cy - 0.24, cz), body, rot=(90, 0, 0))


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


def fin_stack(w, d, base_z, count, gap, bucket):
    for k in range(count):
        box((w, d, 0.08), (0, 0.25, base_z + k * gap), bucket)


def build_cooling():
    clear_scene()

    # ---- T1 basic: low heatsink + 1 plain fan ----
    fn, fa = [], []
    box((1.5, 1.1, 1.9), (0, 0.25, 1.15), fn)          # fin block
    fin_stack(1.6, 1.15, 0.4, 8, 0.2, fn)               # groove plates
    basic_fan((0, -0.5, 1.15), 0.55, fa)
    join_bevel(fn, "T1_Fins", 0.02)
    join_bevel(fa, "T1_Fan", 0.02)

    # ---- T2: taller tower + RGB-ring fan ----
    fn2, fa2, rg2 = [], [], []
    box((1.7, 1.2, 3.0), (0, 0.25, 1.6), fn2)
    fin_stack(1.8, 1.25, 0.4, 13, 0.2, fn2)
    ring_fan((0, -0.58, 1.5), 0.62, fa2, rg2)
    join_bevel(fn2, "T2_Fins", 0.02)
    join_bevel(fa2, "T2_Fan", 0.02)
    join_bevel(rg2, "T2_Ring", 0.02)

    # ---- T3 elite: big dual-fan tower + RGB rings + lit top cap ----
    fn3, fa3, rg3, ac3 = [], [], [], []
    box((1.9, 1.35, 3.6), (0, 0.25, 1.9), fn3)
    fin_stack(2.0, 1.4, 0.4, 15, 0.22, fn3)
    ring_fan((0, -0.62, 1.15), 0.62, fa3, rg3)
    ring_fan((0, -0.62, 2.6), 0.62, fa3, rg3)
    box((1.6, 1.2, 0.28), (0, 0.25, 3.75), ac3)         # lit top cap
    join_bevel(fn3, "T3_Fins", 0.02)
    join_bevel(fa3, "T3_Fan", 0.02)
    join_bevel(rg3, "T3_Ring", 0.02)
    join_bevel(ac3, "T3_Accent", 0.02)

    export("PCCooling.fbx")


build_cooling()
print("Done. Import blender/out/PCCooling.fbx and save assets/studio/PCCooling.rbxm.")
