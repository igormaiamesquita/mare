extends Node3D
## Coisas do rancho para a missão da canoa:
## - "bacia": junta água da chuva (água doce);
## - "bancada": onde se lava o motor com a água da bacia.

var tipo := ""
var main
var raio_interacao := 2.0
var agua := 0.0                 # bacia: 0..1
var _agua_vis: MeshInstance3D


func _ready() -> void:
	add_to_group("interagivel")
	add_child((load("res://assets/%s.glb" % tipo) as PackedScene).instantiate())
	if tipo == "bacia":
		var disco := CylinderMesh.new()
		disco.top_radius = 0.28
		disco.bottom_radius = 0.28
		disco.height = 0.005
		_agua_vis = MeshInstance3D.new()
		_agua_vis.mesh = disco
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.65, 0.7, 0.75)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		_agua_vis.material_override = m
		add_child(_agua_vis)


func _process(delta: float) -> void:
	if tipo != "bacia":
		return
	# a chuva enche a bacia (em horas de jogo: chuva forte enche em ~1h)
	if Mundo.rodando and Mundo.chuva > 0.05:
		agua = minf(1.0, agua + Mundo.chuva * delta * Mundo.acelerar / Mundo.SEGUNDOS_REAIS_POR_HORA)
	_agua_vis.visible = agua > 0.02
	_agua_vis.position.y = 0.02 + agua * 0.15


func texto_interacao(j) -> String:
	match tipo:
		"bacia":
			if agua >= 1.0:
				return "Bacia cheia de água da chuva (água doce). Use na bancada para lavar o motor."
			if Mundo.chuva > 0.05:
				return "A bacia está enchendo com a chuva: %d%%" % int(agua * 100.0)
			return "Bacia: %d%% de água doce. Ela enche quando chove (dá para dormir na rede e esperar)." % int(agua * 100.0)
		"bancada":
			if j.mochila["motor"] > 0 and not j.motor_limpo:
				if main.bacia.agua >= 1.0:
					return "[E] Lavar o motor com a água doce da bacia"
				return "O motor precisa de água doce. Água do mar deixa sal. Espere a chuva encher a bacia (%d%%)." % int(main.bacia.agua * 100.0)
			if j.motor_limpo and j.mochila["motor"] > 0:
				return "Motor limpo! Leve até a canoa."
			return "Bancada de trabalho"
	return ""


func interagir(j) -> void:
	if tipo == "bancada" and j.mochila["motor"] > 0 and not j.motor_limpo and main.bacia.agua >= 1.0:
		j.ocupar(true)
		Mundo.avisar("Lavando o motor: tirando a lama e o sal com água doce...")
		for i in 3:
			j.golpear()
			await get_tree().create_timer(0.6).timeout
		main.bacia.agua = 0.0
		j.motor_limpo = true
		j.ocupar(false)
		Mundo.avisar("Motor lavado! Agora pode instalar na canoa.", "objetivo")
