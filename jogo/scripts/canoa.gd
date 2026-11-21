extends Node3D
## Canoa velha com rabeta. Primeiro é consertada peça por peça; depois dá para pilotar.
## Boia na maré; encalha no raso; bate nas árvores; a gasolina acaba.

var main
var raio_interacao := 3.0
var examinada := false
var furo := true
var tem_motor := false
var tem_helice := false
var tem_remo := false
var tem_cuia := false
var gasolina := 0.0          # 0..100
var pilotando := false

var _modelos := {}
var _vel := 0.0
var _yaw := 0.0
var _t := 0.0
var _aviso_raso := 0.0
var _trava_e := 0.0

const COMPRIMENTO := 5.2
const VEL_MOTOR := 7.0
const VEL_REMO := 1.8


func _ready() -> void:
	add_to_group("interagivel")
	_yaw = rotation.y
	add_child((load("res://assets/canoa.glb") as PackedScene).instantiate())
	_peca_vis("remendo", "res://assets/remendo.glb", Vector3.ZERO, Vector3.ZERO)
	_peca_vis("motor", "res://assets/motor_rabeta.glb", Vector3(0, 0.55, 2.45), Vector3.ZERO)
	_peca_vis("helice", "res://assets/helice.glb", Vector3(0, 0.25, 4.05), Vector3(PI / 2, 0, 0))
	_peca_vis("galao", "res://assets/galao.glb", Vector3(0.25, 0.08, 1.6), Vector3.ZERO)
	_peca_vis("remo", "res://assets/remo.glb", Vector3(-0.25, 0.1, 0.0), Vector3(0, 0.1, 0))
	_peca_vis("cuia", "res://assets/cuia.glb", Vector3(0.1, 0.1, -0.8), Vector3.ZERO)
	_atualizar_vis()


func _peca_vis(nome: String, caminho: String, pos: Vector3, rot: Vector3) -> void:
	var n := (load(caminho) as PackedScene).instantiate() as Node3D
	n.position = pos
	n.rotation = rot
	add_child(n)
	_modelos[nome] = n


func _atualizar_vis() -> void:
	_modelos["remendo"].visible = not furo
	_modelos["motor"].visible = tem_motor
	_modelos["helice"].visible = tem_helice
	_modelos["galao"].visible = gasolina > 0.0
	_modelos["remo"].visible = tem_remo
	_modelos["cuia"].visible = tem_cuia


func pronta() -> bool:
	return not furo and tem_motor and tem_helice and tem_remo and tem_cuia and gasolina > 0.0


func falta() -> Array:
	var f := []
	if furo:
		f.append("tapar o furo (breu)")
	if not tem_motor:
		f.append("motor lavado")
	if not tem_helice:
		f.append("hélice")
	if gasolina <= 0.0:
		f.append("gasolina (galão)")
	if not tem_remo:
		f.append("remo")
	if not tem_cuia:
		f.append("cuia")
	return f


# ------------------------------------------------------------------ conserto

func texto_interacao(j) -> String:
	if pilotando:
		return ""
	if not examinada:
		return "[E] Examinar a canoa velha"
	var m: Dictionary = j.mochila
	if furo and m["breu"] > 0:
		return "[E] Tapar o furo com breu e estopa"
	if not tem_motor and m["motor"] > 0:
		if j.motor_limpo:
			return "[E] Instalar o motor de rabeta"
		return "O motor está cheio de lama e sal. Lave com água doce na bancada do rancho."
	if not tem_helice and m["helice"] > 0:
		return "[E] Pôr a hélice"
	if gasolina <= 0.0 and m["galao"] > 0:
		return "[E] Abastecer com o galão"
	if not tem_remo and m["remo"] > 0:
		return "[E] Guardar o remo na canoa"
	if not tem_cuia and m["cuia"] > 0:
		return "[E] Guardar a cuia na canoa"
	if pronta():
		return "[E] Subir na canoa e pilotar"
	return "Canoa: falta " + ", ".join(falta())


func interagir(j) -> void:
	if not examinada:
		examinada = true
		Mundo.avisar("A canoa tem um furo no casco e está sem motor, hélice, remo, cuia e gasolina. Procure as peças.", "objetivo")
		return
	var m: Dictionary = j.mochila
	if furo and m["breu"] > 0:
		m["breu"] -= 1
		furo = false
		Mundo.avisar("Furo tapado com breu e estopa.")
	elif not tem_motor and m["motor"] > 0 and j.motor_limpo:
		m["motor"] -= 1
		tem_motor = true
		Mundo.avisar("Motor de rabeta instalado na popa.")
	elif not tem_helice and m["helice"] > 0:
		m["helice"] -= 1
		tem_helice = true
		Mundo.avisar("Hélice no lugar.")
	elif gasolina <= 0.0 and m["galao"] > 0:
		m["galao"] -= 1
		gasolina = 100.0
		Mundo.avisar("Tanque cheio.")
	elif not tem_remo and m["remo"] > 0:
		m["remo"] -= 1
		tem_remo = true
		Mundo.avisar("Remo guardado na canoa.")
	elif not tem_cuia and m["cuia"] > 0:
		m["cuia"] -= 1
		tem_cuia = true
		Mundo.avisar("Cuia guardada (para tirar a água que entra).")
	elif pronta():
		embarcar(j)
		return
	_atualizar_vis()
	if pronta():
		Mundo.avisar("A canoa está pronta! Suba e pilote (W/S acelera, A/D vira, E desce).", "objetivo")


