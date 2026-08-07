"""
Detailed PC component display models for the physical PC Store shelves
(replaces the coloured placeholder boxes): a graphics card, a gaming monitor,
and an RGB tower case. Built from plain boxes + cylinders + a bevel -- the SAME
pattern as controller.py / props1-4 that imported cleanly. No lathe, no
subdivision-surface, no 3D text (those broke earlier imports).

Part names drive in-game colour (set by Lobby.buildPCStoreShelves after clone):
  PCGpu     -> Shroud / Backplate / Fan1..3 / Bracket / Accent
  PCMonitor -> Bezel / Screen / Neck / Base / Accent
  PCTower   -> Case / Front / Glass / Fan1..3 / Feet / Accent / Inner* / Cooler

Built Z-up, 1 unit = 1 stud, "front" toward -Y (fans / screen / glass face -Y;
Lobby spins each model so the front faces the aisle). Each model's base sits at
z = 0 so placeProp seats it on the shelf pedestal.

Run in Blender: Scripting -> Open this file -> (Text menu -> Reload if it was
already open) -> Run. It writes THREE files:
  blender/out/PCGpu.fbx, PCMonitor.fbx, PCTower.fbx
Then in Studio, for EACH: Home -> Import 3D -> pick the fbx -> Import ->
right-click the Model -> Save to File -> save to Downloads as
PCGpu.rbxm / PCMonitor.rbxm / PCTower.rbxm, then delete the import from Workspace.
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


def fan_y(center, r, bucket, blades=11):
    """A fan facing -Y (axis along Y): square frame + hub + radial blades, in the
    X-Z plane. All parts go in `bucket` (one colour)."""
    cx, cy, cz = center
    t = 0.14
    box((2 * r + 2 * t, 0.30, t), (cx, cy, cz + r + t / 2), bucket)   # frame top
    box((2 * r + 2 * t, 0.30, t), (cx, cy, cz - r - t / 2), bucket)   # frame bottom
    box((t, 0.30, 2 * r), (cx + r + t / 2, cy, cz), bucket)          # frame right
    box((t, 0.30, 2 * r), (cx - r - t / 2, cy, cz), bucket)          # frame left
    cyl(0.20, 0.34, (cx, cy - 0.02, cz), bucket, rot=(90, 0, 0))     # hub
    for k in range(blades):
        a = k * 2 * math.pi / blades
        bx = cx + math.cos(a) * r * 0.52
        bz = cz + math.sin(a) * r * 0.52
        box((r * 0.92, 0.06, 0.24), (bx, cy - 0.03, bz), bucket, rot=(0, 0, math.degrees(a) + 20))


def fan_x(center, r, bucket, blades=11):
    """A fan facing -X (axis along X): square frame + hub + radial blades, in the
    Y-Z plane. All parts go in `bucket`."""
    cx, cy, cz = center
    t = 0.14
    box((0.30, 2 * r + 2 * t, t), (cx, cy, cz + r + t / 2), bucket)   # frame top
    box((0.30, 2 * r + 2 * t, t), (cx, cy, cz - r - t / 2), bucket)   # frame bottom
    box((0.30, t, 2 * r), (cx, cy + r + t / 2, cz), bucket)          # frame +Y
    box((0.30, t, 2 * r), (cx, cy - r - t / 2, cz), bucket)          # frame -Y
    cyl(0.20, 0.34, (cx - 0.02, cy, cz), bucket, rot=(0, 90, 0))     # hub
    for k in range(blades):
        a = k * 2 * math.pi / blades
        by = cy + math.cos(a) * r * 0.52
        bz = cz + math.sin(a) * r * 0.52
        box((0.06, r * 0.92, 0.24), (cx - 0.03, by, bz), bucket, rot=(math.degrees(a) + 20, 0, 0))


def join_bevel(parts, name, bevel=0.05):
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
# GPU -- a triple-fan graphics card stood UPRIGHT on its short end (the classic
# store-display pose): long axis vertical (Z), fan face toward -Y. ~4.2 studs
# tall as built. Detail: real fan blades, heatsink fins along the top edge, an
# 8-pin power connector, an I/O bracket with display-port slots.
# --------------------------------------------------------------------------
def build_gpu():
    clear_scene()
    shroud, back, bracket, accent = [], [], [], []
    f1, f2, f3 = [], [], []

    # Thick 3-slot shroud + PCB backplate (Gaming Trio bulk).
    box((1.7, 1.4, 4.2), (0, 0.05, 2.15), shroud)
    box((1.82, 0.16, 4.3), (0, 0.82, 2.15), back)
    # Raised ribs on the backplate (stylised vents).
    for k in range(5):
        box((0.12, 0.06, 3.4), (-0.6 + k * 0.3, 0.92, 2.15), back)
    # Front lip framing the fans (top & bottom plates) + two centre dividers.
    box((1.72, 0.18, 0.20), (0, -0.66, 4.05), shroud)
    box((1.72, 0.18, 0.20), (0, -0.66, 0.28), shroud)
    box((1.72, 0.18, 0.14), (0, -0.66, 1.62), shroud)
    box((1.72, 0.18, 0.14), (0, -0.66, 2.72), shroud)
    # Diagonal RGB accent slashes across the shroud front.
    box((0.10, 0.10, 1.1), (0.55, -0.72, 3.4), accent, rot=(0, 0, 32))
    box((0.10, 0.10, 1.1), (-0.55, -0.72, 0.9), accent, rot=(0, 0, 32))
    # Heatsink fins peeking out the +X side.
    for k in range(8):
        box((0.10, 1.15, 0.42), (0.86, 0.1, 0.6 + k * 0.44), shroud)
    # Dual 8-pin power connectors on the top edge.
    box((0.6, 0.45, 0.28), (0.55, 0.2, 4.32), shroud)
    box((0.6, 0.45, 0.28), (-0.15, 0.2, 4.32), shroud)
    # Lit logo bar down the +X top edge.
    box((0.12, 0.14, 2.2), (0.86, -0.5, 2.6), accent)
    # Metal I/O bracket across the bottom + HDMI/DP port bumps + face screws.
    box((1.85, 1.05, 0.22), (0, 0.05, 0.10), bracket)
    box((0.5, 0.30, 0.12), (-0.55, -0.4, 0.10), shroud)          # HDMI port
    for sx in (-0.25, 0.1, 0.45, 0.8):
        box((0.16, 0.30, 0.12), (sx, -0.4, 0.10), shroud)        # DP ports
    for sx, sz in ((-0.78, 0.5), (0.78, 0.5), (-0.78, 3.8), (0.78, 3.8)):
        cyl(0.09, 0.10, (sx, -0.70, sz), bracket, rot=(90, 0, 0))  # face screws

    # Three fans (with a lit RGB hub dot each) stacked up the -Y face.
    for fz, fbk in ((1.05, f1), (2.15, f2), (3.25, f3)):
        fan_y((0, -0.60, fz), 0.62, fbk)
        cyl(0.10, 0.16, (0, -0.80, fz), accent, rot=(90, 0, 0))

    # RGB accent strip down the front-left edge.
    box((0.14, 0.12, 3.5), (-0.80, -0.70, 2.15), accent)

    join_bevel(shroud, "Shroud", bevel=0.05)
    join_bevel(back, "Backplate", bevel=0.02)
    join_bevel(bracket, "Bracket", bevel=0.02)
    join_bevel(f1, "Fan1", bevel=0.02)
    join_bevel(f2, "Fan2", bevel=0.02)
    join_bevel(f3, "Fan3", bevel=0.02)
    join_bevel(accent, "Accent", bevel=0.02)
    export("PCGpu.fbx")


# --------------------------------------------------------------------------
# MONITOR -- a SUPER-ULTRAWIDE CURVED gaming monitor (V7 49" DQHD style), screen
# toward -Y. The curve is faked with 7 flat panel segments across an arc (edges
# pulled toward the viewer, each turned tangent). Thin bezel, central pillar +
# tripod stand. ~8.6 studs WIDE (Lobby scales it by WIDTH so it fits the shelf).
# --------------------------------------------------------------------------
def build_monitor():
    clear_scene()
    bezel, screen, neck, base, accent = [], [], [], [], []

    SZ = 3.4          # centre height of the panel
    PANEL_H = 2.3
    HALF = 4.0        # half the panel width
    SEGS = 11
    seg_w = (2 * HALF) / SEGS
    for i in range(SEGS):
        x = -HALF + seg_w * (i + 0.5)
        t = x / HALF                       # -1 .. 1 across the panel
        y = 0.15 - 0.55 * (t * t)          # concave: edges pulled to viewer (-Y)
        rz = -18.0 * t                     # turn each segment tangent to the arc
        box((seg_w + 0.12, 0.24, PANEL_H + 0.20), (x, y + 0.14, SZ), bezel, rot=(0, 0, rz))   # bezel-back
        box((seg_w + 0.01, 0.10, PANEL_H), (x, y, SZ), screen, rot=(0, 0, rz))                # bright panel
        box((seg_w + 0.02, 0.06, 0.14), (x, y + 0.30, SZ + 0.75), accent, rot=(0, 0, rz))     # rear RGB strip
    # Chin: centre logo bar + power LED + a control joystick nub on the back-right.
    box((0.9, 0.10, 0.14), (0, -0.20, SZ - PANEL_H / 2 - 0.02), accent)
    box((0.14, 0.12, 0.12), (2.7, 0.02, SZ - PANEL_H / 2 - 0.02), accent)
    box((0.3, 0.22, 0.3), (2.4, 0.42, SZ - 0.1), bezel)
    cyl(0.07, 0.22, (2.4, 0.6, SZ - 0.1), bezel, rot=(90, 0, 0))

    # Central pillar (with a cable-management slot) + tripod base.
    box((0.55, 0.7, 2.0), (0, 0.35, 1.35), neck)
    box((0.5, 0.16, 0.5), (0, 0.02, 1.1), neck)                        # cable clip housing
    box((0.9, 0.9, 0.10), (0, 0.35, 0.24), base)                       # brushed top plate
    box((1.0, 1.0, 0.22), (0, 0.35, 0.11), base)                       # base hub
    box((2.4, 0.5, 0.18), (0.85, -0.45, 0.09), base, rot=(0, 0, -30))  # front-right leg
    box((2.4, 0.5, 0.18), (-0.85, -0.45, 0.09), base, rot=(0, 0, 30))  # front-left leg
    box((1.5, 0.5, 0.18), (0, 1.15, 0.09), base)                       # back leg

    join_bevel(bezel, "Bezel", bevel=0.03)
    join_bevel(screen, "Screen", bevel=0.02)
    join_bevel(neck, "Neck", bevel=0.04)
    join_bevel(base, "Base", bevel=0.04)
    join_bevel(accent, "Accent", bevel=0.02)
    export("PCMonitor.fbx")


# --------------------------------------------------------------------------
# TOWER -- an RGB mid-tower (Raider style): mesh FRONT (-Y) holding three RGB
# fans facing the viewer, a tempered-glass side (-X) showing the internals
# (motherboard, a horizontal GPU, two RAM sticks, a round CPU cooler) and the
# backs of the front fans. Raised on four feet. ~4.6 studs tall as built.
# --------------------------------------------------------------------------
def build_tower():
    clear_scene()
    case, front, glass, feet, accent = [], [], [], [], []
    board, cooler = [], []
    f1, f2, f3 = [], [], []

    box((2.2, 4.6, 4.4), (0, 0.0, 2.55), case)          # main body
    box((0.10, 4.2, 4.0), (-1.12, 0.0, 2.55), glass)    # tempered-glass side (-X)

    # Open front bezel (NO solid backing -- the RGB fans must show through) with
    # a light grille of thin bars over the fans so it still reads as a mesh intake.
    box((2.2, 0.20, 0.22), (0, -2.30, 4.70), front)     # bezel top
    box((2.2, 0.20, 0.22), (0, -2.30, 0.40), front)     # bezel bottom
    box((0.22, 0.20, 4.5), (-1.0, -2.30, 2.55), front)  # bezel left
    box((0.22, 0.20, 4.5), (1.0, -2.30, 2.55), front)   # bezel right
    # Three RGB fans right at the front opening, clearly visible (-Y).
    fan_y((0, -2.18, 1.35), 0.62, f1)
    fan_y((0, -2.18, 2.55), 0.62, f2)
    fan_y((0, -2.18, 3.75), 0.62, f3)
    # Thin grille bars OVER the fans (fans glow through the gaps).
    for zz in (0.95, 1.75, 2.15, 2.95, 3.35, 4.15):
        box((1.9, 0.10, 0.08), (0, -2.44, zz), front)
    for vx in (-0.5, 0.5):
        box((0.08, 0.10, 3.9), (vx, -2.44, 2.55), front)
    # Vertical RGB light strip at the front-left inner edge (glows through glass).
    box((0.12, 0.12, 3.6), (-0.92, -2.0, 2.55), accent)

    # Top panel: power button, USB slots, and exhaust vent slats.
    box((0.24, 0.24, 0.12), (0.5, -1.4, 4.86), accent)  # power button
    box((0.5, 0.16, 0.10), (-0.2, -1.4, 4.86), front)   # USB slots
    for k in range(4):
        box((1.5, 0.13, 0.08), (0, -0.2 + k * 0.5, 4.85), front)

    # Rear I/O shield on the +Y back with a few port bumps.
    box((1.5, 0.10, 1.3), (-0.1, 2.30, 3.7), case)
    for pz in (3.35, 3.75, 4.15):
        box((0.9, 0.16, 0.16), (-0.1, 2.34, pz), case)

    # Internals visible through the glass (mounted on the +X inner wall).
    box((0.10, 3.2, 3.2), (0.62, 0.2, 2.9), board)       # motherboard plane
    box((0.7, 2.4, 0.5), (0.2, 0.0, 1.85), board)        # horizontal GPU
    for rz in (0.75, 1.05, 1.35, 1.65):                  # four RAM sticks
        box((0.16, 0.35, 1.1), (0.28, rz, 3.6), board)
    cyl(0.55, 0.5, (0.25, 0.4, 3.5), cooler, rot=(0, 90, 0))  # CPU cooler body
    for a in range(6):                                   # cooler fins
        box((0.42, 0.06, 1.0), (0.25, 0.4, 3.5), cooler, rot=(a * 30, 90, 0))
    # PSU shroud along the bottom + a storage drive sitting on it.
    box((0.95, 3.0, 0.8), (0.3, 0.0, 0.65), case)
    box((0.7, 1.0, 0.5), (0.25, -0.7, 1.35), case)       # SSD/HDD
    # A couple of cables running from the shroud up to the board.
    box((0.10, 0.10, 1.3), (0.55, 0.9, 1.7), case, rot=(12, 0, 0))
    box((0.10, 0.10, 1.1), (0.55, -0.5, 1.5), case, rot=(-10, 0, 0))

    # RGB light bar down the front-left corner + four feet (case sits raised).
    box((0.12, 0.14, 3.9), (-1.06, -2.30, 2.55), accent)
    for fx in (-0.8, 0.8):
        for fy in (-1.8, 1.8):
            box((0.4, 0.4, 0.3), (fx, fy, 0.15), feet)

    join_bevel(case, "Case", bevel=0.07)
    join_bevel(front, "Front", bevel=0.02)
    join_bevel(glass, "Glass", bevel=0.02)
    join_bevel(feet, "Feet", bevel=0.02)
    join_bevel(accent, "Accent", bevel=0.02)
    join_bevel(board, "InnerBoard", bevel=0.02)
    join_bevel(cooler, "Cooler", bevel=0.03)
    join_bevel(f1, "Fan1", bevel=0.02)
    join_bevel(f2, "Fan2", bevel=0.02)
    join_bevel(f3, "Fan3", bevel=0.02)
    export("PCTower.fbx")


build_gpu()
build_monitor()
build_tower()
print("Done. Import PCGpu.fbx / PCMonitor.fbx / PCTower.fbx and save the 3 rbxm files.")
