shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float wave(vec2 p) {
	float t = TIME;
	return noise(p * 0.35 + vec2(t * 0.5, t * 0.3)) * 0.6
		+ noise(p * 0.9 - vec2(t * 0.4, -t * 0.6)) * 0.3
		+ noise(p * 1.6 + vec2(t * 0.9, t * 0.5)) * 0.1;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float e = 0.15;
	float h0 = wave(p);
	float hx = wave(p + vec2(e, 0.0));
	float hz = wave(p + vec2(0.0, e));
	float dist = length(VERTEX);
	float ns = 2.2 / (1.0 + dist * 0.015);
	vec3 nw = normalize(vec3((h0 - hx) * ns, 1.0, (h0 - hz) * ns));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 vw = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vw.xyz /= vw.w;
	float thick = max(-vw.z + VERTEX.z, 0.0);

	float k = clamp(thick / 16.0, 0.0, 1.0);
	vec3 shallow = vec3(0.10, 0.44, 0.46);
	vec3 deep = vec3(0.012, 0.09, 0.19);
	ALBEDO = mix(shallow, deep, pow(k, 0.55));
	float foam = smoothstep(1.4, 0.0, thick) * (0.45 + 0.55 * noise(p * 3.0 + TIME * 0.8));
	ALBEDO = mix(ALBEDO, vec3(0.92), foam * 0.75);
	ROUGHNESS = mix(mix(0.04, 0.22, clamp(dist / 700.0, 0.0, 1.0)), 0.5, foam);
	SPECULAR = 0.75;
	METALLIC = 0.0;
	ALPHA = clamp(0.5 + k * 0.45 + foam, 0.0, 1.0);
}
