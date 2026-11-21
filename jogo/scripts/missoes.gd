extends Node
## Missão do primeiro dia (MVP): balde → 6 caranguejos antes da maré → lenha → fogo → cozinhar → comer com farinha.

const META := 6
const PASSOS := [
	"Pegue o balde no rancho",
	"Pegue 6 caranguejos antes que a maré cubra as tocas",
	"Corte ou junte 2 feixes de lenha",
	"Acenda um fogo (fogão do rancho ou jirau-fogão)",
	"Cozinhe os caranguejos",
	"Coma o que cozinhou",
]

var main
var jogador
var fogao
var etapa := 0
var concluido := false


func _passos() -> bool:
	return main.tutorial != null and main.tutorial.ativo


func nome() -> String:
	if _passos():
		return main.tutorial.nome()
	return main.barco.nome() if concluido else "Caranguejo com Cérebro"


func titulo() -> String:
	if _passos():
		return main.tutorial.titulo()
	if concluido:
		return main.barco.titulo()
	return PASSOS[etapa]


func detalhe() -> String:
	if _passos():
		return main.tutorial.detalhe()
	if concluido:
		return main.barco.detalhe()
	match etapa:
		1:
			var total: int = jogador.caranguejos
			var txt := "%d / %d no balde" % [total, META]
			if main.altura_proxima_toca() > 90.0:
				txt += "\nA maré cobriu as tocas. Durma na rede até a próxima vazante."
			return txt
		2:
			return "%d / 2 feixes (mochila ou fogão). Corte lenha dos troncos caídos com o facão." % (jogador.lenha + main.lenha_nos_fogoes())
		4:
			if main.na_panela_total() > 0:
				return "Cozinhando: %d%%" % int(main.fogao_perto(jogador.global_position).cozimento * 100.0)
			return "Leve os caranguejos até um fogo aceso"
		5:
			return "Com farinha d'água na cuia a comida sustenta mais (tem no saco do rancho)." if not jogador.farinha else "Farinha na cuia: vai comer com farinha."
	return ""


## Para onde aponta o marcador dourado da bússola.
func alvo() -> Dictionary:
	if _passos():
		return main.tutorial.alvo()
	if concluido:
		return main.barco.alvo()
	match etapa:
		0:
			var b = main.item_mais_perto("balde", jogador.global_position)
			return {"pos": b.global_position, "txt": "Balde"} if b != null else {}
		1:
			var t = main.toca_livre_mais_perto(jogador.global_position)
			return {"pos": t.global_position, "txt": "Toca"} if t != null else {"pos": main.pos_spawn, "txt": "Rede"}
		2:
			if jogador.lenha + main.lenha_nos_fogoes() >= 2:
				return {"pos": main.fogao_perto(jogador.global_position).global_position, "txt": "Fogão"}
			var l = main.item_mais_perto("lenha", jogador.global_position)
			var tr = main.tronco_com_lenha_perto(jogador.global_position)
			if tr != null and (l == null or tr.global_position.distance_to(jogador.global_position) < l.global_position.distance_to(jogador.global_position)):
				return {"pos": tr.global_position, "txt": "Tronco (facão)"}
			if l != null:
				return {"pos": l.global_position, "txt": "Lenha"}
			return {"pos": main.fogao_perto(jogador.global_position).global_position, "txt": "Fogão"}
		3, 4:
			return {"pos": main.fogao_perto(jogador.global_position).global_position, "txt": "Fogão"}
		5:
			if not jogador.farinha:
				var f = main.item_mais_perto("farinha", jogador.global_position)
				if f != null:
					return {"pos": f.global_position, "txt": "Farinha"}
			return {"pos": main.fogao_perto(jogador.global_position).global_position, "txt": "Fogão"}
	return {}


func _process(_delta: float) -> void:
	if not Mundo.rodando or concluido or jogador == null:
		return
	var ok := false
	match etapa:
		0: ok = jogador.tem_balde
		1: ok = jogador.caranguejos + main.na_panela_total() + main.cozidos_total() >= META or jogador.comeu
		2: ok = jogador.lenha + main.lenha_nos_fogoes() >= 2 or main.algum_aceso()
		3: ok = main.algum_aceso()
		4: ok = main.cozidos_total() > 0 or jogador.comeu
		5: ok = jogador.comeu
	if ok:
		etapa += 1
		if main.salvador.ativo:
			main.salvador.salvar.call_deferred()
		if etapa >= PASSOS.size():
			concluido = true
			main.hud.tela_final()
			Mundo.avisar("Nova missão: Parabólica na Lama. Ache a canoa velha na beira do igarapé.", "objetivo")
		elif not _passos():
			Mundo.avisar("Novo objetivo: " + PASSOS[etapa], "objetivo")
