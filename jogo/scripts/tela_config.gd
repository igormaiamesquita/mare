extends ColorRect
## Tela de Configurações (abre no início e na pausa). Tudo que muda vai direto para o autoload Config.

signal fechou

const DOURADO := Color(1.0, 0.8, 0.42)
const TEXTO := Color(0.93, 0.92, 0.87)
const APAGADO := Color(0.65, 0.63, 0.58)

var main
var _widgets := {}          # chave -> controle (para atualizar quando o preset muda)
var _valores := {}          # chave -> Label com o número do slider
var _btn_refazer: Button


func _ready() -> void:
	color = Color(0.03, 0.03, 0.025, 0.94)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _tema()
	visible = false

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(900, 0)
	v.add_theme_constant_override("separation", 16)
	centro.add_child(v)

	var titulo := Label.new()
	titulo.text = "CONFIGURAÇÕES"
	titulo.add_theme_font_size_override("font_size", 44)
	titulo.add_theme_color_override("font_color", DOURADO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)

	var abas := TabContainer.new()
	abas.custom_minimum_size = Vector2(900, 520)
	v.add_child(abas)

	var img := _aba(abas, "Imagem")
	_opcoes(img, "preset", "Qualidade", Config.PRESETS, "Ajusta tudo desta aba de uma vez. Mexer em um item vira \"Personalizada\".")
	_opcoes(img, "escala", "Resolução do 3D", Config.NOMES_ESCALA, "Menor = mais leve. A interface continua nítida.")
	_opcoes(img, "sombras", "Sombras", Config.NOMES_SOMBRA, "")
	_slider(img, "vegetacao", "Distância de visão", 0.5, 1.5, 0.05, "%d%%", 100.0, "Até onde aparecem árvores, capim e objetos.")
	_check(img, "oclusao", "Sombra de contato (SSAO)", "Escurece cantos e o chão debaixo das coisas. Pesa um pouco.")
	_check(img, "luz_indireta", "Luz rebatida (SSIL)", "A luz que bate no chão clareia o que está perto. Pesa bastante.")
	_check(img, "brilho_glow", "Brilho do sol e do fogo", "")
	_opcoes(img, "msaa", "Suavizar bordas (MSAA)", Config.NOMES_MSAA, "")
	_slider(img, "brilho", "Brilho da imagem", 0.6, 1.4, 0.05, "%d%%", 100.0, "")

	var tela := _aba(abas, "Tela")
	_check(tela, "tela_cheia", "Tela cheia", "")
	_check(tela, "vsync", "Sincronia vertical (VSync)", "Evita a imagem rasgada; pode limitar o FPS à taxa do monitor.")
	_opcoes(tela, "fps", "Limite de FPS", Config.NOMES_FPS, "")
	_slider(tela, "texto", "Tamanho do texto e da interface", 0.8, 1.3, 0.05, "%d%%", 100.0, "")

	var ctl := _aba(abas, "Controles")
	_slider(ctl, "sensibilidade", "Sensibilidade do mouse", 0.3, 3.0, 0.05, "%.2fx", 1.0, "")
	_check(ctl, "inverter_y", "Inverter o mouse na vertical", "")
	_slider(ctl, "fov", "Campo de visão", 60.0, 100.0, 1.0, "%d°", 1.0, "")
	_slider(ctl, "balanco", "Balanço da câmera ao andar", 0.0, 1.0, 0.05, "%d%%", 100.0, "Diminua se andar der enjoo.")
	var teclas := Label.new()
	teclas.text = ("W A S D  andar   ·   SHIFT  correr   ·   ESPAÇO  pular / puxar a perna da lama / subir em borda alta\n" +
		"CTRL ou OPTION  agachar   ·   E  usar, pegar, cortar   ·   R  soltar o caranguejo   ·   G  largar o balde\n" +
		"I ou TAB  inventário   ·   M  mapa   ·   T  tarrafa (segure e solte)   ·   B  jirau-fogão   ·   F  lanterna   ·   ESC  pausa\n" +
		"Na toca:  SEGURE E  enfiar o braço   ·   ESPAÇO  agarrar   ·   SEGURE E  puxar e SOLTE no \"SOLTE!\"   ·   S  tirar o braço")
	teclas.add_theme_font_size_override("font_size", 16)
	teclas.add_theme_color_override("font_color", APAGADO)
	teclas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ctl.add_child(HSeparator.new())
	ctl.add_child(teclas)

	var jogo := _aba(abas, "Jogo")
	_check(jogo, "primeiros_passos", "Primeiros passos em jogo novo", "Um passo a passo que ensina os controles antes da primeira missão.")
	_btn_refazer = Button.new()
	_btn_refazer.text = "Refazer os primeiros passos agora"
	_btn_refazer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_btn_refazer.pressed.connect(func() -> void:
		main.tutorial.reiniciar()
		fechar())
	jogo.add_child(_btn_refazer)

	var voltar := Button.new()
	voltar.text = "Voltar"
	voltar.custom_minimum_size = Vector2(260, 52)
	voltar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	voltar.pressed.connect(fechar)
	v.add_child(voltar)

	Config.mudou.connect(_atualizar)
	_atualizar()


func abrir() -> void:
	_btn_refazer.visible = main != null and main.hud.iniciado
	_atualizar()
	visible = true


func fechar() -> void:
	visible = false
	fechou.emit()


