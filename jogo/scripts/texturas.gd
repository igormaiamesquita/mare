extends Node
## Troca os materiais lisos dos modelos do Blender por materiais com textura real (Poly Haven, CC0).
## Funciona sozinho: todo modelo que entra na cena é conferido pelo nome do material.
## Usa projeção "triplanar" (não precisa de UV no modelo).

const T := "res://assets/texturas/"

# nome do material no Blender -> [textura, tamanho em metros, tom (multiplica a cor)]
const MAPA := {
	"casca_mangue": ["bark_willow", 1.0, Color(0.85, 0.75, 0.7)],
	"casca_clara": ["bark_willow", 1.0, Color(1.25, 1.2, 1.1)],
	"raiz_mangue": ["bark_willow", 0.8, Color(0.7, 0.6, 0.55)],
	"madeira_rancho": ["weathered_planks", 1.6, Color(1.0, 0.95, 0.9)],
	"madeira_escura": ["weathered_planks", 1.6, Color(0.65, 0.58, 0.52)],
	"lenha": ["bark_willow", 0.6, Color(1.1, 1.0, 0.9)],
	"pau_verde": ["bark_willow", 0.6, Color(1.0, 1.0, 0.85)],
	"madeira_canoa": ["weathered_planks", 2.4, Color(0.9, 0.8, 0.7)],
	"palha": ["thatch_roof_angled", 1.4, Color(1.1, 1.05, 0.95)],
	"palha_escura": ["thatch_roof_angled", 1.4, Color(0.8, 0.75, 0.68)],
	"tabua_azul": ["old_planks_02", 2.0, Color(0.55, 0.85, 1.25)],
	"tabua_verde": ["old_planks_02", 2.0, Color(0.7, 1.2, 0.8)],
	"tabua_rosa": ["old_planks_02", 2.0, Color(1.4, 0.8, 0.8)],
	"lama": ["brown_mud_03", 2.0, Color(0.6, 0.55, 0.5)],
	"casco_velho": ["old_planks_02", 1.8, Color(0.8, 0.72, 0.65)],
	"tinta_velha": ["rusty_metal_02", 2.0, Color(0.7, 0.8, 0.78)],
	"ferrugem": ["rusty_metal_02", 1.6, Color(1, 1, 1)],
	"aco_torre": ["rusty_metal_02", 1.2, Color(0.75, 0.62, 0.55)],
	"parabolica_metal": ["rusty_metal_02", 1.2, Color(1, 1, 1)],
	"zinco": ["rusty_metal_02", 1.5, Color(0.85, 0.85, 0.85)],
	"lata": ["rusty_metal_02", 0.4, Color(1, 1, 1)],
}

var _cache := {}


func _ready() -> void:
	get_tree().node_added.connect(_no_novo)


func material(nome: String) -> Material:
	if not MAPA.has(nome):
		return null
	if _cache.has(nome):
		return _cache[nome]
	var info: Array = MAPA[nome]
	var pasta: String = T + info[0] + "/"
	var m := StandardMaterial3D.new()
	m.resource_name = nome
	m.albedo_texture = load(pasta + "cor.jpg")
	m.albedo_color = info[2]
	m.normal_enabled = true
	m.normal_texture = load(pasta + "normal.jpg")
	m.roughness_texture = load(pasta + "rugosidade.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	if nome.begins_with("ferrugem") or nome in ["parabolica_metal", "lata", "zinco"]:
		m.metallic = 0.35
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	var k := 1.0 / float(info[1])
	m.uv1_scale = Vector3(k, k, k)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[nome] = m
	return m


## Troca os materiais de uma malha (serve para MultiMesh, que é compartilhada).
func aplicar_malha(malha: Mesh) -> void:
	if malha == null:
		return
	for i in malha.get_surface_count():
		var orig := malha.surface_get_material(i)
		if orig != null:
			var novo := material(orig.resource_name)
			if novo != null:
				malha.surface_set_material(i, novo)


## Faz uma árvore de nós sumir de longe (economiza muito: cada objeto desenhado custa).
static func alcance(n: Node, metros: float) -> void:
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		if g.visibility_range_end == 0.0:
			g.visibility_range_end = metros
			g.visibility_range_end_margin = metros * 0.1
			g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for c in n.get_children():
		alcance(c, metros)


func _no_novo(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.material_override != null or mi.mesh == null:
			return
		for i in mi.mesh.get_surface_count():
			var orig := mi.mesh.surface_get_material(i)
			if orig != null:
				var novo := material(orig.resource_name)
				if novo != null:
					mi.set_surface_override_material(i, novo)
	# MultiMesh (árvores, mudas, capim: milhares de cópias) fica com material simples: textura nelas pesa demais
