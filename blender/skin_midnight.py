"""
Studio SKIN building kit -- MIDNIGHT.

Only ONE model now -- the floor module. (Roof caps are built in-game as a
reliable procedural flat slab, so no roof mesh is needed.)

Same footprint/pipeline as the other skins: 48 x 32 x 12, centred on origin,
door on Blender -Y / Roblox -Z front. Colours/materials are applied in-game by
PlotManager.recolorSkin (Midnight = deep midnight-blue walls + silver trim), so
this script only needs correct NAMES:
  SkinFloorMidnightWall  -> midnight-blue walls
  SkinFloorMidnightTrim  -> silver trim bands

Run in Blender (Scripting -> Open -> Reload -> Run), then Import
blender/out/SkinFloorMidnight.fbx, rename the Model to SkinFloorMidnight, and
Save to assets/studio/. (No roof file this time.)
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
WIN_H = 6.5
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
    P = "SkinFloorMidnight"
    walls = []
    trims = []
    # Back wall (+Y): two wide windows.
    walls += wall_with_openings(P, "y", HALF_D, [
        (-HALF_W * 0.5, 12, WIN_Z0, WIN_H),
        (HALF_W * 0.5, 12, WIN_Z0, WIN_H),
    ])
    # Side walls (±X): one wide window each.
    for plane in (-HALF_W, HALF_W):
        walls += wall_with_openings(P, "x", plane, [(0, 14, WIN_Z0, WIN_H)])
    # Front wall (-Y): door + two flanking windows.
    walls += wall_with_openings(P, "y", -HALF_D, [
        (-HALF_W * 0.6, 7, WIN_Z0, WIN_H),
        (0, DOOR_W, -H / 2, DOOR_H),
        (HALF_W * 0.6, 7, WIN_Z0, WIN_H),
    ])

    # A single silver trim band near the top edge (sleeker than Neon's two).
    tz = H / 2 - TRIM_H / 2
    trims.append(box(P + "Trim", 0, HALF_D + 0.15, tz, HALF_W * 2 + 0.6, 0.3, TRIM_H))
    trims.append(box(P + "Trim", 0, -HALF_D - 0.15, tz, HALF_W * 2 + 0.6, 0.3, TRIM_H))
    trims.append(box(P + "Trim", -HALF_W - 0.15, 0, tz, 0.3, HALF_D * 2 + 0.6, TRIM_H))
    trims.append(box(P + "Trim", HALF_W + 0.15, 0, tz, 0.3, HALF_D * 2 + 0.6, TRIM_H))

    wall = join(walls, P + "Wall")
    trim = join(trims, P + "Trim")
    export([wall, trim], "SkinFloorMidnight.fbx")


build_floor()
print("Midnight skin kit done. Import SkinFloorMidnight.fbx (floor only, no roof).")
