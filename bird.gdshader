shader_type spatial;
render_mode cull_disabled;

varying float part;
varying float mat_id;
varying float species;
varying float tip;

void vertex() {
	part = floor(COLOR.r * 16.0 + 0.5);
	mat_id = floor(COLOR.g * 8.0 + 0.5);
	tip = COLOR.b;
	species = INSTANCE_CUSTOM.x;
	float flap = INSTANCE_CUSTOM.y;
	float ph = TIME * (7.0 + species * 0.6) + float(INSTANCE_ID) * 1.7;
	float a = (sin(ph) * 0.75 * flap + 0.12 + (1.0 - flap) * 0.08);
	float b = sin(ph - 0.9) * 0.55 * flap;
	vec3 p = VERTEX;
	vec3 nr = NORMAL;
	if (part == 1.0 || part == 2.0) {
		vec3 piv = vec3(-0.06, 0.0, 0.0);
		float ang = -a;
		if (part == 2.0) {
			vec3 el = vec3(-0.35, 0.0, 0.0);
			float c2 = cos(-b);
			float s2 = sin(-b);
			vec3 q = p - el;
			p = el + vec3(q.x * c2 - q.y * s2, q.x * s2 + q.y * c2, q.z);
		}
		float c = cos(ang);
		float s = sin(ang);
		vec3 q2 = p - piv;
		p = piv + vec3(q2.x * c - q2.y * s, q2.x * s + q2.y * c, q2.z);
		nr = vec3(nr.x * c - nr.y * s, nr.x * s + nr.y * c, nr.z);
	} else if (part == 3.0 || part == 4.0) {
		vec3 piv = vec3(0.06, 0.0, 0.0);
		float ang = a;
		if (part == 4.0) {
			vec3 el = vec3(0.35, 0.0, 0.0);
			float c2 = cos(b);
			float s2 = sin(b);
			vec3 q = p - el;
			p = el + vec3(q.x * c2 - q.y * s2, q.x * s2 + q.y * c2, q.z);
		}
		float c = cos(ang);
		float s = sin(ang);
		vec3 q2 = p - piv;
		p = piv + vec3(q2.x * c - q2.y * s, q2.x * s + q2.y * c, q2.z);
		nr = vec3(nr.x * c - nr.y * s, nr.x * s + nr.y * c, nr.z);
	}
	p.y += sin(ph) * 0.012 * flap;
	VERTEX = p;
	NORMAL = nr;
}

void fragment() {
	vec3 body = vec3(0.45, 0.47, 0.52);
	vec3 wing = vec3(0.36, 0.38, 0.43);
	if (species > 2.5) { body = vec3(0.36, 0.22, 0.12); wing = vec3(0.3, 0.18, 0.1); }
	else if (species > 1.5) { body = vec3(0.04, 0.04, 0.06); wing = vec3(0.03, 0.03, 0.05); }
	else if (species > 0.5) { body = vec3(0.93, 0.93, 0.92); wing = vec3(0.78, 0.8, 0.84); }
	vec3 col = body;
	if (mat_id > 3.5) col = vec3(0.02);
	else if (mat_id > 2.5) col = vec3(0.92, 0.7, 0.15);
	else if (mat_id > 1.5) col = vec3(0.92, 0.7, 0.15);
	else if (mat_id > 0.5) col = wing;
	if (mat_id > 0.5 && mat_id < 1.5 && tip > 0.5) col = vec3(0.05);
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
