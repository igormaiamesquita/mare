extends Node3D
## Fogão de 3 pedras com panela: pôr lenha → acender → pôr os caranguejos → esperar → comer (com farinha, melhor).

const SEGUNDOS_PARA_COZINHAR := 40.0
const HORAS_POR_FEIXE := 2.5

var lenha := 0             # feixes guardados ao lado do fogo
var aceso := false
var combustivel := 0.0     # horas de fogo que restam
var na_panela := 0
var peixe_panela := 0
var peixe_cozido := 0
var cozimento := 0.0       # 0..1
var cozidos := 0
var raio_interacao := 2.2
var modelo := "fogao"      # "fogao" (3 pedras no chão) ou "jirau" (em cima do jirau de lama)

var fogo: GPUParticles3D
var fumaca: GPUParticles3D
var vapor: GPUParticles3D
var luz: OmniLight3D
var _t := 0.0
var _na_panela_vis: Array[Node3D] = []
var _cozidos_vis: Array[Node3D] = []


func _ready() -> void:
	add_to_group("interagivel")
	add_to_group("fogao")
	var pedras := (load("res://assets/fogao.glb") as PackedScene).instantiate() as Node3D
	add_child(pedras)
	var panela := (load("res://assets/panela.glb") as PackedScene).instantiate() as Node3D
	panela.position = Vector3(0, 0.17, 0)
	add_child(panela)
	if modelo == "jirau":
		# panelinha da mochila em cima de 3 pedrinhas, sobre a lama do jirau
		pedras.scale = Vector3.ONE * 0.55
		panela.position.y = 0.1
		panela.scale = Vector3.ONE * 0.85
	# caranguejos dentro da panela: crus enquanto cozinham, vermelhos quando prontos
	for i in 8:
		var a := i / 8.0 * TAU
		var pos := Vector3(cos(a) * 0.06, 0.24 + (i % 3) * 0.02, sin(a) * 0.06)
		for lista in [_na_panela_vis, _cozidos_vis]:
			var nome := "caranguejo" if lista == _na_panela_vis else "caranguejo_cozido"
			var c := (load("res://assets/%s.glb" % nome) as PackedScene).instantiate() as Node3D
			c.position = pos
			c.rotation = Vector3(randf_range(-0.4, 0.4), a, randf_range(-0.4, 0.4))
			c.scale = Vector3.ONE * 0.75
			c.visible = false
			add_child(c)
			lista.append(c)
	fogo = _particulas(Color(1.0, 0.85, 0.35, 1.0), Color(0.9, 0.2, 0.05, 0.0), 40, 0.7, Vector2(0.4, 0.9), 0.22, true, 0.6)
	fogo.position = Vector3(0, 0.08, 0)
	fumaca = _particulas(Color(0.35, 0.33, 0.3, 0.35), Color(0.5, 0.5, 0.5, 0.0), 24, 4.0, Vector2(0.4, 0.7), 0.7, false, 0.15)
	fumaca.position = Vector3(0, 0.45, 0)
	vapor = _particulas(Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0), 20, 2.0, Vector2(0.3, 0.6), 0.35, false, 0.2)
	vapor.position = Vector3(0, 0.36, 0)
	for p in [fogo, fumaca, vapor]:
		p.emitting = false
		add_child(p)
	luz = OmniLight3D.new()
	luz.light_color = Color(1.0, 0.55, 0.25)
	luz.omni_range = 7.0
	luz.light_energy = 0.0
	luz.shadow_enabled = true
	luz.position = Vector3(0, 0.35, 0)
	add_child(luz)


func texto_interacao(j) -> String:
	if cozidos + peixe_cozido > 0:
		if j.farinha:
			return "[E] Comer %s com farinha" % _texto_comida(cozidos, peixe_cozido)
		return "[E] Comer %s (com farinha d'água sustenta mais)" % _texto_comida(cozidos, peixe_cozido)
	if na_panela + peixe_panela > 0:
		return "Cozinhando %s... %d%%" % [_texto_comida(na_panela, peixe_panela), int(cozimento * 100.0)]
	if not aceso:
		if lenha == 0:
			if j.lenha > 0:
				return "[E] Pôr a lenha no fogão"
			return "Sem lenha: procure feixes de galho seco em volta do rancho"
		if j.lenha > 0:
			return "[E] Pôr mais lenha (%d no fogão)" % lenha
		return "[E] Acender o fogo com o isqueiro"
	if j.caranguejos + j.aratus + j.peixes + j.mochila["peixe"] > 0:
		return "[E] Pôr %s na panela" % _texto_comida(j.caranguejos + j.aratus, j.peixes + j.mochila["peixe"])
	if j.lenha > 0:
		return "[E] Pôr mais lenha no fogo"
	return "Fogo aceso (%s de lenha)" % Mundo.texto_duracao(combustivel + lenha * HORAS_POR_FEIXE)


