extends Node
## Gera os ícones da interface fotografando os próprios modelos 3D do jogo (fundo transparente,
## contorno escuro para ler bem por cima do cenário). Salva em res://assets/icones/<nome>.png.
## Rodar (precisa de janela, não use --headless):  godot --path jogo -- --icones
## Depois:  godot --headless --path jogo --import

const TAM := 256
const PASTA := "res://assets/icones/"
## nome do ícone -> [modelo, rotação em graus (x, y, z), extra, giro na tela em graus]
const ITENS := {
	"balde": ["balde", Vector3(-8, 25, 0), ""],
	"mochila": ["embornal", Vector3(0, 200, 0), ""],
	"facao": ["facao", Vector3(0, 90, 0), "", 40.0],
	"tarrafa": ["tarrafa", Vector3(-10, 20, 0), ""],
	"lanterna": ["lanterna", Vector3(0, 60, 25), ""],
	"galochas": ["botas", Vector3(0, 210, 0), ""],
	"panela": ["panela", Vector3(-10, 20, 0), ""],
	"farofa": ["cuia", Vector3(-25, 0, 0), "farofa"],
	"farinha": ["cuia", Vector3(-25, 0, 0), "farinha"],
	"peixe": ["peixe", Vector3(0, 70, -20), ""],
	"caranguejo": ["caranguejo", Vector3(-30, 160, 0), ""],
	"aratu": ["caranguejo", Vector3(-30, 160, 0), "aratu"],
	"lenha": ["feixe_lenha", Vector3(-15, 35, 0), ""],
	"helice": ["helice", Vector3(-20, 30, 0), ""],
	"remo": ["remo", Vector3(90, 0, 0), "", 40.0],
	"cuia": ["cuia", Vector3(-25, 0, 0), ""],
	"galao": ["galao", Vector3(0, 210, 0), ""],
	"breu": ["lata_breu", Vector3(-15, 20, 0), ""],
	"motor": ["motor_rabeta", Vector3(-10, 60, 0), "", 20.0],
}


func gerar(lista: Array = []) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	var vp := SubViewport.new()
	vp.size = Vector2i(TAM, TAM)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.6, 0.56)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	we.environment = env
	vp.add_child(we)
	var chave := DirectionalLight3D.new()
	chave.light_color = Color(1.0, 0.93, 0.82)
	chave.light_energy = 1.9
	chave.rotation_degrees = Vector3(-50, -35, 0)
	vp.add_child(chave)
	var recorte := DirectionalLight3D.new()
	recorte.light_color = Color(0.75, 0.85, 1.0)
	recorte.light_energy = 1.0
	recorte.rotation_degrees = Vector3(-20, 150, 0)
	vp.add_child(recorte)
	var cam := Camera3D.new()
	cam.fov = 26.0
	vp.add_child(cam)
	cam.current = true

	for nome in ITENS:
		if not lista.is_empty() and not nome in lista:
			continue
		var cfg: Array = ITENS[nome]
		var raiz := Node3D.new()
		vp.add_child(raiz)
		var m := (load("res://assets/%s.glb" % cfg[0]) as PackedScene).instantiate() as Node3D
		m.rotation_degrees = cfg[1]
		raiz.add_child(m)
		if cfg.size() > 3:
			raiz.rotation_degrees.z = cfg[3]
		var caixa := _aabb(m)
		if cfg[2] in ["farofa", "farinha"]:
			var f := MeshInstance3D.new()
			var esf := SphereMesh.new()
			esf.radius = caixa.size.x * 0.4
			esf.height = caixa.size.x * 0.8
			f.mesh = esf
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.55, 0.3, 0.12) if cfg[2] == "farofa" else Color(0.95, 0.86, 0.56)
			mat.roughness = 1.0
			f.material_override = mat
			f.scale = Vector3(1, 0.42, 1)
			f.position = caixa.get_center() + Vector3(0, caixa.size.y * 0.42, 0)
			raiz.add_child(f)
		var centro := caixa.get_center()
		var raio := caixa.size.length() * 0.5
		var dist := raio / sin(deg_to_rad(cam.fov * 0.5)) * 0.98
		var dir := Vector3(0, 0.42, 1).normalized()
		cam.position = centro + dir * dist
		cam.look_at(centro, Vector3.UP)
		cam.near = dist * 0.05
		cam.far = dist * 4.0
		for i in 4:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		if cfg[2] == "aratu":
			_tingir(img, Color(1.25, 0.55, 0.42))
		img = _contorno(img, 4, Color(0.07, 0.055, 0.04, 0.92))
		img.save_png(ProjectSettings.globalize_path(PASTA + nome + ".png"))
		print("ICONE ", nome)
		raiz.queue_free()
		await get_tree().process_frame
	vp.queue_free()
	print("ICONES OK")


static func _aabb(n: Node) -> AABB:
	var total := AABB()
	var primeiro := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		var a: AABB = g.global_transform * g.get_aabb()
		if primeiro:
			total = a
			primeiro = false
		else:
			total = total.merge(a)
	return total


static func _tingir(img: Image, cor: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.01:
				img.set_pixel(x, y, Color(minf(1.0, c.r * cor.r), c.g * cor.g, c.b * cor.b, c.a))


## Contorno: espalha o alfa (máximo numa janela, em X e depois em Y) e pinta por baixo do desenho.
static func _contorno(img: Image, r: int, cor: Color) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var a := PackedFloat32Array()
	a.resize(w * h)
	for y in h:
		for x in w:
			a[y * w + x] = img.get_pixel(x, y).a
	var b := PackedFloat32Array()
	b.resize(w * h)
	for y in h:
		for x in w:
			var mx := 0.0
			for k in range(maxi(0, x - r), mini(w, x + r + 1)):
				mx = maxf(mx, a[y * w + k])
			b[y * w + x] = mx
	var saida := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var mx := 0.0
			for k in range(maxi(0, y - r), mini(h, y + r + 1)):
				mx = maxf(mx, b[k * w + x])
			var fundo := Color(cor.r, cor.g, cor.b, cor.a * clampf(mx * 1.5, 0.0, 1.0))
			var c := img.get_pixel(x, y)
			saida.set_pixel(x, y, fundo.blend(c) if c.a > 0.0 else fundo)
	return saida
