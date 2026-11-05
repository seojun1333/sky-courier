shader_type spatial;
// 신호등: COLOR.r이 부품(0 기둥, 1 갓, 2 초록, 3 노랑, 4 빨강), INSTANCE_CUSTOM.x가 현재 신호(0 초록, 1 노랑, 2 빨강).

varying float part;
varying float state;

void vertex() {
	part = floor(COLOR.r * 8.0 + 0.5);
	state = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec3 col = vec3(0.3, 0.31, 0.33);
	vec3 emis = vec3(0.0);
	float metal = 0.5;
	if (part > 1.5) {
		float idx = part - 2.0;
		vec3 lc = idx < 0.5 ? vec3(0.1, 1.0, 0.35) : (idx < 1.5 ? vec3(1.0, 0.75, 0.1) : vec3(1.0, 0.1, 0.08));
		float on = step(abs(state - idx), 0.5);
		col = lc * 0.12;
		emis = lc * on * 4.0;
		metal = 0.0;
	} else if (part > 0.5) {
		col = vec3(0.03);
	}
	ALBEDO = col;
	EMISSION = emis;
	METALLIC = metal;
	ROUGHNESS = 0.55;
}
