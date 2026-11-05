shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float aspect = 1.78;
uniform float distortion = 0.14;
uniform float aberration = 0.0035;
uniform float vignette = 0.5;
uniform float grain = 0.032;
uniform float glitch = 0.0;
uniform float shake = 0.0;
uniform float sat = 1.12;
uniform float contrast = 1.06;
uniform float flash = 0.0;
uniform float white_flash = 0.0;
uniform float face = 0.0;
uniform float speed_lines = 0.0;
uniform float rain_drops = 0.0;
uniform int cb_mode = 0;
uniform float pulse = 0.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	vec2 c = uv - 0.5;
	vec2 ca = c * vec2(aspect, 1.0);
	float r2 = dot(ca, ca);

	// 광각 렌즈 왜곡 (배럴): 좌우 가장자리가 화면 밖으로 나가지 않게 정규화
	float edge = 0.5 * aspect;
	vec2 d = c * (1.0 + distortion * r2 * 2.0) / (1.0 + distortion * 2.0 * edge * edge);

	// 흔들림
	d += vec2(hash(vec2(TIME, 1.0)) - 0.5, hash(vec2(TIME, 2.0)) - 0.5) * shake;

	// 신호 불량: 가로 띠 찢어짐
	float tt = floor(TIME * 18.0);
	float band = floor(uv.y * 30.0);
	float gl = step(1.0 - glitch * 0.6, hash(vec2(band, tt)));
	d.x += gl * (hash(vec2(band + 1.0, tt)) - 0.5) * 0.14;

	vec2 uvd = 0.5 + d;
	vec2 dir = c * aberration * (1.0 + glitch * 6.0);
	vec3 col;
	col.r = texture(screen_tex, uvd - dir).r;
	col.g = texture(screen_tex, uvd).g;
	col.b = texture(screen_tex, uvd + dir).b;

	// 샤프닝
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 blur = (texture(screen_tex, uvd + vec2(px.x, 0.0)).rgb + texture(screen_tex, uvd - vec2(px.x, 0.0)).rgb
		+ texture(screen_tex, uvd + vec2(0.0, px.y)).rgb + texture(screen_tex, uvd - vec2(0.0, px.y)).rgb) * 0.25;
	col += (col - blur) * 0.5;

	// 색보정 (액션캠 느낌)
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, sat);
	col = (col - 0.5) * contrast + 0.5;

	// 비네팅과 렌즈 가장자리
	float v = smoothstep(0.9, 0.25, length(ca) * 0.95);
	col *= mix(1.0 - vignette, 1.0, v);

	// 필름 그레인, 정지 노이즈
	col += (hash(uv * vec2(1920.0, 1080.0) + TIME) - 0.5) * grain;
	col = mix(col, vec3(hash(uv * 500.0 + TIME * 3.0)), glitch * glitch * 0.75);
	col *= 1.0 - glitch * 0.25 * step(0.5, fract(uv.y * 90.0));
	col += vec3(1.0, 0.85, 0.4) * flash * 0.18;
	col = mix(col, vec3(1.0), clamp(white_flash, 0.0, 1.0) * 0.9);

	// 속도선: 화면 가장자리에서 중심으로 모이는 줄
	if (speed_lines > 0.01) {
		float ang = atan(ca.y, ca.x);
		float rr = length(ca);
		float lid = floor(ang * 46.0);
		float lh = hash(vec2(lid, floor(TIME * 16.0)));
		float ln = step(0.8, lh) * smoothstep(0.22, 0.62, rr) * speed_lines;
		col += vec3(0.9, 0.95, 1.0) * ln * 0.16;
	}
	// 렌즈에 맺힌 빗방울
	if (rain_drops > 0.01) {
		vec2 g = uv * vec2(aspect, 1.0) * 14.0;
		vec2 gi = floor(g);
		float life = fract(TIME * 0.18 + hash(gi) * 5.0);
		float on = step(1.0 - rain_drops * 0.22, hash(gi + 7.0));
		float drop = smoothstep(0.22, 0.0, length(fract(g) - vec2(0.5, 0.5 + life * 0.0))) * on * (1.0 - life);
		col = mix(col, col * 1.25 + vec3(0.04), drop * 0.5);
	}
	// 색약 보정
	if (cb_mode > 0) {
		vec3 sim;
		if (cb_mode == 1) sim = vec3(dot(col, vec3(0.567, 0.433, 0.0)), dot(col, vec3(0.558, 0.442, 0.0)), dot(col, vec3(0.0, 0.242, 0.758)));
		else if (cb_mode == 2) sim = vec3(dot(col, vec3(0.625, 0.375, 0.0)), dot(col, vec3(0.7, 0.3, 0.0)), dot(col, vec3(0.0, 0.3, 0.7)));
		else sim = vec3(dot(col, vec3(0.95, 0.05, 0.0)), dot(col, vec3(0.0, 0.433, 0.567)), dot(col, vec3(0.0, 0.475, 0.525)));
		vec3 er = col - sim;
		if (cb_mode < 3) col += vec3(0.0, er.r * 0.7 + er.g, er.r * 0.7 + er.b);
		else col += vec3(er.b * 0.7 + er.r, er.b * 0.7 + er.g, 0.0);
	}
	col += vec3(0.25, 0.8, 1.0) * pulse * 0.22 * smoothstep(0.2, 0.7, length(ca));

	// 화면을 스치는 얼굴
	if (face > 0.01) {
		vec2 q = c * vec2(aspect, 1.0);
		float oval = smoothstep(0.30, 0.27, length(q * vec2(1.0, 0.72)));
		float eyes = smoothstep(0.05, 0.035, length((q - vec2(-0.085, 0.045)) * vec2(1.0, 0.7)))
			+ smoothstep(0.05, 0.035, length((q - vec2(0.085, 0.045)) * vec2(1.0, 0.7)));
		float mouth = smoothstep(0.055, 0.035, length((q - vec2(0.0, -0.115)) * vec2(1.5, 0.6)));
		vec3 fc = mix(vec3(0.86, 0.89, 0.92), vec3(0.0), clamp(eyes + mouth, 0.0, 1.0));
		col = mix(col, fc, oval * clamp(face, 0.0, 1.0));
	}

	float inside = step(0.0, uvd.x) * step(uvd.x, 1.0) * step(0.0, uvd.y) * step(uvd.y, 1.0);
	COLOR = vec4(col * inside, 1.0);
}
