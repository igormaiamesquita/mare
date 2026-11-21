extends Node3D
## Monta o mundo do MVP: chão, água com maré, céu com dia e noite, mangue, rancho, fogão, tocas e caranguejos.

const A := "res://assets/"

var rng := RandomNumberGenerator.new()
var sol: DirectionalLight3D
var lua: DirectionalLight3D
var ambiente: Environment
var ceu: ShaderMaterial
var agua_mat: ShaderMaterial
var chuva_fx: GPUParticles3D
var _molhado := 0.0
var _relampago := 0.0
var corpo_chao: StaticBody3D
var _alturas := PackedFloat32Array()
var mapa_alt: ImageTexture
var mapa_cor: ImageTexture
var terreno_mat: ShaderMaterial
var agua: MeshInstance3D
var jogador
var hud
var missoes
var tutorial
var fogao
var tocas: Array = []
var arvores: Array[Vector3] = []
var pos_rancho := Vector3.ZERO
var pos_spawn := Vector3.ZERO
var _ultima_hora := 0.0
var _relogio_bichos := 0.0
var _andantes: Node3D
var peixes: Node3D
var pocas: Array = []
var barco          # missão "Parabólica na Lama"
var salvador
var cultura
var itens_iniciais := {}       # uid -> item criado na montagem do mundo (para o save)
var _n_itens := 0
var _montando := true
var bacia
var bancada


func _ready() -> void:
	rng.seed = 2026
	seed(2026)
	_qualidade()
	_ambiente()
	_terreno()
	_agua()
	_rancho()
	_vegetacao()
	_criar_mapa()
	_tocas()
	_oficina()
	_criar_chuva()
	var ar := Node3D.new()
	ar.set_script(load("res://scripts/aratus.gd"))
	ar.main = self
	add_child(ar)
	peixes = Node3D.new()
	peixes.set_script(load("res://scripts/peixes.gd"))
	peixes.main = self
	add_child(peixes)
	for d in Terreno.pocas():
		var p := Node3D.new()
		p.set_script(load("res://scripts/poca.gd"))
		p.main = self
		p.dados = d
		add_child(p)
		pocas.append(p)
	_andantes = Node3D.new()
	add_child(_andantes)
	salvador = Node.new()
	salvador.set_script(load("res://scripts/salvar.gd"))
	salvador.main = self
	add_child(salvador)
	_jogador()
	_ultima_hora = Mundo.tempo_total()
	barco = Node.new()
	barco.set_script(load("res://scripts/missao_barco.gd"))
	barco.main = self
	add_child(barco)
	barco.montar()
	cultura = Node.new()
	cultura.set_script(load("res://scripts/cultura.gd"))
	cultura.main = self
	add_child(cultura)
	cultura.montar()
	# telhados: a chuva não entra no rancho nem na palafita
	telhado_seco(pos_rancho + Vector3(0, 3.0, 0), Vector3(5.2, 1.6, 4.8))
	telhado_seco(cultura.palafita_pos + Vector3(0, 5.25, -0.3), Vector3(4.6, 0.9, 5.0))
	# galochas no rancho (criadas por último para não mudar a numeração dos itens dos jogos salvos)
	# do lado de fora, ao lado da porta (bota de lama não entra em casa)
	var pg := pos_rancho + Vector3(1.0, 0, 2.15)
	pg.y = Terreno.altura(pg.x, pg.z)
	var gal := criar_item("galochas", pg)
	gal.rotation.y = 0.4
	_montando = false
	Config.aplicar()
	_debug()


## Em tela grande (retina/4K) desenha o 3D menor e amplia com FSR: mesmo visual, bem mais leve.
func _qualidade() -> void:
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	ajustar_escala()
	vp.size_changed.connect(ajustar_escala)


## Escala do 3D: fixa (Configurações) ou automática pelo tamanho da tela.
func ajustar_escala() -> void:
	var vp := get_viewport()
	if Config.escala_fixa() > 0.0:
		vp.scaling_3d_scale = Config.escala_fixa()
		return
	var largura := float(vp.get_visible_rect().size.x)
	var real := float(DisplayServer.window_get_size().x)
	vp.scaling_3d_scale = clampf(1500.0 / maxf(real, largura), 0.4, 1.0)


# ------------------------------------------------------------------ céu e luz

func _ambiente() -> void:
	var we := WorldEnvironment.new()
	ambiente = Environment.new()
	ambiente.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	ceu = ShaderMaterial.new()
	ceu.shader = load("res://shaders/ceu.gdshader")
	ceu.set_shader_parameter("ruido", _ruido_tex(0.008, false, 11))
	sky.sky_material = ceu
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	ambiente.sky = sky
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	ambiente.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	ambiente.ambient_light_sky_contribution = 0.55
	ambiente.tonemap_mode = Environment.TONE_MAPPER_AGX
	ambiente.ssao_enabled = false   # custava ~8 fps; a diferença visual é pequena
	ambiente.ssao_radius = 1.2
	ambiente.ssao_intensity = 1.6
	ambiente.glow_enabled = true
	ambiente.glow_intensity = 0.4
	ambiente.glow_bloom = 0.04
	ambiente.fog_enabled = true
	ambiente.fog_density = 0.006
	ambiente.fog_sun_scatter = 0.25
	ambiente.fog_aerial_perspective = 0.35
	ambiente.adjustment_enabled = true
	ambiente.adjustment_saturation = 1.12
	ambiente.adjustment_contrast = 1.06
	we.environment = ambiente
	add_child(we)

	sol = DirectionalLight3D.new()
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 50.0
	sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sol.directional_shadow_blend_splits = true
	sol.light_angular_distance = 0.6
	add_child(sol)
	lua = DirectionalLight3D.new()
	lua.light_color = Color(0.55, 0.65, 1.0)
	lua.shadow_enabled = true
	lua.directional_shadow_max_distance = 40.0
	lua.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(lua)


func _luz() -> void:
	var e := Mundo.altura_sol()
	var ang := (Mundo.hora - 6.0) / 12.0 * PI
	var dir_sol := Vector3(cos(ang), sin(ang), 0.35).normalized()   # aponta para o sol (nasce a leste)
	sol.look_at_from_position(Vector3.ZERO, -dir_sol, Vector3.UP)
	var nuv := Mundo.nuvens
	var chu := Mundo.chuva
	var cobertura := smoothstep(0.55, 1.0, nuv)            # céu fechado tira a sombra do sol
	var dia := smoothstep(-0.08, 0.25, e)
	sol.light_energy = dia * 1.5 * (1.0 - cobertura * 0.75)
	sol.visible = e > -0.12
	sol.shadow_opacity = 1.0 - cobertura * 0.7
	sol.light_color = Color(1.0, 0.6, 0.36).lerp(Color(1.0, 0.96, 0.9), smoothstep(0.0, 0.45, e))
	# a lua fica "atrás" do sol conforme a fase: cheia = do lado oposto
	var ang_l := ang - Mundo.fase_lua() * TAU
	var dir_lua := Vector3(cos(ang_l), sin(ang_l), -0.3).normalized()
	lua.look_at_from_position(Vector3.ZERO, -dir_lua, Vector3.UP)
	lua.light_energy = (1.0 - dia) * (0.12 + 0.45 * Mundo.luz_lua()) * (1.0 - cobertura * 0.7)
	lua.visible = dir_lua.y > 0.05 and lua.light_energy > 0.01
	var crep := clampf(1.0 - absf(e) / 0.3, 0.0, 1.0)
	var cinza := Color(0.45, 0.47, 0.5)
	var topo := Color(0.012, 0.018, 0.045).lerp(Color(0.24, 0.44, 0.74), dia).lerp(cinza * maxf(dia, 0.08), cobertura * 0.85)
	var horizonte := Color(0.03, 0.04, 0.07).lerp(Color(0.68, 0.74, 0.8), dia).lerp(Color(0.95, 0.6, 0.4), crep * 0.35 * (1.0 - cobertura))
	horizonte = horizonte.lerp(cinza * maxf(dia, 0.08) * 1.1, cobertura * 0.8)
	ceu.set_shader_parameter("cor_topo", topo)
	ceu.set_shader_parameter("cor_horizonte", horizonte)
	ceu.set_shader_parameter("dir_sol", dir_sol)
	ceu.set_shader_parameter("dir_lua", dir_lua)
	ceu.set_shader_parameter("cor_sol", sol.light_color)
	ceu.set_shader_parameter("fase_lua", Mundo.fase_lua())
	ceu.set_shader_parameter("luz_dia", dia)
	ceu.set_shader_parameter("nuvens", nuv)
	ceu.set_shader_parameter("chuva", chu)
	var relampago := _relampago
	ambiente.ambient_light_energy = lerpf(0.34, 1.0, dia) * (1.0 - chu * 0.35) + relampago * 3.0
	ambiente.ambient_light_color = Color(0.55, 0.5, 0.42).lerp(Color(0.25, 0.3, 0.45), 1.0 - dia).lerp(Color(0.45, 0.48, 0.52), cobertura * 0.6)
	ambiente.fog_light_color = horizonte.darkened(0.1)
	var neblina_manha := crep * 0.007 if Mundo.hora < 12.0 else 0.0
	ambiente.fog_density = lerpf(0.011, 0.0045, dia) + neblina_manha + chu * 0.02
	terreno_mat.set_shader_parameter("chuva", _molhado)
	agua_mat.set_shader_parameter("chuva", chu)


