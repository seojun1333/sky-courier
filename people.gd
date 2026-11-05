extends Node3D
## 드론 주변을 걸어 다니는 사람 13종과 강아지. 도시에서는 인도를 따라 걷고, 들판에서는 어슬렁거린다.
## 드론이 가까이 오면 멈춰서 올려다본다.

const Human := preload("res://human.gd")
const RealPeople := preload("res://realpeople.gd")
const RH := 11.0
const CELL := 160.0
const PER_TYPE := 28
const MAX_DOGS := 40

var terrain: Node3D
var enabled := true
var kind := "alpine"
var mms := {}            # 종류 id -> MultiMesh
var dog_mm: MultiMesh
var agents: Array = []
var t := 0.0
var inited := false
var lineup := false
var real: Node3D
var traffic: Node3D
var sample_pos := Vector3.INF


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--nochars"):
		real = RealPeople.new()
		add_child(real)
	for ty in Human.types():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = Human.build(ty)
		mm.instance_count = PER_TYPE
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Human.make_material(ty)
		mmi.custom_aabb = AABB(Vector3(-6000, -100, -6000), Vector3(12000, 600, 12000))
		add_child(mmi)
		mms[ty.id] = mm
	dog_mm = MultiMesh.new()
	dog_mm.transform_format = MultiMesh.TRANSFORM_3D
	dog_mm.use_custom_data = true
	dog_mm.mesh = Human.build_dog()
	dog_mm.instance_count = MAX_DOGS
	dog_mm.visible_instance_count = 0
	var dmi := MultiMeshInstance3D.new()
	dmi.multimesh = dog_mm
	dmi.material_override = Human.make_dog_material()
	dmi.custom_aabb = AABB(Vector3(-6000, -100, -6000), Vector3(12000, 600, 12000))
	add_child(dmi)


func _weights() -> Dictionary:
	match kind:
		"city":
			return {"office_m": 14, "office_f": 14, "kid": 7, "club_f": 9, "dogwalker": 9, "jogger": 8, "elder": 7, "courier": 8,
				"police": 4, "student": 10, "worker": 5, "tourist": 5}
		"farm":
			return {"farmer": 35, "kid": 10, "dogwalker": 15, "tourist": 10, "elder": 10, "worker": 10}
		_:
			return {"tourist": 30, "jogger": 15, "dogwalker": 20, "kid": 10, "elder": 10, "student": 5}


func _pick_type() -> String:
	var w := _weights()
	var total := 0
	for k in w:
		total += w[k]
	var r := randi() % total
	for k in w:
		r -= w[k]
		if r < 0:
			return k
	return "tourist"


func _spawn(ag: Dictionary, pos: Vector3) -> void:
	if real != null:
		real.release(ag)
	var tid := _pick_type()
	var def := Human.type_by_id(tid)
	ag.type = tid
	ag.v = def.speed * randf_range(0.85, 1.15)
	ag.base = def.speed
	ag.seed = randf()
	ag.walk = 1.0
	ag.dog = def.get("dog", false)
	ag.dp = Vector2.ZERO
	ag.dog_init = false
	ag.active = true
	ag.cw = "walk"
	ag.talk = false
	if kind == "city":
		ag.mode = "side"
		if randf() < 0.07 and _chat_count() < 16 and _spawn_chat(ag, pos):
			return
		var sp := _sidewalk_spot(pos)
		ag.p = sp[0]
		ag.a = sp[1]
	else:
		ag.mode = "wander"
		ag.active = false
		for k in 8:
			var ang := randf() * TAU
			var r := randf_range(35.0, 230.0)
			var p := Vector2(pos.x + cos(ang) * r, pos.z + sin(ang) * r)
			var h: float = terrain.height(p.x, p.y)
			var sl: float = absf(float(terrain.height(p.x + 6.0, p.y)) - h) + absf(float(terrain.height(p.x, p.y + 6.0)) - h)
			if h > 3.0 and h < 110.0 and sl < 7.0:
				ag.p = p
				ag.a = randf() * TAU
				ag.active = true
				break


## 인도 위의 한 지점과 걷는 방향을 고른다. 교차로 안(횡단보도·차도)은 피한다.
func _sidewalk_spot(pos: Vector3) -> Array:
	var axis_x := randf() < 0.5
	var dirn := 1.0 if randf() < 0.5 else -1.0
	var side := (RH + 2.0 + randf_range(0.0, 1.2)) * (1.0 if randf() < 0.5 else -1.0)
	var along := pos.x + randf_range(-230.0, 230.0) if axis_x else pos.z + randf_range(-230.0, 230.0)
	var line := roundf(((pos.z if axis_x else pos.x) + randf_range(-230.0, 230.0)) / CELL) * CELL
	if absf(along - roundf(along / CELL) * CELL) < RH + 3.0:
		along += 28.0
	if axis_x:
		return [Vector2(along, line + side), PI / 2.0 * dirn]
	return [Vector2(line + side, along), 0.0 if dirn > 0.0 else PI]