func _input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("pausa"):
		get_viewport().set_input_as_handled()
		fechar()


# ------------------------------------------------------------------ linhas

func _aba(abas: TabContainer, nome: String) -> VBoxContainer:
	var rolar := ScrollContainer.new()
	rolar.name = nome
	rolar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	abas.add_child(rolar)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	rolar.add_child(v)
	return v


func _linha(pai: VBoxContainer, rotulo: String, dica: String) -> HBoxContainer:
	var bloco := VBoxContainer.new()
	bloco.add_theme_constant_override("separation", 0)
	pai.add_child(bloco)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	bloco.add_child(h)
	var l := Label.new()
	l.text = rotulo
	l.custom_minimum_size.x = 380
	h.add_child(l)
	if dica != "":
		var d := Label.new()
		d.text = dica
		d.add_theme_font_size_override("font_size", 15)
		d.add_theme_color_override("font_color", APAGADO)
		bloco.add_child(d)
	return h


func _opcoes(pai: VBoxContainer, chave: String, rotulo: String, nomes: Array, dica: String) -> void:
	var h := _linha(pai, rotulo, dica)
	var o := OptionButton.new()
	o.custom_minimum_size.x = 300
	for n in nomes:
		o.add_item(n)
	if chave == "preset":
		o.set_item_disabled(nomes.size() - 1, true)   # "Personalizada" só aparece, não se escolhe
	o.item_selected.connect(func(i: int) -> void: Config.mudar(chave, i))
	h.add_child(o)
	_widgets[chave] = o


func _check(pai: VBoxContainer, chave: String, rotulo: String, dica: String) -> void:
	var h := _linha(pai, rotulo, dica)
	var c := CheckButton.new()
	c.toggled.connect(func(sim: bool) -> void: Config.mudar(chave, sim))
	h.add_child(c)
	_widgets[chave] = c


func _slider(pai: VBoxContainer, chave: String, rotulo: String, de: float, ate: float, passo: float, formato: String, mult: float, dica: String) -> void:
	var h := _linha(pai, rotulo, dica)
	var s := HSlider.new()
	s.min_value = de
	s.max_value = ate
	s.step = passo
	s.custom_minimum_size = Vector2(300, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n := Label.new()
	n.custom_minimum_size.x = 80
	s.value_changed.connect(func(x: float) -> void:
		n.text = formato % (x * mult)
		Config.mudar(chave, x))
	h.add_child(s)
	h.add_child(n)
	_widgets[chave] = s
	_valores[chave] = [n, formato, mult]


func _atualizar() -> void:
	for chave in _widgets:
		var w = _widgets[chave]
		var x = Config.v[chave]
		if w is OptionButton:
			(w as OptionButton).select(int(x))
		elif w is CheckButton:
			(w as CheckButton).set_pressed_no_signal(bool(x))
		elif w is HSlider:
			(w as HSlider).set_value_no_signal(float(x))
			var info: Array = _valores[chave]
			(info[0] as Label).text = info[1] % (float(x) * info[2])


# ------------------------------------------------------------------ visual

func _caixa(cor: Color, borda: Color, largura := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.border_color = borda
	s.set_border_width_all(largura)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(10)
	return s


func _tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = 19
	t.set_color("font_color", "Label", TEXTO)
	var normal := _caixa(Color(0.12, 0.1, 0.07, 0.95), Color(1, 0.8, 0.42, 0.45), 1)
	var hover := _caixa(Color(0.24, 0.19, 0.1, 0.95), DOURADO, 2)
	for tipo in ["Button", "OptionButton"]:
		t.set_stylebox("normal", tipo, normal)
		t.set_stylebox("hover", tipo, hover)
		t.set_stylebox("pressed", tipo, hover)
		t.set_stylebox("focus", tipo, _caixa(Color(0, 0, 0, 0), DOURADO, 2))
		t.set_color("font_color", tipo, TEXTO)
		t.set_color("font_hover_color", tipo, DOURADO)
	t.set_stylebox("panel", "TabContainer", _caixa(Color(0.06, 0.055, 0.045, 0.96), Color(1, 0.8, 0.42, 0.3), 1))
	t.set_stylebox("tab_selected", "TabContainer", _caixa(Color(0.2, 0.16, 0.09, 1), DOURADO, 0))
	t.set_stylebox("tab_unselected", "TabContainer", _caixa(Color(0.08, 0.07, 0.05, 1), Color(0, 0, 0, 0), 0))
	t.set_stylebox("tab_hovered", "TabContainer", _caixa(Color(0.16, 0.13, 0.08, 1), Color(0, 0, 0, 0), 0))
	t.set_color("font_selected_color", "TabContainer", DOURADO)
	t.set_color("font_unselected_color", "TabContainer", APAGADO)
	t.set_font_size("font_size", "TabContainer", 20)
	var trilho := _caixa(Color(0.25, 0.22, 0.17), Color(0, 0, 0, 0))
	trilho.set_content_margin_all(3)
	t.set_stylebox("slider", "HSlider", trilho)
	var cheio := _caixa(DOURADO.darkened(0.2), Color(0, 0, 0, 0))
	cheio.set_content_margin_all(3)
	t.set_stylebox("grabber_area", "HSlider", cheio)
	t.set_stylebox("grabber_area_highlight", "HSlider", cheio)
	t.set_color("font_color", "CheckButton", TEXTO)
	return t
