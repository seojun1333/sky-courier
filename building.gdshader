shader_type spatial;

varying vec3 wp;
varying vec3 wn;

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
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = rot * p * 2.03; a *= 0.5; }
	return v;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(wn);
	vec2 p = n.x > n.z ? wp.zy : wp.xy;
	if (n.y > 0.7) p = wp.xz;
	float g = fbm(p * 0.7);
	float fine = noise(p * 7.0);
	vec3 c = mix(vec3(0.17, 0.165, 0.16), vec3(0.30, 0.285, 0.265), g);
	// 빗물 얼룩과 가는 균열, 오염
	float streak = noise(vec2(p.x * 3.0, p.y * 0.22));
	c *= 0.6 + 0.6 * streak;
	float crack = smoothstep(0.012, 0.0, abs(fbm(p * 3.2) - 0.5));
	c *= 1.0 - crack * 0.4;
	c = mix(c, vec3(0.09, 0.12, 0.07), smoothstep(0.62, 0.9, fbm(p * 0.35 + 9.0)) * 0.6);
	ALBEDO = c * (0.85 + 0.3 * fine);
	ROUGHNESS = 0.96;
}
