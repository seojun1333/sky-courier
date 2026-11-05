extends Node3D
## 도로를 달리는 차와 신호등.
## 차는 2차선 도로의 차선 중앙을 따라 달리고, 앞차·보행자와 간격을 유지하며, 교차로에서는 신호에 따라 멈추고
## 직진·좌회전(맞은편이 비면 진입)·우회전을 한다. 드론은 차에 부딪힌다.
## 도로 규격은 city_ground.gdshader와 같다: 160m 격자, 도로 반폭 11m, 횡단보도는 교차로 중심에서 12~15m.

const MB := preload("res://mb.gd")
const CELL := 160.0
const RH := 11.0
const STOP := 16.5                # 교차로 중심에서 정지선까지(횡단보도 바깥)
const OFF := [2.9, 7.9]           # 중앙선에서 1·2차선 중앙까지
const N := 220
const G := 17.0                   # 초록
const Y := 2.5                    # 노랑
const R := 1.5                    # 전방향 빨강
const HALF := G + Y + R
const CYCLE := HALF * 2.0
const HASH := 12.0
const SIG_R := 3

var mm: MultiMesh
var sig_mm: MultiMesh
var cars: Array = []
var t := 0.0
var peds: Array = []              # 횡단 중인 보행자 위치(Vector2) — people.gd가 채운다
var grid := {}
var enabled := true
var dp2 := Vector2.ZERO
var siren_dist := 1.0e9
var honks: Array = []            # 이번 프레임 경적 거리(m)
var inited := false
var palette: Array[Color] = [Color(0.8, 0.1, 0.1), Color(0.1, 0.2, 0.55), Color(0.85, 0.85, 0.87), Color(0.08, 0.08, 0.09),
	Color(0.5, 0.52, 0.55), Color(0.85, 0.7, 0.15), Color(0.1, 0.4, 0.2), Color(0.55, 0.3, 0.1)]


func _ready() -> void:
	var b := MB.new()
	var body := Color(0.5, 0.5, 0.5, 1.0)
	var dark := Color(0.04, 0.045, 0.05, 0.6)
	var glass := Color(0.06, 0.09, 0.12, 0.6)
	b.box(Vector3(-0.9, 0.35, -2.2), Vector3(0.9, 1.0, 2.2), body)
	b.box(Vector3(-0.8, 1.0, -0.6), Vector3(0.8, 1.55, 1.6), glass)
	b.box(Vector3(-0.78, 1.5, -0.55), Vector3(0.78, 1.6, 1.55), body)
	b.box(Vector3(-0.5, 1.6, 0.1), Vector3(0.5, 1.72, 0.5), Color(0.02, 0.02, 0.99, 1.0))      # 경광등
	for sx in [-1.0, 1.0]:
		for sz in [-1.35, 1.35]:
			b.box(Vector3(sx * 0.92 - 0.12, 0.0, sz - 0.32), Vector3(sx * 0.92 + 0.12, 0.62, sz + 0.32), dark)
		b.box(Vector3(sx * 0.62 - 0.22, 0.55, -2.22), Vector3(sx * 0.62 + 0.22, 0.8, -2.18), Color(1, 1, 1, 0.3))
		b.box(Vector3(sx * 0.62 - 0.22, 0.62, 2.18), Vector3(sx * 0.62 + 0.22, 0.82, 2.22), Color(1, 0, 0, 0.1))
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = b.build()
	mm.instance_count = N
	mm.visible_instance_count = 0
	var m := ShaderMaterial.new()
	m.shader = load("res://car.gdshader")
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.custom_aabb = AABB(Vector3(-5000, -5, -5000), Vector3(10000, 30, 10000))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_make_signals()


