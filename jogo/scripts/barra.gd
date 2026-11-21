extends Control
## Barra de baixo: atalhos 1–9 (centro) e o que se carrega (direita: balde, mochila, galochas).
## Sem caixas: cada ícone tem só uma sombra redonda por trás para ler em cima do cenário.

const DOURADO := Color(1.0, 0.8, 0.42)
const NOMES := {"facao": "Facão", "tarrafa": "Tarrafa", "lanterna": "Lanterna", "farofa": "Farofa", "farinha": "Farinha d'água",
	"balde": "Balde", "mochila": "Mochila", "galochas": "Galochas"}

var jogador
var _slots: Array[Slot] = []
var _carga := {}
var _nome: Label
var _ultimo_na_mao := ""


static func icone(nome: String) -> Texture2D:
	var caminho := "res://assets/icones/%s.png" % nome
	return load(caminho) if ResourceLoader.exists(caminho) else null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# faixa escura e macia no pé da tela: a barra e as barras de vida leem em cima de qualquer chão
	var faixa := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0))
	gr.set_color(1, Color(0, 0, 0, 0.5))
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	faixa.texture = gt
	faixa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	faixa.stretch_mode = TextureRect.STRETCH_SCALE
	faixa.anchor_top = 1.0
	faixa.anchor_bottom = 1.0
	faixa.anchor_right = 1.0
	faixa.offset_top = -170
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(faixa)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 2)
	linha.anchor_left = 0.5
	linha.anchor_right = 0.5
	linha.anchor_top = 1.0
	linha.anchor_bottom = 1.0
	linha.offset_left = -9 * 84 / 2.0
	linha.offset_right = 9 * 84 / 2.0
	linha.offset_top = -112
	linha.offset_bottom = -12
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(linha)
	for i in 9:
		var s := Slot.new()
		s.numero = i + 1
		s.custom_minimum_size = Vector2(82, 98)
		linha.add_child(s)
		_slots.append(s)
	_nome = Label.new()
	_nome.add_theme_font_size_override("font_size", 20)
	_nome.add_theme_color_override("font_color", DOURADO)
	_nome.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_nome.add_theme_constant_override("outline_size", 6)
	_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nome.anchor_left = 0.5
	_nome.anchor_right = 0.5
	_nome.anchor_top = 1.0
	_nome.anchor_bottom = 1.0
	_nome.offset_left = -200
	_nome.offset_right = 200
	_nome.offset_top = -146
	_nome.offset_bottom = -114
	_nome.modulate.a = 0.0
	add_child(_nome)

	var dir := HBoxContainer.new()
	dir.add_theme_constant_override("separation", 6)
	dir.anchor_left = 1.0
	dir.anchor_right = 1.0
	dir.anchor_top = 1.0
	dir.anchor_bottom = 1.0
	dir.offset_left = -3 * 92 - 24
	dir.offset_right = -24
	dir.offset_top = -112
	dir.offset_bottom = -12
	dir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dir)
	for nome in ["balde", "mochila", "galochas"]:
		var s := Slot.new()
		s.icone = icone(nome)
		s.custom_minimum_size = Vector2(90, 98)
		dir.add_child(s)
		_carga[nome] = s


## Mostra o nome do item em cima da barra por um instante.
func anunciar(texto: String) -> void:
	_nome.text = texto
	var tw := create_tween()
	_nome.modulate.a = 1.0
	tw.tween_interval(1.2)
	tw.tween_property(_nome, "modulate:a", 0.0, 0.5)


func _process(_delta: float) -> void:
	if jogador == null:
		return
	var j = jogador
	for i in 9:
		var s := _slots[i]
		var nome: String = j.ATALHOS[i]
		s.icone = icone(nome) if nome != "" else null
		s.tem = j.tem_atalho(nome)
		s.selecionado = nome != "" and nome == j.na_mao
		s.aceso = nome == "lanterna" and j.lanterna.light_energy > 0.0
		s.qtd = str(j.mochila["farofa"]) if nome == "farofa" and j.mochila["farofa"] > 0 else ""
		s.queue_redraw()
	var b: Slot = _carga["balde"]
	b.tem = j.tem_balde
	b.qtd = "%d/%d" % [j.caranguejos + j.peixes + j.aratus, j.capacidade_balde] if j.tem_balde else "—"
	b.queue_redraw()
	var m: Slot = _carga["mochila"]
	m.tem = true
	m.qtd = "%d/%d" % [j.espacos_usados(), j.MOCHILA_ESPACOS]
	m.queue_redraw()
	var g: Slot = _carga["galochas"]
	g.tem = j.galochas
	g.qtd = "" if j.galochas else "—"
	g.queue_redraw()
	if j.na_mao != _ultimo_na_mao:
		if _ultimo_na_mao != "":
			anunciar(NOMES.get(j.na_mao, ""))
		_ultimo_na_mao = j.na_mao


class Slot extends Control:
	var numero := 0
	var icone: Texture2D
	var tem := false
	var selecionado := false
	var aceso := false
	var qtd := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := get_theme_default_font()
		var c := Vector2(size.x * 0.5, 48.0)
		# sombra redonda e macia (círculos sobrepostos)
		for k in 7:
			draw_circle(c, 38.0 - k * 4.0, Color(0, 0, 0, 0.08))
		if aceso:
			for k in 4:
				draw_circle(c, 30.0 - k * 6.0, Color(1.0, 0.85, 0.45, 0.07))
		if icone != null:
			var t := 78.0 if selecionado else 68.0
			var cor := Color.WHITE if tem else Color(0.55, 0.55, 0.55, 0.32)
			draw_texture_rect(icone, Rect2(c - Vector2(t, t) * 0.5, Vector2(t, t)), false, cor)
		elif numero > 0:
			draw_circle(c, 2.5, Color(1, 1, 1, 0.25))
		if selecionado:
			draw_line(Vector2(c.x - 22, 92), Vector2(c.x + 22, 92), Color(1.0, 0.8, 0.42), 3.0, true)
		if numero > 0:
			var corn := Color(1, 1, 1, 0.9 if tem else 0.4)
			draw_string_outline(f, Vector2(6, 18), str(numero), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.8))
			draw_string(f, Vector2(6, 18), str(numero), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, corn)
		if qtd != "":
			var pos := Vector2(0, 86)
			draw_string_outline(f, pos, qtd, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6, 17, 5, Color(0, 0, 0, 0.85))
			draw_string(f, pos, qtd, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6, 17, Color(1, 1, 1, 0.95 if tem else 0.5))
