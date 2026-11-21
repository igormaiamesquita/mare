extends ColorRect
## Dormir na rede escolhendo quantas horas. A faixa mostra as próximas 24 h:
## céu (dia/noite), maré (cheia e seca, com horário) e quantas tocas ficam de fora da água.
## Arraste a seta (mouse, roda, A/D ou setas) e confirme com ENTER ou E.

signal escolheu(horas: float)

const DOURADO := Color(1.0, 0.8, 0.42)
const TEXTO := Color(0.93, 0.92, 0.87)
const APAGADO := Color(0.68, 0.66, 0.6)
const JANELA := 24.0            # horas mostradas
const MIN_H := 0.5

var main
var horas := 8.0
var _faixa: Faixa
var _info: RichTextLabel
var _titulo: Label


func _ready() -> void:
	color = Color(0.02, 0.025, 0.035, 0.9)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	centro.add_child(v)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 40)
	_titulo.add_theme_color_override("font_color", DOURADO)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_titulo)
	var sub := Label.new()
	sub.text = "Quanto tempo dormir?  Arraste a seta  ·  roda do mouse ou A / D  ·  ENTER dorme  ·  ESC volta"
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", APAGADO)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	_faixa = Faixa.new()
	_faixa.tela = self
	_faixa.custom_minimum_size = Vector2(1240, 290)
	v.add_child(_faixa)

	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	_info.custom_minimum_size = Vector2(1240, 0)
	_info.add_theme_font_size_override("normal_font_size", 21)
	_info.add_theme_color_override("default_color", TEXTO)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_info)

	var atalhos := HBoxContainer.new()
	atalhos.alignment = BoxContainer.ALIGNMENT_CENTER
	atalhos.add_theme_constant_override("separation", 12)
	v.add_child(atalhos)
	atalhos.add_child(_botao("Até amanhecer", false, func() -> void: _por(_horas_ate_hora(6.0))))
	atalhos.add_child(_botao("Até a próxima maré seca", false, func() -> void: _por(Mundo.horas_ate_mare_baixa() - 0.75)))
	atalhos.add_child(_botao("Até o meio-dia", false, func() -> void: _por(_horas_ate_hora(12.0))))
	var acoes := HBoxContainer.new()
	acoes.alignment = BoxContainer.ALIGNMENT_CENTER
	acoes.add_theme_constant_override("separation", 16)
	v.add_child(acoes)
	acoes.add_child(_botao("Cancelar", false, fechar))
	acoes.add_child(_botao("Dormir", true, confirmar))


func abrir() -> void:
	_titulo.text = "Dormir na rede  ·  agora são %s do dia %d" % [Mundo.texto_hora(), Mundo.dia]
	_faixa.preparar()
	_por(_horas_ate_hora(6.0) if Mundo.hora > 17.0 or Mundo.hora < 5.0 else 3.0)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func fechar() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if main.jogador.estado == main.jogador.Estado.OCUPADO:
		main.jogador.ocupar(false)
	Mundo.rodando = true


func confirmar() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	escolheu.emit(horas)


func _horas_ate_hora(h: float) -> float:
	var d := fposmod(h - Mundo.hora, 24.0)
	return d if d >= MIN_H else d + 24.0


func _por(h: float) -> void:
	horas = clampf(snappedf(h, 0.25), MIN_H, JANELA)
	_faixa.queue_redraw()
	_info.text = "[center]" + _texto_info() + "[/center]"


func _texto_info() -> String:
	var t: float = Mundo.tempo_total() + horas
	var hora_acorda := fposmod(Mundo.hora + horas, 24.0)
	var dia_acorda := Mundo.dia + int(floor((Mundo.hora + horas) / 24.0))
	var sol := sin((hora_acorda - 6.0) / 12.0 * PI)
	var ceu := "dia claro" if sol > 0.25 else ("amanhecendo" if sol > -0.1 and hora_acorda < 12.0 else ("entardecendo" if sol > -0.1 else "noite"))
	var subindo: bool = Mundo.nivel_mare_em(t + 0.05) > Mundo.nivel_mare_em(t)
	var tocas := _faixa.tocas_de_fora(t)
	var linhas := []
	linhas.append("Dormir [color=#f2cf7a]%s[/color]  →  acorda às [color=#f2cf7a]%s[/color] do dia %d  ·  %s" % [
		Mundo.texto_duracao(horas), _hhmm(hora_acorda), dia_acorda, ceu])
	var mare := "maré ENCHENDO" if subindo else "maré VAZANDO"
	var cor_t := "#9be58f" if tocas > 0.5 else ("#e8d27a" if tocas > 0.15 else "#ef8a7a")
	linhas.append("%s  ·  [color=%s]%d%% das tocas fora d'água[/color]" % [mare, cor_t, int(tocas * 100.0)])
	var fome_acorda: float = main.jogador.fome - horas * 1.6
	if fome_acorda < 15.0:
		linhas.append("[color=#ef8a7a]Vai acordar com muita fome. Coma antes de dormir.[/color]")
	return "\n".join(linhas)


