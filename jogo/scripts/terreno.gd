class_name Terreno
## Forma do mapa (metros). Norte = -Z.
## Terra firme com o rancho ao norte → mangue de lama → igarapé → mais mangue → baía com uma croa ao sul.

const METADE := 130
const RANCHO := Vector2(0.0, -78.0)
const ALTURA_RANCHO := 3.0
const CROA := Vector2(15.0, 96.0)
## Tesos: morrinhos de terra firme no meio do mangue, onde a maré alta não chega.
const TESOS := [Vector3(-35, -22, 8.0), Vector3(40, -28, 7.0), Vector3(0, -5, 6.5), Vector3(-75, 35, 8.0), Vector3(55, 38, 7.5), Vector3(-100, -10, 7.0), Vector3(95, -15, 7.0)]
const ALTURA_TESO := 2.8
## Banco de lama na baía onde o barco abandonado encalhou (só aparece na maré baixa).
const NAUFRAGIO := Vector2(-45.0, 66.0)
## Ilha do outro lado da baía (só dá para chegar de canoa).
const ILHA := Vector2(92.0, 104.0)
const CANOA := Vector3(34.0, 0.0, 0.0)    # z é calculado na beira do igarapé

static var _n1: FastNoiseLite
static var _n2: FastNoiseLite
static var _n3: FastNoiseLite


static func _ruidos() -> void:
	if _n1 != null:
		return
	_n1 = FastNoiseLite.new()
	_n1.seed = 4
	_n1.frequency = 0.012
	_n1.fractal_octaves = 4
	_n2 = FastNoiseLite.new()
	_n2.seed = 9
	_n2.frequency = 0.07
	_n2.fractal_octaves = 2
	_n3 = FastNoiseLite.new()
	_n3.seed = 17
	_n3.frequency = 0.035
	_n3.fractal_octaves = 2


static func centro_igarape(x: float) -> float:
	return 12.0 + 16.0 * sin(x * 0.028) + 5.0 * sin(x * 0.071 + 1.3)


## Praia da ilha (areia em volta).
static func mascara_ilha(x: float, z: float) -> float:
	var ix := (x - ILHA.x) / 30.0
	var iz := (z - ILHA.y) / 15.0
	return 1.0 - smoothstep(0.75, 1.1, sqrt(ix * ix + iz * iz))


static func mascara_croa(x: float, z: float) -> float:
	_ruidos()
	var cx := (x - CROA.x) / 38.0
	var cz := (z - CROA.y) / 13.0
	return 1.0 - smoothstep(0.55, 1.0, sqrt(cx * cx + cz * cz) + _n1.get_noise_2d(x, z) * 0.15)


## Altura final: a base, com a lama mole um pouco afundada e as poças cavadas.
static func altura(x: float, z: float) -> float:
	var b := _altura_base(x, z)
	var h := b - 0.1 * _mole_de(x, z, b)
	for p in pocas():
		var d := Vector2(x - p.x, z - p.y).length()
		if d < p.z:
			h -= 0.5 * (1.0 - smoothstep(p.z * 0.35, p.z, d))
	return h


static func _altura_base(x: float, z: float) -> float:
	_ruidos()
	var n := _n1.get_noise_2d(x, z)
	var fino := _n2.get_noise_2d(x, z)
	var firme := 3.0 + n * 0.8 + fino * 0.1
	var mangue := 0.75 + n * 1.0 + fino * 0.12
	var h := lerpf(firme, mangue, smoothstep(-70.0, -38.0, z + n * 8.0))
	# igarapé
	var d := absf(z - centro_igarape(x))
	h = lerpf(h, -2.1 + fino * 0.2, 1.0 - smoothstep(3.5, 10.0, d))
	# baía
	h = lerpf(h, -3.2 + fino * 0.2, smoothstep(50.0, 72.0, z + n * 10.0))
	# croa (banco de areia que aparece na vazante)
	h = lerpf(h, 0.55 + fino * 0.12, mascara_croa(x, z))
	# banco do naufrágio
	var dn := Vector2(x, z).distance_to(NAUFRAGIO)
	h = lerpf(h, -0.85 + fino * 0.1, 1.0 - smoothstep(10.0, 18.0, dn + n * 4.0))
	# ilha
	var ix := (x - ILHA.x) / 30.0
	var iz := (z - ILHA.y) / 15.0
	var di := sqrt(ix * ix + iz * iz) + n * 0.12
	h = lerpf(h, 2.4 + n * 0.6 + fino * 0.1, 1.0 - smoothstep(0.6, 1.0, di))
	# tesos
	for t in TESOS:
		var dt := Vector2(x - t.x, z - t.y).length()
		h = lerpf(h, ALTURA_TESO + fino * 0.12, 1.0 - smoothstep(t.z * 0.55, t.z, dt + n * 2.0))
	# terreiro plano do rancho
	var dr := Vector2(x, z).distance_to(RANCHO)
	h = lerpf(h, ALTURA_RANCHO, 1.0 - smoothstep(9.0, 16.0, dr))
	return h