# ------------------------------------------------------------------ chuva

func _criar_chuva() -> void:
	chuva_fx = GPUParticles3D.new()
	chuva_fx.amount = 9000
	chuva_fx.lifetime = 1.1
	chuva_fx.visibility_aabb = AABB(Vector3(-25, -20, -25), Vector3(50, 40, 50))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(22, 0.5, 22)
	m.direction = Vector3(0.12, -1, 0.05)
	m.spread = 2.0
	m.initial_velocity_min = 16.0
	m.initial_velocity_max = 20.0
	m.gravity = Vector3(0, -9.8, 0)
	# gota que bate num telhado some (ver telhado_seco)
	m.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	chuva_fx.collision_base_size = 0.02
	chuva_fx.process_material = m
	var gota := QuadMesh.new()
	gota.size = Vector2(0.012, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.8, 0.85, 0.9, 0.32)
	gota.material = mat
	chuva_fx.draw_pass_1 = gota
	chuva_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chuva_fx.emitting = false
	add_child(chuva_fx)


## Caixa invisível que apaga as gotas de chuva (telhado).
func telhado_seco(centro: Vector3, tamanho: Vector3) -> void:
	var c := GPUParticlesCollisionBox3D.new()
	c.size = tamanho
	c.position = centro
	add_child(c)


func _tempo(delta: float) -> void:
	var chu := Mundo.chuva
	if jogador != null:
		chuva_fx.global_position = jogador.global_position + Vector3(0, 14, 0)
	chuva_fx.emitting = chu > 0.02
	chuva_fx.amount_ratio = clampf(chu, 0.05, 1.0)
	# o chão vai encharcando com a chuva e seca devagar
	_molhado = move_toward(_molhado, chu, delta * (0.08 if chu > _molhado else 0.01))
	# relâmpago no temporal
	_relampago = maxf(0.0, _relampago - delta * 4.0)
	if chu > 0.75 and Mundo.rodando and randf() < delta * 0.06:
		_relampago = 1.0
		Mundo.avisar("Trovão! Temporal no mangue.")


# ------------------------------------------------------------------ chão

func _terreno() -> void:
	var M := Terreno.METADE
	var N := M * 2 + 1
	var alturas := PackedFloat32Array()
	alturas.resize(N * N)
	var verts := PackedVector3Array()
	verts.resize(N * N)
	var cores := PackedColorArray()
	cores.resize(N * N)
	for iz in N:
		for ix in N:
			var x := float(ix - M)
			var z := float(iz - M)
			var h := Terreno.altura(x, z)
			var i := iz * N + ix
			alturas[i] = h
			verts[i] = Vector3(x, h, z)
			var cz := Terreno.zona(x, z, h)
			cz.a = Terreno.mole(x, z)
			cores[i] = cz
	var normais := PackedVector3Array()
	normais.resize(N * N)
	var tangentes := PackedFloat32Array()
	tangentes.resize(N * N * 4)
	for iz in N:
		for ix in N:
			var i := iz * N + ix
			var hl := alturas[iz * N + maxi(ix - 1, 0)]
			var hr := alturas[iz * N + mini(ix + 1, N - 1)]
			var hu := alturas[maxi(iz - 1, 0) * N + ix]
			var hd := alturas[mini(iz + 1, N - 1) * N + ix]
			normais[i] = Vector3(hl - hr, 2.0, hu - hd).normalized()
			var t := Vector3(2.0, hr - hl, 0.0).normalized()
			tangentes[i * 4] = t.x
			tangentes[i * 4 + 1] = t.y
			tangentes[i * 4 + 2] = t.z
			tangentes[i * 4 + 3] = 1.0
	var indices := PackedInt32Array()
	indices.resize((N - 1) * (N - 1) * 6)
	var k := 0
	for iz in N - 1:
		for ix in N - 1:
			var i := iz * N + ix
			indices[k] = i
			indices[k + 1] = i + 1
			indices[k + 2] = i + N
			indices[k + 3] = i + 1
			indices[k + 4] = i + N + 1
			indices[k + 5] = i + N
			k += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normais
	arr[Mesh.ARRAY_TANGENT] = tangentes
	arr[Mesh.ARRAY_COLOR] = cores
	arr[Mesh.ARRAY_INDEX] = indices
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	terreno_mat = ShaderMaterial.new()
	terreno_mat.shader = load("res://shaders/terreno.gdshader")
	terreno_mat.set_shader_parameter("ruido", _ruido_tex(0.012, false, 1))
	var T := "res://assets/texturas/"
	for par in [["lama", "brown_mud_02"], ["mole", "brown_mud_03"], ["areia", "coast_sand_01"], ["firme", "forest_leaves_02"]]:
		terreno_mat.set_shader_parameter(par[0] + "_cor", load(T + par[1] + "/cor.jpg"))
		terreno_mat.set_shader_parameter(par[0] + "_nor", load(T + par[1] + "/normal.jpg"))
		terreno_mat.set_shader_parameter(par[0] + "_rug", load(T + par[1] + "/rugosidade.jpg"))
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = terreno_mat
	if OS.has_environment("MEDIR_SEM_CHAO"):
		var simples := StandardMaterial3D.new()
		simples.albedo_color = Color(0.2, 0.17, 0.13)
		mi.material_override = simples
	add_child(mi)

	_alturas = alturas
	var corpo := StaticBody3D.new()
	corpo_chao = corpo
	add_child(corpo)
	var cs := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = N
	hm.map_depth = N
	hm.map_data = alturas
	cs.shape = hm
	corpo.add_child(cs)


