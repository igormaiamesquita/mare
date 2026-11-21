extends CharacterBody3D
## O catador, em primeira pessoa: anda, corre, atola, nada, enfia o braço na toca e carrega o balde.

enum Estado { ANDANDO, TOCA, SEGURANDO, OCUPADO, PILOTANDO }

const VEL_ANDAR := 3.2
const VEL_CORRER := 5.8
const PULO := 4.3
const GRAVIDADE := 12.0
const ALTURA_OLHOS := 1.62
const OLHOS_AGACHADO := 0.78
const DIST_TOCA := 0.55

var capacidade_balde := 10
var estado := Estado.ANDANDO
var fome := 70.0              # 100 = de barriga cheia
var estamina := 100.0
var estamina_max := 100.0
var saude := 100.0             # perigos tiram saúde; zerou, desmaia
var mancando := 0.0            # horas de jogo mancando (ferroada de arraia)
var muricoca := 0.0            # 0..1: quanto os mosquitos estão em cima
var lama_no_rosto := 0.0       # horas de proteção contra muriçoca
var boiando := false
var aratus := 0
var tem_tarrafa := false
var galochas := false          # calçadas: atola menos, arraia e bagre machucam menos
var _mira := -1.0
var _mira_alvo := Vector3.ZERO
var _mira_vis: MeshInstance3D
var _aviso_cardume := false
var _aviso_arraia := false
var _aviso_muricoca := 0.0
var _aviso_boiar := false
var agachado := false
var _capsula: CapsuleShape3D
var _forma: CollisionShape3D
var _subindo := false
var tem_balde := false
var caranguejos := 0
var peixes := 0
# mochila: 6 espaços; cada item empilha até um limite por espaço
const MOCHILA_ESPACOS := 6
const PILHA := {"peixe": 3, "lenha": 2, "farinha": 1, "farofa": 2,
	"helice": 1, "remo": 1, "cuia": 1, "galao": 1, "breu": 1, "motor": 1}
const TAMANHO := {"motor": 3}      # espaços que cada unidade ocupa (o resto ocupa 1)
var mochila := {"peixe": 0, "lenha": 0, "farinha": 0, "farofa": 1,
	"helice": 0, "remo": 0, "cuia": 0, "galao": 0, "breu": 0, "motor": 0}
var motor_limpo := false
var canoa = null
var _olhar := 0.0
var lenha: int:
	get:
		return mochila["lenha"]
	set(v):
		mochila["lenha"] = maxi(0, v)
var lenha_max: int:
	get:
		return lenha + cabe_na_mochila("lenha")
var farinha: bool:
	get:
		return mochila["farinha"] > 0
	set(v):
		mochila["farinha"] = 1 if v else 0
var comeu := false
var reputacao := 0
var atolado := 0.0
var nadando := false
var prof_agua := 0.0
var tempo_afogando := 0.0
var stats := {"pegos": 0, "soltos": 0, "pincadas": 0, "perdidos": 0}

var main
var hud
var cabeca: Node3D
var camera: Camera3D
var braco: Node3D
var balde_vis: Node3D
var crabs_vis: Array[Node3D] = []
var mao_crab: Node3D
var facao: Node3D
var _golpe := 0.0
var lanterna: SpotLight3D
var alvo = null
var texto_alvo := ""

var toca = null
var mg := {}
var segurando := {}
var _gastou := false
var _bob := 0.0
var luz_perto: OmniLight3D
## Atalhos 1–9 da barra de baixo ("" = livre, para coisas futuras).
const ATALHOS := ["facao", "tarrafa", "lanterna", "farofa", "farinha", "", "", "", ""]
var na_mao := "facao"          # o que está na mão direita: "facao" ou "tarrafa"
var tarrafa_vis: Node3D
var _botao_tarrafa := false
const LANTERNA := 6.0
var olhou := 0.0               # quanto o mouse já girou a câmera (primeiros passos)
var _tremor := 0.0
var _aviso_fome := false
var _aviso_atolado := false
var _aviso_mare := 0.0
var preso_na_lama := false
var _trava_decisao := 0.0
var construindo := false
var _fantasma: Node3D
var _fantasma_mat: StandardMaterial3D
var _lugar_ok := false
const LENHA_JIRAU := 2
const BRACO_BASE := Vector3(0.2, -0.3, -0.12)
const FACAO_BASE := Vector3(0.3, -0.34, -0.42)
const BALDE_BASE := Vector3(-0.36, -0.44, -0.6)


func _ready() -> void:
	add_to_group("jogador")
	var forma := CollisionShape3D.new()
	forma.name = "CollisionShape3D"
	_forma = forma
	var cap := CapsuleShape3D.new()
	_capsula = cap
	cap.radius = 0.3
	cap.height = 1.75
	forma.shape = cap
	forma.position.y = 0.875
	add_child(forma)
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.4

	cabeca = Node3D.new()
	cabeca.position.y = ALTURA_OLHOS
	add_child(cabeca)
	camera = Camera3D.new()
	camera.fov = float(Config.v["fov"])
	camera.near = 0.03
	camera.far = 700
	cabeca.add_child(camera)
	camera.current = true

	lanterna = SpotLight3D.new()
	lanterna.spot_range = 42.0
	lanterna.spot_angle = 34.0
	lanterna.spot_angle_attenuation = 0.6
	lanterna.spot_attenuation = 0.7
	lanterna.light_energy = 0.0
	lanterna.light_color = Color(1.0, 0.95, 0.85)
	lanterna.shadow_enabled = true
	lanterna.position = Vector3(0.15, -0.1, 0)
	camera.add_child(lanterna)
	# luz fraca em volta, junto com a lanterna: o que está perto (pés, mãos) não some no escuro
	luz_perto = OmniLight3D.new()
	luz_perto.omni_range = 6.0
	luz_perto.light_energy = 0.35
	luz_perto.light_color = Color(1.0, 0.95, 0.85)
	luz_perto.position = Vector3(0, -0.2, -0.6)
	luz_perto.visible = false
	camera.add_child(luz_perto)

	braco = _modelo("braco")
	camera.add_child(braco)
	braco.position = BRACO_BASE
	braco.rotation_degrees = Vector3(8, 6, 0)

	balde_vis = _modelo("balde")
	camera.add_child(balde_vis)
	balde_vis.position = BALDE_BASE
	balde_vis.scale = Vector3.ONE * 0.75
	balde_vis.rotation_degrees = Vector3(20, 0, -6)
	balde_vis.visible = false
	for i in capacidade_balde:
		var c := _modelo("caranguejo" if i % 3 != 2 else "peixe")
		balde_vis.add_child(c)
		c.position = Vector3(randf_range(-0.04, 0.04), 0.05 + i * 0.012, randf_range(-0.04, 0.04))
		c.scale = Vector3.ONE * 0.6
		c.rotation.y = randf() * TAU
		c.visible = false
		crabs_vis.append(c)

	facao = _modelo("facao")
	camera.add_child(facao)
	facao.position = FACAO_BASE
	facao.rotation_degrees = Vector3(35, -12, -20)
	tarrafa_vis = _modelo("tarrafa")
	camera.add_child(tarrafa_vis)
	tarrafa_vis.position = FACAO_BASE + Vector3(0.0, 0.2, -0.04)   # a mão segura no destorcedor; a rede pende
	tarrafa_vis.scale = Vector3.ONE * 0.32
	tarrafa_vis.rotation_degrees = Vector3(6, -20, -4)
	tarrafa_vis.visible = false

	mao_crab = _modelo("caranguejo")
	camera.add_child(mao_crab)
	mao_crab.position = Vector3(0.03, -0.2, -0.42)
	mao_crab.rotation_degrees = Vector3(40, 180, 0)
	mao_crab.scale = Vector3.ONE * 1.0
	mao_crab.visible = false


