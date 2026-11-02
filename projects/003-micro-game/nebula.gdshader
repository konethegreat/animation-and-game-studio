shader_type canvas_item;

uniform float stage : hint_range(0.0, 1.0) = 0.0;
uniform float calm : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amp * noise(p);
		p = p * 2.03 + vec2(3.1, 1.7);
		amp *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = vec2(uv.x * 1.7778, uv.y);

	vec3 low = vec3(0.028, 0.032, 0.058);
	vec3 high = vec3(0.052, 0.048, 0.085);
	vec3 tint = vec3(0.34, 0.46, 0.30);
	vec3 warm = vec3(0.55, 0.28, 0.22);
	if (stage > 0.5) {
		low = vec3(0.042, 0.026, 0.052);
		high = vec3(0.082, 0.042, 0.070);
		tint = vec3(0.55, 0.36, 0.28);
		warm = vec3(0.85, 0.45, 0.22);
	}

	vec3 col = mix(low, high, uv.y);
	float n = fbm(p * 2.1 + vec2(TIME * 0.010, -TIME * 0.006));
	float n2 = fbm(p * 4.4 - vec2(TIME * 0.016, TIME * 0.004));
	float band = smoothstep(0.34, 0.92, n) * (0.55 + 0.45 * n2);

	float drift = calm * 0.55 + 0.45;
	col += tint * band * 0.34 * drift;
	col += warm * smoothstep(0.55, 1.0, n2) * 0.16 * drift;

	vec2 grid = p * 190.0;
	vec2 cell = floor(grid);
	float h = hash(cell);
	float spark = step(0.9968, h);
	vec2 local = fract(grid) - 0.5;
	float twinkle = mix(0.45 + 0.55 * sin(TIME * 1.7 + h * 31.0), 0.65, calm);
	col += spark * smoothstep(0.5, 0.0, length(local)) * vec3(1.0, 0.95, 0.86) * twinkle;

	vec2 v = uv - 0.5;
	col *= 1.0 - dot(v, v) * 0.62;
	COLOR = vec4(col, 1.0);
}
