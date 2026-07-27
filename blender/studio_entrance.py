"""
M7 - Studio creator ENTRANCE props (ground floor), growing per tier.

Props are named  T<tier>_<Role>  so the game reveals more as you upgrade and
colours each by role:
  T1_Plaque (play-button award)  T1_PlayTri  T1_Camera  T1_Tripod
  T2_SpotStand  T2_SpotBox  T2_OnAir
  T3_Carpet  T3_Banner  T3_BannerPole

Origin (0,0,0) = door base centre at the wall plane. Building is behind (+Y),
street is in front (−Y) → −Z in Roblox. 1 unit = 1 stud, Z up.

Run in Blender (Scripting -> Open -> Reload if edited -> ▶ Run). Exports
blender/out/StudioEntrance.fbx. Import 3D -> Save assets/studio/StudioEntrance.rbxm.
"""

import bpy
import os
import math

parts = {}   # name -> list of objects to join


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for item in list(coll):
            coll.remove(item)


def box(name, dims, loc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = dims
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    parts.setdefault(name, []).append(o)
    return o


def cyl(name, r, h, loc, rot=(0, 0, 0), verts=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc)
    o = bpy.context.active_object
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    parts.setdefault(name, []).append(o)
    return o


def cone(name, r, h, loc, rot=(0, 0, 0), verts=3):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r, depth=h, location=loc)
    o = bpy.context.active_object
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    parts.setdefault(name, []).append(o)
    return o


def build():
    clear_scene()

    # --- T1: play-button plaque on the wall LEFT of the door ---
    box("T1_Plaque", (2.8, 0.3, 2.8), (-5.0, -0.75, 5.2))
    cone("T1_PlayTri", 0.85, 0.25, (-5.0, -0.95, 5.2), rot=(math.radians(90), 0, math.radians(-90)), verts=3)

    # --- T1: camera on a tripod, front-left, aimed at the door ---
    cyl("T1_Tripod", 0.16, 5.0, (-8.5, -8.5, 2.5))                       # centre pole
    for az in (0, 120, 240):
        a = math.radians(az)
        cyl("T1_Tripod", 0.12, 5.2, (-8.5 + math.cos(a) * 1.1, -8.5 + math.sin(a) * 1.1, 2.4),
            rot=(math.radians(12) * math.sin(a), math.radians(12) * math.cos(a), 0))
    box("T1_Camera", (1.6, 2.2, 1.4), (-8.5, -8.5, 5.4))                 # body
    cyl("T1_Camera", 0.45, 1.0, (-8.5, -7.2, 5.4), rot=(math.radians(90), 0, 0))  # lens toward door
    box("T1_Camera", (0.9, 0.9, 0.5), (-8.5, -8.5, 6.6))                 # top handle

    # --- T2: studio spotlight (softbox on a stand), front-right ---
    cyl("T2_SpotStand", 0.16, 6.0, (8.5, -8.5, 3.0))
    box("T2_SpotStand", (2.2, 2.2, 0.3), (8.5, -8.5, 0.2))              # base
    box("T2_SpotBox", (2.6, 0.5, 2.6), (8.5, -7.6, 6.2), rot=(math.radians(-20), 0, 0))  # softbox toward door

    # --- T2: ON AIR light above the door ---
    box("T2_OnAir", (4.0, 0.4, 1.2), (0, -0.8, 8.0))

    # --- T3: red carpet runner from door to street ---
    box("T3_Carpet", (5.0, 11.0, 0.2), (0, -6.5, 0.1))

    # --- T3: big channel banner over the entrance ---
    box("T3_Banner", (16.0, 0.4, 3.0), (0, -0.7, 10.2))
    for sx in (-8, 8):
        box("T3_BannerPole", (0.4, 0.4, 4.0), (sx, -0.7, 9.2))


def join_all():
    for name, objs in parts.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        obj = bpy.context.active_object
        obj.name = name
        m = obj.modifiers.new("Bevel", "BEVEL")
        m.width = 0.04
        m.segments = 1
        bpy.ops.object.modifier_apply(modifier="Bevel")
        bpy.ops.object.shade_flat()


def export():
    out = os.path.join(r"/Users/kirill/projects/roblox game", "blender", "out", "StudioEntrance.fbx")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True,
                             apply_unit_scale=True, global_scale=1.0,
                             object_types={"MESH"})
    print("Exported:", out)


build()
join_all()
export()
print("Done. Import blender/out/StudioEntrance.fbx -> Save assets/studio/StudioEntrance.rbxm")
