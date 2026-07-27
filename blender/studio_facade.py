"""
M7 - Premium, HIGHLY DETAILED studio front facade (tier 0 base).

Raised window frames + sills + cross mullions, an awning over every window,
corner pilasters, a layered cornice, a base course, a recessed entrance portal,
and window flower boxes + ground planters filled with REAL detailed flowers of
several species (daisy / marigold / tulip / rose) -- petals radiating around a
centre on little stems, not plain bulbs. A light Bevel rounds every edge.

Colour groups (game paints by name):
  Body(walls) Accent(portal/awnings) Trim(frames/sills/pillars/cornice)
  Win(glass) Planter(wood) Stem(green) Center(yellow) FlowerA/B/C (red/yellow/pink)

Run in Blender (Scripting -> Open -> Reload if edited -> ▶ Run). Exports
blender/out/StudioFacade.fbx -> overwrite assets/studio/StudioFacade.rbxm.
1 unit = 1 stud, Z up. Origin (0,0,0) = door base centre at wall plane, front -Y.
"""

import bpy
import os
import math

TH = 1.0
FRONT = -TH / 2

body, accent, trim, win, planter, stem, center = [], [], [], [], [], [], []
fa, fb, fc = [], [], []  # petal colour buckets (red / yellow / pink)


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
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bucket.append(o)
    return o


