shader_type spatial;
// Chão do mapa com texturas reais (Poly Haven, CC0).
// Cor de vértice: r = lama, g = areia, b = terra firme, a = lama mole.
// Perto da água e na chuva tudo fica mais escuro e brilhante (molhado).

uniform float nivel_agua = 0.0;
uniform float chuva = 0.0;
uniform float escala = 0.33;          // repetições por metro (1 / 3 m)
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;

uniform sampler2D lama_cor : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D lama_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D lama_rug : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D mole_cor : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mole_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D mole_rug : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D areia_cor : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D areia_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D areia_rug : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D firme_cor : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D firme_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D firme_rug : hint_roughness_r, filter_linear_mipmap, repeat_enable;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// amostra em duas escalas e mistura pelo ruído, para esconder a repetição
// (uma função por tipo de textura: o Godot não deixa misturar tipos na mesma função)
// gira e desloca a textura em manchas grandes, para esconder a repetição com uma leitura só
vec4 duas(sampler2D t, vec2 uv, float m) {
	vec2 u = m > 0.5 ? vec2(-uv.y, uv.x) * 0.83 + vec2(0.31, 0.77) : uv;
	return texture(t, u);
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 uv = p * escala;
	float n = texture(ruido, p * 0.035).r;
	float n2 = texture(ruido, p * 0.31).r;
	float m = smoothstep(0.35, 0.65, texture(ruido, p * 0.02 + 3.1).r);

	vec3 w = COLOR.rgb / max(COLOR.r + COLOR.g + COLOR.b, 0.001);
	float mole = smoothstep(0.42, 0.58, COLOR.a + (n2 - 0.5) * 0.3);

	// só lê as texturas do tipo de chão que existe aqui (economiza muito na placa de vídeo)
	vec3 c = vec3(0.0);
	vec3 nr = vec3(0.0);
	float rg = 0.0;
	if (w.r > 0.02) {
		c += duas(lama_cor, uv, m).rgb * w.r;
		nr += texture(lama_nor, uv).rgb * w.r;
		rg += texture(lama_rug, uv).r * w.r;
	}
	if (w.g > 0.02) {
		vec2 u = uv * 0.8;
		c += duas(areia_cor, u, m).rgb * w.g;
		nr += texture(areia_nor, u).rgb * w.g;
		rg += texture(areia_rug, u).r * w.g;
	}
	if (w.b > 0.02) {
		vec2 u = uv * 0.9;
		c += duas(firme_cor, u, m).rgb * w.b;
		nr += texture(firme_nor, u).rgb * w.b;
		rg += texture(firme_rug, u).r * w.b;
	}
	float soma = max(w.r * step(0.02, w.r) + w.g * step(0.02, w.g) + w.b * step(0.02, w.b), 0.001);
	c /= soma;
	nr /= soma;
	rg /= soma;
	// variação grande de tom, para o chão não ficar uniforme
	c *= mix(0.82, 1.12, n);
	// lama mole: bem mais escura e lisa, a "cor diferente" que mostra onde atola
	if (mole > 0.01) {
		vec2 uvm = uv * 1.1;
		c = mix(c, texture(mole_cor, uvm).rgb * vec3(0.45, 0.42, 0.4), mole);
		nr = mix(nr, texture(mole_nor, uvm).rgb, mole);
		rg = mix(rg, texture(mole_rug, uvm).r * 0.5, mole);
	}

	// molhado: perto e abaixo da linha d'água, e com chuva
	float acima = wpos.y - nivel_agua;
	float molhado = 1.0 - smoothstep(0.0, 0.9, acima);
	molhado = max(molhado, w.r * (0.35 + 0.3 * n2));
	molhado *= (1.0 - w.b * 0.8);
	molhado = max(molhado, chuva * mix(0.55, 0.9, n2));

	ALBEDO = c * mix(1.0, 0.65, molhado);
	ROUGHNESS = mix(rg, 0.22, molhado * 0.8);
	SPECULAR = 0.5;
	NORMAL_MAP = nr;
	NORMAL_MAP_DEPTH = mix(1.0, 0.45, molhado);
}
