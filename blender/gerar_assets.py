# Gera os objetos 3D do MVP do jogo do mangue e exporta cada um como .glb para o Godot.
# Rodar:  Blender -b -P blender/gerar_assets.py
# Convenção: metros, Z para cima, a "frente" de cada objeto aponta para +Y
# (o exportador glTF converte para Y para cima e frente em -Z, como o Godot espera).

import bpy, bmesh, math, random, os, sys
import numpy as np
from mathutils import Vector, Matrix, noise

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(BASE, "jogo", "assets")
os.makedirs(ASSETS, exist_ok=True)
# Exportar só alguns:  Blender -b -P blender/gerar_assets.py -- rancho.glb rede.glb
SOMENTE = set(sys.argv[sys.argv.index("--") + 1:]) if "--" in sys.argv else set()

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'

# ---------------------------------------------------------------- materiais

_mats = {}

def material(name, color, rough=0.8, metal=0.0, image=None):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if image is not None:
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        m.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        try:
            m.surface_render_method = 'DITHERED'
        except Exception:
            pass
        m.use_backface_culling = False
    _mats[name] = m
    return m


def leaf_image():
    """Textura de folhas de mangue (verde, com nervura central e fundo transparente)."""
    size = 512
    rng = np.random.default_rng(7)
    img = np.zeros((size, size, 4), dtype=np.float32)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    for _ in range(26):
        cx, cy = rng.uniform(60, size - 60, 2)
        ang = rng.uniform(0, math.pi)
        L = rng.uniform(55, 95)   # comprimento (meio eixo)
        W = L * rng.uniform(0.38, 0.48)
        ca, sa = math.cos(ang), math.sin(ang)
        u = (xx - cx) * ca + (yy - cy) * sa
        v = -(xx - cx) * sa + (yy - cy) * ca
        # folha elíptica com ponta
        shape = (u / L) ** 2 + (v / (W * (1 - 0.35 * (u / L)))) ** 2
        inside = shape < 1.0
        g = rng.uniform(0.0, 1.0)
        base = np.array([0.10 + 0.10 * g, 0.30 + 0.16 * g, 0.06 + 0.05 * g])
        light = 0.85 + 0.25 * (1 - np.clip(shape, 0, 1))
        rib = np.exp(-(v ** 2) / 6.0) * (np.abs(u) < L * 0.95)
        col = base[None, None, :] * light[..., None]
        col = col * (1 - 0.35 * rib[..., None]) + np.array([0.35, 0.45, 0.20]) * 0.35 * rib[..., None]
        img[inside, :3] = col[inside]
        img[inside, 3] = 1.0
    # caule fino de ligação
    image = bpy.data.images.new("folhas_mangue", size, size, alpha=True)
    image.pixels.foreach_set(img[::-1].ravel())
    path = os.path.join(ASSETS, "folhas_mangue.png")
    image.filepath_raw = path
    image.file_format = 'PNG'
    if not SOMENTE:
        image.save()
    return image

LEAF_IMG = leaf_image()

M_CASCA = material("casca_mangue", (0.30, 0.25, 0.20), 0.9)
M_CASCA_CLARA = material("casca_clara", (0.55, 0.50, 0.42), 0.9)
M_RAIZ = material("raiz_mangue", (0.22, 0.17, 0.13), 0.85)
M_FOLHA = material("folha_mangue", (1, 1, 1), 0.6, image=LEAF_IMG)
M_FOLHA_SOLIDA = material("folha_solida", (0.12, 0.30, 0.08), 0.7)
M_LAMA = material("lama", (0.10, 0.085, 0.065), 0.3)
M_BURACO = material("buraco", (0.03, 0.025, 0.02), 0.6)
M_CARAPACA = material("carapaca_uca", (0.23, 0.17, 0.15), 0.35)
M_PATA = material("pata_uca", (0.24, 0.09, 0.13), 0.5)
M_PINCA = material("pinca_uca", (0.42, 0.2, 0.12), 0.4)
M_OLHO = material("olho", (0.01, 0.01, 0.01), 0.1)
M_BALDE = material("balde_plastico", (0.10, 0.12, 0.16), 0.45)
M_ALCA = material("alca_metal", (0.6, 0.6, 0.6), 0.35, 0.9)
M_PEDRA = material("pedra", (0.36, 0.33, 0.30), 0.9)
M_PANELA = material("aluminio", (0.65, 0.65, 0.66), 0.3, 1.0)
M_FULIGEM = material("fuligem", (0.05, 0.045, 0.04), 0.95)
M_LENHA = material("lenha", (0.45, 0.36, 0.26), 0.9)
M_MADEIRA = material("madeira_rancho", (0.42, 0.31, 0.21), 0.85)
M_MADEIRA_ESC = material("madeira_escura", (0.27, 0.20, 0.14), 0.85)
M_PALHA = material("palha", (0.62, 0.50, 0.30), 0.9)
M_PALHA_ESC = material("palha_escura", (0.45, 0.36, 0.22), 0.9)
M_SACO = material("saco_farinha", (0.80, 0.74, 0.60), 0.95)
M_PELE = material("pele", (0.28, 0.16, 0.10), 0.55)
M_MANGA = material("manga_camisa", (0.10, 0.11, 0.13), 0.9)
M_CORDA = material("corda", (0.55, 0.45, 0.30), 0.9)

# ---------------------------------------------------------------- ajudantes

def link(ob, coll):
    coll.objects.link(ob)
    return ob

def new_coll(name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c

def mesh_from_curve(cu_ob, coll):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(cu_ob.evaluated_get(dg))
    name = cu_ob.name
    for c in list(cu_ob.users_collection):
        c.objects.unlink(cu_ob)
    bpy.data.objects.remove(cu_ob)
    ob = bpy.data.objects.new(name, me)
    return link(ob, coll)

def tube(coll, pts, radii, mat, name="tubo", sides=1, caps=True):
    """Tubo que passa pelos pontos, com raio variável (galho, raiz, perna)."""
    cu = bpy.data.curves.new(name, 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = 1.0
    cu.bevel_resolution = sides
    cu.use_fill_caps = caps
    sp = cu.splines.new('POLY')
    sp.points.add(len(pts) - 1)
    for i, (p, r) in enumerate(zip(pts, radii)):
        sp.points[i].co = (p[0], p[1], p[2], 1.0)
        sp.points[i].radius = r
    cu.materials.append(mat)
    ob = bpy.data.objects.new(name, cu)
    coll.objects.link(ob)
    return mesh_from_curve(ob, coll)

def bezier_pts(p0, p1, p2, n=10):
    p0, p1, p2 = Vector(p0), Vector(p1), Vector(p2)
    out = []
    for i in range(n + 1):
        t = i / n
        out.append((1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2)
    return out

def lerp_radii(r0, r1, n):
    return [r0 + (r1 - r0) * i / (n - 1) for i in range(n)]

def bm_object(coll, bm, name, mat):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    return link(ob, coll)

def sphere(coll, loc, scale, mat, name="esfera", seg=12, rings=8, rough=0.0, seed=0):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    if rough > 0:
        for v in bm.verts:
            n = noise.noise(v.co * 2.3 + Vector((seed, seed * 0.7, 1.3)))
            v.co *= 1.0 + rough * n
    for v in bm.verts:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) + Vector(loc)
    return bm_object(coll, bm, name, mat)

def ico(coll, loc, scale, mat, name="pedra", subd=2, rough=0.25, seed=0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subd, radius=1.0)
    for v in bm.verts:
        n = noise.noise(v.co * 1.7 + Vector((seed * 3.1, seed, 0.5)))
        v.co *= 1.0 + rough * n
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) + Vector(loc)
    return bm_object(coll, bm, name, mat)

def box(coll, loc, size, mat, name="caixa", rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    R = (Matrix.Rotation(rot[2], 4, 'Z') @ Matrix.Rotation(rot[1], 4, 'Y') @ Matrix.Rotation(rot[0], 4, 'X'))
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(loc)) @ R, verts=bm.verts)
    return bm_object(coll, bm, name, mat)

def cylinder(coll, loc, r1, r2, depth, mat, name="cilindro", seg=16, cap_top=True, cap_bot=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=depth)
    if not cap_top or not cap_bot:
        faces = [f for f in bm.faces if len(f.verts) == seg]
        for f in faces:
            z = f.calc_center_median().z
            if (z > 0 and not cap_top) or (z < 0 and not cap_bot):
                bmesh.ops.delete(bm, geom=[f], context='FACES_ONLY')
    bmesh.ops.translate(bm, vec=Vector(loc) + Vector((0, 0, depth / 2)), verts=bm.verts)
    return bm_object(coll, bm, name, mat)