func _modelo(nome: String) -> Node3D:
	var n := (load("res://assets/%s.glb" % nome) as PackedScene).instantiate() as Node3D
	_sem_sombra(n)
	return n


func _sem_sombra(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_sem_sombra(c)


## Altura do chão onde você pisa: terreno, ou assoalho (palafita, rancho) se estiver em cima dele.
func chao_efetivo() -> float:
	var t := Terreno.altura(global_position.x, global_position.z)
	if is_on_floor() and global_position.y > t + 0.3:
		return global_position.y
	return t


func cheio() -> bool:
	return caranguejos + peixes + aratus >= capacidade_balde


func espacos_usados() -> int:
	var n := 0
	for item in mochila:
		n += ceili(float(mochila[item]) / PILHA[item]) * TAMANHO.get(item, 1)
	return n


## Quantos mais desse item ainda cabem na mochila.
func cabe_na_mochila(item: String) -> int:
	var pilha: int = PILHA[item]
	var tam: int = TAMANHO.get(item, 1)
	var livres := MOCHILA_ESPACOS - espacos_usados()
	var sobra: int = (pilha - mochila[item] % pilha) % pilha
	return (livres / tam) * pilha + sobra


func ocupar(sim: bool) -> void:
	estado = Estado.OCUPADO if sim else Estado.ANDANDO


func embarcar(c) -> void:
	canoa = c
	estado = Estado.PILOTANDO
	_olhar = 0.0
	velocity = Vector3.ZERO
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true


func desembarcar(p: Vector3) -> void:
	canoa = null
	estado = Estado.ANDANDO
	global_position = p
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = false
	Mundo.avisar("Desceu da canoa.")


func pilotando() -> bool:
	return estado == Estado.PILOTANDO


func cabe_peixe() -> bool:
	return (tem_balde and not cheio()) or cabe_na_mochila("peixe") > 0


func pegar_peixe() -> void:
	stats["peixes"] = stats.get("peixes", 0) + 1
	if tem_balde and not cheio():
		peixes += 1
		Mundo.avisar("Peixe no balde! (%d caranguejos, %d peixes)" % [caranguejos, peixes])
	else:
		mochila["peixe"] += 1
		Mundo.avisar("Balde cheio: o peixe foi para a mochila (%d na mochila)" % mochila["peixe"])


## Inventário: passar peixe entre balde e mochila, comer farofa.
func peixe_para_mochila() -> bool:
	if peixes <= 0 or cabe_na_mochila("peixe") <= 0:
		return false
	peixes -= 1
	mochila["peixe"] += 1
	return true


func peixe_para_balde() -> bool:
	if mochila["peixe"] <= 0 or not tem_balde or cheio():
		return false
	mochila["peixe"] -= 1
	peixes += 1
	return true


func comer_farofa() -> bool:
	if mochila["farofa"] <= 0:
		return false
	mochila["farofa"] -= 1
	fome = minf(100.0, fome + 20.0)
	estamina = minf(estamina_max, estamina + 30.0)
	Mundo.avisar("Comeu um punhado de farofa. Deu para enganar a fome.")
	return true


## O pé está no chão de terra (e não numa rampa, trapiche ou assoalho)?
func _pisa_no_chao() -> bool:
	if not is_on_floor():
		return true
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y > 0.5 and c.get_collider() != main.corpo_chao:
			return false
	return true


## Segura CTRL (ou Option no Mac) para agachar: fica baixo e passa embaixo das coisas.
func _agachar() -> void:
	var quer := Input.is_action_pressed("agachar") and not nadando
	if quer and not agachado:
		agachado = true
		_capsula.height = 1.0
		_forma.position.y = 0.5
	elif not quer and agachado:
		# só levanta se tiver espaço em cima
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.9, 0), global_position + Vector3(0, 1.85, 0))
		q.exclude = [get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			agachado = false
			_capsula.height = 1.75
			_forma.position.y = 0.875


## ESPAÇO perto de uma borda alta (trapiche, assoalho, pedra): agarra e sobe. Funciona nadando também.
func _agarrar_borda() -> bool:
	var frente := -global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var espaco := get_world_3d().direct_space_state
	var pe := global_position.y
	var alcance := 2.15 if nadando else 1.9
	for d in [0.55, 0.8, 1.05]:
		var topo: Vector3 = global_position + frente * float(d)
		var q := PhysicsRayQueryParameters3D.create(Vector3(topo.x, pe + alcance + 0.3, topo.z), Vector3(topo.x, pe + 0.45, topo.z))
		q.exclude = [get_rid()]
		var r := espaco.intersect_ray(q)
		if r.is_empty():
			continue
		var n: Vector3 = r["normal"]
		var y: float = (r["position"] as Vector3).y
		if n.y < 0.7 or y - pe < 0.45 or y - pe > alcance:
			continue
		# espaço livre em cima da borda
		var cima := PhysicsRayQueryParameters3D.create(r["position"] + Vector3(0, 0.05, 0), r["position"] + Vector3(0, 1.7, 0))
		cima.exclude = [get_rid()]
		if not espaco.intersect_ray(cima).is_empty():
			continue
		_subir_para(r["position"] + frente * 0.25 + Vector3(0, 0.05, 0))
		return true
	return false


func _subir_para(destino: Vector3) -> void:
	_subindo = true
	estado = Estado.OCUPADO
	estamina = maxf(0.0, estamina - 6.0)
	velocity = Vector3.ZERO
	var ini := global_position
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		# primeiro sobe, depois vai para frente
		var subida := clampf(t * 1.6, 0.0, 1.0)
		var avanco := clampf((t - 0.45) / 0.55, 0.0, 1.0)
		global_position = Vector3(lerpf(ini.x, destino.x, avanco), lerpf(ini.y, destino.y, subida), lerpf(ini.z, destino.z, avanco))
	, 0.0, 1.0, 0.7)
	await tw.finished
	estado = Estado.ANDANDO
	_subindo = false


