extends CanvasLayer
## Interface: objetivo, bússola, data/hora/maré, minimapa, barras, ferramentas, avisos,
## roda da toca, mapa grande (M) e telas de início, pausa e fim.
## Medidas pensadas para 1600 × 900 (a tela grande escala junto).

var main
var jogador
var missoes

var raiz: Control
var obj_texto: Label
var lbl_missao: Label
var obj_detalhe: Label
var bussola: Bussola
var lbl_hora: Label
var lbl_mare: Label
var barra_fome: ProgressBar
var barra_forca: ProgressBar
var barra_saude: ProgressBar
var muricocas: Muricocas
var lbl_estado: Label
var barra: Control
var minimapa: Mapa
var mapa_grande: Control
var mapa_vista: Mapa
var legenda_mapa: Label
var lbl_sono: Label
var lbl_ajuda: Label
var lbl_prompt: Label
var avisos: VBoxContainer
var roda: RodaToca
var marcadores: Marcadores
var lbl_decisao: Label
var painel_decisao: PanelContainer
var flash: ColorRect
var vinheta: ColorRect
var agua_tela: ColorRect
var cortina: ColorRect
var tela_inicio: Control
var tela_pausa: Control
var tela_fim: Control
var tela_config: Control
var tela_sono: Control
var painel_passos: PanelContainer
var txt_passos: RichTextLabel
var _linha_inicio: Control
var lbl_fim: Label
var iniciado := false
var _mapa_aberto := false
var _inv_aberto := false
var inventario: Control

const DESCRICAO := {
	"peixe": "Peixe. Cabe no balde ou na mochila (3 por espaço). Clique para passar para o outro lado.",
	"caranguejo": "Caranguejo-uçá. Só vai no balde: na mochila ele foge e belisca.",
	"aratu": "Aratu: caranguejo pequeno que sobe nas raízes na maré cheia. Vai no balde; cozinha junto.",
	"lenha": "Feixe de lenha seca (2 por espaço). Para o fogão e o jirau.",
	"farinha": "Cuia de farinha d'água (atalho 5). Com caranguejo ou peixe cozido, a comida sustenta mais e dá saúde. Pura, engana um pouco a fome.",
	"farofa": "Farofa (2 por espaço, atalho 4). Engana a fome em qualquer lugar.",
	"helice": "Hélice do motor de rabeta. Leve até a canoa.",
	"remo": "Remo. Serve quando a gasolina acaba.",
	"cuia": "Cuia para tirar a água que entra na canoa.",
	"galao": "Galão de gasolina para o motor.",
	"breu": "Lata de breu e estopa: tapa o furo do casco.",
	"motor": "Motor de rabeta (ocupa 3 espaços). Precisa ser lavado com água doce antes de instalar.",
}
const NOME_ITEM := {"peixe": "Peixe", "caranguejo": "Caranguejo-uçá", "aratu": "Aratu", "lenha": "Lenha", "farinha": "Farinha d'água", "farofa": "Farofa",
	"helice": "Hélice", "remo": "Remo", "cuia": "Cuia", "galao": "Galão", "breu": "Breu", "motor": "Motor"}
const COR_ITEM := {"peixe": Color(0.6, 0.75, 0.85), "caranguejo": Color(0.85, 0.5, 0.4), "aratu": Color(0.95, 0.4, 0.3), "lenha": Color(0.75, 0.6, 0.4), "farinha": Color(0.95, 0.9, 0.7), "farofa": Color(0.9, 0.75, 0.45),
	"helice": Color(0.45, 0.85, 1.0), "remo": Color(0.45, 0.85, 1.0), "cuia": Color(0.45, 0.85, 1.0), "galao": Color(0.45, 0.85, 1.0), "breu": Color(0.45, 0.85, 1.0), "motor": Color(0.45, 0.85, 1.0)}

const DOURADO := Color(1.0, 0.8, 0.42)
const BRANCO := Color(0.96, 0.96, 0.93)


