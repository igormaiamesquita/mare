extends Node3D
## Parabólica fincada na lama. Ajustar o prato pega o sinal (nomes do mapa e tábua de marés).

var cultura
var raio_interacao := 3.6
var _ajustando := false


func _ready() -> void:
	add_to_group("interagivel")
	var modelo := (load("res://assets/parabolica.glb") as PackedScene).instantiate()
	add_child(modelo)
	# colisão com a forma real (monte de lama, coluna, pés): dá para subir no monte
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).create_trimesh_collision()


func texto_interacao(_j) -> String:
	if cultura.sinal:
		return "Parabólica com sinal. Veja os nomes e a tábua de marés no mapa (M)."
	if _ajustando:
		return "Ajustando..."
	return "[E] Ajustar o prato da parabólica"


func interagir(j) -> void:
	if cultura.sinal or _ajustando:
		return
	_ajustando = true
	j.ocupar(true)
	Mundo.avisar("Virando o prato devagar, procurando o sinal...")
	for i in 3:
		j.golpear()
		await get_tree().create_timer(0.6).timeout
	j.ocupar(false)
	_ajustando = false
	cultura.pegar_sinal()
