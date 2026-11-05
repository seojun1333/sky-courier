extends Node3D
## 미션 4종: 항로 개척(링) · 급송 배달 · 하늘 사진관 · 정밀 착륙. 끝나면 별 1~3개와 기록을 남긴다.

signal completed(info: Dictionary)
signal failed(reason: String)
signal progress(msg: String)
signal photo_taken(quality: float)

const StoryScript := preload("res://story.gd")
const CELL := 160.0
const RING_R := 5.2
const TYPES := ["ring", "delivery", "photo", "landing"]
const MIN_RANK := {"ring": 1, "delivery": 1, "photo": 2, "landing": 3}

var terrain: Node3D
var drone: Node3D
var profile: RefCounted
var world_id := "city"
var kind_world := "city"
var frame_reward := 1.0
var active := false
var kind := ""
var title := ""
var wps: Array = []              # {pos, type: ring|pickup|drop|photo|land, dir}
var nodes: Array = []
var idx := 0
var time_left := 0.0
var time_limit := 1.0
var elapsed := 0.0
var reward := 0
var carrying := false
var qualities: Array = []
var beam: MeshInstance3D


func _ready() -> void:
	beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 0.7
	cm.height = 400.0
	beam.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.albedo_color = Color(0.3, 0.9, 1.0, 0.22)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.visible = false
	add_child(beam)


func _ground(x: float, z: float) -> float:
	return maxf(terrain.ground(x, z), 0.0)


func available(type: String) -> bool:
	return profile.rank() >= int(MIN_RANK[type])


func record_key(type: String) -> String:
	return "%s_%s" % [world_id, type]


func start(type: String, pos: Vector3, fwd: Vector3) -> void:
	cancel(false)
	var f := Vector3(fwd.x, 0.0, fwd.z)
	f = f.normalized() if f.length() > 0.01 else Vector3(0, 0, -1)
	wps.clear()
	carrying = false
	idx = 0
	elapsed = 0.0
	qualities.clear()
	kind = type
	match type:
		"ring": _make_ring_run(pos, f)
		"delivery": _make_delivery(pos, f)
		"photo": _make_photo(pos, f)
		_: _make_landing(pos, f)
	title = StoryScript.MISSION_NAMES[type]
	time_limit = time_left
	_build_visuals()
	active = true
	_refresh()


func _road_start(pos: Vector3, fwd: Vector3) -> Array:
	var axis_x := absf(fwd.x) > absf(fwd.z)
	var d := signf(fwd.x if axis_x else fwd.z)
	if d == 0.0:
		d = 1.0
	var line := roundf((pos.z if axis_x else pos.x) / CELL) * CELL
	return [axis_x, d, line]


func _make_ring_run(pos: Vector3, f: Vector3) -> void:
	var n := 8
	var prev := pos
	var path := 0.0
	if kind_world == "city":
		var rs := _road_start(pos, f)
		var axis_x: bool = rs[0]
		var d: float = rs[1]
		var line: float = rs[2]
		var s0: float = (pos.x if axis_x else pos.z) + d * 50.0
		for i in n:
			var s := s0 + d * 62.0 * i
			var lat := line + (4.5 if i % 2 == 0 else -4.5)
			var h := 9.0 + 6.0 * absf(sin(i * 0.9)) + 2.0 * (i % 3)
			var p := Vector3(s, h, lat) if axis_x else Vector3(lat, h, s)
			wps.append({"pos": p, "type": "ring", "dir": Vector3(d, 0, 0) if axis_x else Vector3(0, 0, d)})
			path += prev.distance_to(p)
			prev = p
	else:
		var dirv := f
		for i in n:
			dirv = dirv.rotated(Vector3.UP, randf_range(-0.55, 0.55))
			var p := prev + dirv * randf_range(95.0, 135.0)
			var g := _ground(p.x, p.z)
			for a in 8:
				g = maxf(g, _ground(p.x + cos(a * TAU / 8.0) * 28.0, p.z + sin(a * TAU / 8.0) * 28.0))
			p.y = g + randf_range(14.0, 34.0)
			wps.append({"pos": p, "type": "ring", "dir": dirv})
			path += prev.distance_to(p)
			prev = p
	time_left = path / 12.0 + 12.0
	reward = 60 + 20 * n