## 신호등: 접근 방향마다 하나. 로컬 -Z가 차의 진행 방향, +X가 오른쪽(보도 쪽)이다. 원점은 정지선 뒤 도로 중앙선.
func _make_signals() -> void:
	var b := MB.new()
	var c := func(code: int) -> Color: return Color(code / 8.0, 0.0, 0.0, 1.0)
	b.box(Vector3(11.5, 0.0, -0.2), Vector3(11.9, 5.8, 0.2), c.call(0))
	b.box(Vector3(2.6, 5.4, -0.1), Vector3(11.9, 5.65, 0.1), c.call(0))
	for hx in [3.2, 8.0]:
		b.box(Vector3(hx - 0.24, 4.1, -0.17), Vector3(hx + 0.24, 5.45, 0.17), c.call(1))
		var ys := [4.4, 4.78, 5.16]
		for i in 3:
			b.box(Vector3(hx - 0.13, ys[i] - 0.13, 0.17), Vector3(hx + 0.13, ys[i] + 0.13, 0.24), c.call(2 + i))
	sig_mm = MultiMesh.new()
	sig_mm.transform_format = MultiMesh.TRANSFORM_3D
	sig_mm.use_custom_data = true
	sig_mm.mesh = b.build()
	sig_mm.instance_count = (2 * SIG_R + 1) * (2 * SIG_R + 1) * 4
	var sm := ShaderMaterial.new()
	sm.shader = load("res://signal.gdshader")
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = sig_mm
	mi.material_override = sm
	mi.custom_aabb = AABB(Vector3(-5000, -5, -5000), Vector3(10000, 30, 10000))
	add_child(mi)


# --- 신호 ---
func _off(ix: int, iz: int) -> float:
	return fposmod(float(ix * 73 + iz * 151) * 5.7, CYCLE)


## 0 초록, 1 노랑, 2 빨강. axis_x는 x 방향으로 달리는 차의 신호.
func light_at(ix: int, iz: int, axis_x: bool) -> int:
	var ph := fposmod(t + _off(ix, iz) - (0.0 if axis_x else HALF), CYCLE)
	if ph < G:
		return 0
	if ph < G + Y:
		return 1
	return 2


## 보행자가 건너기 시작해도 되는 때: 건너는 도로의 차 신호가 막 빨강이 된 직후
func ped_window(ix: int, iz: int, car_axis_x: bool) -> bool:
	var ph := fposmod(t + _off(ix, iz) - (0.0 if car_axis_x else HALF), CYCLE)
	return ph > G + Y + 1.0 and ph < G + Y + 5.5


# --- 차 ---
static func _lp(axis_x: bool, dirn: float, k: int, line: float, s: float) -> Vector2:
	var o: float = OFF[k] * dirn
	return Vector2(s, line + o) if axis_x else Vector2(line - o, s)


func _spawn(car: Dictionary, pos: Vector3, far: bool) -> void:
	for tries in 6:
		car.axis_x = randf() < 0.5
		car.dir = 1.0 if randf() < 0.5 else -1.0
		car.k = randi() % 2
		var ang := randf() * TAU
		var r := randf_range(140.0, 480.0) if far else randf_range(10.0, 420.0)
		var wx := pos.x + cos(ang) * r
		var wz := pos.z + sin(ang) * r
		if car.axis_x:
			car.line = roundf(wz / CELL) * CELL
			car.s = wx
		else:
			car.line = roundf(wx / CELL) * CELL
			car.s = wz
		if absf(car.s - roundf(car.s / CELL) * CELL) < RH + 8.0:
			car.s += 30.0
		var p := _lp(car.axis_x, car.dir, car.k, car.line, car.s)
		var free := true
		for o in cars:
			if o != car and o.has("pos") and o.pos.distance_squared_to(p) < 100.0:
				free = false
				break
		if free:
			break
	car.vmax = randf_range(9.0, 15.0)
	car.v = car.vmax * 0.7
	car.size = randf_range(0.95, 1.2)
	car.long = 1.0 if randf() < 0.88 else randf_range(1.5, 2.4)
	car.siren = randf() < 0.07
	car.color = Color(0.92, 0.93, 0.95) if car.siren else palette[randi() % palette.size()]
	car.turn = false
	car.cu = -1.0e9
	car.intent = 0
	car.stuck = 0.0
	car.pos = _lp(car.axis_x, car.dir, car.k, car.line, car.s)
	car.h = Vector2(car.dir, 0.0) if car.axis_x else Vector2(0.0, car.dir)
	car.yaw = atan2(-car.h.x, -car.h.y)


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / HASH), floori(p.y / HASH))