func _ruido_tex(freq: float, normal: bool, semente: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = semente
	n.frequency = freq
	n.fractal_octaves = 5
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	t.generate_mipmaps = true
	if normal:
		t.as_normal_map = true
		t.bump_strength = 6.0
	return t


# ------------------------------------------------------------------ água

func _agua() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(800, 800)
	var mat := ShaderMaterial.new()
	agua_mat = mat
	mat.shader = load("res://shaders/agua.gdshader")
	mat.set_shader_parameter("onda1", _ruido_tex(0.02, true, 5))
	mat.set_shader_parameter("onda2", _ruido_tex(0.05, true, 6))
	mat.set_shader_parameter("ruido", _ruido_tex(0.03, false, 7))
	agua = MeshInstance3D.new()
	agua.mesh = pm
	agua.material_override = mat
	agua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(agua)


# ------------------------------------------------------------------ rancho, fogão, itens

func _rancho() -> void:
	var chao := Terreno.ALTURA_RANCHO
	pos_rancho = Vector3(Terreno.RANCHO.x, chao - 0.35, Terreno.RANCHO.y)
	var r := (load(A + "rancho.glb") as PackedScene).instantiate() as Node3D
	r.position = pos_rancho
	add_child(r)
	var corpo := StaticBody3D.new()
	corpo.position = pos_rancho
	add_child(corpo)
	_caixa(corpo, Vector3(0, 0.475, 0), Vector3(4.0, 0.1, 3.3))           # assoalho
	_caixa(corpo, Vector3(0, 1.6, -1.6), Vector3(4.2, 2.2, 0.12))         # fundo
	_caixa(corpo, Vector3(-2.0, 1.6, 0), Vector3(0.12, 2.2, 3.3))         # lado
	_caixa(corpo, Vector3(2.0, 1.6, 0), Vector3(0.12, 2.2, 3.3))          # lado
	_caixa(corpo, Vector3(-1.25, 1.6, 1.6), Vector3(1.5, 2.2, 0.12))      # frente
	_caixa(corpo, Vector3(1.25, 1.6, 1.6), Vector3(1.5, 2.2, 0.12))       # frente
	# folha da porta, aberta para dentro do lado esquerdo (igual ao rancho.glb)
	var folha := _caixa(corpo, Vector3(-0.6, 1.4, 1.1), Vector3(0.06, 1.84, 0.95))
	folha.rotation.y = deg_to_rad(10)
	var rampa := _caixa(corpo, Vector3(0, 0.43, 2.05), Vector3(1.0, 0.06, 0.95))
	rampa.rotation.x = deg_to_rad(12)

	pos_spawn = pos_rancho + Vector3(0, 0.6, 3.6)
	criar_item("balde", pos_rancho + Vector3(1.2, 0.53, 0.7))
	criar_item("farinha", pos_rancho + Vector3(-1.45, 0.53, -1.05))
	criar_item("rede", pos_rancho + Vector3(0.0, 1.1, -0.6))
	# pendurada pela alça no gancho da parede da frente (por fora, à esquerda da porta), como se guarda para secar
	criar_item("tarrafa", pos_rancho + Vector3(-1.05, 1.64, 1.9))

	fogao = Node3D.new()
	fogao.name = "FogaoRancho"
	fogao.set_script(load("res://scripts/fogao.gd"))
	var pf := pos_rancho + Vector3(4.6, 0, 4.0)
	pf.y = Terreno.altura(pf.x, pf.z)
	fogao.position = pf
	add_child(fogao)

	# feixes de lenha espalhados pela terra firme
	var postos := 0
	var tentativas := 0
	while postos < 3 and tentativas < 400:
		tentativas += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(9.0, 34.0)
		var p := Vector3(Terreno.RANCHO.x + cos(a) * d, 0, Terreno.RANCHO.y + sin(a) * d * 0.8)
		p.y = Terreno.altura(p.x, p.z)
		if p.y < 2.0:
			continue
		var it := criar_item("lenha", p)
		it.rotation.y = rng.randf() * TAU
		postos += 1


func _caixa(pai: Node3D, pos: Vector3, tam: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = tam
	cs.shape = b
	cs.position = pos
	pai.add_child(cs)
	return cs


func criar_item(tipo: String, pos: Vector3, conteudo: int = 0, _registrar := true) -> Node3D:
	var it := Node3D.new()
	it.set_script(load("res://scripts/item.gd"))
	it.tipo = tipo
	it.conteudo = conteudo
	it.position = pos
	if _montando:
		var uid := "item_%d" % _n_itens
		_n_itens += 1
		it.set_meta("uid", uid)
		itens_iniciais[uid] = it
	add_child(it)
	return it


func tronco_com_lenha_perto(de: Vector3):
	var melhor = null
	var md := INF
	for n in get_tree().get_nodes_in_group("interagivel"):
		if n.get("tipo") == "tronco" and n.conteudo > 0:
			var d: float = n.global_position.distance_to(de)
			if d < md:
				md = d
				melhor = n
	return melhor


func item_mais_perto(tipo: String, de: Vector3):
	var melhor = null
	var md := INF
	for n in get_tree().get_nodes_in_group("interagivel"):
		if n.get("tipo") == tipo:
			var d: float = n.global_position.distance_to(de)
			if d < md:
				md = d
				melhor = n
	return melhor


# ------------------------------------------------------------------ vegetação

func _malha(nome: String) -> Mesh:
	var no := (load(A + nome + ".glb") as PackedScene).instantiate()
	var mi := _achar_malha(no)
	var m: Mesh = mi.mesh
	for i in m.get_surface_count():
		var mat := m.surface_get_material(i)
		if mat is BaseMaterial3D and "folha" in mat.resource_name:
			var bm := mat as BaseMaterial3D
			bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			bm.alpha_scissor_threshold = 0.5
			bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	no.free()
	return m


func _achar_malha(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _achar_malha(c)
		if r != null:
			return r
	return null


func _vegetacao() -> void:
	var tipos := ["arvore_mangue_a", "arvore_mangue_b", "arvore_mangue_c", "arvore_fina_a", "arvore_fina_b"]
	var listas := {}
	for t in tipos:
		listas[t] = []
	var corpo := StaticBody3D.new()
	add_child(corpo)
	var forma := CylinderShape3D.new()
	forma.radius = 0.16
	forma.height = 6.0
	var grade := {}
	var tentativas := 0
	while tentativas < 30000 and arvores.size() < 1600:
		tentativas += 1
		var x := rng.randf_range(-126.0, 126.0)
		var z := rng.randf_range(-126.0, 125.0)
		var h := Terreno.altura(x, z)
		if h < -0.9 or Vector2(x, z).distance_to(Terreno.RANCHO) < 17.0:
			continue
		if Terreno.mascara_croa(x, z) > 0.2 or (z > 62.0 and h < 1.9):
			continue
		var em_mangue := h < 2.0
		var dens := Terreno.densidade_mata(x, z)
		var chance := dens * (1.0 if em_mangue else 0.3)
		var espaco := lerpf(3.6, 1.8, dens) if em_mangue else 3.6
		if rng.randf() > chance:
			continue
		var cel := Vector2i(int(floor(x / 1.8)), int(floor(z / 1.8)))
		var perto := false
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var c := cel + Vector2i(dx, dz)
				if grade.has(c) and (grade[c] as Vector2).distance_to(Vector2(x, z)) < espaco:
					perto = true
		if perto:
			continue
		grade[cel] = Vector2(x, z)
		var tipo: String
		if em_mangue:
			var r := rng.randf()
			tipo = "arvore_mangue_a" if r < 0.3 else ("arvore_mangue_b" if r < 0.55 else ("arvore_mangue_c" if r < 0.78 else ("arvore_fina_a" if r < 0.9 else "arvore_fina_b")))
		else:
			tipo = "arvore_fina_a" if rng.randf() < 0.5 else "arvore_fina_b"
		var esc := rng.randf_range(0.8, 1.25)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * esc)
		listas[tipo].append(Transform3D(b, Vector3(x, h, z)))
		arvores.append(Vector3(x, h, z))
		var cs := CollisionShape3D.new()
		cs.shape = forma
		cs.position = Vector3(x, h + 3.0, z)
		corpo.add_child(cs)
	for t in tipos:
		var lista: Array = listas[t]
		if lista.is_empty():
			continue
		_multimesh_em_partes(_malha(t), lista, 130.0, true, 40.0)

	# pneumatóforos: os espetos de raiz que saem da lama
	var pneu := CylinderMesh.new()
	pneu.top_radius = 0.004
	pneu.bottom_radius = 0.014
	pneu.height = 0.3
	pneu.radial_segments = 5
	pneu.rings = 1
	pneu.cap_top = false
	pneu.cap_bottom = false
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.19, 0.155, 0.12)
	mp.roughness = 0.55
	pneu.material = mp
	var t_pneu := []
	var x0 := -127.0
	while x0 < 127.0:
		var z0 := -52.0
		while z0 < 64.0:
			var x := x0 + rng.randf() * 0.8
			var z := z0 + rng.randf() * 0.8
			z0 += 0.8
			var h := Terreno.altura(x, z)
			if h < -0.7 or h > 1.9 or Terreno.mascara_croa(x, z) > 0.3:
				continue
			if rng.randf() > Terreno.densidade_mata(x, z) * 0.95:
				continue
			for n in rng.randi_range(1, 3):
				var px := x + rng.randf_range(-0.3, 0.3)
				var pz := z + rng.randf_range(-0.3, 0.3)
				var s := rng.randf_range(0.4, 1.3)
				var b := Basis.from_euler(Vector3(rng.randf_range(-0.18, 0.18), rng.randf() * TAU, rng.randf_range(-0.18, 0.18))).scaled(Vector3(1, s, 1))
				t_pneu.append(Transform3D(b, Vector3(px, Terreno.altura(px, pz) + 0.15 * s - 0.04, pz)))
		x0 += 0.8
	_multimesh_em_partes(pneu, t_pneu, 48.0, false)

	# mudas de mangue
	var muda := _malha("muda")
	var t_muda := []
	for i in 3500:
		var x := rng.randf_range(-126.0, 126.0)
		var z := rng.randf_range(-50.0, 60.0)
		var h := Terreno.altura(x, z)
		if h < -0.5 or h > 2.0 or Terreno.mascara_croa(x, z) > 0.3:
			continue
		var s := rng.randf_range(0.7, 1.6)
		t_muda.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, h - 0.02, z)))
	_multimesh_em_partes(muda, t_muda, 55.0, false)

	# capim na terra firme
	var capim := _tufo_capim()
	var t_capim := []
	for i in 16000:
		var x := rng.randf_range(-126.0, 126.0)
		var z := rng.randf_range(-126.0, -35.0)
		var h := Terreno.altura(x, z)
		if Terreno.zona(x, z, h).b < 0.6 or Vector2(x, z).distance_to(Terreno.RANCHO) < 6.0:
			continue
		var s := rng.randf_range(0.6, 1.4)
		t_capim.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.7, 1.3), s)), Vector3(x, h - 0.02, z)))
	_multimesh_em_partes(capim, t_capim, 50.0, false)

	# troncos caídos (dá para cortar lenha com o facão): alguns perto do rancho, o resto no mangue
	var n_tr := 0
	var tent := 0
	while n_tr < 32 and tent < 2000:
		tent += 1
		var x: float
		var z: float
		if n_tr < 5:
			var a := rng.randf() * TAU
			x = Terreno.RANCHO.x + cos(a) * rng.randf_range(12.0, 26.0)
			z = Terreno.RANCHO.y + sin(a) * rng.randf_range(12.0, 22.0)
		else:
			x = rng.randf_range(-115.0, 115.0)
			z = rng.randf_range(-45.0, 55.0)
		var h := Terreno.altura(x, z)
		if h < -0.4 or (n_tr >= 5 and h > 1.8):
			continue
		var tr := criar_item("tronco", Vector3(x, h - 0.06, z), 2)
		tr.rotation.y = rng.randf() * TAU
		n_tr += 1


