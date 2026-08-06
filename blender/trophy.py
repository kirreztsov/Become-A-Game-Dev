"""
Showcase model: the "1,000,000 Subscribers Award" -- a high-poly gold trophy
cup with a turned stem, ring handles and an ornate stepped plinth, crowned with
a play ▶ button emblem and engraved "1,000,000 / SUBSCRIBERS" on the nameplate.
The game's Play-Button / subscriber-milestone reward, as a trophy.

NOTE: Roblox's FBX importer can mirror the X axis -- if in Studio the play ▶
points the wrong way or the text reads backwards, tell me and I'll flip it.

It's built for DETAIL (a 1-2 MB mesh): the cup/stem is a true surface of
revolution (lathe) and the gold bodies get a Subdivision Surface pass, so the
weight is real smooth geometry -- not bloat. Tune file size with the two knobs
below and re-run:
    REV_SEGMENTS  -- how many segments around the lathe (more = heavier/smoother)
    SUBSURF       -- Subdivision Surface levels on the gold bodies (each +1 ~x4 polys)

Part names drive in-game colour:
    TrophyGold  -> gold metal (cup, stem, handles, orbs, play-button badge)
    Plinth      -> dark stone base
    Plate       -> engraving plate (light)
    PlayTri     -> the play ▶ triangle (accent, e.g. white or dark)
    Text        -> engraved "1,000,000 / SUBSCRIBERS" (light/gold)

Built Z-up, base at Z=0, 1 unit = 1 stud (~13 studs tall). Run in Blender
(Scripting -> Open -> Reload -> Run), then Import blender/out/Trophy.fbx and
Save assets/studio/Trophy.rbxm.
"""

import bpy
import bmesh
import os
import math

OUT = r"/Users/kirill/projects/roblox game/blender/out"

# ---- detail knobs (raise for a heavier file, lower for a lighter one) -------
# Cranked for a ~10 MB stress-test export. If the FBX comes out too small/large,
# nudge these and re-run (each +1 on SUBSURF is roughly x4 the polygons/size).
REV_SEGMENTS = 256    # lathe segments around the axis
SUBSURF = 3           # subdivision levels on the gold bodies


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for item in list(coll):
            coll.remove(item)


def _apply(o, rot):
    if rot != (0, 0, 0):
        o.rotation_euler = (math.radians(rot[0]), math.radians(rot[1]), math.radians(rot[2]))
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return o


