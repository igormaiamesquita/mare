shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always;
// Água barrenta do mangue: turva, fica opaca rápido com a profundidade, espuma na beira.

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D onda1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D onda2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform vec3 cor_rasa : source_color = vec3(0.40, 0.33, 0.20);
uniform vec3 cor_funda : source_color = vec3(0.20, 0.16, 0.08);
uniform float turbidez = 0.9;
uniform float chuva = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	vec4 vista = INV_PROJECTION_MATRIX * ndc;
	vista.xyz /= vista.w;
	float espessura = max(-vista.z - (-VERTEX.z), 0.0);

	float t = clamp(espessura / turbidez, 0.0, 1.0);
	vec3 cor = mix(cor_rasa, cor_funda, sqrt(t));

	vec2 p = wpos.xz;
	float n = texture(ruido, p * 0.6 + TIME * 0.03).r;
	float espuma = (1.0 - smoothstep(0.0, 0.08, espessura)) * smoothstep(0.35, 0.7, n);

	ALBEDO = mix(cor, vec3(0.78, 0.74, 0.64), espuma * 0.7);
	ALPHA = clamp(mix(0.25, 0.97, smoothstep(0.0, 0.35, espessura)) + espuma * 0.5, 0.0, 1.0);
	ROUGHNESS = 0.14;
	METALLIC = 0.0;
	SPECULAR = 0.3;
	vec3 n1 = texture(onda1, p * 0.07 + vec2(TIME * 0.012, TIME * 0.007)).rgb;
	vec3 n2 = texture(onda2, p * 0.19 - vec2(TIME * 0.009, TIME * 0.015)).rgb;
	NORMAL_MAP = mix(n1, n2, 0.5);
	// pingos de chuva fazendo a água tremer
	vec3 n3 = texture(onda2, p * 1.3 + vec2(TIME * 0.35, -TIME * 0.27)).rgb;
	NORMAL_MAP = mix(NORMAL_MAP, n3, chuva * 0.6);
	NORMAL_MAP_DEPTH = 0.35 + chuva * 0.6;
}
