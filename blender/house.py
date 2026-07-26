"""
M7 Map - a detailed suburban house (walls, hip roof, door, windows, chimney,
porch). Parts are kept SEPARATE (not joined) and named, so the game colours each
piece (walls cream, roof red, door brown, windows glass-blue, chimney brick).

Run in Blender (Scripting -> Open -> Reload if edited -> ▶ Run). Exports
blender/out/House.fbx. Import 3D into Studio, overwrite assets/studio/House.rbxm.
1 unit = 1 stud, Z up, origin (0,0,0) = base centre on the ground; front faces -Y.
Reference ~12 wide; the game scales it to ~12 studs and faces it at the street.
"""

import bpy
import math
import os


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for item in list(coll):
            coll.remove(item)


def box(name, dims, loc):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return o


def hip_roof(name, W, D, height, base_z):
    # 4-sided pyramid = hip roof; rotate 45 deg so faces align to the walls.
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=(max(W, D) / 2) * 1.18,
                                    radius2=0.0, depth=height,
                                    location=(0, 0, base_z + height / 2))
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (0, 0, math.radians(45))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    bpy.ops.object.shade_flat()
    return o


def build():
    clear_scene()
    W, D, wall_h = 12.0, 9.0, 6.5

    # Walls (base sits on the ground: z from 0..wall_h).
    box("Body", (W, D, wall_h), (0, 0, wall_h / 2))
    # Foundation lip.
    box("Foundation", (W + 0.6, D + 0.6, 0.8), (0, 0, 0.4))
    # Hip roof with overhang.
    hip_roof("Roof", W, D, 4.2, wall_h)

    # Front door (front = -Y).
    box("Door", (2.0, 0.3, 3.6), (0, -D / 2 - 0.05, 1.8))
    box("DoorFrame", (2.6, 0.4, 4.2), (0, -D / 2 - 0.02, 2.1))

    # Front windows.
    for i, x in enumerate((-3.6, 3.6)):
        box("Window%d" % i, (2.2, 0.3, 2.2), (x, -D / 2 - 0.05, 3.4))
        box("WinFrame%d" % i, (2.7, 0.35, 2.7), (x, -D / 2 - 0.02, 3.4))
    # Side windows.
    for i, y in enumerate((-2.2, 2.2)):
        box("WindowS%d" % i, (0.3, 1.8, 2.0), (W / 2 + 0.05, y, 3.4))

    # Little porch roof over the door (two posts + a slab).
    box("PorchSlab", (4.2, 2.2, 0.4), (0, -D / 2 - 1.0, 4.0))
    for x in (-1.7, 1.7):
        box("PorchPost", (0.4, 0.4, 4.0), (x, -D / 2 - 1.9, 2.0))

    # Chimney.
    box("Chimney", (1.4, 1.4, 3.2), (W / 2 - 2.2, 1.6, wall_h + 2.2))


def export():
    out = os.path.join(r"/Users/kirill/projects/roblox game", "blender", "out", "House.fbx")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True,
                             apply_unit_scale=True, global_scale=1.0,
                             object_types={"MESH"})
    print("Exported:", out)


build()
export()
print("Done. Import blender/out/House.fbx -> overwrite assets/studio/House.rbxm")