func interagir(j) -> void:
	if cozidos + peixe_cozido > 0:
		var com_farinha: bool = j.farinha
		j.comer(cozidos + peixe_cozido, com_farinha)
		if com_farinha:
			Mundo.avisar("Comeu %s com farinha. Energia para o resto do dia!" % _texto_comida(cozidos, peixe_cozido), "objetivo")
		else:
			Mundo.avisar("Comeu %s. Com farinha d'água teria sustentado mais." % _texto_comida(cozidos, peixe_cozido), "objetivo")
		cozidos = 0
		peixe_cozido = 0
		return
	if na_panela + peixe_panela > 0:
		return
	if not aceso:
		if j.lenha > 0:
			lenha += j.lenha
			Mundo.avisar("Pôs %d feixes de lenha no fogão" % j.lenha)
			j.lenha = 0
		elif lenha > 0:
			acender()
		return
	if j.caranguejos + j.aratus + j.peixes + j.mochila["peixe"] > 0:
		na_panela = j.caranguejos + j.aratus
		peixe_panela = j.peixes + j.mochila["peixe"]
		j.caranguejos = 0
		j.aratus = 0
		j.peixes = 0
		j.mochila["peixe"] = 0
		cozimento = 0.0
		vapor.emitting = true
		Mundo.avisar("%s foram para a panela com água e sal" % _texto_comida(na_panela, peixe_panela))
	elif j.lenha > 0:
		lenha += j.lenha
		j.lenha = 0
		Mundo.avisar("Mais lenha no fogo")


func _texto_comida(c: int, p: int) -> String:
	var partes := []
	if c > 0:
		partes.append("%d caranguejo%s" % [c, "s" if c > 1 else ""])
	if p > 0:
		partes.append("%d peixe%s" % [p, "s" if p > 1 else ""])
	return " e ".join(partes)


func acender() -> void:
	if lenha <= 0:
		return
	lenha -= 1
	combustivel += HORAS_POR_FEIXE
	aceso = true
	fogo.emitting = true
	fumaca.emitting = true
	Mundo.avisar("Fogo aceso!")


func _process(delta: float) -> void:
	_t += delta
	for i in _na_panela_vis.size():
		_na_panela_vis[i].visible = i < na_panela
		_cozidos_vis[i].visible = i < cozidos
	if aceso and Mundo.nivel_mare() > global_position.y - 0.03:
		aceso = false
		fogo.emitting = false
		fumaca.emitting = false
		Mundo.avisar("A maré subiu e apagou o fogo do jirau!", "perigo")
	if aceso:
		combustivel -= delta * Mundo.acelerar / Mundo.SEGUNDOS_REAIS_POR_HORA if Mundo.rodando else 0.0
		if combustivel <= 0.0:
			if lenha > 0:
				lenha -= 1
				combustivel += HORAS_POR_FEIXE
			else:
				aceso = false
				fogo.emitting = false
				fumaca.emitting = false
				Mundo.avisar("O fogo apagou", "perigo")
		luz.light_energy = 2.2 + sin(_t * 13.0) * 0.25 + sin(_t * 7.3) * 0.35
		if na_panela + peixe_panela > 0 and Mundo.rodando:
			cozimento += delta / SEGUNDOS_PARA_COZINHAR
			if cozimento >= 1.0:
				cozidos += na_panela
				peixe_cozido += peixe_panela
				na_panela = 0
				peixe_panela = 0
				cozimento = 0.0
				vapor.emitting = false
				Mundo.avisar("Comida pronta! Hora de comer.", "objetivo")
	else:
		luz.light_energy = move_toward(luz.light_energy, 0.0, delta * 3.0)


func _particulas(cor_ini: Color, cor_fim: Color, qtd: int, vida: float, vel: Vector2, tam: float, aditivo: bool, subida: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = qtd
	p.lifetime = vida
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.1
	m.direction = Vector3.UP
	m.spread = 14.0
	m.initial_velocity_min = vel.x
	m.initial_velocity_max = vel.y
	m.gravity = Vector3(0.05, subida, 0)
	m.scale_min = 0.6
	m.scale_max = 1.3
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.4))
	curva.add_point(Vector2(0.3, 1.0))
	curva.add_point(Vector2(1.0, 0.2))
	var ct := CurveTexture.new()
	ct.curve = curva
	m.scale_curve = ct
	var g := Gradient.new()
	g.set_color(0, cor_ini)
	g.set_color(1, cor_fim)
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(tam, tam)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if aditivo:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g2 := Gradient.new()
	g2.set_color(0, Color(1, 1, 1, 1))
	g2.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g2
	mat.albedo_texture = tex
	quad.material = mat
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
