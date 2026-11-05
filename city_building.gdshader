shader_type spatial;

uniform float night = 0.7;

varying vec3 wp;
varying vec3 wn;
varying vec4 vc;

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
vec3 hue(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vc = COLOR;
}

void fragment() {
	float style = floor(vc.r * 10.0 + 0.5);
	float tint = vc.g;
	float aux = vc.b;
	vec3 n = normalize(wn);
	float u = dot(wp.xz, vec2(-n.z, n.x));
	float y = wp.y;
	vec3 alb = vec3(0.4);
	vec3 emis = vec3(0.0);
	float rough = 0.9;
	float metal = 0.0;
	float spec = 0.3;
	float fade = smoothstep(120.0, 520.0, -VERTEX.z);
	float grime = noise(vec2(u * 0.6, y * 0.15)) * 0.5 + noise(vec2(u * 3.0, y * 0.4)) * 0.3;

	if (style > 8.5) {
		// 주택 지붕
		float tiles = 0.85 + 0.15 * sin(y * 9.0 + u * 0.5);
		alb = mix(vec3(0.42, 0.19, 0.14), vec3(0.20, 0.24, 0.29), step(0.5, tint)) * tiles;
	} else if (style > 7.5) {
		// 네온 간판
		float bars = step(fract(y * 2.6 + u * 0.15), 0.62);
		vec3 neon = hue(tint);
		emis = neon * (0.5 + 1.4 * bars) * (0.4 + 0.6 * night) * (1.0 + 0.2 * sin(TIME * 5.0 + u));
		alb = neon * 0.25;
	} else if (n.y > 0.75) {
		// 평지붕
		alb = vec3(0.12, 0.125, 0.135) * (0.7 + 0.7 * noise(wp.xz * 0.5));
	} else if (style < 0.5) {
		// 유리 고층 빌딩
		vec2 cell = vec2(u / 1.9, y / 3.8);
		vec2 id = floor(cell);
		vec2 f = fract(cell);
		float win = step(0.06, f.x) * step(f.x, 0.94) * step(0.1, f.y) * step(f.y, 0.88);
		win = mix(win, 0.5, fade);
		vec3 glass = mix(vec3(0.10, 0.20, 0.32), vec3(0.10, 0.28, 0.26), tint) * (0.8 + 0.9 * noise(vec2(u * 0.05, y * 0.04)));
		float lit = step(hash(id + floor(wp.xz * 0.05)), night * 0.3);
		lit = mix(lit, night * 0.3, fade);
		alb = mix(vec3(0.08, 0.09, 0.10), glass, win);
		emis = win * lit * vec3(1.0, 0.8, 0.5) * 1.3;
		rough = mix(0.5, 0.06, win);
		metal = win * 0.6;
		spec = 0.8;
	} else if (style < 1.5) {
		// 사무실: 띠 창
		vec2 cell = vec2(u / 6.0, y / 3.6);
		vec2 id = floor(cell);
		vec2 f = fract(cell);
		float band = step(0.28, f.y) * step(f.y, 0.82) * step(0.04, f.x) * step(f.x, 0.96);
		band = mix(band, 0.5, fade);
		vec3 conc = mix(vec3(0.46, 0.45, 0.42), vec3(0.58, 0.56, 0.52), tint);
		float lit = step(hash(id + floor(wp.xz * 0.05)), night * 0.3);
		lit = mix(lit, night * 0.3, fade);
		alb = mix(conc * (0.8 + 0.4 * grime), vec3(0.07, 0.11, 0.14), band);
		emis = band * lit * vec3(1.0, 0.85, 0.6) * 1.0;
		rough = mix(0.9, 0.1, band);
		metal = band * 0.4;
		spec = 0.6;
	} else if (style < 2.5) {
		// 아파트: 구멍 창과 발코니
		vec2 cell = vec2(u / 3.4, y / 3.0);
		vec2 id = floor(cell);
		vec2 f = fract(cell);
		float win = step(0.2, f.x) * step(f.x, 0.8) * step(0.32, f.y) * step(f.y, 0.86);
		win = mix(win, 0.5, fade);
		vec3 pastel = mix(vec3(0.76, 0.73, 0.67), hue(tint) * 0.5 + 0.4, 0.35);
		float balc = step(f.y, 0.16);
		float lit = step(hash(id + floor(wp.xz * 0.05)), night * 0.5);
		lit = mix(lit, night * 0.3, fade);
		vec3 warm = mix(vec3(1.0, 0.8, 0.5), vec3(0.8, 0.9, 1.0), step(0.7, hash(id * 3.1)));
		alb = pastel * (0.8 + 0.3 * grime) * mix(1.0, 0.65, balc);
		alb = mix(alb, vec3(0.06, 0.09, 0.12), win);
		emis = win * lit * warm * 1.1;
		rough = mix(0.9, 0.12, win);
		spec = 0.5;
	} else if (style < 3.5) {
		// 상가: 1층 유리 + 간판 띠 + 벽돌
		if (y < 4.4) {
			vec2 f = fract(vec2(u / 4.0, 0.0));
			float win = step(0.06, f.x) * step(f.x, 0.94) * step(0.5, y) * step(y, 3.7);
			win = mix(win, 0.5, fade);
			float lit = step(hash(vec2(floor(u / 4.0), floor(wp.x * 0.1 + wp.z * 0.1))), night * 0.7);
			lit = mix(lit, night * 0.3, fade);
			alb = mix(vec3(0.17, 0.16, 0.15), vec3(0.05, 0.07, 0.08), win);
			emis = win * lit * vec3(1.0, 0.78, 0.5) * 0.9;
			rough = mix(0.9, 0.08, win);
			spec = 0.7;
		} else if (y < 5.7) {
			vec3 neon = hue(tint);
			alb = neon * 0.35;
			emis = neon * (0.35 + 0.65 * night) * 1.2;
		} else {
			float row = floor(y / 0.25);
			float brick = step(fract(y / 0.25), 0.9) * step(fract((u + row * 0.35) / 0.7), 0.93);
			vec3 base = mix(vec3(0.34, 0.17, 0.13), vec3(0.50, 0.46, 0.42), 1.0 - brick) * (0.75 + 0.4 * grime);
			vec2 cell = vec2(u / 3.2, (y - 5.7) / 3.4);
			vec2 f = fract(cell);
			float win = step(0.25, f.x) * step(f.x, 0.75) * step(0.3, f.y) * step(f.y, 0.8);
			win = mix(win, 0.5, fade);
			float lit = step(hash(floor(cell) + floor(wp.xz * 0.05)), night * 0.4);
			lit = mix(lit, night * 0.3, fade);
			alb = mix(base, vec3(0.06, 0.09, 0.12), win);
			emis = win * lit * vec3(1.0, 0.82, 0.55);
			rough = mix(0.92, 0.12, win);
		}
	} else if (style < 4.5) {
		// 주택: 회벽 + 작은 창
		vec3 plaster = mix(vec3(0.72, 0.68, 0.60), hue(tint) * 0.5 + 0.4, 0.4);
		vec2 cell = vec2(u / 3.2, y / 3.0);
		vec2 f = fract(cell);
		float win = step(0.3, f.x) * step(f.x, 0.7) * step(0.35, f.y) * step(f.y, 0.8);
		win = mix(win, 0.5, fade);
		float frame = step(0.26, f.x) * step(f.x, 0.74) * step(0.31, f.y) * step(f.y, 0.84) - win;
		float lit = step(hash(floor(cell) + floor(wp.xz * 0.05)), night * 0.5);
		lit = mix(lit, night * 0.3, fade);
		alb = plaster * (0.85 + 0.25 * grime);
		alb = mix(alb, vec3(0.9), clamp(frame, 0.0, 1.0));
		alb = mix(alb, vec3(0.06, 0.09, 0.12), win);
		emis = win * lit * vec3(1.0, 0.8, 0.5);
		rough = mix(0.92, 0.12, win);
	} else if (style < 5.5) {
		// 폐건물: 얼룩진 콘크리트, 낙서, 이끼
		vec3 conc = mix(vec3(0.20, 0.19, 0.18), vec3(0.34, 0.32, 0.29), noise(vec2(u * 0.3, y * 0.3)));
		float streak = noise(vec2(u * 2.5, y * 0.18));
		conc *= 0.55 + 0.7 * streak;
		float crack = smoothstep(0.012, 0.0, abs(noise(vec2(u * 1.7, y * 1.7)) - 0.5));
		conc *= 1.0 - crack * 0.5;
		float g = step(0.8, noise(vec2(u * 0.7, y * 0.9))) * step(2.0, y);
		conc = mix(conc, hue(aux) * 0.7, g * 0.7);
		conc = mix(conc, vec3(0.09, 0.13, 0.06), smoothstep(5.0, 0.0, y) * noise(vec2(u * 0.8, y * 0.8)) * 0.8);
		alb = conc;
	} else if (style < 6.5) {
		// 창고: 골함석
		float rib = 0.82 + 0.18 * sin(u * 6.0);
		alb = mix(vec3(0.40, 0.42, 0.45), hue(tint) * 0.45 + 0.25, 0.5) * rib * (0.8 + 0.3 * grime);
		rough = 0.55;
		metal = 0.3;
	} else {
		// 모텔: 줄무늬 외벽 + 방 창문
		vec2 cell = vec2(u / 5.0, y / 3.2);
		vec2 id = floor(cell);
		vec2 f = fract(cell);
		float win = step(0.3, f.x) * step(f.x, 0.7) * step(0.36, f.y) * step(f.y, 0.8);
		win = mix(win, 0.5, fade);
		vec3 wall = vec3(0.78, 0.74, 0.66);
		float stripe = step(f.y, 0.12);
		alb = mix(wall, hue(tint) * 0.8, stripe) * (0.85 + 0.2 * grime);
		alb = mix(alb, vec3(0.06, 0.09, 0.12), win);
		float lit = step(hash(id + floor(wp.xz * 0.05)), night * 0.4);
		lit = mix(lit, night * 0.3, fade);
		emis = win * lit * vec3(1.0, 0.6, 0.4);
		rough = mix(0.9, 0.12, win);
	}
	ALBEDO = alb;
	EMISSION = emis;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
}

