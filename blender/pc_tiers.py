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


# --------------------------------------------------------------------------
# MONITOR -- three looks, screen toward -Y, base at z=0.
#   T1 basic: small flat 16:9 on a simple stand.
#   T2 RGB:   wider slightly-curved 21:9, thin bezel, chin RGB strip.
#   T3 elite: super-ultrawide curved (11 arc segments) + tripod + rear RGB.
# Screen segments are named T<t>_Screen<n> so the game paints a gradient.
# --------------------------------------------------------------------------
def build_monitor():
    clear_scene()

    # ---- T1 basic ----
    bz, sc, nk, ba = [], [], [], []
    box((3.2, 0.2, 2.0), (0, 0.05, 2.6), bz)
    box((2.9, 0.08, 1.7), (0, -0.09, 2.6), sc)
    box((0.45, 0.45, 1.2), (0, 0.12, 1.4), nk)
    box((1.7, 1.1, 0.16), (0, 0.12, 0.08), ba)
    join_bevel(bz, "T1_Bezel", 0.03)
    join_bevel(sc, "T1_Screen", 0.02)
    join_bevel(nk, "T1_Neck", 0.04)
    join_bevel(ba, "T1_Base", 0.04)

    # ---- T2 curved 21:9 ----
    bz2, nk2, ba2, ac2 = [], [], [], []
    SZ2, PH2, HALF2, SEGS2 = 2.9, 2.2, 3.0, 5
    sw2 = (2 * HALF2) / SEGS2
    for i in range(SEGS2):
        x = -HALF2 + sw2 * (i + 0.5)
        t = x / HALF2
        y = 0.12 - 0.35 * (t * t)
        rz = -14.0 * t
        box((sw2 + 0.10, 0.20, PH2 + 0.16), (x, y + 0.12, SZ2), bz2, rot=(0, 0, rz))
        seg = []
        box((sw2 + 0.01, 0.09, PH2), (x, y, SZ2), seg, rot=(0, 0, rz))
        join_bevel(seg, "T2_Screen" + str(i + 1), 0.02)
    box((2.6, 0.10, 0.14), (0, -0.16, SZ2 - PH2 / 2 - 0.03), ac2)
    box((0.5, 0.5, 1.2), (0, 0.15, 1.3), nk2)
    box((2.0, 1.1, 0.16), (0, 0.15, 0.08), ba2)
    join_bevel(bz2, "T2_Bezel", 0.03)
    join_bevel(nk2, "T2_Neck", 0.04)
    join_bevel(ba2, "T2_Base", 0.04)
    join_bevel(ac2, "T2_Accent", 0.02)

    # ---- T3 elite ultrawide ----
    bz3, nk3, ba3, ac3 = [], [], [], []
    SZ, PH, HALF, SEGS = 3.4, 2.3, 4.0, 11
    sw = (2 * HALF) / SEGS
    for i in range(SEGS):
        x = -HALF + sw * (i + 0.5)
        t = x / HALF
        y = 0.15 - 0.55 * (t * t)
        rz = -18.0 * t
        box((sw + 0.12, 0.24, PH + 0.20), (x, y + 0.14, SZ), bz3, rot=(0, 0, rz))
        box((sw + 0.02, 0.06, 0.14), (x, y + 0.30, SZ + 0.75), ac3, rot=(0, 0, rz))
        seg = []
        box((sw + 0.01, 0.10, PH), (x, y, SZ), seg, rot=(0, 0, rz))
        join_bevel(seg, "T3_Screen" + str(i + 1), 0.02)
    box((0.9, 0.10, 0.14), (0, -0.20, SZ - PH / 2 - 0.02), ac3)
    box((0.55, 0.7, 2.0), (0, 0.35, 1.35), nk3)
    box((1.0, 1.0, 0.22), (0, 0.35, 0.11), ba3)
    box((2.4, 0.5, 0.18), (0.85, -0.45, 0.09), ba3, rot=(0, 0, -30))
    box((2.4, 0.5, 0.18), (-0.85, -0.45, 0.09), ba3, rot=(0, 0, 30))
    box((1.5, 0.5, 0.18), (0, 1.15, 0.09), ba3)
    join_bevel(bz3, "T3_Bezel", 0.03)
    join_bevel(nk3, "T3_Neck", 0.04)
    join_bevel(ba3, "T3_Base", 0.04)
    join_bevel(ac3, "T3_Accent", 0.02)

    export("PCMonitor.fbx")