func _ready() -> void:
	layer = 5
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	agua_tela = _tela_cheia(Color(0.24, 0.19, 0.09, 0.82))
	agua_tela.visible = false
	vinheta = _tela_cheia(Color.WHITE)
	var vm := ShaderMaterial.new()
	vm.shader = load("res://shaders/vinheta.gdshader")
	vinheta.material = vm
	flash = _tela_cheia(Color(0.75, 0.0, 0.0, 0.0))
	muricocas = Muricocas.new()
	muricocas.set_anchors_preset(Control.PRESET_FULL_RECT)
	muricocas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(muricocas)

	# ---- objetivo (canto superior esquerdo)
	var caixa := VBoxContainer.new()
	caixa.position = Vector2(32, 26)
	caixa.add_theme_constant_override("separation", 3)
	raiz.add_child(caixa)
	lbl_missao = _label("MISSÃO", 17, DOURADO)
	caixa.add_child(lbl_missao)
	obj_texto = _label("", 27)
	obj_texto.custom_minimum_size.x = 390
	obj_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(obj_texto)
	obj_detalhe = _label("", 20, Color(0.88, 0.88, 0.84))
	obj_detalhe.custom_minimum_size.x = 390
	obj_detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(obj_detalhe)

	# ---- bússola, data/hora e maré (topo, centro)
	bussola = Bussola.new()
	_centro(bussola, 10, 600, 96)
	raiz.add_child(bussola)
	lbl_hora = _label("", 22)
	lbl_hora.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_centro(lbl_hora, 122, 640, 30)
	raiz.add_child(lbl_hora)
	lbl_mare = _label("", 19, Color(0.75, 0.88, 1.0))
	lbl_mare.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_centro(lbl_mare, 150, 760, 56)
	raiz.add_child(lbl_mare)

	# ---- minimapa e barras (canto inferior esquerdo)
	minimapa = Mapa.new()
	minimapa.redondo = true
	minimapa.zoom = 0.32
	minimapa.anchor_top = 1.0
	minimapa.anchor_bottom = 1.0
	minimapa.offset_left = 30
	minimapa.offset_right = 250
	minimapa.offset_top = -404
	minimapa.offset_bottom = -184
	raiz.add_child(minimapa)
	var dica_mapa := _label("M  mapa", 16, Color(1, 1, 1, 0.75))
	dica_mapa.anchor_top = 1.0
	dica_mapa.anchor_bottom = 1.0
	dica_mapa.offset_left = 180
	dica_mapa.offset_top = -204
	raiz.add_child(dica_mapa)

	var baixo := VBoxContainer.new()
	baixo.anchor_top = 1.0
	baixo.anchor_bottom = 1.0
	baixo.offset_left = 30
	baixo.offset_top = -176
	baixo.offset_right = 420
	baixo.offset_bottom = -22
	baixo.add_theme_constant_override("separation", 5)
	raiz.add_child(baixo)
	baixo.add_child(_label("SAÚDE", 17, Color(1, 0.5, 0.5)))
	barra_saude = _barra(Color(0.9, 0.3, 0.3))
	baixo.add_child(barra_saude)
	baixo.add_child(_label("FOME", 17, Color(1, 0.75, 0.45)))
	barra_fome = _barra(Color(0.95, 0.6, 0.25))
	baixo.add_child(barra_fome)
	baixo.add_child(_label("FORÇA", 17, Color(0.85, 0.95, 0.85)))
	barra_forca = _barra(Color(0.85, 0.92, 0.8))
	baixo.add_child(barra_forca)
	lbl_estado = _label("", 18, Color(1, 0.6, 0.5))
	baixo.add_child(lbl_estado)

	# ---- atalhos 1–9 e o que se carrega (barra.gd)
	barra = Control.new()
	barra.set_script(load("res://scripts/barra.gd"))
	barra.jogador = jogador
	raiz.add_child(barra)

	# ---- mira, texto de interação
	var mira := _label("·", 34, Color(1, 1, 1, 0.85))
	mira.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meio(mira, Vector2(-20, -26), Vector2(20, 18))
	raiz.add_child(mira)
	lbl_prompt = _label("", 25)
	lbl_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meio(lbl_prompt, Vector2(-440, 40), Vector2(440, 84))
	raiz.add_child(lbl_prompt)

	# ---- marcadores em cima das tocas por perto
	marcadores = Marcadores.new()
	marcadores.set_anchors_preset(Control.PRESET_FULL_RECT)
	marcadores.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(marcadores)

	# ---- avisos (direita)
	avisos = VBoxContainer.new()
	avisos.anchor_left = 1.0
	avisos.anchor_right = 1.0
	avisos.offset_left = -500
	avisos.offset_right = -28
	avisos.offset_top = 210
	avisos.offset_bottom = 700
	avisos.add_theme_constant_override("separation", 8)
	avisos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(avisos)

	# ---- roda da toca (centro) e instrução grande
	roda = RodaToca.new()
	_meio(roda, Vector2(-150, -150), Vector2(150, 150))
	roda.visible = false
	raiz.add_child(roda)
	lbl_ajuda = _label("", 28, DOURADO)
	lbl_ajuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ajuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meio(lbl_ajuda, Vector2(-480, 170), Vector2(480, 270))
	raiz.add_child(lbl_ajuda)

	# ---- decisão (segurando o caranguejo)
	painel_decisao = _painel()
	painel_decisao.anchor_left = 0.5
	painel_decisao.anchor_right = 0.5
	painel_decisao.anchor_top = 1.0
	painel_decisao.anchor_bottom = 1.0
	painel_decisao.offset_left = -400
	painel_decisao.offset_right = 400
	painel_decisao.offset_top = -250
	painel_decisao.offset_bottom = -130
	raiz.add_child(painel_decisao)
	lbl_decisao = _label("", 25)
	lbl_decisao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_decisao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	painel_decisao.add_child(lbl_decisao)
	painel_decisao.visible = false

	# ---- mapa grande (M)
	mapa_grande = ColorRect.new()
	(mapa_grande as ColorRect).color = Color(0.03, 0.035, 0.04, 0.92)
	mapa_grande.set_anchors_preset(Control.PRESET_FULL_RECT)
	mapa_grande.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mapa_grande.visible = false
	raiz.add_child(mapa_grande)
	mapa_vista = Mapa.new()
	mapa_vista.zoom = 1.0
	mapa_vista.mostrar_nomes = true
	_meio(mapa_vista, Vector2(-400, -400), Vector2(400, 400))
	mapa_grande.add_child(mapa_vista)
	legenda_mapa = _label("", 18, Color(0.75, 0.88, 1.0))
	legenda_mapa.position = Vector2(40, 420)
	mapa_grande.add_child(legenda_mapa)
	var legenda := _label("MAPA     M fecha\n\nAzul: água agora (maré)\nVerde-escuro: mato fechado\nMarrom: lama firme\nQuase preto: lama mole (atola)\nVerde-claro: terra firme\nTriângulo verde: teso (lugar alto)\nCírculo azul: área onde procurar uma peça\nSeta branca: você", 19)
	legenda.position = Vector2(40, 40)
	mapa_grande.add_child(legenda)

	_criar_inventario()
	cortina = _tela_cheia(Color(0, 0, 0, 0))
	lbl_sono = _label("", 40)
	lbl_sono.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sono.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_sono.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_sono.visible = false
	raiz.add_child(lbl_sono)
	# ---- primeiros passos (embaixo, no centro)
	painel_passos = _painel()
	painel_passos.anchor_left = 0.5
	painel_passos.anchor_right = 0.5
	painel_passos.anchor_top = 1.0
	painel_passos.anchor_bottom = 1.0
	painel_passos.offset_left = -470
	painel_passos.offset_right = 470
	painel_passos.offset_top = -285
	painel_passos.offset_bottom = -182
	painel_passos.grow_vertical = Control.GROW_DIRECTION_BEGIN
	raiz.add_child(painel_passos)
	txt_passos = RichTextLabel.new()
	txt_passos.bbcode_enabled = true
	txt_passos.fit_content = true
	txt_passos.scroll_active = false
	txt_passos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt_passos.add_theme_font_size_override("normal_font_size", 20)
	txt_passos.add_theme_color_override("default_color", BRANCO)
	painel_passos.add_child(txt_passos)
	painel_passos.visible = false

	_criar_telas()
	tela_config = ColorRect.new()
	tela_config.set_script(load("res://scripts/tela_config.gd"))
	tela_config.main = main
	raiz.add_child(tela_config)
	tela_sono = ColorRect.new()
	tela_sono.set_script(load("res://scripts/tela_sono.gd"))
	tela_sono.main = main
	raiz.add_child(tela_sono)
	tela_sono.escolheu.connect(func(h: float) -> void: jogador.dormir_horas(h))
	Mundo.noticia.connect(_noticia)
	_ligar_mapas.call_deferred()
	preparar_inicio.call_deferred()


