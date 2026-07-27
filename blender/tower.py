"""
M7 Map - RoTube-Life-2-style skyline towers (4 variants).

Matches the reference: a solid coloured body, rows of warm-lit windows with
frames, horizontal floor bands, corner pillars, and a darker rooftop cap with
antennas. Each variant is built as THREE meshes so the game colours them:
  V<n>_Body  (walls)         V<n>_Trim  (pillars/bands/frames/cap/antennas)
  V<n>_Win   (lit windows)

Variants are stacked at the origin (one blob in Blender) -- expected; the game
places them singly and stretches each to its skyline slot.

Run in Blender (Scripting -> Open -> Reload if edited -> ▶ Run). Exports
blender/out/Tower.fbx. Import 3D into Studio, overwrite assets/studio/Tower.rbxm.
1 unit = 1 stud, Z up, each centred on the origin (base at Z = -H/2).
"""

import bpy
import os


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
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.shade_flat()
    return obj


def make_tower(n, W, D, H, rows, cols):
    body, trim, win = [], [], []

    body.append(box((W, D, H), (0, 0, 0)))

    # Corner pillars (proud of the walls).
    for sx in (-1, 1):
        for sy in (-1, 1):
            trim.append(box((1.4, 1.4, H), (sx * (W / 2), sy * (D / 2), 0)))

    mh = H * 0.94
    z0 = -mh / 2
    fh = mh / rows

    # Horizontal floor bands.
    for r in range(rows + 1):
        trim.append(box((W + 0.7, D + 0.7, 0.8), (0, 0, z0 + r * fh)))

    # Windows: proud lit panes with gaps between them (the body colour shows
    # through the gaps as the window grid). No separate frame mesh -> nothing
    # overlaps, so no z-fighting. Panes sit clearly OUT from the wall face.
    pane_h = fh * 0.5
    for r in range(rows):
        z = z0 + (r + 0.5) * fh
        for c in range(cols):
            x = -W / 2 + (c + 0.5) * (W / cols)
            pw = (W / cols) * 0.52
            win.append(box((pw, 0.35, pane_h), (x, -D / 2 - 0.2, z)))
            win.append(box((pw, 0.35, pane_h), (x, D / 2 + 0.2, z)))
        for c in range(cols):
            y = -D / 2 + (c + 0.5) * (D / cols)
            pd = (D / cols) * 0.52
            win.append(box((0.35, pd, pane_h), (-W / 2 - 0.2, y, z)))
            win.append(box((0.35, pd, pane_h), (W / 2 + 0.2, y, z)))

    # Rooftop cap + antennas.
    trim.append(box((W + 1.2, D + 1.2, H * 0.12), (0, 0, H / 2 + H * 0.05)))
    for ax in (-1, 0, 1):
        trim.append(box((0.4, 0.4, H * 0.18), (ax * W * 0.2, 0, H / 2 + H * 0.11 + H * 0.09)))

    join(body, "V%d_Body" % n)
    join(trim, "V%d_Trim" % n)
    join(win, "V%d_Win" % n)


def build():
    clear_scene()
    make_tower(1, 14, 14, 50, rows=7, cols=3)
    make_tower(2, 14, 14, 50, rows=8, cols=2)
    make_tower(3, 14, 14, 50, rows=6, cols=3)
    make_tower(4, 14, 14, 50, rows=9, cols=2)


def export():
    out = os.path.join(r"/Users/kirill/projects/roblox game", "blender", "out", "Tower.fbx")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True,
                             apply_unit_scale=True, global_scale=1.0,
                             object_types={"MESH"})
    print("Exported:", out)


build()
export()
print("Done. Import blender/out/Tower.fbx -> overwrite assets/studio/Tower.rbxm")