def box(dims, loc, bucket, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = dims
    bucket.append(_apply(o, rot))
    return o


def cyl(r, depth, loc, bucket, rot=(0, 0, 0), verts=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    bucket.append(_apply(bpy.context.active_object, rot))
    return bpy.context.active_object


def ball(r, loc, bucket, subdiv=3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=r, location=loc)
    bucket.append(_apply(bpy.context.active_object, (0, 0, 0)))
    return bpy.context.active_object


def torus(major_r, minor_r, loc, bucket, rot=(0, 0, 0), maj=48, minr=24):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_r, minor_radius=minor_r, location=loc,
                                     major_segments=maj, minor_segments=minr)
    bucket.append(_apply(bpy.context.active_object, rot))
    return bpy.context.active_object


def lathe(profile, name, bucket, z_off=0.0, segments=REV_SEGMENTS):
    """Surface of revolution from a (radius, z) profile spun about the Z axis."""
    bm = bmesh.new()
    verts = [bm.verts.new((r, 0.0, z + z_off)) for (r, z) in profile]
    for i in range(len(verts) - 1):
        bm.edges.new((verts[i], verts[i + 1]))
    geom = list(bm.verts) + list(bm.edges)
    bmesh.ops.spin(bm, geom=geom, cent=(0, 0, 0), axis=(0, 0, 1),
                   dvec=(0, 0, 0), angle=2 * math.pi, steps=segments, use_duplicate=False)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    bucket.append(o)
    return o


def subsurf(o, levels):
    if levels <= 0:
        return
    bpy.context.view_layer.objects.active = o
    m = o.modifiers.new("Subsurf", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    bpy.ops.object.modifier_apply(modifier="Subsurf")


def curved_text(body, size, radius, z, bucket, extrude=0.18):
    """One solid text string, stood upright and BENT around the cup so it wraps
    the curve without reordering/scrambling the letters. Centred on the front
    (-Y) at height z, at the given cup radius."""
    bpy.ops.object.text_add(location=(0, 0, 0))
    t = bpy.context.active_object
    t.data.body = body
    t.data.size = size
    t.data.extrude = extrude
    t.data.bevel_depth = 0.01
    t.data.align_x = "CENTER"
    t.data.align_y = "CENTER"
    bpy.context.view_layer.objects.active = t
    bpy.ops.object.convert(target="MESH")
    # Stand it upright: height -> Z, width -> X, front face -> -Y.
    t.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # Bend the width around a vertical (Z) axis so it wraps on the cup.
    w = max(t.dimensions.x, 0.001)
    m = t.modifiers.new("Bend", "SIMPLE_DEFORM")
    m.deform_method = "BEND"
    m.deform_axis = "Z"
    m.angle = w / radius
    bpy.context.view_layer.objects.active = t
    bpy.ops.object.modifier_apply(modifier="Bend")
    # Drop the arc onto the cup: its centre of curvature -> trophy axis, at height z.
    t.location = (0, -radius, z)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    bucket.append(t)
    return t


def join_shade(parts, name):
    if not parts:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    bpy.ops.object.shade_smooth()
    return o


def play_triangle(size, depth, loc, bucket, name="PlayTri"):
    """A right-pointing ▶ prism (tip toward +X), thin in Y, standing in XZ."""
    bm = bmesh.new()
    pts = [(size, 0.0), (-size * 0.6, size * 0.85), (-size * 0.6, -size * 0.85)]
    vs = [bm.verts.new((x, -depth / 2, z)) for (x, z) in pts]
    f = bm.faces.new(vs)
    res = bmesh.ops.extrude_face_region(bm, geom=[f])
    ext = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=ext, vec=(0, depth, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = loc
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bucket.append(o)
    return o


def text3d(body, size, loc, bucket, extrude=0.10, bev=0.015):
    bpy.ops.object.text_add(location=loc)
    t = bpy.context.active_object
    t.data.body = body
    t.data.size = size
    t.data.extrude = extrude
    t.data.bevel_depth = bev
    t.data.align_x = "CENTER"
    t.data.align_y = "CENTER"
    t.rotation_euler = (math.radians(90), 0, 0)  # stand up, front faces -Y
    bpy.context.view_layer.objects.active = t
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bucket.append(t)
    return t


def export(filename):
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, filename)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=out, use_selection=True,
                             apply_unit_scale=True, global_scale=1.0,
                             object_types={"MESH"})
    print("Exported:", out)


def build_trophy():
    clear_scene()
    gold, plinth, plate, tri, text = [], [], [], [], []

    # --- ornate stepped plinth (dark stone) ---
    box((6.4, 6.4, 1.0), (0, 0, 0.5), plinth)
    box((5.4, 5.4, 0.8), (0, 0, 1.35), plinth)
    box((4.4, 4.4, 0.6), (0, 0, 1.95), plinth)
    # engraving plate on the front (+Y) face
    box((3.4, 0.2, 1.1), (0, -2.75, 1.0), plate)
    # corner orbs on the lowest tier
    for ox in (-2.9, 2.9):
        for oy in (-2.9, 2.9):
            ball(0.55, (ox, oy, 1.05), gold, subdiv=3)

    BASE = 2.25  # trophy foot sits on the plinth top

    # --- trophy body: solid cup + turned stem, as a lathe profile (r, z) ---
    profile = [
        (0.00, 0.00), (2.40, 0.00), (2.40, 0.55), (1.55, 0.95),
        (1.10, 1.55), (0.62, 3.05), (0.60, 3.45), (1.00, 4.00),
        (0.68, 4.45), (1.45, 4.95), (2.85, 5.85), (3.22, 7.45),
        (3.38, 8.85), (3.45, 9.25), (3.02, 9.42), (0.00, 9.42),
    ]
    body = lathe(profile, "TrophyBody", [], z_off=BASE)
    subsurf(body, SUBSURF)
    gold.append(body)

    # --- two ring handles on the cup sides ---
    for sx in (-1, 1):
        h = torus(1.25, 0.30, (sx * 2.7, 0, BASE + 6.7), [], rot=(0, 90, 0), maj=48, minr=20)
        subsurf(h, max(1, SUBSURF - 1))
        gold.append(h)

    # --- play-button emblem crowning the cup (this is what makes it "the award") ---
    top = BASE + 9.42
    cyl(0.45, 0.8, (0, 0, top + 0.4), gold, verts=24)             # gold riser post
    etop = top + 0.8
    badge = cyl(2.0, 0.45, (0, 0, etop + 1.9), [], rot=(90, 0, 0), verts=64)  # round badge, faces -Y
    subsurf(badge, SUBSURF)
    gold.append(badge)
    ring = torus(2.0, 0.16, (0, 0, etop + 1.9), [], rot=(90, 0, 0), maj=64, minr=16)  # rim
    gold.append(ring)
    play_triangle(1.05, 0.5, (0.2, -0.45, etop + 1.9), tri)       # ▶ raised on the badge front

    # NOTE: the milestone number is NOT baked into the mesh -- 3D text kept
    # breaking the import. It's added in-game as a crisp label instead, which
    # is fully controllable and never mirrors/scrambles. (curved_text / text3d
    # helpers are kept above in case we want engraved text later.)

    join_shade(gold, "TrophyGold")
    join_shade(plinth, "Plinth")
    join_shade(plate, "Plate")
    join_shade(tri, "PlayTri")
    join_shade(text, "Text")
    export("Trophy.fbx")


build_trophy()
print("Done. Import blender/out/Trophy.fbx -> Save assets/studio/Trophy.rbxm")
print("If the file is too small/large, change REV_SEGMENTS / SUBSURF at the top and re-run.")