func andando() -> bool:
	return estado == Estado.ANDANDO


func yaw_bussola() -> float:
	var f := -global_transform.basis.z
	return atan2(f.x, -f.z)


func _unhandled_input(e: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not Mundo.rodando:
		return
	if e is InputEventMouseMotion and estado == Estado.PILOTANDO:
		var mp := e as InputEventMouseMotion
		_olhar = clampf(_olhar - mp.relative.x * Config.sens(), -2.2, 2.2)
		cabeca.rotation.x = clampf(cabeca.rotation.x - mp.relative.y * Config.sens() * _inv_y(), -1.2, 1.2)
	elif e is InputEventMouseMotion and (estado == Estado.ANDANDO or estado == Estado.SEGURANDO):
		var mm := e as InputEventMouseMotion
		rotate_y(-mm.relative.x * Config.sens())
		cabeca.rotation.x = clampf(cabeca.rotation.x - mm.relative.y * Config.sens() * _inv_y(), -1.45, 1.45)
		olhou += mm.relative.length()


func _physics_process(delta: float) -> void:
	if not Mundo.rodando:
		_visual(delta)
		return
	_gastou = false
	match estado:
		Estado.ANDANDO:
			_mover(delta)
			_procurar_alvo()
			if construindo:
				_atualizar_fantasma()
			_teclas()
		Estado.TOCA:
			_minigame(delta)
		Estado.SEGURANDO:
			_mover(delta)
			_decidir()
		Estado.OCUPADO:
			velocity = Vector3.ZERO
		Estado.PILOTANDO:
			velocity = Vector3.ZERO
			if canoa != null:
				global_position = canoa.assento() - Vector3(0, 0.75, 0)
				rotation.y = canoa.rotation.y + _olhar
				prof_agua = 0.0
				nadando = false
	_corpo(delta)
	_visual(delta)


# ------------------------------------------------------------------ andar

func _mover(delta: float) -> void:
	var entrada := Input.get_vector("esquerda", "direita", "frente", "tras")
	var dir := (global_transform.basis * Vector3(entrada.x, 0, entrada.y))
	dir.y = 0.0
	dir = dir.normalized()
	var x := global_position.x
	var z := global_position.z
	var chao := chao_efetivo()
	var nivel := Mundo.nivel_mare()
	prof_agua = maxf(0.0, nivel - chao)
	nadando = prof_agua > 1.35
	# lama só quando o pé está na lama de verdade (não em cima de rampa, trapiche ou assoalho)
	var na_lama := Terreno.e_lama(x, z) and global_position.y < Terreno.altura(x, z) + 0.3 and not nadando and _pisa_no_chao()
	preso_na_lama = na_lama and prof_agua > 0.45
	var correndo := Input.is_action_pressed("correr") and estamina > 5.0 and entrada.length() > 0.1
	boiando = nadando and entrada.length() < 0.1

	var vel := VEL_CORRER if correndo else VEL_ANDAR
	if mancando > 0.0:
		vel *= 0.6
	_agachar()
	if agachado:
		vel *= 0.45
		correndo = false
	if na_lama:
		vel *= 0.62
	if preso_na_lama:
		vel *= 0.55   # com água por cima, a lama segura a perna
	if prof_agua > 0.15 and not nadando:
		vel *= lerpf(1.0, 0.45, clampf((prof_agua - 0.15) / 1.1, 0.0, 1.0))
	if nadando:
		vel = 2.7 if correndo else 1.6
	vel *= 1.0 - minf(0.25, carga() / 40.0)

	# lama mole: a perna afunda e é preciso puxar (espaço)
	if na_lama and prof_agua < 0.5 and Terreno.atoleiro(x, z):
		atolado = minf(1.0, atolado + delta * (0.16 if galochas else 0.3) * (entrada.length() + 0.25))
		if atolado > 0.3 and not _aviso_atolado:
			_aviso_atolado = true
			Mundo.avisar("Atolou na lama mole! Aperte ESPAÇO para puxar as pernas.", "perigo")
	else:
		atolado = maxf(0.0, atolado - delta * 0.6)
		if atolado == 0.0:
			_aviso_atolado = false
	vel *= 1.0 - atolado * 0.88

	# força: correr cansa; nadar devagar cansa pouco; boiar parado descansa (se não estiver pesado)
	if correndo:
		estamina -= (9.0 if nadando else 6.0) * delta
		_gastou = true
	elif nadando and not boiando:
		estamina -= (1.2 + carga() * 0.08) * delta
		_gastou = true
	elif boiando:
		if carga() > 8.0:
			estamina -= (carga() - 8.0) * 0.12 * delta
			_gastou = true
		else:
			estamina += 3.0 * delta
			_gastou = true
			if not _aviso_boiar:
				_aviso_boiar = true
				Mundo.avisar("Parado na água você boia e descansa. Muito peso na mochila e no balde atrapalha.")
	if preso_na_lama and entrada.length() > 0.1:
		estamina -= 1.0 * delta
		_gastou = true
	_perigos(delta, correndo, chao)

	var h := Vector3(velocity.x, 0, velocity.z).lerp(dir * vel, clampf(delta * 10.0, 0.0, 1.0))
	velocity.x = h.x
	velocity.z = h.z

	if Input.is_action_just_pressed("pular") and atolado <= 0.05 and not _subindo and _agarrar_borda():
		return
	if nadando:
		var alvo_y := nivel - 1.45
		velocity.y = (alvo_y - global_position.y) * 4.0
		if estamina <= 0.0:
			# sem força: afunda um pouco e engole água (tira saúde aos poucos)
			velocity.y -= 0.6
			tempo_afogando += delta
			dano(6.0 * delta, "")
			if tempo_afogando < delta * 1.5:
				Mundo.avisar("Sem força! Você está engolindo água. Pare de nadar para boiar, ou largue peso (G larga o balde).", "perigo")
			if saude <= 0.0:
				return
		else:
			tempo_afogando = 0.0
	else:
		tempo_afogando = 0.0
		if not is_on_floor():
			velocity.y -= GRAVIDADE * delta * (0.4 if prof_agua > 0.9 else 1.0)
		if Input.is_action_just_pressed("pular"):
			if atolado > 0.05:
				atolado = maxf(0.0, atolado - (0.45 if galochas else 0.3))
				estamina -= 3.0
				_gastou = true
				_tremor = 0.12
			elif is_on_floor() and estamina > 4.0:
				velocity.y = PULO
				estamina -= 4.0
				_gastou = true
	move_and_slide()
	# não deixa sair do mapa nem ficar abaixo do chão
	global_position.x = clampf(global_position.x, -125.0, 125.0)
	global_position.z = clampf(global_position.z, -125.0, 125.0)
	var chao2 := Terreno.altura(global_position.x, global_position.z)
	if global_position.y < chao2 - 0.5:
		global_position.y = chao2


func _inv_y() -> float:
	return -1.0 if Config.v["inverter_y"] else 1.0


func _procurar_alvo() -> void:
	var melhor = null
	var melhor_ponto := 0.72
	var frente := -camera.global_transform.basis.z
	for n in get_tree().get_nodes_in_group("interagivel"):
		var p: Vector3 = n.global_position
		var plano := Vector2(p.x - global_position.x, p.z - global_position.z).length()
		if plano > n.raio_interacao or absf(p.y - (camera.global_position.y - 0.8)) > 2.0:
			continue
		var ponto := frente.dot((p + Vector3(0, 0.15, 0) - camera.global_position).normalized())
		if ponto > melhor_ponto:
			melhor_ponto = ponto
			melhor = n
	alvo = melhor
	texto_alvo = alvo.texto_interacao(self) if alvo != null else ""


## Tem o item do atalho? (para a barra mostrar apagado o que falta)
func tem_atalho(nome: String) -> bool:
	match nome:
		"facao", "lanterna":
			return true
		"tarrafa":
			return tem_tarrafa
		"farofa":
			return mochila["farofa"] > 0
		"farinha":
			return farinha
	return false


func usar_atalho(i: int) -> void:
	var nome: String = ATALHOS[i]
	match nome:
		"facao":
			na_mao = "facao"
		"tarrafa":
			if tem_tarrafa:
				na_mao = "tarrafa"
				Mundo.avisar("Tarrafa na mão: SEGURE o botão do mouse para mirar e SOLTE para jogar.")
			else:
				Mundo.avisar("Você não tem tarrafa. Tem uma no rancho.")
		"lanterna":
			lanterna.light_energy = 0.0 if lanterna.light_energy > 0.0 else LANTERNA
		"farofa":
			if not comer_farofa():
				Mundo.avisar("Acabou a farofa.")
		"farinha":
			if not comer_farinha():
				Mundo.avisar("A cuia está vazia. Tem farinha no saco do rancho.")


## Um punhado de farinha pura: engana um pouco a fome.
func comer_farinha() -> bool:
	if not farinha:
		return false
	farinha = false
	fome = minf(100.0, fome + 10.0)
	Mundo.avisar("Comeu um punhado de farinha d'água.")
	return true


func _teclas() -> void:
	for i in 9:
		if Input.is_action_just_pressed("atalho_%d" % (i + 1)):
			usar_atalho(i)
	if Input.is_action_just_pressed("lanterna"):
		lanterna.light_energy = 0.0 if lanterna.light_energy > 0.0 else LANTERNA
	if Input.is_action_just_pressed("balde") and tem_balde:
		largar_balde()
	if Input.is_action_just_pressed("construir"):
		construindo = not construindo
		if construindo:
			Mundo.avisar("Construir: jirau-fogão. Escolha um lugar (verde) e aperte E. B cancela.")
		elif _fantasma != null:
			_fantasma.visible = false
	_tarrafa()
	if construindo:
		if Input.is_action_just_pressed("interagir") and _lugar_ok:
			_construir_jirau()
		return
	if Input.is_action_just_pressed("interagir") and alvo != null and texto_alvo.begins_with("[E]"):
		alvo.interagir(self)


# ------------------------------------------------------------------ corpo

func _corpo(delta: float) -> void:
	var horas := delta * Mundo.acelerar / Mundo.SEGUNDOS_REAIS_POR_HORA
	fome = maxf(0.0, fome - horas * 3.2)
	estamina_max = 100.0 if fome > 25.0 else lerpf(30.0, 100.0, fome / 25.0)
	if not _gastou:
		estamina += delta * (20.0 if prof_agua < 0.5 else 12.0)
	# saúde volta devagar quando está alimentado
	if fome > 40.0 and estado != Estado.OCUPADO:
		saude = minf(100.0, saude + horas * 4.0)
	mancando = maxf(0.0, mancando - horas)
	lama_no_rosto = maxf(0.0, lama_no_rosto - horas)
	estamina = clampf(estamina, 0.0, estamina_max)
	if fome < 25.0 and not _aviso_fome:
		_aviso_fome = true
		Mundo.avisar("Você está com fome. A força está acabando.", "perigo")
	if fome > 35.0:
		_aviso_fome = false
	# a maré vai cobrir onde você está?
	_aviso_mare -= delta
	if Mundo.mare_subindo() and _aviso_mare <= 0.0 and estado != Estado.OCUPADO and estado != Estado.PILOTANDO:
		var chao := chao_efetivo()
		var falta := Mundo.horas_ate(chao + 1.2)
		if chao < 2.3 and falta >= 0.0 and falta < 0.75:
			_aviso_mare = 25.0
			if falta < 0.02:
				Mundo.avisar("A água já está no peito! Volte para o rancho ou suba num teso.", "perigo")
			else:
				Mundo.avisar("A maré está subindo! Em %s a água chega no peito aqui. Volte para o rancho ou suba num teso." % Mundo.texto_duracao(falta), "perigo")


func carga() -> float:
	return (caranguejos + peixes + aratus + mochila["peixe"]) * 0.4 + lenha * 1.5 + mochila["motor"] * 4.0 + mochila["galao"] * 2.0


## Perigo tira saúde. Zerou: desmaia e acorda no rancho.
func dano(valor: float, motivo: String) -> void:
	saude = maxf(0.0, saude - valor)
	if motivo != "":
		Mundo.avisar(motivo, "perigo")
		hud.dano()
		_tremor = maxf(_tremor, 0.35)
	if saude <= 0.0 and estado != Estado.OCUPADO:
		desmaiar("Você desmaiou e foi achado por um pescador, que te levou ao rancho. Perdeu o que carregava.")


## Arraia na água rasa, muriçoca no mangue ao anoitecer e à noite.
func _perigos(delta: float, correndo: bool, chao: float) -> void:
	var x := global_position.x
	var z := global_position.z
	# ARRAIA: fica enterrada na água rasa de fundo de lama/areia. Correndo, pisa nela.
	var raso := prof_agua > 0.12 and prof_agua < 0.8 and not nadando
	if raso and not _aviso_arraia:
		_aviso_arraia = true
		Mundo.avisar("Água rasa: arraia gosta de ficar enterrada aqui. Ande devagar, arrastando o pé (sem correr).")
	if raso and correndo and Terreno.zona(x, z, chao).r + Terreno.zona(x, z, chao).g > 0.5:
		if randf() < delta * (0.08 if galochas else 0.25):
			mancando = 1.0 if galochas else 2.0
			if galochas:
				dano(15.0, "Ferroada de arraia! A galocha segurou boa parte, mas doeu. Na água rasa, não corra.")
			else:
				dano(35.0, "Ferroada de arraia! Dor forte no pé: você vai mancar por um tempo. Na água rasa, não corra.")
	# MURIÇOCA: amanhecer, entardecer e noite, dentro do mangue; fogo e lama no rosto espantam
	var hora := Mundo.hora
	var hora_ruim := hora < 6.6 or hora > 17.3
	var no_mangue := chao < 2.1 and not nadando and Mundo.chuva < 0.3
	var perto_fogo := false
	for f in get_tree().get_nodes_in_group("fogao"):
		if f.aceso and f.global_position.distance_to(global_position) < 7.0:
			perto_fogo = true
	var alvo_m := 1.0 if (hora_ruim and no_mangue and not perto_fogo and lama_no_rosto <= 0.0) else 0.0
	muricoca = move_toward(muricoca, alvo_m, delta * (0.08 if alvo_m > muricoca else 0.3))
	_aviso_muricoca -= delta
	if muricoca > 0.5 and _aviso_muricoca <= 0.0:
		_aviso_muricoca = 60.0
		Mundo.avisar("Nuvem de muriçoca! Ficar aqui vai te cansar. Passe lama no rosto (inventário) ou fique perto da fumaça do fogo.", "perigo")
	if muricoca > 0.5:
		estamina -= muricoca * 1.5 * delta
		dano(muricoca * 0.4 * delta, "")


func passar_lama_no_rosto() -> bool:
	var chao := Terreno.altura(global_position.x, global_position.z)
	if Terreno.zona(global_position.x, global_position.z, chao).r < 0.5:
		return false
	lama_no_rosto = 3.0
	muricoca = 0.0
	Mundo.avisar("Passou lama no rosto e nos braços. A muriçoca vai te deixar em paz por umas horas.")
	return true


## Comer o que cozinhou. Com farinha sustenta mais, enche a força e dá saúde; sem farinha também alimenta.
func comer(n: int, com_farinha: bool) -> void:
	if com_farinha:
		fome = minf(100.0, fome + n * 12.0)
		estamina = estamina_max
		saude = minf(100.0, saude + 10.0)
		farinha = false
	else:
		fome = minf(100.0, fome + n * 8.0)
		estamina = minf(estamina_max, estamina + 40.0)
	comeu = true


# ------------------------------------------------------------------ tarrafa (T)

func _tarrafa() -> void:
	var delta := get_physics_process_delta_time()
	if tem_tarrafa and not _aviso_cardume and main.peixes.cardume_perto(global_position, 12.0):
		_aviso_cardume = true
		Mundo.avisar("Cardume perto! Tarrafa na mão (2), SEGURE o botão do mouse (ou T) para mirar e SOLTE para jogar.")
	var mouse: bool = na_mao == "tarrafa" and estado == Estado.ANDANDO and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_botao_tarrafa = Input.is_action_pressed("tarrafa") or mouse
	if Input.is_action_just_pressed("tarrafa") and tem_tarrafa:
		na_mao = "tarrafa"
	if Input.is_action_just_pressed("tarrafa") and not tem_tarrafa:
		Mundo.avisar("Você não tem tarrafa. Tem uma pendurada no rancho.")
		return
	if not tem_tarrafa:
		return
	if _botao_tarrafa and not nadando and atolado < 0.2:
		if _mira < 0.0:
			_mira = 0.0
		_mira = minf(1.0, _mira + delta * 0.9)
		var frente := -global_transform.basis.z
		frente.y = 0.0
		_mira_alvo = global_position + frente.normalized() * lerpf(3.0, 9.0, _mira)
		_mira_alvo.y = maxf(Mundo.nivel_mare(), Terreno.altura(_mira_alvo.x, _mira_alvo.z)) + 0.04
		if _mira_vis == null:
			_mira_vis = MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(4.8, 4.8)
			q.orientation = PlaneMesh.FACE_Y
			_mira_vis.mesh = q
			var m := ShaderMaterial.new()
			m.shader = load("res://shaders/anel_toca.gdshader")
			m.set_shader_parameter("cor", Color(0.9, 0.95, 1.0))
			m.set_shader_parameter("forca", 1.2)
			_mira_vis.material_override = m
			main.add_child(_mira_vis)
		_mira_vis.visible = true
		_mira_vis.global_position = _mira_alvo
		texto_alvo = "Mirando a tarrafa: %.0f m   ·   SOLTE para jogar" % lerpf(3.0, 9.0, _mira)
	elif _mira >= 0.0:
		_mira = -1.0
		if _mira_vis != null:
			_mira_vis.visible = false
		_lancar_tarrafa(_mira_alvo)


func _lancar_tarrafa(alvo_p: Vector3) -> void:
	estado = Estado.OCUPADO
	estamina -= 6.0
	var rede := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.06
	cone.bottom_radius = 2.2
	cone.height = 0.45
	cone.radial_segments = 40
	cone.rings = 6
	cone.cap_bottom = false
	rede.mesh = cone
	rede.material_override = _material_rede()
	main.add_child(rede)
	var ini := camera.global_position + (-camera.global_transform.basis.z) * 0.6
	rede.global_position = ini
	rede.scale = Vector3.ONE * 0.15
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(t: float) -> void:
		rede.global_position = ini.lerp(alvo_p + Vector3(0, 0.25, 0), t) + Vector3(0, sin(t * PI) * 1.6, 0)
	, 0.0, 1.0, 0.6)
	tw.tween_property(rede, "scale", Vector3.ONE, 0.6)
	await tw.finished
	var na_agua := Mundo.nivel_mare() - Terreno.altura(alvo_p.x, alvo_p.z) > 0.25
	if na_agua:
		main.peixes.respingo(alvo_p)
	var t2 := create_tween()
	t2.tween_property(rede, "global_position", alvo_p + Vector3(0, -0.15, 0), 0.6)
	await t2.finished
	await get_tree().create_timer(0.5).timeout
	var pegos := 0
	if na_agua:
		pegos = main.peixes.pescar_tarrafa(alvo_p, 2.7)
		for pc in main.pocas:
			for f in pc.peixes.duplicate():
				if is_instance_valid(f) and Vector2(f.global_position.x - alvo_p.x, f.global_position.z - alvo_p.z).length() < 2.7:
					pc.peixes.erase(f)
					f.queue_free()
					pegos += 1
	var guardados := 0
	for i in pegos:
		if cabe_peixe():
			pegar_peixe()
			guardados += 1
	rede.queue_free()
	estado = Estado.ANDANDO
	if not na_agua:
		Mundo.avisar("A tarrafa caiu na lama. Ela precisa de água para pescar.")
	elif pegos == 0:
		Mundo.avisar("A tarrafa voltou vazia. Mire em cima do cardume (os peixes nadam na superfície).")
	elif guardados < pegos:
		Mundo.avisar("Tarrafa cheia: %d peixes! Só couberam %d no balde e na mochila." % [pegos, guardados], "objetivo")
	else:
		Mundo.avisar("Tarrafa boa: %d peixes!" % pegos, "objetivo")


