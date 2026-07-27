"""
M7 studio interiors (4a): a proper Desk and office Chair to replace the blocky
procedural desk/chair inside the studios. Sized to the exact current layout so
the functional monitor + Seat still line up:

  Desk  -- 6 wide (X) x 3 deep (Z), TOP SURFACE at Z=2.5 (sits on the studio
           floor; the monitor sits on this surface). Parts: DeskTop (wood),
           DeskFrame (dark legs + modesty panel).
  Chair -- an office chair; SEAT CUSHION centred at Z=1.2 (matches the Seat),
           faces +Y (-> +Z in game, toward the monitor). Parts: ChairSeat
           (cushion + back), ChairFrame (dark base/pedestal/arms).

1 unit = 1 stud. Run in Blender (Scripting -> Open -> Reload -> ▶ Run). Import
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


def box(dims, loc, bucket, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = dims
    if rot != (0, 0, 0):
        o.rotation_euler = (math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bucket.append(o)
    return o


def cyl(r, depth, loc, bucket, rot=(0, 0, 0), verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    o = bpy.context.active_object
    if rot != (0, 0, 0):
        o.rotation_euler = (math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
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


def export(filename):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, filename), use_selection=True,
                             apply_unit_scale=True, global_scale=1.0, object_types={"MESH"})
    print("Exported:", filename)


def build_desk():
    clear_scene()
    top, frame = [], []
    box((6.0, 3.0, 0.4), (0, 0, 2.3), top)                 # top surface ~2.5
    box((6.0, 0.5, 0.5), (0, -1.15, 2.15), top)            # front apron
    for sx in (-2.6, 2.6):
        for sy in (-1.1, 1.1):
            box((0.5, 0.5, 2.1), (sx, sy, 1.05), frame)    # legs
    box((5.4, 0.3, 1.7), (0, 1.15, 1.05), frame)           # modesty back panel (+Y)
    box((1.7, 2.4, 1.8), (2.05, 0.1, 1.05), frame)         # side drawer unit
    for dz in (1.4, 0.8):
        box((1.5, 0.12, 0.1), (2.05, -1.05, dz), top)      # drawer handles
    join_bevel(top, "DeskTop")
    join_bevel(frame, "DeskFrame")
    export("Desk.fbx")


def build_chair():
    clear_scene()
    seat, frame = [], []
    # 5-star wheeled base + pedestal.
    for k in range(5):
        a = math.radians(k * 72)
        box((1.3, 0.28, 0.24), (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.2), frame, rot=(0, 0, k * 72))
        cyl(0.16, 0.3, (math.cos(a) * 1.0, math.sin(a) * 1.0, 0.15), frame, rot=(90, 0, 0))  # castor
    cyl(0.18, 1.0, (0, 0, 0.7), frame)                     # gas pedestal
    box((1.8, 1.8, 0.4), (0, 0, 1.2), seat)                # seat cushion (~1.2)
    box((1.7, 0.32, 2.0), (0, -0.8, 2.15), seat, rot=(-8, 0, 0))  # backrest (behind, -Y)
    for sx in (-0.95, 0.95):
        box((0.24, 1.4, 0.24), (sx, -0.1, 1.75), frame)    # armrests
        box((0.22, 0.22, 0.5), (sx, -0.1, 1.4), frame)     # armrest posts
    join_bevel(seat, "ChairSeat")
    join_bevel(frame, "ChairFrame")
    export("Chair.fbx")


build_desk()
build_chair()
print("Done. Import Desk.fbx + Chair.fbx -> Save assets/studio/<Name>.rbxm")
