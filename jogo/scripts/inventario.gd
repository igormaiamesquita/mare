extends ColorRect
## Inventário (I ou TAB): no corpo (ferramentas), mochila (6 espaços) e balde (10).
## Clique no peixe passa entre balde e mochila; clique na farofa ou na farinha come.

const DOURADO := Color(1.0, 0.8, 0.42)
const TEXTO := Color(0.93, 0.92, 0.87)
const APAGADO := Color(0.62, 0.6, 0.55)
const Barra := preload("res://scripts/barra.gd")

const FERRAMENTAS := ["facao", "tarrafa", "lanterna", "panela", "galochas"]
const NOME_FERR := {"facao": "Facão", "tarrafa": "Tarrafa", "lanterna": "Lanterna", "panela": "Panelinha", "galochas": "Galochas"}
const DESC_FERR := {
	"facao": "Facão (atalho 1). Corta lenha dos troncos caídos.",
	"tarrafa": "Tarrafa (atalho 2). Na mão, SEGURE o botão do mouse (ou T) para mirar no cardume e SOLTE para jogar.",
	"lanterna": "Lanterna (atalho 3 ou F). Liga e desliga.",
	"panela": "Panelinha. Vai junto para cozinhar no jirau-fogão.",
	"galochas": "Galochas. Calçadas, a lama mole prende menos e a arraia machuca menos.",
}

var hud
var jogador
var _ferr: GridContainer
var _mochila: GridContainer
var _balde: GridContainer
var _tit_mochila: Label
var _tit_balde: Label
var _nome: Label
var _desc: Label
var _btn_lama: Button


func _ready() -> void:
	color = Color(0.02, 0.022, 0.02, 0.86)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	centro.add_child(v)

	var colunas := HBoxContainer.new()
	colunas.add_theme_constant_override("separation", 64)
	v.add_child(colunas)
	_ferr = _coluna(colunas, "NO CORPO", 1, 0)
	_mochila = _coluna(colunas, "MOCHILA", 3, 1)
	_balde = _coluna(colunas, "BALDE", 5, 2)

	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(1000, 96)
	info.add_theme_constant_override("separation", 4)
	v.add_child(info)
	_nome = _label("", 24, DOURADO)
	info.add_child(_nome)
	_desc = _label("", 19, TEXTO)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size.x = 1000
	info.add_child(_desc)

	var baixo := HBoxContainer.new()
	baixo.add_theme_constant_override("separation", 24)
	v.add_child(baixo)
	_btn_lama = Button.new()
	_btn_lama.text = "Passar lama no rosto (espanta muriçoca)"
	_btn_lama.focus_mode = Control.FOCUS_NONE
	_btn_lama.add_theme_font_size_override("font_size", 18)
	_btn_lama.custom_minimum_size = Vector2(400, 44)
	_btn_lama.add_theme_stylebox_override("normal", _fundo(Color(1, 1, 1, 0.07)))
	_btn_lama.add_theme_stylebox_override("hover", _fundo(Color(1, 0.85, 0.5, 0.16)))
	_btn_lama.add_theme_stylebox_override("pressed", _fundo(Color(1, 0.85, 0.5, 0.22)))
	_btn_lama.pressed.connect(func() -> void:
		if jogador.passar_lama_no_rosto():
			_mostrar("Lama no rosto", "Protegido da muriçoca por umas 3 horas.")
		else:
			_mostrar("Lama no rosto", "Precisa estar pisando na lama para passar no rosto."))
	baixo.add_child(_btn_lama)
	var rodape := _label("Clique no peixe: passa entre balde e mochila   ·   clique na farofa ou na farinha: come   ·   I fecha", 16, APAGADO)
	rodape.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	baixo.add_child(rodape)