def leaf_card(coll, center, size, normal_hint, name="folha"):
    """Quadrado com a textura de folhas, orientado meio ao acaso."""
    bm = bmesh.new()
    h = size / 2
    vs = [bm.verts.new(v) for v in [(-h, -h, 0), (h, -h, 0), (h, h, 0), (-h, h, 0)]]
    f = bm.faces.new(vs)
    uv = bm.loops.layers.uv.new("UVMap")
    for loop, c in zip(f.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
        loop[uv].uv = c
    rot = Vector(normal_hint).to_track_quat('Z', 'Y').to_matrix().to_4x4()
    spin = Matrix.Rotation(random.uniform(0, math.tau), 4, 'Z')
    tilt = Matrix.Rotation(random.uniform(-0.6, 0.6), 4, 'X')
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(center)) @ rot @ tilt @ spin, verts=bm.verts)
    return bm_object(coll, bm, name, M_FOLHA)

def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40)) if hasattr(bpy.ops.object, "shade_smooth_by_angle") else None
    return ob

# modelos que vêm do Poly Haven (blender/importar_externos.py): não sobrescrever
EXTERNOS = {"facao.glb", "galao.glb", "panela.glb", "lata_breu.glb", "tronco_caido.glb", "balde.glb"}


def export(ob, filename):
    if filename in EXTERNOS or (SOMENTE and filename not in SOMENTE):
        return
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ASSETS, filename),
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )

# ---------------------------------------------------------------- árvores

def arvore_mangue(name, seed, height, n_roots, slender=False):
    random.seed(seed)
    coll = new_coll(name)
    parts = []
    lean = Vector((random.uniform(-0.4, 0.4), random.uniform(-0.4, 0.4), 0))
    base_z = 0.9 if not slender else 0.0
    # tronco com leve curva
    n = 12
    pts, radii = [], []
    r0 = 0.11 if not slender else 0.08
    for i in range(n):
        t = i / (n - 1)
        z = base_z + t * (height - base_z)
        off = lean * (t ** 1.5) + Vector((math.sin(t * 5 + seed) * 0.08, math.cos(t * 4 + seed) * 0.08, 0))
        pts.append(Vector((off.x, off.y, z)))
        radii.append(r0 * (1 - 0.65 * t))
    if slender:
        pts.insert(0, Vector((0, 0, -0.3)))
        radii.insert(0, r0 * 1.1)
    parts.append(tube(coll, pts, radii, M_CASCA if not slender else M_CASCA_CLARA, name + "_tronco", sides=2))

    # raízes-escora (rizóforos) em arco até a lama
    if n_roots:
        for k in range(n_roots):
            a = k / n_roots * math.tau + random.uniform(-0.3, 0.3)
            start_z = random.uniform(0.7, 1.9)
            t = (start_z - base_z) / (height - base_z)
            start = Vector((lean.x * max(t, 0) ** 1.5, lean.y * max(t, 0) ** 1.5, start_z))
            dist = random.uniform(0.9, 1.7)
            end = Vector((math.cos(a) * dist, math.sin(a) * dist, -0.25))
            mid = start.lerp(end, 0.45) + Vector((0, 0, random.uniform(0.35, 0.7)))
            bp = bezier_pts(start, mid, end, 10)
            parts.append(tube(coll, bp, lerp_radii(0.045, 0.03, len(bp)), M_RAIZ, name + "_raiz", sides=1))
            # raiz secundária
            if random.random() < 0.6:
                s2 = bp[4]
                a2 = a + random.uniform(-0.8, 0.8)
                e2 = Vector((math.cos(a2) * dist * 1.25, math.sin(a2) * dist * 1.25, -0.25))
                m2 = s2.lerp(e2, 0.5) + Vector((0, 0, 0.25))
                bp2 = bezier_pts(s2, m2, e2, 8)
                parts.append(tube(coll, bp2, lerp_radii(0.03, 0.022, len(bp2)), M_RAIZ, name + "_raiz2", sides=1))

    # galhos e copa
    top = pts[-1]
    tips = [top]
    n_br = random.randint(4, 6)
    for b in range(n_br):
        t = random.uniform(0.55, 0.92)
        idx = int(t * (len(pts) - 1))
        s = pts[idx]
        a = random.uniform(0, math.tau)
        L = random.uniform(1.0, 2.2) * (1.2 - t * 0.5)
        e = s + Vector((math.cos(a) * L, math.sin(a) * L, L * random.uniform(0.5, 1.0)))
        m = s.lerp(e, 0.5) + Vector((0, 0, 0.2))
        bp = bezier_pts(s, m, e, 6)
        parts.append(tube(coll, bp, lerp_radii(radii[idx] * 0.6, 0.012, len(bp)), M_CASCA if not slender else M_CASCA_CLARA, name + "_galho", sides=1))
        tips.append(e)
    # folhas: cartões espalhados em volta de cada ponta
    for tip in tips:
        for _ in range(18 if not slender else 12):
            off = Vector((random.gauss(0, 0.55), random.gauss(0, 0.55), random.gauss(0.1, 0.35)))
            nrm = Vector((off.x, off.y, abs(off.z) + 0.6)).normalized()
            parts.append(leaf_card(coll, tip + off, random.uniform(0.7, 1.1), nrm, name + "_folha"))
    ob = join(parts, name)
    export(ob, name + ".glb")
    return ob

arvore_mangue("arvore_mangue_a", 11, 7.5, 7)
arvore_mangue("arvore_mangue_b", 23, 6.0, 9)
arvore_mangue("arvore_mangue_c", 37, 9.0, 6)
arvore_mangue("arvore_fina_a", 5, 8.5, 0, slender=True)
arvore_mangue("arvore_fina_b", 9, 7.0, 0, slender=True)

# ---------------------------------------------------------------- muda e tronco caído

def muda():
    random.seed(3)
    coll = new_coll("muda")
    parts = [tube(coll, [(0, 0, -0.05), (0.01, 0, 0.18), (0.0, 0.01, 0.38)], [0.008, 0.007, 0.005], M_RAIZ, "caule")]
    for i in range(6):
        a = i * 2.3
        z = 0.22 + i * 0.03
        tip = Vector((math.cos(a) * 0.09, math.sin(a) * 0.09, z + 0.04))
        bm = bmesh.new()
        L, W = 0.09, 0.035
        ring = [bm.verts.new((0, 0, 0)), bm.verts.new((L * 0.5, W, 0.01)), bm.verts.new((L, 0, 0.02)), bm.verts.new((L * 0.5, -W, 0.01))]
        bm.faces.new(ring)
        bmesh.ops.transform(bm, matrix=Matrix.Translation((0, 0, z)) @ Matrix.Rotation(a, 4, 'Z') @ Matrix.Rotation(-0.35, 4, 'Y'), verts=bm.verts)
        parts.append(bm_object(coll, bm, "folha", M_FOLHA_SOLIDA))
    ob = join(parts, "muda")
    export(ob, "muda.glb")

muda()

def tronco_caido():
    random.seed(41)
    coll = new_coll("tronco_caido")
    pts = [Vector((-2.2, 0, 0.1)), Vector((-1, 0.1, 0.16)), Vector((0, -0.05, 0.18)), Vector((1.2, 0.08, 0.15)), Vector((2.3, 0.0, 0.12))]
    parts = [tube(coll, pts, [0.17, 0.18, 0.17, 0.15, 0.12], M_CASCA_CLARA, "tora", sides=2)]
    for x in (-1.4, 0.3, 1.5):
        a = random.uniform(-1, 1)
        s = Vector((x, 0, 0.2))
        e = s + Vector((0.3, math.copysign(0.5, a), 0.45))
        parts.append(tube(coll, [s, s.lerp(e, 0.5), e], [0.05, 0.04, 0.02], M_CASCA_CLARA, "toco"))
    ob = join(parts, "tronco_caido")
    export(ob, "tronco_caido.glb")

tronco_caido()

# ---------------------------------------------------------------- toca de caranguejo

