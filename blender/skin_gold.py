"""
Studio SKIN building kit -- GOLD (DETAILED, ~2 MB target).

One hollow floor module, richly detailed so the in-game building reads as a real
ornate studio, not a plain box. Same footprint/pipeline as before:
  48 (X) x 32 (Y) x 12 (Z), centred on origin, door on Blender -Y = Roblox -Z.
Colours are applied in-game by PlotManager.recolorSkin, so NAMES drive colour:
  SkinFloorGoldWall -> gold walls/structure   SkinFloorGoldTrim -> gold accent

Detail = many named box elements (window frames + mullions + sills + lintels,
pilasters between windows, corner quoins, a stepped cornice, a base plinth, a
paneled door surround) PLUS a Bevel + Subdivision pass on everything for smooth,
heavy geometry. Tune file size with the DETAIL knobs and re-run; I read the
exported FBX size off disk to land it near ~2 MB.

Run in Blender (Scripting -> Open -> Reload -> Run), then Import
blender/out/SkinFloorGold.fbx, rename the Model to SkinFloorGold, Save to File
-> Downloads. (No roof file -- the roof cap is built in-game.)
"""

import bpy
import os

OUT = r"/Users/kirill/projects/roblox game/blender/out"

# ---- footprint (studs) ----
HALF_W = 24.0
HALF_D = 16.0
H = 12.0
T = 0.7
DOOR_W = 7.0
DOOR_H = 9.0
WIN_H = 5.0
WIN_Z0 = -H / 2 + 3.5

# ---- DETAIL knobs (raise for a heavier ~2MB file, lower if too big) ----
BEVEL_SEGMENTS = 4      # edge-loop segments on the bevel (more = heavier/smoother)
BEVEL_WIDTH = 0.06
SUBSURF = 1             # subdivision-surface levels applied to all pieces (+1 ~ x4 polys)


def _clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.objects):
        for b in list(block):
            try:
                block.remove(b)
            except Exception:
                pass


PIECES = []


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


def window_dressing(prefix, axis, plane, c, w, z0, zh):
    """Frame + a 2x2 mullion grid + sill + lintel around a window opening."""
    faceOff = 0.35  # how far the frame sits proud of the wall
    zc = z0 + zh / 2
    if axis == "x":
        s = 1 if plane > 0 else -1
        # frame (4 bars)
        box(prefix + "Trim", plane + s * faceOff, c, z0, T, w + 0.6, 0.4)          # bottom
        box(prefix + "Trim", plane + s * faceOff, c, z0 + zh, T, w + 0.6, 0.4)     # top
        box(prefix + "Trim", plane + s * faceOff, c - w / 2, zc, T, 0.4, zh)       # left
        box(prefix + "Trim", plane + s * faceOff, c + w / 2, zc, T, 0.4, zh)       # right
        box(prefix + "Trim", plane + s * faceOff, c, zc, T * 0.6, 0.25, zh)        # v mullion
        box(prefix + "Trim", plane + s * faceOff, c, zc, T * 0.6, w, 0.25)         # h mullion
        box(prefix + "Trim", plane + s * faceOff, c, z0 - 0.5, T + 0.5, w + 1.2, 0.5)  # sill
    else:
        s = 1 if plane > 0 else -1
        box(prefix + "Trim", c, plane + s * faceOff, z0, w + 0.6, T, 0.4)
        box(prefix + "Trim", c, plane + s * faceOff, z0 + zh, w + 0.6, T, 0.4)
        box(prefix + "Trim", c - w / 2, plane + s * faceOff, zc, 0.4, T, zh)
        box(prefix + "Trim", c + w / 2, plane + s * faceOff, zc, 0.4, T, zh)
        box(prefix + "Trim", c, plane + s * faceOff, zc, 0.25, T * 0.6, zh)
        box(prefix + "Trim", c, plane + s * faceOff, zc, w, T * 0.6, 0.25)
        box(prefix + "Trim", c, plane + s * faceOff, z0 - 0.5, w + 1.2, T + 0.5, 0.5)


