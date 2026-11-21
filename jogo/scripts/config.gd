extends Node
## Configurações do jogador (autoload "Config"): guardadas em user://config.cfg e aplicadas na hora.
## O preset de qualidade só preenche os valores de imagem; depois cada um pode ser mexido à parte.

signal mudou

var comecar_direto := false     # depois de "Novo jogo" na pausa: recarrega e já começa (não é salvo)

const ARQUIVO := "user://config.cfg"
const PRESETS := ["Baixa", "Média", "Alta", "Ultra", "Personalizada"]
const ESCALAS := [0.0, 0.5, 0.67, 0.75, 1.0]          # 0 = automática (pelo tamanho da tela)
const NOMES_ESCALA := ["Automática", "50%", "67%", "75%", "100%"]
const NOMES_SOMBRA := ["Desligadas", "Baixas", "Médias", "Altas"]
const NOMES_MSAA := ["Desligado", "2x", "4x"]
const FPS := [0, 30, 60, 120]
const NOMES_FPS := ["Sem limite", "30", "60", "120"]

# valores (o padrão é o preset "Média", que é como o jogo sempre foi)
var v := {
	"preset": 1,
	"escala": 0,
	"sombras": 2,
	"vegetacao": 1.0,
	"oclusao": false,        # SSAO
	"luz_indireta": false,   # SSIL
	"brilho_glow": true,
	"msaa": 1,
	"vsync": true,
	"fps": 0,
	"tela_cheia": false,
	"sensibilidade": 1.0,
	"inverter_y": false,
	"fov": 72.0,
	"balanco": 1.0,
	"texto": 1.0,
	"brilho": 1.0,
	"primeiros_passos": true,
}

const VALORES_PRESET := [
	{"escala": 2, "sombras": 1, "vegetacao": 0.6, "oclusao": false, "luz_indireta": false, "brilho_glow": false, "msaa": 0},
	{"escala": 0, "sombras": 2, "vegetacao": 1.0, "oclusao": false, "luz_indireta": false, "brilho_glow": true, "msaa": 1},
	{"escala": 0, "sombras": 3, "vegetacao": 1.25, "oclusao": true, "luz_indireta": false, "brilho_glow": true, "msaa": 1},
	{"escala": 4, "sombras": 3, "vegetacao": 1.5, "oclusao": true, "luz_indireta": true, "brilho_glow": true, "msaa": 2},
]


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(ARQUIVO) == OK:
		for k in v:
			if cf.has_section_key("jogo", k):
				var lido = cf.get_value("jogo", k)
				if typeof(lido) == typeof(v[k]) or (typeof(v[k]) == TYPE_FLOAT and typeof(lido) == TYPE_INT):
					v[k] = lido
	_aplicar_janela()


func salvar() -> void:
	var cf := ConfigFile.new()
	for k in v:
		cf.set_value("jogo", k, v[k])
	cf.save(ARQUIVO)


## Muda um valor, aplica e salva. Mexer em algo de imagem vira preset "Personalizada".
func mudar(chave: String, valor) -> void:
	v[chave] = valor
	if chave == "preset" and int(valor) < VALORES_PRESET.size():
		for k in VALORES_PRESET[int(valor)]:
			v[k] = VALORES_PRESET[int(valor)][k]
	elif VALORES_PRESET[0].has(chave):
		v["preset"] = _preset_atual()
	aplicar()
	salvar()
	mudou.emit()


func _preset_atual() -> int:
	for i in VALORES_PRESET.size():
		var igual := true
		for k in VALORES_PRESET[i]:
			if v[k] != VALORES_PRESET[i][k]:
				igual = false
				break
		if igual:
			return i
	return PRESETS.size() - 1


func sens() -> float:
	return 0.0022 * float(v["sensibilidade"])


func escala_fixa() -> float:
	return ESCALAS[int(v["escala"])]


## Aplica tudo no jogo que está aberto (chamado pelo main ao montar e a cada mudança).
func aplicar() -> void:
	_aplicar_janela()
	var main = get_tree().current_scene
	if main == null or not main.has_method("ajustar_escala"):
		return
	main.ajustar_escala()
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][int(v["msaa"])]

	# sombras: atlas, distância e suavidade
	var s := int(v["sombras"])
	RenderingServer.directional_shadow_atlas_set_size([1024, 1024, 2048, 4096][s], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][s])
	for luz in [main.sol, main.lua]:
		luz.shadow_enabled = s > 0
	main.sol.directional_shadow_max_distance = [0.0, 30.0, 50.0, 80.0][s]
	main.lua.directional_shadow_max_distance = [0.0, 25.0, 40.0, 60.0][s]

	var amb: Environment = main.ambiente
	amb.ssao_enabled = bool(v["oclusao"])
	amb.ssil_enabled = bool(v["luz_indireta"])
	amb.glow_enabled = bool(v["brilho_glow"])
	amb.adjustment_brightness = float(v["brilho"])

	# distância da vegetação e dos objetos
	var mult := float(v["vegetacao"])
	for g in get_tree().get_nodes_in_group("alcance"):
		var base: float = g.get_meta("alcance")
		(g as GeometryInstance3D).visibility_range_end = base * mult
		(g as GeometryInstance3D).visibility_range_end_margin = base * mult * 0.1

	if main.jogador != null:
		main.jogador.camera.fov = float(v["fov"])


func _aplicar_janela() -> void:
	var janela := get_tree().root
	janela.content_scale_factor = float(v["texto"])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS[int(v["fps"])]
	if OS.has_feature("headless"):
		return
	var cheia := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if bool(v["tela_cheia"]) != cheia:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v["tela_cheia"] else DisplayServer.WINDOW_MODE_WINDOWED)
