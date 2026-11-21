# Adapta modelos CC0 do Poly Haven (blender/externos/) para o jogo:
# escala, posição/orientação no padrão dos nossos modelos, simplificação dos pesados.
# Exporta com o mesmo nome dos modelos que substituem, então o jogo troca sem mudar código.
# Rodar depois de gerar_assets.py:  Blender -b -P blender/importar_externos.py

import bpy, os, math, sys
from mathutils import Matrix, Vector

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXT = os.path.join(BASE, "blender", "externos")
ASSETS = os.path.join(BASE, "jogo", "assets")

# id do Poly Haven -> (arquivo de saída, escala, matriz de ajuste, alvo de faces ou 0)
ROT_X = lambda g: Matrix.Rotation(math.radians(g), 4, 'X')
ROT_Z = lambda g: Matrix.Rotation(math.radians(g), 4, 'Z')
MODELOS = {
    # facão: cabo na origem, lâmina para +Y, lâmina chata no plano YZ (igual ao nosso)
    "machete": ("facao.glb", 0.9, ROT_X(-90) @ Matrix.Translation((0, 0, 0.07)), 0),
    "metal_jerrycan": ("galao.glb", 0.8, Matrix(), 6000),
    "pot_enamel_01": ("panela.glb", 1.1, Matrix(), 0),
    "can_rusted": ("lata_breu.glb", 1.0, Matrix(), 0),
    "dead_tree_trunk_02": ("tronco_caido.glb", 1.0, Matrix.Translation((0, 0, 0.12)), 6000),
    "old_tyre": ("pneu_velho.glb", 1.0, Matrix.Translation((0, 0, 0.3)), 0),
    "fishermans_hat": ("chapeu.glb", 1.0, Matrix.Translation((0, 0, 0.034)), 4000),
    "rubber_boots": ("botas.glb", 1.0, Matrix(), 6000),
    "wooden_bucket_01": ("balde.glb", 0.6, Matrix(), 0),
    "wicker_basket_02": ("cofo.glb", 1.3, Matrix(), 6000),
    "modular_wooden_pier": ("trapiche.glb", 1.0, Matrix(), 20000),
    "lifebuoy": ("boia.glb", 0.8, Matrix(), 4000),
    "plastic_crate_01": ("caixa_plastica.glb", 1.0, Matrix(), 5000),
    "fern_02": ("samambaia.glb", 0.8, Matrix(), 0),
}
# peças que ficam de fora (o píer vem com sobras: postes soltos, tábuas e um pórtico)
SO_ESTES = {"modular_wooden_pier": ["section_01", "section_02", "section_03", "section_04"],
            "rubber_boots": ["dirty_l", "dirt_r"]}   # só o par sujo de lama (o modelo traz dois pares)
# modelos que vêm fora do lugar: centraliza em X/Y e assenta no chão (z = 0)
CENTRALIZAR = {"rubber_boots"}
# Importar só alguns:  Blender -b -P blender/importar_externos.py -- rubber_boots machete
SOMENTE = set(sys.argv[sys.argv.index("--") + 1:]) if "--" in sys.argv else set()


def processar(k, saida, escala, ajuste, alvo):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(EXT, k, k + ".gltf"))
    obs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if k in SO_ESTES:
        for o in list(obs):
            if not any(t in o.name for t in SO_ESTES[k]):
                bpy.data.objects.remove(o)
        obs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    # tira os pais (glTF às vezes vem com nós vazios) e aplica transformações
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(obs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = os.path.splitext(saida)[0]
    for o in list(bpy.context.scene.objects):
        if o != ob:
            bpy.data.objects.remove(o)
    ob.data.transform(Matrix.Scale(escala, 4) @ ajuste)
    if k in CENTRALIZAR:
        xs = [v.co.x for v in ob.data.vertices]; ys = [v.co.y for v in ob.data.vertices]; zs = [v.co.z for v in ob.data.vertices]
        ob.data.transform(Matrix.Translation((-(min(xs) + max(xs)) / 2, -(min(ys) + max(ys)) / 2, -min(zs))))
    faces = len(ob.data.polygons)
    if alvo and faces > alvo:
        mod = ob.modifiers.new("simplificar", 'DECIMATE')
        mod.ratio = alvo / faces
        bpy.ops.object.modifier_apply(modifier=mod.name)
    print("EXTERNO", k, "->", saida, "faces", faces, "->", len(ob.data.polygons))
    bpy.ops.export_scene.gltf(filepath=os.path.join(ASSETS, saida), export_format='GLB',
                              use_selection=True, export_apply=True, export_yup=True,
                              export_image_format='JPEG', export_jpeg_quality=85)


for k, (saida, escala, ajuste, alvo) in MODELOS.items():
    if SOMENTE and k not in SOMENTE:
        continue
    processar(k, saida, escala, ajuste, alvo)
print("EXTERNOS OK")