static var _mat_rede: StandardMaterial3D

func _material_rede() -> StandardMaterial3D:
	if _mat_rede != null:
		return _mat_rede
	# malha em losango (a mesma ideia da textura do modelo da tarrafa)
	var tam := 128
	var n := 4.0
	var img := Image.create_empty(tam, tam, false, Image.FORMAT_RGBA8)
	for y in tam:
		for x in tam:
			var a := (float(x) + float(y)) / tam * n
			var b := (float(x) - float(y)) / tam * n
			var d := minf(absf(a - roundf(a)), absf(b - roundf(b)))
			img.set_pixel(x, y, Color(0.84, 0.82, 0.74, 1.0) if d < 0.06 else Color(0, 0, 0, 0))
	img.generate_mipmaps()
	_mat_rede = StandardMaterial3D.new()
	_mat_rede.albedo_texture = ImageTexture.create_from_image(img)
	_mat_rede.uv1_scale = Vector3(18, 5, 1)
	_mat_rede.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_mat_rede.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_rede.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return _mat_rede


# ------------------------------------------------------------------ construir

func _atualizar_fantasma() -> void:
	if _fantasma == null:
		_fantasma = Node3D.new()
		_fantasma_mat = StandardMaterial3D.new()
		_fantasma_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_fantasma_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_fantasma_mat.no_depth_test = false
		for nome in ["jirau_pes", "jirau_talos", "jirau_lama"]:
			var parte := (load("res://assets/%s.glb" % nome) as PackedScene).instantiate()
			_pintar(parte)
			_fantasma.add_child(parte)
		main.add_child(_fantasma)
	var frente := -global_transform.basis.z
	frente.y = 0.0
	var pos := global_position + frente.normalized() * 1.7
	pos.y = Terreno.altura(pos.x, pos.z)
	_fantasma.global_position = pos
	_fantasma.rotation.y = rotation.y
	_fantasma.visible = true
	var motivo: String = main.motivo_jirau_invalido(pos)
	if motivo == "" and lenha < LENHA_JIRAU:
		motivo = "Precisa de %d feixes de lenha na mochila (tem %d)" % [LENHA_JIRAU, lenha]
	_lugar_ok = motivo == ""
	_fantasma_mat.albedo_color = Color(0.35, 1.0, 0.45, 0.4) if _lugar_ok else Color(1.0, 0.3, 0.25, 0.4)
	if _lugar_ok:
		texto_alvo = "[E] Construir jirau-fogão aqui (%d lenha)     ·     B cancela" % LENHA_JIRAU
	else:
		texto_alvo = motivo + "     ·     B cancela"


