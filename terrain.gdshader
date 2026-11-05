shader_type spatial;
render_mode cull_disabled;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = rot * p * 2.03; a *= 0.5; }
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = NORMAL;
}

void fragment() {
	vec3 n = normalize(wnorm);
	float slope = 1.0 - n.y;
	float h = wpos.y;
	float n1 = fbm(wpos.xz * 0.045);
	float n2 = fbm(wpos.xz * 0.55);
	float n3 = noise(wpos.xz * 3.0);

	vec3 sand = vec3(0.74, 0.68, 0.50);
	vec3 grass1 = vec3(0.17, 0.30, 0.09);
	vec3 grass2 = vec3(0.32, 0.40, 0.15);
	vec3 dry = vec3(0.46, 0.40, 0.21);
	vec3 rock = vec3(0.24, 0.225, 0.22);
	vec3 rock2 = vec3(0.37, 0.33, 0.30);
	vec3 snow = vec3(0.93, 0.95, 0.99);

	vec3 grass = mix(grass1, grass2, n1);
	grass = mix(grass, dry, smoothstep(0.55, 0.9, fbm(wpos.xz * 0.012)));
	grass *= 0.78 + 0.45 * n2;
	vec3 col = grass;

	col = mix(col, sand, smoothstep(4.5, 1.0, h + (n1 - 0.5) * 3.0));

	float rockMask = smoothstep(0.17, 0.36, slope + (n2 - 0.5) * 0.14);
	col = mix(col, mix(rock, rock2, n2 * 1.6), rockMask);

	float snowMask = smoothstep(250.0, 330.0, h + (n1 - 0.5) * 70.0) * smoothstep(0.55, 0.2, slope);
	col = mix(col, snow, snowMask);

	col = mix(col, col * vec3(0.4, 0.58, 0.6), smoothstep(0.0, -7.0, h));
	ALBEDO = col * (0.92 + 0.16 * n3);
	ROUGHNESS = mix(0.95, 0.55, snowMask);
	SPECULAR = 0.25;
}