def toca():
    coll = new_coll("toca")
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=False, segments=20, radius=1.0)
    # anel de lama levantada em volta do buraco
    rings = [(0.055, -0.04), (0.07, 0.02), (0.11, 0.045), (0.17, 0.03), (0.26, 0.0), (0.32, -0.02)]
    bm.free()
    bm = bmesh.new()
    seg = 20
    layers = []
    for r, z in rings:
        row = []
        for i in range(seg):
            a = i / seg * math.tau
            jitter = 1 + 0.12 * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, r * 10)))
            row.append(bm.verts.new((math.cos(a) * r * jitter, math.sin(a) * r * jitter, z + 0.015 * noise.noise(Vector((a, r * 7, 0.3))))))
        layers.append(row)
    for j in range(len(layers) - 1):
        for i in range(seg):
            a, b = layers[j][i], layers[j][(i + 1) % seg]
            c, d = layers[j + 1][(i + 1) % seg], layers[j + 1][i]
            bm.faces.new((a, b, c, d))
    mound = bm_object(coll, bm, "monte", M_LAMA)
    hole = cylinder(coll, (0, 0, -0.25), 0.058, 0.058, 0.22, M_BURACO, "buraco", seg=16, cap_top=False)
    # inverte normais do buraco para ver o lado de dentro
    bm = bmesh.new(); bm.from_mesh(hole.data); bmesh.ops.reverse_faces(bm, faces=bm.faces); bm.to_mesh(hole.data); bm.free()
    ob = join([mound, hole], "toca")
    export(ob, "toca.glb")

toca()

# ---------------------------------------------------------------- caranguejo-uçá

def caranguejo():
    """Caranguejo-uçá: casco largo, pernas curtas e grossas, pinças grandes. Frente = +Y."""
    random.seed(5)
    coll = new_coll("caranguejo")
    parts = []
    # casco: mais largo na frente, um pouco quadrado
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=22, v_segments=12, radius=1.0)
    for v in bm.verts:
        x, y, z = v.co
        largura = 0.062 * (1.0 + 0.12 * y)          # frente mais larga
        v.co = Vector((x * largura * (1.0 + 0.15 * (1 - abs(x))), y * 0.05, max(z, -0.35) * 0.028 + 0.06))
        v.co.z += 0.004 * noise.noise(v.co * 60)
    parts.append(bm_object(coll, bm, "carapaca", M_CARAPACA))
    parts.append(sphere(coll, (0, 0, 0.047), (0.055, 0.043, 0.016), M_PATA, "barriga", seg=14, rings=8))
    # olhos em pedúnculos na frente
    for sx in (-1, 1):
        parts.append(tube(coll, [(sx * 0.02, 0.042, 0.07), (sx * 0.025, 0.05, 0.085)], [0.0045, 0.004], M_CARAPACA, "pedunculo"))
        parts.append(sphere(coll, (sx * 0.026, 0.051, 0.088), (0.006, 0.006, 0.006), M_OLHO, "olho", seg=8, rings=6))
    # pernas: 4 de cada lado, curtas e grossas, dobradas para baixo
    for sx in (-1, 1):
        for k in range(4):
            y = 0.022 - k * 0.019
            a = 0.45 - k * 0.32
            base = Vector((sx * 0.052, y, 0.055))
            dirv = Vector((sx * math.cos(a), math.sin(a) - 0.1 * k, 0)).normalized()
            joelho = base + dirv * 0.04 + Vector((0, 0, 0.022))
            canela = joelho + dirv * 0.03 + Vector((0, 0, -0.01))
            pe = canela + dirv * 0.012 + Vector((0, 0, -0.055))
            parts.append(tube(coll, [base, joelho, canela, pe], [0.0095, 0.0085, 0.0065, 0.002], M_PATA, "perna"))
    # quelípodes: braço curto e pinça grande (a direita um pouco maior)
    for sx in (-1, 1):
        big = 1.15 if sx > 0 else 1.0
        s = Vector((sx * 0.04, 0.038, 0.055))
        e1 = Vector((sx * 0.07, 0.06, 0.066))
        e2 = Vector((sx * 0.06, 0.088, 0.064))
        parts.append(tube(coll, [s, e1, e2], [0.011, 0.012 * big, 0.013 * big], M_PATA, "braco_pinca"))
        palm = Vector((sx * 0.045, 0.108, 0.064))
        parts.append(sphere(coll, palm, (0.021 * big, 0.03 * big, 0.019 * big), M_PINCA, "palma", seg=14, rings=9))
        ponta = palm + Vector((-sx * 0.012, 0.048 * big, 0.004))
        parts.append(tube(coll, [palm + Vector((0, 0.022, 0.007)), ponta], [0.008 * big, 0.0025], M_PINCA, "dedo"))
        parts.append(tube(coll, [palm + Vector((sx * 0.004, 0.022, -0.007)), ponta + Vector((sx * 0.006, -0.006, -0.01))], [0.007 * big, 0.0025], M_PINCA, "dedo2"))
    ob = join(parts, "caranguejo")
    export(ob, "caranguejo.glb")
    # versão cozida: mesma forma, casca vermelho-alaranjada
    cozido = ob.copy()
    cozido.data = ob.data.copy()
    cozido.name = "caranguejo_cozido"
    coll.objects.link(cozido)
    trocas = {"carapaca_uca": material("carapaca_cozida", (0.75, 0.25, 0.08), 0.4),
              "pata_uca": material("pata_cozida", (0.70, 0.18, 0.06), 0.45),
              "pinca_uca": material("pinca_cozida", (0.85, 0.42, 0.18), 0.4)}
    for i, m in enumerate(cozido.data.materials):
        if m and m.name in trocas:
            cozido.data.materials[i] = trocas[m.name]
    export(cozido, "caranguejo_cozido.glb")

caranguejo()

# ---------------------------------------------------------------- balde

def balde():
    coll = new_coll("balde")
    body = cylinder(coll, (0, 0, 0), 0.12, 0.15, 0.3, M_BALDE, "corpo", seg=24, cap_top=False)
    mod = body.modifiers.new("espessura", 'SOLIDIFY')
    mod.thickness = 0.008
    mod.offset = 1
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(body.evaluated_get(dg))
    body.modifiers.clear()
    body.data = me
    rim = tube(coll, [(math.cos(a) * 0.152, math.sin(a) * 0.152, 0.3) for a in [i / 24 * math.tau for i in range(25)]], [0.008] * 25, M_BALDE, "borda", caps=False)
    alca_pts = [(math.cos(a) * 0.155, 0, 0.27 + math.sin(a) * 0.17) for a in [i / 16 * math.pi for i in range(17)]]
    alca = tube(coll, alca_pts, [0.004] * 17, M_ALCA, "alca")
    ob = join([body, rim, alca], "balde")
    export(ob, "balde.glb")

balde()

# ---------------------------------------------------------------- fogão de 3 pedras com panela

def fogao():
    random.seed(13)
    coll = new_coll("fogao")
    parts = [cylinder(coll, (0, 0, -0.01), 0.45, 0.45, 0.02, M_FULIGEM, "cinza", seg=20)]
    for i in range(3):
        a = i / 3 * math.tau + 0.4
        parts.append(ico(coll, (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.09), (0.12, 0.1, 0.11), M_PEDRA, "pedra", seed=i + 2))
    for i in range(4):
        a = i / 4 * math.tau + 0.2
        s = Vector((math.cos(a) * 0.42, math.sin(a) * 0.42, 0.03))
        e = Vector((math.cos(a) * 0.05, math.sin(a) * 0.05, 0.07))
        parts.append(tube(coll, [s, e], [0.025, 0.02], M_LENHA, "lenha"))
    ob = join(parts, "fogao")
    export(ob, "fogao.glb")

    coll2 = new_coll("panela")
    pan = cylinder(coll2, (0, 0, 0), 0.15, 0.16, 0.16, M_PANELA, "panela", seg=24, cap_top=False)
    mod = pan.modifiers.new("espessura", 'SOLIDIFY'); mod.thickness = 0.004; mod.offset = 1
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(pan.evaluated_get(dg)); pan.modifiers.clear(); pan.data = me
    fundo = cylinder(coll2, (0, 0, -0.002), 0.152, 0.152, 0.03, M_FULIGEM, "fundo", seg=24)
    alcas = [tube(coll2, [(sx * 0.16, -0.03, 0.13), (sx * 0.2, 0, 0.14), (sx * 0.16, 0.03, 0.13)], [0.006] * 3, M_PANELA, "alca") for sx in (-1, 1)]
    ob2 = join([pan, fundo] + alcas, "panela")
    export(ob2, "panela.glb")

fogao()

# ---------------------------------------------------------------- lenha (feixe para pegar)

