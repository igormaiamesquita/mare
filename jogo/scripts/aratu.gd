extends Node3D
## Um aratu agarrado no tronco. Pega na "mãozada"; à noite, com lanterna, fica mais fácil.

var arvore := Vector3.ZERO
var mat: Material
var raio_interacao := 1.7
var _t := 0.0


func _ready() -> void:
	add_to_group("interagivel")
	var m := (load("res://assets/caranguejo.glb") as PackedScene).instantiate() as Node3D
	m.scale = Vector3.ONE * 0.6
	_pintar(m)
	add_child(m)
	Texturas.alcance(self, 30.0)
	_t = randf() * 5.0


func _pintar(n: Node) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_pintar(c)


func _process(delta: float) -> void:
	_t += delta
	# sobe e desce um pouquinho no tronco
	position.y += sin(_t * 1.3) * delta * 0.04


func texto_interacao(j) -> String:
	if not j.tem_balde:
		return "Aratu na raiz (precisa do balde)"
	if j.cheio():
		return "O balde está cheio"
	return "[E] Mãozada no aratu"


func interagir(j) -> void:
	var noite := Mundo.altura_sol() < 0.0
	var com_luz: bool = j.lanterna.light_energy > 0.0
	var chance := 0.55
	if noite:
		chance = 0.8 if com_luz else 0.45   # à noite, a lanterna deixa ele parado
	if randf() < chance:
		j.aratus += 1
		Mundo.avisar("Pegou um aratu! (%d no balde)" % j.aratus)
		queue_free()
	elif randf() < 0.4:
		j.dano(3.0, "A garra do aratu prendeu no dedo!")
	else:
		Mundo.avisar("O aratu pulou na água e sumiu.")
		queue_free()
