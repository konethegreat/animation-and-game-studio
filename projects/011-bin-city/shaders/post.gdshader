shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec3 warm : source_color = vec3(1.0, 0.93, 0.82);
uniform vec3 cool : source_color = vec3(0.72, 0.85, 0.92);
uniform float strength : hint_range(0.0, 1.0) = 0.5;
uniform float vignette : hint_range(0.0, 1.2) = 0.28;
uniform float grain : hint_range(0.0, 0.2) = 0.022;
uniform float saturation : hint_range(0.0, 2.0) = 1.08;
uniform float time = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 base = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 col = base * mix(cool, warm, smoothstep(0.12, 0.78, luma));
	col = mix(vec3(luma), col, saturation);
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.12);
	float d = distance(SCREEN_UV, vec2(0.5));
	col *= 1.0 - vignette * smoothstep(0.35, 0.85, d);
	col += (hash(SCREEN_UV * 1024.0 + vec2(time)) - 0.5) * grain;
	COLOR = vec4(mix(base, col, strength), 1.0);
}