def feixe_lenha():
    random.seed(17)
    coll = new_coll("feixe_lenha")
    parts = []
    for i in range(4):
        y = random.uniform(-0.08, 0.08)
        z = 0.03 + i * 0.03
        a = random.uniform(-0.3, 0.3)
        s = Vector((-0.45, y, z)); e = Vector((0.45, y + a * 0.3, z + random.uniform(-0.02, 0.02)))
        parts.append(tube(coll, [s, s.lerp(e, 0.5) + Vector((0, 0, 0.02)), e], [0.025, 0.028, 0.02], M_LENHA, "pau"))
    for x in (-0.25, 0.25):
        pts = [(x, math.cos(a) * 0.09, 0.07 + math.sin(a) * 0.08) for a in [i / 12 * math.tau for i in range(13)]]
        parts.append(tube(coll, pts, [0.006] * 13, M_CORDA, "amarra", caps=False))
    ob = join(parts, "feixe_lenha")
    export(ob, "feixe_lenha.glb")

feixe_lenha()

# ---------------------------------------------------------------- saco de farinha

def saco_farinha():
    coll = new_coll("saco_farinha")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=4, use_grid_fill=True)
    for v in bm.verts:
        x, y, z = v.co
        z01 = z + 0.5
        bulge = 1 + 0.25 * math.sin(z01 * math.pi) * (1 - z01 * 0.4)
        neck = 1 - 0.55 * max(0, z01 - 0.8) / 0.2
        v.co = Vector((x * 0.32 * bulge * neck, y * 0.22 * bulge * neck, z01 * 0.5))
        v.co += Vector((0, 0, 0.01 * noise.noise(v.co * 15)))
    ob = bm_object(coll, bm, "saco_farinha", M_SACO)
    corda = tube(coll, [(math.cos(a) * 0.11, math.sin(a) * 0.08, 0.44) for a in [i / 12 * math.tau for i in range(13)]], [0.008] * 13, M_CORDA, "corda", caps=False)
    ob = join([ob, corda], "saco_farinha")
    export(ob, "saco_farinha.glb")

saco_farinha()

# ---------------------------------------------------------------- rancho (casinha de pau e palha)

def rancho():
    random.seed(29)
    coll = new_coll("rancho")
    parts = []
    W, D, floor_z, wall_h = 4.0, 3.2, 0.5, 2.1
    # esteios dos cantos
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            parts.append(tube(coll, [(x, y, -0.4), (x + random.uniform(-0.03, 0.03), y, floor_z + wall_h)], [0.07, 0.06], M_MADEIRA_ESC, "esteio", sides=2))
    # esteios do meio das laterais: sobem até a cumeeira (o vão da porta fica livre)
    for x in (-W / 2, W / 2):
        parts.append(tube(coll, [(x, 0, -0.4), (x, 0, floor_z + wall_h + 0.9)], [0.07, 0.06], M_MADEIRA_ESC, "esteio", sides=2))
    # assoalho de tábuas
    n = 14
    for i in range(n):
        x = -W / 2 + (i + 0.5) * W / n
        parts.append(box(coll, (x, 0, floor_z), (W / n - 0.02, D + 0.1, 0.05), M_MADEIRA, "tabua", rot=(0, random.uniform(-0.01, 0.01), 0)))
    # paredes de ripas verticais (fundo e laterais) com frestas
    def wall(x0, y0, x1, y1, door=None):
        length = math.hypot(x1 - x0, y1 - y0)
        count = int(length / 0.14)
        for i in range(count):
            t = (i + 0.5) / count
            if door and door[0] < t < door[1]:
                continue
            x = x0 + (x1 - x0) * t; y = y0 + (y1 - y0) * t
            h = wall_h + random.uniform(-0.05, 0.05)
            ang = math.atan2(y1 - y0, x1 - x0)
            parts.append(box(coll, (x, y, floor_z + h / 2), (0.12, 0.03, h), M_MADEIRA if i % 3 else M_MADEIRA_ESC, "ripa", rot=(0, 0, ang)))
    wall(-W / 2, D / 2, W / 2, D / 2)                  # fundo
    wall(-W / 2, -D / 2, -W / 2, D / 2)                # lateral esquerda
    wall(W / 2, -D / 2, W / 2, D / 2, door=(0.0, 0.0)) # lateral direita
    wall(-W / 2, -D / 2, W / 2, -D / 2, door=(0.37, 0.63))  # frente com porta (frente = -Y), vão de x=-0.58 a 0.58
    # porta: batentes, verga e ripas curtas por cima, para o vão ler como porta
    porta_h = 1.95
    for x in (-0.56, 0.56):
        parts.append(box(coll, (x, -D / 2, floor_z + porta_h / 2), (0.08, 0.09, porta_h), M_MADEIRA_ESC, "batente"))
    parts.append(box(coll, (0, -D / 2, floor_z + porta_h + 0.04), (1.32, 0.1, 0.08), M_MADEIRA_ESC, "verga"))
    for i in range(8):
        x = -0.5 + (i + 0.5) / 8
        h = wall_h - porta_h - 0.08
        parts.append(box(coll, (x, -D / 2, floor_z + porta_h + 0.08 + h / 2), (0.12, 0.03, h), M_MADEIRA if i % 3 else M_MADEIRA_ESC, "ripa"))
    # folha da porta (tábuas com travessas), aberta para dentro, encostada do lado esquerdo
    folha = []
    for i in range(6):
        x = 0.08 + i * 0.16
        folha.append(box(coll, (x, 0, 0.94), (0.15, 0.025, 1.84), M_MADEIRA, "tabua_porta", rot=(0, random.uniform(-0.01, 0.01), 0)))
    for z in (0.3, 1.55):
        folha.append(box(coll, (0.48, 0.03, z), (0.9, 0.03, 0.1), M_MADEIRA_ESC, "travessa"))
    folha.append(box(coll, (0.48, 0.03, 0.93), (1.3, 0.03, 0.09), M_MADEIRA_ESC, "diagonal", rot=(0, -math.atan2(1.25, 0.8), 0)))
    ang = math.radians(100)    # quanto a porta está aberta
    giro = Matrix.Translation((-0.52, -D / 2 + 0.07, floor_z + 0.03)) @ Matrix.Rotation(ang, 4, 'Z')
    for f in folha:
        f.data.transform(giro)
    parts.extend(folha)
    # armadores (ganchos de pau) nas laterais, onde a rede (rede.glb) é amarrada
    for x in (-W / 2 + 0.05, W / 2 - 0.05):
        s = 1 if x < 0 else -1
        parts.append(tube(coll, [(x, 0.6, floor_z + 1.72), (x + s * 0.1, 0.6, floor_z + 1.74), (x + s * 0.12, 0.6, floor_z + 1.8)], [0.025, 0.022, 0.02], M_MADEIRA_ESC, "armador"))
    # vigas
    for y in (-D / 2, D / 2):
        parts.append(box(coll, (0, y, floor_z + wall_h), (W + 0.3, 0.1, 0.1), M_MADEIRA_ESC, "viga"))
    parts.append(box(coll, (0, 0, floor_z + wall_h + 0.9), (W + 0.8, 0.1, 0.1), M_MADEIRA_ESC, "cumeeira", rot=(0, 0, 0)))
    # telhado de palha: duas águas, várias camadas sobrepostas
    pitch = math.atan2(0.9, D / 2 + 0.6)
    for side in (-1, 1):
        for layer in range(9):
            t = layer / 8
            y = side * (D / 2 + 0.6) * (1 - t)
            z = floor_z + wall_h - 0.05 + 0.95 * t
            parts.append(box(coll, (random.uniform(-0.05, 0.05), y, z), (W + 1.0 + random.uniform(-0.1, 0.1), 0.55, 0.06),
                             M_PALHA if layer % 2 == 0 else M_PALHA_ESC, "palha", rot=(-side * pitch, 0, random.uniform(-0.01, 0.01))))
    # escada de 2 degraus na porta
    for i, z in enumerate((0.15, 0.32)):
        parts.append(box(coll, (0, -D / 2 - 0.35 + i * 0.15, z), (0.9, 0.25, 0.05), M_MADEIRA_ESC, "degrau"))
    # banco
    parts.append(box(coll, (-1.2, 1.1, floor_z + 0.45), (1.2, 0.4, 0.05), M_MADEIRA, "banco_tampo"))
    for x in (-1.7, -0.7):
        parts.append(box(coll, (x, 1.1, floor_z + 0.22), (0.05, 0.35, 0.45), M_MADEIRA_ESC, "banco_pe"))
    ob = join(parts, "rancho")
    export(ob, "rancho.glb")

rancho()

# ---------------------------------------------------------------- rede de dormir

