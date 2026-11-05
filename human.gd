extends RefCounted
## 사람 13종과 강아지의 모델·재질. 정점 색: r = 부위(걷기 애니메이션), g = 재질(피부/머리/상의/하의/신발/포인트/소지품/검정).

const MB := preload("res://mb.gd")

static func C(part: int, m: int) -> Color:
	return Color(part / 16.0, m / 8.0, 1.0, 1.0)


static func types() -> Array:
	return [
		{"id": "office_m", "name": "회사원", "height": 1.78, "hair_style": "short", "hair": Color(0.07, 0.05, 0.04), "top": Color(0.12, 0.14, 0.24),
			"bottom": Color(0.11, 0.13, 0.22), "shoes": Color(0.05, 0.04, 0.04), "accent": Color(0.12, 0.14, 0.24), "item": Color(0.25, 0.15, 0.08),
			"jacket": true, "tie": true, "items": ["briefcase"], "speed": 1.5, "stride": 8.0, "swing": 0.7, "arm": 0.45, "lean": 0.04, "vary": 0.4},
		{"id": "office_f", "name": "직장인(여)", "female": true, "height": 1.65, "hair_style": "bun", "hair": Color(0.1, 0.07, 0.05), "top": Color(0.92, 0.92, 0.95),
			"bottom": Color(0.1, 0.1, 0.13), "shoes": Color(0.08, 0.05, 0.05), "accent": Color(0.1, 0.1, 0.13), "item": Color(0.55, 0.1, 0.15),
			"skirt": 1, "items": ["handbag"], "speed": 1.4, "stride": 8.5, "swing": 0.55, "arm": 0.4, "lean": 0.02, "vary": 0.3},
		{"id": "kid", "name": "어린이", "height": 1.1, "hair_style": "short", "hair": Color(0.1, 0.07, 0.05), "top": Color(0.9, 0.3, 0.2),
			"bottom": Color(0.2, 0.3, 0.55), "shoes": Color(0.9, 0.9, 0.9), "accent": Color(0.9, 0.8, 0.2), "item": Color(0.15, 0.45, 0.85),
			"items": ["backpack"], "speed": 1.2, "stride": 11.0, "swing": 0.9, "arm": 0.8, "lean": 0.03, "bob": 0.035, "vary": 1.0},
		{"id": "club_f", "name": "클럽 가는 여자", "female": true, "height": 1.7, "hair_style": "long", "hair": Color(0.08, 0.05, 0.06), "top": Color(0.9, 0.08, 0.45),
			"bottom": Color(0.9, 0.08, 0.45), "shoes": Color(0.85, 0.8, 0.85), "accent": Color(0.9, 0.8, 0.3), "item": Color(0.05, 0.05, 0.07),
			"skirt": 2, "sleeveless": true, "items": ["clutch"], "speed": 1.3, "stride": 8.0, "swing": 0.5, "arm": 0.35, "lean": 0.0, "vary": 0.6},
		{"id": "dogwalker", "name": "강아지 산책", "height": 1.72, "hair_style": "ponytail", "hair": Color(0.3, 0.2, 0.1), "top": Color(0.2, 0.4, 0.3),
			"bottom": Color(0.2, 0.3, 0.5), "shoes": Color(0.9, 0.9, 0.88), "accent": Color(0.8, 0.2, 0.2), "item": Color(0.8, 0.2, 0.2),
			"dog": true, "speed": 1.2, "stride": 7.5, "swing": 0.6, "arm": 0.5, "lean": 0.03, "vary": 0.8},
		{"id": "jogger", "name": "조깅하는 사람", "height": 1.74, "hair_style": "ponytail", "hair": Color(0.15, 0.1, 0.07), "top": Color(0.1, 0.75, 0.85),
			"bottom": Color(0.08, 0.08, 0.1), "shoes": Color(0.95, 0.4, 0.1), "accent": Color(0.95, 0.4, 0.1), "item": Color(0.1, 0.1, 0.1),
			"shorts": true, "sleeveless": true, "speed": 3.0, "stride": 12.5, "swing": 1.0, "arm": 0.95, "lean": 0.18, "bob": 0.05, "vary": 1.0},
		{"id": "elder", "name": "노인", "height": 1.64, "hair_style": "short", "hair": Color(0.72, 0.72, 0.74), "top": Color(0.42, 0.32, 0.26),
			"bottom": Color(0.26, 0.26, 0.3), "shoes": Color(0.15, 0.1, 0.08), "accent": Color(0.3, 0.2, 0.15), "item": Color(0.35, 0.22, 0.1),
			"items": ["cane"], "speed": 0.8, "stride": 5.0, "swing": 0.35, "arm": 0.25, "lean": 0.25, "bob": 0.01, "vary": 0.5},
		{"id": "courier", "name": "배달원", "height": 1.74, "hair_style": "none", "hair": Color(0.1, 0.07, 0.05), "top": Color(0.1, 0.1, 0.12),
			"bottom": Color(0.14, 0.14, 0.18), "shoes": Color(0.08, 0.08, 0.08), "accent": Color(1.0, 0.5, 0.05), "item": Color(1.0, 0.5, 0.05),
			"hat": "helmet", "vest": true, "items": ["deliverybox"], "speed": 1.9, "stride": 9.0, "swing": 0.75, "arm": 0.5, "lean": 0.07, "vary": 0.0},
		{"id": "police", "name": "경찰", "height": 1.80, "hair_style": "none", "hair": Color(0.08, 0.06, 0.05), "top": Color(0.1, 0.15, 0.3),
			"bottom": Color(0.08, 0.11, 0.22), "shoes": Color(0.04, 0.04, 0.05), "accent": Color(0.85, 0.75, 0.2), "item": Color(0.05, 0.05, 0.07),
			"hat": "police", "belt": true, "items": [], "speed": 1.4, "stride": 8.0, "swing": 0.65, "arm": 0.4, "lean": 0.0, "vary": 0.0},
		{"id": "student", "name": "학생", "female": true, "height": 1.6, "hair_style": "ponytail", "hair": Color(0.08, 0.06, 0.05), "top": Color(0.92, 0.92, 0.94),
			"bottom": Color(0.2, 0.22, 0.42), "shoes": Color(0.95, 0.95, 0.95), "accent": Color(0.7, 0.1, 0.15), "item": Color(0.1, 0.12, 0.3),
			"skirt": 1, "tie": true, "items": ["backpack"], "speed": 1.4, "stride": 9.0, "swing": 0.6, "arm": 0.5, "lean": 0.03, "vary": 0.2},
		{"id": "tourist", "name": "관광객", "height": 1.75, "hair_style": "short", "hair": Color(0.3, 0.2, 0.1), "top": Color(0.95, 0.55, 0.2),
			"bottom": Color(0.7, 0.6, 0.4), "shoes": Color(0.6, 0.45, 0.3), "accent": Color(0.2, 0.2, 0.22), "item": Color(0.15, 0.4, 0.3),
			"hat": "straw", "shorts": true, "items": ["backpack", "camera"], "speed": 1.1, "stride": 7.0, "swing": 0.6, "arm": 0.5, "lean": 0.03, "vary": 1.0},
		{"id": "farmer", "name": "농부", "height": 1.74, "hair_style": "short", "hair": Color(0.25, 0.18, 0.1), "top": Color(0.7, 0.2, 0.15),
			"bottom": Color(0.2, 0.3, 0.5), "shoes": Color(0.28, 0.18, 0.1), "accent": Color(0.2, 0.3, 0.5), "item": Color(0.85, 0.72, 0.35),
			"hat": "straw", "items": [], "speed": 1.1, "stride": 7.0, "swing": 0.6, "arm": 0.5, "lean": 0.06, "vary": 0.4},
		{"id": "worker", "name": "공사 인부", "height": 1.76, "hair_style": "none", "hair": Color(0.1, 0.07, 0.05), "top": Color(0.9, 0.9, 0.88),
			"bottom": Color(0.3, 0.3, 0.34), "shoes": Color(0.25, 0.18, 0.1), "accent": Color(1.0, 0.45, 0.05), "item": Color(1.0, 0.85, 0.1),
			"hat": "hardhat", "vest": true, "items": [], "speed": 1.3, "stride": 7.5, "swing": 0.65, "arm": 0.5, "lean": 0.05, "vary": 0.0},
	]