func _tufo_capim() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in 9:
		var a := r.randf() * TAU
		var d := Vector3(cos(a), 0, sin(a))
		var lado := Vector3(-d.z, 0, d.x) * 0.018
		var base := d * r.randf_range(0.0, 0.08)
		var topo := base + d * r.randf_range(0.05, 0.15) + Vector3(0, r.randf_range(0.25, 0.45), 0)
		st.set_color(Color(0.16, 0.2, 0.07))
		st.set_normal(Vector3.UP)
		st.add_vertex(base - lado)
		st.set_color(Color(0.16, 0.2, 0.07))
		st.add_vertex(base + lado)
		st.set_color(Color(0.5, 0.55, 0.25))
		st.add_vertex(topo)
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	m.surface_set_material(0, mat)
	return m


## Espalha muitas cópias pequenas em pedaços de 24 m, cada pedaço some de longe (economiza GPU).
func _multimesh_em_partes(malha: Mesh, transforms: Array, alcance: float, sombra: bool, tam: float = 24.0) -> void:
	var partes := {}
	for t in transforms:
		var tr: Transform3D = t
		var k := Vector2i(int(floor(tr.origin.x / tam)), int(floor(tr.origin.z / tam)))
		if not partes.has(k):
			partes[k] = []
		partes[k].append(tr)
	for k in partes:
		var lista: Array = partes[k]
		var centro := Vector3(k.x * tam + tam * 0.5, 0, k.y * tam + tam * 0.5)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = malha
		mm.instance_count = lista.size()
		for i in lista.size():
			var tr: Transform3D = lista[i]
			tr.origin -= centro
			mm.set_instance_transform(i, tr)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.position = centro
		mmi.visibility_range_end = alcance
		mmi.visibility_range_end_margin = 6.0
		mmi.set_meta("alcance", alcance)
		mmi.add_to_group("alcance")
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if not sombra:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


# ------------------------------------------------------------------ oficina do rancho (missão da canoa)

func _oficina() -> void:
	bancada = Node3D.new()
	bancada.set_script(load("res://scripts/oficina.gd"))
	bancada.tipo = "bancada"
	bancada.main = self
	var pb := pos_rancho + Vector3(-4.6, 0, 3.6)
	pb.y = Terreno.altura(pb.x, pb.z)
	bancada.position = pb
	bancada.rotation.y = 0.3
	add_child(bancada)
	bacia = Node3D.new()
	bacia.set_script(load("res://scripts/oficina.gd"))
	bacia.tipo = "bacia"
	bacia.main = self
	var pc := pos_rancho + Vector3(-3.0, 0, 5.4)
	pc.y = Terreno.altura(pc.x, pc.z)
	bacia.position = pc
	add_child(bacia)


# ------------------------------------------------------------------ fogões e jirau

func fogao_perto(de: Vector3):
	var melhor = fogao
	var md := INF
	for f in get_tree().get_nodes_in_group("fogao"):
		var d: float = f.global_position.distance_to(de) - (20.0 if f.aceso else 0.0)
		if d < md:
			md = d
			melhor = f
	return melhor


func lenha_nos_fogoes() -> int:
	var n := 0
	for f in get_tree().get_nodes_in_group("fogao"):
		n += f.lenha
	return n


func algum_aceso() -> bool:
	for f in get_tree().get_nodes_in_group("fogao"):
		if f.aceso:
			return true
	return false


func na_panela_total() -> int:
	var n := 0
	for f in get_tree().get_nodes_in_group("fogao"):
		n += f.na_panela
	return n


func cozidos_total() -> int:
	var n := 0
	for f in get_tree().get_nodes_in_group("fogao"):
		n += f.cozidos
	return n


## Monta o jirau-fogão por etapas, como no vídeo: pés → cama de talos → camada de lama → fogão.
func construir_jirau(pos: Vector3, yaw: float) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	j.rotation.y = yaw
	add_child(j)
	var etapas := [
		["jirau_pes", "Fincando os 4 pés..."],
		["jirau_talos", "Arrumando a cama de talos..."],
		["jirau_lama", "Passando a camada de lama para o fogo não queimar a madeira..."],
	]
	for e in etapas:
		Mundo.avisar(e[1])
		var parte := (load(A + e[0] + ".glb") as PackedScene).instantiate() as Node3D
		parte.scale = Vector3(1, 0.01, 1)
		j.add_child(parte)
		for i in 2:
			jogador.golpear()
			await get_tree().create_timer(0.45).timeout
		var tw := create_tween()
		tw.tween_property(parte, "scale", Vector3.ONE, 0.35)
		await tw.finished
	_finalizar_jirau(j)
	Mundo.avisar("Jirau-fogão pronto! Ponha lenha e acenda.", "objetivo")
	return j


## Jirau já montado (ao carregar o jogo salvo).
func jirau_pronto(pos: Vector3, yaw: float) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	j.rotation.y = yaw
	add_child(j)
	for nome in ["jirau_pes", "jirau_talos", "jirau_lama"]:
		j.add_child((load(A + nome + ".glb") as PackedScene).instantiate())
	_finalizar_jirau(j)
	return j


func _finalizar_jirau(j: Node3D) -> void:
	var corpo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.8, 0.9, 0.7)
	cs.shape = b
	cs.position.y = 0.45
	corpo.add_child(cs)
	j.add_child(corpo)
	var f := Node3D.new()
	f.set_script(load("res://scripts/fogao.gd"))
	f.modelo = "jirau"
	f.position = Vector3(0, 0.905, 0)
	j.add_child(f)


## O lugar serve para o jirau? Devolve "" se sim, ou o motivo se não.
func motivo_jirau_invalido(pos: Vector3) -> String:
	var chao := Terreno.altura(pos.x, pos.z)
	if Mundo.nivel_mare() - chao > 0.6:
		return "Água funda demais aqui"
	if Vector2(pos.x, pos.z).distance_to(Terreno.RANCHO) < 9.0:
		return "Perto demais do rancho (lá já tem fogão)"
	var mx := chao
	var mn := chao
	for d in [Vector2(0.5, 0), Vector2(-0.5, 0), Vector2(0, 0.5), Vector2(0, -0.5)]:
		var h := Terreno.altura(pos.x + d.x, pos.z + d.y)
		mx = maxf(mx, h)
		mn = minf(mn, h)
	if mx - mn > 0.35:
		return "Chão muito torto"
	return ""


