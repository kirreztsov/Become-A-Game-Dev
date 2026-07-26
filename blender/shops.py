"""
M7 shop storefront: a detailed Blender facade that mounts on the front of each
lobby shop, replacing the plain procedural front wall. The doorway gap, roof,
side/back walls, interior counter, shopkeeper NPC and buy-prompt all stay as
they are -- this only dresses up the storefront.

Part names drive in-game colouring:
  ShopFront -> Body (cream wall), Awning (per-shop colour), Win (glass),
               Trim (door frame + window frames + plinth).

Built Z-up, base at Z=0, the OUTWARD face toward +Y (-> +Z in-game, the street).
15 studs wide x 8 tall, door gap X -2..2 / Z 0..6. 1 unit = 1 stud.

Run in Blender (Scripting -> Open -> Reload -> ▶ Run). Then in Studio import
blender/out/ShopFront.fbx and Save assets/studio/ShopFront.rbxm.
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


def box(dims, loc, bucket, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = dims
    if rot != (0, 0, 0):
        o.rotation_euler = (math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bucket.append(o)
    return o


def join_bevel(parts, name, bevel=0.03):
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


def build_shopfront():
    clear_scene()
    body, awning, win, trim = [], [], [], []
    # Flanking wall panels (door gap is X -2..2) + lintel over the door.
    box((5.5, 1.0, 8.0), (-4.75, 0, 4.0), body)
    box((5.5, 1.0, 8.0), (4.75, 0, 4.0), body)
    box((15.0, 1.0, 2.0), (0, 0, 7.0), body)          # lintel above the door
    box((15.0, 1.1, 0.8), (0, 0, 0.4), trim)          # base plinth
    # Door surround.
    box((0.5, 1.2, 6.3), (-2.2, 0, 3.15), trim)
    box((0.5, 1.2, 6.3), (2.2, 0, 3.15), trim)
    box((5.0, 1.2, 0.5), (0, 0, 6.2), trim)
    # Big storefront windows on each panel (protrude slightly toward +Y).
    for cx in (-4.75, 4.75):
        box((3.8, 0.3, 3.4), (cx, 0.55, 4.3), win)
        box((4.3, 0.4, 0.3), (cx, 0.5, 6.05), trim)   # frame top
        box((4.3, 0.4, 0.3), (cx, 0.5, 2.55), trim)   # frame bottom
        box((0.3, 0.4, 3.7), (cx - 2.0, 0.5, 4.3), trim)
        box((0.3, 0.4, 3.7), (cx + 2.0, 0.5, 4.3), trim)
        box((0.22, 0.42, 3.4), (cx, 0.5, 4.3), trim)  # mullion
    # Striped awning slab sloping out over the street, kept within Z 0..8.
    box((15.6, 2.6, 0.4), (0, 1.5, 6.6), awning, rot=(-52, 0, 0))
    box((15.6, 0.5, 0.9), (0, 2.7, 5.5), awning)      # awning front valance
    join_bevel(body, "Body")
    join_bevel(awning, "Awning", bevel=0.0)
    join_bevel(win, "Win", bevel=0.0)
    join_bevel(trim, "Trim")
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "ShopFront.fbx"), use_selection=True,
                             apply_unit_scale=True, global_scale=1.0, object_types={"MESH"})
    print("Exported ShopFront.fbx")


build_shopfront()
print("Done. Import blender/out/ShopFront.fbx -> Save assets/studio/ShopFront.rbxm")
