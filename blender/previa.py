# Renderiza uma prévia dos objetos lado a lado.
# Rodar:  Blender -b blender/mangue_assets.blend -P blender/previa.py -- <saida.png> [grupo]
import bpy, sys, math, os
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = args[0] if args else "/tmp/previa.png"
grupo = args[1] if len(args) > 1 else "grandes"

scene = bpy.context.scene
grupos = {
    "grandes": ["arvore_mangue_a", "arvore_mangue_b", "arvore_mangue_c", "arvore_fina_a", "rancho", "tronco_caido"],
    "cultura": ["parabolica"],
    "barco": ["canoa", "barco_abandonado", "bancada"],
    "pecas": ["motor_rabeta", "helice", "remo", "cuia", "galao", "lata_breu", "bacia"],
    "pequenos": ["caranguejo", "balde", "fogao", "panela", "toca", "feixe_lenha", "saco_farinha", "muda", "braco"],
}
names = grupos[grupo]
for ob in scene.objects:
    ob.hide_render = ob.name not in names

x = 0.0
gap = {"grandes": 1.5, "barco": 1.0}.get(grupo, 0.25)
for n in names:
    ob = scene.objects[n]
    w = ob.dimensions.x
    ob.location = (x + w / 2, 0, 0)
    x += w + gap
total = x - gap

# chão
bpy.ops.mesh.primitive_plane_add(size=200, location=(total / 2, 0, -0.02))
chao = bpy.context.active_object
m = bpy.data.materials.new("chao"); m.use_nodes = True
[n for n in m.node_tree.nodes if n.type=="BSDF_PRINCIPLED"][0].inputs["Base Color"].default_value = (0.25, 0.22, 0.18, 1)
chao.data.materials.append(m)

sun = bpy.data.objects.new("sol", bpy.data.lights.new("sol", 'SUN'))
sun.data.energy = 4
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
scene.collection.objects.link(sun)
scene.world = bpy.data.worlds.new("ceu")
scene.world.use_nodes = True
[n for n in scene.world.node_tree.nodes if n.type=="BACKGROUND"][0].inputs["Color"].default_value = (0.6, 0.7, 0.85, 1)
[n for n in scene.world.node_tree.nodes if n.type=="BACKGROUND"][0].inputs["Strength"].default_value = 0.8

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
h = {"grandes": 10, "barco": 3.0, "pecas": 0.8, "cultura": 9.0}.get(grupo, 0.6)
dist = total / (2 * 0.45) * 1.05
cam.location = (total / 2 + (dist * 0.6 if grupo == "barco" else 0), -dist, h * 0.55 + dist * 0.18 + (4 if grupo == "barco" else 0))
direction = Vector((total / 2, 0, h * 0.4)) - cam.location
cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = 40
scene.camera = cam

for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = eng
        break
    except TypeError:
        pass
scene.render.resolution_x = 1600
scene.render.resolution_y = 800
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDER OK", out)
