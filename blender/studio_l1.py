"""
M7 - Level 1 studio facade: HUMBLE / basic (the scrappy starter).

Deliberately plain: flat wall panels, a few small square windows with a simple
thin frame, a basic door surround, and one thin top trim line. No awnings, no
flower boxes, no columns, no ornament -- that detail arrives at L2 and L3.

Parts named Body / Trim / Win (the game paints them, tier-0 humble palette).
Footprint 48 wide x 12 tall, door gap X -3..3 / Z 0..7, front -Y. 1 unit = 1 stud.

Run in Blender (Scripting -> Open -> Reload -> ▶ Run). Exports
blender/out/StudioL1.fbx -> Save assets/studio/StudioL1.rbxm.
"""

import bpy
import os

TH = 1.0
FRONT = -TH / 2
body, trim, win = [], [], []


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for item in list(coll):
            coll.remove(item)


def box(dims, loc, bucket):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = dims
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
    o = bpy.context.active_object
    o.name = name
    if bevel > 0:
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = 1
        bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_flat()


def small_window(cx, cz):
    s = 2.6
    box((s, 0.3, s), (cx, FRONT + 0.02, cz), win)                 # plain glass
    b = 0.28
    box((s + 2 * b, 0.3, b), (cx, FRONT - 0.12, cz + s / 2 + b / 2), trim)  # frame top
    box((s + 2 * b, 0.3, b), (cx, FRONT - 0.12, cz - s / 2 - b / 2), trim)  # frame bottom
    box((b, 0.3, s), (cx - s / 2 - b / 2, FRONT - 0.12, cz), trim)          # frame left
    box((b, 0.3, s), (cx + s / 2 + b / 2, FRONT - 0.12, cz), trim)          # frame right


def build():
    clear_scene()
    # Plain wall panels + lintel over the door.
    box((21, TH, 12), (-13.5, 0, 6), body)
    box((21, TH, 12), (13.5, 0, 6), body)
    box((6, TH, 5), (0, 0, 9.5), body)

    # One thin top trim line + a plain base.
    box((49, TH + 0.3, 0.5), (0, 0, 11.6), trim)
    box((49, TH + 0.3, 0.6), (0, 0, 0.4), trim)

    # Basic door surround.
    box((0.6, TH + 0.4, 7), (-3.3, 0, 3.5), trim)
    box((0.6, TH + 0.4, 7), (3.3, 0, 3.5), trim)
    box((7.2, TH + 0.4, 0.6), (0, 0, 7.2), trim)

    # A few small, sparse windows (humble).
    for cx in (-18, -9, 9, 18):
        small_window(cx, 6.5)

    join_bevel(body, "Body")
    join_bevel(trim, "Trim")
    join_bevel(win, "Win", bevel=0.0)


def export():
    out = os.path.join(r"/Users/kirill/projects/roblox game", "blender", "out", "StudioL1.fbx")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True,
                             apply_unit_scale=True, global_scale=1.0,
                             object_types={"MESH"})
    print("Exported:", out)


build()
export()
print("Done. Import blender/out/StudioL1.fbx -> Save assets/studio/StudioL1.rbxm")
