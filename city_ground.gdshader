shader_type spatial;
render_mode cull_disabled;

uniform float cell = 160.0;
uniform float road_half = 11.0;

varying vec3 wpos;
varying vec4 vcol;

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

// 도로 표시: lat = 도로 중심선에서의 가로 거리, along = 진행 방향 좌표, other = 교차 도로 중심선까지 거리
void marks(float lat, float along, float other, out float white, out float yellow) {
	white = 0.0;
	yellow = 0.0;
	if (other < road_half) return;
	yellow = step(abs(abs(lat) - 0.28), 0.09);
	float dash = step(abs(abs(lat) - 5.5), 0.1) * step(fract(along / 9.0), 0.55);
	float edge = step(abs(abs(lat) - (road_half - 0.8)), 0.1);
	float zebra = step(other, road_half + 4.2) * step(road_half + 1.0, other) * step(fract(lat / 1.3), 0.55) * step(abs(lat), road_half - 0.6);
	white = max(max(dash, edge), zebra);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 rel = p - round(p / cell) * cell;
	vec2 dm = abs(rel);
	float roadZ = step(dm.x, road_half);
	float roadX = step(dm.y, road_half);
	float road = max(roadZ, roadX);
	float sw = max(step(dm.x, road_half + 4.0), step(dm.y, road_half + 4.0)) * (1.0 - road);
	float type = vcol.r * 10.0;
	float n1 = fbm(p * 0.05);
	float n2 = fbm(p * 0.7);
	float n3 = noise(p * 5.0);

	// 블록 바닥
	vec3 col;
	if (type < 0.5) {
		col = mix(vec3(0.26, 0.26, 0.27), vec3(0.34, 0.33, 0.32), n1);
	} else if (type < 1.5) {
		col = mix(vec3(0.16, 0.34, 0.10), vec3(0.28, 0.46, 0.15), n1) * (0.85 + 0.3 * n2);
	} else if (type < 2.5) {
		col = mix(vec3(0.36, 0.44, 0.16), vec3(0.50, 0.48, 0.22), n1) * (0.85 + 0.3 * n2);
	} else {
		col = vec3(0.13, 0.13, 0.14) * (0.9 + 0.2 * n2);
		float bay = step(fract(p.x / 2.8), 0.05) + step(fract(p.y / 5.6), 0.04) * 0.0;
		col = mix(col, vec3(0.8), bay * 0.8);
	}

	// 인도: 보도블록 줄눈
	if (sw > 0.5) {
		vec2 tile = fract(p / 1.4);
		float joint = step(tile.x, 0.04) + step(tile.y, 0.04);
		col = mix(vec3(0.56, 0.54, 0.51), vec3(0.45, 0.43, 0.41), clamp(joint, 0.0, 1.0)) * (0.9 + 0.2 * n2);
		float curb = step(dm.x, road_half + 0.5) * step(road_half, dm.x) + step(dm.y, road_half + 0.5) * step(road_half, dm.y);
		col = mix(col, vec3(0.7), clamp(curb, 0.0, 1.0) * 0.6);
	}

	// 도로
	float rough = 0.95;
	if (road > 0.5) {
		col = vec3(0.075, 0.075, 0.082) * (0.8 + 0.5 * n2) + vec3(0.02) * n3;
		float w1 = 0.0;
		float y1 = 0.0;
		float w2 = 0.0;
		float y2 = 0.0;
		if (roadZ > 0.5) marks(rel.x, p.y, dm.y, w1, y1);
		if (roadX > 0.5) marks(rel.y, p.x, dm.x, w2, y2);
		col = mix(col, vec3(0.82), max(w1, w2) * 0.9);
		col = mix(col, vec3(0.85, 0.65, 0.1), max(y1, y2) * 0.9);
		col *= 1.0 - smoothstep(0.55, 0.8, fbm(p * 0.3 + 4.0)) * 0.25;
		rough = 0.55;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