def rede():
    """Rede maranhense listrada, com varanda (franja) e punhos de cordinha.
    Origem = linha dos armadores do rancho (o jogo balança a rede girando em X).
    Os armadores ficam em x = ±1.94; o pano vai de x = -1.15 a 1.15."""
    random.seed(41)
    coll = new_coll("rede")
    parts = []
    cores = {
        "creme": material("rede_creme", (0.86, 0.80, 0.66), 0.95),
        "vermelho": material("rede_vermelho", (0.62, 0.09, 0.07), 0.9),
        "laranja": material("rede_laranja", (0.86, 0.40, 0.08), 0.9),
        "amarelo": material("rede_amarelo", (0.90, 0.70, 0.16), 0.9),
        "verde": material("rede_verde", (0.10, 0.38, 0.22), 0.9),
    }
    varanda = material("rede_varanda", (0.74, 0.68, 0.55), 0.95)
    for m in list(cores.values()) + [varanda]:
        m.use_backface_culling = False
    listras = ["creme", "vermelho", "vermelho", "laranja", "amarelo", "verde", "creme",
               "creme", "verde", "amarelo", "laranja", "vermelho", "vermelho", "creme"]
    L = 1.15          # meio comprimento do pano
    NU, NV = 28, len(listras)

    def ponto(u, v):
        """u: -1..1 ao longo da rede; v: -1..1 de um lado ao outro do pano."""
        k = 1 - u * u
        meia_larg = 0.07 + 0.66 * k ** 0.7
        x = u * L
        y = v * meia_larg
        z = -0.58 - 0.52 * k + 0.20 * v * v * k ** 0.8      # caimento + o pano em concha
        return Vector((x, y, z))

    bm = bmesh.new()
    grade = [[bm.verts.new(ponto(-1 + 2 * i / NU, -1 + 2 * j / NV)) for j in range(NV + 1)] for i in range(NU + 1)]
    mat_idx = {n: i for i, n in enumerate(cores)}
    for i in range(NU):
        for j in range(NV):
            f = bm.faces.new((grade[i][j], grade[i + 1][j], grade[i + 1][j + 1], grade[i][j + 1]))
            f.material_index = mat_idx[listras[j]]
    me = bpy.data.meshes.new("pano")
    bm.to_mesh(me)
    bm.free()
    for m in cores.values():
        me.materials.append(m)
    pano = link(bpy.data.objects.new("pano", me), coll)
    parts.append(pano)

    # varanda: faixa de franja pendurada nas duas bordas compridas, com a barra recortada
    for lado in (-1, 1):
        bm = bmesh.new()
        topo, baixo = [], []
        n = 90
        for i in range(n + 1):
            u = -0.82 + 1.64 * i / n
            p = ponto(u, lado)
            fora = Vector((0, lado * 0.02, 0))
            topo.append(bm.verts.new(p))
            queda = 0.085 if i % 2 == 0 else 0.055
            baixo.append(bm.verts.new(p + fora + Vector((0, 0, -queda))))
        for i in range(n):
            bm.faces.new((topo[i], topo[i + 1], baixo[i + 1], baixo[i]))
        parts.append(bm_object(coll, bm, "varanda", varanda))

    # punhos: cordinhas que saem da ponta do pano e se juntam num nó; corda até o armador
    for s in (-1, 1):
        no = Vector((s * 1.52, 0, -0.30))
        for j in range(0, NV + 1, 2):
            p = ponto(s * 1.0, -1 + 2 * j / NV)
            meio = p.lerp(no, 0.5) + Vector((0, 0, -0.02))
            parts.append(tube(coll, [tuple(p), tuple(meio), tuple(no)], [0.005, 0.005, 0.006], cores["creme"], "cordinha", sides=1, caps=False))
        parts.append(sphere(coll, tuple(no), (0.035, 0.03, 0.03), cores["creme"], "no_punho", seg=8, rings=6))
        armador = Vector((s * 1.86, 0, 0.0))
        parts.append(tube(coll, [tuple(no), tuple(no.lerp(armador, 0.5) + Vector((0, 0, -0.03))), tuple(armador)], [0.012, 0.012, 0.012], M_CORDA, "corda"))
    ob = join(parts, "rede")
    export(ob, "rede.glb")

rede()

# ---------------------------------------------------------------- braço em primeira pessoa

def braco():
    coll = new_coll("braco")
    parts = []
    # cotovelo na origem, mão em +Y
    parts.append(tube(coll, [(0, -0.6, 0), (0, -0.2, 0), (0, 0.3, 0)], [0.055, 0.05, 0.043], M_MANGA, "manga", sides=2))
    parts.append(tube(coll, [(0, 0.25, 0), (0, 0.42, 0)], [0.036, 0.03], M_PELE, "antebraco", sides=2))
    palm = box(coll, (0, 0.47, 0), (0.08, 0.1, 0.03), M_PELE, "palma")
    bev = palm.modifiers.new("b", 'BEVEL'); bev.width = 0.01; bev.segments = 2
    parts.append(palm)
    for i, x in enumerate((-0.03, -0.01, 0.01, 0.03)):
        L = (0.075, 0.085, 0.08, 0.06)[i]
        parts.append(tube(coll, [(x, 0.515, 0), (x, 0.515 + L * 0.5, -0.006), (x, 0.515 + L, -0.016)], [0.009, 0.0085, 0.0075], M_PELE, "dedo"))
    # mão direita com a palma para baixo: o polegar fica do lado de dentro (-X)
    parts.append(tube(coll, [(-0.04, 0.44, -0.005), (-0.06, 0.48, -0.012), (-0.065, 0.52, -0.02)], [0.011, 0.01, 0.009], M_PELE, "polegar"))
    # aplica o bevel antes de juntar
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(palm.evaluated_get(dg)); palm.modifiers.clear(); palm.data = me
    ob = join(parts, "braco")
    export(ob, "braco.glb")

braco()

# ---------------------------------------------------------------- facão

def facao():
    coll = new_coll("facao")
    lamina_mat = material("lamina", (0.55, 0.55, 0.56), 0.35, 0.95)
    cabo_mat = material("cabo_facao", (0.06, 0.05, 0.045), 0.6)
    # lâmina: perfil afinando até a ponta, frente = +Y, cabo na origem
    bm = bmesh.new()
    perfil = [(0.10, 0.018), (0.25, 0.021), (0.38, 0.024), (0.46, 0.022), (0.52, 0.012), (0.55, 0.0)]
    topo, baixo = [], []
    for y, w in [(0.08, 0.016)] + perfil:
        topo.append(bm.verts.new((0.0, y, w)))
        baixo.append(bm.verts.new((0.0, y, -w * 0.9)))
    for i in range(len(topo) - 1):
        bm.faces.new((baixo[i], baixo[i + 1], topo[i + 1], topo[i]))
    lam = bm_object(coll, bm, "lamina", lamina_mat)
    sol = lam.modifiers.new("esp", 'SOLIDIFY'); sol.thickness = 0.003; sol.offset = 0
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(lam.evaluated_get(dg)); lam.modifiers.clear(); lam.data = me
    cabo = tube(coll, [(0, -0.05, 0), (0, 0.04, 0), (0, 0.085, 0)], [0.014, 0.016, 0.015], cabo_mat, "cabo", sides=2)
    ob = join([lam, cabo], "facao")
    export(ob, "facao.glb")

facao()

# ---------------------------------------------------------------- peixe (tainha)

def peixe():
    coll = new_coll("peixe")
    costas = material("peixe_costas", (0.22, 0.26, 0.28), 0.3, 0.6)
    barriga = material("peixe_barriga", (0.78, 0.8, 0.8), 0.25, 0.7)
    nadadeira = material("peixe_nadadeira", (0.3, 0.32, 0.3), 0.5)
    olho_m = material("olho", (0.01, 0.01, 0.01), 0.1)
    # corpo alongado, frente = +Y, 30 cm
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0)
    for v in bm.verts:
        y = v.co.y
        afina = 1.0 - 0.55 * max(0.0, -y)      # rabo mais fino
        v.co = Vector((v.co.x * 0.032 * afina, y * 0.15, v.co.z * 0.042 * afina))
    corpo = bm_object(coll, bm, "corpo", barriga)
    corpo.data.materials.append(costas)
    for f in corpo.data.polygons:
        if f.center.z > 0.004:
            f.material_index = 1
    parts = [corpo]
    # rabo
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in [(0, -0.13, 0), (0, -0.21, 0.05), (0, -0.19, 0.0), (0, -0.21, -0.05)]]
    bm.faces.new(vs)
    parts.append(bm_object(coll, bm, "rabo", nadadeira))
    # nadadeiras dorsais
    for y0, alt in ((0.03, 0.035), (-0.06, 0.025)):
        bm = bmesh.new()
        vs = [bm.verts.new(v) for v in [(0, y0 + 0.03, 0.035), (0, y0 - 0.01, 0.035 + alt), (0, y0 - 0.03, 0.033)]]
        bm.faces.new(vs)
        parts.append(bm_object(coll, bm, "dorsal", nadadeira))
    for sx in (-1, 1):
        parts.append(sphere(coll, (sx * 0.02, 0.1, 0.008), (0.006, 0.006, 0.006), olho_m, "olho", seg=8, rings=6))
    ob = join(parts, "peixe")
    export(ob, "peixe.glb")

