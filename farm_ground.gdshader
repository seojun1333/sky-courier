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
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = rot * p * 2.03; a *= 0.5; }
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
	float n1 = fbm(p * 0.03);
	float n2 = fbm(p * 0.5);

	vec2 w = p / 90.0 + vec2(fbm(p * 0.004) * 1.5);
	vec2 fc = floor(w);
	float hf = hash(fc);
	float ang = hf * 6.283;
	float rows = 0.5 + 0.5 * sin(dot(p, vec2(cos(ang), sin(ang))) * (1.6 + hf * 1.2));
	vec3 col;
	if (hf < 0.22) col = mix(vec3(0.72, 0.60, 0.24), vec3(0.84, 0.72, 0.32), rows * 0.5 + n2 * 0.5);
	else if (hf < 0.46) col = mix(vec3(0.16, 0.38, 0.11), vec3(0.26, 0.50, 0.16), rows);
	else if (hf < 0.62) col = mix(vec3(0.36, 0.25, 0.16), vec3(0.28, 0.19, 0.12), rows);
	else if (hf < 0.80) col = mix(vec3(0.27, 0.43, 0.15), vec3(0.36, 0.52, 0.20), n1);
	else col = mix(vec3(0.52, 0.44, 0.20), vec3(0.38, 0.48, 0.19), n1);
	col *= 0.9 + 0.2 * n2;

	vec2 fp = fract(w);
	float border = min(min(fp.x, 1.0 - fp.x), min(fp.y, 1.0 - fp.y));
	col = mix(col, vec3(0.10, 0.22, 0.07), smoothstep(0.012, 0.004, border) * 0.8);

	float rd = abs(fbm(p * 0.0035 + 3.0) - 0.5);
	float road = smoothstep(0.011, 0.006, rd);
	col = mix(col, vec3(0.55, 0.45, 0.32) * (0.9 + 0.2 * n2), road);

	col = mix(col, vec3(0.37, 0.34, 0.30), smoothstep(0.25, 0.45, slope));
	col = mix(col, vec3(0.92, 0.94, 0.98), smoothstep(140.0, 190.0, wpos.y + (n1 - 0.5) * 40.0) * smoothstep(0.5, 0.2, slope));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
