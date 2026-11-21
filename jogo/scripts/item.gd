extends Node3D
## Coisas que dá para pegar ou usar: balde, feixe de lenha, saco de farinha, rede de dormir, galochas.

var tipo := ""
var conteudo := 0          # caranguejos no balde largado / lenha que ainda sai do tronco
var raio_interacao := 2.0
var peixes := 0            # peixes no balde largado

const MODELOS := {
	"balde": "res://assets/balde.glb",
	"lenha": "res://assets/feixe_lenha.glb",
	"farinha": "res://assets/saco_farinha.glb",
	"tronco": "res://assets/tronco_caido.glb",
	"tarrafa": "res://assets/tarrafa.glb",
	"galochas": "res://assets/botas.glb",
}
var _cortando := false
var _rede: Node3D             # o modelo da rede, que balança
var _t := 0.0


func _ready() -> void:
	add_to_group("interagivel")
	if MODELOS.has(tipo):
		add_child((load(MODELOS[tipo]) as PackedScene).instantiate())
	Texturas.alcance(self, 70.0)
	if tipo == "rede":
		raio_interacao = 2.2
		# o item fica no meio do pano; o modelo tem a origem na linha dos armadores, 1.15 m acima
		_rede = (load("res://assets/rede.glb") as PackedScene).instantiate() as Node3D
		_rede.position.y = 1.15
		add_child(_rede)
		_t = randf() * TAU
	if tipo == "tronco":
		raio_interacao = 2.6
		var corpo := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(4.2, 0.35, 0.4)
		cs.shape = b
		cs.position.y = 0.17
		corpo.add_child(cs)
		add_child(corpo)


func texto_interacao(j) -> String:
	match tipo:
		"balde":
			if conteudo + peixes > 0:
				return "[E] Pegar o balde (%d caranguejos, %d peixes)" % [conteudo, peixes]
			return "[E] Pegar o balde"
		"lenha":
			if j.cabe_na_mochila("lenha") <= 0:
				return "A mochila está cheia"
			return "[E] Pegar o feixe de lenha"
		"tronco":
			if conteudo <= 0:
				return "Tronco já cortado"
			if j.cabe_na_mochila("lenha") <= 0:
				return "A mochila está cheia"
			if _cortando:
				return "Cortando..."
			return "[E] Cortar lenha com o facão (%d)" % conteudo
		"farinha":
			if j.farinha:
				return "A cuia já está cheia de farinha"
			if j.cabe_na_mochila("farinha") <= 0:
				return "A mochila está cheia"
			return "[E] Encher a cuia de farinha (vai na mochila)"
		"rede":
			return "[E] Deitar na rede e dormir até a próxima maré baixa"
		"tarrafa":
			return "[E] Pegar a tarrafa"
		"galochas":
			return "[E] Calçar as galochas (atola menos na lama e protege o pé)"
	return ""


func interagir(j) -> void:
	match tipo:
		"balde":
			j.pegar_balde(conteudo, peixes)
			queue_free()
		"lenha":
			j.lenha += 1
			Mundo.avisar("Feixe de lenha na mochila (%d)" % j.lenha)
			queue_free()
		"tronco":
			if _cortando or conteudo <= 0:
				return
			_cortando = true
			for i in 3:
				j.golpear()
				await get_tree().create_timer(0.45).timeout
			conteudo -= 1
			j.lenha = mini(j.lenha + 1, j.lenha_max)
			_cortando = false
			Mundo.avisar("Cortou um feixe de lenha (%d na mochila)" % j.lenha)
		"farinha":
			j.farinha = true
			Mundo.avisar("Encheu a cuia de farinha d'água")
		"rede":
			j.dormir()
		"tarrafa":
			j.tem_tarrafa = true
			Mundo.avisar("Pegou a tarrafa! Perto de um cardume, SEGURE T para mirar e SOLTE para jogar.", "objetivo")
			queue_free()
		"galochas":
			j.galochas = true
			Mundo.avisar("Calçou as galochas: a lama mole prende menos e o pé fica protegido da arraia.", "objetivo")
			queue_free()


func _process(delta: float) -> void:
	if _rede != null:
		_t += delta
		_rede.rotation.x = sin(_t * 0.8) * 0.035 + sin(_t * 0.31) * 0.015
	# a maré leva o que ficou no chão
	if tipo == "balde" and conteudo + peixes > 0 and Mundo.nivel_mare() > global_position.y + 0.15:
		Mundo.avisar("A maré alcançou o balde e tudo fugiu: %d caranguejos e %d peixes!" % [conteudo, peixes], "perigo")
		for j in get_tree().get_nodes_in_group("jogador"):
			j.stats["perdidos"] += conteudo + peixes
		conteudo = 0
		peixes = 0
