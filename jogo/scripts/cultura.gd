extends Node
## Homenagem ao mangue brasileiro em geral: o mapa é do Maranhão (maré gigante, bumba-meu-boi)
## com coisas de Pernambuco e do mangue beat (parabólica na lama, palafita, maracatu, frevo).
## - Palafita: abrigo alto, a maré não chega; tem rede.
## - Parabólica: ajustando, "pega o sinal": revela os nomes no mapa e a tábua de marés.

var main
var palafita_pos := Vector3.ZERO
var parabolica: Node3D
var sinal := false
var trapiche_ponta := Vector3.ZERO


func montar() -> void:
	_palafita()
	_parabolica()
	_decoracao()


## Objetos de cena (modelos CC0 do Poly Haven): chapéu no rancho, pneus velhos que a maré trouxe.
## (As galochas viraram item: main.gd cria no rancho.)
func _decoracao() -> void:
	var r: Vector3 = main.pos_rancho
	_enfeite("chapeu", r + Vector3(-1.3, 0.98, -1.1), 0.4, Vector3.ZERO)
	var nf := Vector3(Terreno.NAUFRAGIO.x, 0, Terreno.NAUFRAGIO.y)
	for off in [Vector3(-6, 0, 3), Vector3(4, 0, -5)]:
		var p: Vector3 = nf + off
		p.y = Terreno.altura(p.x, p.z) - 0.12
		_enfeite("pneu_velho", p, randf() * TAU, Vector3(PI / 2 - 0.15, 0, 0))
	for p2 in [Vector3(-90, 0, Terreno.centro_igarape(-90) - 7), Vector3(48, 0, 20)]:
		p2.y = Terreno.altura(p2.x, p2.z) - 0.15
		_enfeite("pneu_velho", p2, randf() * TAU, Vector3(PI / 2 - 0.25, 0, 0.2))


	# cofo no rancho e na palafita
	_enfeite("cofo", r + Vector3(-0.6, 0.53, -1.2), 0.8, Vector3.ZERO)
	_enfeite("cofo", palafita_pos + Vector3(1.0, 3.05, -1.0), 0.2, Vector3.ZERO)
	# trapiche ao lado da palafita, entrando no igarapé
	_trapiche()
	# samambaias na terra firme
	_samambaias()


func _trapiche() -> void:
	var x := palafita_pos.x + 4.5
	var z0 := palafita_pos.z + 3.0
	var deck := 2.5
	var t := (load("res://assets/trapiche.glb") as PackedScene).instantiate() as Node3D
	t.position = Vector3(x, deck - 2.63, z0 - 0.4)
	t.rotation.y = PI
	main.add_child(t)
	# colisão com a forma real (assoalho, estacas, guarda-corpo)
	for mi in t.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).create_trimesh_collision()
	var corpo := StaticBody3D.new()
	main.add_child(corpo)
	# rampa da lama até o trapiche
	# o pé da rampa entra um pouco na lama, para não virar degrau
	var pe := Vector3(x, Terreno.altura(x, z0 - 5.5) - 0.3, z0 - 5.5)
	var topo := Vector3(x, deck + 0.06, z0 - 0.75)   # termina na altura do assoalho, encostada na ponta do trapiche
	var rampa := CollisionShape3D.new()
	var rb := BoxShape3D.new()
	rb.size = Vector3(1.4, 0.1, pe.distance_to(topo) + 0.3)
	rampa.shape = rb
	rampa.position = (pe + topo) * 0.5
	rampa.rotation.x = -atan2(topo.y - pe.y, topo.z - pe.z)   # sobe em direção ao trapiche (+Z)
	corpo.add_child(rampa)
	var tabua := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = rb.size
	tabua.mesh = bm
	tabua.material_override = Texturas.material("madeira_rancho")
	tabua.position = rampa.position
	tabua.rotation = rampa.rotation
	main.add_child(tabua)
	trapiche_ponta = Vector3(x, deck, z0 + 11.0)
	# boia deitada e caixa em cima do assoalho (posição medida depois que a física existir)
	_assentar.call_deferred("boia", Vector3(x + 0.45, 0, z0 + 6.0), 0.3, Vector3(PI / 2, 0, 0))
	_assentar.call_deferred("caixa_plastica", Vector3(x - 0.5, 0, z0 + 9.0), 0.4, Vector3.ZERO)


