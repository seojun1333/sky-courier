extends Node3D
## 무한에 가까운 절차적 지형. 월드 종류(alpine/farm/city/mars)에 따라 높이·재질·장식이 달라진다.

const CHUNK := 160.0

var profile := {}
var kind := "alpine"
var radius := 11
var home_xz := Vector2.ZERO
var decorator: Object = null    # decorate(c, ring) -> Node3D, block_info(c) -> Color

var n_base := FastNoiseLite.new()
var n_ridge := FastNoiseLite.new()
var n_mask := FastNoiseLite.new()
var n_detail := FastNoiseLite.new()
var n_forest := FastNoiseLite.new()
var n_crater := FastNoiseLite.new()
var n_canyon := FastNoiseLite.new()

var chunks := {}          # Vector2i -> {mi, mm, deco, res}
var want_res := {}
var queue: Array = []
var last_center := Vector2i(1 << 30, 1 << 30)
var terrain_mat: ShaderMaterial
var water: MeshInstance3D
var tree_mesh: ArrayMesh
var spawn_h := 18.0


func _init() -> void:
	_cfg(n_base, 1337, 0.0011, FastNoiseLite.FRACTAL_FBM, 5)
	_cfg(n_ridge, 77, 0.0016, FastNoiseLite.FRACTAL_RIDGED, 5)
	_cfg(n_mask, 5, 0.0005, FastNoiseLite.FRACTAL_FBM, 2)
	_cfg(n_detail, 9, 0.025, FastNoiseLite.FRACTAL_FBM, 3)
	_cfg(n_forest, 21, 0.006, FastNoiseLite.FRACTAL_FBM, 3)
	_cfg(n_canyon, 303, 0.0009, FastNoiseLite.FRACTAL_RIDGED, 3)
	n_crater.noise_type = FastNoiseLite.TYPE_CELLULAR
	n_crater.seed = 55
	n_crater.frequency = 0.0021
	n_crater.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	n_crater.fractal_type = FastNoiseLite.FRACTAL_NONE


func _cfg(n: FastNoiseLite, s: int, freq: float, fractal: int, octaves: int) -> void:
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = s
	n.frequency = freq
	n.fractal_type = fractal
	n.fractal_octaves = octaves


func _ready() -> void:
	kind = profile.get("kind", "alpine")
	radius = profile.get("radius", 11)
	home_xz = profile.get("home", Vector2.ZERO)
	spawn_h = {"alpine": 18.0, "farm": 8.0, "city": 0.0, "mars": 30.0}[kind]
	var shader_path: String = {"alpine": "res://terrain.gdshader", "farm": "res://farm_ground.gdshader",
		"city": "res://city_ground.gdshader", "mars": "res://mars_ground.gdshader"}[kind]
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = load(shader_path)
	tree_mesh = _make_tree_mesh()

	water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(9000, 9000)
	water.mesh = pm
	var wm := ShaderMaterial.new()
	wm.shader = load("res://water.gdshader")
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.visible = profile.get("water", true)
	add_child(water)
	_make_pad()


