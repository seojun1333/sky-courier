shader_type spatial;

global uniform float night_f;

varying vec4 vc;
varying vec3 inst_col;
varying float siren;

void vertex() {
	vc = COLOR;
	inst_col = INSTANCE_CUSTOM.rgb;
	siren = INSTANCE_CUSTOM.a;
	// 경광등 막대는 경찰차에서만 지붕 위로 올라온다(나머지 차는 차체 안에 묻어 둔다)
	if (COLOR.b > 0.95 && COLOR.r < 0.1 && siren < 0.5) {
		VERTEX.y -= 0.4;
	}
}

void fragment() {
	float a = vc.a;
	vec3 col = vc.rgb;
	vec3 emis = vec3(0.0);
	float rough = 0.45;
	float metal = 0.3;
	if (a > 0.9 && vc.b > 0.95 && vc.r < 0.1) {
		float ph = step(0.5, fract(TIME * 3.2));
		col = mix(vec3(0.9, 0.05, 0.05), vec3(0.1, 0.25, 1.0), ph);
		emis = col * 4.0;
	} else if (a > 0.9) {
		col = inst_col;                     // 차체 색
		rough = 0.28;
		metal = 0.55;
	} else if (a > 0.4) {
		rough = 0.9;
		metal = 0.0;
	} else if (a > 0.2) {
		col = vec3(1.0, 0.95, 0.8);         // 전조등
		emis = vec3(1.0, 0.92, 0.7) * (0.5 + 3.5 * night_f);
	} else {
		col = vec3(0.8, 0.05, 0.03);        // 후미등
		emis = vec3(1.0, 0.1, 0.05) * (0.5 + 2.2 * night_f);
	}
	ALBEDO = col;
	EMISSION = emis;
	ROUGHNESS = rough;
	METALLIC = metal;
}