func _ligar_mapas() -> void:
	for m in [minimapa, mapa_vista]:
		m.hud = self
		m.preparar(main.mapa_alt, main.mapa_cor)


# ------------------------------------------------------------------ construção

func _label(texto: String, tamanho: int, cor: Color = BRANCO) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _tela_cheia(cor: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = cor
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(r)
	return r


func _centro(c: Control, y: float, largura: float, altura: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.offset_left = -largura / 2.0
	c.offset_right = largura / 2.0
	c.offset_top = y
	c.offset_bottom = y + altura
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _meio(c: Control, a: Vector2, b: Vector2) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = a.x
	c.offset_top = a.y
	c.offset_right = b.x
	c.offset_bottom = b.y
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _barra(cor: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(320, 14)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0, 0, 0, 0.5)
	fundo.set_corner_radius_all(5)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = cor
	cheio.set_corner_radius_all(5)
	b.add_theme_stylebox_override("background", fundo)
	b.add_theme_stylebox_override("fill", cheio)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _painel() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.045, 0.035, 0.8)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(12)
	s.border_color = Color(1, 0.8, 0.42, 0.35)
	s.border_width_top = 2
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _criar_telas() -> void:
	tela_inicio = _tela_overlay(
		"MARÉ",
		"sobrevivência no mangue",
		"Você mora num rancho na beira do mangue. A comida está na lama, e quem manda no relógio é a maré.\n\n" +
		"A maré sobe duas vezes por dia. Volte ao rancho ou suba num teso antes que a água chegue no peito.\n" +
		"Os primeiros passos ensinam os controles; a lista completa fica em Configurações → Controles.",
		"")
	tela_pausa = _tela_overlay("PAUSA", "", "O jogo salva sozinho a cada 2 minutos, ao dormir e ao fechar a janela.", "")
	tela_pausa.set_meta("com_botoes", true)
	_botoes(tela_pausa, [
		["Continuar", true, continuar],
		["Configurações", false, _abrir_config],
		["Pular os primeiros passos", false, _pular_passos, "pular"],
		["Novo jogo", false, _novo_jogo_pausa, "novo"],
		["Salvar e sair", false, _sair],
	])
	tela_pausa.visible = false
	tela_fim = _tela_overlay("CARANGUEJO COM CÉREBRO", "missão concluída", "", "Clique para continuar no mangue")
	lbl_fim = tela_fim.get_meta("corpo")
	tela_fim.visible = false


func _tela_overlay(titulo: String, sub: String, corpo: String, rodape: String) -> Control:
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.03, 0.025, 0.88)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	raiz.add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.add_child(centro)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	centro.add_child(v)
	if titulo == "MARÉ":
		var logo := TextureRect.new()
		logo.texture = load("res://assets/logo_caranguejo.png")
		logo.custom_minimum_size = Vector2(220, 220)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(logo)
	var t := _label(titulo, 64 if titulo.length() > 14 else 90, DOURADO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if sub != "":
		var s := _label(sub, 28, Color(0.9, 0.9, 0.85))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
	var c := _label(corpo, 20, Color(0.9, 0.9, 0.86))
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.custom_minimum_size.x = 1250
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(c)
	fundo.set_meta("corpo", c)
	var r := _label(rodape, 24, Color(1, 1, 1, 0.9))
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(r)
	var tw := create_tween().set_loops()
	tw.tween_property(r, "modulate:a", 0.35, 0.9)
	tw.tween_property(r, "modulate:a", 1.0, 0.9)
	fundo.gui_input.connect(_clique_tela.bind(fundo))
	return fundo


func _clique_tela(e: InputEvent, tela: Control) -> void:
	if tela.has_meta("com_botoes"):
		return
	if e is InputEventMouseButton and e.pressed:
		tela.visible = false
		if tela == tela_inicio:
			comecar()
		else:
			continuar()


## Tela inicial: Continuar (se houver jogo salvo), Novo jogo, Configurações e Sair.
func preparar_inicio() -> void:
	tela_inicio.set_meta("com_botoes", true)
	if _linha_inicio != null:
		_linha_inicio.queue_free()
	var lista := []
	if main.salvador != null and main.salvador.existe() and main.salvador.ativo:
		lista.append(["Continuar  (" + main.salvador.resumo() + ")", true, _continuar_salvo])
		lista.append(["Novo jogo", false, _novo_jogo])
	else:
		lista.append(["Começar", true, comecar])
	lista.append(["Configurações", false, _abrir_config])
	lista.append(["Sair", false, get_tree().quit])
	_linha_inicio = _botoes(tela_inicio, lista)
	if Config.comecar_direto:
		Config.comecar_direto = false
		comecar()


## Linha de botões no fim de uma tela (início/pausa). Cada item: [texto, destaque, ação, nome opcional].
func _botoes(tela: Control, lista: Array) -> Control:
	var v: VBoxContainer = tela.get_child(0).get_child(0)
	v.get_child(v.get_child_count() - 1).visible = false      # o "clique para ..." piscando
	var coluna := VBoxContainer.new()
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_theme_constant_override("separation", 10)
	coluna.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(coluna)
	for item in lista:
		var b := _botao(item[0], item[1])
		b.pressed.connect(item[2])
		if item.size() > 3:
			b.name = item[3]
		coluna.add_child(b)
	return coluna


func _botao(texto: String, destaque: bool) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(420, 54)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
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
	b.add_theme_color_override("font_color", DOURADO if destaque else BRANCO)
	b.add_theme_color_override("font_hover_color", DOURADO)
	return b


func _continuar_salvo() -> void:
	main.salvador.carregar()
	comecar()


func _novo_jogo() -> void:
	main.salvador.apagar()
	comecar()


func _abrir_config() -> void:
	tela_config.abrir()


func _pular_passos() -> void:
	main.tutorial.pular()
	continuar()


## Pede confirmação (segundo clique), apaga o jogo salvo e recomeça do zero.
func _novo_jogo_pausa() -> void:
	var b := tela_pausa.find_child("novo", true, false) as Button
	if not b.has_meta("confirmar"):
		b.set_meta("confirmar", true)
		b.text = "Apagar o jogo atual e começar de novo?  (clique de novo)"
		b.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		return
	main.salvador.apagar()
	main.salvador.ativo = false        # não deixa salvar o jogo velho por cima no caminho
	Mundo.reiniciar()
	Config.comecar_direto = true
	get_tree().reload_current_scene()


func _sair() -> void:
	if main.salvador.ativo:
		main.salvador.salvar()
	get_tree().quit()


func comecar() -> void:
	tela_inicio.visible = false
	iniciado = true
	continuar()
	Mundo.avisar("Objetivo: " + missoes.titulo(), "objetivo")


func continuar() -> void:
	var novo := tela_pausa.find_child("novo", true, false) as Button
	if novo != null and novo.has_meta("confirmar"):
		novo.remove_meta("confirmar")
		novo.text = "Novo jogo"
		novo.add_theme_color_override("font_color", BRANCO)
	tela_pausa.visible = false
	tela_fim.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Mundo.rodando = true


func abrir_mapa(sim: bool) -> void:
	_mapa_aberto = sim
	if sim:
		if main.cultura.sinal:
			legenda_mapa.text = "TÁBUA DE MARÉS\n(sinal da parabólica)\n\n" + main.cultura.tabua()
		else:
			legenda_mapa.text = "Sem sinal: ajuste a\nparabólica na lama para\nver os nomes e a tábua\nde marés."
	mapa_grande.visible = sim
	Mundo.rodando = not sim


func _unhandled_input(e: InputEvent) -> void:
	if not iniciado:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_M and not _inv_aberto:
		if _mapa_aberto or Mundo.rodando:
			abrir_mapa(not _mapa_aberto)
		return
	if e is InputEventKey and e.pressed and not e.echo and (e.physical_keycode == KEY_I or e.physical_keycode == KEY_TAB) and not _mapa_aberto:
		if _inv_aberto or (Mundo.rodando and jogador.andando()):
			abrir_inventario(not _inv_aberto)
		return
	if e.is_action_pressed("pausa"):
		if _inv_aberto:
			abrir_inventario(false)
		elif _mapa_aberto:
			abrir_mapa(false)
		elif tela_pausa.visible:
			continuar()
		elif Mundo.rodando:
			Mundo.rodando = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			var pular := tela_pausa.find_child("pular", true, false)
			if pular != null:
				pular.visible = main.tutorial.ativo
			tela_pausa.visible = true
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and Mundo.rodando:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func tela_rabeta() -> void:
	lbl_fim.text = "Você consertou a canoa com peças achadas no mangue, lavou o motor com água da chuva\ne atravessou a baía até a ilha.\n\nAgora o mapa é maior: a maré manda também no caminho da canoa."
	(tela_fim.get_child(0).get_child(0).get_child(0) as Label).text = "PARABÓLICA NA LAMA"
	Mundo.rodando = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tela_fim.visible = true


func tela_final() -> void:
	var s: Dictionary = jogador.stats
	(tela_fim.get_child(0).get_child(0).get_child(0) as Label).text = "CARANGUEJO COM CÉREBRO"
	var rep := "O mangue está agradecido." if jogador.reputacao > 0 else ("Tirou o que não devia." if jogador.reputacao < 0 else "Nem bem, nem mal com o mangue.")
	lbl_fim.text = "O caranguejo tem cérebro: se esconde, corre e se defende. Mesmo assim, você pegou, cozinhou e comeu antes da maré fechar o caminho.\n\n" + \
		"Caranguejos pegos: %d     Soltos: %d     Pinçadas: %d     Perdidos para a maré: %d\n%s\n\nTerminou às %s do dia %d." % [
			s["pegos"], s["soltos"], s["pincadas"], s["perdidos"], rep, Mundo.texto_hora(), Mundo.dia]
	Mundo.rodando = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tela_fim.visible = true


# ------------------------------------------------------------------ inventário (I)

func _criar_inventario() -> void:
	inventario = ColorRect.new()
	inventario.set_script(load("res://scripts/inventario.gd"))
	inventario.hud = self
	inventario.jogador = jogador
	raiz.add_child(inventario)


func abrir_inventario(sim: bool) -> void:
	_inv_aberto = sim
	Mundo.rodando = not sim
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if sim else Input.MOUSE_MODE_CAPTURED
	if sim:
		inventario.abrir()
	else:
		inventario.visible = false


# ------------------------------------------------------------------ chamadas do jogador

func mostrar_toca(sim: bool) -> void:
	roda.visible = sim


func decisao(texto: String) -> void:
	lbl_decisao.text = texto
	painel_decisao.visible = texto != ""


func dano() -> void:
	flash.color.a = 0.45
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.6)