func height(x: float, z: float) -> float:
	match kind:
		"city":
			return 0.0
		"farm":
			var b := n_base.get_noise_2d(x, z)
			var h := 8.0 + b * 26.0 + n_detail.get_noise_2d(x, z) * 1.2
			var mask := smoothstep(0.25, 0.55, n_mask.get_noise_2d(x, z))
			var r := clampf(n_ridge.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
			h = maxf(h + pow(r, 2.2) * mask * 150.0, 1.5)
			return lerpf(8.0, h, smoothstep(40.0, 220.0, Vector2(x, z).distance_to(home_xz)))
		"mars":
			var h := 40.0 + n_base.get_noise_2d(x, z) * 38.0 + sin(x * 0.02 + n_detail.get_noise_2d(x * 0.3, z * 0.3) * 6.0) * 2.5
			var cm := smoothstep(-0.25, 0.3, n_mask.get_noise_2d(x + 999.0, z))
			var d := clampf(n_crater.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
			h -= (1.0 - smoothstep(0.0, 0.3, d)) * 30.0 * cm
			h += smoothstep(0.28, 0.34, d) * (1.0 - smoothstep(0.34, 0.45, d)) * 7.0 * cm
			var can := 1.0 - smoothstep(0.0, 0.05, absf(n_canyon.get_noise_2d(x, z)))
			h -= can * 75.0 * smoothstep(0.0, 0.25, n_mask.get_noise_2d(x * 0.7, z * 0.7) + 0.2)
			h = maxf(h, 6.0)
			return lerpf(30.0, h, smoothstep(45.0, 240.0, Vector2(x, z).distance_to(home_xz)))
		_:
			var b := n_base.get_noise_2d(x, z)
			var mask := smoothstep(-0.15, 0.4, n_mask.get_noise_2d(x, z))
			var r := clampf(n_ridge.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
			var h := b * 85.0 + 14.0 + pow(r, 2.4) * mask * 480.0 + n_detail.get_noise_2d(x, z) * 3.0
			return lerpf(18.0, h, smoothstep(45.0, 240.0, Vector2(x, z).distance_to(home_xz)))


func ground(x: float, z: float) -> float:
	return maxf(height(x, z), 0.0)


func _make_pad() -> void:
	var pad := Node3D.new()
	pad.position = Vector3(home_xz.x, spawn_h + 0.02, home_xz.y)
	add_child(pad)
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.2
	cyl.bottom_radius = 3.3
	cyl.height = 0.12
	base.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.17, 0.2)
	m.roughness = 0.8
	base.material_override = m
	pad.add_child(base)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.92, 0.9)
	white.roughness = 0.7
	for part in [Vector3(-0.9, 0.07, 0), Vector3(0.9, 0.07, 0), Vector3(0, 0.07, 0)]:
		var bx := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.28, 0.02, 2.4) if part.x != 0.0 else Vector3(1.6, 0.02, 0.28)
		bx.mesh = b
		bx.material_override = white
		bx.position = part
		pad.add_child(bx)
	var led := StandardMaterial3D.new()
	led.albedo_color = Color(1, 0.6, 0.1)
	led.emission_enabled = true
	led.emission = Color(1, 0.55, 0.1)
	led.emission_energy_multiplier = 3.0
	for k in 8:
		var s := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.09
		sp.height = 0.18
		s.mesh = sp
		s.material_override = led
		var a := TAU * k / 8.0
		s.position = Vector3(cos(a) * 3.0, 0.1, sin(a) * 3.0)
		pad.add_child(s)


func _make_tree_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.22
	trunk.height = 2.2
	trunk.radial_segments = 6
	trunk.rings = 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 1.1, 0)))
	st.commit(mesh)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.22, 0.14, 0.09)
	tm.roughness = 1.0
	mesh.surface_set_material(0, tm)

	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 2.0 - k * 0.55
		cone.height = 3.3 - k * 0.5
		cone.radial_segments = 8
		cone.rings = 1
		st2.append_from(cone, 0, Transform3D(Basis(), Vector3(0, 2.4 + k * 1.7, 0)))
	st2.commit(mesh)
	var lm := StandardMaterial3D.new()
	lm.vertex_color_use_as_albedo = true
	lm.roughness = 0.95
	mesh.surface_set_material(1, lm)
	return mesh


func _res_for(ring: int) -> int:
	if kind == "city":
		return 8
	if ring <= 1:
		return 64
	if ring <= 3:
		return 40
	if ring <= 6:
		return 24
	return 14


func update(pos: Vector3, budget_ms: float = 5.0) -> void:
	water.position = Vector3(snappedf(pos.x, 100.0), 0.0, snappedf(pos.z, 100.0))
	var cc := Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))
	if cc != last_center:
		last_center = cc
		_rescan()
	_process_queue(budget_ms)


func _rescan() -> void:
	want_res.clear()
	var need: Array = []
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var ring := roundi(Vector2(dx, dz).length())
			if ring > radius:
				continue
			var c := last_center + Vector2i(dx, dz)
			var res := _res_for(ring)
			want_res[c] = res
			if not chunks.has(c) or chunks[c].res != res:
				need.append(c)
	for c in chunks.keys():
		if not want_res.has(c):
			_free_chunk(c)
	var lc := last_center
	need.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - lc).length_squared() < (b - lc).length_squared())
	queue = need


func _process_queue(budget_ms: float) -> void:
	var t0 := Time.get_ticks_usec()
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if not want_res.has(c):
			continue
		_make_chunk(c, want_res[c])
		if (Time.get_ticks_usec() - t0) / 1000.0 > budget_ms:
			break


