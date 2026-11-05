extends RefCounted
## 시골 농가와 화성 지형 장식(바위, 버려진 기지).

const MB := preload("res://mb.gd")

var terrain: Node3D
var buildings: Node3D
var kind := "farm"
var mat: StandardMaterial3D
var rock_mesh: Mesh


func _init(k: String) -> void:
	kind = k
	mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	if kind == "mars":
		var sp := SphereMesh.new()
		sp.radius = 1.0
		sp.height = 1.6
		sp.radial_segments = 7
		sp.rings = 4
		rock_mesh = sp
		var rm := StandardMaterial3D.new()
		rm.vertex_color_use_as_albedo = true
		rm.albedo_color = Color(1, 1, 1)
		rm.roughness = 1.0
		sp.material = rm


func on_free(c: Vector2i) -> void:
	if buildings != null:
		buildings.remove_solid(c)


func decorate(c: Vector2i, ring: int) -> Node3D:
	if kind == "farm":
		return _farm(c, ring)
	return _mars(c, ring)


# ---------- 농장 ----------
func _farm(c: Vector2i, ring: int) -> Node3D:
	if ring > 7:
		return null
	var rs := RandomNumberGenerator.new()
	rs.seed = hash(Vector2i(c.x * 5273 + 1, c.y * 80009 + 4))
	if rs.randf() > 0.2:
		return null
	var ox := c.x * 160.0
	var oz := c.y * 160.0
	var cx := ox + rs.randf_range(40.0, 120.0)
	var cz := oz + rs.randf_range(40.0, 120.0)
	if Vector2(cx, cz).distance_to(terrain.home_xz) < 100.0:
		return null
	var lo := INF
	var hi := -INF
	for k in 9:
		var hh: float = terrain.height(cx + (k % 3 - 1) * 18.0, cz + (k / 3 - 1) * 18.0)
		lo = minf(lo, hh)
		hi = maxf(hi, hh)
	if lo < 3.0 or hi - lo > 6.0:
		return null
	var base := hi
	var b := MB.new()
	var boxes: Array = []
	var yaw := rs.randi_range(0, 3) * PI / 2.0
	var rot := Basis(Vector3.UP, yaw)
	# 로컬 좌표(원점은 농가 중심)에서 만들고 마지막에 회전
	var parts: Array = []   # [kind, mn, mx, color, extra]
	var red := Color(0.55, 0.14, 0.10)
	var white := Color(0.88, 0.86, 0.80)
	var roofc := Color(0.28, 0.24, 0.22)
	parts.append(["box", Vector3(-12, -1.5, -8), Vector3(2, 6.5, 8), red, 0.0])                    # 헛간
	parts.append(["gable", Vector3(-12.6, 6.5, -8.6), Vector3(2.6, 6.5, 8.6), roofc, 4.5])
	parts.append(["box", Vector3(8, -1.5, -5), Vector3(17, 3.6, 4), white, 0.0])                   # 농가
	parts.append(["gableX", Vector3(7.5, 3.6, -5.6), Vector3(17.5, 3.6, 4.6), Color(0.45, 0.2, 0.15), 2.6])
	parts.append(["box", Vector3(-3, -1.5, 11), Vector3(3, 2.8, 16), Color(0.5, 0.42, 0.3), 0.0])  # 창고
	var mesh_parts := MB.new()
	for p in parts:
		var mn: Vector3 = rot * p[1]
		var mx: Vector3 = rot * p[2]
		var lo2 := mn.min(mx)
		var hi2 := mx.max(mn)
		if p[0] == "box":
			mesh_parts.box(lo2, hi2, p[3])
			boxes.append({"min": Vector3(cx, base, cz) + lo2, "max": Vector3(cx, base, cz) + hi2})
		else:
			var along_x: bool = (p[0] == "gableX")
			if absf(yaw - PI / 2.0) < 0.1 or absf(yaw - 3.0 * PI / 2.0) < 0.1:
				along_x = not along_x
			mesh_parts.gable(lo2, hi2, p[4], along_x, p[3])
	# 사일로 두 개
	for sx in [-1.0, 1.0]:
		var sp: Vector3 = rot * Vector3(5.0, -1.5, 12.0 + sx * 4.0)
		mesh_parts.cylinder(sp, 2.4, 14.0, 12, Color(0.72, 0.74, 0.76))
		mesh_parts.cylinder(sp + Vector3(0, 14.0, 0), 2.4, 2.2, 12, Color(0.6, 0.62, 0.66), 0.2, true)
		boxes.append({"min": Vector3(cx, base, cz) + sp + Vector3(-2.4, 1.5, -2.4), "max": Vector3(cx, base, cz) + sp + Vector3(2.4, 16.0, 2.4)})
	# 건초 더미
	for i in 6:
		var hp: Vector3 = rot * Vector3(rs.randf_range(-16.0, -4.0), -1.4, rs.randf_range(-14.0, -10.0))
		mesh_parts.cylinder(hp, 1.0, 1.3, 10, Color(0.8, 0.68, 0.3))
	# 울타리
	for i in 18:
		var fp: Vector3 = rot * Vector3(-18.0 + i * 2.2, -1.5, 20.0)
		mesh_parts.box(fp + Vector3(-0.08, 0, -0.08), fp + Vector3(0.08, 1.3, 0.08), Color(0.4, 0.3, 0.2))
	mesh_parts.box(rot * Vector3(-18.0, -0.7, 19.95) + Vector3(0, 0, 0), rot * Vector3(20.6, -0.55, 20.05), Color(0.45, 0.35, 0.25))
	var node := Node3D.new()
	node.position = Vector3(cx, base, cz)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_parts.build()
	mi.material_override = mat
	node.add_child(mi)
	if buildings != null:
		buildings.add_solid(c, boxes)
	return node


