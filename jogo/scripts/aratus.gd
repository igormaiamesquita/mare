extends Node3D
## Aratu: caranguejo pequeno que sobe nas raízes e troncos quando a maré enche (e desce na vazante).
## Aparece nas árvores perto do jogador quando a água está funda no pé da árvore.

var main
var _relogio := 0.0
var _mat: StandardMaterial3D


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.85, 0.25, 0.1)
	_mat.roughness = 0.35
	_mat.emission_enabled = true
	_mat.emission = Color(0.25, 0.05, 0.0)


func _process(delta: float) -> void:
	if main.jogador == null or not Mundo.rodando:
		return
	_relogio -= delta
	if _relogio > 0.0:
		return
	_relogio = 1.0
	var jp: Vector3 = main.jogador.global_position
	var nivel := Mundo.nivel_mare()
	# quem ficou longe ou com a árvore no seco desce
	for a in get_children():
		if a.global_position.distance_to(jp) > 40.0 or nivel < a.arvore.y + 0.2:
			a.queue_free()
	var noite := Mundo.altura_sol() < 0.0
	var maximo := 16 if noite else 9
	if get_child_count() >= maximo:
		return
	var candidatas := []
	for t in main.arvores:
		var d: float = Vector2(t.x - jp.x, t.z - jp.z).length()
		if d > 3.0 and d < 22.0 and nivel > t.y + 0.35 and t.y < 1.7:
			candidatas.append(t)
	if candidatas.is_empty():
		return
	for i in 3:
		var arv: Vector3 = candidatas[randi() % candidatas.size()]
		var a := Node3D.new()
		a.set_script(load("res://scripts/aratu.gd"))
		a.arvore = arv
		a.mat = _mat
		add_child(a)
		var ang := randf() * TAU
		a.global_position = arv + Vector3(cos(ang) * 0.17, (nivel - arv.y) + randf_range(0.25, 1.0), sin(ang) * 0.17)
		a.rotation = Vector3(-PI / 2, ang + PI / 2, 0)
