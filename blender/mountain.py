"""
M7 Map - a jagged FACETED mountain (direct vertex-jitter, flat-shaded).

Reliable jaggedness: build a broad cone, subdivide it, then shove every vertex
by a random amount (bigger near the base, tapering to the peak) so the surface
becomes craggy rock with an irregular silhouette. Flat shading keeps sharp
facets. A wide snow cone caps the summit.

Run in Blender (Scripting -> Open -> Reload if edited -> ▶ Run). Exports
blender/out/Mountain.fbx. Import 3D into Studio, overwrite assets/studio/Mountain.rbxm.
(Game colours Peak/SubPeak green, Snow white.)

1 unit = 1 stud, Z up, origin (0,0,0) = base centre on the ground.
"""

import bpy
import bmesh
import os
import math
import random


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.textures):
        for item in list(coll):
            coll.remove(item)


def craggy(name, base_r, height, location, cuts, jitter, seed):
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=base_r, radius2=0.0,
                                    depth=height, location=location)
    obj = bpy.context.active_object
    obj.name = name

    # Subdivide (flat facets, no smoothing).
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.subdivide(number_cuts=cuts)
    bpy.ops.object.mode_set(mode="OBJECT")

    # Jitter every vertex: radial push (in/out) + vertical wobble, stronger near
    # the base, tapering off toward the peak so the summit stays a point.
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    rng = random.Random(seed)
    zs = [v.co.z for v in bm.verts]
    zmin, zmax = min(zs), max(zs)
    span = max(zmax - zmin, 0.001)
    for v in bm.verts:
        hf = (v.co.z - zmin) / span            # 0 base .. 1 tip
        amp = jitter * (1.0 - hf * 0.75)
        r = math.hypot(v.co.x, v.co.y)
        nx, ny = (v.co.x / r, v.co.y / r) if r > 1e-4 else (0.0, 0.0)
        v.co.x += nx * (rng.random() * 2 - 1) * amp
        v.co.y += ny * (rng.random() * 2 - 1) * amp
        v.co.z += (rng.random() * 2 - 1) * amp * 0.5
    bm.to_mesh(me)
    bm.free()
    bpy.ops.object.shade_flat()
    return obj


def snow(name, base_r, height, center):
    # Wide, short cone that wraps the summit as a cap (sits above the peak tip).
    bpy.ops.mesh.primitive_cone_add(vertices=22, radius1=base_r, radius2=0.0,
                                    depth=height, location=center)
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.shade_flat()
    return obj


def build():
    clear_scene()

    # Broad and not too tall = mountain, not a spike.
    base_w, H = 56.0, 42.0

    craggy("Peak", base_w / 2, H, (0.0, 0.0, H / 2), cuts=7, jitter=base_w * 0.08, seed=3)
    snow("Snow", base_w * 0.17, H * 0.28, (0.0, 0.0, 0.87 * H))

    # Lower shoulder peak for a ridge line.
    sh, sr = H * 0.62, base_w * 0.34
    craggy("SubPeak", sr, sh, (base_w * 0.30, base_w * 0.13, sh / 2),
           cuts=6, jitter=sr * 0.11, seed=8)
    snow("SnowSub", sr * 0.3, sh * 0.26, (base_w * 0.30, base_w * 0.13, 0.85 * sh))


def export():
    out = os.path.join(r"/Users/kirill/projects/roblox game", "blender", "out", "Mountain.fbx")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True,
                             apply_unit_scale=True, global_scale=1.0,
                             object_types={"MESH"})
    print("Exported:", out)


build()
export()
print("Done. Import blender/out/Mountain.fbx -> overwrite assets/studio/Mountain.rbxm")