func escurecer(alfa: float) -> void:
	var tw := create_tween()
	tw.tween_property(cortina, "color:a", alfa, 0.8)
	await tw.finished


## Escurece a tela e mostra o relógio passando (dormir, desmaio).
func passar_tempo(titulo: String, horas: float) -> void:
	var inicio := Mundo.texto_hora()
	lbl_sono.visible = true
	var passos := 40
	for i in passos:
		Mundo.avancar_horas(horas / passos)
		lbl_sono.text = "%s\n\n%s  →  %s\n(%s)" % [titulo, inicio, Mundo.texto_hora(), Mundo.texto_duracao(horas * (i + 1) / passos)]
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.9).timeout
	lbl_sono.visible = false


func _noticia(texto: String, tipo: String) -> void:
	var cor := BRANCO
	if tipo == "perigo":
		cor = Color(1.0, 0.58, 0.48)
	elif tipo == "objetivo":
		cor = DOURADO
	var p := _painel()
	var l := _label(texto, 20, cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 440
	p.add_child(l)
	avisos.add_child(p)
	while avisos.get_child_count() > 4:
		avisos.get_child(0).free()
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(5.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------------------ atualização

func _process(_delta: float) -> void:
	if jogador == null or missoes == null:
		return
	var passos: bool = main.tutorial.ativo
	lbl_missao.text = missoes.nome() if passos else "MISSÃO  ·  " + missoes.nome()
	painel_passos.visible = passos and iniciado and not painel_decisao.visible and not roda.visible and not _inv_aberto and not _mapa_aberto
	if painel_passos.visible:
		var d: String = main.tutorial.dica()
		if txt_passos.get_meta("txt", "") != d:
			txt_passos.set_meta("txt", d)
			txt_passos.text = "[center]" + d + "[/center]"
	obj_texto.text = missoes.titulo()
	obj_detalhe.text = missoes.detalhe()
	bussola.yaw = jogador.yaw_bussola()
	bussola.marcas = main.marcas_bussola()
	bussola.queue_redraw()
	var tempo := ""
	if Mundo.chuva > 0.05:
		tempo = "   ·   chovendo"
	elif Mundo.nuvens > 0.8:
		tempo = "   ·   nublado"
	lbl_hora.text = "%s   ·   %s   ·   %s%s" % [Mundo.texto_data(), Mundo.texto_hora(), Mundo.nome_lua(), tempo]
	lbl_mare.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	lbl_mare.text = _texto_mare()
	barra_fome.value = jogador.fome
	barra_saude.value = jogador.saude
	muricocas.forca = jogador.muricoca
	if jogador.muricoca > 0.05:
		muricocas.queue_redraw()
	barra_forca.value = jogador.estamina
	lbl_estado.text = ""
	if jogador.pilotando():
		var c = jogador.canoa
		lbl_estado.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		lbl_estado.text = "Gasolina %d%%   ·   W/S acelera   A/D vira   E desce" % int(c.gasolina)
	else:
		lbl_estado.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
	if jogador.pilotando():
		pass
	elif jogador.preso_na_lama:
		lbl_estado.text = "A lama prende as pernas embaixo d'água"
	elif jogador.nadando:
		lbl_estado.text = "Nadando: a força está acabando"
	elif jogador.atolado > 0.2:
		lbl_estado.text = "Atolado! ESPAÇO para puxar as pernas"
	elif jogador.mancando > 0.0:
		lbl_estado.text = "Mancando (ferroada de arraia)"
	elif jogador.muricoca > 0.5:
		lbl_estado.text = "Muriçoca! Lama no rosto ou fumaça do fogo"
	elif jogador.boiando:
		lbl_estado.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		lbl_estado.text = "Boiando e descansando"
	lbl_prompt.text = jogador.texto_alvo if jogador.andando() else ""

	var forca := 0.0
	forca = maxf(forca, (1.0 - jogador.fome / 25.0) * 0.8 if jogador.fome < 25.0 else 0.0)
	forca = maxf(forca, (1.0 - jogador.estamina / 25.0) * 0.6 if jogador.estamina < 25.0 else 0.0)
	forca = maxf(forca, jogador.atolado * 0.7)
	(vinheta.material as ShaderMaterial).set_shader_parameter("forca", forca)
	agua_tela.visible = jogador.camera.global_position.y < Mundo.nivel_mare()

	_atualizar_marcadores()
	minimapa.queue_redraw()
	if _mapa_aberto:
		mapa_vista.queue_redraw()
	if roda.visible and jogador.toca != null:
		roda.mg = jogador.mg
		roda.queue_redraw()
		lbl_ajuda.text = _ajuda_toca()
	else:
		lbl_ajuda.text = ""


func _atualizar_marcadores() -> void:
	var lista := []
	var cam: Camera3D = jogador.camera
	if jogador.andando() and not _mapa_aberto:
		var frente := -cam.global_transform.basis.z
		var mira = jogador.alvo
		for t in main.tocas:
			if t.destaque < 0.05:
				continue
			var p: Vector3 = t.global_position + Vector3(0, 0.45, 0)
			if frente.dot(p - cam.global_position) <= 0.2:
				continue
			var d: float = t.global_position.distance_to(jogador.global_position)
			lista.append({"tela": cam.unproject_position(p), "d": d, "a": t.destaque, "mirando": t == mira})
	marcadores.lista = lista
	marcadores.queue_redraw()


func _ajuda_toca() -> String:
	var mg: Dictionary = jogador.mg
	match mg["fase"]:
		"procurando":
			lbl_ajuda.add_theme_color_override("font_color", BRANCO)
			if mg["vazia"]:
				return "Toca vazia.  S  tira o braço"
			if mg["perto"] > 0.4:
				return "Tá perto... continue segurando  E"
			return "SEGURE  E  para enfiar o braço     ·     S  tira o braço"
		"agarrar":
			lbl_ajuda.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
			return "Achou! Aperte  ESPAÇO  para agarrar\nno centro do verde a pegada é FORTE  ·  no vermelho ele dá pinçada"
		"puxando":
			if mg["puxao"] > 0.0:
				lbl_ajuda.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
				return "ELE ESTÁ PUXANDO — SOLTE O  E !"
			lbl_ajuda.add_theme_color_override("font_color", DOURADO)
			return "SEGURE  E  para puxar     ·     pegada %s" % ["", "FRACA", "MÉDIA", "FORTE"][mg["pegada"]]
	return ""


func _texto_mare() -> String:
	var forca_mare := " (maré de lua)" if absf(cos(Mundo.fase_lua() * TAU * 2.0)) > 0.7 and cos(Mundo.fase_lua() * TAU * 2.0) > 0.0 else ""
	if Mundo.mare_subindo():
		var h: float = main.altura_proxima_toca()
		var txt := "Maré ENCHENDO%s   ·   " % forca_mare
		if h > 90.0:
			txt += "todas as tocas estão cobertas"
		else:
			txt += "a próxima toca fica coberta em " + Mundo.texto_duracao(Mundo.horas_ate(h))
		return txt + _perigo_aqui()
	return "Maré VAZANDO%s   ·   maré baixa em %s" % [forca_mare, Mundo.texto_duracao(Mundo.horas_ate_mare_baixa())]


func _perigo_aqui() -> String:
	if jogador.pilotando():
		return "\nNa canoa: no raso ela encalha"
	var chao: float = jogador.chao_efetivo()
	if chao >= 2.3:
		return "\nVocê está em lugar alto: a maré não chega aqui"
	var falta := Mundo.horas_ate(chao + 1.2)
	if falta == 0.0:
		lbl_mare.add_theme_color_override("font_color", Color(1, 0.55, 0.45))
		return "\nPERIGO: a água já está no peito! Vá para um lugar alto"
	if falta > 0.0 and falta < 1.5:
		lbl_mare.add_theme_color_override("font_color", Color(1, 0.55, 0.45))
		return "\nPERIGO: aqui a água chega no peito em " + Mundo.texto_duracao(falta)
	return ""


# ------------------------------------------------------------------ desenhos

class Bussola extends Control:
	var yaw := 0.0
	var marcas: Array = []
	const CAMPO := 1.8

	func _draw() -> void:
		var w := size.x
		var meio := w * 0.5
		var y := 26.0
		var f := get_theme_default_font()
		draw_rect(Rect2(0, y - 20, w, 40), Color(0, 0, 0, 0.32))
		var nomes := {0: "N", 45: "NE", 90: "L", 135: "SE", 180: "S", 225: "SO", 270: "O", 315: "NO"}
		for i in range(0, 360, 15):
			var d := wrapf(deg_to_rad(i) - yaw, -PI, PI)
			if absf(d) > CAMPO * 0.5:
				continue
			var x := meio + d / (CAMPO * 0.5) * meio
			var alfa := 1.0 - absf(d) / (CAMPO * 0.5) * 0.7
			if nomes.has(i):
				var nome: String = nomes[i]
				var fs := 28 if nome.length() == 1 else 19
				var tw := f.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var cor := Color(1, 0.82, 0.45, alfa) if nome == "N" else Color(1, 1, 1, alfa)
				draw_string_outline(f, Vector2(x - tw / 2.0, y + 10), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, alfa * 0.8))
				draw_string(f, Vector2(x - tw / 2.0, y + 10), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cor)
			else:
				draw_line(Vector2(x, y - 7), Vector2(x, y + 7), Color(1, 1, 1, alfa * 0.6), 2.0)
		var usados: Array[float] = []
		for m in marcas:
			var d := wrapf(float(m["ang"]) - yaw, -PI, PI)
			var dentro := absf(d) <= CAMPO * 0.5
			var x := meio + clampf(d / (CAMPO * 0.5), -1.0, 1.0) * (meio - 16.0)
			var cor: Color = m["cor"]
			var p := Vector2(x, y + 34)
			var forma: String = m.get("forma", "")
			Icone.desenhar(self, forma, p, cor, 1.3)
			if not dentro:
				var s := signf(d)
				draw_colored_polygon(PackedVector2Array([p + Vector2(s * 18, -8), p + Vector2(s * 28, 0), p + Vector2(s * 18, 8)]), cor)
			var txt: String = m["txt"]
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var ly := y + 64.0
			for ux in usados:
				if absf(ux - x) < 130.0:
					ly += 18.0
			usados.append(x)
			var lx := clampf(x - tw / 2.0, 0.0, w - tw)
			draw_string_outline(f, Vector2(lx, ly), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0, 0, 0, 0.8))
			draw_string(f, Vector2(lx, ly), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cor)
		draw_colored_polygon(PackedVector2Array([Vector2(meio - 8, y - 26), Vector2(meio + 8, y - 26), Vector2(meio, y - 15)]), Color(1, 0.8, 0.42))


