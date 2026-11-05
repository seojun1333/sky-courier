extends Node3D
## 폐건물: 배치, 벽 충돌, 실내 어둠/조명, 깜짝 귀신 이벤트.

const GhostScript := preload("res://ghost.gd")
const CELL := 500.0
const R := 3
const WALL := 0.35
const HALF_X := 8.0
const HALF_Z := 5.5
const ROOF := 7.3

var terrain: Node3D
var audio: Node
var city := {}                 # Vector2i -> Dictionary (비어 있으면 건물 없음)
var last := Vector2i(1 << 30, 1 << 30)
var mat: ShaderMaterial
var ghost: Node3D
var t := 0.0
var indoor_f := 0.0
var indoor_t := 0.0
var cur := {}
var ev := {}
var ambient_t := 8.0
var global_cd := 0.0
var scare_glitch := 0.0
var scare_flash := 0.0
var nearest_pos := Vector3.ZERO
var nearest_dist := INF
var nearest_b := {}
var blackout := 0.0
var face := 0.0
var sub_t := 25.0
var msg_q: Array = []
var eye_root: Node3D
var eyes: Array = []

const MSGS := ["!! UNKNOWN SIGNAL DETECTED", "!! PROXIMITY: 0.8 m", "!! REC 00:00:00", "!! LINK: 2 DEVICES CONNECTED",
	"!! OBJECT BEHIND CAMERA", "!! DO NOT TURN AROUND"]


func _ready() -> void:
	mat = ShaderMaterial.new()
	mat.shader = load("res://building.gdshader")
	ghost = GhostScript.new()
	add_child(ghost)
	eye_root = Node3D.new()
	eye_root.visible = false
	add_child(eye_root)
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Color(1.0, 0.12, 0.06)
	em.emission_enabled = true
	em.emission = Color(1.0, 0.1, 0.05)
	em.emission_energy_multiplier = 3.0
	for i in 8:
		var pair := Node3D.new()
		for sx in [-1.0, 1.0]:
			var m := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.035
			sp.height = 0.07
			m.mesh = sp
			m.material_override = em
			m.position = Vector3(sx * 0.09, 0, 0)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pair.add_child(m)
		eye_root.add_child(pair)
		eyes.append(pair)


# ---------- 건물 생성 ----------
func _box(a: Vector3, b: Vector3) -> Dictionary:
	return {"min": Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)),
		"max": Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))}


func _wall_x(boxes: Array, x0: float, x1: float, z: float, y0: float, y1: float, ops: Array) -> void:
	var hw := WALL * 0.5
	var xs := x0
	ops.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	for o in ops:
		if o[0] > xs:
			boxes.append(_box(Vector3(xs, y0, z - hw), Vector3(o[0], y1, z + hw)))
		if o[2] > y0:
			boxes.append(_box(Vector3(o[0], y0, z - hw), Vector3(o[1], o[2], z + hw)))
		if o[3] < y1:
			boxes.append(_box(Vector3(o[0], o[3], z - hw), Vector3(o[1], y1, z + hw)))
		xs = o[1]
	if x1 > xs:
		boxes.append(_box(Vector3(xs, y0, z - hw), Vector3(x1, y1, z + hw)))


func _wall_z(boxes: Array, z0: float, z1: float, x: float, y0: float, y1: float, ops: Array) -> void:
	var hw := WALL * 0.5
	var zs := z0
	ops.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	for o in ops:
		if o[0] > zs:
			boxes.append(_box(Vector3(x - hw, y0, zs), Vector3(x + hw, y1, o[0])))
		if o[2] > y0:
			boxes.append(_box(Vector3(x - hw, y0, o[0]), Vector3(x + hw, o[2], o[1])))
		if o[3] < y1:
			boxes.append(_box(Vector3(x - hw, o[3], o[0]), Vector3(x + hw, y1, o[1])))
		zs = o[1]
	if z1 > zs:
		boxes.append(_box(Vector3(x - hw, y0, zs), Vector3(x + hw, y1, z1)))


