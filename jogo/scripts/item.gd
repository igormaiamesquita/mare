extends Node3D
## Coisas que dá para pegar ou usar: balde, feixe de lenha, saco de farinha, rede de dormir.

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
}
var _cortando := false


func _ready() -> void:
	add_to_group("interagivel")
	if MODELOS.has(tipo):
		add_child((load(MODELOS[tipo]) as PackedScene).instantiate())
	Texturas.alcance(self, 70.0)
	if tipo == "rede":
		raio_interacao = 2.2
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


func _process(_delta: float) -> void:
	# a maré leva o que ficou no chão
	if tipo == "balde" and conteudo + peixes > 0 and Mundo.nivel_mare() > global_position.y + 0.15:
		Mundo.avisar("A maré alcançou o balde e tudo fugiu: %d caranguejos e %d peixes!" % [conteudo, peixes], "perigo")
		for j in get_tree().get_nodes_in_group("jogador"):
			j.stats["perdidos"] += conteudo + peixes
		conteudo = 0
		peixes = 0
