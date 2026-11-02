shader_type spatial;
render_mode specular_disabled, cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float band_softness = 0.07;

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
	if (albedo.a < 0.99) {
		ALPHA_SCISSOR_THRESHOLD = 0.5;
	}
	ROUGHNESS = 0.9;
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float band = smoothstep(0.16, 0.16 + band_softness, nl) * 0.42
			+ smoothstep(0.5, 0.5 + band_softness, nl) * 0.33
			+ step(0.82, nl) * 0.25;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band;
}