func _pintar(n: Node) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = _fantasma_mat
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_pintar(c)


func _construir_jirau() -> void:
	var pos := _fantasma.global_position
	var yaw := _fantasma.rotation.y
	construindo = false
	_fantasma.visible = false
	lenha -= LENHA_JIRAU
	estado = Estado.OCUPADO
	await main.construir_jirau(pos, yaw)
	estado = Estado.ANDANDO


func golpear() -> void:
	na_mao = "facao"
	_golpe = 0.8
	_tremor = 0.08


# ------------------------------------------------------------------ balde

func largar_balde() -> void:
	var pos := global_position - global_transform.basis.z * 0.7
	pos.y = maxf(Terreno.altura(pos.x, pos.z), global_position.y)
	var it = main.criar_item("balde", pos, caranguejos + aratus)
	it.peixes = peixes
	aratus = 0
	caranguejos = 0
	peixes = 0
	tem_balde = false
	Mundo.avisar("Largou o balde. Cuidado: a maré leva o que fica no chão.")


func pegar_balde(conteudo: int, n_peixes: int = 0) -> void:
	tem_balde = true
	caranguejos = conteudo
	peixes = n_peixes


# ------------------------------------------------------------------ toca (mini-jogo)

func iniciar_toca(t) -> void:
	toca = t
	estado = Estado.TOCA
	mg = {"prof": 0.0, "fase": "procurando", "agulha": 0.0, "alvo": 0.0, "tam": 1.0, "vel": 3.0, "erros": 0,
		"tensao": 0.0, "progresso": 0.0, "puxao": 0.0, "pegada": 0, "prox_puxao": 1.0, "vazia": false, "perto": 0.0}
	var para: Vector3 = t.global_position - global_position
	para.y = 0.0
	var dir := para.normalized() if para.length() > 0.05 else -global_transform.basis.z
	var pos: Vector3 = t.global_position - dir * DIST_TOCA
	pos.y = Terreno.altura(pos.x, pos.z)
	global_position = pos
	velocity = Vector3.ZERO
	look_at(Vector3(t.global_position.x, global_position.y, t.global_position.z), Vector3.UP)
	cabeca.rotation.x = -atan2(OLHOS_AGACHADO - 0.02, DIST_TOCA)
	braco.rotation = Vector3.ZERO
	hud.mostrar_toca(true)