static func _hhmm(h: float) -> String:
	var hh := int(h)
	return "%02d:%02d" % [hh, int((h - hh) * 60.0)]


func _botao(texto: String, destaque: bool, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(250, 50)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.13, 0.08, 0.95) if destaque else Color(0.1, 0.1, 0.1, 0.9)
	s.border_color = DOURADO if destaque else Color(1, 0.8, 0.42, 0.4)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", s)
	var s2 := s.duplicate() as StyleBoxFlat
	s2.bg_color = Color(0.3, 0.24, 0.12, 0.95)
	s2.border_color = DOURADO
	b.add_theme_stylebox_override("hover", s2)
	b.add_theme_stylebox_override("pressed", s2)
	b.add_theme_color_override("font_color", DOURADO if destaque else TEXTO)
	b.pressed.connect(acao)
	return b


func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("pausa"):
		get_viewport().set_input_as_handled()
		fechar()
	elif e is InputEventKey and e.pressed:
		var k := (e as InputEventKey).physical_keycode
		if k in [KEY_ENTER, KEY_KP_ENTER, KEY_E] and not e.echo:
			get_viewport().set_input_as_handled()
			confirmar()
		elif k in [KEY_D, KEY_RIGHT]:
			get_viewport().set_input_as_handled()
			_por(horas + 0.5)
		elif k in [KEY_A, KEY_LEFT]:
			get_viewport().set_input_as_handled()
			_por(horas - 0.5)


# ------------------------------------------------------------------ a faixa das próximas 24 h

