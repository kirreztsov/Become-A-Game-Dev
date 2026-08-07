"""
Detailed PC component display models for the physical PC Store shelves
(replaces the coloured placeholder boxes): a graphics card, a gaming monitor,
and an RGB tower case. Built from plain boxes + cylinders + a bevel -- the SAME
pattern as controller.py / props1-4 that imported cleanly. No lathe, no
subdivision-surface, no 3D text (those broke earlier imports).

Part names drive in-game colour (set by Lobby.buildPCStoreShelves after clone):
  PCGpu     -> Shroud / Backplate / Fan1..3 / Bracket / Accent
  PCMonitor -> Bezel / Screen / Neck / Base / Accent
  PCTower   -> Case / Front / Glass / Fan1..3 / Feet / Accent

Built Z-up, 1 unit = 1 stud, "front" toward -Y (fans / screen / glass face -Y;
Lobby spins each model so the front faces the aisle). Each model's base sits at
z = 0 so placeProp seats it on the shelf pedestal.

Run in Blender: Scripting -> Open this file -> (Text menu -> Reload if it was
already open) -> Run. It writes THREE files:
  blender/out/PCGpu.fbx, PCMonitor.fbx, PCTower.fbx
Then in Studio, for EACH: Home -> Import 3D -> pick the fbx -> Import ->
right-click the Model -> Save to File -> save to Downloads as
PCGpu.rbxm / PCMonitor.rbxm / PCTower.rbxm, then delete the import from Workspace.
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


def cyl(r, depth, loc, bucket, rot=(0, 0, 0), verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    return _finish(bpy.context.active_object, rot, bucket)


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
        m.segments = 2
        bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_flat()


def export(filename):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, filename), use_selection=True,
                             apply_unit_scale=True, global_scale=1.0, object_types={"MESH"})
    print("Exported:", filename)


# --------------------------------------------------------------------------
# GPU -- a triple-fan graphics card stood UPRIGHT on its short end (the classic
# store-display pose): long axis vertical (Z), the big fan face toward -Y. Keeps
# a small footprint on the pedestal. ~4.2 studs tall as built.
# --------------------------------------------------------------------------
def build_gpu():
    clear_scene()
    shroud, back, bracket, accent = [], [], [], []
    f1, f2, f3 = [], [], []

    # Plastic shroud (the body you see) + PCB backplate behind it.
    box((1.7, 1.1, 4.2), (0, 0.0, 2.15), shroud)
    box((1.7, 0.16, 4.2), (0, 0.63, 2.15), back)
    # Metal I/O bracket across the bottom.
    box((1.75, 1.05, 0.18), (0, 0.02, 0.09), bracket)

    # Three fans stacked up the -Y (front) face -- axis along Y.
    for fz, bucket in ((1.05, f1), (2.15, f2), (3.25, f3)):
        cyl(0.62, 0.24, (0, -0.50, fz), bucket, rot=(90, 0, 0))   # fan ring
        cyl(0.16, 0.30, (0, -0.54, fz), bucket, rot=(90, 0, 0))   # hub cap

    # RGB accent strip down the front-left edge.
    box((0.14, 0.12, 3.6), (-0.78, -0.46, 2.15), accent)

    join_bevel(shroud, "Shroud", bevel=0.06)
    join_bevel(back, "Backplate", bevel=0.02)
    join_bevel(bracket, "Bracket", bevel=0.02)
    join_bevel(f1, "Fan1", bevel=0.03)
    join_bevel(f2, "Fan2", bevel=0.03)
    join_bevel(f3, "Fan3", bevel=0.03)
    join_bevel(accent, "Accent", bevel=0.02)
    export("PCGpu.fbx")


# --------------------------------------------------------------------------
# MONITOR -- a widescreen gaming monitor on a stand, screen toward -Y.
# ~5 studs wide, ~4.6 tall including base.
# --------------------------------------------------------------------------
def build_monitor():
    clear_scene()
    bezel, screen, neck, base, accent = [], [], [], [], []

    SCREEN_Z = 3.05  # centre height of the panel
    box((5.0, 0.24, 3.0), (0, 0.02, SCREEN_Z), bezel)      # outer frame
    box((4.6, 0.10, 2.6), (0, -0.13, SCREEN_Z), screen)    # display panel (front)
    box((0.55, 0.55, 1.15), (0, 0.18, 1.05), neck)         # stand neck
    box((2.5, 1.4, 0.18), (0, 0.18, 0.09), base)           # stand foot on ground
    box((4.4, 0.10, 0.12), (0, -0.19, 1.62), accent)       # RGB strip along the chin

    join_bevel(bezel, "Bezel", bevel=0.05)
    join_bevel(screen, "Screen", bevel=0.02)
    join_bevel(neck, "Neck", bevel=0.04)
    join_bevel(base, "Base", bevel=0.05)
    join_bevel(accent, "Accent", bevel=0.02)
    export("PCMonitor.fbx")


# --------------------------------------------------------------------------
# TOWER -- an RGB PC case: glass side panel on -X, front toward -Y, three RGB
# fans stacked at the front intake (visible through the glass). ~4.5 studs tall.
# --------------------------------------------------------------------------
def build_tower():
    clear_scene()
    case, front, glass, feet, accent = [], [], [], [], []
    f1, f2, f3 = [], [], []

    box((2.2, 4.6, 4.4), (0, 0.0, 2.35), case)          # main body
    box((2.2, 0.16, 4.4), (0, -2.30, 2.35), front)      # front panel (-Y)
    box((0.10, 4.2, 4.0), (-1.12, 0.0, 2.35), glass)    # tempered-glass side (-X)

    # Three RGB intake fans stacked up the front, axis along X (face the glass).
    for fz, bucket in ((1.15, f1), (2.35, f2), (3.55, f3)):
        cyl(0.55, 0.18, (-0.55, -1.65, fz), bucket, rot=(0, 90, 0))
        cyl(0.14, 0.24, (-0.60, -1.65, fz), bucket, rot=(0, 90, 0))

    # RGB light bar down the front edge + two feet.
    box((0.12, 0.14, 3.9), (-1.06, -2.28, 2.35), accent)
    box((0.6, 1.2, 0.18), (-0.7, 0, 0.09), feet)
    box((0.6, 1.2, 0.18), (0.7, 0, 0.09), feet)

    join_bevel(case, "Case", bevel=0.07)
    join_bevel(front, "Front", bevel=0.03)
    join_bevel(glass, "Glass", bevel=0.02)
    join_bevel(feet, "Feet", bevel=0.02)
    join_bevel(accent, "Accent", bevel=0.02)
    join_bevel(f1, "Fan1", bevel=0.03)
    join_bevel(f2, "Fan2", bevel=0.03)
    join_bevel(f3, "Fan3", bevel=0.03)
    export("PCTower.fbx")


build_gpu()
build_monitor()
build_tower()
print("Done. Import PCGpu.fbx / PCMonitor.fbx / PCTower.fbx and save the 3 rbxm files.")