## Coloca o objeto em cima do que estiver embaixo (raio para baixo).
func _assentar(nome: String, xz: Vector3, yaw: float, rot: Vector3) -> void:
	await main.get_tree().physics_frame
	await main.get_tree().physics_frame
	var espaco: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 8.0, xz.z), Vector3(xz.x, -4.0, xz.z))
	var r: Dictionary = espaco.intersect_ray(q)
	var y: float = r["position"].y if not r.is_empty() else Terreno.altura(xz.x, xz.z)
	var folga := 0.08 if nome == "boia" else 0.0   # a boia deitada tem metade da espessura abaixo do centro
	_enfeite(nome, Vector3(xz.x, y + folga, xz.z), yaw, rot)


func _samambaias() -> void:
	var malha: Mesh = null
	var no := (load("res://assets/samambaia.glb") as PackedScene).instantiate()
	for c in no.find_children("*", "MeshInstance3D", true, false):
		malha = (c as MeshInstance3D).mesh
		break
	no.free()
	if malha == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lista := []
	for i in 3000:
		if lista.size() >= 260:
			break
		var px := rng.randf_range(-120.0, 120.0)
		var pz := rng.randf_range(-120.0, -40.0)
		var h := Terreno.altura(px, pz)
		if Terreno.zona(px, pz, h).b < 0.7 or Vector2(px, pz).distance_to(Terreno.RANCHO) < 7.0:
			continue
		lista.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 1.1)), Vector3(px, h - 0.03, pz)))
	main._multimesh_em_partes(malha, lista, 45.0, false)


func _enfeite(nome: String, pos: Vector3, yaw: float, rot: Vector3) -> void:
	var n := (load("res://assets/%s.glb" % nome) as PackedScene).instantiate() as Node3D
	n.position = pos
	n.rotation = rot
	n.rotate_y(yaw)
	main.add_child(n)
	Texturas.alcance(n, 60.0)


# ------------------------------------------------------------------ palafita

func _palafita() -> void:
	# na margem norte do igarapé, a oeste, virada para a água (+Z)
	# procura chão plano perto do igarapé, a oeste, para a escada encostar na lama
	var x := -58.0
	var z := Terreno.centro_igarape(x) - 16.0
	var melhor := INF
	for xi in range(-80, -30, 2):
		var cz := Terreno.centro_igarape(float(xi))
		for dz in range(14, 30, 2):
			var zz := cz - float(dz)
			var h := Terreno.altura(float(xi), zz)
			if h < 0.4 or h > 1.5:
				continue
			var desnivel := 0.0
			for off in [Vector2(0, 6.1), Vector2(0, 3.0), Vector2(1.8, 0), Vector2(-1.8, 0), Vector2(0, -1.5)]:
				desnivel = maxf(desnivel, absf(Terreno.altura(xi + off.x, zz + off.y) - h))
			var perto_teso := false
			for t in Terreno.TESOS:
				if Vector2(xi - t.x, zz - t.y).length() < t.z + 8.0:
					perto_teso = true
			if perto_teso:
				continue
			var arv := false
			for a in main.arvores:
				if absf(a.x - xi) < 4.0 and a.z > zz - 3.0 and a.z < zz + 8.0:
					arv = true
					break
			var custo := desnivel + (5.0 if arv else 0.0) + absf(dz - 16) * 0.02
			if custo < melhor:
				melhor = custo
				x = float(xi)
				z = zz
	palafita_pos = Vector3(x, Terreno.altura(x, z), z)
	var no := (load("res://assets/palafita.glb") as PackedScene).instantiate() as Node3D
	no.position = palafita_pos
	main.add_child(no)
	var corpo := StaticBody3D.new()
	corpo.position = palafita_pos
	main.add_child(corpo)
	var piso := 3.0
	_caixa(corpo, Vector3(0, piso, 0.6), Vector3(3.6, 0.1, 4.2))                 # assoalho + varanda
	_caixa(corpo, Vector3(0, piso + 1.0, -1.5), Vector3(3.7, 2.0, 0.1))          # fundo
	_caixa(corpo, Vector3(-1.8, piso + 1.0, 0), Vector3(0.1, 2.0, 3.0))          # lados
	_caixa(corpo, Vector3(1.8, piso + 1.0, 0), Vector3(0.1, 2.0, 3.0))
	_caixa(corpo, Vector3(-1.08, piso + 1.0, 1.5), Vector3(1.44, 2.0, 0.1))      # frente com porta
	_caixa(corpo, Vector3(1.115, piso + 1.0, 1.5), Vector3(1.37, 2.0, 0.1))
	# escada: do piso da varanda (z=2.7) até a lama, onde ela realmente estiver
	var base_y := Terreno.altura(palafita_pos.x, palafita_pos.z + 6.1) - palafita_pos.y
	var topo := Vector3(0, piso, 2.7)
	var pe := Vector3(0, base_y, 6.1)
	var meio := (topo + pe) * 0.5
	var comp := topo.distance_to(pe)
	var rampa := _caixa(corpo, meio, Vector3(0.9, 0.08, comp + 0.3))
	rampa.rotation.x = atan2(topo.y - pe.y, pe.z - topo.z)
	# a palafita é mais estreita que o rancho: rede no meio, um pouco mais curta
	var rp: Node3D = main.criar_item("rede", palafita_pos + Vector3(0.0, piso + 0.6, -0.5))
	rp._rede.scale.x = 0.92
	main.criar_item("lenha", palafita_pos + Vector3(-1.2, piso + 0.05, -1.0))


