"""
Studio SKIN building kit -- MIDNIGHT (DETAILED, distinct ART-DECO design).

A vertical, deco look -- DIFFERENT from Gold (classical) and Neon (horizontal):
many VERTICAL RIBS/fluting running full height, tall narrow windows between them,
and layered horizontal banding top + bottom. Detail via many named boxes + bevel
+ subsurf. Colour in-game (recolorSkin): deep midnight-blue walls, silver trim.
Footprint 48x32x12, centred, door -Y.

NAMES: SkinFloorMidnightWall -> blue walls;  SkinFloorMidnightTrim -> silver.
Run: Scripting -> Open -> Reload -> Run; Import blender/out/SkinFloorMidnight.fbx,
rename Model SkinFloorMidnight, Save to File -> Downloads. (No roof file.)
"""

import bpy
import os

OUT = r"/Users/kirill/projects/roblox game/blender/out"

HALF_W = 24.0
HALF_D = 16.0
H = 12.0
T = 0.7
DOOR_W = 6.0
DOOR_H = 9.5
WIN_W = 4.0
WIN_H = 7.0
WIN_Z0 = -H / 2 + 2.5

BEVEL_SEGMENTS = 4
BEVEL_WIDTH = 0.05
SUBSURF = 1

PIECES = []


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
    PIECES.append(o)
    return o


def wall_with_openings(prefix, axis, plane, openings):
    span_half = HALF_D if axis == "x" else HALF_W
    z_bot, z_top = -H / 2, H / 2
    cuts = sorted(openings, key=lambda o: o[0])
    edges = [-span_half]
    for (c, w, z0, zh) in cuts:
        edges += [c - w / 2, c + w / 2]
    edges.append(span_half)
    i = 0
    while i < len(edges) - 1:
        a, b = edges[i], edges[i + 1]
        if (i % 2 == 0) and b - a > 0.01:
            c = (a + b) / 2.0
            width = b - a
            if axis == "x":
                box(prefix + "Wall", plane, c, 0, T, width, H)
            else:
                box(prefix + "Wall", c, plane, 0, width, T, H)
        i += 1
    for (c, w, z0, zh) in cuts:
        below_h = z0 - z_bot
        above_h = z_top - (z0 + zh)
        if below_h > 0.01:
            cz = z_bot + below_h / 2
            if axis == "x":
                box(prefix + "Wall", plane, c, cz, T, w, below_h)
            else:
                box(prefix + "Wall", c, plane, cz, w, T, below_h)
        if above_h > 0.01:
            cz = (z0 + zh) + above_h / 2
            if axis == "x":
                box(prefix + "Wall", plane, c, cz, T, w, above_h)
            else:
                box(prefix + "Wall", c, plane, cz, w, T, above_h)


def rib(prefix, axis, plane, along):
    """A vertical fluting rib standing proud of a wall face, full height."""
    if axis == "y":
        s = 1 if plane > 0 else -1
        box(prefix + "Trim", along, plane + s * 0.3, 0, 0.7, 0.6, H - 0.6)
    else:
        s = 1 if plane > 0 else -1
        box(prefix + "Trim", plane + s * 0.3, along, 0, 0.6, 0.7, H - 0.6)


def build():
    _clear()
    P = "SkinFloorMidnight"
    back = [(x, WIN_W, WIN_Z0, WIN_H) for x in (-18, -6, 6, 18)]
    left = [(y, WIN_W, WIN_Z0, WIN_H) for y in (-8, 8)]
    right = left
    front = [(-15, WIN_W, WIN_Z0, WIN_H), (0, DOOR_W, -H / 2, DOOR_H), (15, WIN_W, WIN_Z0, WIN_H)]

    wall_with_openings(P, "y", HALF_D, back)
    wall_with_openings(P, "x", -HALF_W, left)
    wall_with_openings(P, "x", HALF_W, right)
    wall_with_openings(P, "y", -HALF_D, front)

    # Vertical ribs across every face (deco fluting) -- between + around windows.
    for x in range(-21, 22, 3):
        rib(P, "y", HALF_D, x)
        rib(P, "y", -HALF_D, x)
    for y in range(-13, 14, 3):
        rib(P, "x", -HALF_W, y)
        rib(P, "x", HALF_W, y)

    # Layered horizontal banding: a strong base + a stepped top crown band.
    box(P + "Trim", 0, HALF_D + 0.3, -H / 2 + 0.7, HALF_W * 2 + 1.8, 0.8, 1.6)
    box(P + "Trim", 0, -HALF_D - 0.3, -H / 2 + 0.7, HALF_W * 2 + 1.8, 0.8, 1.6)
    box(P + "Trim", -HALF_W - 0.3, 0, -H / 2 + 0.7, 0.8, HALF_D * 2 + 1.8, 1.6)
    box(P + "Trim", HALF_W + 0.3, 0, -H / 2 + 0.7, 0.8, HALF_D * 2 + 1.8, 1.6)
    for k, grow in enumerate((0.5, 1.1)):
        z = H / 2 - 0.4 - k * 0.7
        box(P + "Trim", 0, HALF_D + grow, z, HALF_W * 2 + grow * 2 + 1, 0.5, 0.7)
        box(P + "Trim", 0, -HALF_D - grow, z, HALF_W * 2 + grow * 2 + 1, 0.5, 0.7)
        box(P + "Trim", -HALF_W - grow, 0, z, 0.5, HALF_D * 2 + grow * 2 + 1, 0.7)
        box(P + "Trim", HALF_W + grow, 0, z, 0.5, HALF_D * 2 + grow * 2 + 1, 0.7)

    # A tall deco entrance frame around the door.
    box(P + "Trim", -DOOR_W / 2 - 0.6, -HALF_D - 0.4, -H / 2 + DOOR_H / 2, 1.2, T, DOOR_H + 1)
    box(P + "Trim", DOOR_W / 2 + 0.6, -HALF_D - 0.4, -H / 2 + DOOR_H / 2, 1.2, T, DOOR_H + 1)
    box(P + "Trim", 0, -HALF_D - 0.5, -H / 2 + DOOR_H + 1.2, DOOR_W + 3, T, 2.2)

    for o in PIECES:
        bpy.context.view_layer.objects.active = o
        bev = o.modifiers.new("Bevel", "BEVEL")
        bev.segments = BEVEL_SEGMENTS
        bev.width = BEVEL_WIDTH
        if SUBSURF > 0:
            sub = o.modifiers.new("Subsurf", "SUBSURF")
            sub.levels = SUBSURF
            sub.render_levels = SUBSURF
        for m in list(o.modifiers):
            try:
                bpy.ops.object.modifier_apply(modifier=m.name)
            except Exception:
                pass

    def join(objs, name):
        objs = [o for o in objs if o and o.name in bpy.data.objects]
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

    # build both lists BEFORE joining (joining consumes objects; touching a
    # consumed object's .name afterwards throws StructRNA-removed).
    wall_objs = [o for o in PIECES if o.name.startswith(P + "Wall")]
    trim_objs = [o for o in PIECES if o.name.startswith(P + "Trim")]
    wall = join(wall_objs, P + "Wall")
    trim = join(trim_objs, P + "Trim")
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in (wall, trim):
        if o:
            o.select_set(True)
    bpy.context.view_layer.objects.active = wall or trim
    path = os.path.join(OUT, "SkinFloorMidnight.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True,
                             object_types={"MESH"}, mesh_smooth_type="FACE")
    print("Exported", path)


build()
print("Detailed art-deco Midnight done. Import blender/out/SkinFloorMidnight.fbx.")