func _chat_count() -> int:
	var n := 0
	for a in agents:
		if a.get("cw", "") == "chat":
			n += 1
	return n


## 마주 보고 이야기하는 2~3명. 이 agent가 첫 사람이고, 나머지는 멀리 있는 다른 agent를 불러 온다.
func _spawn_chat(ag: Dictionary, pos: Vector3) -> bool:
	var sp := _sidewalk_spot(pos)
	var c: Vector2 = sp[0]
	var count := 2 if randf() < 0.7 else 3
	var spot := 0
	var ring := PackedVector2Array()
	for i in count:
		var ang := TAU * i / count + randf() * 0.3
		ring.append(c + Vector2(cos(ang), sin(ang)) * (0.55 if count == 2 else 0.8))
	_make_talker(ag, ring[0], c)
	var placed := 1
	var tries := 0
	while placed < count and tries < 30 and agents.size() > 4:
		tries += 1
		var o: Dictionary = agents[randi() % agents.size()]
		if o == ag or not o.get("active", false) or o.get("cw", "") == "chat":
			continue
		if Vector2(o.p.x - pos.x, o.p.y - pos.z).length() < 90.0:
			continue
		if real != null:
			real.release(o)
		_make_talker(o, ring[placed], c)
		placed += 1
	return true


func _make_talker(ag: Dictionary, p: Vector2, center: Vector2) -> void:
	var ok := false
	for k in 8:
		var tid := _pick_type()
		if tid != "jogger" and tid != "courier":
			ag.type = tid
			ok = true
			break
	if not ok:
		ag.type = "office_m"
	var def := Human.type_by_id(ag.type)
	ag.base = def.speed
	ag.v = def.speed
	ag.dog = false
	ag.mode = "side"
	ag.cw = "chat"
	ag.talk = true
	ag.walk = 0.0
	ag.p = p
	ag.a = atan2(center.x - p.x, center.y - p.y)
	ag.active = true


## 도시 보행: 인도를 걷다가 교차로 앞에서 (30%) 모퉁이를 돌거나 신호를 기다려 횡단보도를 건넌다.
func _city_step(ag: Dictionary, dt: float) -> void:
	var dv := Vector2(sin(ag.a), cos(ag.a))
	var axis_x := absf(dv.x) > 0.5
	var d := signf(dv.x if axis_x else dv.y)
	var c: float = ag.p.x if axis_x else ag.p.y
	var lat: float = ag.p.y if axis_x else ag.p.x
	var u := c * d
	var state: String = ag.cw
	var ui := ceilf((u + RH + 0.7) / CELL) * CELL
	if state == "walk":
		if (ui - (RH + 0.7)) - u < 0.2:
			var lc := roundf(lat / CELL) * CELL
			var ci := ui * d
			ag.ix = Vector2(ci, lc) if axis_x else Vector2(lc, ci)
			if randf() < 0.3:
				var s := signf(lat - lc)
				if axis_x:
					ag.a = 0.0 if s > 0.0 else PI
					ag.p = Vector2(ci - d * (RH + 2.4), lat)
				else:
					ag.a = PI / 2.0 if s > 0.0 else -PI / 2.0
					ag.p = Vector2(lat, ci - d * (RH + 2.4))
			else:
				ag.cw = "wait"
	elif state == "wait":
		var ix: Vector2 = ag.ix
		if traffic == null or traffic.ped_window(roundi(ix.x / CELL), roundi(ix.y / CELL), not axis_x):
			ag.cw = "cross"
	elif state == "cross":
		var ix2: Vector2 = ag.ix
		var cx: float = ix2.x if axis_x else ix2.y
		if (c - cx) * d > RH + 0.7:
			ag.cw = "walk"


