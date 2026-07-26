"""
M7 Map batch - a detailed low-poly stylised tree.

Root flare + tapered trunk + connected branches (each with a leafy tip) +
a full layered canopy.

HOW TO RUN: Scripting tab -> Open this file -> (Text menu -> Reload if you
edited it) -> ▶ Run Script. Exports blender/out/Tree.fbx.
Then Import 3D into Studio and Save to File as assets/studio/Tree.rbxm.
(Skip materials -- the game colours Trunk/Branch brown + Foliage green.)

1 unit = 1 stud, Z up, origin (0,0,0) = base of the trunk on the ground.
Pieces named Trunk* / Branch* (brown) and Foliage* (green).
"""

import bpy
import os
import math
from mathutils import Vector

PROJECT_DIR = r"/Users/kirill/projects/roblox game"
OUT_DIR = os.path.join(PROJECT_DIR, "blender", "out")
OUT_FILE = os.path.join(OUT_DIR, "Tree.fbx")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for item in list(block):
            block.remove(item)


def add_cone(name, r1, r2, height, location):
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=r1, radius2=r2,
                                     depth=height, location=location)
    bpy.context.active_object.name = name


def add_foliage(name, radius, location):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius,
                                           location=location)
    bpy.context.active_object.name = name


def add_branch(name, radius, length, attach, tilt_deg, az_deg):
    """Branch cylinder whose BASE sits at `attach` on the trunk, angling out and
    up. Returns the tip point (for a leaf cluster)."""
    tilt = math.radians(tilt_deg)
    az = math.radians(az_deg)
    d = Vector((math.sin(tilt) * math.cos(az),
                math.sin(tilt) * math.sin(az),
                math.cos(tilt)))
    a = Vector(attach)
    center = a + d * (length / 2.0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=radius, depth=length,
                                         location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_euler = Vector((0, 0, 1)).rotation_difference(d).to_euler()
    return a + d * length


def build():
    clear_scene()

    # Root flare + tapered trunk (base on the ground).
    add_cone("TrunkRoot", 1.3, 0.85, 1.2, (0.0, 0.0, 0.6))
    add_cone("Trunk", 0.82, 0.42, 6.0, (0.0, 0.0, 3.2))

    # Connected branches, each capped with a small leaf cluster.
    tips = []
    tips.append(add_branch("Branch1", 0.22, 3.0, (0.0, 0.0, 4.2), 55, 25))
    tips.append(add_branch("Branch2", 0.22, 3.0, (0.0, 0.0, 4.7), 58, 150))
    tips.append(add_branch("Branch3", 0.20, 2.6, (0.0, 0.0, 3.9), 52, 265))
    for i, tip in enumerate(tips):
        add_foliage("FoliageB%d" % i, 1.35, (tip.x, tip.y, tip.z))

    # Full layered main canopy.
    add_foliage("Foliage1", 2.7, (0.0, 0.0, 7.2))
    add_foliage("Foliage2", 2.1, (1.9, 0.6, 7.6))
    add_foliage("Foliage3", 2.1, (-1.8, -0.7, 7.4))
    add_foliage("Foliage4", 1.8, (0.7, 1.9, 6.9))
    add_foliage("Foliage5", 1.8, (-0.7, -1.9, 7.0))
    add_foliage("Foliage6", 1.7, (0.2, 0.2, 9.1))
    add_foliage("Foliage7", 1.6, (1.6, -1.6, 6.6))
    add_foliage("Foliage8", 1.6, (-1.7, 1.3, 6.7))


def export():
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(
        filepath=OUT_FILE,
        use_selection=True,
        apply_unit_scale=True,
        global_scale=1.0,
        object_types={"MESH"},
    )
    print("Exported:", OUT_FILE)


build()
export()
print("Done. Import blender/out/Tree.fbx, then Save to File into assets/studio/.")
