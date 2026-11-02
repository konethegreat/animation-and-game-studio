shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, fog_disabled;

uniform float intensity = 0.0;
uniform vec4 tint : source_color = vec4(0.55, 0.7, 0.95, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float cols = 80.0;
	float lane = floor(uv.x * cols);
	float lane_hash = hash(vec2(lane, 3.0));
	float x = fract(uv.x * cols) - 0.5;
	float speed = 1.4 + lane_hash * 1.9;
	float y = fract(uv.y + TIME * speed * 0.55);
	float streak = smoothstep(0.09, 0.0, abs(x)) * smoothstep(0.42, 0.02, y);
	streak *= step(0.3, lane_hash);
	float mist = 0.045 * smoothstep(0.0, 1.0, uv.y) * (0.6 + 0.4 * sin(TIME * 0.7 + uv.x * 9.0));
	vec3 col = tint.rgb * (streak * 0.55 + mist) * intensity;
	ALBEDO = col;
	ALPHA = clamp((streak * 0.5 + mist) * intensity, 0.0, 1.0);
}