func _layout(rs: RandomNumberGenerator, depth: float) -> Array:
	var B: Array = []
	var H := 7.2
	B.append(_box(Vector3(-8.4, -depth, -5.9), Vector3(8.4, 0.15, 5.9)))   # 기초 + 바닥
	_wall_x(B, -8, 8, 5.5, 0, H, [[-1.4, 1.4, 0, 3.0], [-6, -4.4, 1.0, 2.5], [4.4, 6, 1.0, 2.5],
		[-6, -4.4, 4.4, 5.8], [-1, 0.6, 4.4, 5.8], [4.4, 6, 4.4, 5.8]])
	_wall_x(B, -8, 2, -5.5, 0, H, [[-6, -4.4, 1.0, 2.5], [-6, -4.4, 4.4, 5.8], [-1, 0.6, 4.4, 5.8]])
	_wall_x(B, 2, 8, -5.5, 0, 5.0, [[3.5, 7.2, 0, 3.2]])
	_wall_z(B, -5.5, 5.5, -8, 0, H, [[-3.5, -2, 1.0, 2.5], [2, 3.5, 1.0, 2.5], [-3.5, -2, 4.4, 5.8], [1, 2.6, 4.4, 5.8]])
	_wall_z(B, -5.5, 1, 8, 0, H, [[-3, -1.5, 1.0, 2.5]])
	_wall_z(B, 1, 5.5, 8, 0, 4.0, [])
	_wall_x(B, -7.8, 7.8, 0.5, 0, 3.3, [[-1.2, 1.0, 0, 2.6], [4, 6, 0, 3.3]])
	_wall_x(B, -7.8, -1, -1.5, 3.6, H, [[-5, -3.8, 3.6, 5.9]])
	# 2층 바닥(가운데가 무너짐)
	B.append(_box(Vector3(-8, 3.3, -5.5), Vector3(1.5, 3.6, 5.5)))
	B.append(_box(Vector3(5.5, 3.3, -5.5), Vector3(8, 3.6, 5.5)))
	B.append(_box(Vector3(1.5, 3.3, 0.5), Vector3(5.5, 3.6, 5.5)))
	B.append(_box(Vector3(1.5, 3.3, -5.5), Vector3(5.5, 3.6, -3.5)))
	# 지붕(구멍 있음)
	B.append(_box(Vector3(-8, 7.0, -5.5), Vector3(-3, 7.3, 5.5)))
	B.append(_box(Vector3(2.5, 7.0, -5.5), Vector3(8, 7.3, 1)))
	B.append(_box(Vector3(-3, 7.0, 2.5), Vector3(2.5, 7.3, 5.5)))
	B.append(_box(Vector3(-3, 7.0, -5.5), Vector3(2.5, 7.3, -2)))
	# 기둥
	for c in [Vector2(-3, 3), Vector2(3, 3), Vector2(-4, -3)]:
		B.append(_box(Vector3(c.x - 0.25, 0.15, c.y - 0.25), Vector3(c.x + 0.25, 3.3, c.y + 0.25)))
	# 잔해 상자
	for i in 7:
		var cx := rs.randf_range(-7.0, 7.0)
		var cz := rs.randf_range(-4.8, 4.8)
		if (absf(cx) < 1.8 and cz > 0.0) or absf(cz - 0.5) < 0.9 or (absf(cx) < 1.6 and cz < 0.0 and cz > -4.5):
			continue
		var w := rs.randf_range(0.5, 1.3)
		var h := rs.randf_range(0.4, 1.1)
		B.append(_box(Vector3(cx - w * 0.5, 0.15, cz - w * 0.5), Vector3(cx + w * 0.5, 0.15 + h, cz + w * 0.5)))
	# 무너진 모서리의 잔해 더미
	B.append(_box(Vector3(8.3, -depth, 1.5), Vector3(10.5, 1.0, 4.5)))
	B.append(_box(Vector3(10.5, -depth, 2.5), Vector3(11.7, 0.5, 4.0)))
	return B


