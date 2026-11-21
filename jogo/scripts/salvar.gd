extends Node
## Salvar e carregar o jogo (user://save.json).
## Salva sozinho a cada 2 minutos, ao dormir, ao concluir etapa de missão e ao fechar a janela.

var main
var caminho := "user://save.json"
var ativo := true                 # desligado nos testes e nas fotos, para não mexer no save de quem joga
var _relogio := 120.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--teste" or a.begins_with("--fotos="):
			caminho = "user://save_teste.json"
			ativo = false


func existe() -> bool:
	return FileAccess.file_exists(caminho)


func resumo() -> String:
	if not existe():
		return ""
	var f := FileAccess.open(caminho, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return ""
	var h: float = d["mundo"]["hora"]
	return "dia %d, %02d:%02d" % [int(d["mundo"]["dia"]), int(h), int((h - int(h)) * 60.0)]


func apagar() -> void:
	if existe():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))


func _process(delta: float) -> void:
	if not ativo or not Mundo.rodando:
		return
	_relogio -= delta
	if _relogio <= 0.0:
		_relogio = 120.0
		salvar()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and ativo and main != null and main.hud != null and main.hud.iniciado:
		salvar()


# ------------------------------------------------------------------ salvar

func _v(p: Vector3) -> Array:
	return [p.x, p.y, p.z]


func _de_v(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _fogao(f) -> Dictionary:
	var d := {"lenha": f.lenha, "aceso": f.aceso, "combustivel": f.combustivel, "na_panela": f.na_panela,
		"peixe_panela": f.peixe_panela, "cozidos": f.cozidos, "peixe_cozido": f.peixe_cozido, "cozimento": f.cozimento}
	if f.modelo == "jirau":
		var j: Node3D = f.get_parent()
		d["pos"] = _v(j.global_position)
		d["yaw"] = j.rotation.y
	return d


func dados() -> Dictionary:
	var j = main.jogador
	var pos: Vector3 = j.global_position
	if j.pilotando():
		pos = j.canoa.global_position + j.canoa.global_transform.basis.x * 1.4
		pos.y = maxf(Terreno.altura(pos.x, pos.z), Mundo.nivel_mare() - 1.4) + 0.1
	var d := {
		"versao": 1,
		"mundo": {"hora": Mundo.hora, "dia": Mundo.dia, "chuva": Mundo.chuva, "nuvens": Mundo.nuvens},
		"jogador": {
			"pos": _v(pos), "yaw": j.rotation.y, "fome": j.fome, "estamina": j.estamina, "saude": j.saude,
			"mancando": j.mancando, "lama": j.lama_no_rosto, "tem_balde": j.tem_balde,
			"caranguejos": j.caranguejos, "peixes": j.peixes, "aratus": j.aratus, "mochila": j.mochila,
			"motor_limpo": j.motor_limpo, "tem_tarrafa": j.tem_tarrafa, "galochas": j.galochas, "reputacao": j.reputacao,
			"stats": j.stats, "comeu": j.comeu, "lanterna": j.lanterna.light_energy > 0.0,
		},
		"missoes": {"etapa": main.missoes.etapa, "concluido": main.missoes.concluido},
		"tutorial": {"ativo": main.tutorial.ativo, "etapa": main.tutorial.etapa},
		"fogao_rancho": _fogao(main.fogao),
		"jiraus": [],
		"itens_removidos": [],
		"troncos": {},
		"baldes_largados": [],
		"bacia": main.bacia.agua,
		"sinal": main.cultura.sinal,
		"barco": {},
	}
	for f in get_tree().get_nodes_in_group("fogao"):
		if f.modelo == "jirau":
			d["jiraus"].append(_fogao(f))
	for uid in main.itens_iniciais:
		var n = main.itens_iniciais[uid]
		if not is_instance_valid(n):
			d["itens_removidos"].append(uid)
		elif n.tipo == "tronco":
			d["troncos"][uid] = n.conteudo
	for n in get_tree().get_nodes_in_group("interagivel"):
		if n.get("tipo") == "balde" and not n.has_meta("uid"):
			d["baldes_largados"].append({"pos": _v(n.global_position), "conteudo": n.conteudo, "peixes": n.peixes})
	var b = main.barco
	var c = b.canoa
	d["barco"] = {
		"examinada": c.examinada, "furo": c.furo, "tem_motor": c.tem_motor, "tem_helice": c.tem_helice,
		"tem_remo": c.tem_remo, "tem_cuia": c.tem_cuia, "gasolina": c.gasolina,
		"pos": _v(c.global_position), "yaw": c._yaw, "concluida": b.concluida,
		"pecas_pegas": b.pecas.keys().filter(func(id): return not is_instance_valid(b.pecas[id])),
	}
	return d


func salvar() -> void:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(dados(), "\t"))
	f.close()