## Formas dos ícones (bússola e mapas).
class Icone:
	static func desenhar(c: CanvasItem, forma: String, p: Vector2, cor: Color, k: float) -> void:
		var sombra := Color(0, 0, 0, 0.6)
		match forma:
			"casa":
				var pts := PackedVector2Array([p + Vector2(-10, -1) * k, p + Vector2(0, -11) * k, p + Vector2(10, -1) * k, p + Vector2(7, -1) * k, p + Vector2(7, 9) * k, p + Vector2(-7, 9) * k, p + Vector2(-7, -1) * k])
				c.draw_polyline(pts + PackedVector2Array([pts[0]]), sombra, 4.0)
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -1) * k, p + Vector2(0, -11) * k, p + Vector2(10, -1) * k]), cor)
				c.draw_rect(Rect2(p + Vector2(-7, -1) * k, Vector2(14, 10) * k), cor)
				c.draw_rect(Rect2(p + Vector2(-2, 3) * k, Vector2(4, 6) * k), Color(0, 0, 0, 0.6))
			"teso":
				var t := PackedVector2Array([p + Vector2(-11, 8) * k, p + Vector2(0, -9) * k, p + Vector2(11, 8) * k])
				c.draw_polyline(t + PackedVector2Array([t[0]]), sombra, 3.0)
				c.draw_colored_polygon(t, cor)
			"nome":
				c.draw_circle(p, 3.0 * k, cor)
			"fogo":
				c.draw_circle(p, 7 * k, sombra)
				c.draw_circle(p, 5.5 * k, cor)
				c.draw_circle(p + Vector2(0, 1) * k, 2.5 * k, Color(1, 0.9, 0.4))
			_:
				var l := PackedVector2Array([p + Vector2(0, -8) * k, p + Vector2(7, 0) * k, p + Vector2(0, 8) * k, p + Vector2(-7, 0) * k])
				c.draw_polyline(l + PackedVector2Array([l[0]]), sombra, 3.0)
				c.draw_colored_polygon(l, cor)


