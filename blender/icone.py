# Renderiza o caranguejo como ícone/logo do jogo (fundo transparente).
# Rodar:  Blender -b blender/mangue_assets.blend -P blender/icone.py -- <saida.png> <tamanho>
import bpy, sys, math
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
saida = args[0] if args else "/tmp/icone.png"
tam = int(args[1]) if len(args) > 1 else 512

scene = bpy.context.scene
for ob in scene.objects:
    ob.hide_render = ob.name != "caranguejo"
crab = scene.objects["caranguejo"]
crab.location = (0, 0, 0)
crab.rotation_euler = (0, 0, 0)

# luz quente de cima + contraluz azulada (lama e água)
for nome, energia, rot, cor in (("chave", 4.0, (math.radians(40), math.radians(-25), math.radians(20)), (1.0, 0.9, 0.75)),
                                 ("contra", 2.5, (math.radians(-60), 0, math.radians(180)), (0.55, 0.7, 1.0))):
    l = bpy.data.objects.new(nome, bpy.data.lights.new(nome, 'SUN'))
    l.data.energy = energia
    l.data.color = cor
    l.rotation_euler = rot
    scene.collection.objects.link(l)

scene.world = bpy.data.worlds.new("vazio")
scene.world.use_nodes = True
bg = [n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND"][0]
bg.inputs["Color"].default_value = (0.35, 0.3, 0.25, 1)
bg.inputs["Strength"].default_value = 0.6

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 0.27
# de frente e um pouco de cima: pinças abertas para a câmera (frente do bicho = +Y)
cam.location = (0, 0.42, 0.34)
direcao = Vector((0, 0, 0.05)) - cam.location
cam.rotation_euler = direcao.to_track_quat('-Z', 'Y').to_euler()
scene.camera = cam

for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = eng
        break
    except TypeError:
        pass
scene.render.film_transparent = True
scene.render.resolution_x = tam
scene.render.resolution_y = tam
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = 'Standard'
scene.render.use_stamp = False
scene.render.metadata_input = 'SCENE'
for k in ('use_stamp_filename', 'use_stamp_date', 'use_stamp_time', 'use_stamp_render_time', 'use_stamp_frame', 'use_stamp_camera', 'use_stamp_lens', 'use_stamp_scene', 'use_stamp_memory', 'use_stamp_hostname'):
    setattr(scene.render, k, False)
scene.render.filepath = saida
bpy.ops.render.render(write_still=True)
print("ICONE OK", saida)