# --------------------------------------------------------------------------
# TOWER -- three looks, front toward -Y, base at z=0.
#   T1 basic: plain solid case, no glass/RGB.
#   T2 RGB:   case with a side window + 2 front RGB fans + a light strip.
#   T3 elite: full glass side, mesh front, 3 RGB fans, internals.
# --------------------------------------------------------------------------
def build_tower():
    clear_scene()

    # ---- T1 basic ----
    c1, ft1 = [], []
    box((2.2, 4.4, 4.2), (0, 0, 2.3), c1)
    box((2.2, 0.14, 4.2), (0, -2.2, 2.3), c1)          # solid front
    box((0.3, 0.2, 0.12), (0.5, -2.28, 3.9), c1)       # power button nub
    for fx in (-0.8, 0.8):
        for fy in (-1.7, 1.7):
            box((0.4, 0.4, 0.3), (fx, fy, 0.15), ft1)
    join_bevel(c1, "T1_Case", 0.05)
    join_bevel(ft1, "T1_Feet", 0.03)

    # ---- T2 window + 2 fans ----
    c2, fr2, gl2, ft2, ac2, r2a, r2b = [], [], [], [], [], [], []
    box((2.2, 4.4, 4.2), (0, 0, 2.3), c2)
    box((0.10, 3.6, 3.4), (-1.12, 0, 2.3), gl2)        # side window
    box((2.2, 0.12, 4.2), (0, -2.22, 2.3), fr2)        # front panel
    ring_fan((0, -1.95, 1.6), 0.55, fr2, r2a)
    ring_fan((0, -1.95, 3.0), 0.55, fr2, r2b)
    box((0.12, 0.12, 3.4), (-1.05, -2.2, 2.3), ac2)    # RGB strip
    for fx in (-0.8, 0.8):
        for fy in (-1.7, 1.7):
            box((0.4, 0.4, 0.3), (fx, fy, 0.15), ft2)
    join_bevel(c2, "T2_Case", 0.05)
    join_bevel(fr2, "T2_Front", 0.02)
    join_bevel(gl2, "T2_Glass", 0.02)
    join_bevel(ft2, "T2_Feet", 0.03)
    join_bevel(ac2, "T2_Accent", 0.02)
    join_bevel(r2a, "T2_Ring1", 0.02)
    join_bevel(r2b, "T2_Ring2", 0.02)

    # ---- T3 elite (glass + mesh front + 3 fans + internals) ----
    c3, fr3, gl3, ft3, ac3, bd3, co3 = [], [], [], [], [], [], []
    f1, f2, f3, r1, r2, r3 = [], [], [], [], [], []
    box((2.2, 4.6, 4.4), (0, 0.0, 2.55), c3)
    box((0.10, 4.2, 4.0), (-1.12, 0.0, 2.55), gl3)
    box((2.2, 0.20, 0.22), (0, -2.30, 4.70), fr3)      # bezel top
    box((2.2, 0.20, 0.22), (0, -2.30, 0.40), fr3)      # bezel bottom
    box((0.22, 0.20, 4.5), (-1.0, -2.30, 2.55), fr3)
    box((0.22, 0.20, 4.5), (1.0, -2.30, 2.55), fr3)
    ring_fan((0, -2.18, 1.35), 0.62, f1, r1)
    ring_fan((0, -2.18, 2.55), 0.62, f2, r2)
    ring_fan((0, -2.18, 3.75), 0.62, f3, r3)
    for zz in (0.95, 1.75, 2.15, 2.95, 3.35, 4.15):
        box((1.9, 0.10, 0.08), (0, -2.44, zz), fr3)
    box((0.12, 0.12, 3.6), (-0.92, -2.0, 2.55), ac3)
    box((0.10, 3.2, 3.2), (0.62, 0.2, 2.9), bd3)       # motherboard
    box((0.7, 2.4, 0.5), (0.2, 0.0, 1.7), bd3)         # inner GPU
    for rz in (0.75, 1.05, 1.35, 1.65):
        box((0.16, 0.35, 1.1), (0.28, rz, 3.6), bd3)   # RAM
    cyl(0.55, 0.5, (0.25, 0.4, 3.5), co3, rot=(0, 90, 0))
    for fx in (-0.8, 0.8):
        for fy in (-1.8, 1.8):
            box((0.4, 0.4, 0.3), (fx, fy, 0.15), ft3)
    join_bevel(c3, "T3_Case", 0.06)
    join_bevel(fr3, "T3_Front", 0.02)
    join_bevel(gl3, "T3_Glass", 0.02)
    join_bevel(ft3, "T3_Feet", 0.03)
    join_bevel(ac3, "T3_Accent", 0.02)
    join_bevel(bd3, "T3_InnerBoard", 0.02)
    join_bevel(co3, "T3_Cooler", 0.03)
    join_bevel(f1, "T3_Fan1", 0.02)
    join_bevel(f2, "T3_Fan2", 0.02)
    join_bevel(f3, "T3_Fan3", 0.02)
    join_bevel(r1, "T3_Ring1", 0.02)
    join_bevel(r2, "T3_Ring2", 0.02)
    join_bevel(r3, "T3_Ring3", 0.02)

    export("PCTower.fbx")


build_gpu()
build_monitor()
build_tower()
print("Done. Import PCGpu.fbx, PCMonitor.fbx, PCTower.fbx (overwrite the 3 rbxm files).")
