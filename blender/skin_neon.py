"""
Studio SKIN building kit -- NEON.

Same footprint/pipeline as skin_gold.py (48 x 32 x 12, centred on origin, door on
Blender -Y / Roblox -Z front). Restyled for the Neon skin: a flat modern roof and
a thin trim band that the game lights up with the neon accent colour. Walls stay
dark; ONLY the trim glows (project Neon-accent-only rule) -- the colours/materials
are applied in-game by PlotManager.recolorSkin, so this script only needs correct
NAMES:
  SkinFloorNeonWall  -> dark walls        SkinFloorNeonTrim -> glowing neon band
  SkinRoofNeonRoof   -> dark flat roof     SkinRoofNeonTrim  -> glowing neon edge

Bigger window openings than Gold for a modern glassy look. Two FBX exported.

Run in Blender (Scripting -> Open -> Reload -> Run), then Import
blender/out/SkinFloorNeon.fbx + SkinRoofNeon.fbx, rename the Models to
SkinFloorNeon / SkinRoofNeon, and Save each to assets/studio/.
"""

import bpy
import os

OUT = r"/Users/kirill/projects/roblox game/blender/out"

HALF_W = 24.0
HALF_D = 16.0
H = 12.0
T = 0.6
DOOR_W = 7.0
DOOR_H = 9.0
TRIM_H = 1.2
WIN_H = 6.5          # taller windows than Gold (modern)
WIN_Z0 = -H / 2 + 3.0


def _clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.objects):
        for b in list(block):
            try:
                block.remove(b)
            except Exception:
                pass


def box(name, cx, cy, cz, sx, sy, sz):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy, cz))
    o = bpy.context.active_object
    o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    o.name = name
    return o


def join(objs, name):
    objs = [o for o in objs if o is not None]
    if not objs:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    j = bpy.context.active_object
    j.name = name
    return j


def wall_with_openings(prefix, axis, plane, openings):
    span_half = HALF_D if axis == "x" else HALF_W
    z_bot, z_top = -H / 2, H / 2
    segs = []
    cuts = sorted(openings, key=lambda o: o[0])
    edges = [-span_half]
    for (c, w, z0, zh) in cuts:
        edges.append(c - w / 2)
        edges.append(c + w / 2)
    edges.append(span_half)
    i = 0
    while i < len(edges) - 1:
        a, b = edges[i], edges[i + 1]
        if (i % 2 == 0) and b - a > 0.01:
            c = (a + b) / 2.0
            width = b - a
            if axis == "x":
                segs.append(box(prefix + "Wall", plane, c, 0, T, width, H))
            else:
                segs.append(box(prefix + "Wall", c, plane, 0, width, T, H))
        i += 1
    for (c, w, z0, zh) in cuts:
        below_h = z0 - z_bot
        above_h = z_top - (z0 + zh)
        if below_h > 0.01:
            cz = z_bot + below_h / 2
            if axis == "x":
                segs.append(box(prefix + "Wall", plane, c, cz, T, w, below_h))
            else:
                segs.append(box(prefix + "Wall", c, plane, cz, w, T, below_h))
        if above_h > 0.01:
            cz = (z0 + zh) + above_h / 2
            if axis == "x":
                segs.append(box(prefix + "Wall", plane, c, cz, T, w, above_h))
            else:
                segs.append(box(prefix + "Wall", c, plane, cz, w, T, above_h))
    return segs


def export(objs, filename):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        if o is not None:
            o.select_set(True)
    if objs and objs[0] is not None:
        bpy.context.view_layer.objects.active = objs[0]
    path = os.path.join(OUT, filename)
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        apply_unit_scale=True,
        object_types={"MESH"},
        mesh_smooth_type="FACE",
    )
    print("Exported", path)


def build_floor():
    _clear()
    P = "SkinFloorNeon"
    walls = []
    trims = []
    # Back wall (+Y): three tall windows (modern glass frontage).
    walls += wall_with_openings(P, "y", HALF_D, [
        (-HALF_W * 0.55, 9, WIN_Z0, WIN_H),
        (0, 9, WIN_Z0, WIN_H),
        (HALF_W * 0.55, 9, WIN_Z0, WIN_H),
    ])
    # Side walls (±X): two tall windows each.
    for plane in (-HALF_W, HALF_W):
        walls += wall_with_openings(P, "x", plane, [
            (-HALF_D * 0.45, 7, WIN_Z0, WIN_H),
            (HALF_D * 0.45, 7, WIN_Z0, WIN_H),
        ])
    # Front wall (-Y): door + two flanking windows.
    walls += wall_with_openings(P, "y", -HALF_D, [
        (-HALF_W * 0.6, 7, WIN_Z0, WIN_H),
        (0, DOOR_W, -H / 2, DOOR_H),
        (HALF_W * 0.6, 7, WIN_Z0, WIN_H),
    ])

    # Two glowing trim bands (top edge + a mid belt) -- neon accent.
    tz_top = H / 2 - TRIM_H / 2
    tz_mid = -H / 2 + TRIM_H
    for tz in (tz_top, tz_mid):
        trims.append(box(P + "Trim", 0, HALF_D + 0.15, tz, HALF_W * 2 + 0.6, 0.25, TRIM_H * 0.6))
        trims.append(box(P + "Trim", 0, -HALF_D - 0.15, tz, HALF_W * 2 + 0.6, 0.25, TRIM_H * 0.6))
        trims.append(box(P + "Trim", -HALF_W - 0.15, 0, tz, 0.25, HALF_D * 2 + 0.6, TRIM_H * 0.6))
        trims.append(box(P + "Trim", HALF_W + 0.15, 0, tz, 0.25, HALF_D * 2 + 0.6, TRIM_H * 0.6))

    wall = join(walls, P + "Wall")
    trim = join(trims, P + "Trim")
    export([wall, trim], "SkinFloorNeon.fbx")


def build_roof():
    _clear()
    P = "SkinRoofNeon"
    parts = []
    # Flat modern roof slab.
    parts.append(box(P + "Roof", 0, 0, 0, HALF_W * 2 + 1.5, HALF_D * 2 + 1.5, 1.0))
    # A raised glowing neon parapet edge around the rim.
    parts.append(box(P + "Trim", 0, HALF_D + 0.4, 1.0, HALF_W * 2 + 2, 0.4, 1.2))
    parts.append(box(P + "Trim", 0, -HALF_D - 0.4, 1.0, HALF_W * 2 + 2, 0.4, 1.2))
    parts.append(box(P + "Trim", HALF_W + 0.4, 0, 1.0, 0.4, HALF_D * 2 + 2, 1.2))
    parts.append(box(P + "Trim", -HALF_W - 0.4, 0, 1.0, 0.4, HALF_D * 2 + 2, 1.2))
    roof = join([p for p in parts if p.name.endswith("Roof")], P + "Roof")
    trim = join([p for p in parts if p.name.endswith("Trim")], P + "Trim")
    export([roof, trim], "SkinRoofNeon.fbx")


build_floor()
build_roof()
print("Neon skin kit done. Import SkinFloorNeon.fbx + SkinRoofNeon.fbx.")