func _build_grid() -> void:
	grid.clear()
	for c in cars:
		var k := _cell(c.pos)
		if grid.has(k):
			grid[k].append(c)
		else:
			grid[k] = [c]


## 진행 방향 앞쪽 가장 가까운 장애물(차·보행자)까지의 간격(m)
func _gap(car: Dictionary, p: Vector2, h: Vector2) -> float:
	var r := Vector2(-h.y, h.x)
	var best := 1.0e9
	var half: float = 2.2 * car.size * car.long
	var seen := {}
	for d in [0.0, 10.0, 20.0, 30.0]:
		var base: Vector2 = p + h * float(d)
		for side in [-2.5, 0.0, 2.5]:
			var k := _cell(base + r * side)
			if seen.has(k) or not grid.has(k):
				continue
			seen[k] = true
			for o in grid[k]:
				if o == car:
					continue
				var rel: Vector2 = o.pos - p
				var f := rel.dot(h)
				if f < 0.3 or f > 36.0:
					continue
				var lat := absf(rel.dot(r))
				var oh: Vector2 = o.h
				var lim := 2.1 if absf(oh.dot(h)) > 0.7 else 2.5
				if lat > lim:
					continue
				best = minf(best, f - half - 2.2 * o.size * o.long)
	for pd in peds:
		var rel2: Vector2 = pd - p
		var f2 := rel2.dot(h)
		if f2 > 0.3 and f2 < 11.0 and absf(rel2.dot(r)) < 1.9:
			best = minf(best, f2 - half - 0.6)
	return best


func _oncoming_clear(iw: Vector2, car: Dictionary) -> bool:
	var c0 := _cell(iw)
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var k := c0 + Vector2i(dx, dz)
			if not grid.has(k):
				continue
			for o in grid[k]:
				if o == car or o.turn or o.axis_x != car.axis_x or o.dir != -car.dir:
					continue
				var rel: Vector2 = o.pos - iw
				if rel.length() < 32.0 and o.v > 1.5 and rel.dot(o.h) < 0.0:
					return false
	return true


func _stop_speed(d: float) -> float:
	return 0.0 if d < 0.3 else sqrt(2.0 * 4.0 * d)


func _pick_intent(car: Dictionary) -> int:
	if randf() < 0.3:
		return 1 if car.k == 0 else 2
	return 0


func _begin_turn(car: Dictionary, ui: float) -> void:
	var left: bool = car.intent == 1
	var h: Vector2 = car.h
	var nh := Vector2(h.y, -h.x) if left else Vector2(-h.y, h.x)
	var nx := absf(nh.x) > 0.5
	var nd := nh.x + nh.y
	var p0 := _lp(car.axis_x, car.dir, car.k, car.line, (ui - RH) * car.dir)
	var nline: float = ui * car.dir
	var p2 := _lp(nx, nd, car.k, nline, car.line + nd * RH)
	var p1 := Vector2(p2.x, p0.y) if car.axis_x else Vector2(p0.x, p2.y)
	car.bz = [p0, p1, p2]
	car.bu = 0.0
	car.blen = (p0.distance_to(p2) + p0.distance_to(p1) + p1.distance_to(p2)) * 0.5
	car.n_axis_x = nx
	car.n_dir = nd
	car.n_line = nline
	car.n_s = car.line + nd * (RH + 0.5)
	car.turn = true