class Faixa extends Control:
	var tela
	var _amostras := []        # [horas_a_frente, nivel, fração de tocas de fora]
	var _extremos := []        # [horas_a_frente, "cheia"/"seca", nivel]
	var _arrastando := false
	const PASSO := 0.25
	const MARGEM := 24.0

	func preparar() -> void:
		_amostras.clear()
		_extremos.clear()
		var t0: float = Mundo.tempo_total()
		var alturas := []
		for tc in tela.main.tocas:
			alturas.append(tc.global_position.y)
		var h := 0.0
		while h <= tela.JANELA + 0.001:
			var n: float = Mundo.nivel_mare_em(t0 + h)
			var fora := 0
			for a in alturas:
				if a + 0.03 >= n:
					fora += 1
			_amostras.append([h, n, float(fora) / maxf(1.0, alturas.size())])
			h += PASSO
		for i in range(1, _amostras.size() - 1):
			var a: float = _amostras[i - 1][1]
			var b: float = _amostras[i][1]
			var c: float = _amostras[i + 1][1]
			if b >= a and b > c:
				_extremos.append([_amostras[i][0], "cheia", b])
			elif b <= a and b < c:
				_extremos.append([_amostras[i][0], "seca", b])
		queue_redraw()

	func tocas_de_fora(t: float) -> float:
		var h := clampf(t - Mundo.tempo_total(), 0.0, tela.JANELA)
		var i := clampi(int(round(h / PASSO)), 0, _amostras.size() - 1)
		return _amostras[i][2] if not _amostras.is_empty() else 0.0

	func _x(h: float) -> float:
		return MARGEM + h / tela.JANELA * (size.x - MARGEM * 2.0)

	func _h(x: float) -> float:
		return (x - MARGEM) / (size.x - MARGEM * 2.0) * tela.JANELA

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			var mb := e as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_arrastando = mb.pressed
				if mb.pressed:
					tela._por(_h(mb.position.x))
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				tela._por(tela.horas + 0.5)
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				tela._por(tela.horas - 0.5)
		elif e is InputEventMouseMotion and _arrastando:
			tela._por(_h((e as InputEventMouseMotion).position.x))

	func _draw() -> void:
		if _amostras.is_empty():
			return
		var f := get_theme_default_font()
		var topo := 34.0
		var ceu_alt := 70.0
		var mare_top := topo + ceu_alt + 8.0
		var mare_alt := 90.0
		var tocas_y := mare_top + mare_alt + 6.0
		var larg := (size.x - MARGEM * 2.0) / (_amostras.size() - 1)
		# céu: cor de cada pedaço pela altura do sol
		for s in _amostras:
			var hh: float = fposmod(Mundo.hora + s[0], 24.0)
			var sol := sin((hh - 6.0) / 12.0 * PI)
			var noite := Color(0.05, 0.07, 0.17)
			var crep := Color(0.86, 0.46, 0.26)
			var dia := Color(0.46, 0.66, 0.9)
			var c := noite.lerp(crep, clampf((sol + 0.12) / 0.2, 0.0, 1.0))
			c = c.lerp(dia, clampf((sol - 0.08) / 0.3, 0.0, 1.0))
			draw_rect(Rect2(_x(s[0]) - larg * 0.5, topo, larg + 1.0, ceu_alt), c)
		# horas do relógio a cada 3 h
		for s in _amostras:
			var hh2: float = Mundo.hora + s[0]
			var cheia := fposmod(hh2, 3.0)
			if cheia < PASSO * 0.999:
				var x := _x(s[0] - cheia)
				var rel := int(round(hh2 - cheia)) % 24
				draw_line(Vector2(x, topo), Vector2(x, tocas_y + 18.0), Color(1, 1, 1, 0.12), 1.0)
				var icone := "☀" if rel >= 6 and rel <= 15 else ("☾" if rel >= 19 or rel <= 3 else "")
				draw_string(f, Vector2(x - 22, topo + ceu_alt - 10), "%02dh %s" % [rel, icone], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.85))
		# maré: área azul
		var lo := -2.6
		var hi := 2.8
		var pts := PackedVector2Array()
		pts.append(Vector2(_x(0.0), mare_top + mare_alt))
		for s in _amostras:
			var y: float = mare_top + mare_alt - (float(s[1]) - lo) / (hi - lo) * mare_alt
			pts.append(Vector2(_x(s[0]), y))
		pts.append(Vector2(_x(tela.JANELA), mare_top + mare_alt))
		draw_rect(Rect2(MARGEM, mare_top, size.x - MARGEM * 2.0, mare_alt), Color(0.06, 0.07, 0.06))
		draw_colored_polygon(pts, Color(0.2, 0.42, 0.62, 0.9))
		draw_polyline(pts.slice(1, pts.size() - 1), Color(0.6, 0.82, 1.0), 2.0, true)
		draw_string(f, Vector2(MARGEM + 4, mare_top + 16), "MARÉ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.75, 0.88, 1.0, 0.8))
		for ex in _extremos:
			var xe := _x(ex[0])
			var ye: float = mare_top + mare_alt - (float(ex[2]) - lo) / (hi - lo) * mare_alt
			var hh3: float = fposmod(Mundo.hora + ex[0], 24.0)
			var txt := "%s %s" % [ex[1], tela._hhmm(hh3)]
			var yt := ye - 8.0 if ex[1] == "cheia" else ye + 20.0
			draw_circle(Vector2(xe, ye), 4.0, Color.WHITE)
			draw_string(f, Vector2(xe - 44, yt), txt, HORIZONTAL_ALIGNMENT_CENTER, 88, 15, Color.WHITE)
		# tocas de fora: faixa verde (mais forte = mais tocas para catar)
		for s in _amostras:
			var a: float = s[2]
			draw_rect(Rect2(_x(s[0]) - larg * 0.5, tocas_y, larg + 1.0, 14.0), Color(0.42, 0.85, 0.36, 0.12 + a * 0.85))
		draw_string(f, Vector2(MARGEM, tocas_y + 80.0), "Verde forte = muitas tocas fora d'água (hora boa de catar caranguejo)", HORIZONTAL_ALIGNMENT_RIGHT, size.x - MARGEM * 2.0, 14, Color(0.7, 0.85, 0.65, 0.85))
		# a seta: até onde vai dormir
		var xs := _x(tela.horas)
		draw_rect(Rect2(MARGEM, topo, xs - MARGEM, tocas_y + 14.0 - topo), Color(0, 0, 0, 0.35))
		draw_line(Vector2(xs, topo - 4.0), Vector2(xs, tocas_y + 18.0), tela.DOURADO, 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(xs - 11, 4), Vector2(xs + 11, 4), Vector2(xs, 24)]), tela.DOURADO)
		draw_string(f, Vector2(xs - 60, tocas_y + 56.0), "acorda " + tela._hhmm(fposmod(Mundo.hora + tela.horas, 24.0)), HORIZONTAL_ALIGNMENT_CENTER, 120, 17, tela.DOURADO)
		draw_string(f, Vector2(MARGEM - 10, tocas_y + 56.0), "agora", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.6))
