"""
M7 props batch 3: beach + plaza structures to replace procedural builders in
Lobby.luau with detailed Blender meshes.

Props (part names drive in-game colouring):
  LifeguardTower -> TowerWood (legs/platform/ladder), TowerWall (cream sides),
                    TowerRed (back wall + roof). Open front faces +Y.
  PicnicTable    -> PicnicWood (top + seats), PicnicLeg (A-frame legs)
  MarketStall    -> StallWood (counter/posts), StallCanopyA/B (striped roof),
                    StallProduce (goods)
  FoodCart       -> CartBody (per-instance colour), CartTrim (counter/posts),
                    CartWheel, CartCanopyA/B (stripes), CartSign (emoji re-added
                    in Lua). Front faces +Y.

Built Z-up, base at Z=0, 1 unit = 1 stud. Final size set in-game.

Run in Blender (Scripting -> Open -> Reload -> ▶ Run). Then in Studio import
each blender/out/<Name>.fbx and Save assets/studio/<Name>.rbxm.
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


def cyl(r, depth, loc, bucket, rot=(0, 0, 0), verts=18):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    return _finish(bpy.context.active_object, rot, bucket)


def ball(r, loc, bucket):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=loc)
    return _finish(bpy.context.active_object, (0, 0, 0), bucket)


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


def export(filename):
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, filename)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True,
                             apply_unit_scale=True, global_scale=1.0,
                             object_types={"MESH"})
    print("Exported:", out)


# ---------------------------------------------------------------- LifeguardTower
def build_tower():
    clear_scene()
    wood, wall, red = [], [], []
    platY = 6.0
    for ox in (-3, 3):                                     # 4 stilts
        for oy in (-3, 3):
            box((0.6, 0.6, platY), (ox, oy, platY / 2), wood)
    box((8.2, 8.2, 0.5), (0, 0, platY + 0.25), wood)       # platform
    box((8.0, 0.4, 4.0), (0, -3.8, platY + 2.3), red)      # back wall (-Y)
    box((0.4, 8.0, 4.0), (-3.8, 0, platY + 2.3), wall)     # left wall
    box((0.4, 8.0, 4.0), (3.8, 0, platY + 2.3), wall)      # right wall
    box((8.0, 0.4, 1.2), (0, 3.8, platY + 1.1), wall)      # front rail (+Y open)
    box((9.6, 9.8, 0.45), (0, 0, platY + 4.6), red, rot=(12, 0, 0))  # slanted roof
    box((0.4, 0.4, 4.6), (0, -3.8, platY + 4.6), wood)     # roof back support
    # Ladder down the front (+Y).
    for oz in range(5):
        box((3.6, 0.3, 0.28), (0, 4.1, 1.0 + oz * 1.0), wood)
    for lx in (-1.7, 1.7):
        box((0.28, 0.3, 5.2), (lx, 4.1, 2.8), wood)
    join_bevel(wood, "TowerWood")
    join_bevel(wall, "TowerWall")
    join_bevel(red, "TowerRed")
    export("LifeguardTower.fbx")


# ---------------------------------------------------------------- PicnicTable
def build_picnic():
    clear_scene()
    top, leg = [], []
    box((5.0, 2.4, 0.32), (0, 0, 2.15), top)               # table top
    for oy in (-1.7, 1.7):                                  # 2 bench seats
        box((5.0, 0.95, 0.3), (0, oy, 1.15), top)
    # A-frame legs at each end: two slanted boards forming an A.
    for ex in (-2.0, 2.0):
        box((0.4, 0.4, 2.6), (ex, -1.2, 1.1), leg, rot=(-24, 0, 0))
        box((0.4, 0.4, 2.6), (ex, 1.2, 1.1), leg, rot=(24, 0, 0))
        box((0.4, 3.2, 0.35), (ex, 0, 1.35), leg)          # cross brace
    join_bevel(top, "PicnicWood")
    join_bevel(leg, "PicnicLeg")
    export("PicnicTable.fbx")


# ---------------------------------------------------------------- MarketStall
def build_stall():
    clear_scene()
    woodb, ca, cb, produce = [], [], [], []
    box((5.0, 1.6, 1.7), (0, -1.4, 0.85), woodb)           # counter
    for ox in (-2.4, 2.4):                                  # 4 posts
        for oy in (-2, 2):
            box((0.3, 0.3, 5.0), (ox, oy, 2.5), woodb)
    box((6.2, 5.2, 0.45), (0, 0, 5.2), ca)                 # roof base
    for i in range(-2, 3):                                  # white stripes
        box((0.95, 5.2, 0.5), (i * 1.2, 0, 5.35), cb)
    box((6.2, 0.5, 0.7), (0, 2.55, 5.0), ca)               # front valance
    for i in (-1, 0, 1):                                    # produce on counter
        ball(0.45, (i * 1.2, -1.4, 1.9), produce)
    join_bevel(woodb, "StallWood")
    join_bevel(ca, "StallCanopyA", bevel=0.0)
    join_bevel(cb, "StallCanopyB", bevel=0.0)
    join_bevel(produce, "StallProduce")
    export("MarketStall.fbx")


# ---------------------------------------------------------------- FoodCart
def build_cart():
    clear_scene()
    body, trim, wheel, ca, cb, sign = [], [], [], [], [], []
    box((4.4, 2.4, 2.0), (0, 0, 1.6), body)                # cart body
    box((4.7, 2.7, 0.35), (0, 0, 2.75), trim)              # counter top
    for ox in (-1.4, 1.4):                                  # 4 wheels (axis Y)
        for oy in (-1.15, 1.15):
            cyl(0.7, 0.4, (ox, oy, 0.7), wheel, rot=(90, 0, 0), verts=16)
    for ox in (-2.0, 2.0):                                  # canopy posts
        box((0.22, 0.22, 1.8), (ox, 0, 3.7), trim)
    box((5.2, 3.2, 0.4), (0, 0, 4.7), ca)                  # canopy base
    for i in (-1, 0, 1):                                    # canopy stripes
        box((1.05, 3.2, 0.45), (i * 1.7, 0, 4.83), cb)
    box((1.7, 0.22, 1.7), (0, 1.5, 3.5), sign)             # emoji sign board (+Y front)
    join_bevel(body, "CartBody")
    join_bevel(trim, "CartTrim")
    join_bevel(wheel, "CartWheel")
    join_bevel(ca, "CartCanopyA", bevel=0.0)
    join_bevel(cb, "CartCanopyB", bevel=0.0)
    join_bevel(sign, "CartSign", bevel=0.0)
    export("FoodCart.fbx")


build_tower()
build_picnic()
build_stall()
build_cart()
print("Done. Import each blender/out/*.fbx -> Save assets/studio/<Name>.rbxm "
      "(LifeguardTower, PicnicTable, MarketStall, FoodCart).")
