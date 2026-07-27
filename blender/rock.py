"""
M7 Map - a SET of jagged boulder variants (6 different shapes).

Each variant is a high-poly icosphere, squashed to a different shape, then
vertex-jittered into a craggy faceted rock. The game picks a random mix of these
at every rock spot, so no two piles look the same.

NOTE: the 6 variants are built ON TOP of each other at the origin, so in Blender
they'll look like one lumpy blob -- that's expected. You'll see the variety in
the game, where the code places them individually.

Run in Blender (Scripting -> Open -> Reload if edited -> ▶ Run). Exports
blender/out/Rock.fbx. Import 3D into Studio, overwrite assets/studio/Rock.rbxm.
(Game colours them grey.)  1 unit = 1 stud, Z up, each centred on the origin.
"""

import bpy
import bmesh
import os
import random


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.textures):
        for item in list(coll):
            coll.remove(item)


def boulder(name, radius, scale, jitter, seed, subdiv=3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=radius,
                                          location=(0.0, 0.0, 0.0))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # Jitter every vertex for a chunky faceted rock (push along normal + random).
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    rng = random.Random(seed)
    for v in bm.verts:
        v.co += v.normal * ((rng.random() * 2 - 1) * jitter)
        v.co.x += (rng.random() * 2 - 1) * jitter * 0.45
        v.co.y += (rng.random() * 2 - 1) * jitter * 0.45
        v.co.z += (rng.random() * 2 - 1) * jitter * 0.45
    bm.to_mesh(me)
    bm.free()
    bpy.ops.object.shade_flat()
    return obj


def build():
    clear_scene()
    # (name, radius, (sx,sy,sz), jitter, seed) -- varied silhouettes.
    specs = [
        ("Variant1", 2.0, (1.00, 1.00, 0.85), 0.50, 11),  # round
        ("Variant2", 1.9, (1.50, 1.10, 0.70), 0.55, 22),  # flat slab
        ("Variant3", 1.6, (0.85, 0.85, 1.30), 0.45, 33),  # tall
        ("Variant4", 2.2, (1.45, 0.80, 0.95), 0.60, 44),  # oblong
        ("Variant5", 1.5, (1.10, 1.10, 1.00), 0.42, 55),  # chunky small
        ("Variant6", 1.8, (0.90, 1.35, 0.80), 0.52, 66),  # wedge
    ]
    for spec in specs:
        boulder(spec[0], spec[1], spec[2], spec[3], spec[4])


def export():
    out = os.path.join(r"/Users/kirill/projects/roblox game", "blender", "out", "Rock.fbx")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True,
                             apply_unit_scale=True, global_scale=1.0,
                             object_types={"MESH"})
    print("Exported:", out)


build()
export()
print("Done. Import blender/out/Rock.fbx -> overwrite assets/studio/Rock.rbxm")