# ------------------------------------------------------------------ mapa

func _criar_mapa() -> void:
	var M := Terreno.METADE
	var N := M * 2 + 1
	var img_alt := Image.create_empty(N, N, false, Image.FORMAT_RF)
	var img_cor := Image.create_empty(N, N, false, Image.FORMAT_RGB8)
	var c_lama := Color(0.38, 0.31, 0.22)
	var c_areia := Color(0.8, 0.72, 0.53)
	var c_firme := Color(0.45, 0.52, 0.27)
	for iz in N:
		for ix in N:
			var h: float = _alturas[iz * N + ix]
			img_alt.set_pixel(ix, iz, Color(h, 0, 0))
			var z := Terreno.zona(float(ix - M), float(iz - M), h)
			var cor := c_lama * z.r + c_areia * z.g + c_firme * z.b
			cor = cor.lerp(Color(0.13, 0.1, 0.08), Terreno.mole(float(ix - M), float(iz - M)) * 0.85)
			img_cor.set_pixel(ix, iz, cor)
	var c_mato := Color(0.16, 0.33, 0.14)
	for a in arvores:
		var ix := int(round(a.x)) + M
		var iz := int(round(a.z)) + M
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var x := clampi(ix + dx, 0, N - 1)
				var y := clampi(iz + dz, 0, N - 1)
				var f := 0.75 if dx == 0 and dz == 0 else 0.3
				img_cor.set_pixel(x, y, img_cor.get_pixel(x, y).lerp(c_mato, f))
	mapa_alt = ImageTexture.create_from_image(img_alt)
	mapa_cor = ImageTexture.create_from_image(img_cor)


## Ícones do mapa: rancho, fogão, tesos, balde largado e objetivo.
func marcas_mapa() -> Array:
	var lista := []
	lista.append({"pos": pos_rancho, "forma": "casa", "txt": "Rancho", "cor": Color(1, 1, 1)})
	for f in get_tree().get_nodes_in_group("fogao"):
		lista.append({"pos": f.global_position, "forma": "fogo", "txt": "" if f == fogao else "Jirau", "cor": Color(1.0, 0.55, 0.2)})
	for i in Terreno.TESOS.size():
		var t: Vector3 = Terreno.TESOS[i]
		lista.append({"pos": Vector3(t.x, 0, t.y), "forma": "teso", "txt": cultura.nome_teso(i) if cultura != null else "Teso", "cor": Color(0.5, 1.0, 0.6)})
	if cultura != null:
		lista.append({"pos": cultura.parabolica.global_position, "forma": "", "txt": "Parabólica na Lama" if cultura.sinal else "Parabólica", "cor": Color(0.85, 0.85, 1.0)})
		lista.append({"pos": cultura.palafita_pos, "forma": "casa", "txt": "Palafita do Capibaribe" if cultura.sinal else "Palafita", "cor": Color(0.75, 0.9, 1.0)})
		if cultura.sinal:
			for par in cultura.nomes():
				lista.append({"pos": par[1], "forma": "nome", "txt": par[0], "cor": Color(1.0, 0.95, 0.8)})
	if barco != null and barco.canoa != null:
		lista.append({"pos": barco.canoa.global_position, "forma": "", "txt": "Canoa", "cor": Color(0.45, 0.85, 1.0)})
		if missoes.concluido:
			if barco.canoa.examinada and not barco.concluida:
				for id in barco.pecas:
					if is_instance_valid(barco.pecas[id]):
						lista.append({"pos": barco.areas[id], "forma": "area", "raio": barco.RAIO_AREA, "txt": barco.NOMES[id] + "?", "cor": Color(0.45, 0.85, 1.0)})
			lista.append({"pos": barco.naufragio.global_position, "forma": "", "txt": "Barco abandonado", "cor": Color(0.7, 0.7, 0.7)})
			lista.append({"pos": Vector3(Terreno.ILHA.x, 0, Terreno.ILHA.y), "forma": "", "txt": "Ilha", "cor": Color(0.9, 0.9, 0.6)})
	if not jogador.tem_balde:
		var b = item_mais_perto("balde", jogador.global_position)
		if b != null:
			lista.append({"pos": b.global_position, "forma": "", "txt": "Balde", "cor": Color(0.5, 0.75, 1.0)})
	var alvo: Dictionary = missoes.alvo()
	if not alvo.is_empty():
		lista.append({"pos": alvo["pos"], "forma": "", "txt": alvo["txt"], "cor": Color(1.0, 0.8, 0.42)})
	return lista


# ------------------------------------------------------------------ tocas e caranguejos

func _tocas() -> void:
	var tentativas := 0
	while tocas.size() < 110 and tentativas < 12000:
		tentativas += 1
		var x: float
		var z: float
		if not arvores.is_empty() and rng.randf() < 0.75:
			var a: Vector3 = arvores[rng.randi() % arvores.size()]
			var ang := rng.randf() * TAU
			var d := rng.randf_range(1.3, 2.8)
			x = a.x + cos(ang) * d
			z = a.z + sin(ang) * d
		else:
			x = rng.randf_range(-110.0, 110.0)
			z = rng.randf_range(-48.0, 52.0)
		var h := Terreno.altura(x, z)
		if h < 0.05 or h > 1.45 or absf(x) > 120.0:
			continue
		# caranguejo gosta de lama mole: lá tem bem mais toca
		if Terreno.mole(x, z) < 0.3 and rng.randf() < 0.55:
			continue
		var longe := true
		for t in tocas:
			if Vector2(t.position.x, t.position.z).distance_to(Vector2(x, z)) < 1.8:
				longe = false
				break
		if not longe:
			continue
		var toca := Node3D.new()
		toca.set_script(load("res://scripts/toca.gd"))
		toca.position = Vector3(x, h, z)
		toca.rotation.y = rng.randf() * TAU
		add_child(toca)
		tocas.append(toca)


func toca_livre_mais_perto(de: Vector3):
	var melhor = null
	var md := INF
	for t in tocas:
		if t.coberta():
			continue
		var d: float = t.global_position.distance_to(de)
		if d < md:
			md = d
			melhor = t
	return melhor


## Altura da toca mais baixa que ainda está descoberta (99 se todas cobertas).
func altura_proxima_toca() -> float:
	var nivel := Mundo.nivel_mare()
	var menor := 99.0
	for t in tocas:
		var h: float = t.global_position.y
		if h + 0.03 >= nivel and h < menor:
			menor = h
	return menor + 0.03 if menor < 90.0 else 99.0


func repovoar(horas: float) -> void:
	for t in tocas:
		if not t.ocupada and randf() < clampf(horas * 0.12, 0.0, 0.9):
			t.receber()


## O bicho escapou da toca por um buraco vizinho e sai correndo pela lama.
func fuga_toca_vizinha(t) -> bool:
	var vizinha = null
	var md := 7.0
	for o in tocas:
		if o == t or o.coberta():
			continue
		var d: float = o.global_position.distance_to(t.global_position)
		if d < md:
			md = d
			vizinha = o
	if vizinha == null:
		return false
	t.esvaziar()
	var c := _novo_andante(vizinha.global_position + Vector3(0.2, 0, 0.2))
	c.fugir()
	c.toca_destino = toca_livre_mais_perto(c.global_position + (c.global_position - jogador.global_position).normalized() * 6.0)
	return true


func soltar_caranguejo(pos: Vector3) -> void:
	var c := _novo_andante(pos)
	c.fugir()


func _novo_andante(pos: Vector3) -> Node3D:
	var c := Node3D.new()
	c.set_script(load("res://scripts/caranguejo_andante.gd"))
	c.main = self
	pos.y = Terreno.altura(pos.x, pos.z)
	c.position = pos
	_andantes.add_child(c)
	return c