func _make_building(key: Vector2i) -> Dictionary:
	var rs := RandomNumberGenerator.new()
	rs.seed = hash(Vector2i(key.x * 3779 + 1, key.y * 51001 + 2))
	var near_origin := key.x >= -1 and key.x <= 0 and key.y >= -1 and key.y <= 0
	if rs.randf() > (0.85 if near_origin else 0.22):
		return {}
	var spot := Vector2.ZERO
	var base := 0.0
	var found := false
	for attempt in 14:
		var cx: float
		var cz: float
		if near_origin:
			var a := rs.randf() * TAU
			var r := rs.randf_range(110.0, 260.0)
			cx = cos(a) * r
			cz = sin(a) * r
		else:
			cx = (key.x + rs.randf_range(0.1, 0.9)) * CELL
			cz = (key.y + rs.randf_range(0.1, 0.9)) * CELL
		var lo := INF
		var hi := -INF
		for iz in 5:
			for ix in 5:
				var h: float = terrain.height(cx + (ix - 2) * 4.5, cz + (iz - 2) * 3.4)
				lo = minf(lo, h)
				hi = maxf(hi, h)
		if lo > 2.5 and hi < 120.0 and hi - lo < 5.0:
			spot = Vector2(cx, cz)
			base = hi
			found = true
			break
	if not found:
		return {}
	var yaw := rs.randi_range(0, 3) * PI / 2.0
	var origin := Vector3(spot.x, base, spot.y)
	var rot := Basis(Vector3.UP, yaw)
	var depth := 6.0   # 기초를 경사 아래로 충분히 묻는다
	var local_boxes := _layout(rs, depth)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var aabbs: Array = []
	for b in local_boxes:
		var mn: Vector3 = b.min
		var mx: Vector3 = b.max
		var bm := BoxMesh.new()
		bm.size = mx - mn
		st.append_from(bm, 0, Transform3D(rot, origin + rot * ((mn + mx) * 0.5)))
		var wmin := Vector3(INF, INF, INF)
		var wmax := Vector3(-INF, -INF, -INF)
		for cxi in [mn.x, mx.x]:
			for cyi in [mn.y, mx.y]:
				for czi in [mn.z, mx.z]:
					var w: Vector3 = origin + rot * Vector3(cxi, cyi, czi)
					wmin = wmin.min(w)
					wmax = wmax.max(w)
		aabbs.append({"min": wmin, "max": wmax})
	var node := Node3D.new()
	add_child(node)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	node.add_child(mi)

	var lights: Array = []
	var defs := [
		[Vector3(-4, 1.8, 2.8), Color(0.6, 0.78, 0.7), 0.45],
		[Vector3(3, 1.8, -2.8), Color(0.6, 0.78, 0.7), 0.45],
		[Vector3(-4, 5.2, 0), Color(0.65, 0.8, 0.75), 0.4],
		[Vector3(0, 2.4, 6.6), Color(1.0, 0.4, 0.15), 0.7]]
	for d in defs:
		var l := OmniLight3D.new()
		l.position = origin + rot * d[0]
		l.light_color = d[1]
		l.omni_range = 9.0
		l.light_energy = d[2]
		l.distance_fade_enabled = true
		l.distance_fade_begin = 90.0
		l.distance_fade_length = 40.0
		node.add_child(l)
		lights.append({"node": l, "base": d[2], "ph": rs.randf() * 20.0})

	return {"origin": origin, "yaw": yaw, "rot": rot, "base": base, "aabbs": aabbs, "node": node,
		"lights": lights, "armed": true, "type": rs.randi_range(0, 4), "dark_until": 0.0,
		"spot": origin + rot * Vector3(0, 0.15, -3.6), "hang": origin + rot * Vector3(1.0, 3.6, -1.5)}


# ---------- 충돌 ----------
var solid := {}      # Vector2i(청크) -> Array[{min,max}]: 도시·농가·기지 같은 고정 구조물
var extra := {}      # Vector2i -> Dictionary: 도시의 들어갈 수 있는 폐건물
var spawn_ruins := true


func add_solid(key: Vector2i, boxes: Array) -> void:
	solid[key] = boxes


func remove_solid(key: Vector2i) -> void:
	solid.erase(key)


func add_enterable(key: Vector2i, b: Dictionary) -> void:
	extra[key] = b


func remove_enterable(key: Vector2i) -> void:
	extra.erase(key)


func _all() -> Array:
	var out: Array = []
	for k in city.keys():
		if not city[k].is_empty():
			out.append(city[k])
	for k in extra.keys():
		out.append(extra[k])
	return out