## Mapa visto de cima (minimapa redondo ou mapa grande). Norte para cima.
class Mapa extends Control:
	var hud
	var zoom := 1.0
	var redondo := false
	var mostrar_nomes := false
	var _mat: ShaderMaterial
	var _pronto := false

	func preparar(alt: Texture2D, cor: Texture2D) -> void:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/mapa.gdshader")
		_mat.set_shader_parameter("alturas", alt)
		_mat.set_shader_parameter("cores", cor)
		_mat.set_shader_parameter("redondo", redondo)
		_mat.set_shader_parameter("zoom", zoom)
		var fundo := ColorRect.new()
		fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
		fundo.material = _mat
		fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fundo.show_behind_parent = true
		add_child(fundo)
		_pronto = true

	func _uv(p: Vector3) -> Vector2:
		return Vector2((p.x + 130.0) / 260.0, (p.z + 130.0) / 260.0)

	func _tela(uv: Vector2, centro: Vector2) -> Vector2:
		return ((uv - centro) / zoom + Vector2(0.5, 0.5)) * size

	func _draw() -> void:
		if not _pronto or hud == null or hud.jogador == null:
			return
		var j = hud.jogador
		var centro := Vector2(0.5, 0.5) if not redondo else _uv(j.global_position)
		_mat.set_shader_parameter("centro", centro)
		_mat.set_shader_parameter("nivel", Mundo.nivel_mare())
		var f := get_theme_default_font()
		var raio := size.x * 0.5
		var ocupados: Array[Rect2] = []
		for m in hud.main.marcas_mapa():
			var p := _tela(_uv(m["pos"]), centro)
			if redondo:
				var dv := p - size * 0.5
				if dv.length() > raio - 10.0:
					if m["forma"] != "casa" and m["txt"] == "":
						continue
					p = size * 0.5 + dv.normalized() * (raio - 10.0)
			if m["forma"] == "area":
				var rp: float = float(m["raio"]) / 260.0 / zoom * size.x
				var cor_a: Color = m["cor"]
				draw_circle(p, rp, Color(cor_a.r, cor_a.g, cor_a.b, 0.15))
				draw_arc(p, rp, 0, TAU, 40, Color(cor_a.r, cor_a.g, cor_a.b, 0.8), 2.0)
				if mostrar_nomes:
					var tw2 := f.get_string_size(m["txt"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
					draw_string_outline(f, p - Vector2(tw2 / 2.0, -6), m["txt"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.8))
					draw_string(f, p - Vector2(tw2 / 2.0, -6), m["txt"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, cor_a)
				continue
			Icone.desenhar(self, m["forma"], p, m["cor"], 1.0 if redondo else 1.4)
			var txt: String = m["txt"]
			if mostrar_nomes and txt != "":
				# desvia de nomes já escritos (desce ou sobe até achar espaço)
				var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
				var pos := p + Vector2(14, 6)
				for tentativa in 8:
					var r := Rect2(pos - Vector2(0, 16), Vector2(tw, 20))
					var bate := false
					for o in ocupados:
						if r.intersects(o):
							bate = true
							break
					if not bate:
						break
					pos.y += 20.0 if tentativa % 2 == 0 else -20.0 * (tentativa + 1)
				ocupados.append(Rect2(pos - Vector2(0, 16), Vector2(tw, 20)))
				draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.8))
				draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, m["cor"])
		# você: seta apontando para onde olha
		var a: float = j.yaw_bussola()
		var pj := _tela(_uv(j.global_position), centro)
		var dir := Vector2(sin(a), -cos(a))
		var lado := Vector2(-dir.y, dir.x)
		var k := 1.0 if redondo else 1.4
		var seta := PackedVector2Array([pj + dir * 12 * k, pj - dir * 8 * k + lado * 8 * k, pj - dir * 4 * k, pj - dir * 8 * k - lado * 8 * k])
		draw_colored_polygon(seta, Color(0, 0, 0, 0.6) if false else Color(1, 1, 1))
		draw_polyline(seta + PackedVector2Array([seta[0]]), Color(0, 0, 0, 0.7), 2.0)
		if redondo:
			draw_string_outline(f, Vector2(raio - 6, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.8))
			draw_string(f, Vector2(raio - 6, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.82, 0.45))


