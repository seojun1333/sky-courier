shader_type spatial;
// 기본 알몸 모델에 옷을 입힌다. 모델 정점의 기준 자세(T자) 좌표를 COLOR에 구워 두었고, 그 높이·가로 위치로 상의/하의/신발 영역을 가른다.

uniform sampler2D skin_tex : source_color;
uniform sampler2D normal_tex : hint_normal;
uniform sampler2D rough_tex : hint_default_white;
uniform vec3 skin_tint = vec3(1.0);
uniform vec3 shirt_col = vec3(0.2, 0.3, 0.6);
uniform vec3 shirt2_col = vec3(0.2, 0.3, 0.6);
uniform vec3 pants_col = vec3(0.15, 0.15, 0.2);
uniform vec3 shoe_col = vec3(0.08, 0.08, 0.09);
uniform float sleeve_x = 0.34;
uniform float pants_y = 0.0;
uniform float shirt_top = 1.53;
uniform float shirt_bottom = 0.99;
uniform float stripe = 0.0;

varying vec3 rest;

void vertex() {
	rest = vec3(COLOR.r * 2.0 - 1.0, COLOR.g * 2.0, COLOR.b * 2.0 - 1.0);
}

void fragment() {
	vec3 base = texture(skin_tex, UV).rgb;
	float lum = dot(base, vec3(0.3, 0.59, 0.11));
	float ax = abs(rest.x);
	float y = rest.y;
	float torso = smoothstep(shirt_bottom - 0.01, shirt_bottom + 0.01, y) * (1.0 - smoothstep(shirt_top - 0.01, shirt_top + 0.01, y));
	float body_w = 1.0 - smoothstep(0.19, 0.22, ax);
	float arm = step(1.33, y) * smoothstep(0.17, 0.2, ax) * (1.0 - smoothstep(sleeve_x - 0.012, sleeve_x + 0.012, ax));
	float shirt = clamp(torso * (body_w + arm), 0.0, 1.0);
	float leg_end = max(pants_y, 0.0);
	float pants = (1.0 - smoothstep(shirt_bottom - 0.01, shirt_bottom + 0.01, y)) * smoothstep(leg_end - 0.01, leg_end + 0.01, y) * (1.0 - step(0.3, ax));
	float shoe = (1.0 - smoothstep(0.1, 0.13, y)) * (1.0 - step(0.3, ax));
	vec3 col = base * skin_tint;
	float shade = clamp(lum * 1.7, 0.45, 1.25);
	vec3 shirt_c = mix(shirt_col, shirt2_col, step(0.5, fract((y * 16.0))) * stripe);
	col = mix(col, shirt_c * shade, shirt);
	col = mix(col, pants_col * shade, pants);
	col = mix(col, shoe_col, shoe);
	ALBEDO = col;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	ROUGHNESS = mix(0.55, 0.88, max(shirt, pants));
	SPECULAR = 0.35;
}
