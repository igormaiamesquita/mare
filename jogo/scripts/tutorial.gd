extends Node3D
## Primeiros passos: ensina uma coisa por vez antes da missão "Caranguejo com Cérebro".
## Enquanto está ativo, a missão continua andando por baixo (missoes.gd), mas a tela, a bússola
## e a seta dourada mostram o passo daqui. Passo já cumprido (fora de ordem) é pulado sozinho.

var main
var jogador
var ativo := false
var etapa := 0

var _viu_inventario := false
var _viu_mapa := false
var _seta: MeshInstance3D
var _t := 0.0

const PASSOS := [
	{"id": "olhar", "titulo": "Olhe em volta"},
	{"id": "galochas", "titulo": "Calce as galochas"},
	{"id": "balde", "titulo": "Pegue o balde no rancho"},
	{"id": "tarrafa", "titulo": "Pegue a tarrafa"},
	{"id": "inventario", "titulo": "Abra o inventário"},
	{"id": "lenha", "titulo": "Corte lenha num tronco caído"},
	{"id": "mapa", "titulo": "Veja a maré no mapa"},
	{"id": "toca", "titulo": "Pegue seu primeiro caranguejo"},
]


func _ready() -> void:
	ativo = bool(Config.v["primeiros_passos"])
	_seta = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.16
	cone.bottom_radius = 0.0
	cone.height = 0.34
	cone.radial_segments = 4
	cone.rings = 1
	_seta.mesh = cone
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.78, 0.32, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	_seta.material_override = m
	_seta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_seta.visible = false
	add_child(_seta)


static func tecla(t: String) -> String:
	return "[bgcolor=#f2cf7acc][color=#1a140a] %s [/color][/bgcolor]" % t


func nome() -> String:
	return "PRIMEIROS PASSOS  ·  %d de %d" % [mini(etapa + 1, PASSOS.size()), PASSOS.size()]


func titulo() -> String:
	return PASSOS[etapa]["titulo"] if etapa < PASSOS.size() else ""


## Texto com as teclas, para o painel de baixo (BBCode).
func dica() -> String:
	if etapa >= PASSOS.size():
		return ""
	var E := tecla("E")
	match PASSOS[etapa]["id"]:
		"olhar":
			return "Mexa o %s para olhar em volta." % tecla("mouse")
		"galochas":
			return "Ande com %s %s %s %s até as galochas, ao lado da porta. Olhe para elas e aperte %s.\nCom elas a lama mole prende menos e a arraia machuca menos." % [tecla("W"), tecla("A"), tecla("S"), tecla("D"), E]
		"balde":
			return "Entre pela porta. Olhe para o balde e aperte %s.\nÉ no balde que vão os caranguejos (até 10)." % E
		"tarrafa":
			return "A tarrafa fica no fundo do rancho. Olhe para ela e aperte %s.\nDepois, perto de um cardume: tecla %s põe a tarrafa na mão, SEGURE o %s para mirar e SOLTE para jogar." % [E, tecla("2"), tecla("botão do mouse")]
		"inventario":
			return "Aperte %s para ver a mochila e o balde. Aperte %s de novo para fechar." % [tecla("I"), tecla("I")]
		"lenha":
			return "Os troncos caídos ficam em volta do rancho. Olhe para um e aperte %s: o facão corta.\nA lenha vai para a mochila e serve para acender o fogo e cozinhar." % E
		"mapa":
			return "Aperte %s. A água azul mostra até onde a maré chega agora; os morrinhos verdes (tesos) ficam secos.\nFeche com %s." % [tecla("M"), tecla("M")]
		"toca":
			if main.altura_proxima_toca() > 90.0:
				return "A maré cobriu as tocas. Deite na rede do rancho (%s) e durma até a vazante." % E
			return ("Ache uma toca na lama (anel dourado). Bolinhas de lama fresca na boca = tem caranguejo.\n" +
				"SEGURE %s para enfiar o braço  ·  %s para agarrar no verde  ·  SEGURE %s para puxar e SOLTE no \"SOLTE!\"") % [E, tecla("ESPAÇO"), E]
	return ""


func detalhe() -> String:
	return ""


func alvo() -> Dictionary:
	if etapa >= PASSOS.size():
		return {}
	var p: Vector3 = jogador.global_position
	match PASSOS[etapa]["id"]:
		"galochas", "balde", "tarrafa":
			var it = main.item_mais_perto(PASSOS[etapa]["id"], p)
			return {"pos": it.global_position, "txt": PASSOS[etapa]["titulo"].get_slice(" ", 2).capitalize()} if it != null else {}
		"lenha":
			var tr = main.tronco_com_lenha_perto(p)
			return {"pos": tr.global_position, "txt": "Tronco"} if tr != null else {}
		"toca":
			if main.altura_proxima_toca() > 90.0:
				var r = main.item_mais_perto("rede", p)
				return {"pos": r.global_position, "txt": "Rede"} if r != null else {}
			var t = main.toca_livre_mais_perto(p)
			return {"pos": t.global_position, "txt": "Toca"} if t != null else {}
	return {}


func _cumprido(id: String) -> bool:
	match id:
		"olhar":
			return jogador.olhou > 500.0
		"galochas":
			return jogador.galochas
		"balde":
			return jogador.tem_balde
		"tarrafa":
			return jogador.tem_tarrafa
		"inventario":
			if main.hud._inv_aberto:
				_viu_inventario = true
			return _viu_inventario and not main.hud._inv_aberto
		"lenha":
			return jogador.lenha > 0 or main.lenha_nos_fogoes() > 0
		"mapa":
			if main.hud._mapa_aberto:
				_viu_mapa = true
			return _viu_mapa and not main.hud._mapa_aberto
		"toca":
			return jogador.stats["pegos"] > 0
	return true


func _process(delta: float) -> void:
	_t += delta
	if not ativo or jogador == null or not main.hud.iniciado:
		_seta.visible = false
		return
	var avancou := false
	while etapa < PASSOS.size() and _cumprido(PASSOS[etapa]["id"]):
		etapa += 1
		avancou = true
	if etapa >= PASSOS.size():
		terminar()
		return
	if avancou:
		Mundo.avisar("Feito! Próximo: " + titulo(), "objetivo")
	var a := alvo()
	_seta.visible = not a.is_empty() and Mundo.rodando
	if _seta.visible:
		var alto := 1.0 if PASSOS[etapa]["id"] in ["toca", "lenha"] else 0.75
		_seta.global_position = a["pos"] + Vector3(0, alto + sin(_t * 3.0) * 0.08, 0)
		_seta.rotation.y = _t * 1.5


func terminar() -> void:
	if not ativo:
		return
	ativo = false
	_seta.visible = false
	Mundo.avisar("Primeiros passos concluídos! Agora a missão é sua: " + main.missoes.titulo(), "objetivo")


func pular() -> void:
	ativo = false
	_seta.visible = false


func reiniciar() -> void:
	etapa = 0
	_viu_inventario = false
	_viu_mapa = false
	ativo = true
