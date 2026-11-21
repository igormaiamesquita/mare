extends Node3D
## Poça da vazante: quando a maré baixa, a água fica presa aqui e alguns peixes ficam presos junto.
## Dá para pegar com a mão.

var main
var dados := Vector3.ZERO      # x, z, raio
var nivel := 0.0               # altura da água parada
var agua: MeshInstance3D
var peixes: Array = []
var _isolada := false


func _ready() -> void:
	nivel = Terreno.nivel_poca(dados)
	position = Vector3(dados.x, nivel, dados.y)
	var disco := CylinderMesh.new()
	disco.top_radius = dados.z * 0.95
	disco.bottom_radius = dados.z * 0.95
	disco.height = 0.01
	disco.radial_segments = 40
	disco.rings = 1
	agua = MeshInstance3D.new()
	agua.mesh = disco
	agua.material_override = main.agua_mat
	agua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(agua)


func _process(_delta: float) -> void:
	var isolada := Mundo.nivel_mare() < nivel - 0.02
	agua.visible = isolada
	if isolada and not _isolada:
		# a maré acabou de baixar: alguns peixes ficaram presos
		for i in randi_range(1, 3):
			_novo_peixe()
	elif not isolada and _isolada:
		for p in peixes:
			if is_instance_valid(p):
				p.queue_free()
		peixes.clear()
	_isolada = isolada


func _novo_peixe() -> void:
	var p := Node3D.new()
	p.set_script(load("res://scripts/peixe_poca.gd"))
	p.poca = self
	add_child(p)
	peixes.append(p)