def ico(r, loc, bucket, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bucket.append(o)
    return o


def join_bevel(parts, name, bevel=0.05):
    if not parts:
        return
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    if bevel > 0:
        m = obj.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = 1
        bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_flat()


def flower(cx, cy, cz, species, petals):
    """A detailed flower head in the X-Z plane facing -Y, on a short green stem.
    species: 0 daisy, 1 marigold, 2 tulip, 3 rose."""
    box((0.07, 0.5, 0.07), (cx, cy + 0.15, cz - 0.45), stem)  # stem
    if species == 0:  # DAISY: yellow disc centre + 9 slim white-ish petals
        ico(0.16, (cx, cy - 0.02, cz), center, (1, 0.6, 1))
        for i in range(9):
            a = i / 9 * 2 * math.pi
            r = 0.34
            box((0.4, 0.06, 0.14), (cx + math.cos(a) * r, cy - 0.02, cz + math.sin(a) * r),
                petals, rot=(0, a, 0))
    elif species == 1:  # MARIGOLD: bushy, two rings of short rounded petals
        ico(0.14, (cx, cy - 0.05, cz), center, (1, 0.6, 1))
        for ring, (rr, n, pl) in enumerate(((0.24, 8, 0.26), (0.34, 8, 0.24))):
            for i in range(n):
                a = i / n * 2 * math.pi + ring * 0.4
                ico(pl, (cx + math.cos(a) * rr, cy - 0.04, cz + math.sin(a) * rr),
                    petals, (1.2, 0.5, 0.9))
    elif species == 2:  # TULIP: 5 upright cupped petals, no flat centre
        for i in range(5):
            a = i / 5 * 2 * math.pi
            r = 0.13
            box((0.16, 0.5, 0.28), (cx + math.cos(a) * r, cy - 0.02, cz + 0.18 + math.sin(a) * r),
                petals, rot=(math.radians(18) * math.sin(a), 0, math.radians(18) * math.cos(a)))
    else:  # ROSE: tight layered rounded petals
        ico(0.16, (cx, cy - 0.04, cz), petals, (1, 0.5, 1))
        for i in range(5):
            a = i / 5 * 2 * math.pi
            ico(0.16, (cx + math.cos(a) * 0.2, cy - 0.02, cz + math.sin(a) * 0.2),
                petals, (1.1, 0.5, 0.8))


def flower_row(cx, cy, cz, n, w):
    """A row of `n` flowers with varied species + colours in a box."""
    buckets = (fa, fb, fc)
    for i in range(n):
        fx = cx - w / 2 + (i + 0.5) * (w / max(1, n))
        flower(fx, cy, cz, (i * 3 + int(cx)) % 4, buckets[(i + int(cz)) % 3])


def window(cx, cz, w, h):
    box((w, 0.3, h), (cx, FRONT + 0.02, cz), win)                 # glass
    b = 0.32
    fy = FRONT - 0.18
    box((w + 2 * b, 0.34, b), (cx, fy, cz + h / 2 + b / 2), trim)  # frame top
    box((w + 2 * b, 0.34, b), (cx, fy, cz - h / 2 - b / 2), trim)  # frame bottom
    box((b, 0.34, h + 2 * b), (cx - w / 2 - b / 2, fy, cz), trim)  # frame left
    box((b, 0.34, h + 2 * b), (cx + w / 2 + b / 2, fy, cz), trim)  # frame right
    box((0.16, 0.24, h), (cx, FRONT - 0.30, cz), trim)            # vertical mullion
    box((w, 0.24, 0.16), (cx, FRONT - 0.30, cz), trim)            # horizontal mullion
    box((w + 1.4, 1.4, 0.35), (cx, FRONT - 0.7, cz + h / 2 + 0.9), accent)  # awning
    box((w + 1.0, 0.5, 0.35), (cx, FRONT - 0.28, cz - h / 2 - b), trim)     # sill
    box((w + 0.6, 0.9, 0.9), (cx, FRONT - 0.55, cz - h / 2 - 1.1), planter)  # flower box
    flower_row(cx, FRONT - 0.95, cz - h / 2 - 0.55, max(3, int(w)), w)       # flowers


def build():
    clear_scene()
    box((21, TH, 12), (-13.5, 0, 6), body)   # left panel
    box((21, TH, 12), (13.5, 0, 6), body)    # right panel
    box((6, TH, 5), (0, 0, 9.5), body)       # lintel over door

    for sx in (-24, 24):                      # corner pilasters
        box((1.4, TH + 0.7, 12), (sx, 0, 6), trim)
    box((50, TH + 1.0, 0.7), (0, -0.1, 11.5), trim)   # cornice a
    box((49, TH + 0.5, 0.5), (0, -0.05, 10.8), trim)  # cornice b
    box((49.5, TH + 0.6, 1.0), (0, -0.05, 0.5), trim)  # base course

    box((0.9, TH + 0.6, 8), (-3.4, 0, 4), accent)     # portal jambs + header
    box((0.9, TH + 0.6, 8), (3.4, 0, 4), accent)
    box((8.2, TH + 0.6, 1.0), (0, 0, 7.7), accent)
    box((9.2, TH + 0.9, 0.7), (0, -0.15, 8.4), trim)  # pediment

    # Ground planters flanking the entrance, full of flowers.
    for sx in (-6.5, 6.5):
        box((2.6, 2.4, 2.0), (sx, FRONT - 1.2, 1.0), planter)
        flower_row(sx, FRONT - 1.6, 2.6, 4, 2.2)

    for cx in (-18.5, -8.5, 8.5, 18.5):
        window(cx, 4.6, 3.8, 5.0)
    for cx in (-18.5, -8.5, 8.5, 18.5):
        window(cx, 9.7, 3.6, 2.4)

    join_bevel(body, "Body")
    join_bevel(accent, "Accent")
    join_bevel(trim, "Trim")
    join_bevel(win, "Win", bevel=0.0)
    join_bevel(planter, "Planter")
    join_bevel(stem, "Stem", bevel=0.0)
    join_bevel(center, "Center", bevel=0.0)
    join_bevel(fa, "FlowerA", bevel=0.0)
    join_bevel(fb, "FlowerB", bevel=0.0)
    join_bevel(fc, "FlowerC", bevel=0.0)


def export():
    out = os.path.join(r"/Users/kirill/projects/roblox game", "blender", "out", "StudioFacade.fbx")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True,
                             apply_unit_scale=True, global_scale=1.0,
                             object_types={"MESH"})
    print("Exported:", out)


build()
export()
print("Done. Import blender/out/StudioFacade.fbx -> overwrite assets/studio/StudioFacade.rbxm")
