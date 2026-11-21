extends Node
## Teste automático: joga a missão inteira apertando as teclas de verdade.
## Rodar:  godot --headless --path jogo -- --teste

var main
var j


func _ready() -> void:
	_rodar.call_deferred()


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Quadros de tela (o _process): com a física acelerada, vários quadros de física cabem num só.
func _tela(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _apertar(acao: String) -> void:
	Input.action_press(acao)
	await _quadros(1)
	Input.action_release(acao)
	await _quadros(1)


func _falhar(msg: String) -> void:
	print("TESTE FALHOU: ", msg)
	get_tree().quit(1)


func _usar(alvo) -> void:
	# fica ao lado do alvo, olhando para ele, e aperta E
	var p: Vector3 = alvo.global_position
	j.global_position = Vector3(p.x, p.y + 0.05, p.z + 1.0)
	j.velocity = Vector3.ZERO
	j.look_at(Vector3(p.x, j.global_position.y, p.z), Vector3.UP)
	j.cabeca.rotation.x = -atan2(1.5, 1.0)
	await _quadros(3)
	print("  alvo: ", j.texto_alvo)
	await _apertar("interagir")


func _rodar() -> void:
	j = main.jogador
	main.hud.comecar()
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 40
	await _quadros(5)
	print("0) primeiros passos")
	main.tutorial.reiniciar()
	await _tela(3)
	if main.tutorial.etapa != 0:
		return _falhar("primeiros passos não começou no passo 1")
	j.olhou = 1000.0     # o teste não mexe o mouse
	await _tela(3)
	if main.tutorial.etapa != 1:
		return _falhar("primeiros passos não passou do olhe em volta (etapa %d, ativo %s, iniciado %s)" % [main.tutorial.etapa, main.tutorial.ativo, main.hud.iniciado])
	print("   passo: ", main.tutorial.titulo(), "  /  bússola: ", main.missoes.alvo().get("txt", "-"))
	print("1) balde")
	await _usar(main.item_mais_perto("balde", j.global_position))
	if not j.tem_balde:
		return _falhar("não pegou o balde")
	print("1b) galochas")
	await _usar(main.item_mais_perto("galochas", j.global_position))
	if not j.galochas:
		return _falhar("não calçou as galochas")
	await _tela(3)
	print("   passo: ", main.tutorial.titulo())
	if main.tutorial.titulo() != "Pegue a tarrafa":
		return _falhar("primeiros passos não chegou na tarrafa")
	await _usar(main.item_mais_perto("tarrafa", j.global_position))
	main.hud.abrir_inventario(true)
	await _tela(3)
	main.hud.abrir_inventario(false)
	await _tela(3)
	print("   passo: ", main.tutorial.titulo())
	if main.tutorial.titulo() != "Corte lenha num tronco caído":
		return _falhar("primeiros passos não chegou na lenha")

	print("2) caranguejos")
	var tentativas := 0
	while j.caranguejos < 6 and tentativas < 60:
		tentativas += 1
		var toca = null
		for t in main.tocas:
			if t.ocupada and not t.coberta() and t.global_position.y > Mundo.nivel_mare() + 0.3:
				toca = t
				break
		if toca == null:
			return _falhar("nenhuma toca ocupada descoberta")
		await _usar(toca)
		if j.estado != 1:
			print("  não entrou na toca: ", j.texto_alvo)
			continue
		var limite := 0
		while j.estado == 1 and limite < 3000:
			limite += 1
			var fase: String = j.mg["fase"]
			if fase == "procurando":
				Input.action_press("interagir")
			elif fase == "agarrar":
				Input.action_release("interagir")
				var dif := absf(wrapf(j.mg["agulha"] - j.mg["alvo"], -PI, PI))
				if dif < j.mg["tam"] * 0.12:
					await _apertar("agarrar")
					print("    pegada: ", j.mg["pegada"])
			elif fase == "puxando":
				if j.mg["puxao"] > 0.0 or j.mg["tensao"] > 0.75:
					Input.action_release("interagir")
				else:
					Input.action_press("interagir")
			await _quadros(1)
		Input.action_release("interagir")
		await _quadros(60)
		if j.estado == 2:
			var info: Dictionary = j.segurando
			await _apertar("interagir")
			print("  pegou (fêmea=%s miúdo=%s) -> balde %d   hora %s  maré %.2f" % [info["femea"], info["miudo"], j.caranguejos, Mundo.texto_hora(), Mundo.nivel_mare()])
		else:
			print("  saiu da toca sem caranguejo (estado %d)" % j.estado)
	print("   pinçadas: ", j.stats["pincadas"], "  objetivo agora: ", main.missoes.titulo())
	if j.caranguejos < 6:
		return _falhar("só pegou %d" % j.caranguejos)

	print("2b) peixe na poça (%d poças no mapa)" % main.pocas.size())
	var achou := false
	for pc in main.pocas:
		if pc.peixes.is_empty():
			continue
		for tentativa in 8:
			if pc.peixes.is_empty():
				break
			var f = pc.peixes[0]
			await _usar(f)
			await _quadros(80)
			if j.peixes > 0:
				break
		if j.peixes > 0:
			achou = true
			break
	print("   peixes no balde: ", j.peixes)
	if not achou:
		return _falhar("não conseguiu pegar peixe em nenhuma poça")
	print("2c) inventário")
	var ok_m: bool = j.peixe_para_mochila()
	print("   peixe do balde para a mochila: %s  (balde %d, mochila %d, espaços %d/%d)" % [ok_m, j.peixes, j.mochila["peixe"], j.espacos_usados(), j.MOCHILA_ESPACOS])
	if not ok_m or j.mochila["peixe"] != 1:
		return _falhar("não passou o peixe para a mochila")
	var fome_antes: float = j.fome
	j.comer_farofa()
	print("   farofa: fome %.0f -> %.0f, farofa restante %d" % [fome_antes, j.fome, j.mochila["farofa"]])
	print("3) lenha")
	for i in 2:
		await _usar(main.item_mais_perto("lenha", main.fogao.global_position))
	print("   lenha na mão: ", j.lenha)
	main.hud.abrir_mapa(true)
	await _tela(3)
	main.hud.abrir_mapa(false)
	await _tela(3)
	if main.tutorial.ativo:
		return _falhar("primeiros passos não terminou (parou em '%s')" % main.tutorial.titulo())
	print("   primeiros passos concluídos; missão: ", main.missoes.titulo())
	print("4) fogão")
	await _usar(main.fogao)   # põe lenha
	await _usar(main.fogao)   # acende
	await _usar(main.fogao)   # põe caranguejos
	print("   aceso=%s na panela=%d caranguejos + %d peixes (mochila agora %d peixes)" % [main.fogao.aceso, main.fogao.na_panela, main.fogao.peixe_panela, j.mochila["peixe"]])
	var espera := 0
	while main.fogao.cozidos == 0 and espera < 4000:
		espera += 1
		await _quadros(1)
	print("   cozidos: ", main.fogao.cozidos)
	print("5) comer sem farinha")
	if j.farinha:
		return _falhar("já começou com farinha na cuia")
	await _usar(main.fogao)
	await _quadros(10)
	print("   fome: %.0f  comeu: %s  missão concluída: %s" % [j.fome, j.comeu, main.missoes.concluido])
	if not main.missoes.concluido:
		return _falhar("missão não concluída (etapa %d)" % main.missoes.etapa)
	print("5b) atalhos 1-9 e farinha")
	main.hud.continuar()      # fecha a tela de missão concluída (ela pausa o mundo)
	await _quadros(3)
	j.usar_atalho(2)
	var acesa: bool = j.lanterna.light_energy > 0.0
	j.usar_atalho(2)
	j.usar_atalho(1)
	var tarrafa_mao: bool = j.na_mao == "tarrafa"
	j.usar_atalho(0)
	await _usar(main.item_mais_perto("farinha", j.global_position))
	var tinha: bool = j.farinha
	var fome_f: float = j.fome
	j.usar_atalho(4)
	print("   lanterna acendeu: %s · tarrafa na mão: %s · facão de volta: %s · farinha: %s -> comeu (fome %.0f -> %.0f)" % [acesa, tarrafa_mao, j.na_mao == "facao", tinha, fome_f, j.fome])
	if not acesa or j.lanterna.light_energy > 0.0 or not tarrafa_mao or j.na_mao != "facao" or not tinha or j.farinha:
		return _falhar("atalhos da barra não funcionaram")
	print("6) jirau-fogão no meio do mangue")
	main.hud.tela_fim.visible = false
	Mundo.rodando = true
	Mundo.hora = 6.5
	var lugar := Vector3(-6, 0, -30)
	lugar.y = Terreno.altura(lugar.x, lugar.z) + 0.05
	j.global_position = lugar
	j.rotation.y = PI
	j.lenha = 4
	await _quadros(3)
	await _apertar("construir")
	await _quadros(3)
	print("   construir: ", j.texto_alvo)
	await _apertar("interagir")
	var espera2 := 0
	while j.estado != 0 and espera2 < 2000:
		espera2 += 1
		await _quadros(1)
	var jirau = null
	for f in get_tree().get_nodes_in_group("fogao"):
		if f.modelo == "jirau":
			jirau = f
	if jirau == null:
		return _falhar("jirau não foi construído")
	print("   jirau pronto a %.2f m de altura (chão %.2f), lenha na mochila: %d" % [jirau.global_position.y, Terreno.altura(lugar.x, lugar.z), j.lenha])
	await _usar(jirau)   # põe lenha
	await _usar(jirau)   # acende
	print("   aceso: ", jirau.aceso)
	if not jirau.aceso:
		return _falhar("jirau não acendeu")
	Mundo.hora = 11.8
	await _quadros(5)
	print("   maré %.2f às 11:48 -> aceso: %s" % [Mundo.nivel_mare(), jirau.aceso])
	if jirau.aceso:
		return _falhar("a maré cheia deveria apagar o fogo do jirau")
	print("7) missão A rabeta")
	main.hud.tela_fim.visible = false
	Mundo.rodando = true
	Mundo.hora = 6.3
	var b = main.barco
	print("   título: ", main.missoes.titulo())
	await _usar(b.canoa)
	print("   canoa examinada: ", b.canoa.examinada)
	j.mochila["lenha"] = 0
	j.mochila["peixe"] = 0
	for id in ["breu", "helice", "galao", "remo", "cuia"]:
		var pc = b.pecas[id]
		await _usar(pc)
		print("   %s -> mochila %d  (espaços %d/6)" % [id, j.mochila[id], j.espacos_usados()])
	for i in 5:
		await _usar(b.canoa)
	print("   canoa falta: ", b.canoa.falta())
	await _usar(b.pecas["motor"])
	print("   motor na mochila: %d (espaços %d/6)" % [j.mochila["motor"], j.espacos_usados()])
	await _usar(main.bancada)
	print("   bancada sem água: ", j.texto_alvo)
	Mundo.forcar_chuva(1.0)
	Mundo.acelerar = 40.0
	var t0 := 0
	while main.bacia.agua < 1.0 and t0 < 3000:
		t0 += 1
		await _quadros(1)
	Mundo.acelerar = 1.0
	Mundo.forcar_chuva(0.0)
	print("   bacia: %d%% (chuva)" % int(main.bacia.agua * 100))
	await _usar(main.bancada)
	await _quadros(200)
	print("   motor limpo: ", j.motor_limpo)
	await _usar(b.canoa)
	print("   canoa pronta: %s  falta: %s" % [b.canoa.pronta(), b.canoa.falta()])
	if not b.canoa.pronta():
		return _falhar("canoa não ficou pronta")
	# leva a canoa para a água aberta da baía e pilota até a ilha
	Mundo.hora = 12.0
	b.canoa.global_position = Vector3(40, Mundo.nivel_mare(), 78)
	var para_ilha: Vector3 = Vector3(Terreno.ILHA.x, 0, Terreno.ILHA.y) - b.canoa.global_position
	b.canoa._yaw = atan2(-para_ilha.x, -para_ilha.z)
	await _usar(b.canoa)
	await _quadros(60)
	print("   pilotando: ", j.pilotando())
	var gas0: float = b.canoa.gasolina
	Input.action_press("frente")
	var t1 := 0
	while not b.concluida and t1 < 3000:
		t1 += 1
		await _quadros(1)
	Input.action_release("frente")
	print("   chegou na ilha: %s  gasolina %.0f -> %.0f" % [b.concluida, gas0, b.canoa.gasolina])
	if not b.concluida:
		return _falhar("não chegou na ilha de canoa")
	main.hud.tela_fim.visible = false
	Mundo.rodando = true
	await _apertar("interagir")
	await _quadros(5)
	print("   desceu: ", not j.pilotando())
	print("8) perigos, tarrafa e aratu")
	main.hud.tela_fim.visible = false
	Mundo.rodando = true
	j.saude = 100.0
	j.tem_balde = true
	j.caranguejos = 0
	j.peixes = 0
	j.aratus = 0
	for k in j.mochila:
		j.mochila[k] = 0
	# boiar na água funda descansa
	Mundo.hora = 11.8
	var fundo := Vector3(-30, 0, 10)
	j.global_position = Vector3(fundo.x, Mundo.nivel_mare() - 1.45, fundo.z)
	j.estamina = 30.0
	await _quadros(120)
	print("   boiando=%s força 30 -> %.0f, saúde %.0f" % [j.boiando, j.estamina, j.saude])
	# arraia: correr na água rasa
	Mundo.hora = 8.6
	var raso := Vector3.ZERO
	for i in 3000:
		var px := randf_range(-100, 100)
		var pz := randf_range(-40, 50)
		var pr := Mundo.nivel_mare() - Terreno.altura(px, pz)
		var zz := Terreno.zona(px, pz, Terreno.altura(px, pz))
		if pr > 0.25 and pr < 0.6 and zz.r + zz.g > 0.7:
			raso = Vector3(px, Terreno.altura(px, pz), pz)
			break
	j.global_position = raso + Vector3(0, 0.1, 0)
	var s0: float = j.saude
	Input.action_press("frente")
	Input.action_press("correr")
	var t3 := 0
	while j.mancando <= 0.0 and t3 < 1500:
		t3 += 1
		j.estamina = 100.0
		if t3 % 15 == 0:
			j.global_position = raso + Vector3(0, 0.1, 0)
		await _quadros(1)
	Input.action_release("frente")
	Input.action_release("correr")
	print("   arraia: saúde %.0f -> %.0f, mancando %.1f h" % [s0, j.saude, j.mancando])
	# muriçoca ao anoitecer no mangue
	Mundo.hora = 18.2
	j.global_position = Vector3(-6, Terreno.altura(-6, -30) + 0.1, -30)
	var t4 := 0
	while j.muricoca < 0.6 and t4 < 1500:
		t4 += 1
		await _quadros(1)
	print("   muriçoca: %.2f" % j.muricoca)
	var lama_ok: bool = j.passar_lama_no_rosto()
	await _quadros(30)
	print("   lama no rosto: %s -> muriçoca %.2f" % [lama_ok, j.muricoca])
	# tarrafa em cima de um cardume
	Mundo.hora = 11.0
	j.saude = 100.0
	j.mancando = 0.0
	j.tem_tarrafa = true
	# em pé na água rasa, olhando para a água funda
	var nv := Mundo.nivel_mare()
	var pe := Vector3.ZERO
	var dirt := Vector3.FORWARD
	for i in 6000:
		var px := randf_range(-110, 110)
		var pz := randf_range(-40, 50)
		var d1 := nv - Terreno.altura(px, pz)
		if d1 < 0.2 or d1 > 0.9:
			continue
		var a := randf() * TAU
		var dv := Vector3(cos(a), 0, sin(a))
		var q := Vector3(px, 0, pz) + dv * 6.0
		if nv - Terreno.altura(q.x, q.z) > 0.8:
			pe = Vector3(px, Terreno.altura(px, pz) + 0.05, pz)
			dirt = dv
			break
	j.global_position = pe
	j.look_at(pe + dirt, Vector3.UP)
	await _quadros(3)
	var frente: Vector3 = -j.global_transform.basis.z
	frente.y = 0.0
	var centro_c: Vector3 = j.global_position + frente.normalized() * 6.0
	main.peixes._novo_cardume(centro_c)
	var cd = main.peixes.cardumes[main.peixes.cardumes.size() - 1]
	cd["alvo"] = centro_c
	var p0: int = j.peixes + j.mochila["peixe"]
	Input.action_press("tarrafa")
	await _quadros(12)
	# o cardume passa embaixo da mira
	var mira: Vector3 = j._mira_alvo
	print("   mirando: estado=%d mira=%.2f alvo=%s pe=%s" % [j.estado, j._mira, str(mira), str(j.global_position)])
	cd["centro"] = Vector3(mira.x, cd["centro"].y, mira.z)
	cd["alvo"] = cd["centro"]
	await _quadros(2)
	Input.action_release("tarrafa")
	await _quadros(4)
	var t5 := 0
	while j.estado != 0 and t5 < 600:
		t5 += 1
		await _quadros(1)
	await _quadros(5)
	print("   tarrafa: peixes %d -> %d  (nadando=%s)" % [p0, j.peixes + j.mochila["peixe"], j.nadando])
	if j.peixes + j.mochila["peixe"] <= p0:
		return _falhar("tarrafa não pegou nenhum peixe")
	# aratu na raiz com a maré cheia
	Mundo.hora = 11.5
	j.peixes = 0
	j.mochila["peixe"] = 0
	var aratus_no = main.get_children().filter(func(n): return n.get_script() == load("res://scripts/aratus.gd"))[0]
	var t6 := 0
	while aratus_no.get_child_count() == 0 and t6 < 600:
		t6 += 1
		await _quadros(1)
	print("   aratus nas árvores: ", aratus_no.get_child_count())
	var pegou_aratu := false
	for tentativa in 20:
		var espera_a := 0
		while aratus_no.get_child_count() == 0 and espera_a < 300:
			espera_a += 1
			await _quadros(1)
		if aratus_no.get_child_count() == 0:
			break
		var ar = aratus_no.get_child(0)
		j.global_position = Vector3(ar.global_position.x + 0.9, maxf(Terreno.altura(ar.global_position.x + 0.9, ar.global_position.z), Mundo.nivel_mare() - 1.2), ar.global_position.z)
		j.look_at(Vector3(ar.global_position.x, j.global_position.y, ar.global_position.z), Vector3.UP)
		j.cabeca.rotation.x = 0.0
		await _quadros(2)
		print("   alvo: ", j.texto_alvo)
		await _apertar("interagir")
		await _quadros(3)
		if j.aratus > 0:
			pegou_aratu = true
			break
	print("   aratus no balde: ", j.aratus)
	if not pegou_aratu:
		return _falhar("não pegou aratu")
	print("8b) caranguejo com cérebro")
	Mundo.hora = 7.0
	var tq = main.toca_livre_mais_perto(Vector3(0, 0, -30))
	var n_andantes: int = main._andantes.get_child_count()
	var fugiu: bool = main.fuga_toca_vizinha(tq)
	print("   fuga pela toca vizinha: %s (andantes %d -> %d)" % [fugiu, n_andantes, main._andantes.get_child_count()])
	# encurralado: perto de você e longe da toca
	var pc: Vector3 = j.global_position + Vector3(1.2, 0, 0)
	var cr = main._novo_andante(pc)
	await _quadros(2)
	cr.fugir()
	var t7 := 0
	while is_instance_valid(cr) and cr.ameacando <= 0.0 and t7 < 120:
		t7 += 1
		await _quadros(1)
	print("   encurralado levantou as pinças: ", is_instance_valid(cr) and cr.ameacando > 0.0)
	print("   alvo: ", j.texto_alvo)
	print("8c) palafita e parabólica")
	var cu = main.cultura
	await _usar(cu.parabolica)
	var t8 := 0
	while not cu.sinal and t8 < 400:
		t8 += 1
		await _quadros(1)
	print("   sinal: %s  nomes no mapa: %d" % [cu.sinal, main.marcas_mapa().filter(func(m): return m["forma"] == "nome").size()])
	print("   tábua:\n      " + cu.tabua().replace("\n", "\n      "))
	# na palafita com a maré cheia: não pode estar nadando
	Mundo.hora = 11.8
	j.global_position = cu.palafita_pos + Vector3(0, 3.2, 0)
	j.velocity = Vector3.ZERO
	await _quadros(30)
	print("   na palafita, maré %.2f: altura pé %.2f, nadando=%s, chão efetivo %.2f" % [Mundo.nivel_mare(), j.global_position.y, j.nadando, j.chao_efetivo()])
	if j.nadando or not cu.sinal:
		return _falhar("palafita/parabólica com problema")
	# subir a escada da palafita andando
	j.global_position = Vector3(cu.palafita_pos.x, Terreno.altura(cu.palafita_pos.x, cu.palafita_pos.z + 7.5) + 0.1, cu.palafita_pos.z + 7.5)
	Mundo.hora = 7.0
	j.look_at(Vector3(cu.palafita_pos.x, j.global_position.y, cu.palafita_pos.z), Vector3.UP)
	Input.action_press("frente")
	await _quadros(240)
	Input.action_release("frente")
	print("   subiu a escada: altura %.2f (piso em %.2f)" % [j.global_position.y, cu.palafita_pos.y + 3.0])
	print("8d) trapiche: rampa, agarrar borda, agachar")
	j.saude = 100.0
	j.mancando = 0.0
	j.estamina = 100.0
	var tp: Vector3 = main.cultura.trapiche_ponta
	var z0: float = tp.z - 11.0
	# subir a rampa andando, sem atolar
	Mundo.hora = 7.0
	j.global_position = Vector3(tp.x, Terreno.altura(tp.x, z0 - 4.3) + 0.15, z0 - 4.3)
	j.look_at(Vector3(tp.x, j.global_position.y, z0 + 5.0), Vector3.UP)
	Input.action_press("frente")
	var max_atol := 0.0
	for i in 300:
		await _quadros(1)
		max_atol = maxf(max_atol, j.atolado)
		if j.global_position.y > tp.y - 0.1 and j.is_on_floor():
			break
	Input.action_release("frente")
	print("   rampa: altura %.2f (assoalho ~%.2f), atolado máx %.2f" % [j.global_position.y, tp.y, max_atol])
	print("     parou em z %.2f (pé da rampa %.2f, início do trapiche %.2f)" % [j.global_position.z, z0 - 5.5, z0])
	for k in j.get_slide_collision_count():
		var c = j.get_slide_collision(k)
		print("     bate em %s normal %s pos %s" % [str(c.get_collider()), str(c.get_normal().snapped(Vector3.ONE * 0.01)), str(c.get_position().snapped(Vector3.ONE * 0.01))])
	# nadando ao lado do trapiche na maré cheia: ESPAÇO agarra e sobe
	Mundo.hora = 11.8
	await _quadros(5)
	var lado := Vector3(tp.x + 1.9, Mundo.nivel_mare() - 1.45, z0 + 6.0)
	j.global_position = lado
	j.velocity = Vector3.ZERO
	j.look_at(Vector3(tp.x, lado.y, z0 + 6.0), Vector3.UP)
	await _quadros(20)
	var y0: float = j.global_position.y
	await _apertar("pular")
	await _quadros(60)
	print("   agarrou a borda nadando: %.2f -> %.2f (nadando=%s)" % [y0, j.global_position.y, j.nadando])
	# agachar embaixo do trapiche na maré baixa
	Mundo.hora = 6.2
	await _quadros(3)
	j.global_position = Vector3(tp.x + 3.0, Terreno.altura(tp.x + 3.0, z0 + 4.0) + 0.1, z0 + 4.0)
	j.look_at(Vector3(tp.x - 3.0, j.global_position.y, z0 + 4.0), Vector3.UP)
	Input.action_press("agachar")
	Input.action_press("frente")
	await _quadros(240)
	Input.action_release("frente")
	print("   agachado=%s, passou para o outro lado: %s (x %.2f, trapiche em %.2f)" % [j.agachado, j.global_position.x < tp.x - 0.5, j.global_position.x, tp.x])
	Input.action_release("agachar")
	await _quadros(20)
	print("   levantou: ", not j.agachado)
	# canoa: lista aparece sozinha perto (missão já em andamento)
	main.barco.canoa.examinada = false
	main.barco.concluida = false
	j.global_position = main.barco.canoa.global_position + Vector3(3, 0.5, 0)
	await _quadros(5)
	print("   canoa examinada sozinha: %s  · marcador: %s" % [main.barco.canoa.examinada, str(main.barco.alvo().get("txt", "(dentro da área)"))])
	main.barco.concluida = true
	print("9) salvar e carregar")
	var sv = main.salvador
	Mundo.hora = 9.25
	j.mochila["farofa"] = 2
	j.caranguejos = 3
	j.tem_tarrafa = true
	var pos_salva: Vector3 = j.global_position
	var lenha_rancho: int = main.fogao.lenha
	var gas: float = main.barco.canoa.gasolina
	var n_jiraus := get_tree().get_nodes_in_group("fogao").size()
	sv.salvar()
	print("   salvo em %s (%s)" % [sv.caminho, sv.resumo()])
	# bagunça tudo
	Mundo.hora = 20.0
	j.mochila["farofa"] = 0
	j.caranguejos = 0
	j.tem_tarrafa = false
	j.global_position = Vector3(0, 10, 0)
	main.barco.canoa.gasolina = 0.0
	var ok_c: bool = sv.carregar()
	await _quadros(5)
	var n_jiraus2 := get_tree().get_nodes_in_group("fogao").size()
	print("   carregou=%s hora=%s farofa=%d caranguejos=%d tarrafa=%s pos ok=%s gasolina=%.0f fogões %d->%d" % [
		ok_c, Mundo.texto_hora(), j.mochila["farofa"], j.caranguejos, j.tem_tarrafa,
		j.global_position.distance_to(pos_salva) < 0.5, main.barco.canoa.gasolina, n_jiraus, n_jiraus2])
	if not ok_c or j.mochila["farofa"] != 2 or j.caranguejos != 3 or not j.tem_tarrafa or absf(Mundo.hora - 9.25) > 0.01 or absf(main.barco.canoa.gasolina - gas) > 0.1:
		return _falhar("o jogo carregado não bate com o salvo")
	print("9) dormir na rede escolhendo as horas")
	await _usar(main.item_mais_perto("rede", j.global_position))
	await _tela(2)
	if not main.hud.tela_sono.visible:
		return _falhar("a rede não abriu a escolha de horas")
	main.hud.tela_sono._por(5.0)
	var t_antes: float = Mundo.tempo_total()
	main.hud.tela_sono.confirmar()
	var espera_sono := 0
	while j.estado != 0 and espera_sono < 4000:
		espera_sono += 1
		await _quadros(1)
	var dormiu: float = Mundo.tempo_total() - t_antes
	print("   dormiu %.2f h (pediu 5)" % dormiu)
	if absf(dormiu - 5.0) > 0.2:
		return _falhar("dormiu um tempo diferente do escolhido")
	print("6) maré alta")
	for h in [9.0, 10.0, 11.0, 12.0]:
		print("   %02d:00  nível %.2f  (chão do mangue ~0.75, teso %.1f, rancho %.1f)" % [int(h), Mundo.nivel_mare_em(h), Terreno.ALTURA_TESO, Terreno.ALTURA_RANCHO])
	print("TESTE OK")
	get_tree().quit(0)
