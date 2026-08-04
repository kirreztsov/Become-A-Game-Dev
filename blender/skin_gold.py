"""
Studio SKIN building kit -- GOLD.

Builds TWO models for the "Gold" studio skin, exported as separate FBX so each
imports as its own Roblox Model:

  SkinFloorGold  -- one hollow floor module (walls + door + window openings),
                    sized to the studio footprint so it STACKS per floor.
  SkinRoofGold   -- a peaked gold roof cap for the top floor.

Footprint / proportions (authored at 1 unit = 1 stud):
  X width  = 48  (matches BUILDING_HALF_W*2 = 48)
  Y depth  = 32  (matches BUILDING_HALF_D*2 = 32)
  Z height = 12  (matches WALL_HEIGHT = 12)
Both models are built CENTRED on the origin (X,Y,Z all centred), because
StudioModels.place() pivots a Roblox Model at its bounding-box centre and the
Luau places the floor centre at mid-wall height. The building FRONT (with the
door) faces Blender -Y, which maps to Roblox -Z (the plaza side).

Roblox's FBX importer may mirror X and imports Blender Z-up as Roblox Y-up.
If in Studio the door ends up on the wrong side or it's mirrored, tell me and
I'll flip the axis here.

Part NAMES drive in-game colour (PlotManager.recolorSkin tints Wall/Roof/Trim):
  SkinFloorGoldWall  -> gold walls        SkinFloorGoldTrim -> gold accent band
  SkinRoofGoldRoof   -> gold roof         SkinRoofGoldTrim  -> roof accent

Run in Blender (Scripting -> Open -> Reload -> Run), then Import
blender/out/SkinFloorGold.fbx and blender/out/SkinRoofGold.fbx, rename the
imported Models to `SkinFloorGold` / `SkinRoofGold`, and Save each to
assets/studio/ (Save to File). Chunky on purpose -- few solid boxes -- so the
importer keeps every piece.
"""

import bpy
import os
import math

OUT = r"/Users/kirill/projects/roblox game/blender/out"

# ---- footprint (studs) ----
HALF_W = 24.0   # X: 48 wide
HALF_D = 16.0   # Y: 32 deep
H = 12.0        # Z: wall height
T = 0.6         # wall thickness
DOOR_W = 7.0
DOOR_H = 9.0
TRIM_H = 1.2    # accent band height at the top
WIN_H = 5.0     # window opening height
WIN_Z0 = -H / 2 + 3.5  # window bottom (studs from centre)


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
    """A solid box centred at (cx,cy,cz) with full sizes (sx,sy,sz)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy, cz))
    o = bpy.context.active_object
    o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    o.name = name
    return o


def join(objs, name):
    """Join a list of objects into one, named `name`."""
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
    """
    Build a wall as solid segments around rectangular openings (holes).
    axis="x": wall lies in the Y-Z plane at X=plane (side wall), spans Y.
    axis="y": wall lies in the X-Z plane at Y=plane (front/back), spans X.
    openings: list of (centre_along, width, z0, z_h) holes to leave.
    Returns a list of segment objects.
    """
    span_half = HALF_D if axis == "x" else HALF_W
    z_bot, z_top = -H / 2, H / 2
    segs = []
    # Solid full-height end pillars + fill, minus the openings. Simple approach:
    # a full wall, then carve by building the complementary solid strips.
    # Left of first opening, between openings, right of last opening (full height),
    # plus sill (below) and header (above) spanning each opening.
    cuts = sorted(openings, key=lambda o: o[0])
    edges = [-span_half]
    for (c, w, z0, zh) in cuts:
        edges.append(c - w / 2)
        edges.append(c + w / 2)
    edges.append(span_half)
    # Full-height solid columns between openings (edges come in pairs of gaps).
    i = 0
    idx = 0
    while i < len(edges) - 1:
        a, b = edges[i], edges[i + 1]
        is_solid = (i % 2 == 0)  # segments outside openings are solid
        if is_solid and b - a > 0.01:
            c = (a + b) / 2.0
            width = b - a
            idx += 1
            if axis == "x":
                segs.append(box(prefix + "Wall", plane, c, 0, T, width, H))
            else:
                segs.append(box(prefix + "Wall", c, plane, 0, width, T, H))
        i += 1
    # Sill (below) + header (above) spanning each opening.
    for (c, w, z0, zh) in cuts:
        below_h = (z0) - z_bot
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
                segs.append(box(prefix + "Wall", c, plane, cz, w, above_h))
    return segs


def build_floor():
    _clear()
    walls = []
    trims = []
    P = "SkinFloorGold"

    # Back wall (+Y): two window openings.
    walls += wall_with_openings(P, "y", HALF_D, [
        (-HALF_W / 2, 8, WIN_Z0, WIN_H),
        (HALF_W / 2, 8, WIN_Z0, WIN_H),
    ])
    # Left / right walls (±X): one window opening each.
    walls += wall_with_openings(P, "x", -HALF_W, [(0, 10, WIN_Z0, WIN_H)])
    walls += wall_with_openings(P, "x", HALF_W, [(0, 10, WIN_Z0, WIN_H)])
    # Front wall (-Y): a central DOOR opening (gap from floor up DOOR_H).
    walls += wall_with_openings(P, "y", -HALF_D, [(0, DOOR_W, -H / 2, DOOR_H)])

    # Accent trim band wrapping the top edge of all four walls.
    tz = H / 2 - TRIM_H / 2
    trims.append(box(P + "Trim", 0, HALF_D + 0.15, tz, HALF_W * 2 + 0.6, 0.3, TRIM_H))
    trims.append(box(P + "Trim", 0, -HALF_D - 0.15, tz, HALF_W * 2 + 0.6, 0.3, TRIM_H))
    trims.append(box(P + "Trim", -HALF_W - 0.15, 0, tz, 0.3, HALF_D * 2 + 0.6, TRIM_H))
    trims.append(box(P + "Trim", HALF_W + 0.15, 0, tz, 0.3, HALF_D * 2 + 0.6, TRIM_H))

    wall = join(walls, P + "Wall")
    trim = join(trims, P + "Trim")

    export([wall, trim], "SkinFloorGold.fbx")


def build_roof():
    _clear()
    P = "SkinRoofGold"
    parts = []
    # A thin base slab + a low 4-sided pyramid (hip roof) sized to the footprint.
    parts.append(box(P + "Roof", 0, 0, -1.5, HALF_W * 2 + 2, HALF_D * 2 + 2, 0.6))
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=1.0, radius2=0.0, depth=1.0, location=(0, 0, 1.2))
    cone = bpy.context.active_object
    # Scale the square pyramid to the footprint; rotate 45deg so faces align to walls.
    cone.scale = ((HALF_W + 1) * math.sqrt(2) / 2 * 2 / 2, (HALF_D + 1) * math.sqrt(2) / 2 * 2 / 2, 6.0)
    cone.rotation_euler = (0, 0, math.radians(45))
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    cone.name = P + "Roof"
    parts.append(cone)
    # A slim accent ridge cap on top.
    parts.append(box(P + "Trim", 0, 0, 4.2, 3, 3, 0.5))
    roof = join([p for p in parts if p.name.endswith("Roof")], P + "Roof")
    trim = join([p for p in parts if p.name.endswith("Trim")], P + "Trim")
    export([roof, trim], "SkinRoofGold.fbx")


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


build_floor()
build_roof()
print("Gold skin kit done. Import blender/out/SkinFloorGold.fbx + SkinRoofGold.fbx.")
