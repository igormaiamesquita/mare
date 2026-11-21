extends Node3D
## Peça da canoa largada no mundo (hélice, remo, cuia, galão, breu, motor). Brilha quando você chega perto.

const INFO := {
	"helice": ["a hélice", "res://assets/helice.glb"],
	"remo": ["o remo", "res://assets/remo.glb"],
	"cuia": ["a cuia", "res://assets/cuia.glb"],
	"galao": ["o galão de gasolina", "res://assets/galao.glb"],
	"breu": ["a lata de breu e estopa", "res://assets/lata_breu.glb"],
	"motor": ["o motor de rabeta", "res://assets/motor_rabeta.glb"],
}

var id := ""
var raio_interacao := 2.0
var destaque := 0.0
var _anel: MeshInstance3D
var _mat: ShaderMaterial
var _jogador


func _ready() -> void:
	add_to_group("interagivel")
	add_to_group("peca")
	var m := (load(INFO[id][1]) as PackedScene).instantiate() as Node3D
	m.rotation.y = randf() * TAU
	if id == "motor":
		m.rotation.z = 0.5   # caído de lado
	add_child(m)
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	q.orientation = PlaneMesh.FACE_Y
	_anel = MeshInstance3D.new()
	_anel.mesh = q
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/anel_toca.gdshader")
	_mat.set_shader_parameter("cor", Color(0.45, 0.85, 1.0))
	_anel.material_override = _mat
	_anel.position.y = 0.05
	_anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_anel)
	Texturas.alcance(self, 80.0)


func nome() -> String:
	return INFO[id][0]


func _process(delta: float) -> void:
	if _jogador == null:
		_jogador = get_tree().get_first_node_in_group("jogador")
		return
	var d := global_position.distance_to(_jogador.global_position)
	destaque = move_toward(destaque, 1.0 - smoothstep(9.0, 15.0, d), delta * 2.0)
	_anel.visible = destaque > 0.01
	_mat.set_shader_parameter("forca", destaque * 1.4)


func texto_interacao(j) -> String:
	if j.cabe_na_mochila(id) <= 0:
		return "Não cabe na mochila (o motor ocupa 3 espaços). Abra o inventário (I) e libere espaço."
	return "[E] Pegar %s" % nome()


func interagir(j) -> void:
	if j.cabe_na_mochila(id) <= 0:
		return
	j.mochila[id] += 1
	var extra := ""
	if id == "motor":
		extra = " Está cheio de lama e sal: vai precisar lavar com água doce."
	Mundo.avisar("Pegou %s!%s" % [nome(), extra], "objetivo")
	queue_free()