func _snap_inter(p: Vector3) -> Vector3:
	return Vector3(roundf(p.x / CELL) * CELL, 0.0, roundf(p.z / CELL) * CELL)


func _spot(pos: Vector3, f: Vector3, dmin: float, dmax: float, spread: float) -> Vector3:
	var a := pos
	for tries in 30:
		a = pos + f.rotated(Vector3.UP, randf_range(-spread, spread)) * randf_range(dmin, dmax)
		if kind_world == "city":
			a = _snap_inter(a)
			break
		if terrain.height(a.x, a.z) > 2.5:
			break
	a.y = _ground(a.x, a.z) + 3.0
	return a


func _make_delivery(pos: Vector3, f: Vector3) -> void:
	var a := _spot(pos, f, 140.0, 240.0, 0.7)
	var b := _spot(a, Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU), 480.0, 800.0, 0.0)
	wps.append({"pos": a, "type": "pickup", "dir": Vector3.UP})
	wps.append({"pos": b, "type": "drop", "dir": Vector3.UP})
	time_left = (pos.distance_to(a) + a.distance_to(b)) / 10.0 + 35.0
	reward = int((110.0 + a.distance_to(b) * 0.14) * frame_reward)


func _make_photo(pos: Vector3, f: Vector3) -> void:
	var prev := pos
	var path := 0.0
	for i in 3:
		var p := _spot(prev, f.rotated(Vector3.UP, randf_range(-1.0, 1.0)), 150.0, 260.0, 0.8)
		p.y = _ground(p.x, p.z) + (randf_range(8.0, 26.0) if kind_world == "city" else randf_range(5.0, 18.0))
		wps.append({"pos": p, "type": "photo", "dir": Vector3.UP})
		path += prev.distance_to(p)
		prev = p
	time_left = path / 9.0 + 70.0
	reward = 150


func _make_landing(pos: Vector3, f: Vector3) -> void:
	var p := _spot(pos, f, 220.0, 380.0, 0.7)
	p.y = _ground(p.x, p.z) + 0.1
	wps.append({"pos": p, "type": "land", "dir": Vector3.UP})
	time_left = pos.distance_to(p) / 10.0 + 45.0
	reward = 130