## Pontinhos pretos zumbindo na tela quando a muriçoca ataca.
class Muricocas extends Control:
	var forca := 0.0

	func _draw() -> void:
		if forca < 0.05:
			return
		var t := Time.get_ticks_msec() * 0.001
		var n := int(140 * forca)
		for i in n:
			var base := Vector2(fmod(i * 197.3, size.x), fmod(i * 131.7, size.y))
			var p := base + Vector2(sin(t * 7.0 + i), cos(t * 9.0 + i * 1.3)) * 18.0
			draw_circle(p, 2.4 + fmod(i, 3.0) * 0.9, Color(0.03, 0.03, 0.03, 0.85 * forca))


## Marcador "Toca" flutuando em cima de cada toca por perto.
class Marcadores extends Control:
	var lista: Array = []

	func _draw() -> void:
		var f := get_theme_default_font()
		var escala := size.y / float(get_viewport().get_visible_rect().size.y) if get_viewport() else 1.0
		for m in lista:
			var p: Vector2 = m["tela"] * escala
			var a: float = m["a"]
			var cor := Color(1.0, 0.8, 0.42, a)
			if m["mirando"]:
				cor = Color(1, 1, 1, a)
			var k := 1.25 if m["mirando"] else 1.0
			# losango com borda escura
			var l := PackedVector2Array([p + Vector2(0, -9) * k, p + Vector2(8, 0) * k, p + Vector2(0, 9) * k, p + Vector2(-8, 0) * k])
			draw_polyline(l + PackedVector2Array([l[0]]), Color(0, 0, 0, 0.6 * a), 3.0)
			draw_colored_polygon(l, cor)
			var txt := "Toca  %d m" % int(round(m["d"]))
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			draw_string_outline(f, p + Vector2(-tw / 2.0, -16), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color(0, 0, 0, 0.75 * a))
			draw_string(f, p + Vector2(-tw / 2.0, -16), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, cor)


