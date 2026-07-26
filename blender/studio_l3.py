"""
M7 - Level 3 studio facade: LUXURY HQ (gold-carved palace).

The top-tier glow-up. Fluted pilasters with gold capitals + bases, tall
ARCHED windows in gold frames with keystones, a gold crest/medallion over the
door, a layered gold cornice with dentils, gold belt courses + rosette carvings
on the walls, and a grand gold door surround. Purple/cream body + lots of gold.

Parts named Body / Accent / Trim / Win / Gold (the game paints them; tier-2
palette = purple body, lighter-purple accent, and real metal GOLD ornament).
Footprint 48 wide x ~13 tall, door gap X -3..3 / Z 0..7, front -Y. 1 unit = 1 stud.

Run in Blender (Scripting -> Open -> Reload -> ▶ Run). Exports
blender/out/StudioL3.fbx -> Save assets/studio/StudioL3.rbxm.
"""

import bpy
import os
import math

TH = 1.0
FRONT = -TH / 2  # front surface of the 1-thick wall (front faces -Y)
body, accent, trim, win, gold = [], [], [], [], []


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
    if rot != (0, 0, 0):
        o.rotation_euler = (math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bucket.append(o)
    return o


def disc(radius, depth, loc, bucket):
    # A thin cylinder standing in the XZ plane (axis along Y/depth) -> a disc
    # whose round face points at the viewer. Used for arch heads & medallions.
    bpy.ops.mesh.primitive_cylinder_add(vertices=28, radius=radius, depth=depth, location=loc)
    o = bpy.context.active_object
    o.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bucket.append(o)
    return o


def join_bevel(parts, name, bevel=0.04):
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


def pilaster(x):
    # Cream/accent fluted shaft with a gold capital, gold base and a gold necking
    # ring -- a classical column pressed against the wall.
    box((1.8, 0.5, 9.6), (x, FRONT - 0.25, 5.4), accent)          # shaft (purple)
    for fx in (-0.55, 0.0, 0.55):                                  # 3 flute grooves
        box((0.16, 0.55, 9.0), (x + fx, FRONT - 0.28, 5.4), body)  # darker purple reveal
    box((2.7, 0.7, 0.9), (x, FRONT - 0.35, 10.3), gold)           # capital
    box((3.0, 0.85, 0.5), (x, FRONT - 0.45, 10.9), gold)          # capital abacus
    box((2.5, 0.7, 0.7), (x, FRONT - 0.35, 0.9), gold)            # base
    box((2.0, 0.6, 0.3), (x, FRONT - 0.3, 9.7), gold)             # necking ring


def arched_window(cx, cz, hw=2.4, hh=3.0):
    # Tall arched window: gold outer frame, glass, gold mullions, a gold arched
    # head (disc), a keystone and a gold sill.
    box((2 * hw + 1.0, 0.4, 2 * hh + 1.0), (cx, FRONT - 0.15, cz), gold)   # outer frame
    box((2 * hw, 0.3, 2 * hh), (cx, FRONT - 0.32, cz), win)                # glass
    box((0.24, 0.42, 2 * hh), (cx, FRONT - 0.42, cz), gold)                # centre mullion
    for gz in (cz - hh * 0.5, cz + hh * 0.5):                              # 2 transoms
        box((2 * hw, 0.42, 0.22), (cx, FRONT - 0.42, gz), gold)
    disc(hw + 0.6, 0.42, (cx, FRONT - 0.16, cz + hh), gold)                # arched head ring
    disc(hw - 0.05, 0.3, (cx, FRONT - 0.34, cz + hh), win)                 # arch glass fill
    box((0.9, 0.7, 1.5), (cx, FRONT - 0.5, cz + hh + 0.65), gold)          # keystone
    box((2 * hw + 1.6, 0.6, 0.55), (cx, FRONT - 0.45, cz - hh - 0.35), gold)  # sill


def rosette(cx, cz, r=0.7):
    disc(r, 0.4, (cx, FRONT - 0.35, cz), gold)
    box((0.5, 0.55, 0.5), (cx, FRONT - 0.5, cz), gold, rot=(0, 45, 0))  # diamond boss


def build():
    clear_scene()

    # --- Main body walls (purple) + solid parapet ---
    box((21, TH, 12), (-13.5, 0, 6), body)     # left  X -24..-3
    box((21, TH, 12), (13.5, 0, 6), body)      # right X  3..24
    box((6, TH, 5), (0, 0, 9.5), body)         # over-door lintel wall  Z 7..12
    box((49, TH, 1.0), (0, 0, 12.6), body)     # parapet cap band

    # --- Grand base: gold plinth molding + a step ---
    box((49, TH + 0.9, 1.2), (0, -0.25, 0.6), gold)   # gold base molding
    box((50, TH + 1.3, 0.5), (0, -0.1, 0.1), accent)  # bottom step

    # --- Belt course (subtle purple accent band) at mid-height ---
    box((49, 0.55, 0.5), (0, FRONT - 0.3, 2.2), accent)

    # --- Pilasters framing the bays and the door ---
    for px in (-22, -13.5, -5, 5, 13.5, 22):
        pilaster(px)

    # --- Four tall arched windows in the bays ---
    for cx in (-17.75, -9.25, 9.25, 17.75):
        arched_window(cx, 5.6)

    # --- Grand gold door surround ---
    box((0.8, 0.7, 7.6), (-3.5, FRONT - 0.4, 3.8), gold)   # left jamb
    box((0.8, 0.7, 7.6), (3.5, FRONT - 0.4, 3.8), gold)    # right jamb
    box((8.4, 0.8, 0.9), (0, FRONT - 0.45, 7.6), gold)     # lintel
    # Stepped pediment over the door.
    box((7.0, 0.7, 0.5), (0, FRONT - 0.4, 8.2), gold)
    box((5.0, 0.7, 0.5), (0, FRONT - 0.45, 8.7), gold)
    box((3.0, 0.7, 0.5), (0, FRONT - 0.5, 9.2), gold)

    # --- Crest / medallion over the door ---
    disc(1.9, 0.5, (0, FRONT - 0.5, 10.4), gold)          # medallion plate
    disc(1.4, 0.6, (0, FRONT - 0.65, 10.4), accent)       # inset
    box((0.7, 0.9, 0.7), (0, FRONT - 0.8, 10.4), gold, rot=(0, 45, 0))  # star boss
    for lx in (-2.1, 2.1):                                # laurel side scrolls
        disc(0.6, 0.4, (lx, FRONT - 0.45, 10.4), gold)

    # --- Wall carvings: rosettes high on the side panels ---
    for cx in (-21.5, 21.5):
        rosette(cx, 9.4)
    for cx in (-13.5, 13.5):
        rosette(cx, 2.2, r=0.55)

    # --- Layered gold cornice with dentils ---
    box((49.0, 0.6, 0.7), (0, FRONT - 0.35, 11.3), gold)
    box((50.2, 0.85, 0.6), (0, FRONT - 0.6, 11.85), gold)
    box((49.6, 1.05, 0.5), (0, FRONT - 0.85, 12.35), gold)   # crown lip
    x = -23.0
    while x <= 23.0:                                          # dentil row
        box((0.7, 0.6, 0.5), (x, FRONT - 0.5, 10.85), gold)
        x += 2.0

    join_bevel(body, "Body")
    join_bevel(accent, "Accent")
    join_bevel(trim, "Trim")
    join_bevel(win, "Win", bevel=0.0)
    join_bevel(gold, "Gold")


def export():
    out = os.path.join(r"/Users/kirill/projects/roblox game", "blender", "out", "StudioL3.fbx")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True,
                             apply_unit_scale=True, global_scale=1.0,
                             object_types={"MESH"})
    print("Exported:", out)


build()
export()
print("Done. Import blender/out/StudioL3.fbx -> Save assets/studio/StudioL3.rbxm")