## 박스 하나와의 충돌을 풀고 [pos, vel, impact, up]을 갱신한다
func _push(box: Dictionary, st: Dictionary, rad: float) -> void:
	var mn: Vector3 = box.min
	var mx: Vector3 = box.max
	var pos: Vector3 = st.pos
	var cp := pos.clamp(mn, mx)
	var diff := pos - cp
	var d2 := diff.length_squared()
	if d2 >= rad * rad:
		return
	var n: Vector3
	var pen: float
	if d2 > 1.0e-8:
		var d := sqrt(d2)
		n = diff / d
		pen = rad - d
	else:   # 상자 안으로 파고든 경우: 가장 가까운 면으로 민다
		var best := INF
		n = Vector3.UP
		pen = 0.0
		for ax in 3:
			var lo: float = pos[ax] - mn[ax]
			var hi: float = mx[ax] - pos[ax]
			if lo < best:
				best = lo
				n = Vector3.ZERO
				n[ax] = -1.0
				pen = lo + rad
			if hi < best:
				best = hi
				n = Vector3.ZERO
				n[ax] = 1.0
				pen = hi + rad
	st.pos = pos + n * pen
	var vn: float = st.vel.dot(n)
	if vn < 0.0:
		st.impact = maxf(st.impact, -vn)
		st.vel -= n * vn * 1.05
	if n.y > 0.7:
		st.up = true


func collide(pos: Vector3, vel: Vector3, rad: float) -> Dictionary:
	var st := {"pos": pos, "vel": vel, "impact": 0.0, "up": false}
	for b in _all():
		if pos.distance_to(b.origin) > b.get("reach", 30.0):
			continue
		for box in b.aabbs:
			_push(box, st, rad)
	var c := Vector2i(floori(pos.x / 160.0), floori(pos.z / 160.0))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := c + Vector2i(dx, dz)
			if solid.has(key):
				for box in solid[key]:
					if box.max.y > pos.y - 2.0 and box.min.y < pos.y + 2.0:
						_push(box, st, rad)
	return st


func _inside(b: Dictionary, p: Vector3) -> bool:
	var l: Vector3 = b.rot.inverse() * (p - b.origin)
	return absf(l.x) < b.get("hx", HALF_X) + 0.3 and absf(l.z) < b.get("hz", HALF_Z) + 0.3 and l.y > -0.5 and l.y < b.get("roof", ROOF) + 0.1


# ---------- 매 프레임 ----------
func update(drone: Node3D, dt: float) -> void:
	t += dt
	var pos: Vector3 = drone.position
	var c := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	if c != last:
		last = c
		if spawn_ruins:
			for dz in range(-R, R + 1):
				for dx in range(-R, R + 1):
					var key := c + Vector2i(dx, dz)
					if not city.has(key):
						city[key] = _make_building(key)
			for key in city.keys():
				if absi(key.x - c.x) > R + 1 or absi(key.y - c.y) > R + 1:
					var b: Dictionary = city[key]
					if not b.is_empty():
						b.node.queue_free()
					city.erase(key)

	var best := INF
	cur = {}
	for b in _all():
		var d := pos.distance_to(b.origin)
		if d < best:
			best = d
			nearest_pos = b.origin + Vector3(0, 3, 0)
			nearest_b = b
		if d < b.get("reach", 16.0) and _inside(b, pos):
			cur = b
		if d < 120.0:
			_flicker(b)
	nearest_dist = best
	indoor_f = move_toward(indoor_f, 0.0 if cur.is_empty() else 1.0, dt * 2.5)
	scare_glitch = move_toward(scare_glitch, 0.0, dt * 1.6)
	scare_flash = move_toward(scare_flash, 0.0, dt * 3.0)
	face = move_toward(face, 0.0, dt * 8.0)
	blackout = move_toward(blackout, 1.0 if (not cur.is_empty() and t < cur.dark_until) else 0.0, dt * 8.0)
	_events(drone, dt)


func _flicker(b: Dictionary) -> void:
	var off: bool = t < b.dark_until
	for l in b.lights:
		var e: float = 0.0
		if not off:
			e = l.base * (0.7 + 0.3 * sin(t * 13.0 + l.ph) * sin(t * 7.3 + l.ph * 2.0))
			if fmod(t * 0.37 + l.ph, 1.0) > 0.965:
				e *= 0.08
		l.node.light_energy = e