func sair_toca(msg: String = "") -> void:
	estado = Estado.ANDANDO
	toca = null
	cabeca.rotation.x = -0.35
	braco.rotation_degrees = Vector3(8, 6, 0)
	hud.mostrar_toca(false)
	if msg != "":
		Mundo.avisar(msg, "perigo")


func _minigame(delta: float) -> void:
	var t = toca
	if t == null or not is_instance_valid(t):
		sair_toca()
		return
	if t.coberta():
		sair_toca("A maré cobriu a toca!")
		return
	var segurando_e := Input.is_action_pressed("interagir")
	var apertou_e := Input.is_action_just_pressed("interagir")
	var recolhendo := Input.is_action_pressed("tras") or Input.is_action_pressed("recolher")
	match mg["fase"]:
		# 1) PROCURAR: segura E e o braço desce na toca
		"procurando":
			if recolhendo:
				mg["prof"] = maxf(0.0, mg["prof"] - 0.7 * delta)
				if mg["prof"] <= 0.0:
					sair_toca()
					return
			elif segurando_e and estamina > 1.0:
				mg["prof"] = minf(t.fundo, mg["prof"] + 0.38 * delta)
				estamina -= 5.0 * delta
				_gastou = true
			mg["perto"] = 0.0
			if t.ocupada:
				mg["perto"] = clampf(1.0 - absf(mg["prof"] - t.profundidade) / 0.35, 0.0, 1.0)
				if absf(mg["prof"] - t.profundidade) < 0.04:
					mg["fase"] = "agarrar"
					mg["agulha"] = randf() * TAU
					mg["alvo"] = randf() * TAU
					mg["tam"] = deg_to_rad(110.0 if t.miudo else 95.0)
					mg["vel"] = 3.2 if not t.miudo else 2.6
					mg["erros"] = 0
					_tremor = 0.2
			elif mg["prof"] >= t.fundo - 0.01 and not mg["vazia"]:
				mg["vazia"] = true
				Mundo.avisar("Chegou no fundo da toca. Está vazia. Aperte S para tirar o braço.")
		# 2) AGARRAR: o ponteiro gira; ESPAÇO na hora certa. Quanto mais no centro do verde, mais forte a pegada.
		"agarrar":
			mg["agulha"] = fposmod(mg["agulha"] + mg["vel"] * delta, TAU)
			if recolhendo:
				mg["fase"] = "procurando"
				mg["prof"] = maxf(0.0, mg["prof"] - 0.1)
			elif Input.is_action_just_pressed("agarrar"):
				var dif := absf(wrapf(mg["agulha"] - mg["alvo"], -PI, PI))
				var dif_pinca := absf(wrapf(mg["agulha"] - mg["alvo"] - PI, -PI, PI))
				if dif < mg["tam"] * 0.5:
					var quanto: float = dif / (mg["tam"] * 0.5)
					mg["pegada"] = 3 if quanto < 0.34 else (2 if quanto < 0.68 else 1)
					Mundo.avisar(["", "Pegada FRACA: cuidado, ele pode escapar.", "Pegada MÉDIA: segura bem, mas pode afrouxar.", "Pegada FORTE: agora ele não escapa!"][mg["pegada"]], "perigo" if mg["pegada"] == 1 else "info")
					mg["fase"] = "puxando"
					mg["tensao"] = 0.3
					mg["progresso"] = 0.0
					mg["puxao"] = 0.0
					mg["prox_puxao"] = randf_range(0.8, 1.6)
					_tremor = 0.1
				elif dif_pinca < deg_to_rad(45.0):
					_pincada()
				else:
					mg["erros"] += 1
					_tremor = 0.08
					if mg["erros"] >= 3:
						if randf() < 0.4 and main.fuga_toca_vizinha(t):
							sair_toca("Ele fugiu pela toca vizinha e saiu correndo! Corra atrás!")
							return
						Mundo.avisar("Ele se assustou e foi mais para o fundo.", "perigo")
						t.profundidade = minf(t.fundo - 0.02, t.profundidade + 0.1)
						mg["fase"] = "procurando"
					else:
						Mundo.avisar("Escorregou! Ele está agitado.")
						mg["tam"] *= 0.85
						mg["vel"] *= 1.12
						mg["alvo"] = randf() * TAU
		# 3) PUXAR: segura E para puxar; quando ele puxar de volta, solta.
		# Pegada forte: ele nunca escapa, no máximo puxa de volta. Média: afrouxa para fraca. Fraca: pode escapar.
		"puxando":
			mg["prox_puxao"] -= delta
			if mg["puxao"] > 0.0:
				mg["puxao"] -= delta
			elif mg["prox_puxao"] <= 0.0:
				mg["puxao"] = randf_range(0.5, 0.8)
				mg["prox_puxao"] = randf_range(1.0, 1.8) + mg["puxao"]
			var puxando_ele: bool = mg["puxao"] > 0.0
			if segurando_e:
				mg["tensao"] += (1.6 if puxando_ele else 0.45) * delta
				estamina -= 4.0 * delta
				_gastou = true
			else:
				mg["tensao"] -= 0.7 * delta
				if puxando_ele:
					mg["progresso"] = maxf(0.0, mg["progresso"] - 0.08 * delta)
			mg["tensao"] = clampf(mg["tensao"], 0.0, 1.0)
			var tensao: float = mg["tensao"]
			if segurando_e and not puxando_ele and tensao > 0.15:
				mg["progresso"] += [0.0, 0.34, 0.42, 0.52][mg["pegada"]] * delta
			mg["prof"] = t.profundidade * (1.0 - mg["progresso"])
			if tensao >= 1.0:
				_tremor = 0.25
				match int(mg["pegada"]):
					3:
						Mundo.avisar("Ele deu um puxão, mas você segurou firme. Puxe de novo!")
						mg["progresso"] = maxf(0.0, mg["progresso"] - 0.15)
						mg["tensao"] = 0.55
					2:
						Mundo.avisar("Ele puxou forte e a pegada afrouxou! Agora está FRACA.", "perigo")
						mg["pegada"] = 1
						mg["progresso"] = maxf(0.0, mg["progresso"] - 0.1)
						mg["tensao"] = 0.5
					_:
						if randf() < 0.35 and main.fuga_toca_vizinha(t):
							sair_toca("A pegada estava fraca: ele escapou e saiu pela toca vizinha! Corra atrás!")
							return
						Mundo.avisar("A pegada estava fraca e ele escapou para o fundo.", "perigo")
						t.profundidade = minf(t.fundo - 0.02, t.profundidade + 0.12)
						mg["fase"] = "procurando"
						mg["prof"] = maxf(0.0, mg["prof"] - 0.12)
			elif mg["progresso"] >= 1.0:
				var femea: bool = t.femea
				var miudo: bool = t.miudo
				t.esvaziar()
				segurar_caranguejo(femea, miudo, "Tirou o caranguejo da toca!")
				return
	# braço sai do ombro direito e entra na toca (a toca desce inclinada)
	var prof: float = mg["prof"]
	var frente_h := -global_transform.basis.z
	var mao_w: Vector3 = t.global_position + Vector3(0, 0.02, 0) + Vector3.DOWN * prof * 0.9 + frente_h * prof * 0.4
	if mg["fase"] == "agarrar" or (mg["fase"] == "puxando" and mg["puxao"] > 0.0):
		mao_w += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.008
	var ombro_w := camera.to_global(Vector3(0.3, -0.42, 0.05))
	var d := (mao_w - ombro_w).normalized()
	braco.global_position = braco.global_position.lerp(mao_w - d * 0.62, clampf(delta * 14.0, 0.0, 1.0))
	braco.look_at(braco.global_position + d, camera.global_transform.basis.y)