## Roda da toca: profundidade, ponteiro para agarrar e força para puxar.
class RodaToca extends Control:
	var mg := {}

	func _draw() -> void:
		if mg.is_empty():
			return
		var c := size * 0.5
		var r := size.x * 0.42
		var f := get_theme_default_font()
		draw_circle(c, r + 18, Color(0, 0, 0, 0.35))
		match mg["fase"]:
			"procurando":
				# anel enche com a profundidade; pulsa mais rápido quando o bicho está perto
				var prof: float = mg["prof"]
				draw_arc(c, r, 0, TAU, 64, Color(1, 1, 1, 0.18), 10.0)
				draw_arc(c, r, -PI / 2, -PI / 2 + TAU * clampf(prof / 0.9, 0.0, 1.0), 64, Color(1, 1, 1, 0.85), 10.0)
				var perto: float = mg["perto"]
				var pulso := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * lerpf(2.0, 14.0, perto))
				draw_circle(c, lerpf(8.0, 30.0, perto) * (0.7 + 0.3 * pulso), Color(1, 0.8, 0.42, 0.25 + 0.6 * perto))
				_texto(f, c + Vector2(0, r * 0.55), "braço: %d cm" % int(prof * 100.0), 20)
			"agarrar":
				var alvo: float = mg["alvo"]
				var tam: float = mg["tam"]
				draw_arc(c, r, 0, TAU, 72, Color(1, 1, 1, 0.15), 22.0)
				# verde em 3 faixas: fraca (borda), média e forte (centro)
				draw_arc(c, r, alvo - tam * 0.5, alvo + tam * 0.5, 32, Color(0.62, 0.92, 0.55, 0.9), 22.0)
				draw_arc(c, r, alvo - tam * 0.34, alvo + tam * 0.34, 24, Color(0.3, 0.85, 0.35, 0.95), 22.0)
				draw_arc(c, r, alvo - tam * 0.17, alvo + tam * 0.17, 16, Color(0.08, 0.6, 0.2, 1.0), 26.0)
				draw_arc(c, r, alvo + PI - deg_to_rad(45), alvo + PI + deg_to_rad(45), 32, Color(0.95, 0.25, 0.2, 0.95), 22.0)
				var ag: float = mg["agulha"]
				var ponta := c + Vector2(cos(ag), sin(ag)) * (r + 16)
				draw_line(c, ponta, Color(1, 1, 1), 5.0)
				draw_circle(c, 9, Color(1, 1, 1))
				_texto(f, c + Vector2(0, r * 0.5), "ESPAÇO", 20, Color(0.6, 1, 0.6))
			"puxando":
				var tensao: float = mg["tensao"]
				var prog: float = mg["progresso"]
				var puxao: bool = mg["puxao"] > 0.0
				draw_arc(c, r, -PI / 2, -PI / 2 + TAU * prog, 64, Color(1, 0.8, 0.42), 14.0)
				draw_arc(c, r, -PI / 2 + TAU * prog, -PI / 2 + TAU, 64, Color(1, 1, 1, 0.15), 14.0)
				var cor := Color(0.95, 0.3, 0.25) if puxao else Color(0.5, 0.9, 0.5)
				draw_circle(c, lerpf(20.0, r * 0.75, tensao), Color(cor.r, cor.g, cor.b, 0.35))
				draw_arc(c, r * 0.75, 0, TAU, 48, Color(1, 0.3, 0.25, 0.8), 3.0)
				_texto(f, c + Vector2(0, 8), "PUXANDO" if not puxao else "SOLTE!", 26, cor)
				var pegada: int = mg["pegada"]
				var cores := [Color.WHITE, Color(1, 0.6, 0.45), Color(1, 0.85, 0.45), Color(0.5, 1, 0.55)]
				_texto(f, c + Vector2(0, 40), "pegada " + ["", "fraca", "média", "FORTE"][pegada], 19, cores[pegada])

	func _texto(f: Font, p: Vector2, t: String, fs: int, cor: Color = Color.WHITE) -> void:
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(f, p - Vector2(tw / 2.0, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.8))
		draw_string(f, p - Vector2(tw / 2.0, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cor)
