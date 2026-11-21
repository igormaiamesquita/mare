extends Node3D
## Toca de caranguejo na lama. Pode ter bicho ou estar vazia.
## Sinal de bicho dentro: bolinhas de lama fresca na boca da toca.

var ocupada := true
var profundidade := 0.45   # onde o bicho está (m, ao longo da toca)
var fundo := 0.8           # até onde a toca vai
var femea := false
var miudo := false
var raio_interacao := 1.7
var sinais: Array[MeshInstance3D] = []
var destaque := 0.0            # 0..1, quanto o anel está aceso (o HUD também usa)
var _anel: MeshInstance3D
var _anel_mat: ShaderMaterial
var _jogador

const ALCANCE_DESTAQUE := 10.0

static var _bolinha: SphereMesh
static var _quad: QuadMesh


func _ready() -> void:
	add_to_group("interagivel")
	add_to_group("toca")
	add_child((load("res://assets/toca.glb") as PackedScene).instantiate())
	if _bolinha == null:
		_bolinha = SphereMesh.new()
		_bolinha.radius = 0.012
		_bolinha.height = 0.014
		_bolinha.radial_segments = 8
		_bolinha.rings = 4
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.09, 0.075, 0.055)
		m.roughness = 0.25
		_bolinha.material = m
	for i in 12:
		var mi := MeshInstance3D.new()
		mi.mesh = _bolinha
		var a := randf() * TAU
		var r := randf_range(0.08, 0.24)
		mi.position = Vector3(cos(a) * r, 0.03, sin(a) * r)
		mi.scale = Vector3.ONE * randf_range(0.7, 1.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		sinais.append(mi)
	# anel de destaque
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(1.15, 1.15)
		_quad.orientation = PlaneMesh.FACE_Y
	_anel = MeshInstance3D.new()
	_anel.mesh = _quad
	_anel_mat = ShaderMaterial.new()
	_anel_mat.shader = load("res://shaders/anel_toca.gdshader")
	_anel.material_override = _anel_mat
	_anel.position.y = 0.06
	_anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anel.visible = false
	add_child(_anel)
	sortear(0.65)
	Texturas.alcance(self, 32.0)
	for s in sinais:
		s.visibility_range_end = 14.0


func _process(delta: float) -> void:
	if _jogador == null:
		_jogador = get_tree().get_first_node_in_group("jogador")
		if _jogador == null:
			return
	var alvo := 0.0
	if not coberta() and _jogador.toca != self:
		var d := global_position.distance_to(_jogador.global_position)
		alvo = 1.0 - smoothstep(ALCANCE_DESTAQUE * 0.6, ALCANCE_DESTAQUE, d)
	destaque = move_toward(destaque, alvo, delta * 2.5)
	_anel.visible = destaque > 0.01
	if _anel.visible:
		_anel_mat.set_shader_parameter("forca", destaque * 1.5)


func sortear(chance: float) -> void:
	ocupada = randf() < chance
	_novo_bicho()


func _novo_bicho() -> void:
	profundidade = randf_range(0.22, 0.68)
	fundo = maxf(profundidade + 0.1, randf_range(0.6, 0.9))
	femea = randf() < 0.25
	miudo = (not femea) and randf() < 0.2
	for s in sinais:
		s.visible = ocupada


func coberta() -> bool:
	return Mundo.nivel_mare() > global_position.y + 0.03


func texto_interacao(j) -> String:
	if coberta():
		return "A maré cobriu esta toca"
	if not j.tem_balde:
		return "Pegue o balde no rancho antes"
	if j.cheio():
		return "O balde está cheio"
	return "[E] Enfiar o braço na toca"


func interagir(j) -> void:
	j.iniciar_toca(self)


func esvaziar() -> void:
	ocupada = false
	for s in sinais:
		s.visible = false


func receber() -> void:
	if ocupada:
		return
	ocupada = true
	_novo_bicho()