func _step(car: Dictionary, dt: float) -> void:
	var p: Vector2 = car.pos
	var h: Vector2 = car.h
	var vt: float = car.vmax
	var gap := _gap(car, p, h)
	var ui := 0.0
	if car.turn:
		vt = minf(vt, 6.5 if car.intent == 1 else 5.0)
	else:
		var u: float = car.s * car.dir
		ui = floorf((u - RH) / CELL) * CELL + CELL
		if car.cu != ui:
			car.cu = ui
			car.intent = _pick_intent(car)
		var ds := ui - STOP - u
		var wi: float = ui * car.dir
		var iw := Vector2(wi, car.line) if car.axis_x else Vector2(car.line, wi)
		if ds > -1.0:
			var st := light_at(roundi(iw.x / CELL), roundi(iw.y / CELL), car.axis_x)
			if st == 2 or (st == 1 and ds > car.v * car.v / 9.0 + 1.0):
				vt = minf(vt, _stop_speed(ds))
		if car.intent == 1:
			var db := ui - RH - u
			if db > -0.5 and db < 16.0 and not _oncoming_clear(iw, car):
				vt = minf(vt, _stop_speed(db - 1.5))
		if car.intent != 0:
			vt = minf(vt, 8.0 if ui - RH - u < 20.0 else vt)
	if gap < 45.0:
		vt = minf(vt, maxf(0.0, gap - 2.0))
	if gap < 4.5 and car.v > 3.0 and randf() < 0.006:
		var hd: float = p.distance_to(dp2)
		if hd < 140.0:
			honks.append(hd)
	if gap < 1.0:
		car.v = 0.0
	if vt < car.v:
		car.v = maxf(vt, car.v - 9.0 * dt)
	else:
		car.v = minf(vt, car.v + 3.0 * dt)
	if car.v < 0.3:
		car.stuck += dt
	else:
		car.stuck = 0.0
	if car.turn:
		car.bu += car.v * dt / car.blen
		var bz: Array = car.bz
		var u2: float = minf(car.bu, 1.0)
		var a: Vector2 = bz[0].lerp(bz[1], u2)
		var b2: Vector2 = bz[1].lerp(bz[2], u2)
		car.pos = a.lerp(b2, u2)
		var tg := (b2 - a)
		if tg.length() > 0.01:
			car.h = tg.normalized()
		if car.bu >= 1.0:
			car.turn = false
			car.axis_x = car.n_axis_x
			car.dir = car.n_dir
			car.line = car.n_line
			car.s = car.n_s
			car.cu = -1.0e9
			car.intent = 0
			car.pos = _lp(car.axis_x, car.dir, car.k, car.line, car.s)
			car.h = Vector2(car.dir, 0.0) if car.axis_x else Vector2(0.0, car.dir)
	else:
		car.s += car.dir * car.v * dt
		if car.intent != 0 and car.s * car.dir >= ui - RH:
			_begin_turn(car, ui)
		else:
			car.pos = _lp(car.axis_x, car.dir, car.k, car.line, car.s)
	car.yaw = atan2(-car.h.x, -car.h.y)


func update(pos: Vector3, dt: float) -> void:
	if not enabled:
		return
	t += dt
	if not inited:
		inited = true
		for i in N:
			var car := {}
			_spawn(car, pos, false)
			cars.append(car)
		mm.visible_instance_count = N
	_build_grid()
	var dp := Vector2(pos.x, pos.z)
	dp2 = dp
	siren_dist = 1.0e9
	honks.clear()
	for i in N:
		var car: Dictionary = cars[i]
		_step(car, dt)
		if car.siren:
			siren_dist = minf(siren_dist, car.pos.distance_to(dp))
		if car.pos.distance_to(dp) > 640.0 or car.stuck > 40.0:
			_spawn(car, pos, true)
		var bas := Basis(Vector3.UP, car.yaw).scaled(Vector3(car.size, car.size, car.size * car.long))
		mm.set_instance_transform(i, Transform3D(bas, Vector3(car.pos.x, 0.04, car.pos.y)))
		var cc: Color = car.color
		cc.a = 1.0 if car.siren else 0.0
		mm.set_instance_custom_data(i, cc)
	_update_signals(pos)