## Peso de cada tipo de chão: r = lama, g = areia, b = terra firme.
static func zona(x: float, z: float, h: float) -> Color:
	_ruidos()
	var n3 := _n3.get_noise_2d(x, z)
	var firme := smoothstep(2.0, 2.45, h + n3 * 0.08)
	var praia := mascara_ilha(x, z) * (1.0 - smoothstep(1.6, 2.3, h))
	var areia := clampf(mascara_croa(x, z) * 1.3 + smoothstep(-1.2, -2.6, h) * 0.55 + praia * 1.5, 0.0, 1.0 - firme)
	var lama := clampf(1.0 - firme - areia, 0.0, 1.0)
	return Color(lama, areia, firme)


static func e_lama(x: float, z: float) -> bool:
	var h := altura(x, z)
	return zona(x, z, h).r > 0.5


## Pontos de lama mole onde a perna afunda ("sumidouro").
static func atoleiro(x: float, z: float) -> bool:
	return mole(x, z) > 0.5


## 0..1: lama mole e funda (escura, onde atola e onde o caranguejo mais cava). Manchas irregulares.
static func mole(x: float, z: float) -> float:
	return _mole_de(x, z, _altura_base(x, z))


static func _mole_de(x: float, z: float, h: float) -> float:
	_ruidos()
	var n := _n3.get_noise_2d(x * 1.9 + 300.0, z * 1.9) + _n2.get_noise_2d(x * 1.3, z * 1.3 - 50.0) * 0.12
	var m := smoothstep(0.24, 0.42, n)
	m *= 1.0 - smoothstep(0.85, 1.15, h)
	m *= smoothstep(-0.9, -0.55, h)
	m *= 1.0 - smoothstep(0.1, 0.3, mascara_croa(x, z))
	return m


## Poças que guardam água (e peixe) quando a maré vaza: Vector3(x, z, raio).
static var _pocas: Array = []
static var _pocas_prontas := false

static func pocas() -> Array:
	if _pocas_prontas:
		return _pocas
	_pocas_prontas = true
	_ruidos()
	var z := -40.0
	while z < 50.0:
		var x := -115.0
		while x < 115.0:
			var px := x + _n2.get_noise_2d(x * 3.0, z) * 5.0
			var pz := z + _n2.get_noise_2d(x, z * 3.0) * 5.0
			var h := _altura_base(px, pz)
			var livre := true
			for t in TESOS:
				if Vector2(px - t.x, pz - t.y).length() < t.z + 4.0:
					livre = false
			if livre and h > 0.45 and h < 1.15 and _mole_de(px, pz, h) < 0.1 and absf(_n3.get_noise_2d(px * 7.0, pz * 7.0)) < 0.18:
				_pocas.append(Vector3(px, pz, 3.0 + absf(_n1.get_noise_2d(px * 5.0, pz)) * 6.0))
			x += 17.0
		z += 15.0
	return _pocas


## Nível da água parada na poça (a borda mais baixa, um pouco abaixo).
static func nivel_poca(p: Vector3) -> float:
	var menor := INF
	for i in 12:
		var a := i / 12.0 * TAU
		menor = minf(menor, _altura_base(p.x + cos(a) * p.z, p.y + sin(a) * p.z))
	return menor - 0.06


## 0..1: onde o mato é mais fechado.
static func densidade_mata(x: float, z: float) -> float:
	_ruidos()
	return clampf(0.45 + _n3.get_noise_2d(x * 0.6 - 100.0, z * 0.6) * 1.8, 0.05, 1.0)


## Teso mais perto de um ponto (em x, z).
static func teso_mais_perto(p: Vector3) -> Vector3:
	var melhor := Vector3.ZERO
	var md := INF
	for t in TESOS:
		var d := Vector2(p.x - t.x, p.z - t.y).length()
		if d < md:
			md = d
			melhor = Vector3(t.x, ALTURA_TESO, t.y)
	return melhor
