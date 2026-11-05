extends Node3D
## 숨겨진 상자: 맵마다 10개. 가까이 가면 컴퍼스에 '?'가 뜨고, 닿으면 보상을 받는다.

signal found(id: String, n: int, total: int)

const COUNT := 10
const CELL := 160.0

var terrain: Node3D
var world: Dictionary
var profile: RefCounted
var items: Array = []
var spin := 0.0


func setup(t: Node3D, w: Dictionary, prof: RefCounted) -> void:
	terrain = t
	world = w
	profile = prof
	var got: Array = profile.data.secrets.get(world.id, [])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("secrets_" + String(world.id))
	var home: Vector2 = world.home
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.72, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.65, 0.15)
	mat.emission_energy_multiplier = 2.6
	mat.metallic = 0.6
	mat.roughness = 0.3
	var box := BoxMesh.new()
	box.size = Vector3(1.3, 1.3, 1.3)
	for i in COUNT:
		var id := "%s_%d" % [world.id, i]
		var p := Vector3.ZERO
		if world.kind == "city":
			for tries in 30:
				var ix := rng.randi_range(-7, 7)
				var iz := rng.randi_range(-7, 7)
				if absi(ix) + absi(iz) < 2:
					continue
				p = Vector3(ix * CELL, 24.0 + rng.randf() * 46.0, iz * CELL)
				break
		else:
			for tries in 60:
				var ang := rng.randf() * TAU
				var r := 260.0 + rng.randf() * 1500.0
				var x := home.x + cos(ang) * r
				var z := home.y + sin(ang) * r
				var g: float = terrain.height(x, z)
				if g > 2.5:
					p = Vector3(x, g + 6.0 + rng.randf() * 18.0, z)
					break
		if p == Vector3.ZERO:
			continue
		var node := Node3D.new()
		node.position = p
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = mat
		mi.rotation = Vector3(0.6, 0.0, 0.6)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
		var sp := CPUParticles3D.new()
		sp.amount = 14
		sp.lifetime = 1.8
		sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		sp.emission_sphere_radius = 1.6
		sp.gravity = Vector3(0, 0.6, 0)
		sp.initial_velocity_max = 0.3
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		var spm := StandardMaterial3D.new()
		spm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spm.albedo_color = Color(1.0, 0.85, 0.4)
		sm.material = spm
		sp.mesh = sm
		node.add_child(sp)
		node.visible = false
		add_child(node)
		items.append({"id": id, "pos": p, "node": node, "taken": got.has(id), "mi": mi})
		if got.has(id):
			node.queue_free()


func total() -> int:
	return items.size()


func found_count() -> int:
	var n := 0
	for it in items:
		if it.taken:
			n += 1
	return n


func update(pos: Vector3, dt: float) -> void:
	spin += dt
	for it in items:
		if it.taken:
			continue
		var d: float = pos.distance_to(it.pos)
		var node: Node3D = it.node
		node.visible = d < 520.0
		if node.visible:
			(it.mi as MeshInstance3D).rotation = Vector3(0.6, spin * 1.3, 0.6)
			node.position.y = it.pos.y + sin(spin * 2.0 + it.pos.x) * 0.35
		if d < 4.8:
			it.taken = true
			node.queue_free()
			var arr: Array = profile.data.secrets.get(world.id, [])
			arr.append(it.id)
			profile.data.secrets[world.id] = arr
			found.emit(it.id, found_count(), total())


## 아직 못 찾은 것 중 가장 가까운 상자 {pos, dist}. 없으면 dist = INF
func nearest(pos: Vector3) -> Dictionary:
	var best := {"pos": Vector3.ZERO, "dist": INF}
	for it in items:
		if it.taken:
			continue
		var d: float = pos.distance_to(it.pos)
		if d < best.dist:
			best = {"pos": it.pos, "dist": d}
	return best


func remaining_positions() -> Array:
	var out: Array = []
	for it in items:
		if not it.taken:
			out.append(it.pos)
	return out
