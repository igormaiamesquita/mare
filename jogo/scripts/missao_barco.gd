extends Node
## Missão "Parabólica na Lama": achar a canoa velha, juntar as peças pelo mapa, lavar o motor com água da chuva,
## consertar e chegar de canoa à ilha do outro lado da baía.

var main
var canoa
var naufragio: Node3D
var pecas := {}            # id -> nó no mundo (enquanto não foi pego)
var onde := {
	"helice": "na croa (maré baixa)",
	"remo": "no meio do mangue",
	"cuia": "perto de um teso",
	"galao": "preso nas raízes",
	"breu": "no barco abandonado (baía, maré baixa)",
	"motor": "no barco abandonado (baía, maré baixa)",
}
var areas := {}            # id -> Vector3: centro aproximado da área de busca (não é o lugar exato)
const RAIO_AREA := 22.0
const NOMES := {"helice": "Hélice", "remo": "Remo", "cuia": "Cuia", "galao": "Galão", "breu": "Breu", "motor": "Motor"}
var chegou_ilha := false
var concluida := false
var _rng := RandomNumberGenerator.new()


func montar() -> void:
	_rng.seed = 77
	# canoa na beira norte do igarapé
	# procura um trecho da margem norte sem árvore nem tronco por perto
	var cx: float = Terreno.CANOA.x
	var z := 0.0
	for tentativa in 40:
		cx = Terreno.CANOA.x + tentativa * 3.0
		var cz := Terreno.centro_igarape(cx)
		z = cz
		while z > cz - 20.0 and Terreno.altura(cx, z) < -0.2:
			z -= 0.5
		var livre := true
		for a in main.arvores:
			if Vector2(a.x - cx, a.z - (z + 1.5)).length() < 5.0:
				livre = false
				break
		for n in main.get_tree().get_nodes_in_group("interagivel"):
			if n.get("tipo") == "tronco" and Vector2(n.global_position.x - cx, n.global_position.z - z).length() < 6.0:
				livre = false
		if livre:
			break
	canoa = Node3D.new()
	canoa.set_script(load("res://scripts/canoa.gd"))
	canoa.main = main
	canoa.position = Vector3(cx, Terreno.altura(cx, z), z + 1.5)
	canoa.rotation.y = PI / 2 + 0.2
	main.add_child(canoa)

	# barco abandonado deitado no banco de lama da baía
	naufragio = (load("res://assets/barco_abandonado.glb") as PackedScene).instantiate()
	var nx: float = Terreno.NAUFRAGIO.x
	var nz: float = Terreno.NAUFRAGIO.y
	naufragio.position = Vector3(nx, Terreno.altura(nx, nz) - 0.9, nz)
	naufragio.rotation = Vector3(0.06, 0.6, 0.3)
	main.add_child(naufragio)
	var corpo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.2, 2.4, 11.0)
	cs.shape = b
	cs.position = Vector3(1.75, 1.1, 0)
	corpo.add_child(cs)
	naufragio.add_child(corpo)

	# peças
	_peca("motor", naufragio.to_global(Vector3(-0.3, 0.5, -2.5)))
	_peca("breu", naufragio.to_global(Vector3(-0.2, 0.5, 1.8)))
	var croa := _lugar(Vector3(Terreno.CROA.x + 12.0, 0, Terreno.CROA.y), 10.0, 0.3, 2.0)
	_peca("helice", croa)
	_peca("remo", _lugar(Vector3(-60, 0, 22), 14.0, 0.2, 1.4))
	var teso: Vector3 = Terreno.TESOS[4]
	_peca("cuia", _lugar(Vector3(teso.x + 8.0, 0, teso.y), 5.0, 0.3, 2.9))
	var raiz := Vector3(80, 0, -20)
	var melhor := 1e9
	for a in main.arvores:
		var d := Vector2(a.x - 80.0, a.z + 20.0).length()
		if d < melhor and a.y < 1.6:
			melhor = d
			raiz = a + Vector3(0.8, 0, 0.6)
	raiz.y = Terreno.altura(raiz.x, raiz.z)
	_peca("galao", raiz)


func _lugar(perto: Vector3, raio: float, hmin: float, hmax: float) -> Vector3:
	for i in 300:
		var a := _rng.randf() * TAU
		var r := _rng.randf() * raio
		var p := perto + Vector3(cos(a) * r, 0, sin(a) * r)
		var h := Terreno.altura(p.x, p.z)
		if h > hmin and h < hmax:
			return Vector3(p.x, h, p.z)
	perto.y = Terreno.altura(perto.x, perto.z)
	return perto