func _bichos(delta: float) -> void:
	_relogio_bichos -= delta
	if _relogio_bichos > 0.0 or jogador == null:
		return
	_relogio_bichos = 1.5
	for c in _andantes.get_children():
		if c.global_position.distance_to(jogador.global_position) > 70.0:
			c.queue_free()
	if _andantes.get_child_count() >= 14 or Mundo.altura_sol() < 0.0:
		return
	var perto := []
	for t in tocas:
		if not t.coberta() and t.global_position.y > Mundo.nivel_mare() + 0.15:
			var d: float = t.global_position.distance_to(jogador.global_position)
			if d > 9.0 and d < 45.0:
				perto.append(t)
	if perto.is_empty():
		return
	var t = perto[randi() % perto.size()]
	var a := randf() * TAU
	_novo_andante(t.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.4, 1.5))


# ------------------------------------------------------------------ jogador e interface

func _jogador() -> void:
	jogador = CharacterBody3D.new()
	jogador.set_script(load("res://scripts/jogador.gd"))
	jogador.main = self
	jogador.position = pos_spawn
	jogador.rotation.y = PI
	add_child(jogador)

	missoes = Node.new()
	missoes.set_script(load("res://scripts/missoes.gd"))
	missoes.main = self
	missoes.jogador = jogador
	missoes.fogao = fogao
	add_child(missoes)
	tutorial = Node3D.new()
	tutorial.set_script(load("res://scripts/tutorial.gd"))
	tutorial.main = self
	tutorial.jogador = jogador
	add_child(tutorial)

	hud = CanvasLayer.new()
	hud.set_script(load("res://scripts/hud.gd"))
	hud.main = self
	hud.jogador = jogador
	hud.missoes = missoes
	add_child(hud)
	jogador.hud = hud


func marcas_bussola() -> Array:
	var lista := []
	var alvo: Dictionary = missoes.alvo()
	if not alvo.is_empty():
		lista.append(_marca(alvo["pos"], alvo["txt"], Color(1.0, 0.8, 0.42)))
	if alvo.get("txt", "") != "Rede":
		lista.append(_marca(pos_rancho, "Rancho", Color(1, 1, 1), "casa"))
	# perigo de maré: mostra o teso mais perto
	var chao := Terreno.altura(jogador.global_position.x, jogador.global_position.z)
	if Mundo.mare_subindo() and chao < 2.3:
		var falta := Mundo.horas_ate(chao + 1.2)
		if falta >= 0.0 and falta < 1.0:
			var teso := Terreno.teso_mais_perto(jogador.global_position)
			if teso.distance_to(jogador.global_position) < pos_rancho.distance_to(jogador.global_position):
				lista.append(_marca(teso, "Teso (lugar alto)", Color(0.5, 1.0, 0.6), "teso"))
	if not jogador.tem_balde:
		var b = item_mais_perto("balde", jogador.global_position)
		if b != null and alvo.get("txt", "") != "Balde":
			lista.append(_marca(b.global_position, "Balde", Color(0.5, 0.75, 1.0)))
	return lista


func _marca(p: Vector3, txt: String, cor: Color, forma: String = "") -> Dictionary:
	var d: Vector3 = p - jogador.global_position
	var dist := Vector2(d.x, d.z).length()
	return {"ang": atan2(d.x, -d.z), "txt": "%s  %d m" % [txt, int(dist)], "cor": cor, "forma": forma}


func _process(delta: float) -> void:
	var nivel := Mundo.nivel_mare()
	agua.position.y = nivel
	terreno_mat.set_shader_parameter("nivel_agua", nivel)
	_luz()
	_tempo(delta)
	if Mundo.rodando:
		_bichos(delta)
		if Mundo.tempo_total() - _ultima_hora >= 1.0:
			_ultima_hora = Mundo.tempo_total()
			repovoar(1.0)


# ------------------------------------------------------------------ fotos automáticas (teste)
# godot --path jogo -- --fotos=rancho,mangue,toca --saida=/pasta

func _debug() -> void:
	var fotos := ""
	var saida := OS.get_user_data_dir()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fotos="):
			fotos = a.substr(8)
		elif a.begins_with("--saida="):
			saida = a.substr(8)
	if fotos != "":
		_tirar_fotos.call_deferred(fotos.split(","), saida)
	if "--medir" in OS.get_cmdline_user_args():
		_medir.call_deferred()
	if "--icones" in OS.get_cmdline_user_args():
		var ic := Node.new()
		ic.set_script(load("res://scripts/icones.gd"))
		add_child(ic)
		var so := []
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--so="):
				so = Array(arg.substr(5).split(","))
		await ic.gerar(so)
		get_tree().quit()
		return
	if "--teste-novo-jogo" in OS.get_cmdline_user_args():
		_teste_novo_jogo.call_deferred()
	if "--teste" in OS.get_cmdline_user_args():
		var t := Node.new()
		t.set_script(load("res://scripts/teste.gd"))
		t.main = self
		add_child(t)


## Testa "Novo jogo" na pausa: recarrega a cena e confere se tudo voltou ao começo.
## godot --headless --path jogo -- --teste-novo-jogo
func _teste_novo_jogo() -> void:
	await get_tree().create_timer(0.5).timeout
	if Config.has_meta("novo_jogo_testado"):
		var ok: bool = hud.iniciado and absf(Mundo.hora - 6.0) < 0.1 and Mundo.dia == 1 and not jogador.tem_balde and tutorial.ativo == bool(Config.v["primeiros_passos"])
		print("NOVO JOGO: iniciado=%s hora=%.2f dia=%d balde=%s passos=%s -> %s" % [hud.iniciado, Mundo.hora, Mundo.dia, jogador.tem_balde, tutorial.ativo, "OK" if ok else "FALHOU"])
		get_tree().quit(0 if ok else 1)
		return
	Config.set_meta("novo_jogo_testado", true)
	salvador.ativo = false
	hud.comecar()
	Mundo.hora = 15.0
	Mundo.dia = 3
	jogador.tem_balde = true
	hud._novo_jogo_pausa()        # 1º clique: pede confirmação
	if Mundo.hora != 15.0:
		print("NOVO JOGO: apagou sem confirmar -> FALHOU")
		get_tree().quit(1)
		return
	hud._novo_jogo_pausa()        # 2º clique: recomeça


## Mede o tempo de processador por quadro (sem desenhar), parado no mangue.
func _medir() -> void:
	hud.comecar()
	_posicionar(Vector3(-6, 0, -30), PI, -0.12)
	Mundo.hora = 7.0
	await get_tree().create_timer(1.0).timeout
	var t0 := Time.get_ticks_usec()
	var n := 0
	while n < 300:
		await get_tree().process_frame
		n += 1
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
	print("MEDIR quadro_ms=%.2f  (%.0f fps só de processador)" % [ms, 1000.0 / ms])
	get_tree().quit()


func _posicionar(p: Vector3, yaw: float, pitch: float) -> void:
	p.y = Terreno.altura(p.x, p.z) + 0.05
	jogador.global_position = p
	jogador.rotation.y = yaw
	jogador.cabeca.rotation.x = pitch