func _mat(c: Color, energy := 2.4, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _color_of(t: String) -> Color:
	match t:
		"pickup": return Color(1.0, 0.6, 0.15)
		"drop": return Color(0.3, 1.0, 0.45)
		"photo": return Color(1.0, 0.35, 0.85)
		"land": return Color(0.35, 1.0, 0.7)
		_: return Color(0.25, 0.9, 1.0)


func _build_visuals() -> void:
	for n in nodes:
		n.queue_free()
	nodes.clear()
	for w in wps:
		var node := Node3D.new()
		node.position = w.pos
		var mi := MeshInstance3D.new()
		var t: String = w.type
		var col := _color_of(t)
		if t == "ring":
			var tm := TorusMesh.new()
			tm.inner_radius = RING_R - 0.45
			tm.outer_radius = RING_R + 0.45
			mi.mesh = tm
			mi.material_override = _mat(col)
			node.basis = Basis(Quaternion(Vector3.UP, (w.dir as Vector3).normalized()))
			node.position = w.pos
		elif t == "photo":
			var sp := SphereMesh.new()
			sp.radius = 3.2
			sp.height = 6.4
			mi.mesh = sp
			mi.material_override = _mat(col, 1.6, 0.35)
		else:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 8.0 if t != "land" else 7.0
			cyl.bottom_radius = cyl.top_radius
			cyl.height = 0.6
			mi.mesh = cyl
			mi.material_override = _mat(col)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
		add_child(node)
		nodes.append(node)


func _refresh() -> void:
	for i in nodes.size():
		nodes[i].visible = active and i >= idx and i <= idx + 2
		var m := (nodes[i].get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
		m.emission_energy_multiplier = 3.2 if i == idx else 0.9
	if active and idx < wps.size():
		beam.visible = true
		var t: Vector3 = wps[idx].pos
		beam.global_position = Vector3(t.x, t.y + 180.0, t.z)
		var c := _color_of(wps[idx].type)
		(beam.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, 0.23)
	else:
		beam.visible = false


func _clear() -> void:
	active = false
	for n in nodes:
		n.queue_free()
	nodes.clear()
	beam.visible = false


func cancel(announce := true) -> void:
	if not active:
		return
	_clear()
	if announce:
		failed.emit("미션 취소")


func fail(reason: String) -> void:
	if not active:
		return
	_clear()
	failed.emit(reason)


func target() -> Vector3:
	if active and idx < wps.size():
		return wps[idx].pos
	return Vector3.INF


func update(pos: Vector3, dt: float, bounty: float) -> void:
	_bounty_cache = bounty
	if not active:
		return
	time_left -= dt
	elapsed += dt
	if time_left <= 0.0:
		fail("시간 초과")
		return
	var w: Dictionary = wps[idx]
	var wp: Vector3 = w.pos
	var hd := Vector2(pos.x - wp.x, pos.z - wp.z).length()
	match String(w.type):
		"ring":
			if pos.distance_to(wp) < RING_R + 0.5:
				time_left += 4.0
				idx += 1
				progress.emit("링 통과!  +4초")
				_next(bounty)
		"pickup":
			if hd < 9.0 and pos.y - wp.y < 36.0:
				carrying = true
				idx += 1
				progress.emit("소포를 실었습니다. 목적지로!")
				_next(bounty)
		"drop":
			if hd < 9.0 and pos.y - wp.y < 36.0:
				idx += 1
				_next(bounty)
		"land":
			if drone.state == "idle" and hd < 7.0:
				qualities.append(clampf(1.0 - hd / 7.0, 0.0, 1.0))
				idx += 1
				_next(bounty)


## 셔터. 미션이 사진 미션이 아니면 그냥 찍기만 한다.
func try_photo(cam: Camera3D) -> int:
	if not active or kind != "photo" or idx >= wps.size():
		return -1
	var wp: Vector3 = wps[idx].pos
	var to := wp - cam.global_position
	var dist := to.length()
	if cam.is_position_behind(wp):
		progress.emit("표식이 카메라 뒤쪽이에요")
		return 0
	var ang := rad_to_deg((-cam.global_basis.z).angle_to(to))
	if dist > 110.0:
		progress.emit("너무 멀어요. 더 가까이!")
		return 0
	if dist < 10.0:
		progress.emit("너무 가까워요")
		return 0
	if ang > 12.0:
		progress.emit("표식을 화면 가운데에 두세요")
		return 0
	var q := clampf(1.0 - ang / 12.0 * 0.5 - dist / 110.0 * 0.4, 0.1, 1.0)
	qualities.append(q)
	idx += 1
	photo_taken.emit(q)
	_next(_bounty_cache)
	return 1


var _bounty_cache := 1.0


func _stars() -> int:
	var ratio := time_left / maxf(time_limit, 1.0)
	match kind:
		"photo":
			var avg := 0.0
			for q in qualities:
				avg += float(q)
			avg /= maxf(qualities.size(), 1)
			if avg >= 0.78 and ratio >= 0.3:
				return 3
			return 2 if avg >= 0.55 else 1
		"landing":
			var q0 := float(qualities[0]) if not qualities.is_empty() else 0.0
			if q0 >= 0.64 and ratio >= 0.35:
				return 3
			return 2 if q0 >= 0.3 else 1
		_:
			return 3 if ratio >= 0.45 else (2 if ratio >= 0.2 else 1)


func _next(bounty: float) -> void:
	_bounty_cache = bounty
	if idx >= wps.size():
		var st := _stars()
		_clear()
		var mult: float = [0.8, 1.0, 1.3][st - 1]
		var r := int(round(reward * mult * bounty))
		var key := record_key(kind)
		var best: bool = profile.record_time(key, elapsed)
		profile.record_stars(key, st)
		completed.emit({"reward": r, "title": title, "stars": st, "kind": kind, "time": elapsed, "record": best, "key": key})
	else:
		_refresh()


func hud_info(pos: Vector3, cam: Camera3D) -> Dictionary:
	if not active or idx >= wps.size():
		return {"on": false}
	var t: Vector3 = wps[idx].pos
	return {"on": true, "title": title, "time": time_left, "idx": idx, "n": wps.size(), "kind": kind, "dist": pos.distance_to(t),
		"scr": cam.unproject_position(t), "behind": cam.is_position_behind(t), "type": wps[idx].type, "carry": carrying, "reward": reward,
		"limit": time_limit}
