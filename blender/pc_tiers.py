"""
Tiered PC-part display models: each category packs MULTIPLE visual "looks" into
ONE file, named with a tier prefix (T1_/T2_/T3_) so the game clones only the
look matching the player's current upgrade tier and swaps it when they buy.

  Basic (T1) -> plain, no RGB      RGB (T2) -> bigger, one glowing ring
  Elite (T3) -> biggest, full RGB, fancy

Built Z-up, upright on the short end (like the shop counter), front toward -Y,
1 unit = 1 stud, each look's base at z=0. The three looks are stacked at the
origin (they overlap in Blender -- that's expected; only one is shown in-game).

Part names: T<tier>_<Role> (e.g. T3_Shroud, T2_Ring1). The game colours by the
Role substring, so painting still works. Run in Blender (Scripting -> Open ->
Reload -> Run); it writes blender/out/PCGpu.fbx (GPU only for now). Import it and
save assets/studio/PCGpu.rbxm (overwrite the old one).
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


def basic_fan(center, r, body):
    """A plain fan (no glowing ring): square frame + dark face + hub + blades."""
    cx, cy, cz = center
    t = 0.13
    box((2 * r + 2 * t, 0.28, t), (cx, cy, cz + r + t / 2), body)
    box((2 * r + 2 * t, 0.28, t), (cx, cy, cz - r - t / 2), body)
    box((t, 0.28, 2 * r), (cx + r + t / 2, cy, cz), body)
    box((t, 0.28, 2 * r), (cx - r - t / 2, cy, cz), body)
    cyl(r * 0.9, 0.12, (cx, cy - 0.1, cz), body, rot=(90, 0, 0))  # solid dark face
    for k in range(7):
        a = k * 2 * math.pi / 7
        box((r * 0.5, 0.04, 0.1), (cx + math.cos(a) * r * 0.4, cy - 0.16, cz + math.sin(a) * r * 0.4), body, rot=(0, 0, math.degrees(a) + 22))
    cyl(0.15, 0.2, (cx, cy - 0.18, cz), body, rot=(90, 0, 0))


def ring_fan(center, r, body, ring):
    """A fan with a bright RGB ring: frame + glow ring + dark face + blades + hub."""
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
        m.segments = 2
        bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_flat()


def export(filename):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, filename), use_selection=True,
                             apply_unit_scale=True, global_scale=1.0, object_types={"MESH"})
    print("Exported:", filename)


# --------------------------------------------------------------------------
# GPU -- three looks, upright, fans on the -Y face.
#   T1 basic: thin single-fan card, no RGB.
#   T2 RGB:   dual-fan card with one RGB ring per fan + backplate.
#   T3 elite: thick triple-fan card, bright RGB rings, backplate ribs, dual
#             power connectors, lit logo bar.
# --------------------------------------------------------------------------
def build_gpu():
    clear_scene()

    # ---- T1 basic ----
    b = []
    box((1.35, 0.9, 2.6), (0, 0.05, 1.35), b)          # shroud
    box((1.4, 0.85, 0.18), (0, 0.02, 0.09), b)         # bracket
    basic_fan((0, -0.42, 1.5), 0.5, b)
    join_bevel(b, "T1_Shroud", 0.04)

    # ---- T2 RGB ----
    body, ring, back, brk = [], [], [], []
    box((1.6, 1.1, 3.4), (0, 0.05, 1.7), body)         # shroud
    box((1.65, 0.16, 3.5), (0, 0.65, 1.7), back)       # backplate
    box((1.65, 1.05, 0.2), (0, 0.03, 0.1), brk)        # bracket
    ring_fan((0, -0.55, 1.1), 0.55, body, ring)
    ring_fan((0, -0.55, 2.35), 0.55, body, ring)
    box((0.13, 0.11, 2.8), (-0.72, -0.62, 1.7), ring)  # side RGB strip
    join_bevel(body, "T2_Shroud", 0.04)
    join_bevel(back, "T2_Backplate", 0.02)
    join_bevel(brk, "T2_Bracket", 0.02)
    join_bevel(ring, "T2_Ring1", 0.02)

    # ---- T3 elite (the fancy triple-fan) ----
    sh, bk, br, ac = [], [], [], []
    r1, r2, r3 = [], [], []
    f1, f2, f3 = [], [], []
    box((1.7, 1.4, 4.2), (0, 0.05, 2.15), sh)
    box((1.82, 0.16, 4.3), (0, 0.82, 2.15), bk)
    for k in range(5):
        box((0.12, 0.06, 3.4), (-0.6 + k * 0.3, 0.92, 2.15), bk)
    box((1.72, 0.18, 0.2), (0, -0.66, 4.05), sh)
    box((1.72, 0.18, 0.2), (0, -0.66, 0.28), sh)
    box((1.72, 0.18, 0.14), (0, -0.66, 1.62), sh)
    box((1.72, 0.18, 0.14), (0, -0.66, 2.72), sh)
    for k in range(8):
        box((0.1, 1.15, 0.42), (0.86, 0.1, 0.6 + k * 0.44), sh)
    box((0.6, 0.45, 0.28), (0.55, 0.2, 4.32), sh)
    box((0.6, 0.45, 0.28), (-0.15, 0.2, 4.32), sh)
    box((1.85, 1.05, 0.22), (0, 0.05, 0.1), br)
    box((0.12, 0.14, 2.2), (0.86, -0.5, 2.6), ac)      # lit logo bar
    box((0.14, 0.12, 3.5), (-0.8, -0.7, 2.15), ac)     # side RGB strip
    ring_fan((0, -0.6, 1.05), 0.62, f1, r1)
    ring_fan((0, -0.6, 2.15), 0.62, f2, r2)
    ring_fan((0, -0.6, 3.25), 0.62, f3, r3)
    join_bevel(sh, "T3_Shroud", 0.05)
    join_bevel(bk, "T3_Backplate", 0.02)
    join_bevel(br, "T3_Bracket", 0.02)
    join_bevel(ac, "T3_Accent", 0.02)
    join_bevel(f1, "T3_Fan1", 0.02)
    join_bevel(f2, "T3_Fan2", 0.02)
    join_bevel(f3, "T3_Fan3", 0.02)
    join_bevel(r1, "T3_Ring1", 0.02)
    join_bevel(r2, "T3_Ring2", 0.02)
    join_bevel(r3, "T3_Ring3", 0.02)

    export("PCGpu.fbx")


build_gpu()
print("Done. Import blender/out/PCGpu.fbx and save assets/studio/PCGpu.rbxm (overwrite).")
