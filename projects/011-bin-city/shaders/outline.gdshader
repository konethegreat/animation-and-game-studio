shader_type spatial;
render_mode unshaded, cull_front, fog_disabled;

uniform vec4 ink : source_color = vec4(0.16, 0.13, 0.11, 1.0);

void fragment() {
	ALBEDO = ink.rgb;
	ROUGHNESS = 1.0;
}