static func type_by_id(id: String) -> Dictionary:
	for t in types():
		if t.id == id:
			return t
	return types()[0]


static func make_material(t: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://human.gdshader")
	var cv := func(c: Color) -> Vector3: return Vector3(c.r, c.g, c.b)
	m.set_shader_parameter("c_hair", cv.call(t.hair))
	m.set_shader_parameter("c_top", cv.call(t.top))
	m.set_shader_parameter("c_bottom", cv.call(t.bottom))
	m.set_shader_parameter("c_shoes", cv.call(t.shoes))
	m.set_shader_parameter("c_accent", cv.call(t.accent))
	m.set_shader_parameter("c_item", cv.call(t.item))
	m.set_shader_parameter("swing", t.get("swing", 0.7))
	m.set_shader_parameter("arm_swing", t.get("arm", 0.5))
	m.set_shader_parameter("stride", t.get("stride", 7.0))
	m.set_shader_parameter("lean", t.get("lean", 0.0))
	m.set_shader_parameter("bob", t.get("bob", 0.02))
	m.set_shader_parameter("vary", t.get("vary", 0.0))
	return m


static func build(t: Dictionary) -> ArrayMesh:
	var b := MB.new()
	var fem: bool = t.get("female", false)
	var skirt: int = t.get("skirt", 0)
	var shorts: bool = t.get("shorts", false)
	var sleeveless: bool = t.get("sleeveless", false)
	var lowskin := skirt > 0
	var hw := 0.09

	# 다리
	for side in [-1, 1]:
		var th := 1 if side < 0 else 3
		var sh := th + 1
		var x: float = side * hw
		if shorts:
			b.cylinder(Vector3(x, 0.68, 0), 0.085, 0.25, 8, C(th, 3), 0.1, false, Vector2(1.0, 1.05))
			b.cylinder(Vector3(x, 0.50, 0), 0.07, 0.18, 8, C(th, 0), 0.08, false)
		else:
			b.cylinder(Vector3(x, 0.50, 0), 0.075, 0.43, 8, C(th, 0 if lowskin else 3), 0.095, false, Vector2(1.0, 1.05))
		b.cylinder(Vector3(x, 0.09, 0), 0.052, 0.42, 8, C(sh, 0 if (lowskin or shorts) else 3), 0.068, false)
		b.box(Vector3(x - 0.045, 0.0, -0.17), Vector3(x + 0.045, 0.09, 0.07), C(sh, 4))

	# 골반과 몸통
	var hipc := 2 if skirt == 3 else 3
	b.cylinder(Vector3(0, 0.84, 0), 0.14, 0.13, 10, C(0, hipc), 0.15, false, Vector2(1.18 if fem else 1.12, 0.85))
	var shr := 0.17 if fem else 0.19
	b.cylinder(Vector3(0, 0.95, 0), 0.15, 0.47, 10, C(0, 2), shr, true, Vector2(1.1 if not fem else 1.0, 0.78))
	if fem:
		b.sphere(Vector3(-0.055, 1.28, -0.095), Vector3(0.06, 0.055, 0.05), 8, 5, C(0, 2))
		b.sphere(Vector3(0.055, 1.28, -0.095), Vector3(0.06, 0.055, 0.05), 8, 5, C(0, 2))
	if t.get("jacket", false):
		b.cylinder(Vector3(0, 0.76, 0), 0.165, 0.68, 10, C(0, 5), 0.2, true, Vector2(1.15, 0.85))
		b.box(Vector3(-0.05, 1.0, -0.158), Vector3(0.05, 1.38, -0.14), C(0, 2))   # 재킷 앞섶 안의 셔츠
	if t.get("vest", false):
		b.cylinder(Vector3(0, 0.96, 0), 0.158, 0.46, 10, C(0, 5), 0.196, true, Vector2(1.12, 0.8))
		b.box(Vector3(-0.19, 1.14, -0.17), Vector3(0.19, 1.2, 0.17), C(0, 4))
	if t.get("belt", false):
		b.cylinder(Vector3(0, 0.92, 0), 0.158, 0.05, 10, C(0, 7), -1.0, false, Vector2(1.12, 0.82))
		b.box(Vector3(0.03, 0.9, -0.15), Vector3(0.1, 1.02, -0.11), C(0, 5))
	if t.get("tie", false):
		b.box(Vector3(-0.02, 1.0, -0.16), Vector3(0.02, 1.36, -0.15), C(0, 5))
	# 치마/원피스
	if skirt == 1:
		b.cylinder(Vector3(0, 0.55, 0), 0.25, 0.4, 12, C(0, 3), 0.155, false, Vector2(1.1, 1.0))
	elif skirt == 2:
		b.cylinder(Vector3(0, 0.7, 0), 0.2, 0.25, 12, C(0, 3), 0.16, false, Vector2(1.1, 1.0))
	elif skirt == 3:
		b.cylinder(Vector3(0, 0.34, 0), 0.28, 0.62, 12, C(0, 3), 0.16, false)

	# 목, 머리, 얼굴
	b.cylinder(Vector3(0, 1.42, 0), 0.05, 0.08, 8, C(0, 0), -1.0, false)
	b.sphere(Vector3(0, 1.64, 0), Vector3(0.1, 0.12, 0.11), 12, 8, C(0, 0))
	b.sphere(Vector3(-0.04, 1.65, -0.098), Vector3(0.013, 0.013, 0.01), 5, 3, C(0, 7))
	b.sphere(Vector3(0.04, 1.65, -0.098), Vector3(0.013, 0.013, 0.01), 5, 3, C(0, 7))
	b.box(Vector3(-0.012, 1.62, -0.118), Vector3(0.012, 1.635, -0.105), C(0, 0))
	var hs: String = t.get("hair_style", "short")
	if hs != "none":
		b.sphere(Vector3(0, 1.675, 0.012), Vector3(0.108, 0.1, 0.115), 12, 6, C(0, 1))
		if hs == "long":
			b.cylinder(Vector3(0, 1.26, 0.06), 0.09, 0.44, 10, C(0, 1), 0.115, false, Vector2(1.15, 0.6))
		elif hs == "ponytail":
			b.cylinder(Vector3(0, 1.42, 0.13), 0.028, 0.24, 8, C(0, 1), 0.045, true)
		elif hs == "bun":
			b.sphere(Vector3(0, 1.79, 0.07), Vector3(0.055, 0.055, 0.055), 8, 5, C(0, 1))
	var hat: String = t.get("hat", "")
	if hat == "straw":
		b.cylinder(Vector3(0, 1.72, 0), 0.24, 0.016, 14, C(0, 6), -1.0, true)
		b.cylinder(Vector3(0, 1.73, 0), 0.115, 0.07, 12, C(0, 6), 0.1, true)
	elif hat == "helmet":
		b.sphere(Vector3(0, 1.69, 0.005), Vector3(0.125, 0.115, 0.13), 12, 7, C(0, 5))
		b.box(Vector3(-0.09, 1.665, -0.14), Vector3(0.09, 1.69, -0.105), C(0, 7))
	elif hat == "hardhat":
		b.sphere(Vector3(0, 1.7, 0.0), Vector3(0.125, 0.105, 0.13), 12, 7, C(0, 6))
		b.box(Vector3(-0.1, 1.69, -0.19), Vector3(0.1, 1.705, -0.1), C(0, 6))
	elif hat == "police":
		b.cylinder(Vector3(0, 1.72, 0), 0.125, 0.055, 12, C(0, 7), 0.115, true)
		b.box(Vector3(-0.1, 1.715, -0.19), Vector3(0.1, 1.73, -0.1), C(0, 7))
		b.box(Vector3(-0.02, 1.74, -0.128), Vector3(0.02, 1.765, -0.118), C(0, 5))

	# 팔
	for side in [-1, 1]:
		var up := 5 if side < 0 else 7
		var fo := up + 1
		var x: float = side * 0.215
		var sleeve := 0 if sleeveless else 2
		b.sphere(Vector3(x * 0.95, 1.41, 0), Vector3(0.06, 0.06, 0.06), 8, 5, C(up, sleeve))
		b.cylinder(Vector3(x, 1.14, 0), 0.042, 0.28, 8, C(up, sleeve), 0.052, false)
		var long_s: bool = not sleeveless and not t.get("shorts", false)
		b.cylinder(Vector3(x, 0.87, 0), 0.034, 0.28, 8, C(fo, 2 if long_s else 0), 0.042, false)
		b.sphere(Vector3(x, 0.85, 0), Vector3(0.036, 0.045, 0.036), 8, 5, C(fo, 0))

	# 소지품
	var items: Array = t.get("items", [])
	if items.has("briefcase"):
		b.box(Vector3(0.2, 0.52, -0.2), Vector3(0.245, 0.84, 0.2), C(8, 6))
	if items.has("handbag"):
		b.box(Vector3(-0.255, 0.62, -0.13), Vector3(-0.19, 0.84, 0.13), C(6, 6))
	if items.has("clutch"):
		b.box(Vector3(-0.25, 0.72, -0.08), Vector3(-0.2, 0.86, 0.08), C(6, 6))
	if items.has("backpack"):
		b.box(Vector3(-0.15, 1.02, 0.09), Vector3(0.15, 1.42, 0.27), C(0, 6))
		b.box(Vector3(-0.13, 1.02, 0.27), Vector3(0.13, 1.2, 0.3), C(0, 6))
	if items.has("deliverybox"):
		b.box(Vector3(-0.26, 0.98, 0.1), Vector3(0.26, 1.5, 0.52), C(0, 5))
		b.box(Vector3(-0.26, 1.24, 0.5), Vector3(0.26, 1.28, 0.53), C(0, 7))
	if items.has("cane"):
		b.cylinder(Vector3(0.29, 0.0, -0.05), 0.013, 0.86, 6, C(8, 6))
	if items.has("camera"):
		b.box(Vector3(-0.07, 1.14, -0.2), Vector3(0.07, 1.25, -0.14), C(0, 7))

	var mesh := b.build()
	return mesh


static func dog_part(b: Object, mn: Vector3, mx: Vector3, part: int, m: int) -> void:
	b.box(mn, mx, C(part, m))


static func build_dog() -> ArrayMesh:
	var b := MB.new()
	dog_part(b, Vector3(-0.11, 0.30, -0.28), Vector3(0.11, 0.58, 0.30), 0, 0)
	dog_part(b, Vector3(-0.075, 0.50, -0.42), Vector3(0.075, 0.69, -0.26), 6, 0)
	dog_part(b, Vector3(-0.04, 0.52, -0.53), Vector3(0.04, 0.61, -0.42), 6, 0)
	dog_part(b, Vector3(-0.022, 0.585, -0.54), Vector3(0.022, 0.62, -0.5), 6, 7)
	for sx in [-1.0, 1.0]:
		dog_part(b, Vector3(sx * 0.075 - 0.025, 0.67, -0.37), Vector3(sx * 0.075 + 0.025, 0.77, -0.31), 6, 7)
		dog_part(b, Vector3(sx * 0.04 - 0.012, 0.63, -0.425), Vector3(sx * 0.04 + 0.012, 0.65, -0.415), 6, 7)
	dog_part(b, Vector3(-0.085, 0.5, -0.285), Vector3(0.085, 0.55, -0.245), 0, 5)
	var legs := [[-0.07, -0.2, 1], [0.07, -0.2, 2], [-0.07, 0.2, 3], [0.07, 0.2, 4]]
	for lg in legs:
		dog_part(b, Vector3(lg[0] - 0.03, 0.0, lg[1] - 0.03), Vector3(lg[0] + 0.03, 0.31, lg[1] + 0.03), lg[2], 0)
		dog_part(b, Vector3(lg[0] - 0.035, 0.0, lg[1] - 0.05), Vector3(lg[0] + 0.035, 0.04, lg[1] + 0.03), lg[2], 7)
	dog_part(b, Vector3(-0.02, 0.5, 0.29), Vector3(0.02, 0.66, 0.33), 5, 0)
	return b.build()


static func make_dog_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://dog.gdshader")
	return m