## Põe o jogador em `de` (os pés; y=0 assenta no chão) olhando para o ponto `alvo`.
func _olhar(de: Vector3, alvo: Vector3) -> void:
	if de.y == 0.0:
		de.y = Terreno.altura(de.x, de.z) + 0.05
	jogador.global_position = de
	jogador.velocity = Vector3.ZERO
	var olho: Vector3 = jogador.cabeca.global_position
	var d := alvo - olho
	jogador.rotation.y = atan2(-d.x, -d.z)
	jogador.cabeca.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _tirar_fotos(lista: PackedStringArray, saida: String) -> void:
	hud.tela_inicio.visible = false
	hud.iniciado = true
	tutorial.pular()      # só a foto "passos" mostra os primeiros passos
	DisplayServer.window_set_size(Vector2i(1600, 900))
	if "--sem-hud" in OS.get_cmdline_user_args():
		hud.visible = false
	await get_tree().create_timer(1.0).timeout
	for nome in lista:
		if hud._mapa_aberto:
			hud.abrir_mapa(false)
		if hud._inv_aberto:
			hud.abrir_inventario(false)
		hud.tela_pausa.visible = false
		hud.tela_config.visible = false
		hud.tela_sono.visible = false
		hud.tela_fim.visible = false
		if not nome.begins_with("inicio"):
			hud.tela_inicio.visible = false
		if nome != "segurando":
			if jogador.toca != null:
				jogador.sair_toca()
			if not jogador.segurando.is_empty():
				jogador._fim_decisao()
		match nome:
			"inicio":
				hud.tela_inicio.visible = true
			"inicio_salvo":
				salvador.salvar()
				salvador.ativo = true
				hud.preparar_inicio()
				salvador.ativo = false
				hud.tela_inicio.visible = true
			"rancho":
				hud.tela_inicio.visible = false
				Mundo.hora = 7.0
				_posicionar(pos_rancho + Vector3(5.5, 0, 10.0), deg_to_rad(25), -0.08)
			"mangue":
				Mundo.hora = 6.6
				_posicionar(Vector3(-6, 0, -30), PI, -0.12)
			"mangue2":
				Mundo.hora = 8.0
				_posicionar(Vector3(30, 0, -12), PI * 0.75, -0.2)
			"toca":
				Mundo.hora = 6.8
				var t = toca_livre_mais_perto(Vector3(0, 0, -30))
				_posicionar(t.global_position + Vector3(0, 0, -1.0), PI, -0.5)
				jogador.tem_balde = true
				jogador.iniciar_toca(t)
				jogador.mg["prof"] = 0.3
				jogador.mg["fase"] = "agarrar"
				jogador.mg["agulha"] = 0.4
				jogador.mg["alvo"] = 1.2
				jogador.mg["tam"] = 1.3
				jogador.mg["vel"] = 0.0
				Mundo.rodando = true
			"lama":
				Mundo.forcar_chuva(0.0)
				Mundo.hora = 7.5
				var achado := Vector3.ZERO
				for i in 4000:
					var px := randf_range(-60.0, 60.0)
					var pz := randf_range(-40.0, 0.0)
					if Terreno.mole(px, pz) > 0.9 and Terreno.mole(px, pz - 9.0) < 0.2:
						achado = Vector3(px, 0, pz)
						break
				_posicionar(achado + Vector3(0, 0, -9.0), PI, -0.35)
				for pc in pocas:
					pc.visible = false
			"poca":
				for pc in pocas:
					pc.visible = true
				Mundo.hora = 7.5
				var pc = pocas[0]
				for q in pocas:
					if not q.peixes.is_empty():
						pc = q
						break
				_posicionar(Vector3(pc.dados.x, 0, pc.dados.y - pc.dados.z - 1.5), PI, -0.55)
			"cardume":
				Mundo.hora = 11.0
				_posicionar(Vector3(-30, 0, 10), PI * 0.5, -0.25)
				peixes._novo_cardume(jogador.global_position + Vector3(-5, 0, 0))
				peixes._pular(jogador.global_position + Vector3(-7, 0, 1.5))
				Mundo.rodando = true
			"construir":
				Mundo.forcar_chuva(0.0)
				Mundo.hora = 7.0
				_posicionar(Vector3(-6, 0, -30), PI, -0.3)
				jogador.lenha = 4
				jogador.construindo = true
				Mundo.rodando = true
			"jirau":
				jogador.construindo = false
				if jogador._fantasma != null:
					jogador._fantasma.visible = false
				Mundo.rodando = false
				Mundo.hora = 9.9
				var pj := Vector3(-6, 0, -33)
				pj.y = Terreno.altura(pj.x, pj.z)
				var jr := await construir_jirau(pj, PI)
				var fg = jr.get_child(jr.get_child_count() - 1)
				fg.lenha = 2
				fg.acender()
				fg.na_panela = 5
				_posicionar(Vector3(-5.2, 0, -30.9), 0.35, -0.3)
				jogador.texto_alvo = ""
			"inventario":
				Mundo.hora = 8.0
				_posicionar(Vector3(-6, 0, -30), PI, -0.2)
				jogador.tem_balde = true
				jogador.caranguejos = 5
				jogador.peixes = 2
				for k in {"peixe": 2, "lenha": 2, "farinha": 1, "farofa": 1}:
					jogador.mochila[k] = {"peixe": 2, "lenha": 2, "farinha": 1, "farofa": 1}[k]
				jogador.tem_tarrafa = true
				jogador.galochas = true
				jogador.aratus = 1
				Mundo.rodando = true
				hud.abrir_inventario(true)
			"canoa":
				Mundo.forcar_chuva(0.0)
				Mundo.hora = 7.5
				var cp: Vector3 = barco.canoa.global_position
				_posicionar(cp + Vector3(-3.5, 0, -3.0), -2.3, -0.3)
			"naufragio":
				Mundo.hora = 6.3
				var np: Vector3 = barco.naufragio.global_position
				_posicionar(np + Vector3(-7.0, 0, -8.0), -2.45, -0.15)
			"pilotando":
				Mundo.hora = 12.0
				var c = barco.canoa
				c.furo = false
				c.tem_motor = true
				c.tem_helice = true
				c.tem_remo = true
				c.tem_cuia = true
				c.gasolina = 80.0
				c._atualizar_vis()
				c.global_position = Vector3(30, Mundo.nivel_mare(), 70)
				var pi_v: Vector3 = Vector3(Terreno.ILHA.x, 0, Terreno.ILHA.y) - c.global_position
				c._yaw = atan2(-pi_v.x, -pi_v.z)
				c.embarcar(jogador)
				jogador.cabeca.rotation.x = -0.15
				Mundo.rodando = true
				Input.action_press("frente")
			"ilha":
				Input.action_release("frente")
				barco.canoa.global_position = Vector3(Terreno.ILHA.x - 45.0, Mundo.nivel_mare(), Terreno.ILHA.y - 5.0)
				barco.canoa._yaw = -PI / 2 + 0.1
				jogador._olhar = 0.0
			"aratu_noite":
				Mundo.forcar_chuva(0.0)
				Mundo.hora = 22.6
				_posicionar(Vector3(-12, 0, -18), PI * 0.8, 0.15)
				jogador.global_position.y = maxf(jogador.global_position.y, Mundo.nivel_mare() - 1.2)
				jogador.lanterna.light_energy = jogador.LANTERNA
				jogador.tem_balde = true
				Mundo.rodando = true
			"mira_tarrafa":
				jogador.lanterna.light_energy = 0.0
				Mundo.hora = 10.6
				jogador.tem_tarrafa = true
				_posicionar(Vector3(28, 0, -8), PI * 0.9, -0.3)
				jogador.global_position.y = maxf(jogador.global_position.y, Mundo.nivel_mare() - 0.9)
				Input.action_press("tarrafa")
				Mundo.rodando = true
			"muricoca":
				Input.action_release("tarrafa")
				Mundo.hora = 18.4
				_posicionar(Vector3(-6, 0, -30), PI, -0.05)
				jogador.muricoca = 1.0
			"pincas":
				Mundo.hora = 8.0
				_posicionar(Vector3(-6, 0, -30), PI, -0.55)
				var pc: Vector3 = jogador.global_position + Vector3(0, 0, 1.3)
				var cr = _novo_andante(pc)
				cr.toca_destino = toca_livre_mais_perto(pc + Vector3(0, 0, 12))
				cr.fugindo = true
				cr._ja_ameacou = true
				cr.ameacando = 99.0
				Mundo.rodando = true
			"palafita":
				Mundo.forcar_chuva(0.0)
				Mundo.hora = 11.0
				var pp: Vector3 = cultura.palafita_pos
				jogador.global_position = Vector3(pp.x + 9.0, Mundo.nivel_mare() - 1.45, pp.z + 13.0)
				jogador.rotation.y = atan2(9.0, 13.0)
				jogador.cabeca.rotation.x = 0.12
			"parabolica":
				Mundo.hora = 16.8
				var pb: Vector3 = cultura.parabolica.global_position
				_posicionar(pb + Vector3(-9.0, 0, 11.0), atan2(-9.0, 11.0), 0.22)
			"mapa_nomes":
				Mundo.hora = 10.0
				cultura.sinal = true
				_posicionar(Vector3(-6, 0, -30), PI, -0.05)
				hud.abrir_mapa(true)
			"facao_mao":
				Mundo.forcar_chuva(0.0)
				Mundo.hora = 9.0
				_posicionar(pos_rancho + Vector3(3, 0, 8), PI * 0.85, -0.25)
			"sono":
				Mundo.hora = 19.0
				_olhar(pos_rancho + Vector3(0.0, 0.6, 1.2), pos_rancho + Vector3(0.0, 1.1, -0.6))
				jogador.dormir()
				hud.tela_sono._por(10.5)
			"pausa":
				Mundo.hora = 8.0
				_olhar(pos_rancho + Vector3(0.3, 0.0, 5.5), pos_rancho + Vector3(0, 1.3, 1.6))
				hud.tela_pausa.visible = true
			"config":
				hud.tela_config.abrir()
			"passos":
				Mundo.hora = 8.0
				tutorial.reiniciar()
				jogador.olhou = 1000.0
				Mundo.rodando = true
				_olhar(pos_rancho + Vector3(-1.5, 0.0, 6.5), pos_rancho + Vector3(1.0, 0.3, 2.15))
			"tarrafa":
				Mundo.hora = 8.5
				_olhar(pos_rancho + Vector3(-0.7, 0.0, 3.6), pos_rancho + Vector3(-1.05, 1.9, 1.9))
			"porta":
				Mundo.hora = 8.0
				_olhar(pos_rancho + Vector3(0.3, 0.0, 5.5), pos_rancho + Vector3(0, 1.3, 1.6))
			"bacia":
				Mundo.hora = 9.0
				_olhar(bacia.global_position + Vector3(0.0, 0.0, 1.1), bacia.global_position)
				bacia.agua = 0.6
			"galochas":
				Mundo.hora = 9.5
				_olhar(pos_rancho + Vector3(-0.6, 0.0, 4.2), pos_rancho + Vector3(0.6, 0.5, 2.0))
			"rede":
				Mundo.hora = 9.5
				_olhar(pos_rancho + Vector3(0.0, 0.6, 1.2), pos_rancho + Vector3(0.0, 1.1, -0.6))
			"rancho_dentro":
				Mundo.hora = 9.5
				jogador.global_position = pos_rancho + Vector3(0.6, 0.6, 1.3)
				jogador.rotation.y = 0.5
				jogador.cabeca.rotation.x = -0.45
			"panela":
				Mundo.hora = 9.0
				fogao.lenha = 2
				fogao.acender()
				fogao.na_panela = 6
				_posicionar(fogao.global_position + Vector3(-1.2, 0, 1.2), deg_to_rad(-45), -0.55)
			"galao":
				Mundo.hora = 9.0
				var gp = barco.pecas["galao"].global_position
				_posicionar(gp + Vector3(1.2, 0, 1.2), atan2(1.2, 1.2), -0.5)
			"trapiche":
				Mundo.forcar_chuva(0.0)
				Mundo.hora = 8.5
				var tp: Vector3 = cultura.trapiche_ponta
				_posicionar(tp + Vector3(-8, 0, -4), atan2(-8.0, -4.0) + PI * 0.0, 0.05)
				jogador.look_at(Vector3(tp.x, jogador.global_position.y, tp.z - 5.0), Vector3.UP)
			"balde_mao":
				Mundo.hora = 8.0
				jogador.tem_balde = true
				jogador.caranguejos = 4
				_posicionar(Vector3(-6, 0, -30), PI, -0.35)
			"chuva_dentro":
				Mundo.forcar_chuva(1.0)
				Mundo.hora = 14.0
				jogador.global_position = pos_rancho + Vector3(0.3, 0.6, 1.0)
				jogador.rotation.y = 0.0
				jogador.cabeca.rotation.x = 0.05
				Mundo.rodando = true
			"chuva_porta":
				jogador.global_position = pos_rancho + Vector3(0.0, 0.6, 0.2)
				jogador.rotation.y = PI
				jogador.cabeca.rotation.x = 0.0
			"trapiche_rampa":
				Mundo.forcar_chuva(0.0)
				Mundo.hora = 8.0
				var tr: Vector3 = cultura.trapiche_ponta
				_posicionar(Vector3(tr.x - 4.0, 0, tr.z - 19.0), 0.0, -0.05)
				jogador.look_at(Vector3(tr.x, jogador.global_position.y + 0.5, tr.z - 6.0), Vector3.UP)
			"trapiche_cima":
				var tc: Vector3 = cultura.trapiche_ponta
				jogador.global_position = Vector3(tc.x, tc.y + 0.1, tc.z - 9.5)
				jogador.look_at(Vector3(tc.x, tc.y + 0.1, tc.z), Vector3.UP)
				jogador.cabeca.rotation.x = -0.35
			"areas":
				missoes.concluido = true
				barco.canoa.examinada = true
				Mundo.hora = 9.0
				_posicionar(barco.canoa.global_position + Vector3(4, 0, 0), 0.0, 0.0)
				hud.abrir_mapa(true)
			"tocas":
				Mundo.hora = 7.2
				var t3 = toca_livre_mais_perto(Vector3(10, 0, -25))
				_posicionar(t3.global_position + Vector3(0.5, 0, -5.0), PI + 0.1, -0.35)
				jogador.tem_balde = true
			"puxando":
				Mundo.hora = 6.8
				var t2 = toca_livre_mais_perto(Vector3(0, 0, -30))
				_posicionar(t2.global_position + Vector3(0, 0, -1.0), PI, -0.5)
				jogador.tem_balde = true
				jogador.iniciar_toca(t2)
				jogador.mg["prof"] = 0.3
				jogador.mg["fase"] = "puxando"
				jogador.mg["pegada"] = 3
				jogador.mg["tensao"] = 0.5
				jogador.mg["progresso"] = 0.45
				jogador.mg["puxao"] = 0.0
				jogador.mg["prox_puxao"] = 99.0
			"segurando":
				jogador.tem_balde = true
				jogador.caranguejos = 3
				if jogador.toca != null:
					jogador.sair_toca()
				jogador.segurar_caranguejo(false, false, "teste")
			"mare":
				Mundo.hora = 11.6
				_posicionar(Vector3(-6, 0, -30), PI, -0.1)
			"noite":
				Mundo.hora = 20.5
				fogao.lenha = 2
				fogao.acender()
				_posicionar(pos_rancho + Vector3(2.0, 0, 9.5), deg_to_rad(20), -0.1)
				jogador.lanterna.light_energy = jogador.LANTERNA
			"perigo":
				jogador.lanterna.light_energy = 0.0
				Mundo.rodando = false
				Mundo.hora = 10.4
				jogador.tem_balde = true
				jogador.caranguejos = 4
				_posicionar(Vector3(-20, 0, -15), PI * 0.9, -0.05)
			"panela":
				Mundo.hora = 9.0
				fogao.lenha = 2
				fogao.acender()
				fogao.na_panela = 6
				_posicionar(fogao.global_position + Vector3(-1.2, 0, 1.2), deg_to_rad(-45), -0.55)
			"facao":
				Mundo.hora = 8.0
				jogador.tem_balde = false
				var tr = tronco_com_lenha_perto(pos_rancho)
				_posicionar(tr.global_position + Vector3(0, 0, 2.2), 0.0, -0.35)
			"por_do_sol":
				Mundo.forcar_chuva(0.0)
				Mundo.nuvens = 0.35
				Mundo.hora = 17.55
				_posicionar(Vector3(-20, 0, -40), PI / 2, 0.06)
			"sol":
				Mundo.forcar_chuva(0.0)
				Mundo.nuvens = 0.3
				Mundo.hora = 16.0
				_posicionar(pos_rancho + Vector3(0, 0, 8), 1.96, 0.45)
			"lua":
				Mundo.forcar_chuva(0.0)
				Mundo.nuvens = 0.2
				Mundo.hora = 20.5
				_posicionar(pos_rancho + Vector3(0, 0, 8), -PI / 2 - 0.1, 1.0)
			"chuva":
				Mundo.forcar_chuva(0.9)
				Mundo.hora = 14.0
				_posicionar(Vector3(-6, 0, -30), PI, -0.05)
			"mapa":
				Mundo.forcar_chuva(0.0)
				Mundo.hora = 10.0
				_posicionar(Vector3(-6, 0, -30), PI, -0.05)
				hud.abrir_mapa(true)
			"croa":
				Mundo.hora = 6.2
				_posicionar(Vector3(10, 0, 48), PI, -0.05)
		await get_tree().create_timer(4.0).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png(saida.path_join(nome + ".png"))
		print("FOTO ", nome, "  fps=", Engine.get_frames_per_second(), "  process_ms=", snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1), "  fisica_ms=", snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.1), "  draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "  objetos=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	get_tree().quit()