def build():
    _clear()
    P = "SkinFloorGold"

    # Window layouts per wall: list of (centre, width, z0, height)
    back = [(-HALF_W * 0.55, 8, WIN_Z0, WIN_H), (0, 8, WIN_Z0, WIN_H), (HALF_W * 0.55, 8, WIN_Z0, WIN_H)]
    left = [(-HALF_D * 0.45, 6, WIN_Z0, WIN_H), (HALF_D * 0.45, 6, WIN_Z0, WIN_H)]
    right = left
    front = [(-HALF_W * 0.62, 6, WIN_Z0, WIN_H), (0, DOOR_W, -H / 2, DOOR_H), (HALF_W * 0.62, 6, WIN_Z0, WIN_H)]

    wall_with_openings(P, "y", HALF_D, back)
    wall_with_openings(P, "x", -HALF_W, left)
    wall_with_openings(P, "x", HALF_W, right)
    wall_with_openings(P, "y", -HALF_D, front)

    # Window frames/mullions/sills (the door opening is skipped -- it gets a surround).
    for (c, w, z0, zh) in back:
        window_dressing(P, "y", HALF_D, c, w, z0, zh)
    for (c, w, z0, zh) in left:
        window_dressing(P, "x", -HALF_W, c, w, z0, zh)
    for (c, w, z0, zh) in right:
        window_dressing(P, "x", HALF_W, c, w, z0, zh)
    for (c, w, z0, zh) in front:
        if zh == DOOR_H:
            # Door surround: jambs + header + a few panels.
            box(P + "Trim", c - w / 2, -HALF_D - 0.35, -H / 2 + zh / 2, 0.6, T, zh)
            box(P + "Trim", c + w / 2, -HALF_D - 0.35, -H / 2 + zh / 2, 0.6, T, zh)
            box(P + "Trim", c, -HALF_D - 0.35, -H / 2 + zh + 0.3, w + 1.4, T, 0.7)
            box(P + "Trim", c, -HALF_D - 0.5, -H / 2 + zh + 1.4, w + 2.2, T, 1.4)  # pediment
        else:
            window_dressing(P, "y", -HALF_D, c, w, z0, zh)

    # Pilasters between windows on the long walls (vertical columns).
    for x in (-HALF_W * 0.28, HALF_W * 0.28):
        box(P + "Wall", x, HALF_D + 0.25, 0, 1.6, 0.5, H)
    # Corner quoins (stacked blocks at all 4 corners).
    for cx in (-HALF_W, HALF_W):
        for cy in (-HALF_D, HALF_D):
            for k in range(6):
                z = -H / 2 + 1.0 + k * 2.0
                wq = 2.6 if k % 2 == 0 else 1.8
                box(P + "Trim", cx, cy, z, wq, wq, 1.4)

    # Base plinth course wrapping the bottom.
    box(P + "Trim", 0, HALF_D + 0.2, -H / 2 + 0.6, HALF_W * 2 + 1.6, 0.6, 1.4)
    box(P + "Trim", 0, -HALF_D - 0.2, -H / 2 + 0.6, HALF_W * 2 + 1.6, 0.6, 1.4)
    box(P + "Trim", -HALF_W - 0.2, 0, -H / 2 + 0.6, 0.6, HALF_D * 2 + 1.6, 1.4)
    box(P + "Trim", HALF_W + 0.2, 0, -H / 2 + 0.6, 0.6, HALF_D * 2 + 1.6, 1.4)

    # Stepped cornice at the top (3 stacked bands, each proud a bit more).
    for k, grow in enumerate((0.4, 0.9, 1.5)):
        z = H / 2 - 0.3 - k * 0.6
        box(P + "Trim", 0, HALF_D + grow, z, HALF_W * 2 + grow * 2 + 1, 0.5, 0.6)
        box(P + "Trim", 0, -HALF_D - grow, z, HALF_W * 2 + grow * 2 + 1, 0.5, 0.6)
        box(P + "Trim", -HALF_W - grow, 0, z, 0.5, HALF_D * 2 + grow * 2 + 1, 0.6)
        box(P + "Trim", HALF_W + grow, 0, z, 0.5, HALF_D * 2 + grow * 2 + 1, 0.6)

    # ---- weight + smoothness: bevel + subsurf every piece, then join per name ----
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

    walls = [o for o in PIECES if o.name.startswith(P + "Wall")]
    trims = [o for o in PIECES if o.name.startswith(P + "Trim")]

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

    wall = join(walls, P + "Wall")
    trim = join(trims, P + "Trim")

    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in (wall, trim):
        if o:
            o.select_set(True)
    bpy.context.view_layer.objects.active = wall or trim
    path = os.path.join(OUT, "SkinFloorGold.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True,
                             object_types={"MESH"}, mesh_smooth_type="FACE")
    print("Exported", path)


build()
print("Detailed Gold done. Import blender/out/SkinFloorGold.fbx.")