func _label(t: String, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _fundo(cor: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.set_corner_radius_all(10)
	s.set_content_margin_all(8)
	return s


func _coluna(pai: HBoxContainer, titulo: String, colunas: int, i: int) -> GridContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pai.add_child(v)
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 10)
	v.add_child(cab)
	if i > 0:
		var ic := TextureRect.new()
		ic.texture = Barra.icone("mochila" if i == 1 else "balde")
		ic.custom_minimum_size = Vector2(40, 40)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cab.add_child(ic)
	var l := _label(titulo, 22, TEXTO)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cab.add_child(l)
	if i == 1:
		_tit_mochila = l
	elif i == 2:
		_tit_balde = l
	var g := GridContainer.new()
	g.columns = colunas
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	v.add_child(g)
	return g


func abrir() -> void:
	_mostrar("", "Passe o mouse num item para ver o que é.")
	montar()
	visible = true


func _mostrar(nome: String, desc: String) -> void:
	_nome.text = nome
	_desc.text = desc


func montar() -> void:
	for g in [_ferr, _mochila, _balde]:
		for c in g.get_children():
			c.queue_free()
	var j = jogador
	# no corpo
	for f in FERRAMENTAS:
		var tem: bool = f in ["facao", "lanterna", "panela"] or (f == "tarrafa" and j.tem_tarrafa) or (f == "galochas" and j.galochas)
		var s := _slot(f, "", Vector2(92, 92), tem)
		var desc: String = DESC_FERR[f] if tem else ("Ainda não pegou: " + NOME_FERR[f].to_lower() + " está no rancho.")
		s.mouse_entered.connect(_mostrar.bind(NOME_FERR[f], desc))
		_ferr.add_child(s)
	# mochila: cada pilha ocupa um espaço (o motor ocupa 3)
	for item in ["peixe", "lenha", "farinha", "farofa", "helice", "remo", "cuia", "galao", "breu", "motor"]:
		var n: int = j.mochila[item]
		var pilha: int = j.PILHA[item]
		var tam: int = j.TAMANHO.get(item, 1)
		while n > 0:
			var q := mini(n, pilha)
			for k in tam:
				var s := _slot(item if k == 0 else "", str(q) if q > 1 and k == 0 else "", Vector2(112, 112), true)
				var nome_i: String = hud.NOME_ITEM[item]
				var desc_i: String = hud.DESCRICAO[item]
				if item == "motor":
					nome_i = "Motor limpo" if j.motor_limpo else "Motor (sujo de lama e sal)"
				s.mouse_entered.connect(_mostrar.bind(nome_i, desc_i))
				s.pressed.connect(_clique.bind(item, "mochila"))
				_mochila.add_child(s)
			n -= q
	while _mochila.get_child_count() < j.MOCHILA_ESPACOS:
		_mochila.add_child(_slot("", "", Vector2(112, 112), false))
	_tit_mochila.text = "MOCHILA   %d/%d" % [j.espacos_usados(), j.MOCHILA_ESPACOS]
	# balde: um lugar por bicho
	if j.tem_balde:
		for par in [["caranguejo", j.caranguejos], ["aratu", j.aratus], ["peixe", j.peixes]]:
			for i in par[1]:
				var s := _slot(par[0], "", Vector2(80, 80), true)
				s.mouse_entered.connect(_mostrar.bind(hud.NOME_ITEM[par[0]], hud.DESCRICAO[par[0]]))
				s.pressed.connect(_clique.bind(par[0], "balde"))
				_balde.add_child(s)
		while _balde.get_child_count() < j.capacidade_balde:
			_balde.add_child(_slot("", "", Vector2(80, 80), false))
		_tit_balde.text = "BALDE   %d/%d" % [j.caranguejos + j.peixes + j.aratus, j.capacidade_balde]
	else:
		_tit_balde.text = "BALDE   (não está com você)"


func _slot(item: String, qtd: String, tam: Vector2, tem: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = tam
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _fundo(Color(1, 1, 1, 0.05 if item == "" else 0.08)))
	b.add_theme_stylebox_override("hover", _fundo(Color(1, 0.85, 0.5, 0.16)))
	b.add_theme_stylebox_override("pressed", _fundo(Color(1, 0.85, 0.5, 0.24)))
	if item != "":
		var ic := TextureRect.new()
		ic.texture = Barra.icone(item)
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 6
		ic.offset_top = 6
		ic.offset_right = -6
		ic.offset_bottom = -6
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.modulate = Color.WHITE if tem else Color(0.55, 0.55, 0.55, 0.3)
		b.add_child(ic)
	if qtd != "":
		var l := _label(qtd, 20, Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 6)
		l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		l.offset_left = -40
		l.offset_top = -30
		l.offset_right = -8
		l.offset_bottom = -4
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(l)
	return b


func _clique(item: String, onde: String) -> void:
	var j = jogador
	match [item, onde]:
		["peixe", "balde"]:
			_mostrar("Peixe", "Um peixe passou do balde para a mochila." if j.peixe_para_mochila() else "Não cabe mais peixe na mochila.")
		["peixe", "mochila"]:
			if not j.tem_balde:
				_mostrar("Peixe", "Você não está com o balde.")
			else:
				_mostrar("Peixe", "Um peixe passou da mochila para o balde." if j.peixe_para_balde() else "O balde está cheio.")
		["farofa", _]:
			j.comer_farofa()
			_mostrar("Farofa", "Comeu farofa. Fome: %d" % int(j.fome))
		["farinha", _]:
			j.comer_farinha()
			_mostrar("Farinha d'água", "Comeu um punhado de farinha. Fome: %d" % int(j.fome))
	montar()
