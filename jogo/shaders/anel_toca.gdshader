shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;
// Anel que brilha em volta da boca da toca quando o jogador chega perto.

uniform float forca = 0.0;
uniform vec3 cor : source_color = vec3(1.0, 0.78, 0.35);

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float pulso = 0.75 + 0.25 * sin(TIME * 3.0);
	float anel = smoothstep(0.62, 0.78, d) * (1.0 - smoothstep(0.8, 0.98, d));
	float miolo = (1.0 - smoothstep(0.0, 0.75, d)) * 0.12;
	ALBEDO = cor;
	ALPHA = (anel * pulso + miolo) * forca;
}
