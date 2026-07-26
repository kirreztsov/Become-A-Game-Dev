"""
M7 mountains: ragged peaks, a big landmark massif (RoTube Peaks) and a stone
tunnel-mouth portal.

Models (part names drive in-game colouring):
  Mountain    -> Base (grass), Rock (grey crags), Snow (caps). A craggy,
                 asymmetric multi-peak mesh; variety comes from in-game
                 yaw/scale/colour jitter. Replaces the old Mountain.
  RoTubePeak  -> Base, Rock, Snow. A tall multi-summit massif with a FLAT top
                 shelf for a viewpoint platform (built in Lua).
  TunnelMouth -> Stone (portal arch + pillars), Dark (recessed tunnel interior).
                 Front faces -Y (toward town).

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


def cone(r1, r2, depth, loc, bucket, rot=(0, 0, 0), verts=6):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc)
    return _finish(bpy.context.active_object, rot, bucket)


def join_flat(parts, name):
    if not parts:
        return
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    bpy.context.active_object.name = name
    bpy.ops.object.shade_flat()


def export(filename):
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, filename)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True,
                             apply_unit_scale=True, global_scale=1.0,
                             object_types={"MESH"})
    print("Exported:", out)


def _peak(x, y, r, h, v, yaw, grass, rock, snow, snowcap=True):
    # rocky craggy cone
    cone(r, r * 0.06, h, (x, y, h / 2), rock, verts=v, rot=(0, 0, yaw))
    # grassy skirt over the lower third
    cone(r * 1.4, r * 0.55, h * 0.4, (x, y, h * 0.2), grass, verts=v, rot=(0, 0, yaw + 20))
    if snowcap:
        cone(r * 0.34, 0.05, h * 0.22, (x, y, h * 0.88), snow, verts=v, rot=(0, 0, yaw + 40))


def _spurs(rock, cx, cy, count, yaw0):
    # angular rock spurs jutting from the slope, for raggedness
    for i in range(count):
        a = math.radians(yaw0 + i * (360 / count))
        r = 5.5
        box((1.6, 1.6, 4.5), (cx + math.cos(a) * r, cy + math.sin(a) * r, 3.5),
            rock, rot=(18, 0, math.degrees(a)))


# ---------------------------------------------------------------- Mountain
def build_mountain():
    # SQUARED / blocky mesa (flat-topped, terraced, angular cliff faces) rather
    # than a pointy peak -- these tile into a continuous mountain WALL around the
    # whole map. Slight per-block yaw keeps faces from lining up on a grid;
    # in-game yaw/scale/colour jitter makes each instance different.
    clear_scene()
    grass, rock, snow = [], [], []
    # grassy foot (two wide, low, offset slabs)
    box((30, 27, 6), (0, 0, 3), grass, rot=(0, 0, 10))
    box((23, 21, 5), (4, -3, 5.5), grass, rot=(0, 0, -16))
    # squared rock mesa, three stacked terraces
    box((25, 23, 18), (0, 0, 13), rock, rot=(0, 0, 7))
    box((19, 18, 12), (3, 2, 25), rock, rot=(0, 0, -9))
    box((13, 12, 9), (-2, -2, 33), rock, rot=(0, 0, 18))
    # blocky buttresses / ledges for chunky faces
    box((10, 6, 22), (12, 3, 12), rock, rot=(0, 0, 3))
    box((6, 25, 11), (-4, -10, 9), rock, rot=(0, 0, -4))
    box((22, 7, 6), (2, 11, 14), rock, rot=(0, 0, 2))
    # flat snowy caps on the terrace tops
    box((13.5, 12.5, 2.4), (-2, -2, 38), snow, rot=(0, 0, 18))
    box((8, 7, 1.8), (6, 4, 28), snow, rot=(0, 0, -9))
    join_flat(grass, "Base")
    join_flat(rock, "Rock")
    join_flat(snow, "Snow")
    export("Mountain.fbx")


# ---------------------------------------------------------------- RoTubePeak
def build_rotube():
    clear_scene()
    grass, rock, snow = [], [], []
    # Main summit: tall, truncated flat on top (r2 large) for the viewpoint.
    cone(11, 3.6, 34, (0, 0, 17), rock, verts=7, rot=(0, 0, 0))
    cone(15, 6, 13, (0, 0, 6.5), grass, verts=7, rot=(0, 0, 22))   # grass base
    # A ring of snow just below the flat summit.
    cone(4.4, 3.6, 3.2, (0, 0, 31.5), snow, verts=7, rot=(0, 0, 10))
    # Sub-peaks around the massif.
    _peak(11, 5, 5.5, 19, 6, 40, grass, rock, snow)
    _peak(-11, -3, 5.0, 17, 6, 80, grass, rock, snow)
    _peak(-4, 12, 4.4, 15, 5, 120, grass, rock, snow)
    _peak(7, -11, 4.2, 14, 5, 160, grass, rock, snow)
    # wide foothills
    for (x, y, r, h) in ((0, 0, 20, 7), (13, -9, 10, 5), (-14, 8, 10, 5), (9, 13, 9, 5), (-10, -12, 9, 5)):
        cone(r, r * 0.45, h, (x, y, h / 2), grass, verts=7, rot=(0, 0, (x * 17) % 90))
    _spurs(rock, 0, 0, 7, 25)
    join_flat(grass, "Base")
    join_flat(rock, "Rock")
    join_flat(snow, "Snow")
    export("RoTubePeak.fbx")


# ---------------------------------------------------------------- TunnelMouth
def build_tunnel():
    clear_scene()
    stone, dark = [], []
    # Portal front plane at Y=0; opening ~15 wide x ~12 tall; depth into +Y.
    box((3.5, 5.0, 14), (-9.0, 0, 7), stone)       # left pillar
    box((3.5, 5.0, 14), (9.0, 0, 7), stone)        # right pillar
    box((24, 5.0, 4.5), (0, 0, 15.5), stone)       # top lintel band
    box((3.5, 5.2, 3.2), (0, -0.1, 17.2), stone)   # keystone
    # Chunky stone voussoirs stepping over the opening (arch look).
    for sx, sz, ang in ((-5.5, 12.8, -22), (5.5, 12.8, 22), (-2.8, 14.2, -10), (2.8, 14.2, 10)):
        box((3.8, 5.0, 3.2), (sx, 0, sz), stone, rot=(0, ang, 0))
    # Rocky wings that blend into the mountain.
    box((7, 6, 12), (-12.5, 0.5, 6), stone, rot=(0, 0, 0))
    box((7, 6, 12), (12.5, 0.5, 6), stone)
    # Dark recessed interior seen through the opening (the "tunnel").
    box((15, 11, 12.5), (0, 7.5, 6), dark)
    join_flat(stone, "Stone")
    join_flat(dark, "Dark")
    export("TunnelMouth.fbx")


build_mountain()
build_rotube()
build_tunnel()
print("Done. Import each blender/out/*.fbx -> Save assets/studio/<Name>.rbxm "
      "(Mountain, RoTubePeak, TunnelMouth).")
