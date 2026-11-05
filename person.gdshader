shader_type spatial;

varying float vy;
varying float vid;

float hash(float n) { return fract(sin(n * 91.3458) * 47453.5453); }

void vertex() {
	vid = float(INSTANCE_ID);
	vy = VERTEX.y;
	float walk = INSTANCE_CUSTOM.x;
	float ph = TIME * 7.5 + vid * 2.3;
	float y = VERTEX.y;
	if (y < 0.86) {
		VERTEX.z += sin(ph) * sign(VERTEX.x) * 0.45 * walk * (0.86 - y) / 0.86;
	} else if (y < 1.46 && abs(VERTEX.x) > 0.215) {
		VERTEX.z += -sin(ph) * sign(VERTEX.x) * 0.4 * walk * (1.46 - y);
	}
}

void fragment() {
	vec3 pants = mix(vec3(0.12, 0.14, 0.25), vec3(0.26, 0.2, 0.12), step(0.5, hash(vid + 3.0)));
	vec3 shirt = vec3(hash(vid), hash(vid + 7.0), hash(vid + 13.0)) * 0.7 + 0.15;
	vec3 skin = vec3(0.80, 0.62, 0.50);
	vec3 hair = vec3(0.09, 0.07, 0.05);
	vec3 col = vy < 0.85 ? pants : (vy < 1.46 ? shirt : (vy > 1.66 ? hair : skin));
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
