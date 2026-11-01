shader_type spatial;
render_mode blend_mix, cull_back, specular_schlick_ggx;

uniform vec4 deep : source_color = vec4(0.16, 0.36, 0.36, 1.0);
uniform vec4 light_water : source_color = vec4(0.46, 0.68, 0.62, 1.0);
uniform float speed = 0.06;

void fragment() {
	vec2 uv = UV * vec2(26.0, 8.0);
	float band = sin(uv.x * 1.4 + TIME * speed * 6.0) * 0.5 + 0.5;
	float ripple = sin(uv.y * 3.1 - TIME * speed * 4.0 + uv.x * 0.7) * 0.5 + 0.5;
	float glint = pow(max(0.0, sin(uv.x * 3.3 + uv.y * 1.7 + TIME * 0.5)), 18.0);
	vec3 color = mix(deep.rgb, light_water.rgb, band * 0.45 + ripple * 0.2);
	color += vec3(0.95, 0.86, 0.68) * glint * 0.55;
	ALBEDO = color;
	ROUGHNESS = 0.18;
	METALLIC = 0.15;
	ALPHA = 0.94;
}