peixe()

# ---------------------------------------------------------------- jirau-fogão (fogão suspenso de pau, talo e lama)
# Em 3 partes, para a montagem aparecer por etapas no jogo. Topo da camada de lama a 0,88 m.

def jirau():
    random.seed(61)
    pau = material("pau_verde", (0.38, 0.33, 0.22), 0.85)
    talo = material("talo_mangue", (0.33, 0.36, 0.2), 0.8)
    # 1) quatro pés fincados + travessas
    coll = new_coll("jirau_pes")
    parts = []
    cantos = [(-0.32, -0.28), (0.32, -0.28), (0.32, 0.28), (-0.32, 0.28)]
    for (x, y) in cantos:
        inc = (random.uniform(-0.03, 0.03), random.uniform(-0.03, 0.03))
        parts.append(tube(coll, [(x, y, -0.25), (x + inc[0], y + inc[1], 0.95)], [0.03, 0.026], pau, "pe"))
    for y in (-0.28, 0.28):
        parts.append(tube(coll, [(-0.42, y, 0.74), (0.42, y, 0.75)], [0.024, 0.022], pau, "travessa"))
    ob = join(parts, "jirau_pes")
    export(ob, "jirau_pes.glb")
    # 2) cama de talos atravessados
    coll = new_coll("jirau_talos")
    parts = []
    for i in range(11):
        x = -0.36 + i * 0.072
        parts.append(tube(coll, [(x + random.uniform(-0.01, 0.01), -0.4, 0.79), (x + random.uniform(-0.02, 0.02), 0.4, 0.79 + random.uniform(-0.01, 0.01))], [0.018, 0.016], talo, "talo"))
    ob = join(parts, "jirau_talos")
    export(ob, "jirau_talos.glb")
    # 3) camada de lama por cima (protege a madeira do fogo)
    coll = new_coll("jirau_lama")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=3, use_grid_fill=True)
    for v in bm.verts:
        x, y, z = v.co
        v.co = Vector((x * 0.74 + 0.02 * noise.noise(v.co * 6), y * 0.66 + 0.02 * noise.noise(v.co * 5 + Vector((3, 0, 0))), 0.835 + z * 0.07 + 0.012 * noise.noise(v.co * 9)))
    lama = bm_object(coll, bm, "lama", M_LAMA)
    ob = join([lama], "jirau_lama")
    export(ob, "jirau_lama.glb")

jirau()

# ---------------------------------------------------------------- missão "A rabeta": canoa, motor e peças

def casco(coll, comp, larg, alt, mat, nome, segs=14):
    """Casco aberto de canoa/barco: seções em U ao longo de Y, pontas afinando."""
    bm = bmesh.new()
    perfil = 9
    secs = []
    for i in range(segs + 1):
        t = i / segs
        y = (t - 0.5) * comp
        afina = max(0.03, math.sin(math.pi * t)) ** 0.55
        w = larg * 0.5 * afina
        h = alt * (0.75 + 0.25 * abs(t - 0.5) * 2)
        anel = []
        for k in range(perfil):
            a = math.pi * k / (perfil - 1)
            anel.append(bm.verts.new((math.cos(a) * w * -1, y, h - math.sin(a) * h * max(afina, 0.25) ** 0.3)))
        secs.append(anel)
    for i in range(segs):
        for k in range(perfil - 1):
            bm.faces.new((secs[i][k], secs[i][k + 1], secs[i + 1][k + 1], secs[i + 1][k]))
    ob = bm_object(coll, bm, nome, mat)
    sol = ob.modifiers.new("esp", 'SOLIDIFY'); sol.thickness = 0.035; sol.offset = 0
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg)); ob.modifiers.clear(); ob.data = me
    return ob


def canoa():
    random.seed(71)
    coll = new_coll("canoa")
    madeira = material("madeira_canoa", (0.33, 0.24, 0.16), 0.8)
    faixa = material("faixa_azul", (0.12, 0.3, 0.5), 0.6)
    parts = [casco(coll, 5.2, 1.05, 0.55, madeira, "casco")]
    # borda pintada e bancos
    for sx in (-1, 1):
        parts.append(tube(coll, [(sx * 0.52 * max(0.03, math.sin(math.pi * t)) ** 0.55, (t - 0.5) * 5.2, 0.55 * (0.75 + 0.25 * abs(t - 0.5) * 2)) for t in [i / 14 for i in range(15)]], [0.025] * 15, faixa, "borda"))
    for y in (-1.6, 0.0, 1.4):
        parts.append(box(coll, (0, y, 0.33), (0.85, 0.22, 0.04), madeira, "banco"))
    # suporte do motor na popa (-Y)
    parts.append(box(coll, (0, -2.45, 0.5), (0.3, 0.12, 0.2), madeira, "suporte"))
    ob = join(parts, "canoa")
    export(ob, "canoa.glb")
    # remendo (aparece depois de tapar o furo)
    coll2 = new_coll("remendo")
    rem = box(coll2, (0.38, 0.6, 0.22), (0.04, 0.35, 0.22), material("breu", (0.03, 0.03, 0.03), 0.3), "remendo", rot=(0, 0.35, 0))
    export(join([rem], "remendo"), "remendo.glb")


def motor_rabeta():
    coll = new_coll("motor_rabeta")
    verm = material("motor_vermelho", (0.55, 0.08, 0.05), 0.45)
    metal = material("metal_motor", (0.45, 0.45, 0.46), 0.4, 0.9)
    preto = material("preto_motor", (0.05, 0.05, 0.05), 0.6)
    parts = [box(coll, (0, 0, 0.18), (0.32, 0.38, 0.3), verm, "bloco")]
    parts.append(cylinder(coll, (0, 0.12, 0.32), 0.09, 0.09, 0.08, metal, "tampa"))
    parts.append(box(coll, (0.0, -0.05, 0.38), (0.22, 0.2, 0.08), preto, "tanque"))
    # rabeta: eixo longo para trás (-Y) e para baixo
    parts.append(tube(coll, [(0, -0.15, 0.1), (0, -1.0, -0.12), (0, -1.6, -0.3)], [0.025, 0.022, 0.02], metal, "eixo"))
    # cabo de pilotar para frente (+Y)
    parts.append(tube(coll, [(0, 0.15, 0.25), (0, 0.9, 0.42)], [0.018, 0.016], metal, "cabo"))
    parts.append(tube(coll, [(0, 0.85, 0.41), (0, 1.0, 0.45)], [0.03, 0.03], preto, "punho"))
    ob = join(parts, "motor_rabeta")
    export(ob, "motor_rabeta.glb")


def helice():
    coll = new_coll("helice")
    metal = material("bronze", (0.55, 0.42, 0.2), 0.35, 0.9)
    parts = [cylinder(coll, (0, 0, -0.04), 0.03, 0.03, 0.08, metal, "cubo")]
    for i in range(3):
        a = i / 3 * math.tau
        bm = bmesh.new()
        vs = [bm.verts.new(v) for v in [(0.02, 0, -0.02), (0.13, 0.03, 0.0), (0.12, -0.03, 0.02), (0.02, 0, 0.02)]]
        bm.faces.new(vs)
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(a, 3, 'Z'))
        parts.append(bm_object(coll, bm, "pa", metal))
    ob = join(parts, "helice")
    export(ob, "helice.glb")


def remo():
    coll = new_coll("remo")
    parts = [tube(coll, [(0, -0.8, 0.03), (0, 0.5, 0.03)], [0.022, 0.02], M_MADEIRA, "cabo")]
    parts.append(box(coll, (0, 0.72, 0.03), (0.16, 0.45, 0.025), M_MADEIRA, "pa"))
    ob = join(parts, "remo")
    export(ob, "remo.glb")


def cuia():
    coll = new_coll("cuia")
    m = material("cabaca", (0.5, 0.36, 0.18), 0.6)
    c = cylinder(coll, (0, 0, 0), 0.06, 0.1, 0.07, m, "cuia", seg=18, cap_top=False)
    mod = c.modifiers.new("e", 'SOLIDIFY'); mod.thickness = 0.006
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(c.evaluated_get(dg)); c.modifiers.clear(); c.data = me
    export(join([c], "cuia"), "cuia.glb")


