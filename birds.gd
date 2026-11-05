extends Node3D
## 하늘을 선회하는 새 떼. 칸마다 같은 자리에 같은 무리가 생긴다.

const CELL := 400.0
const R := 3
const MAX_BIRDS := 480

var terrain: Node3D
var audio: Node
var enabled := true
var mm: MultiMesh
var flocks := {}        # Vector2i -> Array[Dictionary]
var last := Vector2i(1 << 30, 1 << 30)
var t := 0.0
var chirp_t := 3.0
var sample_pos := Vector3.INF


func _ready() -> void:
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _make_mesh()
	mm.instance_count = MAX_BIRDS
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-6000, -200, -6000), Vector3(12000, 3000, 12000))
	add_child(mmi)


func _make_mesh() -> ArrayMesh:
	var MBs := preload("res://mb.gd")
	var b := MBs.new()
	var cb := func(part: int, m: int, tipf: float = 0.0) -> Color: return Color(part / 16.0, m / 8.0, tipf, 1.0)
	b.sphere(Vector3(0, 0, 0), Vector3(0.06, 0.06, 0.17), 8, 5, cb.call(0, 0))
	b.sphere(Vector3(0, 0.03, -0.19), Vector3(0.04, 0.04, 0.045), 7, 4, cb.call(0, 0))
	b.box(Vector3(-0.011, 0.02, -0.28), Vector3(0.011, 0.035, -0.22), cb.call(0, 2))
	b.box(Vector3(-0.045, -0.005, 0.15), Vector3(0.045, 0.006, 0.3), cb.call(0, 1))
	b.sphere(Vector3(-0.02, 0.045, -0.2), Vector3(0.008, 0.008, 0.008), 4, 3, cb.call(0, 4))
	b.sphere(Vector3(0.02, 0.045, -0.2), Vector3(0.008, 0.008, 0.008), 4, 3, cb.call(0, 4))
	b.box(Vector3(-0.35, -0.004, -0.09), Vector3(-0.05, 0.004, 0.13), cb.call(1, 1))
	b.box(Vector3(-0.74, -0.003, -0.04), Vector3(-0.35, 0.003, 0.1), cb.call(2, 1))
	b.box(Vector3(-0.74, -0.0035, -0.04), Vector3(-0.6, 0.0035, 0.1), cb.call(2, 1, 1.0))
	b.box(Vector3(0.05, -0.004, -0.09), Vector3(0.35, 0.004, 0.13), cb.call(3, 1))
	b.box(Vector3(0.35, -0.003, -0.04), Vector3(0.74, 0.003, 0.1), cb.call(4, 1))
	b.box(Vector3(0.6, -0.0035, -0.04), Vector3(0.74, 0.0035, 0.1), cb.call(4, 1, 1.0))
	var mesh := b.build()
	var m := ShaderMaterial.new()
	m.shader = load("res://bird.gdshader")
	mesh.surface_set_material(0, m)
	return mesh

func _spawn_cell(key: Vector2i) -> void:
	var arr: Array = []
	flocks[key] = arr
	var rs := RandomNumberGenerator.new()
	rs.seed = hash(Vector2i(key.x * 6007 + 5, key.y * 90001 + 17))
	if rs.randf() > 0.55:
		return
	var sp := rs.randi_range(0, 3)     # 0 비둘기, 1 갈매기, 2 까마귀, 3 매
	var cnt := rs.randi_range(2, 3) if sp == 3 else rs.randi_range(8, 16)
	var cx := (key.x + rs.randf()) * CELL
	var cz := (key.y + rs.randf()) * CELL
	var offs: Array[Vector3] = []
	for i in cnt:
		offs.append(Vector3(rs.randf_range(-7, 7), rs.randf_range(-3, 3), rs.randf_range(-7, 7)))
	var radius := rs.randf_range(40.0, 120.0)
	var gh: float = terrain.ground(cx, cz)
	for k in 8:   # 궤도 전체에서 가장 높은 지형 위로 난다
		var a := TAU * k / 8.0
		gh = maxf(gh, terrain.ground(cx + cos(a) * (radius + 10.0), cz + sin(a) * (radius + 10.0)))
	arr.append({
		"c": Vector2(cx, cz), "y": gh + rs.randf_range(30.0, 80.0), "r": radius,
		"w": rs.randf_range(0.12, 0.25) * (1.0 if rs.randf() < 0.5 else -1.0), "ph": rs.randf() * TAU, "off": offs, "sp": sp})


func update(pos: Vector3, dt: float) -> void:
	if not enabled:
		return
	t += dt
	var c := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	if c != last:
		last = c
		for dz in range(-R, R + 1):
			for dx in range(-R, R + 1):
				var key := c + Vector2i(dx, dz)
				if not flocks.has(key):
					_spawn_cell(key)
		for key in flocks.keys():
			if absi(key.x - c.x) > R + 1 or absi(key.y - c.y) > R + 1:
				flocks.erase(key)

	var i := 0
	var nearest := INF
	sample_pos = Vector3.INF
	for key in flocks.keys():
		for f in flocks[key]:
			var a: float = f.ph + t * f.w
			var center := Vector3(f.c.x + cos(a) * f.r, f.y + sin(a * 2.0) * 4.0, f.c.y + sin(a) * f.r)
			var sgn := signf(f.w)
			var yaw := atan2(sin(a) * sgn, -cos(a) * sgn)
			var bas := Basis(Vector3.UP, yaw)
			var offs: Array = f.off
			var sp: int = f.sp
			var sz: float = [1.0, 1.5, 1.3, 1.9][sp]
			for k in offs.size():
				if i >= MAX_BIRDS:
					break
				var o: Vector3 = offs[k]
				var p := center + bas * o * sz + Vector3(0, sin(t * 1.3 + k) * 0.8, 0)
				mm.set_instance_transform(i, Transform3D(bas.scaled(Vector3.ONE * sz), p))
				var flap := 1.0
				if sp == 1:
					flap = 0.5 + 0.5 * sin(t * 0.4 + k + f.ph)
				elif sp == 3:
					flap = 0.12
				mm.set_instance_custom_data(i, Color(sp, flap, 0.0, 0.0))
				var d := p.distance_squared_to(pos)
				if d < nearest:
					nearest = d
				if sample_pos == Vector3.INF:
					sample_pos = p
				i += 1
	mm.visible_instance_count = i

	chirp_t -= dt
	if chirp_t <= 0.0:
		chirp_t = randf_range(0.8, 2.5)
		if nearest < 90.0 * 90.0 and audio != null:
			audio.chirp()

