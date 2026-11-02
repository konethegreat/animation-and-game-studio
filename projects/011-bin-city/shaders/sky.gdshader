shader_type sky;

uniform vec3 zenith : source_color = vec3(0.30, 0.46, 0.64);
uniform vec3 horizon : source_color = vec3(1.0, 0.83, 0.62);
uniform vec3 ground : source_color = vec3(0.55, 0.48, 0.40);
uniform vec3 sun_colour : source_color = vec3(1.0, 0.88, 0.70);
uniform vec3 sun_direction = vec3(-0.45, 0.38, -0.35);
uniform float sun_size : hint_range(0.0, 1.0) = 0.9985;
uniform float horizon_softness : hint_range(0.01, 1.0) = 0.45;

void sky() {
	vec3 dir = normalize(sun_direction);
	float h = EYEDIR.y;
	vec3 col = mix(horizon, zenith, smoothstep(0.0, horizon_softness, h));
	col = mix(col, ground, smoothstep(0.0, -0.35, h));
	float sun = smoothstep(sun_size, sun_size + 0.0012, dot(EYEDIR, dir));
	col = mix(col, sun_colour, sun);
	float halo = pow(max(dot(EYEDIR, dir), 0.0), 18.0) * 0.22;
	col += sun_colour * halo;
	COLOR = col;
}