func _peca(id: String, pos: Vector3) -> void:
	var p := Node3D.new()
	p.set_script(load("res://scripts/peca.gd"))
	p.id = id
	pos.y = maxf(pos.y, Terreno.altura(pos.x, pos.z)) + 0.05
	p.position = pos
	main.add_child(p)
	pecas[id] = p
	# a área de busca fica deslocada da peça: dá a direção, mas não o ponto
	var a := _rng.randf() * TAU
	var desloc := _rng.randf_range(6.0, 14.0)
	areas[id] = Vector3(pos.x + cos(a) * desloc, 0, pos.z + sin(a) * desloc)


func _pega(id: String) -> bool:
	return not is_instance_valid(pecas.get(id))


func _process(_d: float) -> void:
	if concluida or canoa == null:
		return
	# chegou perto da canoa: examina sozinho
	var j = main.jogador
	if not canoa.examinada and j != null and main.missoes.concluido and j.global_position.distance_to(canoa.global_position) < 6.0:
		canoa.examinada = true
		Mundo.avisar("Achou a canoa velha! Tem um furo e faltam peças. Veja a lista no objetivo: o mapa (M) mostra as áreas onde procurar.", "objetivo")
	if canoa.pilotando and not chegou_ilha:
		if Vector2(canoa.global_position.x, canoa.global_position.z).distance_to(Terreno.ILHA) < 38.0:
			chegou_ilha = true
			concluida = true
			Mundo.avisar("Chegou na ilha de canoa! Missão \"Parabólica na Lama\" concluída.", "objetivo")
			main.hud.tela_rabeta()


# ------------------------------------------------------------------ textos para o HUD

func nome() -> String:
	return "Livre no mangue" if concluida else "Parabólica na Lama"


func titulo() -> String:
	if concluida:
		return "Explore a ilha e o mangue de canoa"
	if not canoa.examinada:
		return "Ache a canoa velha na beira do igarapé"
	if canoa.pronta():
		return "Suba na canoa e atravesse a baía até a ilha"
	return "Conserte a canoa com a rabeta"


func detalhe() -> String:
	if concluida:
		return "Gasolina: %d%%. Na maré baixa a canoa encalha." % int(canoa.gasolina)
	if not canoa.examinada:
		return "Dica: a canoa fica na margem norte, a leste."
	var linhas := []
	var j = main.jogador
	for id in ["helice", "remo", "cuia", "galao", "breu", "motor"]:
		var feito := _pega(id)
		var nome: String = {"helice": "Hélice", "remo": "Remo", "cuia": "Cuia", "galao": "Galão de gasolina", "breu": "Breu e estopa", "motor": "Motor de rabeta"}[id]
		var dica := ""
		if not feito:
			dica = "  —  " + onde[id]
			if dentro_da_area(id):
				dica = "  —  ESTÁ AQUI PERTO: procure o brilho azul"
		linhas.append(("[x] " if feito else "[  ] ") + nome + dica)
	var lavado: bool = j.motor_limpo or canoa.tem_motor
	linhas.append(("[x] " if lavado else "[  ] ") + "Motor lavado com água doce (bacia de chuva + bancada do rancho)")
	linhas.append(("[x] " if canoa.pronta() else "[  ] ") + "Tudo montado na canoa")
	return "\n".join(linhas)


func alvo() -> Dictionary:
	if concluida:
		return {}
	var j = main.jogador
	if not canoa.examinada:
		return {"pos": canoa.global_position, "txt": "Canoa"}
	# carregando peça? leva para a canoa (motor sujo vai para a bancada antes)
	if j.mochila["motor"] > 0 and not j.motor_limpo:
		return {"pos": main.bancada.global_position, "txt": "Bancada"}
	for id in ["breu", "helice", "galao", "remo", "cuia"]:
		if j.mochila[id] > 0:
			return {"pos": canoa.global_position, "txt": "Canoa"}
	if j.mochila["motor"] > 0:
		return {"pos": canoa.global_position, "txt": "Canoa"}
	if canoa.pronta():
		if canoa.pilotando:
			return {"pos": Vector3(Terreno.ILHA.x, 0, Terreno.ILHA.y), "txt": "Ilha"}
		return {"pos": canoa.global_position, "txt": "Canoa"}
	# área de busca mais perto que ainda falta (dentro dela, sem marcador: procure o brilho)
	var melhor = null
	var md := INF
	for id in pecas:
		if not _pega(id):
			var d: float = areas[id].distance_to(Vector3(j.global_position.x, 0, j.global_position.z))
			if d < md:
				md = d
				melhor = id
	if melhor != null:
		if dentro_da_area(melhor):
			return {}
		return {"pos": areas[melhor], "txt": "Procure: " + NOMES[melhor]}
	return {"pos": canoa.global_position, "txt": "Canoa"}


func dentro_da_area(id: String) -> bool:
	var j = main.jogador
	return areas[id].distance_to(Vector3(j.global_position.x, 0, j.global_position.z)) < RAIO_AREA
