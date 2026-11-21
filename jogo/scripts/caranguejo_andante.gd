extends Node3D
## Caranguejo andando na lama. Anda de lado; quando a pessoa chega perto ou a maré sobe, corre para uma toca.
## Dá para agarrar no pulo se chegar bem perto.

var main
var fugindo := false
var toca_destino = null
var alvo := Vector3.ZERO
var pausa := 0.0
var raio_interacao := 1.5
var modelo: Node3D
var _t := 0.0
var ameacando := 0.0       # segundos de pinça levantada (encurralado)
var _ja_ameacou := false


func _ready() -> void:
	add_to_group("interagivel")
	modelo = (load("res://assets/caranguejo.glb") as PackedScene).instantiate()
	add_child(modelo)
	Texturas.alcance(self, 35.0)
	_t = randf() * 10.0
	_novo_alvo()


func _novo_alvo() -> void:
	alvo = global_position + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
	pausa = randf_range(0.3, 2.5)


func fugir() -> void:
	if fugindo:
		return
	fugindo = true
	toca_destino = main.toca_livre_mais_perto(global_position)
	# avisa os vizinhos: quem está perto também corre para a toca
	for c in get_parent().get_children():
		if c != self and not c.fugindo and c.global_position.distance_to(global_position) < 6.0:
			c.fugir.call_deferred()


func _process(delta: float) -> void:
	if not Mundo.rodando or main.jogador == null:
		return
	_t += delta
	var j = main.jogador
	var dj := global_position.distance_to(j.global_position)
	var vel_j := Vector2(j.velocity.x, j.velocity.z).length()
	if not fugindo and (dj < 2.0 or (dj < 6.0 and vel_j > 3.6)):
		fugir()
	if not fugindo and Mundo.nivel_mare() > global_position.y - 0.05:
		fugir()

	# encurralado: perto de você e longe da toca, ele para e levanta as pinças
	if fugindo and not _ja_ameacou and dj < 1.8 and toca_destino != null and is_instance_valid(toca_destino) \
			and toca_destino.global_position.distance_to(global_position) > 2.5:
		_ja_ameacou = true
		ameacando = randf_range(1.2, 2.2)
	if ameacando > 0.0:
		ameacando -= delta
		var para_j: Vector3 = j.global_position - global_position
		var ang_j := atan2(-para_j.x, -para_j.z)
		rotation.y = lerp_angle(rotation.y, ang_j + PI, delta * 10.0)   # frente (pinças) virada para você
		modelo.rotation.x = lerpf(modelo.rotation.x, -0.55, delta * 10.0)
		modelo.position.y = 0.025 + absf(sin(_t * 9.0)) * 0.006
		return
	modelo.rotation.x = lerpf(modelo.rotation.x, 0.0, delta * 8.0)
	var destino := alvo
	if fugindo:
		if toca_destino != null and is_instance_valid(toca_destino):
			destino = toca_destino.global_position
		else:
			destino = global_position + (global_position - j.global_position).normalized() * 3.0
	var dir := destino - global_position
	dir.y = 0.0
	if dir.length() < 0.12:
		if fugindo and toca_destino != null and is_instance_valid(toca_destino):
			toca_destino.receber()
			queue_free()
			return
		if not fugindo:
			pausa -= delta
			if pausa <= 0.0:
				_novo_alvo()
		return
	if not fugindo and pausa > 0.0 and dir.length() > 0.12 and randf() < 0.002:
		pausa = randf_range(0.5, 1.5)
	var v := 2.8 if fugindo else 0.55
	global_position += dir.normalized() * v * delta
	global_position.y = Terreno.altura(global_position.x, global_position.z)
	# anda de lado: o eixo X do corpo aponta para onde vai
	var ang := atan2(-dir.z, dir.x)
	rotation.y = lerp_angle(rotation.y, ang, delta * 8.0)
	modelo.position.y = absf(sin(_t * (30.0 if fugindo else 16.0))) * 0.008


func texto_interacao(j) -> String:
	if not j.tem_balde:
		return ""
	if j.cheio():
		return "O balde está cheio"
	if ameacando > 0.0:
		return "[E] Agarrar (cuidado: ele está de pinça levantada!)"
	return "[E] Agarrar o caranguejo"


func interagir(j) -> void:
	if ameacando > 0.0:
		if randf() < 0.45:
			j.dano(8.0, "Ele estava de pinça levantada e beliscou sua mão!")
			ameacando = 0.0
			return
	elif randf() < 0.15:
		Mundo.avisar("Escapou por entre as pernas!")
		fugir()
		return
	j.segurar_caranguejo(randf() < 0.25, randf() < 0.2, "Pegou no pulo!")
	queue_free()
