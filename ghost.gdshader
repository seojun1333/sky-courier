shader_type spatial;
render_mode blend_mix, cull_back;

uniform float alpha = 0.85;

void vertex() {
	VERTEX.x += sin(TIME * 2.0 + VERTEX.y * 4.0) * 0.05 * VERTEX.y;
	VERTEX.z += cos(TIME * 1.7 + VERTEX.y * 3.0) * 0.035 * VERTEX.y;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	ALBEDO = vec3(0.82, 0.88, 0.95);
	EMISSION = vec3(0.5, 0.65, 0.8) * (0.4 + fres * 1.3);
	ALPHA = clamp(alpha * (0.6 + 0.4 * fres) * (0.88 + 0.12 * sin(TIME * 41.0)), 0.0, 1.0);
}
