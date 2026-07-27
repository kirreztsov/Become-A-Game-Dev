"""
M7 Round 2 - One floor's exterior facade (structural frame + window grid).

HOW TO RUN: Scripting tab -> Open this file -> (Text menu -> Reload if you
edited it) -> press the ▶ Run Script button. Exports blender/out/FacadeModule.fbx.
Then Import 3D into Studio and Save to File as assets/studio/FacadeModule.rbxm.

This is ONE floor's opaque shell: solid back wall, 4 corner pillars, a top
cornice cap, a base band, and dark modern window frames (top/bottom rails +
vertical mullions) on the left / right / front. The see-through GLASS stays as
game Parts behind these frames, and the DOOR is left as a centre gap on the
front. Modelled at 1 unit = 1 stud, Z up, origin = floor base centre.
Front = -Y (Roblox -Z). Pieces are named so the game colours them by name.
"""

import bpy
import os

PROJECT_DIR = r"/Users/kirill/projects/roblox game"
OUT_DIR = os.path.join(PROJECT_DIR, "blender", "out")
OUT_FILE = os.path.join(OUT_DIR, "FacadeModule.fbx")

HW = 18.0   # BUILDING_HALF_W
HD = 16.0   # BUILDING_HALF_D
H = 12.0    # WALL_HEIGHT
DOOR_HALF = 2.0  # DOOR_WIDTH / 2


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


def build():
    clear_scene()

    # Solid back wall.
    add_box("WallBack", (HW * 2, 0.6, H), (0.0, HD, H / 2))

    # Chunky corner pillars.
    for name, sx, sy in (("ColFL", -HW, -HD), ("ColFR", HW, -HD),
                         ("ColBL", -HW, HD), ("ColBR", HW, HD)):
        add_box(name, (1.8, 1.8, H), (sx, sy, H / 2))

    # Top cornice cap (projecting ring).
    add_box("CorniceF", (HW * 2 + 2, 1.0, 0.8), (0.0, -HD, H - 0.4))
    add_box("CorniceB", (HW * 2 + 2, 1.0, 0.8), (0.0, HD, H - 0.4))
    add_box("CorniceL", (1.0, HD * 2 + 2, 0.8), (-HW, 0.0, H - 0.4))
    add_box("CorniceR", (1.0, HD * 2 + 2, 0.8), (HW, 0.0, H - 0.4))

    # Base band ring.
    add_box("BaseF", (HW * 2, 1.0, 1.0), (0.0, -HD, 0.5))
    add_box("BaseB", (HW * 2, 1.0, 1.0), (0.0, HD, 0.5))
    add_box("BaseL", (1.0, HD * 2, 1.0), (-HW, 0.0, 0.5))
    add_box("BaseR", (1.0, HD * 2, 1.0), (HW, 0.0, 0.5))

    # Left / right window frames: top + bottom rails + vertical mullions.
    for side, sx in (("L", -HW), ("R", HW)):
        add_box("FrameTop" + side, (0.4, HD * 2, 0.4), (sx, 0.0, H - 1.2))
        add_box("FrameBot" + side, (0.4, HD * 2, 0.4), (sx, 0.0, 1.2))
        for i, y in enumerate((-HD * 0.66, -HD * 0.22, HD * 0.22, HD * 0.66)):
            add_box("FrameV%s%d" % (side, i), (0.4, 0.4, H - 2.4), (sx, y, H / 2))

    # Front window frame with a centre door gap.
    add_box("FrameTopF", (HW * 2, 0.4, 0.4), (0.0, -HD, H - 1.2))
    seg_w = HW - DOOR_HALF                     # from wall edge to door edge
    seg_cx = (HW + DOOR_HALF) / 2.0
    add_box("FrameBotFL", (seg_w, 0.4, 0.4), (-seg_cx, -HD, 1.2))
    add_box("FrameBotFR", (seg_w, 0.4, 0.4), (seg_cx, -HD, 1.2))
    for i, x in enumerate((-13.0, -7.0, 7.0, 13.0)):
        add_box("FrameVF%d" % i, (0.4, 0.4, H - 2.4), (x, -HD, H / 2))


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
print("Done. Import blender/out/FacadeModule.fbx, then Save to File into assets/studio/.")