func _free_chunk(c: Vector2i) -> void:
	var d: Dictionary = chunks[c]
	d.mi.queue_free()
	if d.mm != null:
		d.mm.queue_free()
	if d.deco != null:
		d.deco.queue_free()
	if decorator != null and decorator.has_method("on_free"):
		decorator.on_free(c)
	chunks.erase(c)


func _make_chunk(c: Vector2i, res: int) -> void:
	if chunks.has(c):
		_free_chunk(c)
	var ring := roundi((c - last_center).length())
	var mi := _build_mesh(c, res)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (ring <= 2 and kind != "city") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var mm: MultiMeshInstance3D = null
	if kind == "alpine" or kind == "farm":
		if ring <= 4:
			mm = _build_trees(c, ring <= 2)
			if mm != null:
				add_child(mm)
	var deco: Node3D = null
	if decorator != null:
		deco = decorator.decorate(c, ring)
		if deco != null:
			add_child(deco)
	chunks[c] = {"mi": mi, "mm": mm, "deco": deco, "res": res}


func _build_mesh(c: Vector2i, res: int) -> MeshInstance3D:
	var step := CHUNK / res
	var ox := c.x * CHUNK
	var oz := c.y * CHUNK
	var n := res + 1
	var m := res + 3
	var hs := PackedFloat32Array()
	hs.resize(m * m)
	for j in m:
		for i in m:
			hs[j * m + i] = height(ox + (i - 1) * step, oz + (j - 1) * step)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(n * n)
	norms.resize(n * n)
	for j in n:
		for i in n:
			var gi := (j + 1) * m + (i + 1)
			verts[j * n + i] = Vector3(i * step, hs[gi], j * step)
			norms[j * n + i] = Vector3(hs[gi - 1] - hs[gi + 1], 2.0 * step, hs[gi - m] - hs[gi + m]).normalized()

	var idx := PackedInt32Array()
	for j in res:
		for i in res:
			var a := j * n + i
			var b := a + 1
			var cc := a + n
			var d := cc + 1
			idx.append_array([a, b, cc, b, d, cc])

	var edges: Array = []
	var top: Array = []
	var bottom: Array = []
	var left: Array = []
	var right: Array = []
	for k in n:
		top.append(k)
		bottom.append(res * n + k)
		left.append(k * n)
		right.append(k * n + res)
	edges = [top, bottom, left, right]
	for e in edges:
		var base := verts.size()
		for k in e.size():
			verts.append(verts[e[k]] + Vector3(0, -16, 0))
			norms.append(norms[e[k]])
		for k in e.size() - 1:
			idx.append_array([e[k], e[k + 1], base + k, e[k + 1], base + k + 1, base + k])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	if decorator != null and decorator.has_method("block_info"):
		var col: Color = decorator.block_info(c)
		var cols := PackedColorArray()
		cols.resize(verts.size())
		cols.fill(col)
		arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = terrain_mat
	mi.position = Vector3(ox, 0, oz)
	return mi


func _build_trees(c: Vector2i, shadows: bool) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(c.x * 7919 + 13, c.y * 104729 + 7))
	var ox := c.x * CHUNK
	var oz := c.y * CHUNK
	var sp := 10.0
	var cnt := int(CHUNK / sp)
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	var sparse := kind == "farm"
	for j in cnt:
		for i in cnt:
			var x := ox + (i + rng.randf()) * sp
			var z := oz + (j + rng.randf()) * sp
			var h := height(x, z)
			var dens := n_forest.get_noise_2d(x, z)
			var roll := rng.randf()
			if h < 5.0 or h > 150.0:
				continue
			if sparse:
				if dens < 0.28 + roll * 0.2 or Vector2(x, z).distance_to(home_xz) < 90.0:
					continue
			elif dens < -0.05 + roll * 0.25:
				continue
			if absf(height(x + 2.0, z) - h) + absf(height(x, z + 2.0) - h) > 2.6:
				continue
			var s := rng.randf_range(0.8, 1.7)
			var bs := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.35), s))
			xf.append(Transform3D(bs, Vector3(x, h - 0.3, z)))
			cols.append(Color.from_hsv(rng.randf_range(0.20, 0.34), rng.randf_range(0.45, 0.75), rng.randf_range(0.2, 0.4)))
	if xf.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tree_mesh
	mm.instance_count = xf.size()
	for k in xf.size():
		mm.set_instance_transform(k, xf[k])
		mm.set_instance_color(k, cols[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
