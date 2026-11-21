extends Node3D
## Vida na água: cardumes nadando perto da superfície e tainhas pulando onde a água é funda.
## Tudo acontece só perto do jogador, para não pesar.

var main
var _cena: PackedScene
var cardumes: Array = []
var _relogio := 0.0
var _pulo := 3.0


func _ready() -> void:
	_cena = load("res://assets/peixe.glb")


func _fundura(x: float, z: float) -> float:
	return Mundo.nivel_mare() - Terreno.altura(x, z)


func _ponto_na_agua(perto: Vector3, raio_min: float, raio_max: float, fundura_min: float) -> Variant:
	for i in 10:
		var a := randf() * TAU
		var r := randf_range(raio_min, raio_max)
		var p := perto + Vector3(cos(a) * r, 0, sin(a) * r)
		if absf(p.x) < 125.0 and absf(p.z) < 125.0 and _fundura(p.x, p.z) > fundura_min:
			return p
	return null


func _process(delta: float) -> void:
	if main.jogador == null or not Mundo.rodando:
		return
	var jp: Vector3 = main.jogador.global_position
	var nivel := Mundo.nivel_mare()
	_relogio -= delta
	if _relogio <= 0.0:
		_relogio = 1.0
		for c in cardumes.duplicate():
			if c["centro"].distance_to(jp) > 65.0 or _fundura(c["centro"].x, c["centro"].z) < 0.3:
				_remover(c)
		if cardumes.size() < 6:
			var p = _ponto_na_agua(jp, 12.0, 40.0, 0.6)
			if p != null:
				_novo_cardume(p)

	for c in cardumes:
		var centro: Vector3 = c["centro"]
		var alvo: Vector3 = c["alvo"]
		# foge de quem chega perto
		var fugindo := Vector2(centro.x - jp.x, centro.z - jp.z).length() < 4.0
		if fugindo:
			alvo = centro + (centro - jp).normalized() * 6.0
			c["alvo"] = alvo
		var para := alvo - centro
		para.y = 0.0
		if para.length() < 0.8 or _fundura(alvo.x, alvo.z) < 0.5:
			var novo = _ponto_na_agua(centro, 4.0, 12.0, 0.6)
			if novo != null:
				c["alvo"] = novo
			continue
		var dir := para.normalized()
		var vel := 3.2 if fugindo else 1.2
		c["dir"] = c["dir"].lerp(dir, clampf(delta * 2.0, 0.0, 1.0)).normalized()
		centro += c["dir"] * vel * delta
		centro.y = nivel - 0.04
		c["centro"] = centro
		c["t"] += delta
		var peixes: Array = c["peixes"]
		var offs: Array = c["offs"]
		for i in peixes.size():
			var f: Node3D = peixes[i]
			var o: Vector3 = offs[i]
			var onda := Vector3(sin(c["t"] * 2.0 + i), 0, cos(c["t"] * 1.7 + i * 2.0)) * 0.15
			f.global_position = centro + o + onda
			var d: Vector3 = c["dir"]
			f.look_at(f.global_position + d, Vector3.UP)
			f.rotate_object_local(Vector3.UP, sin(c["t"] * 14.0 + i) * 0.18)

	# tainha pulando
	_pulo -= delta
	if _pulo <= 0.0:
		_pulo = randf_range(2.5, 6.0)
		var p = _ponto_na_agua(jp, 7.0, 25.0, 0.5)
		if p != null:
			_pular(p)


func _novo_cardume(p: Vector3) -> void:
	var c := {"centro": p, "alvo": p, "dir": Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized(), "t": randf() * 10.0, "peixes": [], "offs": []}
	var n := randi_range(5, 9)
	for i in n:
		var f := _cena.instantiate() as Node3D
		f.scale = Vector3.ONE * randf_range(0.7, 1.15)
		add_child(f)
		c["peixes"].append(f)
		c["offs"].append(Vector3(randf_range(-0.8, 0.8), randf_range(-0.06, 0.03), randf_range(-0.8, 0.8)))
	cardumes.append(c)


## Tarrafa caiu aqui: pega os peixes que estavam embaixo e espanta o cardume.
func pescar_tarrafa(centro: Vector3, raio: float) -> int:
	var n := 0
	for c in cardumes.duplicate():
		var lista: Array = c["peixes"]
		var offs: Array = c["offs"]
		for i in range(lista.size() - 1, -1, -1):
			var f: Node3D = lista[i]
			if Vector2(f.global_position.x - centro.x, f.global_position.z - centro.z).length() < raio and randf() < 0.9:
				f.queue_free()
				lista.remove_at(i)
				offs.remove_at(i)
				n += 1
		var cc: Vector3 = c["centro"]
		if Vector2(cc.x - centro.x, cc.z - centro.z).length() < raio + 8.0:
			var fuga := cc - centro
			fuga.y = 0.0
			c["alvo"] = cc + fuga.normalized() * 16.0
		if lista.is_empty():
			cardumes.erase(c)
	return n


func cardume_perto(p: Vector3, dist: float) -> bool:
	for c in cardumes:
		if c["centro"].distance_to(p) < dist:
			return true
	return false


func _remover(c: Dictionary) -> void:
	for f in c["peixes"]:
		f.queue_free()
	cardumes.erase(c)


func _pular(p: Vector3) -> void:
	var nivel := Mundo.nivel_mare()
	var f := _cena.instantiate() as Node3D
	f.scale = Vector3.ONE * 1.3
	add_child(f)
	var a := randf() * TAU
	var dir := Vector3(cos(a), 0, sin(a))
	var ini := Vector3(p.x, nivel - 0.05, p.z)
	var fim := ini + dir * 1.4
	f.global_position = ini
	respingo(ini)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var pos := ini.lerp(fim, t) + Vector3(0, sin(t * PI) * 0.75, 0)
		var prox := ini.lerp(fim, t + 0.02) + Vector3(0, sin((t + 0.02) * PI) * 0.75, 0)
		if is_instance_valid(f):
			f.global_position = pos
			f.look_at(prox, Vector3.UP)
	, 0.0, 1.0, 0.75)
	tw.tween_callback(func() -> void:
		respingo(fim)
		f.queue_free())


## Respingo de água (pulo de peixe, peixe escapando).
func respingo(p: Vector3) -> void:
	var r := GPUParticles3D.new()
	r.one_shot = true
	r.amount = 24
	r.lifetime = 0.6
	r.explosiveness = 0.95
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 35.0
	m.initial_velocity_min = 1.2
	m.initial_velocity_max = 2.6
	m.gravity = Vector3(0, -9.8, 0)
	m.scale_min = 0.5
	m.scale_max = 1.0
	r.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.85, 0.85, 0.8, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = mat
	r.draw_pass_1 = q
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(r)
	r.global_position = p
	r.emitting = true
	get_tree().create_timer(1.2).timeout.connect(r.queue_free)
