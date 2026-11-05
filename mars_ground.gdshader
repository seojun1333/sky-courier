shader_type spatial;
render_mode cull_disabled;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = rot * p * 2.03; a *= 0.5; }
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = NORMAL;
}

void fragment() {
	vec2 p = wpos.xz;
	vec3 n = normalize(wnorm);
	float slope = 1.0 - n.y;
	float n1 = fbm(p * 0.02);
	float n2 = fbm(p * 0.4);
	float n3 = noise(p * 3.0);

	vec3 base1 = vec3(0.55, 0.26, 0.14);
	vec3 base2 = vec3(0.78, 0.44, 0.25);
	vec3 pale = vec3(0.88, 0.66, 0.48);
	vec3 dark = vec3(0.26, 0.12, 0.09);

	vec3 col = mix(base1, base2, n1);
	float ripple = 0.5 + 0.5 * sin(p.x * 0.35 + fbm(p * 0.05) * 7.0);
	col = mix(col, pale, ripple * 0.18 * (1.0 - clamp(slope * 3.0, 0.0, 1.0)));
	col = mix(col, dark * 0.8, smoothstep(0.62, 0.78, fbm(p * 0.008 + 7.0)) * 0.7);
	col = mix(col, dark, smoothstep(0.14, 0.40, slope + (n2 - 0.5) * 0.1));
	ALBEDO = col * (0.88 + 0.24 * n3);
	ROUGHNESS = 0.98;
	SPECULAR = 0.1;
}
