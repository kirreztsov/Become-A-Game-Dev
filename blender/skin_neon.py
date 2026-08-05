"""
Studio SKIN building kit -- NEON (DETAILED, distinct MODERN/TECH design).

A sleek, horizontal, futuristic look -- DIFFERENT from Gold's classical style:
long horizontal ribbon windows, protruding glowing FINS along each floor line,
vertical corner light-strips, and a flat canopy over the door. Detail via many
named boxes + bevel + subsurf. Colour in-game (recolorSkin): dark walls, glowing
purple accent on Trim (neon on trim only). Footprint 48x32x12, centred, door -Y.

NAMES: SkinFloorNeonWall -> dark walls;  SkinFloorNeonTrim -> glowing accent.
Run: Scripting -> Open -> Reload -> Run; Import blender/out/SkinFloorNeon.fbx,
rename Model SkinFloorNeon, Save to File -> Downloads. (No roof file.)
"""

import bpy
import os

OUT = r"/Users/kirill/projects/roblox game/blender/out"

HALF_W = 24.0
HALF_D = 16.0
H = 12.0
T = 0.7
DOOR_W = 8.0
DOOR_H = 9.0
BAND_Z0 = -1.9          # ribbon window band (centred): from -1.9 to +1.9
BAND_H = 3.8

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


def hfin(prefix, z, grow):
    """A thin horizontal glowing fin wrapping all four sides, proud by `grow`."""
    box(prefix + "Trim", 0, HALF_D + grow / 2, z, HALF_W * 2 + 1.2, grow, 0.5)
    box(prefix + "Trim", 0, -HALF_D - grow / 2, z, HALF_W * 2 + 1.2, grow, 0.5)
    box(prefix + "Trim", -HALF_W - grow / 2, 0, z, grow, HALF_D * 2 + 1.2, 0.5)
    box(prefix + "Trim", HALF_W + grow / 2, 0, z, grow, HALF_D * 2 + 1.2, 0.5)


def build():
    _clear()
    P = "SkinFloorNeon"
    # Long horizontal RIBBON windows (wide, short) -- the modern signature.
    wall_with_openings(P, "y", HALF_D, [(0, 40, BAND_Z0, BAND_H)])
    wall_with_openings(P, "x", -HALF_W, [(0, 26, BAND_Z0, BAND_H)])
    wall_with_openings(P, "x", HALF_W, [(0, 26, BAND_Z0, BAND_H)])
    wall_with_openings(P, "y", -HALF_D, [(-13, 12, BAND_Z0, BAND_H), (0, DOOR_W, -H / 2, DOOR_H), (13, 12, BAND_Z0, BAND_H)])

    # Thin vertical mullions dividing the ribbon windows into panes.
    for x in range(-20, 21, 4):
        box(P + "Trim", x, HALF_D + 0.25, 0, 0.25, 0.3, BAND_H)
    for y in range(-12, 13, 4):
        box(P + "Trim", -HALF_W - 0.25, y, 0, 0.3, 0.25, BAND_H)
        box(P + "Trim", HALF_W + 0.25, y, 0, 0.3, 0.25, BAND_H)

    # Protruding glowing FINS: floor line (bottom), mid, and top eave.
    hfin(P, -H / 2 + 0.4, 1.3)
    hfin(P, BAND_Z0 + BAND_H + 0.6, 0.9)   # eave just above the ribbon
    hfin(P, H / 2 - 0.4, 1.6)              # top eave (biggest)

    # Vertical corner light-strips (full height, glowing) instead of quoins.
    for cx in (-HALF_W, HALF_W):
        for cy in (-HALF_D, HALF_D):
            box(P + "Trim", cx, cy, 0, 1.1, 1.1, H - 0.4)

    # Flat cantilevered canopy fin over the door.
    box(P + "Trim", 0, -HALF_D - 1.6, -H / 2 + DOOR_H + 0.6, DOOR_W + 4, 3.2, 0.6)

    _finish(P, "SkinFloorNeon.fbx")


def _finish(P, filename):
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
    path = os.path.join(OUT, filename)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True,
                             object_types={"MESH"}, mesh_smooth_type="FACE")
    print("Exported", path)


build()
print("Detailed modern Neon done. Import blender/out/SkinFloorNeon.fbx.")