def galao():
    coll = new_coll("galao")
    m = material("galao_azul", (0.15, 0.3, 0.6), 0.4)
    corpo = box(coll, (0, 0, 0.18), (0.22, 0.14, 0.34), m, "corpo")
    bev = corpo.modifiers.new("b", 'BEVEL'); bev.width = 0.025; bev.segments = 2
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(corpo.evaluated_get(dg)); corpo.modifiers.clear(); corpo.data = me
    tampa = cylinder(coll, (0.06, 0, 0.35), 0.025, 0.025, 0.04, material("tampa_amarela", (0.8, 0.65, 0.1), 0.5), "tampa")
    alca = tube(coll, [(-0.06, 0, 0.35), (-0.04, 0, 0.4), (0.02, 0, 0.4), (0.03, 0, 0.35)], [0.012] * 4, m, "alca")
    export(join([corpo, tampa, alca], "galao"), "galao.glb")


def lata_breu():
    coll = new_coll("lata_breu")
    lata = cylinder(coll, (0, 0, 0), 0.08, 0.08, 0.14, material("lata", (0.4, 0.38, 0.33), 0.5, 0.7), "lata")
    breu = cylinder(coll, (0, 0, 0.13), 0.075, 0.075, 0.015, material("breu", (0.03, 0.03, 0.03), 0.3), "breu")
    estopa = ico(coll, (0.12, 0.02, 0.04), (0.06, 0.05, 0.04), M_CORDA, "estopa", rough=0.4)
    export(join([lata, breu, estopa], "lata_breu"), "lata_breu.glb")


def barco_abandonado():
    random.seed(83)
    coll = new_coll("barco_abandonado")
    casco_m = material("casco_velho", (0.28, 0.2, 0.15), 0.9)
    tinta = material("tinta_velha", (0.32, 0.36, 0.34), 0.9)
    parts = [casco(coll, 12.0, 3.6, 2.2, casco_m, "casco", segs=18)]
    # convés parcial e cabine quebrada
    parts.append(box(coll, (0, 3.2, 1.9), (3.0, 4.0, 0.08), tinta, "conves"))
    for x, y, w, d, h in ((0, 3.0, 2.2, 0.08, 1.5), (-1.1, 3.8, 0.08, 1.6, 1.5), (1.1, 3.8, 0.08, 1.6, 1.2)):
        parts.append(box(coll, (x, y, 1.9 + h / 2), (w, d, h), tinta, "cabine"))
    # costelas expostas no buraco da popa
    for y in (-4.8, -4.0, -3.2):
        parts.append(tube(coll, [(-1.6, y, 1.8), (-1.2, y, 0.4), (0, y, 0.15), (1.2, y, 0.4), (1.6, y, 1.8)], [0.06] * 5, casco_m, "costela"))
    ob = join(parts, "barco_abandonado")
    export(ob, "barco_abandonado.glb")


def bancada():
    coll = new_coll("bancada")
    parts = [box(coll, (0, 0, 0.82), (1.4, 0.6, 0.06), M_MADEIRA, "tampo")]
    for x in (-0.62, 0.62):
        for y in (-0.24, 0.24):
            parts.append(box(coll, (x, y, 0.4), (0.06, 0.06, 0.8), M_MADEIRA_ESC, "pe"))
    parts.append(box(coll, (0, 0, 0.25), (1.3, 0.5, 0.03), M_MADEIRA_ESC, "prateleira"))
    export(join(parts, "bancada"), "bancada.glb")


