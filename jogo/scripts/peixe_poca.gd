extends Node3D
## Peixe preso na poça. Nada devagar; quando a mão chega, às vezes escapa entre os dedos.

var poca
var raio_interacao := 1.6
var alvo := Vector3.ZERO
var _susto := 0.0
var _t := 0.0
var modelo: Node3D
var bagre := false


func _ready() -> void:
	add_to_group("interagivel")
	modelo = (load("res://assets/peixe.glb") as PackedScene).instantiate()
	modelo.scale = Vector3.ONE * randf_range(0.9, 1.3)
	add_child(modelo)
	bagre = randf() < 0.35
	if bagre:
		# bagre: escuro, mais largo, com esporão
		modelo.scale *= Vector3(1.3, 1.0, 1.15)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.18, 0.16, 0.12)
		m.roughness = 0.35
		_pintar(modelo, m)
	position = _ponto()
	alvo = _ponto()
	_t = randf() * 10.0


func _pintar(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = m
	for c in n.get_children():
		_pintar(c, m)


func _ponto() -> Vector3:
	var a := randf() * TAU
	var r := randf_range(0.0, poca.dados.z * 0.55)
	return Vector3(cos(a) * r, -0.09, sin(a) * r)


func _process(delta: float) -> void:
	_t += delta
	_susto = maxf(0.0, _susto - delta)
	var para := alvo - position
	if para.length() < 0.15:
		alvo = _ponto()
		return
	var vel := 2.8 if _susto > 0.0 else 0.5
	position += para.normalized() * vel * delta
	look_at(global_position + para.normalized(), Vector3.UP)
	modelo.rotation.y = sin(_t * (18.0 if _susto > 0.0 else 8.0)) * 0.2


func texto_interacao(j) -> String:
	if not j.cabe_peixe():
		return "Balde e mochila cheios"
	if _susto > 0.0:
		return "Ele está agitado..."
	if bagre:
		return "[E] Pegar o bagre (cuidado com o esporão)"
	return "[E] Pegar o peixe com a mão"


func interagir(j) -> void:
	if _susto > 0.0:
		return
	if randf() < 0.6:
		j.pegar_peixe()
		poca.peixes.erase(self)
		queue_free()
	elif bagre and randf() < 0.5:
		j.dano(15.0, "Esporão do bagre na mão! Dói muito. Pegue o bagre por cima, com calma.")
		_susto = 1.5
		alvo = _ponto()
	else:
		Mundo.avisar("Escapou entre os dedos! Tente de novo.")
		_susto = 1.2
		alvo = _ponto()
		var peixes_vida = poca.main.peixes
		if peixes_vida != null:
			peixes_vida.respingo(global_position + Vector3(0, 0.1, 0))
