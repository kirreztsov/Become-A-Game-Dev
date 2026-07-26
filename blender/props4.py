"""
M7 props batch 4: real flower beds (no more bulbs-on-sticks!) + a playground
slide and swing set.

Props (part names drive in-game colouring):
  FlowerBed -> BedWood (planter), BedSoil, Stem, Center, PetalA (red),
               PetalB (yellow), PetalC (purple), PetalW (white) -- a mix of
               daisies, tulips and puff flowers in a wooden planter.
  Slide     -> SlideFrame (metal), SlideChute (bright), SlideStep
  SwingSet  -> SwingFrame (metal A-frame + bar), SwingSeat

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


def cyl(r, depth, loc, bucket, rot=(0, 0, 0), verts=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    return _finish(bpy.context.active_object, rot, bucket)


def ball(r, loc, bucket):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=loc)
    return _finish(bpy.context.active_object, (0, 0, 0), bucket)


def join_bevel(parts, name, bevel=0.02):
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


# ---------------------------------------------------------------- FlowerBed
def build_flowerbed():
    clear_scene()
    wood, soil, stem, center, pa, pb, pc, pw = [], [], [], [], [], [], [], []
    box((5.0, 3.0, 1.2), (0, 0, 0.6), wood)                 # planter box
    box((4.6, 2.6, 0.3), (0, 0, 1.15), soil)                # soil top
    top = 1.2

    def daisy(x, y):
        cyl(0.09, 1.3, (x, y, top + 0.65), stem)
        ball(0.22, (x, y, top + 1.35), center)              # yellow center
        for k in range(8):
            a = math.radians(k * 45)
            box((0.5, 0.22, 0.1), (x + math.cos(a) * 0.42, y + math.sin(a) * 0.42, top + 1.35), pw, rot=(0, 0, k * 45))

    def tulip(x, y, bucket):
        cyl(0.09, 1.2, (x, y, top + 0.6), stem)
        for k in range(5):                                   # cupped petals
            a = math.radians(k * 72)
            box((0.28, 0.5, 0.14), (x + math.cos(a) * 0.22, y + math.sin(a) * 0.22, top + 1.35), bucket, rot=(24, 0, k * 72))

    def puff(x, y, bucket):
        cyl(0.09, 1.15, (x, y, top + 0.58), stem)
        ball(0.34, (x, y, top + 1.25), bucket)
        for dx, dy, dz in ((0.28, 0, 0.05), (-0.28, 0, 0.05), (0, 0.28, 0.05), (0, -0.28, 0.05), (0, 0, 0.32)):
            ball(0.2, (x + dx, y + dy, top + 1.25 + dz), bucket)

    daisy(-1.5, 0.6)
    tulip(-0.5, -0.5, pa)
    puff(0.5, 0.6, pb)
    tulip(1.5, -0.5, pc)
    daisy(0.9, -0.7)
    puff(-1.0, 0.7, pc)
    join_bevel(wood, "BedWood")
    join_bevel(soil, "BedSoil")
    join_bevel(stem, "Stem", bevel=0.0)
    join_bevel(center, "Center")
    join_bevel(pa, "PetalA", bevel=0.0)
    join_bevel(pb, "PetalB", bevel=0.0)
    join_bevel(pc, "PetalC", bevel=0.0)
    join_bevel(pw, "PetalW", bevel=0.0)
    export("FlowerBed.fbx")


# ---------------------------------------------------------------- Slide
def build_slide():
    clear_scene()
    frame, chute, step = [], [], []
    # Top platform + 4 legs.
    box((2.6, 2.6, 0.3), (0, 0, 3.0), frame)
    for ox in (-1.1, 1.1):
        for oy in (-1.1, 1.1):
            box((0.25, 0.25, 3.0), (ox, oy, 1.5), frame)
    # Guard rails around the platform top.
    for oy in (-1.2, 1.2):
        box((2.6, 0.14, 1.0), (0, oy, 3.6), frame)
    # Steps up the -X side.
    for i in range(4):
        box((1.0, 2.2, 0.18), (-1.3 - i * 0.0, -0.0 + 0, 0.6 + i * 0.7), step, rot=(0, 0, 0))
    for i in range(4):
        pass
    # Slide chute down the +X side (a sloped ramp + two side walls).
    box((4.6, 1.6, 0.2), (2.6, 0, 1.7), chute, rot=(0, -34, 0))
    for oy in (-0.85, 0.85):
        box((4.6, 0.15, 0.6), (2.6, oy, 1.9), chute, rot=(0, -34, 0))
    join_bevel(frame, "SlideFrame")
    join_bevel(chute, "SlideChute")
    join_bevel(step, "SlideStep")
    export("Slide.fbx")


# ---------------------------------------------------------------- SwingSet
def build_swing():
    clear_scene()
    frame, seat = [], []
    topZ = 4.0
    # Two A-frames (each two splayed legs) + top bar.
    for ex in (-3.0, 3.0):
        box((0.25, 0.25, 4.4), (ex, -1.4, topZ / 2), frame, rot=(28, 0, 0))
        box((0.25, 0.25, 4.4), (ex, 1.4, topZ / 2), frame, rot=(-28, 0, 0))
    box((6.6, 0.3, 0.3), (0, 0, topZ), frame)               # top bar
    # Two swings: chains + a seat.
    for sx in (-1.5, 1.5):
        for oy in (-0.5, 0.5):
            box((0.08, 0.08, 2.6), (sx, oy, topZ - 1.3), frame)
        box((1.1, 1.1, 0.16), (sx, 0, topZ - 2.6), seat)
    join_bevel(frame, "SwingFrame")
    join_bevel(seat, "SwingSeat")
    export("SwingSet.fbx")


build_flowerbed()
build_slide()
build_swing()
print("Done. Import each blender/out/*.fbx -> Save assets/studio/<Name>.rbxm "
      "(FlowerBed, Slide, SwingSet).")
