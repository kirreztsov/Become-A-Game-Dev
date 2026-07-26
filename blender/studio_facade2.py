"""
M7 - Tier 2 (2nd upgrade) studio front facade: a RoTube "shop" look.

DISTINCT from tier 1's facade (not just recoloured): big ground-floor storefront
windows (3 per side), a horizontal awning band, and a row of smaller upper
windows. Same footprint + centre door gap so it drops into the same slot.

Parts named Body / Accent / Trim / Win (the game colours them white / blue /
white / warm per the tier-2 style). Frame behind glass, mullions in front -> no
z-fighting.

Run in Blender (Scripting -> Open -> Reload if edited -> ▶ Run). Exports
blender/out/StudioFacade2.fbx. Import 3D -> Save to File assets/studio/StudioFacade2.rbxm.
1 unit = 1 stud, Z up. Origin (0,0,0) = door base centre at the wall plane, front -Y.
Door gap: X -2..2, Z 0..6.
"""

import bpy
import os

TH = 1.0


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for item in list(coll):
            coll.remove(item)


def box(dims, loc):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return o


def join(parts, name):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    bpy.ops.object.shade_flat()
    return o


def build():
    clear_scene()
    body, accent, trim, win = [], [], [], []

    # White wall panels (left + right of the door) + lintel.
    body.append(box((16, TH, 12), (-10, 0, 6)))
    body.append(box((16, TH, 12), (10, 0, 6)))
    body.append(box((4, TH, 6), (0, 0, 9)))

    # Corner pillars + top parapet + foundation strip (Trim/white).
    for sx in (-18, 18):
        trim.append(box((1.0, TH + 0.5, 12), (sx, 0, 6)))
    trim.append(box((37, TH + 0.6, 1.2), (0, 0, 11.4)))
    trim.append(box((37, TH + 0.6, 1.0), (0, 0, 0.5)))

    # Blue awning band across the whole front (Accent) + door-flank pilasters.
    accent.append(box((37, TH + 0.7, 1.3), (0, -0.2, 7.6)))
    for sx in (-2.6, 2.6):
        accent.append(box((0.8, TH + 0.4, 6.5), (sx, 0, 3.25)))

    # Windows: frame plate behind, glass, white cross-mullions in front.
    def window(cx, cz, w, h):
        trim.append(box((w + 0.9, 0.24, h + 0.9), (cx, -0.72, cz)))
        win.append(box((w, 0.14, h), (cx, -0.95, cz)))
        trim.append(box((0.22, 0.10, h), (cx, -1.12, cz)))
        trim.append(box((w, 0.10, 0.22), (cx, -1.12, cz)))

    # Big ground storefront windows: 3 per side.
    for cx in (-15, -10, -5, 5, 10, 15):
        window(cx, 3.9, 3.6, 5.2)   # tall storefront
    # Smaller upper windows above the awning: 3 per side.
    for cx in (-15, -10, -5, 5, 10, 15):
        window(cx, 9.6, 3.4, 2.6)


def export():
    out = os.path.join(r"/Users/kirill/projects/roblox game", "blender", "out", "StudioFacade2.fbx")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True,
                             apply_unit_scale=True, global_scale=1.0,
                             object_types={"MESH"})
    print("Exported:", out)


build()
export()
print("Done. Import blender/out/StudioFacade2.fbx -> Save assets/studio/StudioFacade2.rbxm")
