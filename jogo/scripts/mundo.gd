extends Node
## Relógio do jogo, maré e teclas. Fica sempre carregado (autoload "Mundo").

signal noticia(texto: String, tipo: String)

const SEGUNDOS_REAIS_POR_HORA := 90.0   # 1 hora no jogo = 1,5 minuto real
const PERIODO_MARE := 12.4              # horas entre duas marés baixas
const HORA_MARE_BAIXA := 6.0            # primeira maré baixa do dia 1
const MARE_AMPLITUDE := 2.15            # metros acima/abaixo do meio
const MARE_MEIO := 0.15

var hora := 6.0
var dia := 1

# calendário: o jogo começa em 1º de maio (fim da época das chuvas no Maranhão)
const MES_INICIAL := 4          # 0 = janeiro
const DIA_INICIAL := 1
const MESES := ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
# chance de começar a chover por hora, por mês (jan..dez): chuva de jan a jun, pico em mar/abr; seca em ago/set
const CHANCE_CHUVA := [0.10, 0.13, 0.17, 0.17, 0.12, 0.07, 0.03, 0.01, 0.01, 0.015, 0.02, 0.05]
const LUA_INICIAL := 0.42       # 0 = nova, 0.5 = cheia
const MES_LUNAR := 29.53

# tempo: 0..1
var chuva := 0.0
var nuvens := 0.25
var _alvo_chuva := 0.0
var _alvo_nuvens := 0.25
var _hora_chuva := 0.0
var _rng := RandomNumberGenerator.new()
var acelerar := 1.0
var rodando := false


func _ready() -> void:
	_criar_acoes()


## Volta o relógio, o tempo e a maré para o começo (novo jogo sem fechar o programa).
func reiniciar() -> void:
	hora = 6.0
	dia = 1
	chuva = 0.0
	nuvens = 0.25
	_alvo_chuva = 0.0
	_alvo_nuvens = 0.25
	_hora_chuva = 0.0
	acelerar = 1.0
	rodando = false


func _process(delta: float) -> void:
	if not rodando:
		return
	avancar_horas(delta * acelerar / SEGUNDOS_REAIS_POR_HORA)


func avancar_horas(h: float) -> void:
	_clima(h)
	hora += h
	while hora >= 24.0:
		hora -= 24.0
		dia += 1


func tempo_total() -> float:
	return (dia - 1) * 24.0 + hora


func nivel_mare_em(t: float) -> float:
	var fase := (t - HORA_MARE_BAIXA) / PERIODO_MARE * TAU
	# maré de lua (sizígia) na lua cheia e na nova; maré de quarto, menor, nas meias-luas
	var lua := fase_lua_em(t)
	var amp := MARE_AMPLITUDE * (0.88 + 0.12 * cos(lua * TAU * 2.0))
	return MARE_MEIO - amp * cos(fase)


func fase_lua_em(t: float) -> float:
	return fposmod(LUA_INICIAL + t / 24.0 / MES_LUNAR, 1.0)


func fase_lua() -> float:
	return fase_lua_em(tempo_total())


## Fração iluminada da lua (0 nova, 1 cheia).
func luz_lua() -> float:
	return 0.5 - 0.5 * cos(fase_lua() * TAU)


func nome_lua() -> String:
	var f := fase_lua()
	if f < 0.04 or f > 0.96:
		return "lua nova"
	if f < 0.21:
		return "lua crescente"
	if f < 0.29:
		return "quarto crescente"
	if f < 0.46:
		return "lua crescente"
	if f < 0.54:
		return "lua cheia"
	if f < 0.71:
		return "lua minguante"
	if f < 0.79:
		return "quarto minguante"
	return "lua minguante"


func mes() -> int:
	return (MES_INICIAL + int((DIA_INICIAL - 1 + dia - 1) / 30.0)) % 12


func texto_data() -> String:
	var d := (DIA_INICIAL - 1 + dia - 1) % 30 + 1
	return "%d de %s" % [d, MESES[mes()]]


