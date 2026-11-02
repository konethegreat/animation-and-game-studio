shader_type spatial;
render_mode blend_mix, cull_back, specular_schlick_ggx;

uniform vec4 deep : source_color = vec4(0.16, 0.36, 0.36, 1.0);
uniform vec4 light_water : source_color = vec4(0.46, 0.68, 0.62, 1.0);
uniform float speed = 0.06;
uniform float foam_width = 0.09;

void fragment() {
	vec2 uv = UV;
	vec2 flow_a = uv * vec2(30.0, 9.0) + vec2(TIME * speed * 0.6, 0.0);
	vec2 flow_b = uv * vec2(17.0, 6.0) - vec2(TIME * speed * 0.4, TIME * speed * 0.12);
	float band = sin(flow_a.x * 1.4 + sin(flow_a.y * 2.2)) * 0.5;
	band += sin(flow_b.x * 2.3 - flow_b.y * 1.7) * 0.35;
	band = clamp(band * 0.5 + 0.5, 0.0, 1.0);
	float glint = pow(max(0.0, sin(flow_a.x * 3.3 + flow_b.y * 1.7 + TIME * 0.5)), 18.0);
	vec3 color = mix(deep.rgb, light_water.rgb, band * 0.55);
	float depth = abs(uv.y - 0.5) * 2.0;
	color = mix(color, deep.rgb, (1.0 - depth) * 0.4);
	color += vec3(0.95, 0.86, 0.68) * glint * 0.5;
	float edge = min(uv.y, 1.0 - uv.y);
	float foam_wave = sin(uv.x * 62.0 + TIME * 0.7) * 0.025;
	float foam = smoothstep(foam_width + foam_wave, 0.005, edge);
	color = mix(color, vec3(0.92, 0.96, 0.9), foam * 0.85);
	ALBEDO = color;
	ROUGHNESS = mix(0.16, 0.6, foam);
	METALLIC = 0.15;
	ALPHA = 0.95;
}
