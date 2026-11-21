shader_type sky;
// Céu do mangue: degradê, sol com brilho, lua com fases, estrelas e nuvens que andam com o vento.

uniform vec3 cor_topo : source_color = vec3(0.26, 0.45, 0.72);
uniform vec3 cor_horizonte : source_color = vec3(0.66, 0.72, 0.78);
uniform vec3 cor_chao : source_color = vec3(0.05, 0.05, 0.045);
uniform vec3 cor_sol : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 dir_sol = vec3(0.0, 1.0, 0.0);
uniform vec3 dir_lua = vec3(0.0, -1.0, 0.0);
uniform float fase_lua = 0.5;      // 0 nova, 0.5 cheia
uniform float luz_dia = 1.0;       // 0 noite, 1 dia
uniform float nuvens = 0.3;        // quanto do céu está coberto
uniform float chuva = 0.0;         // escurece as nuvens
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 c = mix(cor_horizonte, cor_topo, pow(clamp(h, 0.0, 1.0), 0.55));
	if (h < 0.0) {
		c = mix(cor_horizonte, cor_chao, clamp(-h * 5.0, 0.0, 1.0));
	}
	float noite = 1.0 - luz_dia;
	float limpo = 1.0 - clamp(nuvens * 1.1, 0.0, 1.0) * 0.85;

	// estrelas
	if (h > 0.0 && noite > 0.02) {
		vec3 p = floor(d * 260.0);
		float r = hash(p);
		float brilho = step(0.9965, r) * (0.6 + 0.4 * sin(TIME * 2.0 + r * 50.0));
		c += vec3(0.9, 0.92, 1.0) * brilho * noite * limpo * smoothstep(0.0, 0.25, h) * 1.4;
	}

	// sol: disco + brilho em volta
	vec3 sd = normalize(dir_sol);
	float s = dot(d, sd);
	float disco = smoothstep(0.99905, 0.9993, s);
	float halo = pow(max(s, 0.0), 300.0) * 1.5 + pow(max(s, 0.0), 30.0) * 0.35 + pow(max(s, 0.0), 5.0) * 0.1;
	float sol_visivel = smoothstep(-0.06, 0.02, sd.y);
	c += cor_sol * (disco * 40.0 + halo) * sol_visivel * mix(limpo, 1.0, 0.25);

	// lua: disco com crateras e fase
	vec3 ld = normalize(dir_lua);
	float m = dot(d, ld);
	float raio = 0.99875;
	if (m > raio && ld.y > -0.05) {
		vec3 direita = normalize(cross(ld, vec3(0.0, 1.0, 0.0)));
		vec3 cima = cross(direita, ld);
		vec2 uv = vec2(dot(d, direita), dot(d, cima)) / sqrt(1.0 - raio * raio);
		float r2 = dot(uv, uv);
		float z = sqrt(max(0.0, 1.0 - r2));
		vec3 n = vec3(uv, z);
		float ang = fase_lua * 6.2831853;
		vec3 luz = vec3(-sin(ang), 0.0, -cos(ang));
		float ilum = smoothstep(-0.04, 0.08, dot(n, luz));
		float crat = texture(ruido, uv * 0.35 + 0.5).r;
		float crat2 = texture(ruido, uv * 0.9 + 0.2).r;
		vec3 cor_lua = vec3(0.93, 0.92, 0.86) * mix(0.62, 1.05, crat) * mix(0.85, 1.05, crat2);
		float borda = 1.0 - smoothstep(0.92, 1.0, sqrt(r2));
		vec3 lua = cor_lua * ilum * 1.7 + vec3(0.04, 0.05, 0.07) * (1.0 - ilum);
		c = mix(c, lua, borda * limpo);
	}
	c += vec3(0.55, 0.62, 0.8) * pow(max(m, 0.0), 900.0) * 0.4 * noite * limpo;

	// nuvens
	if (h > 0.0) {
		vec2 p = d.xz / (h + 0.06) * 0.22 + vec2(TIME * 0.0025, TIME * 0.0012);
		float n1 = texture(ruido, p).r;
		float n2 = texture(ruido, p * 2.9 + vec2(3.1, 1.7)).r;
		float f = n1 * 0.7 + n2 * 0.3;
		float cob = smoothstep(0.66 - nuvens * 0.5, 0.82 - nuvens * 0.42, f);
		cob *= smoothstep(0.0, 0.1, h);
		vec3 clara = mix(vec3(1.0, 0.98, 0.95), cor_horizonte, 0.25) * mix(0.12, 1.0, luz_dia);
		clara += cor_sol * pow(max(s, 0.0), 8.0) * 0.6 * luz_dia;
		vec3 escura = vec3(0.32, 0.34, 0.37) * mix(0.1, 1.0, luz_dia);
		vec3 cor_nuvem = mix(clara, escura, clamp(chuva * 1.2 + (n2 - 0.5) * 0.4, 0.0, 1.0));
		c = mix(c, cor_nuvem, cob);
	}
	COLOR = c;
}
