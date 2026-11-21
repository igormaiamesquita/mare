shader_type canvas_item;
// Escurece as bordas da tela (fome, cansaço, atolado).

uniform float forca = 0.0;
uniform vec4 cor : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 c = UV - 0.5;
	float d = length(c * vec2(1.6, 1.0));
	float a = smoothstep(0.35, 0.95, d) * forca;
	COLOR = vec4(cor.rgb, a * cor.a);
}
