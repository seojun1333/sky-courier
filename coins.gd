extends Node3D
## 하늘에 떠 있는 코인 궤적. 좌표로 결정되므로 같은 곳에는 항상 같은 코인이 있다.

const CELL := 120.0
const R := 5

var terrain: Node3D
var kind := "alpine"
var cells := {}        # Vector2i -> Array[{node, id, phase}]
var taken := {}
var last := Vector2i(1 << 30, 1 << 30)
var coin_mesh: ArrayMesh
var coin_mat: StandardMaterial3D
var spin := 0.0
var nearest_pos := Vector3.ZERO
var nearest_dist := INF


func _ready() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 0.9
	cyl.height = 0.14
	cyl.radial_segments = 20
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(cyl, 0, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO))
	coin_mesh = st.commit()
	coin_mat = StandardMaterial3D.new()
	coin_mat.albedo_color = Color(1.0, 0.76, 0.18)
	coin_mat.metallic = 1.0
	coin_mat.roughness = 0.28
	coin_mat.emission_enabled = true
	coin_mat.emission = Color(1.0, 0.55, 0.08)
	coin_mat.emission_energy_multiplier = 0.9


func _spawn_cell(key: Vector2i) -> void:
	var arr: Array = []
	cells[key] = arr
	var rs := RandomNumberGenerator.new()
	rs.seed = hash(Vector2i(key.x * 7919 + 3, key.y * 104729 + 11))
	if rs.randf() > 0.8:
		return
	var p := Vector2((key.x + rs.randf()) * CELL, (key.y + rs.randf()) * CELL)
	var dir := Vector2.from_angle(rs.randf() * TAU)
	var cnt := rs.randi_range(5, 10)
	var alt := rs.randf_range(6.0, 28.0)
	if kind == "city":   # 도시에서는 도로 위 하늘길을 따라 코인이 이어진다
		if rs.randf() < 0.5:
			p.y = roundf(p.y / 160.0) * 160.0 + rs.randf_range(-6.0, 6.0)
			dir = Vector2(1, 0)
		else:
			p.x = roundf(p.x / 160.0) * 160.0 + rs.randf_range(-6.0, 6.0)
			dir = Vector2(0, 1)
		alt = rs.randf_range(10.0, 45.0)
	for i in cnt:
		var wx := p.x + dir.x * i * 9.0 + dir.y * sin(i * 0.7) * 4.0
		var wz := p.y + dir.y * i * 9.0 - dir.x * sin(i * 0.7) * 4.0
		var id := "%d_%d_%d" % [key.x, key.y, i]
		if taken.has(id):
			continue
		var gh: float = terrain.ground(wx, wz)
		var node := MeshInstance3D.new()
		node.mesh = coin_mesh
		node.material_override = coin_mat
		node.position = Vector3(wx, gh + alt + sin(i * 0.8) * 3.0, wz)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		arr.append({"node": node, "id": id, "phase": i * 0.6})


var pick_r2 := 9.0   # 코인 자석: 먹는 반경의 제곱


## 반환값: 이번 프레임에 먹은 코인 수
func update(pos: Vector3, dt: float) -> int:
	var c := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	if c != last:
		last = c
		for dz in range(-R, R + 1):
			for dx in range(-R, R + 1):
				var key := c + Vector2i(dx, dz)
				if not cells.has(key):
					_spawn_cell(key)
		for key in cells.keys():
			if absi(key.x - c.x) > R + 2 or absi(key.y - c.y) > R + 2:
				for it in cells[key]:
					it.node.queue_free()
				cells.erase(key)
	spin += dt * 2.4
	var got := 0
	var best := INF
	for key in cells.keys():
		var near := absi(key.x - c.x) <= 1 and absi(key.y - c.y) <= 1
		var arr: Array = cells[key]
		for k in range(arr.size() - 1, -1, -1):
			var it: Dictionary = arr[k]
			var node: Node3D = it.node
			if near:
				node.rotation.y = spin + it.phase
			var d2 := node.position.distance_squared_to(pos)
			if d2 < pick_r2:
				taken[it.id] = true
				node.queue_free()
				arr.remove_at(k)
				got += 1
			elif d2 < best:
				best = d2
				nearest_pos = node.position
	nearest_dist = sqrt(best) if best < INF else INF
	return got
