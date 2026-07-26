"""
M7 Round 1 - Studio entrance canopy + "STUDIO" sign (v2, cleaner + named parts).

HOW TO RUN (in Blender):
  1. Scripting tab -> Open this file (blender/entrance_sign.py) -> press the
     ▶ Run Script button.
  2. It builds the model AND exports it to blender/out/EntranceSign.fbx.
  3. Import that .fbx into Studio, then Save to File into assets/studio/.
     (Colors are set later in game code, so you do NOT need to set materials
      by hand -- just import and save.)

Modelled at Roblox scale: 1 Blender unit = 1 stud, Z is up. Origin (0,0,0) is
the CENTRE of the doorway at floor level. Pieces are kept as SEPARATE named
objects (Canopy, PostL, PostR, Board, StudioText) so the game can colour each
one by name after import.
"""

import bpy
import os
import math

PROJECT_DIR = r"/Users/kirill/projects/roblox game"
OUT_DIR = os.path.join(PROJECT_DIR, "blender", "out")
OUT_FILE = os.path.join(OUT_DIR, "EntranceSign.fbx")

DOOR_WIDTH = 4.0
DOOR_HEIGHT = 6.0


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for item in list(block):
            block.remove(item)


def add_box(name, size, location):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0] / 2.0, size[1] / 2.0, size[2] / 2.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def add_text(name, body, location, height):
    curve = bpy.data.curves.new(type="FONT", name=name + "Font")
    curve.body = body
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = 0.06
    curve.size = height
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)  # stand upright, face -Y
    obj.location = location
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return obj


def build():
    clear_scene()

    # A compact entrance: two posts hold a canopy over the door; a sign board
    # sits just above the door with "STUDIO" text on its front (-Y) face.
    # -Y is "outward from the building" (maps to Roblox -Z, the front).

    # Canopy shelf projecting out over the door.
    add_box("Canopy", (9.0, 3.0, 0.5), (0.0, -1.3, DOOR_HEIGHT + 0.5))  # z 6.25..6.75

    # Two support posts at the outer front corners.
    for name, sx in (("PostL", -3.6), ("PostR", 3.6)):
        add_box(name, (0.5, 0.5, DOOR_HEIGHT + 0.6), (sx, -2.6, (DOOR_HEIGHT + 0.6) / 2.0))

    # Sign board mounted just above the door, flat against the wall.
    board_z = DOOR_HEIGHT + 1.4          # centre 7.4
    add_box("Board", (8.0, 0.4, 2.2), (0.0, -0.1, board_z))  # z 6.3..8.5

    # "STUDIO" text on the board's front face.
    add_text("StudioText", "STUDIO", (0.0, -0.35, board_z), 1.3)


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
print("Done. Import blender/out/EntranceSign.fbx, then Save to File into assets/studio/.")