func _pincada() -> void:
	stats["pincadas"] += 1
	estamina -= 10.0
	_gastou = true
	dano(8.0, "AI! Levou uma pinçada!")
	_tremor = 0.6
	mg["prof"] = maxf(0.0, mg["prof"] - 0.22)
	mg["fase"] = "procurando"
	toca.profundidade = minf(toca.fundo - 0.02, toca.profundidade + 0.08)


func segurar_caranguejo(femea: bool, miudo: bool, msg: String) -> void:
	if estado == Estado.TOCA:
		hud.mostrar_toca(false)
	toca = null
	estado = Estado.SEGURANDO
	segurando = {"femea": femea, "miudo": miudo}
	_trava_decisao = 0.7   # evita guardar sem querer quem ainda está apertando E
	cabeca.rotation.x = -0.25
	braco.position = BRACO_BASE
	braco.rotation_degrees = Vector3(8, 6, 0)
	var desc := "Macho graúdo! Bom para a panela."
	if femea:
		desc = "É uma fêmea (avental largo). O certo é soltar, para o mangue continuar dando."
	elif miudo:
		desc = "É miúdo, ainda pequeno. O certo é soltar."
	Mundo.avisar(msg)
	hud.decisao(desc + "\n[E] Guardar no balde      [R] Soltar")


