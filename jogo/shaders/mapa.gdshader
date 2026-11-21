shader_type canvas_item;
// Mapa visto de cima: cor do chão, relevo sombreado e a água da maré de agora.

uniform sampler2D alturas : filter_linear;   // r = altura (m)
uniform sampler2D cores : filter_linear;     // cor do chão
uniform float nivel = 0.0;
uniform vec2 centro = vec2(0.5);
uniform float zoom = 1.0;                    // quanto do mapa aparece (1 = tudo)
uniform bool redondo = false;

void fragment() {
	vec2 uv = centro + (UV - 0.5) * zoom;
	vec4 fora = vec4(0.08, 0.1, 0.12, 1.0);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		COLOR = fora;
	} else {
		float h = texture(alturas, uv).r;
		vec3 c = texture(cores, uv).rgb;
		float px = 1.0 / 261.0;
		float hx = texture(alturas, uv + vec2(px, 0.0)).r - texture(alturas, uv - vec2(px, 0.0)).r;
		float hz = texture(alturas, uv + vec2(0.0, px)).r - texture(alturas, uv - vec2(0.0, px)).r;
		c *= clamp(1.0 - (hx + hz) * 0.5, 0.6, 1.4);
		float prof = nivel - h;
		if (prof > 0.0) {
			vec3 agua = mix(vec3(0.33, 0.5, 0.58), vec3(0.14, 0.27, 0.38), clamp(prof / 2.5, 0.0, 1.0));
			c = mix(c, agua, clamp(0.55 + prof * 0.4, 0.0, 0.95));
		}
		COLOR = vec4(c, 1.0);
	}
	if (redondo) {
		float d = length(UV - 0.5);
		if (d > 0.5) {
			discard;
		}
		COLOR.rgb = mix(COLOR.rgb, vec3(0.95, 0.85, 0.6), smoothstep(0.47, 0.49, d));
	}
}