# ------------------------------------------------------------------ pilotar

func embarcar(j) -> void:
	pilotando = true
	_trava_e = 0.6
	j.embarcar(self)
	Mundo.avisar("W/S acelera e freia · A/D vira · E desce. Cuidado com o raso e com as árvores.")


func desembarcar(j) -> void:
	pilotando = false
	_vel = 0.0
	var lado := global_transform.basis.x * 1.4
	var p := global_position + lado
	p.y = maxf(Terreno.altura(p.x, p.z), Mundo.nivel_mare() - 1.4) + 0.1
	j.desembarcar(p)


func assento() -> Vector3:
	return to_global(Vector3(0, 0.45, 1.9))


func _fundura_em(local: Vector3) -> float:
	var p := to_global(local)
	return Mundo.nivel_mare() - Terreno.altura(p.x, p.z)


func _bate_em_arvore(p: Vector3) -> bool:
	for a in main.arvores:
		if absf(a.x - p.x) < 1.0 and absf(a.z - p.z) < 1.0:
			return true
	return false


func _physics_process(delta: float) -> void:
	_t += delta
	var nivel := Mundo.nivel_mare()
	var chao := Terreno.altura(global_position.x, global_position.z)
	var boiando := nivel > chao + 0.25
	# altura: boia na água ou fica deitada na lama
	var alvo_y := nivel - 0.12 if boiando else chao + 0.02
	global_position.y = lerpf(global_position.y, alvo_y, clampf(delta * 3.0, 0.0, 1.0))
	if not pilotando or not Mundo.rodando:
		rotation = Vector3(sin(_t * 0.8) * 0.02 if boiando else 0.0, _yaw, sin(_t * 1.1) * 0.025 if boiando else 0.0)
		return
	# controles
	var acel := Input.get_axis("tras", "frente")
	var virar := Input.get_axis("direita", "esquerda")
	var tem_gasolina := gasolina > 0.0 and tem_motor and tem_helice
	var maxima := VEL_MOTOR if tem_gasolina else VEL_REMO
	_vel = move_toward(_vel, acel * maxima, delta * (3.0 if absf(acel) > 0.0 else 1.5))
	_yaw += virar * delta * (0.9 if absf(_vel) > 0.3 else 0.4)
	if tem_gasolina and absf(acel) > 0.0:
		gasolina = maxf(0.0, gasolina - delta * absf(acel) * 0.55)
		if gasolina <= 0.0:
			Mundo.avisar("Acabou a gasolina! Agora é no remo.", "perigo")
			_atualizar_vis()
	var frente := Vector3(-sin(_yaw), 0, -cos(_yaw))
	var prox := global_position + frente * _vel * delta
	# encalhe: proa (ou popa, de ré) no raso
	var ponta := Vector3(0, 0, -COMPRIMENTO * 0.45 if _vel >= 0.0 else COMPRIMENTO * 0.45)
	var raso := _fundura_em(ponta) < 0.3 or not boiando
	var arvore := _bate_em_arvore(prox + frente * signf(_vel) * COMPRIMENTO * 0.4)
	_aviso_raso -= delta
	if raso or arvore or absf(prox.x) > 124.0 or absf(prox.z) > 124.0:
		if absf(_vel) > 0.5 and _aviso_raso <= 0.0:
			_aviso_raso = 3.0
			Mundo.avisar("Encalhou no raso! Dê ré ou espere a maré encher." if raso else "Bateu nas raízes! Dê ré e desvie.", "perigo")
		_vel = 0.0
	else:
		global_position.x = prox.x
		global_position.z = prox.z
	var bal := clampf(absf(_vel) / VEL_MOTOR, 0.0, 1.0)
	rotation = Vector3(-bal * 0.06 + sin(_t * 1.5) * 0.02, _yaw, -virar * bal * 0.08 + sin(_t * 1.2) * 0.02)
	# hélice girando
	if tem_helice:
		_modelos["helice"].rotate_object_local(Vector3.UP, _vel * delta * 6.0)
	_trava_e -= delta
	if Input.is_action_just_pressed("interagir") and _trava_e <= 0.0:
		desembarcar(main.jogador)
