shader_type canvas_item;

uniform float stage : hint_range(0.0, 1.0) = 0.0;
uniform float glow : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.7, 289.3))) * 43758.5453123);
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

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	if (d > 1.0) {
		discard;
	}

	float z = sqrt(max(0.0, 1.0 - d * d));
	vec3 normal = normalize(vec3(p.x, -p.y, z));
	vec3 light = normalize(vec3(-0.55, -0.62, 0.58));
	float lambert = clamp(dot(normal, light), 0.0, 1.0);

	vec2 q = vec2(p.x * 2.4, p.y * 2.4);
	float grain = noise(q * 3.2) * 0.55 + noise(q * 7.4) * 0.45;
	float bands = sin(p.y * 15.0 + sin(p.x * 4.2) * 1.3) * 0.5 + 0.5;
	float fibre = smoothstep(0.42, 0.58, noise(vec2(q.x * 9.0, q.y * 2.2)));

	vec3 paper = mix(vec3(0.965, 0.915, 0.80), vec3(0.875, 0.80, 0.655), bands * 0.5);
	paper = mix(paper, vec3(0.80, 0.715, 0.565), fibre * 0.22);
	paper *= 0.94 + grain * 0.14;

	float crater = 0.0;
	crater += smoothstep(0.075, 0.0, length(p - vec2(-0.32, 0.28))) * 0.35;
	crater += smoothstep(0.055, 0.0, length(p - vec2(0.18, -0.44))) * 0.3;
	crater += smoothstep(0.04, 0.0, length(p - vec2(0.48, 0.16))) * 0.26;
	crater += smoothstep(0.03, 0.0, length(p - vec2(-0.55, -0.32))) * 0.22;
	paper *= 1.0 - crater;

	float shade = 0.44 + 0.72 * lambert;
	vec3 col = paper * shade;
	col += vec3(1.0, 0.78, 0.46) * pow(lambert, 3.0) * 0.34;

	float rim = smoothstep(0.88, 1.0, d);
	col += mix(vec3(0.80, 0.94, 0.44), vec3(1.0, 0.72, 0.42), stage) * rim * (0.18 + glow * 0.24);

	float terminator = smoothstep(0.0, 0.32, lambert);
	col = mix(col * 0.8, col, terminator);
	COLOR = vec4(col, 1.0);
}