# ------------------------------------------------------------------ carregar

func carregar() -> bool:
	if not existe():
		return false
	var f := FileAccess.open(caminho, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return false
	aplicar(d)
	return true


func _por_fogao(f, d: Dictionary) -> void:
	f.lenha = int(d["lenha"])
	f.combustivel = float(d["combustivel"])
	f.na_panela = int(d["na_panela"])
	f.peixe_panela = int(d["peixe_panela"])
	f.cozidos = int(d["cozidos"])
	f.peixe_cozido = int(d["peixe_cozido"])
	f.cozimento = float(d["cozimento"])
	if bool(d["aceso"]):
		f.aceso = true
		f.fogo.emitting = true
		f.fumaca.emitting = true
		f.vapor.emitting = f.na_panela + f.peixe_panela > 0


func aplicar(d: Dictionary) -> void:
	var m: Dictionary = d["mundo"]
	Mundo.hora = float(m["hora"])
	Mundo.dia = int(m["dia"])
	Mundo.forcar_chuva(float(m["chuva"]))
	Mundo.nuvens = float(m["nuvens"])

	var j = main.jogador
	var jd: Dictionary = d["jogador"]
	j.global_position = _de_v(jd["pos"])
	j.rotation.y = float(jd["yaw"])
	j.fome = float(jd["fome"])
	j.estamina = float(jd["estamina"])
	j.saude = float(jd["saude"])
	j.mancando = float(jd["mancando"])
	j.lama_no_rosto = float(jd["lama"])
	j.tem_balde = bool(jd["tem_balde"])
	j.caranguejos = int(jd["caranguejos"])
	j.peixes = int(jd["peixes"])
	j.aratus = int(jd["aratus"])
	for k in jd["mochila"]:
		if j.mochila.has(k):
			j.mochila[k] = int(jd["mochila"][k])
	j.motor_limpo = bool(jd["motor_limpo"])
	j.tem_tarrafa = bool(jd["tem_tarrafa"])
	j.galochas = bool(jd.get("galochas", false))
	j.reputacao = int(jd["reputacao"])
	for k in jd["stats"]:
		j.stats[k] = int(jd["stats"][k])
	j.comeu = bool(jd["comeu"])
	j.lanterna.light_energy = j.LANTERNA if bool(jd["lanterna"]) else 0.0

	main.missoes.etapa = int(d["missoes"]["etapa"])
	main.missoes.concluido = bool(d["missoes"]["concluido"])
	# jogos salvos de antes dos primeiros passos: já passaram dessa fase
	var tut: Dictionary = d.get("tutorial", {"ativo": false, "etapa": 0})
	main.tutorial.ativo = bool(tut["ativo"])
	main.tutorial.etapa = int(tut["etapa"])

	_por_fogao(main.fogao, d["fogao_rancho"])
	for jr in d["jiraus"]:
		var no: Node3D = main.jirau_pronto(_de_v(jr["pos"]), float(jr["yaw"]))
		var fg = no.get_child(no.get_child_count() - 1)
		fg.ready.connect(_por_fogao.bind(fg, jr), CONNECT_ONE_SHOT)
		if fg.is_node_ready():
			_por_fogao(fg, jr)

	for uid in d["itens_removidos"]:
		var n = main.itens_iniciais.get(uid)
		if n != null and is_instance_valid(n):
			n.queue_free()
	for uid in d["troncos"]:
		var n = main.itens_iniciais.get(uid)
		if n != null and is_instance_valid(n):
			n.conteudo = int(d["troncos"][uid])
	for bl in d["baldes_largados"]:
		var it = main.criar_item("balde", _de_v(bl["pos"]), int(bl["conteudo"]), false)
		it.peixes = int(bl["peixes"])
	main.bacia.agua = float(d["bacia"])
	main.cultura.sinal = bool(d.get("sinal", false))

	var bd: Dictionary = d["barco"]
	var c = main.barco.canoa
	c.examinada = bool(bd["examinada"])
	c.furo = bool(bd["furo"])
	c.tem_motor = bool(bd["tem_motor"])
	c.tem_helice = bool(bd["tem_helice"])
	c.tem_remo = bool(bd["tem_remo"])
	c.tem_cuia = bool(bd["tem_cuia"])
	c.gasolina = float(bd["gasolina"])
	c.global_position = _de_v(bd["pos"])
	c._yaw = float(bd["yaw"])
	c._atualizar_vis()
	main.barco.concluida = bool(bd["concluida"])
	main.barco.chegou_ilha = main.barco.concluida
	for id in bd["pecas_pegas"]:
		var p = main.barco.pecas.get(id)
		if p != null and is_instance_valid(p):
			p.queue_free()
