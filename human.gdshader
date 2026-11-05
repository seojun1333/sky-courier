shader_type spatial;

uniform vec3 skin_a = vec3(0.92, 0.74, 0.62);
uniform vec3 skin_b = vec3(0.78, 0.58, 0.44);
uniform vec3 skin_c = vec3(0.50, 0.34, 0.24);
uniform vec3 c_hair = vec3(0.08, 0.06, 0.05);
uniform vec3 c_top = vec3(0.3, 0.3, 0.5);
uniform vec3 c_bottom = vec3(0.15, 0.15, 0.2);
uniform vec3 c_shoes = vec3(0.05, 0.05, 0.05);
uniform vec3 c_accent = vec3(0.8, 0.8, 0.8);
uniform vec3 c_item = vec3(0.3, 0.2, 0.1);
uniform float swing = 0.7;
uniform float arm_swing = 0.6;
uniform float stride = 7.0;
uniform float lean = 0.0;
uniform float bob = 0.02;
uniform float vary = 0.0;

varying float part;
varying float mat_id;
varying float seed;

mat3 rotx(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

void vertex() {
	part = floor(COLOR.r * 16.0 + 0.5);
	mat_id = floor(COLOR.g * 8.0 + 0.5);
	float walk = INSTANCE_CUSTOM.x;
	seed = INSTANCE_CUSTOM.y;
	float spd = INSTANCE_CUSTOM.z;
	float ph = TIME * stride * spd + seed * 40.0;
	float s1 = sin(ph);
	vec3 p = VERTEX;
	vec3 nr = NORMAL;

	vec3 hipL = vec3(-0.09, 0.93, 0.0);
	vec3 hipR = vec3(0.09, 0.93, 0.0);
	vec3 kneeL = vec3(-0.09, 0.50, 0.0);
	vec3 kneeR = vec3(0.09, 0.50, 0.0);
	vec3 shL = vec3(-0.215, 1.41, 0.0);
	vec3 shR = vec3(0.215, 1.41, 0.0);
	vec3 elL = vec3(-0.215, 1.14, 0.0);
	vec3 elR = vec3(0.215, 1.14, 0.0);

	float aL = s1 * swing * walk;
	float aR = -aL;
	float kL = -max(0.0, sin(ph - 1.0)) * swing * 1.25 * walk;
	float kR = -max(0.0, sin(ph + 3.14159 - 1.0)) * swing * 1.25 * walk;
	float armL = -s1 * arm_swing * walk;
	float armR = -armL;
	float eL = (0.22 + max(0.0, armL) * 0.7) * walk;
	float eR = (0.22 + max(0.0, armR) * 0.7) * walk;

	if (part == 1.0) {
		mat3 R = rotx(aL);
		p = hipL + R * (p - hipL);
		nr = R * nr;
	} else if (part == 2.0) {
		mat3 Rk = rotx(kL);
		mat3 Rh = rotx(aL);
		p = kneeL + Rk * (p - kneeL);
		p = hipL + Rh * (p - hipL);
		nr = Rh * Rk * nr;
	} else if (part == 3.0) {
		mat3 R = rotx(aR);
		p = hipR + R * (p - hipR);
		nr = R * nr;
	} else if (part == 4.0) {
		mat3 Rk = rotx(kR);
		mat3 Rh = rotx(aR);
		p = kneeR + Rk * (p - kneeR);
		p = hipR + Rh * (p - hipR);
		nr = Rh * Rk * nr;
	} else if (part == 5.0) {
		mat3 R = rotx(armL);
		p = shL + R * (p - shL);
		nr = R * nr;
	} else if (part == 6.0) {
		mat3 Re = rotx(eL);
		mat3 Rs = rotx(armL);
		p = elL + Re * (p - elL);
		p = shL + Rs * (p - shL);
		nr = Rs * Re * nr;
	} else if (part == 7.0) {
		mat3 R = rotx(armR);
		p = shR + R * (p - shR);
		nr = R * nr;
	} else if (part == 8.0) {
		mat3 Re = rotx(eR);
		mat3 Rs = rotx(armR);
		p = elR + Re * (p - elR);
		p = shR + Rs * (p - shR);
		nr = Rs * Re * nr;
	}
	// 상체 기울기(조깅은 앞으로, 노인은 구부정)
	if (part != 1.0 && part != 2.0 && part != 3.0 && part != 4.0 && VERTEX.y > 0.88) {
		mat3 Rl = rotx(-lean);
		vec3 hc = vec3(0.0, 0.93, 0.0);
		p = hc + Rl * (p - hc);
		nr = Rl * nr;
	}
	p.y += abs(s1) * bob * walk;
	VERTEX = p;
	NORMAL = nr;
}

void fragment() {
	vec3 skin = mix(mix(skin_a, skin_b, step(0.33, seed)), skin_c, step(0.66, seed));
	float v1 = 0.85 + 0.3 * fract(seed * 7.13);
	vec3 top = mix(c_top, c_top.gbr, clamp(seed * vary, 0.0, 1.0)) * v1;
	vec3 col = skin;
	float rough = 0.7;
	if (mat_id > 6.5) { col = vec3(0.02); rough = 0.4; }
	else if (mat_id > 5.5) { col = c_item; rough = 0.55; }
	else if (mat_id > 4.5) { col = c_accent; }
	else if (mat_id > 3.5) { col = c_shoes; rough = 0.5; }
	else if (mat_id > 2.5) { col = c_bottom * (0.9 + 0.2 * fract(seed * 3.7)); rough = 0.9; }
	else if (mat_id > 1.5) { col = top; rough = 0.92; }
	else if (mat_id > 0.5) { col = c_hair * (0.8 + 0.4 * fract(seed * 11.7)); rough = 0.5; }
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