def bacia():
    coll = new_coll("bacia")
    """Bacia de alumínio com fundo, borda enrolada e uns amassados, em cima de dois tijolos
    (assim o chão irregular não atravessa o fundo). O jogo põe a água em oficina.gd:
    fundo de dentro em z = BASE + 0.006, borda em z = BASE + 0.15 (raio 0.20 -> 0.30)."""
    random.seed(5)
    coll = new_coll("bacia")
    m = material("bacia_aluminio", (0.62, 0.62, 0.64), 0.45, 0.85)
    BASE = 0.09
    # perfil (raio, altura): por dentro, sobe, enrola a borda, desce por fora e fecha o fundo
    perfil = [(0.0, 0.006), (0.18, 0.006), (0.215, 0.015), (0.235, 0.035), (0.300, 0.148),
              (0.310, 0.162), (0.325, 0.167), (0.336, 0.159), (0.335, 0.148), (0.322, 0.144),
              (0.305, 0.141), (0.240, 0.031), (0.219, 0.009), (0.18, 0.0), (0.0, 0.0)]
    bm = bmesh.new()
    vs = [bm.verts.new((r, 0, z + BASE)) for r, z in perfil]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    bmesh.ops.spin(bm, geom=vs + es, axis=(0, 0, 1), cent=(0, 0, 0), steps=36, angle=math.tau, use_duplicate=False)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    for v in bm.verts:   # amassados: empurra a parede junto (dentro e fora andam iguais)
        if v.co.z > BASE + 0.03:
            v.co.x *= 1 + 0.025 * noise.noise(Vector((v.co.x * 9, v.co.y * 9, 3.1)))
            v.co.y *= 1 + 0.025 * noise.noise(Vector((v.co.x * 9, v.co.y * 9, 3.1)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    parts = [bm_object(coll, bm, "bacia", m)]
    tijolo = material("tijolo", (0.52, 0.24, 0.14), 0.95)
    for y in (-0.12, 0.12):
        parts.append(box(coll, (random.uniform(-0.02, 0.02), y, BASE / 2), (0.40, 0.11, BASE), tijolo, "tijolo", rot=(0, 0, random.uniform(-0.08, 0.08))))
    export(join(parts, "bacia"), "bacia.glb")



def tarrafa():
    coll = new_coll("tarrafa")
    rede = material("rede_tarrafa", (0.75, 0.75, 0.7), 0.8)
    chumbo = material("chumbo", (0.25, 0.25, 0.27), 0.5, 0.8)
    # rede recolhida: um monte em cone com dobras
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=0.25, radius2=0.04, depth=0.45)
    for v in bm.verts:
        v.co.x *= 1 + 0.12 * noise.noise(v.co * 8)
        v.co.y *= 1 + 0.12 * noise.noise(v.co * 8 + Vector((2, 0, 0)))
    bmesh.ops.translate(bm, vec=(0, 0, 0.225), verts=bm.verts)
    monte = bm_object(coll, bm, "monte", rede)
    parts = [monte]
    for i in range(14):
        a = i / 14 * math.tau
        parts.append(sphere(coll, (math.cos(a) * 0.26, math.sin(a) * 0.26, 0.02), (0.018, 0.018, 0.018), chumbo, "chumbo", seg=6, rings=4))
    parts.append(tube(coll, [(0, 0, 0.45), (0.05, 0.1, 0.55), (0.15, 0.15, 0.5)], [0.006] * 3, M_CORDA, "corda"))
    export(join(parts, "tarrafa"), "tarrafa.glb")

tarrafa()
canoa()
motor_rabeta()
helice()
remo()
cuia()
galao()
lata_breu()
barco_abandonado()
bancada()
bacia()


# ---------------------------------------------------------------- homenagem ao mangue geral: parabólica e palafita

def parabolica():
    """Parabólica fincada no mangue (homenagem ao mangue beat): torre enferrujada com plataforma,
    pés de aço e pés que viraram raiz de mangue, cravados num monte de lama. ~7 m de altura."""
    random.seed(101)
    coll = new_coll("parabolica")
    metal = material("parabolica_metal", (0.62, 0.6, 0.56), 0.5, 0.6)
    aco = material("aco_torre", (0.4, 0.3, 0.24), 0.6, 0.5)
    parts = []
    # monte de lama em volta da base
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=36, radius1=3.2, radius2=0.5, depth=1.3)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=3, use_grid_fill=True)
    for v in bm.verts:
        v.co.z += 0.65
        v.co.z += 0.18 * noise.noise(v.co * 1.3) + 0.05 * noise.noise(v.co * 6)
        v.co.x *= 1 + 0.1 * noise.noise(v.co * 0.8 + Vector((5, 0, 0)))
        v.co.y *= 1 + 0.1 * noise.noise(v.co * 0.8 + Vector((0, 5, 0)))
    parts.append(bm_object(coll, bm, "monte", M_LAMA))
    # coluna central e plataforma com guarda-corpo
    parts.append(cylinder(coll, (0, 0, 0.6), 0.42, 0.36, 3.4, aco, "coluna", seg=20))
    parts.append(cylinder(coll, (0, 0, 2.6), 0.55, 0.55, 0.18, aco, "anel"))
    parts.append(cylinder(coll, (0, 0, 4.0), 1.15, 1.15, 0.1, aco, "plataforma", seg=24))
    for i in range(12):
        a = i / 12 * math.tau
        parts.append(tube(coll, [(math.cos(a) * 1.1, math.sin(a) * 1.1, 4.1), (math.cos(a) * 1.1, math.sin(a) * 1.1, 4.75)], [0.025] * 2, aco, "grade"))
    parts.append(tube(coll, [(math.cos(a) * 1.1, math.sin(a) * 1.1, 4.75) for a in [i / 24 * math.tau for i in range(25)]], [0.03] * 25, aco, "corrimao", caps=False))
    # pés: dois de aço (retos, com sapata) e dois que viraram raiz (curvos, casca)
    for k, ang in enumerate((0.6, 2.2, 3.8, 5.3)):
        topo = Vector((math.cos(ang) * 0.4, math.sin(ang) * 0.4, 2.7))
        pe = Vector((math.cos(ang) * 2.4, math.sin(ang) * 2.4, 0.15))
        if k % 2 == 0:
            parts.append(tube(coll, [topo, pe], [0.09, 0.08], aco, "pe_aco", sides=2))
            parts.append(cylinder(coll, tuple(pe - Vector((0, 0, 0.1))), 0.18, 0.18, 0.12, aco, "sapata"))
        else:
            meio = topo.lerp(pe, 0.5) + Vector((math.cos(ang) * 0.4, math.sin(ang) * 0.4, 0.5))
            pts = bezier_pts(topo, meio, pe + Vector((math.cos(ang) * 0.4, math.sin(ang) * 0.4, -0.4)), 10)
            parts.append(tube(coll, pts, lerp_radii(0.12, 0.07, len(pts)), M_RAIZ, "pe_raiz", sides=2))
            # raízes finas que saem do pé-raiz
            for r in range(3):
                s0 = pts[3 + r * 2]
                a2 = ang + random.uniform(-0.9, 0.9)
                e2 = s0 + Vector((math.cos(a2) * 1.0, math.sin(a2) * 1.0, -s0.z - 0.3))
                pts2 = bezier_pts(s0, s0.lerp(e2, 0.5) + Vector((0, 0, 0.3)), e2, 7)
                parts.append(tube(coll, pts2, lerp_radii(0.04, 0.025, len(pts2)), M_RAIZ, "raizinha"))
    # raízes de mangue abraçando a coluna
    for r in range(5):
        a0 = r / 5 * math.tau + 0.3
        pts = []
        for t in range(10):
            f = t / 9
            aa = a0 + f * 2.2
            raio = 0.42 + f * 1.4
            pts.append(Vector((math.cos(aa) * raio, math.sin(aa) * raio, 2.0 - f * 2.0 + 0.2 * math.sin(f * math.pi))))
        parts.append(tube(coll, pts, lerp_radii(0.05, 0.035, len(pts)), M_RAIZ, "raiz_coluna"))
    # garfo e prato grande, inclinado para o céu
    parts.append(box(coll, (0, 0, 4.4), (0.7, 0.4, 0.6), aco, "cabeca"))
    for sx in (-0.45, 0.45):
        parts.append(tube(coll, [(sx, 0, 4.5), (sx, 0.3, 5.3)], [0.06, 0.06], aco, "garfo"))
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=1.0)
    for v in list(bm.verts):
        if v.co.z > -0.45:
            bm.verts.remove(v)
    for v in bm.verts:
        v.co = Vector((v.co.x * 2.6, v.co.y * 2.6, (v.co.z + 1.0) * 1.2))
    prato = bm_object(coll, bm, "prato", metal)
    m = prato.modifiers.new("esp", 'SOLIDIFY'); m.thickness = 0.03
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(prato.evaluated_get(dg)); prato.modifiers.clear(); prato.data = me
    prato.data.materials.append(material("ferrugem", (0.42, 0.2, 0.08), 0.8))
    for f in prato.data.polygons:
        if noise.noise(f.center * 1.5) > 0.05:
            f.material_index = 1
    R = Matrix.Translation((0, 0.5, 5.2)) @ Matrix.Rotation(math.radians(-48), 4, 'X')
    prato.data.transform(R)
    parts.append(prato)
    # aro do prato
    parts.append(tube(coll, [R @ Vector((math.cos(a) * 2.42, math.sin(a) * 2.42, 0.66)) for a in [i / 40 * math.tau for i in range(41)]], [0.04] * 41, aco, "aro", caps=False))
    # receptor no foco, preso por 3 hastes
    foco = R @ Vector((0, 0, 2.3))
    for a in (0.0, 2.1, 4.2):
        base = R @ Vector((math.cos(a) * 2.2, math.sin(a) * 2.2, 0.55))
        parts.append(tube(coll, [base, foco], [0.03, 0.025], aco, "haste"))
    parts.append(cylinder(coll, tuple(foco - Vector((0, 0, 0.15))), 0.1, 0.12, 0.35, aco, "receptor"))
    export(join(parts, "parabolica"), "parabolica.glb")


def palafita():
    """Casinha de tábua sobre estacas na beira do mangue. Piso a 3,0 m do chão de lama."""
    random.seed(97)
    coll = new_coll("palafita")
    parts = []
    W, D, piso, alt = 3.6, 3.0, 3.0, 2.0
    tabua_cores = [material("tabua_azul", (0.2, 0.34, 0.45), 0.85), material("tabua_verde", (0.25, 0.4, 0.3), 0.85), M_MADEIRA, material("tabua_rosa", (0.55, 0.32, 0.32), 0.85)]
    # estacas
    for x in (-W / 2, 0, W / 2):
        for y in (-D / 2, D / 2):
            parts.append(tube(coll, [(x, y, -1.0), (x + random.uniform(-0.05, 0.05), y, piso)], [0.09, 0.08], M_MADEIRA_ESC, "estaca", sides=2))
    # assoalho e varanda na frente (-Y)
    for i in range(12):
        x = -W / 2 + (i + 0.5) * W / 12
        parts.append(box(coll, (x, -0.6, piso), (W / 12 - 0.02, D + 1.2, 0.05), M_MADEIRA, "piso"))
    # paredes de tábuas coloridas (fundo e lados; frente com porta)
    def parede(x0, y0, x1, y1, porta=None):
        L = math.hypot(x1 - x0, y1 - y0)
        n = int(L / 0.2)
        ang = math.atan2(y1 - y0, x1 - x0)
        for i in range(n):
            t = (i + 0.5) / n
            if porta and porta[0] < t < porta[1]:
                continue
            h = alt + random.uniform(-0.04, 0.04)
            parts.append(box(coll, (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, piso + h / 2), (0.19, 0.03, h), tabua_cores[(i // 3) % 4], "tabua", rot=(0, 0, ang)))
    parede(-W / 2, D / 2, W / 2, D / 2)
    parede(-W / 2, -D / 2, -W / 2, D / 2)
    parede(W / 2, -D / 2, W / 2, D / 2)
    parede(-W / 2, -D / 2, W / 2, -D / 2, porta=(0.4, 0.62))
    # telhado de telha/zinco em uma água
    zinco = material("zinco", (0.5, 0.5, 0.5), 0.5, 0.8)
    parts.append(box(coll, (0, -0.3, piso + alt + 0.3), (W + 0.6, D + 1.6, 0.04), zinco, "telhado", rot=(math.radians(10), 0, 0)))
    # guarda-corpo da varanda
    for x in (-W / 2, W / 2):
        parts.append(tube(coll, [(x, -D / 2, piso + 0.9), (x, -D / 2 - 1.2, piso + 0.9)], [0.025] * 2, M_MADEIRA_ESC, "corrimao"))
    # escada de pau até a lama
    for k in range(9):
        z = piso - 0.33 * (k + 1)
        y = -D / 2 - 1.2 - 0.22 * (k + 1)
        parts.append(box(coll, (0, y, z), (0.8, 0.22, 0.04), M_MADEIRA, "degrau"))
    for x in (-0.42, 0.42):
        parts.append(tube(coll, [(x, -D / 2 - 1.2, piso), (x, -D / 2 - 1.2 - 2.2, piso - 3.2)], [0.04] * 2, M_MADEIRA_ESC, "banzo"))
    export(join(parts, "palafita"), "palafita.glb")


parabolica()
palafita()

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BASE, "blender", "mangue_assets.blend"))
print("ASSETS OK:", sorted(f for f in os.listdir(ASSETS) if f.endswith(".glb")))