func _clima(h: float) -> void:
	_hora_chuva -= h
	if _hora_chuva <= 0.0:
		_hora_chuva = 1.0
		if _alvo_chuva > 0.0:
			# a chuva para depois de um tempo
			if _rng.randf() < 0.45:
				_alvo_chuva = 0.0
				_alvo_nuvens = _rng.randf_range(0.2, 0.55)
		else:
			var chance: float = CHANCE_CHUVA[mes()]
			if hora > 13.0 and hora < 18.0:
				chance *= 1.8   # pancada de chuva de tarde
			if _rng.randf() < chance:
				_alvo_chuva = _rng.randf_range(0.35, 1.0)
				_alvo_nuvens = 1.0
			else:
				_alvo_nuvens = clampf(_alvo_nuvens + _rng.randf_range(-0.2, 0.2), 0.1, 0.75)
	# muda devagar (em horas de jogo)
	nuvens = move_toward(nuvens, _alvo_nuvens, h * 1.2)
	var pode_chover := nuvens > 0.8
	chuva = move_toward(chuva, _alvo_chuva if pode_chover else 0.0, h * 1.5)


## Para testes e fotos.
func forcar_chuva(forca: float) -> void:
	_alvo_chuva = forca
	_alvo_nuvens = 1.0 if forca > 0.0 else 0.3
	chuva = forca
	nuvens = _alvo_nuvens
	_hora_chuva = 2.0


func nivel_mare() -> float:
	return nivel_mare_em(tempo_total())


func mare_subindo() -> bool:
	return nivel_mare_em(tempo_total() + 0.02) > nivel_mare()


## Horas até a maré chegar a um nível. 0 se já chegou, -1 se não chega no próximo ciclo.
func horas_ate(nivel: float) -> float:
	var t := tempo_total()
	if nivel_mare_em(t) >= nivel:
		return 0.0
	var h := 0.0
	while h < 13.0:
		h += 0.05
		if nivel_mare_em(t + h) >= nivel:
			return h
	return -1.0


func horas_ate_mare_baixa() -> float:
	var fase := fposmod(tempo_total() - HORA_MARE_BAIXA, PERIODO_MARE)
	return PERIODO_MARE - fase


func texto_hora() -> String:
	var h := int(hora)
	var m := int((hora - h) * 60.0)
	return "%02d:%02d" % [h, m]


func texto_duracao(horas: float) -> String:
	var minutos := int(round(horas * 60.0))
	if minutos < 60:
		return "%d min" % minutos
	return "%dh%02d" % [minutos / 60, minutos % 60]


## Altura do sol: 1 ao meio-dia, 0 no nascer/pôr, negativo à noite.
func altura_sol() -> float:
	return sin((hora - 6.0) / 12.0 * PI)


func avisar(texto: String, tipo: String = "info") -> void:
	noticia.emit(texto, tipo)


func _criar_acoes() -> void:
	var teclas := {
		"frente": [KEY_W, KEY_UP], "tras": [KEY_S, KEY_DOWN],
		"esquerda": [KEY_A, KEY_LEFT], "direita": [KEY_D, KEY_RIGHT],
		"correr": [KEY_SHIFT], "pular": [KEY_SPACE], "agarrar": [KEY_SPACE],
		"interagir": [KEY_E], "soltar": [KEY_R], "lanterna": [KEY_F],
		"balde": [KEY_G], "pausa": [KEY_ESCAPE], "construir": [KEY_B], "tarrafa": [KEY_T], "agachar": [KEY_CTRL, KEY_ALT],
	}
	for nome in teclas:
		if InputMap.has_action(nome):
			continue
		InputMap.add_action(nome)
		for k in teclas[nome]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(nome, ev)
	var botoes := {"empurrar": MOUSE_BUTTON_LEFT, "recolher": MOUSE_BUTTON_RIGHT}
	for nome in botoes:
		if InputMap.has_action(nome):
			continue
		InputMap.add_action(nome)
		var mb := InputEventMouseButton.new()
		mb.button_index = botoes[nome]
		InputMap.action_add_event(nome, mb)
