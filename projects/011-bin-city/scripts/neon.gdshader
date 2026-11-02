shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, fog_disabled;

uniform vec4 neon_colour : source_color = vec4(1.0, 0.32, 0.72, 1.0);
uniform float energy = 1.7;
uniform float flicker_speed = 6.0;
uniform float dropout = 0.0;

void fragment() {
	float wave = sin(TIME * flicker_speed) * sin(TIME * flicker_speed * 0.37 + 1.7);
	float flick = 0.84 + 0.16 * wave;
	float drop = 0.0;
	if (dropout > 0.0) {
		drop = step(1.0 - dropout, sin(TIME * 1.1 + neon_colour.r * 17.0)) * 0.6;
	}
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.6);
	vec3 col = neon_colour.rgb * energy * max(flick - drop, 0.22);
	col += neon_colour.rgb * rim * energy * 0.35;
	ALBEDO = col;
	EMISSION = col;
	ROUGHNESS = 0.5;
}