func _update_signals(pos: Vector3) -> void:
	var cx := roundi(pos.x / CELL)
	var cz := roundi(pos.z / CELL)
	var n := 0
	for dz in range(-SIG_R, SIG_R + 1):
		for dx in range(-SIG_R, SIG_R + 1):
			var ix := cx + dx
			var iz := cz + dz
			var ctr := Vector2(ix * CELL, iz * CELL)
			for ax in [true, false]:
				for d in [1.0, -1.0]:
					var o: Vector2 = ctr + (Vector2(-d * 12.8, 0.0) if ax else Vector2(0.0, -d * 12.8))
					var h := Vector2(d, 0.0) if ax else Vector2(0.0, d)
					var yaw := atan2(-h.x, -h.y)
					sig_mm.set_instance_transform(n, Transform3D(Basis(Vector3.UP, yaw), Vector3(o.x, 0.0, o.y)))
					sig_mm.set_instance_custom_data(n, Color(float(light_at(ix, iz, ax)), 0, 0, 0))
					n += 1


## 개발용 점검: 겹친 차 쌍, 멈춘 차, 회전 중인 차 수
func stats() -> Dictionary:
	var overlaps := 0
	var stopped := 0
	var moving := 0
	var turning := 0
	for c in cars:
		if c.v < 0.3:
			stopped += 1
		else:
			moving += 1
		if c.turn:
			turning += 1
		var k := _cell(c.pos)
		for o in grid.get(k, []):
			if o != c and o.pos.distance_to(c.pos) < 2.6:
				overlaps += 1
	return {"overlap": overlaps / 2, "stopped": stopped, "moving": moving, "turning": turning}


## 드론과 차의 충돌: buildings.collide와 같은 형식으로 돌려준다
func collide(pos: Vector3, vel: Vector3, rad: float) -> Dictionary:
	var st := {"pos": pos, "vel": vel, "impact": 0.0, "up": false}
	if pos.y > 3.4 or not inited:
		return st
	var p2 := Vector2(pos.x, pos.z)
	var c0 := _cell(p2)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := c0 + Vector2i(dx, dz)
			if not grid.has(k):
				continue
			for o in grid[k]:
				var sz: float = o.size
				var yaw: float = o.yaw
				var bs := Basis(Vector3.UP, yaw)
				var rel := pos - Vector3(o.pos.x, 0.0, o.pos.y)
				var lp := bs.inverse() * rel
				var ex := 0.9 * sz + rad
				var ez: float = 2.2 * sz * float(o.long) + rad
				var ey := 0.8 * sz + rad
				var ly := lp.y - 0.8 * sz
				if absf(lp.x) >= ex or absf(lp.z) >= ez or absf(ly) >= ey:
					continue
				var px := ex - absf(lp.x)
				var py := ey - absf(ly)
				var pz: float = ez - absf(lp.z)
				var nrm := Vector3.ZERO
				var push := 0.0
				if py <= px and py <= pz:
					nrm = Vector3(0, signf(ly) if ly != 0.0 else 1.0, 0)
					push = py
				elif px <= pz:
					nrm = Vector3(signf(lp.x) if lp.x != 0.0 else 1.0, 0, 0)
					push = px
				else:
					nrm = Vector3(0, 0, signf(lp.z) if lp.z != 0.0 else 1.0)
					push = pz
				var wn := bs * nrm
				var cv: Vector3 = Vector3(o.h.x, 0.0, o.h.y) * float(o.v)
				var rv: Vector3 = st.vel - cv
				var into := -rv.dot(wn)
				st.pos += wn * push
				if into > 0.0:
					st.vel += wn * into
					st.impact = maxf(st.impact, into)
				if wn.y > 0.5:
					st.up = true
	return st
