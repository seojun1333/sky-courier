shader_type spatial;

uniform float stride = 9.0;

varying float part;
varying float mat_id;
varying float seed;

mat3 rotx(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}
mat3 roty(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

void vertex() {
	part = floor(COLOR.r * 16.0 + 0.5);
	mat_id = floor(COLOR.g * 8.0 + 0.5);
	float walk = INSTANCE_CUSTOM.x;
	seed = INSTANCE_CUSTOM.y;
	float ph = TIME * stride + seed * 30.0;
	float s1 = sin(ph) * 0.7 * walk;
	vec3 p = VERTEX;
	vec3 nr = NORMAL;
	vec3 piv = vec3(0.0, 0.31, 0.0);
	if (part == 1.0 || part == 4.0) {
		piv = vec3(part == 1.0 ? -0.07 : 0.07, 0.31, part == 1.0 ? -0.2 : 0.2);
		mat3 R = rotx(s1);
		p = piv + R * (p - piv);
		nr = R * nr;
	} else if (part == 2.0 || part == 3.0) {
		piv = vec3(part == 2.0 ? 0.07 : -0.07, 0.31, part == 2.0 ? -0.2 : 0.2);
		mat3 R = rotx(-s1);
		p = piv + R * (p - piv);
		nr = R * nr;
	} else if (part == 5.0) {
		vec3 tb = vec3(0.0, 0.5, 0.3);
		mat3 R = roty(sin(TIME * 11.0 + seed * 9.0) * 0.6);
		p = tb + R * (p - tb);
		nr = R * nr;
	} else if (part == 6.0) {
		p.y += sin(ph * 2.0) * 0.012 * walk;
	}
	p.y += abs(sin(ph)) * 0.015 * walk;
	VERTEX = p;
	NORMAL = nr;
}

void fragment() {
	vec3 fur = vec3(0.55, 0.38, 0.2);
	float r = fract(seed * 5.31);
	if (r < 0.25) fur = vec3(0.08, 0.07, 0.07);
	else if (r < 0.5) fur = vec3(0.85, 0.82, 0.75);
	else if (r < 0.75) fur = vec3(0.7, 0.5, 0.25);
	vec3 col = fur;
	if (mat_id > 6.5) col = vec3(0.03);
	else if (mat_id > 4.5) col = vec3(0.8, 0.1, 0.1);
	ALBEDO = col;
	ROUGHNESS = 0.8;
}