func _events(drone: Node3D, dt: float) -> void:
	global_cd = maxf(0.0, global_cd - dt)
	if not ev.is_empty():
		_run_event(drone, dt)
		return
	var dpos: Vector3 = drone.position
	if cur.is_empty():
		indoor_t = 0.0
		# 밖에서 창문을 올려다보면 누군가 서 있다
		var nb: Dictionary = nearest_b
		if not nb.is_empty() and nb.armed and nb.type == 4 and global_cd <= 0.0 and nearest_dist < 60.0 and nearest_dist > 16.0:
			var ol: Vector3 = nb.rot.inverse() * (dpos - nb.origin)
			if ol.z > nb.get("front", 5.5) + 1.5 and absf(ol.x) < 30.0 and ol.y < 30.0:
				_start_event(nb, 4)
		return
	indoor_t += dt
	ambient_t -= dt
	if ambient_t <= 0.0:
		ambient_t = randf_range(6.0, 13.0)
		var r := randf()
		if r < 0.26:
			audio.creak()
		elif r < 0.48:
			audio.whisper()
		elif r < 0.66:
			audio.knock()
		elif r < 0.82:
			audio.steps()
		else:
			audio.giggle()
	sub_t -= dt
	if sub_t <= 0.0:   # 화면에 얼굴이 아주 잠깐 스친다
		sub_t = randf_range(22.0, 45.0)
		face = 1.0
		scare_glitch = maxf(scare_glitch, 0.4)
		audio.whisper()
	if cur.armed and global_cd <= 0.0:
		match int(cur.type):
			0:
				if indoor_t > 1.0 and dpos.distance_to(cur.spot) < 9.0:
					_start_event(cur, 0)
			1:
				if indoor_t > 2.2:
					_start_event(cur, 1)
			2:
				if indoor_t > 2.5:
					_start_event(cur, 2)
			3:
				if indoor_t > 0.8 and dpos.distance_to(cur.hang) < 8.0:
					_start_event(cur, 3)


func _start_event(b: Dictionary, type: int) -> void:
	ev = {"b": b, "type": type, "t": 0.0, "step": 0, "blink": 0.0, "n": 0, "pos": []}
	b.armed = false
	global_cd = 25.0
	if type != 4:
		b.dark_until = t + 0.9
	audio.whisper()
	msg_q.append(MSGS[randi() % MSGS.size()])


func _floor_y(b: Dictionary, drone: Node3D) -> float:
	return maxf(b.base + 0.15, drone.position.y - 1.3)


func _end_event() -> void:
	ghost.visible = false
	ghost.set_hanging(false)
	eye_root.visible = false
	ev = {}


func _run_event(drone: Node3D, dt: float) -> void:
	var b: Dictionary = ev.b
	ev.t += dt
	var typ: int = ev.type
	if typ != 4 and cur.is_empty() and ev.t > 5.0 and ev.step < 2:
		_end_event()
		return
	match ev.step:
		0:
			if ev.t >= (0.0 if typ == 4 else 0.9):
				_ev_setup(b, typ, drone)
		1:
			_ev_loop(b, typ, drone, dt)
		2:
			_ev_scare(b, typ, drone)
		3:
			if ev.t > 1.5:
				_end_event()


func _ev_setup(b: Dictionary, typ: int, drone: Node3D) -> void:
	var dpos: Vector3 = drone.position
	ev.step = 1
	ev.t = 0.0
	match typ:
		0:
			ghost.global_position = Vector3(b.spot.x, _floor_y(b, drone), b.spot.z)
		1:
			var f: Vector3 = -drone.cam.global_basis.z
			f.y = 0.0
			f = f.normalized() if f.length() > 0.1 else Vector3.FORWARD
			var gp: Vector3 = dpos + f * 13.0
			ghost.global_position = Vector3(gp.x, _floor_y(b, drone), gp.z)
		2:
			b.dark_until = t + 8.0
			eye_root.visible = true
			# 처음 몇 쌍은 카메라 앞쪽 부채꼴에, 나머지는 사방에 둔다
			var fwd: Vector3 = -drone.cam.global_basis.z
			fwd.y = 0.0
			fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
			for i in eyes.size():
				var spread := 0.8 if i < 5 else 2.6
				var dir := fwd.rotated(Vector3.UP, randf_range(-spread, spread))
				eyes[i].global_position = dpos + dir * randf_range(4.0, 8.0) + Vector3(0, randf_range(-0.6, 1.0), 0)
				eyes[i].visible = false
		3:
			ghost.set_hanging(true)
			ghost.global_position = b.hang + Vector3(0, 0.95, 0)
		4:
			ghost.global_position = b.get("watch", b.origin + b.rot * Vector3(-0.2, 3.7, 4.7))
	if typ != 2:
		ghost.visible = true
		ghost.body_mat.set_shader_parameter("alpha", 0.85)
		ghost.face(dpos)
	audio.creak()
	if typ != 4:
		scare_glitch = 0.5


