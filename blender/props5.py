"""
M7 props batch 5: Balloons, BasketballHoop, PierSection, SkateRamp.

Part names drive in-game colouring (the Lobby builders paint by name):
  Balloons      -> BalloonA..BalloonE (5 party colours), Knot, String
  BasketballHoop-> HoopPole, HoopArm (metal), Backboard, BackboardTrim (white),
                   Rim (orange), Net (white). Modelled 1:1 in height so the rim
                   sits at Z=5.9 above the base (base = court surface); the
                   builder places the base on the court so the rim lines up with
                   the functional shooting sensor.
  PierSection   -> PierDeck, PierSeam, PierPiling, PierRailPost, PierRail.
                   ONE bay, 11 long (X) x 9 wide (Y), modelled 1:1 in height:
                   pilings from Z=0 (seabed, world Y=0) to the deck at Z=7.6;
                   the builder tiles bays along the pier's length (no scaling).
  SkateRamp     -> RampSurface, RampSide, RampCoping (metal), RampDeck. A
                   quarter-pipe, ~10 wide (X) x radius 5 high.

Built Z-up, base at Z=0, 1 unit = 1 stud. Balloons + SkateRamp scale to a
target size in-game; BasketballHoop + PierSection are authored 1:1 (placed
without scaling so their heights line up with the map).

Run in Blender (Scripting -> Open -> Reload -> Run). Then in Studio import each
blender/out/<Name>.fbx and Save assets/studio/<Name>.rbxm.
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


def cyl(r, depth, loc, bucket, rot=(0, 0, 0), verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    return _finish(bpy.context.active_object, rot, bucket)


def ball(r, loc, bucket, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    return _finish(o, (0, 0, 0), bucket)


def torus(major_r, minor_r, loc, bucket, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_r, minor_radius=minor_r, location=loc,
                                     major_segments=20, minor_segments=8)
    return _finish(bpy.context.active_object, rot, bucket)


def join_bevel(parts, name, bevel=0.02):
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
        m.segments = 1
        bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_flat()


def export(filename):
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, filename)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True,
                             apply_unit_scale=True, global_scale=1.0,
                             object_types={"MESH"})
    print("Exported:", out)


# ---------------------------------------------------------------- Balloons
def build_balloons():
    clear_scene()
    knots, strings = [], []
    bunches = []  # (bucket, name)
    tie = (0.0, 0.0, 0.4)  # where all strings meet, near the ground
    # 5 balloons clustered up high, each its own coloured part.
    layout = [
        ("BalloonA", (-0.9, -0.3, 6.0)),
        ("BalloonB", (0.9, 0.2, 6.3)),
        ("BalloonC", (0.0, 0.8, 6.8)),
        ("BalloonD", (-0.5, 0.7, 5.6)),
        ("BalloonE", (0.7, -0.7, 5.7)),
    ]
    for pname, (bx, by, bz) in layout:
        bucket = []
        # teardrop = ico sphere squashed a touch and pulled up
        ball(0.85, (bx, by, bz), bucket, scale=(1.0, 1.0, 1.18))
        # little knot cone at the bottom of the balloon
        cyl(0.16, 0.28, (bx, by, bz - 0.95), knots, verts=6)
        join_bevel(bucket, pname, bevel=0.0)
        bunches.append((bx, by, bz))
        # string from knot down to the tie point
        kx, ky, kz = bx, by, bz - 1.05
        mid = ((kx + tie[0]) / 2, (ky + tie[1]) / 2, (kz + tie[2]) / 2)
        dx, dy, dz = tie[0] - kx, tie[1] - ky, tie[2] - kz
        dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        # thin cylinder oriented along the knot->tie vector (approx: tilt by XZ/YZ)
        ax = math.degrees(math.atan2(math.sqrt(dx * dx + dy * dy), -dz)) if dist > 0 else 0
        az = math.degrees(math.atan2(dy, dx))
        c = cyl(0.04, dist, mid, [], verts=6, rot=(0, 0, 0))
        c.rotation_euler = (math.radians(ax), 0, math.radians(az + 90))
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        strings.append(c)
    join_bevel(knots, "Knot")
    join_bevel(strings, "String", bevel=0.0)
    export("Balloons.fbx")


# ---------------------------------------------------------------- BasketballHoop
def build_basketball_hoop():
    clear_scene()
    pole, board, rim, net = [], [], [], []
    RIM_Z = 5.9          # rim height above the base (matches world court->sensor)
    board_z = RIM_Z + 0.9
    # Pole: rises at the back, then an arm reaches forward to the backboard.
    cyl(0.35, RIM_Z + 1.4, (0.0, -1.6, (RIM_Z + 1.4) / 2), pole)          # vertical post (behind)
    box((0.35, 1.6, 0.35), (0.0, -0.8, board_z), pole)                    # arm to backboard
    # Backboard (faces +Y, toward the court): 6 wide (X) x 3.6 tall (Z).
    box((6.0, 0.25, 3.6), (0.0, 0.0, board_z), board)
    box((2.4, 0.10, 1.6), (0.0, 0.14, RIM_Z + 0.6), board)                # shooter's square (trim)
    # Rim: a torus lying flat, just in front of the backboard.
    torus(0.9, 0.09, (0.0, 0.95, RIM_Z), rim, rot=(90, 0, 0))
    # Net: a short tapering ring of strands under the rim.
    for k in range(10):
        a = math.radians(k * 36)
        sx, sy = math.cos(a) * 0.82, math.sin(a) * 0.82 + 0.95
        box((0.05, 0.05, 1.1), (sx, sy - 0.0, RIM_Z - 0.55), net,
            rot=(math.degrees(math.atan2(0.35, 1.1)) * math.cos(a),
                 0, 0))
    join_bevel(pole, "HoopPole")
    join_bevel(board, "Backboard")
    join_bevel(rim, "Rim", bevel=0.0)
    join_bevel(net, "Net", bevel=0.0)
    export("BasketballHoop.fbx")


# ---------------------------------------------------------------- PierSection
def build_pier_section():
    clear_scene()
    deck, seam, piling, railpost, rail = [], [], [], [], []
    BAY = 11.0          # length of one bay along X
    W = 9.0             # width across (Y)
    DECK_Z = 7.6        # deck centre height (world deckY); thickness 0.5
    # Deck plank slab.
    box((BAY, W, 0.5), (0, 0, DECK_Z), deck)
    # Plank seams across the deck (darker grooves running across the width).
    for i in range(1, 4):
        sx = -BAY / 2 + BAY * (i / 4)
        box((0.22, W, 0.52), (sx, 0, DECK_Z + 0.01), seam)
    # Two round pilings at the bay's leading edge, from seabed (Z=0) to deck.
    for oy in (-W / 2 + 0.9, W / 2 - 0.9):
        cyl(0.55, DECK_Z, (-BAY / 2 + 0.9, oy, DECK_Z / 2), piling)
    # Rail posts + top rail along both long edges.
    for oy in (-W / 2 + 0.3, W / 2 - 0.3):
        for rx in (-BAY / 2 + 1.5, BAY / 2 - 1.5):
            box((0.35, 0.35, 2.4), (rx, oy, DECK_Z + 0.25 + 1.2), railpost)
        box((BAY, 0.28, 0.28), (0, oy, DECK_Z + 0.25 + 2.1), rail)
    join_bevel(deck, "PierDeck")
    join_bevel(seam, "PierSeam", bevel=0.0)
    join_bevel(piling, "PierPiling")
    join_bevel(railpost, "PierRailPost")
    join_bevel(rail, "PierRail")
    export("PierSection.fbx")


# ---------------------------------------------------------------- SkateRamp
def build_skate_ramp():
    clear_scene()
    surface, side, coping, deck = [], [], [], []
    R = 5.0             # radius / height of the quarter-pipe
    W = 10.0            # width along X (skating direction is along Y)
    segs = 12
    # Concave riding surface: tangent slats along a quarter arc.
    # p(a): y = R*sin(a), z = R - R*cos(a); tangent tilt = a.
    prev = None
    for k in range(segs):
        a = (math.pi / 2) * (k + 0.5) / segs
        y = R * math.sin(a)
        z = R - R * math.cos(a)
        seg_len = (math.pi / 2) * R / segs + 0.15  # overlap a hair to avoid gaps
        box((W, seg_len, 0.35), (0, y, z), surface, rot=(math.degrees(a), 0, 0))
    # Solid side walls (quarter-disc approximated by vertical slabs under the curve).
    for ex in (-W / 2 + 0.25, W / 2 - 0.25):
        for k in range(segs):
            a = (math.pi / 2) * (k + 0.5) / segs
            y = R * math.sin(a)
            z = R - R * math.cos(a)
            box((0.5, (math.pi / 2) * R / segs + 0.15, z), (ex, y, z / 2), side)
    # Coping: a metal pipe along the top front lip.
    cyl(0.22, W, (0, R, R), coping, rot=(0, 90, 0))
    # Top deck platform behind the curve.
    box((W, 2.4, 0.4), (0, R + 1.2, R - 0.2), deck)
    join_bevel(surface, "RampSurface")
    join_bevel(side, "RampSide")
    join_bevel(coping, "RampCoping")
    join_bevel(deck, "RampDeck")
    export("SkateRamp.fbx")


build_balloons()
build_basketball_hoop()
build_pier_section()
build_skate_ramp()
print("Done. Import each blender/out/*.fbx -> Save assets/studio/<Name>.rbxm "
      "(Balloons, BasketballHoop, PierSection, SkateRamp).")