func _decidir() -> void:
	if _trava_decisao > 0.0:
		_trava_decisao -= get_physics_process_delta_time()
		return
	var femea: bool = segurando.get("femea", false)
	var miudo: bool = segurando.get("miudo", false)
	if Input.is_action_just_pressed("interagir"):
		if cheio():
			Mundo.avisar("O balde está cheio. Solte este.", "perigo")
			return
		caranguejos += 1
		stats["pegos"] += 1
		if femea or miudo:
			reputacao -= 1
			Mundo.avisar("Guardou mesmo assim. O mangue sente quando a gente tira o que não devia.", "perigo")
		else:
			Mundo.avisar("Caranguejo no balde (%d)" % caranguejos)
		_fim_decisao()
	elif Input.is_action_just_pressed("soltar"):
		stats["soltos"] += 1
		if femea or miudo:
			reputacao += 1
			Mundo.avisar("Soltou. Ele volta para a lama e o mangue continua cheio.")
		else:
			Mundo.avisar("Soltou um macho graúdo... a barriga não agradece.")
		main.soltar_caranguejo(global_position - global_transform.basis.z * 0.6)
		_fim_decisao()


func _fim_decisao() -> void:
	segurando = {}
	estado = Estado.ANDANDO
	hud.decisao("")


# ------------------------------------------------------------------ dormir / desmaiar

## Deita na rede: abre a escolha de quantas horas dormir (tela_sono.gd).
func dormir() -> void:
	estado = Estado.OCUPADO
	Mundo.rodando = false
	hud.tela_sono.abrir()


func dormir_horas(h: float) -> void:
	estado = Estado.OCUPADO
	Mundo.rodando = true
	await hud.escurecer(1.0)
	await hud.passar_tempo("Dormindo na rede", h)
	fome = maxf(0.0, fome - h * 1.6)
	estamina = minf(estamina_max, estamina + estamina_max * h / 4.0)
	saude = minf(100.0, saude + h * 8.0)
	mancando = maxf(0.0, mancando - h)
	main.repovoar(h)
	await get_tree().create_timer(0.6).timeout
	await hud.escurecer(0.0)
	estado = Estado.ANDANDO
	var mare := "a maré está enchendo" if Mundo.mare_subindo() else "a maré está vazando"
	Mundo.avisar("Dormiu %s e acordou às %s (dia %d): %s." % [Mundo.texto_duracao(h), Mundo.texto_hora(), Mundo.dia, mare])
	if main.salvador.ativo:
		main.salvador.salvar()
		Mundo.avisar("Jogo salvo.")


func desmaiar(motivo: String) -> void:
	if estado == Estado.OCUPADO:
		return
	if estado == Estado.TOCA:
		hud.mostrar_toca(false)
	estado = Estado.OCUPADO
	await hud.escurecer(1.0)
	stats["perdidos"] += caranguejos + peixes + mochila["peixe"]
	caranguejos = 0
	peixes = 0
	mochila["peixe"] = 0
	global_position = main.pos_spawn
	velocity = Vector3.ZERO
	await hud.passar_tempo("Desmaiado", 5.0)
	fome = maxf(0.0, fome - 8.0)
	estamina = 60.0
	saude = 50.0
	mancando = 0.0
	aratus = 0
	atolado = 0.0
	tempo_afogando = 0.0
	await get_tree().create_timer(0.6).timeout
	await hud.escurecer(0.0)
	estado = Estado.ANDANDO
	Mundo.avisar(motivo, "perigo")


# ------------------------------------------------------------------ visual

func _visual(delta: float) -> void:
	luz_perto.visible = lanterna.light_energy > 0.0
	var hv := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() or nadando:
		_bob += delta * hv * 2.3
	var alvo_y := (0.95 if agachado else ALTURA_OLHOS) - atolado * 0.5
	if hv > 0.3 and estado != Estado.TOCA:
		alvo_y += sin(_bob) * 0.03 * float(Config.v["balanco"])
	if estado == Estado.TOCA:
		alvo_y = OLHOS_AGACHADO
	cabeca.position.y = lerpf(cabeca.position.y, alvo_y, clampf(delta * 8.0, 0.0, 1.0))
	_tremor = maxf(0.0, _tremor - delta * 1.5)
	camera.h_offset = randf_range(-1.0, 1.0) * _tremor * 0.04
	camera.v_offset = randf_range(-1.0, 1.0) * _tremor * 0.04
	if estado != Estado.TOCA:
		var balanco := Vector3(sin(_bob * 0.5) * 0.01, absf(cos(_bob * 0.5)) * 0.012, 0)
		braco.position = braco.position.lerp(BRACO_BASE + balanco, clampf(delta * 10.0, 0.0, 1.0))
	braco.visible = estado == Estado.TOCA
	facao.visible = estado == Estado.ANDANDO and na_mao == "facao"
	tarrafa_vis.visible = estado == Estado.ANDANDO and na_mao == "tarrafa" and _mira < 0.0
	if _golpe > 0.0:
		_golpe = maxf(0.0, _golpe - delta)
		var g := sin(_golpe * 12.0)
		facao.position = FACAO_BASE + Vector3(-0.1 * g, 0.12 * absf(g), -0.1 * absf(g))
		facao.rotation_degrees = Vector3(35 - 70 * absf(g), -12, -20)
	else:
		facao.position = facao.position.lerp(FACAO_BASE + Vector3(sin(_bob * 0.5) * 0.012, absf(cos(_bob * 0.5)) * 0.015, 0), clampf(delta * 10.0, 0.0, 1.0))
		facao.rotation_degrees = Vector3(35, -12, -20)
	balde_vis.position = balde_vis.position.lerp(BALDE_BASE + Vector3(cos(_bob * 0.5) * 0.015, absf(sin(_bob * 0.5)) * 0.03, 0), clampf(delta * 8.0, 0.0, 1.0))
	balde_vis.rotation_degrees.z = -6.0 + sin(_bob * 0.5) * 5.0
	balde_vis.visible = tem_balde and estado != Estado.TOCA
	for i in crabs_vis.size():
		crabs_vis[i].visible = i < caranguejos + peixes
	mao_crab.visible = estado == Estado.SEGURANDO
	if mao_crab.visible:
		mao_crab.rotation_degrees.z = sin(Time.get_ticks_msec() * 0.02) * 6.0