func _ev_loop(b: Dictionary, typ: int, drone: Node3D, dt: float) -> void:
	var dpos: Vector3 = drone.position
	if typ == 2:
		ev.blink += dt
		for i in eyes.size():
			var e: Node3D = eyes[i]
			e.visible = i <= ev.n and fmod(t * 1.3 + i, 3.0) > 0.15
			e.look_at(dpos, Vector3.UP)
		if ev.blink > 0.8:
			ev.blink = 0.0
			ev.n += 2
			for e in eyes:
				e.global_position = e.global_position.lerp(dpos, 0.27)
			scare_glitch = 0.4
			audio.boom()
		var nearest_eye := INF
		for e in eyes:
			nearest_eye = minf(nearest_eye, e.global_position.distance_to(dpos))
		if ev.t > 5.0 or nearest_eye < 1.8:
			ev.step = 2
			ev.t = 0.0
		return
	ghost.face(dpos)
	var gd := Vector2(ghost.global_position.x - dpos.x, ghost.global_position.z - dpos.z).length()
	if typ != 4:
		scare_glitch = maxf(scare_glitch, clampf(1.0 - gd / 12.0, 0.0, 1.0) * 0.55)
	match typ:
		0:
			ev.blink += dt
			if ev.blink > 0.85:
				ev.blink = 0.0
				var target := Vector3(dpos.x, _floor_y(b, drone), dpos.z)
				ghost.global_position = ghost.global_position.lerp(target, 0.4)
				b.dark_until = t + 0.14
				scare_glitch = 0.55
				audio.boom()
			if gd < 3.2:
				ev.step = 2
				ev.t = 0.0
		1:
			var dir := (Vector3(dpos.x, ghost.global_position.y, dpos.z) - ghost.global_position).normalized()
			ghost.global_position += dir * (4.0 + ev.t * 14.0) * dt
			if gd < 1.9:
				ev.step = 2
				ev.t = 0.0
		3:
			ghost.rotation.z = sin(t * 1.6) * 0.22
			if ghost.global_position.distance_to(dpos) < 3.4 or ev.t > 6.0:
				ev.step = 2
				ev.t = 0.0
		4:
			if gd < 17.0 or ev.t > 9.0:
				ev.step = 2
				ev.t = 0.0


func _ev_scare(b: Dictionary, typ: int, drone: Node3D) -> void:
	var dpos: Vector3 = drone.position
	var gp: Vector3 = ghost.global_position
	if typ == 2:
		gp = eyes[0].global_position
	if typ == 4:   # 창가의 그림자는 소리 없이 사라진다
		audio.whisper()
		audio.creak()
		ghost.visible = false
		b.dark_until = t + 0.6
		scare_glitch = 0.7
		face = 1.0
	else:
		audio.scream()
		audio.boom()
		scare_flash = 1.0
		scare_glitch = 1.0
		face = 1.0
		ghost.visible = false
		eye_root.visible = false
		ghost.set_hanging(false)
		b.dark_until = t + 1.3
		var away := dpos - gp
		away.y = 0.0
		away = away.normalized() if away.length() > 0.05 else Vector3.BACK
		drone.yank(away * 10.0 + Vector3(0, 2.0, 0))
	ev.step = 3
	ev.t = 0.0


## 개발용: 지정한 이벤트를 바로 시작한다
func debug_start(b: Dictionary, type: int) -> void:
	_end_event()
	global_cd = 0.0
	_start_event(b, type)