func _caixa(pai: Node3D, pos: Vector3, tam: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = tam
	cs.shape = b
	cs.position = pos
	pai.add_child(cs)
	return cs


# ------------------------------------------------------------------ parabólica

func _parabolica() -> void:
	parabolica = Node3D.new()
	parabolica.set_script(load("res://scripts/parabolica.gd"))
	parabolica.cultura = self
	# lama aberta, sem árvore em volta, para a parabólica aparecer de longe
	var p := Vector3(22.0, 0, -16.0)
	for i in 200:
		var c := Vector3(22.0 + (i % 14) * 2.0 - 14.0, 0, -16.0 + int(i / 14) * 2.0 - 14.0)
		var livre := true
		for a in main.arvores:
			if Vector2(a.x - c.x, a.z - c.z).length() < 4.5:
				livre = false
				break
		var h := Terreno.altura(c.x, c.z)
		if livre and h > 0.3 and h < 1.4:
			p = c
			break
	p.y = Terreno.altura(p.x, p.z)
	parabolica.position = p
	parabolica.rotation.y = 2.4
	main.add_child(parabolica)
	# tocas no pé do monte, com caranguejo andando em volta (como na imagem do mangue beat)
	for i in 4:
		var a := i / 4.0 * TAU + 0.4
		var tp := p + Vector3(cos(a) * 3.6, 0, sin(a) * 3.6)
		tp.y = Terreno.altura(tp.x, tp.z)
		var toca := Node3D.new()
		toca.set_script(load("res://scripts/toca.gd"))
		toca.position = tp
		main.add_child(toca)
		toca.sortear(0.9)
		main.tocas.append(toca)


func pegar_sinal() -> void:
	sinal = true
	Mundo.avisar("A parabólica pegou o sinal! Agora o mapa (M) mostra os nomes dos lugares e a tábua de marés.", "objetivo")


# ------------------------------------------------------------------ nomes no mapa

## Nome dos tesos depois do sinal (os outros ficam só "Teso").
func nome_teso(i: int) -> String:
	if not sinal:
		return "Teso"
	return {0: "Teso do Bumba", 1: "Teso do Frevo", 3: "Teso do Reggae"}.get(i, "Teso")


func nomes() -> Array:
	var ilha := Vector3(Terreno.ILHA.x, 0, Terreno.ILHA.y)
	var croa := Vector3(Terreno.CROA.x, 0, Terreno.CROA.y)
	var t1: Vector3 = Terreno.TESOS[0]
	var t2: Vector3 = Terreno.TESOS[1]
	var t3: Vector3 = Terreno.TESOS[3]
	return [
		["Igarapé do Uçá", Vector3(-95, 0, Terreno.centro_igarape(-95) + 6)],

		["Mangue do Siri", Vector3(70, 0, 25)],
		["Croa Grande", croa],
		["Ilha do Maracatu", ilha],
		["Baía do Boi", Vector3(-20, 0, 105)],
		["Barco Encalhado", Vector3(Terreno.NAUFRAGIO.x, 0, Terreno.NAUFRAGIO.y)],

	]


## Próximas marés (cheias e baixas) para mostrar no mapa.
func tabua() -> String:
	var linhas := []
	var t := Mundo.tempo_total()
	var h := 0.0
	var anterior := Mundo.nivel_mare_em(t)
	var subindo := Mundo.nivel_mare_em(t + 0.05) > anterior
	while h < 26.0 and linhas.size() < 4:
		h += 0.05
		var n := Mundo.nivel_mare_em(t + h)
		var sobe := Mundo.nivel_mare_em(t + h + 0.05) > n
		if sobe != subindo:
			var hora := fposmod(Mundo.hora + h, 24.0)
			var dia := "amanhã " if Mundo.hora + h >= 24.0 else ""
			linhas.append("%s %s%02d:%02d   (%.1f m)" % ["Cheia" if subindo else "Baixa", dia, int(hora), int((hora - int(hora)) * 60.0), n + 2.4])
			subindo = sobe
	return "\n".join(linhas)
