shader_type sky;

uniform vec3 top_col = vec3(0.14, 0.31, 0.66);
uniform vec3 mid_col = vec3(0.42, 0.60, 0.84);
uniform vec3 hor_col = vec3(0.84, 0.77, 0.70);
uniform vec3 gnd_col = vec3(0.30, 0.30, 0.34);
uniform float cloud_amount = 1.0;
uniform vec3 sun_col = vec3(1.0, 0.85, 0.6);
uniform float sun_size = 2500.0;
uniform float star_amt = 0.0;
uniform float overcast = 0.0;
uniform float cloud_cover = 0.0;

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
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = rot * p * 2.05; a *= 0.5; }
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		vec3 upper = mix(mid_col, top_col, smoothstep(0.15, 0.9, h));
		col = mix(hor_col, upper, smoothstep(0.0, 0.4, pow(h, 0.6)));
	} else {
		col = mix(hor_col, gnd_col, smoothstep(0.0, -0.25, h));
	}

	if (h > 0.02 && star_amt > 0.01) {
		vec2 sp = d.xz / (h + 0.3) * 70.0;
		vec2 cell = floor(sp);
		float st = step(0.987, hash(cell));
		float tw = 0.55 + 0.45 * sin(TIME * 2.0 + hash(cell + 3.0) * 6.28);
		float pt = smoothstep(0.28, 0.0, length(fract(sp) - 0.5));
		col += vec3(1.0, 0.96, 0.9) * st * pt * tw * star_amt * smoothstep(0.04, 0.3, h) * (1.0 - overcast);
	}

	float sdot = 0.0;
	if (LIGHT0_ENABLED) {
		sdot = max(dot(d, normalize(LIGHT0_DIRECTION)), 0.0);
		col += sun_col * (pow(sdot, sun_size) * 40.0 + pow(sdot, 20.0) * 0.18);
	}

	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.14) * 0.38 + vec2(TIME * 0.010, TIME * 0.004);
		float n = fbm(uv);
		float c = smoothstep(0.46 - cloud_cover * 0.28, 0.68 - cloud_cover * 0.2, n) * smoothstep(0.0, 0.10, h) * cloud_amount;
		vec3 cc = mix(vec3(0.60, 0.62, 0.72), vec3(1.0, 0.97, 0.92), smoothstep(0.5, 0.95, n));
		cc += vec3(1.0, 0.8, 0.5) * pow(sdot, 5.0) * 0.35;
		col = mix(col, cc * mix(1.0, 0.42, overcast), c * 0.88);
	}
	col = mix(col, vec3(dot(col, vec3(0.34))) * 0.7, overcast * 0.72);
	COLOR = col;
}