# ---------- 화성 ----------
func _mars(c: Vector2i, ring: int) -> Node3D:
	if ring > 6:
		return null
	var rs := RandomNumberGenerator.new()
	rs.seed = hash(Vector2i(c.x * 6151 + 3, c.y * 70001 + 8))
	var ox := c.x * 160.0
	var oz := c.y * 160.0
	var node := Node3D.new()

	# 바위
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	for i in rs.randi_range(18, 40):
		var x := ox + rs.randf() * 160.0
		var z := oz + rs.randf() * 160.0
		var h: float = terrain.height(x, z)
		var s := rs.randf_range(0.5, 2.6) * (3.0 if rs.randf() < 0.05 else 1.0)
		var bs := Basis(Vector3.UP, rs.randf() * TAU).scaled(Vector3(s * rs.randf_range(0.8, 1.4), s * rs.randf_range(0.5, 1.0), s * rs.randf_range(0.8, 1.4)))
		xf.append(Transform3D(bs, Vector3(x, h + s * 0.1, z)))
		var g := rs.randf_range(0.18, 0.42)
		cols.append(Color(g * 1.3, g * 0.75, g * 0.55))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = rock_mesh
	mm.instance_count = xf.size()
	for k in xf.size():
		mm.set_instance_transform(k, xf[k])
		mm.set_instance_color(k, cols[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ring <= 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mmi)

	# 버려진 기지
	if rs.randf() < 0.08 or (c == Vector2i(0, 0)):
		var cx := ox + rs.randf_range(50.0, 110.0)
		var cz := oz + rs.randf_range(50.0, 110.0)
		if c == Vector2i(0, 0):
			cx = 105.0
			cz = 20.0
		var lo := INF
		var hi := -INF
		for k in 9:
			var hh: float = terrain.height(cx + (k % 3 - 1) * 12.0, cz + (k / 3 - 1) * 12.0)
			lo = minf(lo, hh)
			hi = maxf(hi, hh)
		if hi - lo < 6.0 and lo > 6.0:
			node.add_child(_base(cx, hi, cz, rs, c))
	return node


func _base(cx: float, base: float, cz: float, rs: RandomNumberGenerator, c: Vector2i) -> Node3D:
	var b := MB.new()
	var boxes: Array = []
	var white := Color(0.82, 0.82, 0.84)
	var orange := Color(0.9, 0.45, 0.12)
	var dark := Color(0.2, 0.21, 0.24)
	# 거주 모듈 둥근 지붕 두 개와 연결 통로
	for k in 2:
		var p := Vector3(-8.0 + k * 16.0, -2.0, 0.0)
		b.cylinder(p, 6.0, 4.4, 16, white)
		b.cylinder(p + Vector3(0, 4.4, 0), 6.0, 2.6, 16, white, 3.2, true)
		b.cylinder(p + Vector3(0, 4.4, 0), 6.05, 0.5, 16, orange)
		b.cylinder(p + Vector3(0, 7.0, 0), 3.2, 1.6, 12, white, 0.3, true)
		boxes.append({"min": Vector3(cx, base, cz) + p + Vector3(-6, 2.0, -6), "max": Vector3(cx, base, cz) + p + Vector3(6, 8.5, 6)})
	b.box(Vector3(-2.0, -0.5, -1.6), Vector3(10.0, 2.4, 1.6), Color(0.7, 0.7, 0.72))
	# 태양광 패널
	for i in 6:
		var px := -14.0 + i * 5.0
		b.box(Vector3(px, 1.6, 10.0), Vector3(px + 4.0, 1.75, 14.0), Color(0.08, 0.12, 0.3))
		b.box(Vector3(px + 1.9, -1.5, 11.9), Vector3(px + 2.1, 1.6, 12.1), dark)
	# 안테나 접시
	b.cylinder(Vector3(18.0, -2.0, -8.0), 0.3, 6.0, 6, dark)
	b.cylinder(Vector3(18.0, 4.0, -8.0), 0.2, 0.8, 12, white, 2.2, false)
	# 로버(바퀴 6개)
	b.box(Vector3(-14.0, 0.0, -12.0), Vector3(-10.0, 1.4, -9.0), Color(0.75, 0.72, 0.65))
	for i in 3:
		for sz in [-1.0, 1.0]:
			b.cylinder(Vector3(-13.4 + i * 1.5, 0.4, -10.5 + sz * 1.7), 0.5, 0.3, 8, dark)
	var node := Node3D.new()
	node.position = Vector3(cx, base, cz)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	mi.material_override = mat
	node.add_child(mi)
	if buildings != null:
		buildings.add_solid(c, boxes)
	return node