func update(pos: Vector3, dt: float) -> void:
	if not enabled:
		return
	t += dt
	if not inited:
		inited = true
		var n := 140 if kind == "city" else (24 if kind == "farm" else 18)
		for i in n:
			var ag := {}
			_spawn(ag, pos)
			agents.append(ag)
	var slot := {}
	for k in mms:
		slot[k] = 0
	var dogs := 0
	sample_pos = Vector3.INF
	var crossers: Array = []
	for ag in agents:
		if not ag.active:
			if not lineup:
				_spawn(ag, pos)
			continue
		var p: Vector2 = ag.p
		var to_d := Vector2(pos.x - p.x, pos.z - p.y)
		var dist := to_d.length()
		if dist > 280.0 and not lineup:
			_spawn(ag, pos)
			continue
		var gy: float = terrain.height(p.x, p.y)
		if kind == "city" and not lineup:
			_city_step(ag, dt)
		var stand: bool = (lineup and ag.get("still", false)) or ag.get("cw", "walk") == "wait" or ag.get("cw", "walk") == "chat"
		ag.walk = move_toward(ag.walk, 0.0 if stand else 1.0, dt * 3.0)
		if ag.mode == "wander" and not lineup:
			ag.a += sin(t * 0.3 + ag.seed * 20.0) * 0.35 * dt
		if ag.get("cw", "walk") == "cross":
			crossers.append(ag.p)
		var dir := Vector2(sin(ag.a), cos(ag.a))
		if ag.walk > 0.05 and not lineup:
			var np: Vector2 = p + dir * (ag.v * ag.walk * dt)
			if ag.mode == "wander":
				var nh: float = terrain.height(np.x, np.y)
				if nh < 1.5 or absf(nh - gy) > 0.5 * ag.v * dt * 6.0:
					ag.a += PI * 0.8
				else:
					ag.p = np
					p = np
					gy = nh
			else:
				ag.p = np
				p = np
		var def := Human.type_by_id(ag.type)
		var sc: float = def.height / 1.8 * (0.96 + ag.seed * 0.1)
		var yaw := atan2(-dir.x, -dir.y)
		var bas := Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc, sc))
		var drawn := false
		if real != null:
			var dd := Vector3(to_d.x, pos.y - gy, to_d.y).length()
			if dd < (62.0 if ag.get("slot", -1) >= 0 else 48.0):
				drawn = real.draw(ag, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, gy, p.y)), 0.96 + ag.seed * 0.1)
		var mm: MultiMesh = mms[ag.type]
		var s: int = slot[ag.type]
		if drawn:
			if sample_pos == Vector3.INF:
				sample_pos = Vector3(p.x, gy, p.y)
		elif s < PER_TYPE:
			mm.set_instance_transform(s, Transform3D(bas, Vector3(p.x, gy, p.y)))
			mm.set_instance_custom_data(s, Color(ag.walk, ag.seed, ag.v / ag.base, 0.0))
			slot[ag.type] = s + 1
			if sample_pos == Vector3.INF:
				sample_pos = Vector3(p.x, gy, p.y)
		if ag.dog and dogs < MAX_DOGS:
			var right := Vector2(dir.y, -dir.x)
			var target: Vector2 = p + right * 1.0 - dir * 0.1
			if not ag.dog_init:
				ag.dp = target
				ag.dog_init = true
			ag.dp = ag.dp.lerp(target, 1.0 - exp(-6.0 * dt))
			var dgy: float = terrain.height(ag.dp.x, ag.dp.y)
			var dbas := Basis(Vector3.UP, yaw)
			dog_mm.set_instance_transform(dogs, Transform3D(dbas, Vector3(ag.dp.x, dgy, ag.dp.y)))
			dog_mm.set_instance_custom_data(dogs, Color(ag.walk, ag.seed, 1.0, 0.0))
			dogs += 1
	if real != null:
		real.finish()
	if traffic != null:
		traffic.peds = crossers
	for k in mms:
		mms[k].visible_instance_count = slot[k]
	dog_mm.visible_instance_count = dogs


## 개발용 점검: 상태별 인원
func stats() -> Dictionary:
	var s := {"walk": 0, "wait": 0, "cross": 0, "chat": 0}
	for ag in agents:
		if ag.get("active", false):
			s[ag.get("cw", "walk")] += 1
	return s


## 개발용: 모든 종류를 한 줄로 세운다(제자리 걷기)
func debug_lineup(center: Vector3, yaw_deg: float) -> void:
	lineup = true
	agents.clear()
	inited = true
	var yaw := deg_to_rad(yaw_deg)
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var rgt := Vector2(cos(yaw), -sin(yaw))
	var i := 0
	for ty in Human.types():
		var ag := {"type": ty.id, "v": ty.speed, "base": ty.speed, "seed": (i * 0.137) + 0.05, "walk": 1.0, "dog": ty.get("dog", false),
			"dp": Vector2.ZERO, "dog_init": false, "active": true, "mode": "side", "still": false}
		ag.p = Vector2(center.x, center.z) + rgt * ((i - 6) * 1.5)
		ag.a = atan2(-fwd.x, -fwd.y)
		agents.append(ag)
		i += 1
