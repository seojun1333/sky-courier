extends Node3D
## 전투 관리자: 드론 대전(웨이브)·괴물 사냥. 기관포·유도탄·록온, 적 생성, 탄환, 드랍·보급 아이템, HUD 데이터.

const EnemyScript := preload("res://enemy.gd")
const ItemsScript := preload("res://items.gd")
const UI := preload("res://ui.gd")

signal reward(info: Dictionary)

const START_AMMO := 600
const START_MISSILES := 5
const AMMO_MAX := 1500
const MISSILE_MAX := 12
const MAG_AMOUNT := 250
const PICKUP_RESPAWN := 30.0
const CELL := 260.0
const DMG_MULT := 1.6          # 적 공격력 배율

var main: Node
var drone: Node3D
var terrain: Node3D
var buildings: Node3D
var fx: Node
var audio: Node
var mode := "hunt"
var world: Dictionary = {}
var enemies: Array = []
var bullets: Array = []
var missiles: Array = []
var drops: Array = []
var pickups := {}
var pk_cd := {}

var ammo := START_AMMO
var missile_n := START_MISSILES
var fire_t := 0.0
var mis_cd := 0.0
var lock_target: Node3D = null
var lock_prog := 0.0
var locked := false
var lock_lost := 0.0
var lock_tick_t := 0.0
var hit_marker := 0.0
var kill_marker := false
var hurt_flash := 0.0
var dmg_marks: Array = []
var shake := 0.0
var wave := 0
var wave_active := false
var wave_t := 3.0
var kills := 0
var boss_kills := 0
var since_boss := 0
var spawn_t := 2.0
var warn_t := 0.0
var warn_on := false
var no_ammo_t := 0.0
var rng := RandomNumberGenerator.new()
var mm_tracer: MultiMeshInstance3D
var mm_orb: MultiMeshInstance3D
var banner_msg := ""
var test_fire := false


func setup(m: Node) -> void:
	main = m
	drone = m.drone
	terrain = m.terrain
	buildings = m.buildings
	fx = m.fx
	audio = m.audio
	world = m.world
	mode = m.game_mode
	rng.randomize()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.07, 0.07, 2.2)
	mm_tracer = _make_mm(tm, 420)
	var om := SphereMesh.new()
	om.radius = 0.5
	om.height = 1.0
	om.radial_segments = 10
	om.rings = 5
	mm_orb = _make_mm(om, 200)


func _make_mm(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-9000, -9000, -9000), Vector3(18000, 18000, 18000))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# ---------------------------------------------------------------- 매 프레임
func update(dt: float) -> void:
	var cam: Camera3D = drone.cam
	hit_marker = maxf(0.0, hit_marker - dt)
	hurt_flash = maxf(0.0, hurt_flash - dt * 1.6)
	shake = maxf(0.0, shake - dt * 2.5)
	mis_cd = maxf(0.0, mis_cd - dt)
	no_ammo_t = maxf(0.0, no_ammo_t - dt)
	for mk in dmg_marks:
		mk.t -= dt
	dmg_marks = dmg_marks.filter(func(m: Dictionary) -> bool: return m.t > 0.0)
	_resupply(dt)
	_spawn_logic(dt)
	for e in enemies:
		if is_instance_valid(e):
			e.tick(dt)
	_cull_enemies()
	_player_weapons(dt, cam)
	_update_lock(dt, cam)
	_update_bullets(dt)
	_update_missiles(dt)
	_update_drops(dt)
	_update_pickups(dt)
	_render_bullets()


func alive_count() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and e.alive:
			n += 1
	return n


func _cull_enemies() -> void:
	var keep: Array = []
	var P := drone.position
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.alive and e.position.distance_to(P) > 650.0:
			e.queue_free()
			continue
		keep.append(e)
	enemies = keep


# ---------------------------------------------------------------- 기지 보급
func _resupply(dt: float) -> void:
	if drone.state == "idle" and Vector2(drone.position.x - drone.home.x, drone.position.z - drone.home.z).length() < 9.0:
		if ammo < START_AMMO or missile_n < START_MISSILES or drone.hp < drone.hp_max:
			drone.hp = minf(drone.hp_max, drone.hp + 30.0 * dt)
			ammo = maxi(ammo, mini(START_AMMO, ammo + int(120.0 * dt) + 1))
			if missile_n < START_MISSILES and fmod(Time.get_ticks_msec() / 1000.0, 1.0) < dt:
				missile_n += 1


func on_player_down() -> void:
	ammo = maxi(ammo, 300)
	missile_n = maxi(missile_n, 3)
	lock_target = null
	locked = false
	lock_prog = 0.0


# ---------------------------------------------------------------- 내 무기
func _aim_dir(cam: Camera3D) -> Vector3:
	var fwd := -cam.global_basis.z
	var origin := cam.global_position
	# 약한 조준 보정: 십자선 가까이 있는 적 쪽으로 살짝 끌어당긴다
	var best: Node3D = null
	var best_a := 0.09
	for e in enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var to: Vector3 = e.center() - origin
		var d := to.length()
		if d > 320.0 or d < 3.0:
			continue
		var a := fwd.angle_to(to)
		if a < best_a:
			best_a = a
			best = e
	if best != null:
		var tgt: Vector3 = best.center() + best.vel * (best.center().distance_to(origin) / 230.0)
		fwd = fwd.slerp((tgt - origin).normalized(), 0.65).normalized()
	return fwd


func _player_weapons(dt: float, cam: Camera3D) -> void:
	var want_fire := test_fire or (Input.is_action_pressed("fire") and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.get_connected_joypads().size() > 0))
	fire_t -= dt
	if want_fire and drone.state != "crashed":
		if ammo > 0:
			while fire_t <= 0.0 and ammo > 0:
				fire_t += 1.0 / 13.0
				var dir := _aim_dir(cam)
				var origin: Vector3 = drone.position + dir * 3.2 + Vector3(0, -0.1, 0)
				var sd := deg_to_rad(0.5)
				dir = (dir + Vector3(rng.randf_range(-sd, sd), rng.randf_range(-sd, sd), rng.randf_range(-sd, sd))).normalized()
				bullets.append({"p": origin, "prev": origin, "v": dir * 230.0 + drone.vel * 0.5, "life": 1.5, "dmg": 7.0, "team": 0,
					"col": Color(0.6, 1.0, 1.0), "shape": 0, "size": 1.0, "grav": 0.0})
				audio.gun()
				drone.mouse_acc += Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.8, 0.0))
				shake = maxf(shake, 0.12)
		else:
			fire_t = 0.0
			if no_ammo_t <= 0.0:
				no_ammo_t = 1.2
				pass
				audio.deny()
	else:
		fire_t = minf(fire_t, 0.0)


func fire_missile() -> void:
	if drone.state == "crashed":
		return
	if mis_cd > 0.0:
		return
	if missile_n <= 0:
		main.hud.show_toast("유도탄 없음", 1.4, Color(1.0, 0.5, 0.4))
		audio.deny()
		return
	if not locked or lock_target == null or not is_instance_valid(lock_target) or not lock_target.alive:
		main.hud.show_toast("록온 필요 — 적을 화면 가운데에 두세요", 1.6, Color(1.0, 0.8, 0.4))
		audio.deny()
		return
	missile_n -= 1
	mis_cd = 1.1
	var cam: Camera3D = drone.cam
	var dir := -cam.global_basis.z
	_spawn_missile(drone.position + Vector3(0, -0.3, 0) + dir * 1.5, dir, lock_target, 0)
	audio.missile()
	shake = maxf(shake, 0.3)


func _update_lock(dt: float, cam: Camera3D) -> void:
	var fwd := -cam.global_basis.z
	var origin := cam.global_position
	var best: Node3D = null
	var best_a := 0.3
	for e in enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var to: Vector3 = e.center() - origin
		var d := to.length()
		if d > 400.0 or d < 6.0:
			continue
		var a := fwd.angle_to(to)
		if a < best_a:
			best_a = a
			best = e
	if locked:
		if lock_target == null or not is_instance_valid(lock_target) or not lock_target.alive:
			locked = false
			lock_prog = 0.0
			lock_target = null
			return
		var a2 := fwd.angle_to(lock_target.center() - origin)
		if a2 > 0.55:
			lock_lost += dt
			if lock_lost > 0.6:
				locked = false
				lock_prog = 0.0
				lock_target = null
		else:
			lock_lost = 0.0
		return
	if best == null:
		lock_prog = 0.0
		lock_target = null
		return
	if best != lock_target:
		lock_target = best
		lock_prog = 0.0
	lock_prog += dt / 0.85
	lock_tick_t -= dt
	if lock_tick_t <= 0.0:
		lock_tick_t = 0.18
		audio.lock_tick()
	if lock_prog >= 1.0:
		locked = true
		lock_lost = 0.0
		audio.lock_ok()


# ---------------------------------------------------------------- 탄환
func enemy_shot(pos: Vector3, dir: Vector3, speed: float, dmg: float, col: Color, shape := 0, life := 2.0, grav := 0.0, size := 0.0) -> void:
	if bullets.size() > 380:
		return
	bullets.append({"p": pos, "prev": pos, "v": dir * speed, "life": life, "dmg": dmg, "team": 1, "col": col, "shape": shape,
		"size": size if size > 0.0 else 1.0, "grav": grav})
	var d := pos.distance_to(drone.position)
	if shape == 0:
		audio.egun(-10.0 - d / 25.0)


func audio_pop(p: Vector3) -> void:
	audio.pop(-6.0 - p.distance_to(drone.position) / 20.0)


func _update_bullets(dt: float) -> void:
	var keep: Array = []
	var P: Vector3 = drone.position
	for b in bullets:
		b.prev = b.p
		b.v.y -= float(b.grav) * dt
		b.p += b.v * dt
		b.life -= dt
		var dead: bool = b.life <= 0.0
		if not dead:
			var g: float = terrain.ground(b.p.x, b.p.z)
			if b.p.y < g:
				dead = true
				if int(b.shape) == 1:
					fx.burst(b.p, b.col, 12, 6.0, 0.18)
		if not dead and int(b.team) == 0:
			for e in enemies:
				if is_instance_valid(e) and e.alive and e.segment_hit(b.prev, b.p, 0.3):
					e.hurt(float(b.dmg), b.p, (b.v as Vector3).normalized(), "bullet")
					hit_marker = 0.18
					kill_marker = not e.alive
					audio.hit()
					dead = true
					break
		elif not dead:
			var ab: Vector3 = b.p - b.prev
			var l2 := ab.length_squared()
			var tt := 0.0 if l2 < 0.0001 else clampf((P - b.prev).dot(ab) / l2, 0.0, 1.0)
			var hr := 1.5 + (float(b.size) * 0.6 if int(b.shape) == 1 else 0.0)
			if (b.prev + ab * tt).distance_squared_to(P) < hr * hr and drone.state != "crashed":
				hurt_player(float(b.dmg), b.prev)
				if int(b.shape) == 1:
					fx.burst(b.p, b.col, 14, 6.0, 0.2)
				dead = true
		if not dead:
			keep.append(b)
	bullets = keep


func _render_bullets() -> void:
	var mt: MultiMesh = mm_tracer.multimesh
	var mo: MultiMesh = mm_orb.multimesh
	var nt := 0
	var no := 0
	for b in bullets:
		var v: Vector3 = b.v
		if int(b.shape) == 0:
			if nt >= mt.instance_count:
				continue
			var basis := Basis.looking_at(v.normalized(), Vector3.UP if absf(v.normalized().y) < 0.99 else Vector3.RIGHT)
			mt.set_instance_transform(nt, Transform3D(basis, b.p))
			mt.set_instance_color(nt, b.col)
			nt += 1
		else:
			if no >= mo.instance_count:
				continue
			var s: float = float(b.size) * 2.0
			mo.set_instance_transform(no, Transform3D(Basis().scaled(Vector3(s, s, s)), b.p))
			mo.set_instance_color(no, b.col)
			no += 1
	mt.visible_instance_count = nt
	mo.visible_instance_count = no


# ---------------------------------------------------------------- 유도탄
func enemy_missile(e: Node3D) -> void:
	var dir: Vector3 = (drone.position - e.position).normalized()
	_spawn_missile(e.position + dir * 2.0, dir, null, 1)
	audio.missile()
	main.hud.show_toast("미사일 경보!", 1.4, Color(1.0, 0.35, 0.3))


func _spawn_missile(pos: Vector3, dir: Vector3, tgt: Node3D, team: int) -> void:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.16
	cm.height = 1.5
	body.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.9, 0.9, 0.92) if team == 0 else Color(0.8, 0.15, 0.12)
	bm.metallic = 0.4
	bm.roughness = 0.4
	body.material_override = bm
	body.rotation.x = PI * 0.5
	n.add_child(body)
	var nose := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.0
	nm.bottom_radius = 0.16
	nm.height = 0.5
	nose.mesh = nm
	nose.material_override = bm
	nose.rotation.x = PI * 0.5
	nose.position = Vector3(0, 0, -1.0)
	n.add_child(nose)
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.15
	fm.height = 0.5
	flame.mesh = fm
	var flm := StandardMaterial3D.new()
	flm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flm.albedo_color = Color(1.0, 0.7, 0.25)
	flame.material_override = flm
	flame.position = Vector3(0, 0, 0.9)
	n.add_child(flame)
	var tr := CPUParticles3D.new()
	tr.amount = 36
	tr.lifetime = 1.1
	tr.local_coords = false
	tr.direction = Vector3(0, 0, 1)
	tr.spread = 8.0
	tr.initial_velocity_min = 1.0
	tr.initial_velocity_max = 3.0
	tr.gravity = Vector3(0, 0.6, 0)
	tr.scale_amount_min = 0.7
	tr.scale_amount_max = 1.6
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sm.radial_segments = 6
	sm.rings = 3
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.8, 0.8, 0.82, 0.4)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = smat
	tr.mesh = sm
	tr.position = Vector3(0, 0, 1.0)
	n.add_child(tr)
	add_child(n)
	n.global_position = pos
	missiles.append({"n": n, "p": pos, "v": dir * (30.0 if team == 0 else 24.0), "tgt": tgt, "team": team, "life": 7.0 if team == 0 else 6.0})


func _update_missiles(dt: float) -> void:
	var keep: Array = []
	var P: Vector3 = drone.position
	warn_on = false
	for m in missiles:
		var team: int = m.team
		var v: Vector3 = m.v
		var spd := v.length()
		var vmax := 90.0 if team == 0 else 50.0
		var accel := 80.0 if team == 0 else 30.0
		var turn := 3.4 if team == 0 else 1.25
		var dir := v.normalized()
		var want := dir
		if team == 0:
			var t: Node3D = m.tgt
			if t != null and is_instance_valid(t) and t.alive:
				want = ((t.center() + t.vel * 0.15) - m.p).normalized()
		else:
			want = (P - m.p).normalized()
		var ang := dir.angle_to(want)
		if ang > 0.0001:
			dir = dir.slerp(want, minf(1.0, turn * dt / ang)).normalized()
		spd = minf(spd + accel * dt, vmax)
		m.v = dir * spd
		m.p += m.v * dt
		m.life -= dt
		var n: Node3D = m.n
		n.global_position = m.p
		n.global_basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
		var boom: bool = m.life <= 0.0
		if not boom and m.p.y < float(terrain.ground(m.p.x, m.p.z)):
			boom = true
		if not boom and team == 0:
			for e in enemies:
				if is_instance_valid(e) and e.alive and m.p.distance_to(e.center()) < e.rad + 2.2:
					boom = true
					break
		if not boom and team == 1:
			var dp: float = m.p.distance_to(P)
			if dp < 3.2:
				boom = true
			if dp < 230.0:
				warn_on = true
		if boom:
			_explode(m.p, 10.0 if team == 0 else 7.0, 90.0 if team == 0 else 26.0, team)
			n.queue_free()
		else:
			keep.append(m)
	missiles = keep
	if warn_on:
		warn_t -= dt
		if warn_t <= 0.0:
			warn_t = 0.45
			audio.warn()


func _explode(p: Vector3, radius: float, dmg: float, team: int) -> void:
	fx.explosion(p, 1.0 if team == 0 else 0.8)
	var d := p.distance_to(drone.position)
	audio.explode(-4.0 - d / 30.0)
	if d < 120.0:
		shake = maxf(shake, clampf(1.0 - d / 120.0, 0.0, 1.0) * 0.9)
	if team == 0:
		for e in enemies.duplicate():
			if is_instance_valid(e) and e.alive:
				var de: float = p.distance_to(e.center()) - e.rad
				if de < radius:
					e.hurt(dmg * (1.0 - 0.55 * clampf(de / radius, 0.0, 1.0)), p, (e.center() - p).normalized(), "missile")
					hit_marker = 0.25
					kill_marker = not e.alive
	elif d < radius:
		hurt_player(dmg * (1.0 - 0.5 * d / radius), p)


func shockwave(pos: Vector3, radius: float, dmg: float) -> void:
	fx.burst(pos + Vector3(0, 0.5, 0), Color(0.55, 0.45, 0.35), 40, 18.0, 0.4)
	audio.explode(-6.0 - pos.distance_to(drone.position) / 30.0)
	shake = maxf(shake, 0.4)
	var P: Vector3 = drone.position
	var hd := Vector2(P.x - pos.x, P.z - pos.z).length()
	if hd < radius and P.y < pos.y + 14.0:
		hurt_player(dmg * (1.0 - 0.4 * hd / radius), pos)


func hurt_player(dmg: float, from: Vector3) -> void:
	if drone.state == "crashed":
		return
	drone.hurt(dmg * DMG_MULT)
	audio.hurt()
	hurt_flash = 1.0
	shake = maxf(shake, 0.5)
	dmg_marks.append({"w": from, "t": 1.4})


# ---------------------------------------------------------------- 적 생성
func _spawn_logic(dt: float) -> void:
	if mode == "duel":
		var n := alive_count()
		if wave_active:
			if n == 0:
				wave_active = false
				wave_t = 5.0
				var bonus := 25 * wave
				reward.emit({"name": "WAVE %d 클리어" % wave, "coins": bonus, "xp": 10 + 4 * wave, "items": {}, "wave": true})
				main.hud.show_banner("WAVE %d 클리어!" % wave, 3.0, Color(0.5, 1.0, 0.6))
		else:
			wave_t -= dt
			if wave_t <= 0.0:
				_start_wave()
	else:
		spawn_t -= dt
		var rank: int = main.profile.rank()
		var want := clampi(3 + rank / 2 + kills / 12, 3, 8)
		var normal := 0
		var boss := false
		for e in enemies:
			if is_instance_valid(e) and e.alive:
				if e.is_boss():
					boss = true
				else:
					normal += 1
		if spawn_t <= 0.0 and normal < want:
			spawn_t = rng.randf_range(2.0, 4.0)
			if since_boss >= 14 and not boss:
				since_boss = 0
				_spawn("eye")
				main.hud.show_banner("공허의 눈이 나타났다!", 3.0, Color(0.95, 0.3, 0.6))
			else:
				var pool: Array = [["slime", 40]]
				pool.append(["bat", 30])
				if rank >= 2:
					pool.append(["golem", 18])
				if rank >= 4:
					pool.append(["wyvern", 12])
				var k := _pick(pool)
				if k == "bat":
					for i in 3:
						_spawn("bat")
				else:
					_spawn(k)


func _pick(pool: Array) -> String:
	var tot := 0
	for p in pool:
		tot += int(p[1])
	var r := rng.randi() % maxi(tot, 1)
	for p in pool:
		r -= int(p[1])
		if r < 0:
			return String(p[0])
	return String(pool[0][0])


func _start_wave() -> void:
	wave += 1
	wave_active = true
	var n := mini(2 + wave, 9)
	var list: Array = []
	for i in n:
		var pool: Array = [["scout", 60]]
		if wave >= 2:
			pool.append(["gunship", 35])
		if wave >= 3:
			pool.append(["striker", 25])
		list.append(_pick(pool))
	if wave % 3 == 0:
		list[0] = "ace"
	for k in list:
		_spawn(k)
	main.hud.show_banner("WAVE %d  —  적 %d기" % [wave, list.size()], 3.0, Color(1.0, 0.55, 0.4))
	main.hud.show_radio("관제 노을: 「적 반응 %d기! 탄창은 하늘에 떠 있어요, 잘 찾아봐요.」" % list.size(), 6.0)


func spawn_at(k: String, pos: Vector3) -> Node3D:
	var e: Node3D = EnemyScript.new()
	e.setup(k, self)
	e.position = pos
	add_child(e)
	enemies.append(e)
	return e


func _spawn(k: String) -> void:
	var T: Dictionary = EnemyScript.TYPES[k]
	var P: Vector3 = drone.position
	var fwd: Vector3 = -drone.cam.global_basis.z
	var base_a := atan2(fwd.z, fwd.x)
	var pos := Vector3.ZERO
	var ok := false
	for i in 10:
		var a := base_a + rng.randf_range(-1.3, 1.3)
		var d := rng.randf_range(110.0, 175.0) if bool(T.fly) else rng.randf_range(85.0, 140.0)
		pos = Vector3(P.x + cos(a) * d, 0.0, P.z + sin(a) * d)
		var g: float = terrain.ground(pos.x, pos.z)
		if bool(T.fly):
			pos.y = maxf(g + 14.0, P.y + rng.randf_range(0.0, 25.0))
			ok = true
			break
		if terrain.height(pos.x, pos.z) > 0.8:
			pos.y = g
			ok = true
			break
	if not ok:
		pos = Vector3(P.x + 120.0, terrain.ground(P.x + 120.0, P.z), P.z)
	spawn_at(k, pos)


# ---------------------------------------------------------------- 처치·드랍
func on_enemy_die(e: Node3D) -> void:
	var T: Dictionary = e.T
	var items := {}
	var bounty := 1.0 + 0.15 * int(drone.lv.get("bounty", 0))
	for d in T.drops:
		if String(d[0]) == "mag":
			continue
		if rng.randf() <= float(d[1]):
			var n := rng.randi_range(int(d[2]), int(d[3]))
			_spawn_drop(String(d[0]), n, e.center() + Vector3(rng.randf_range(-2, 2), 0.5, rng.randf_range(-2, 2)))
			if not (String(d[0]) in ["mag", "missile", "repair"]):
				items[String(d[0])] = n
	kills += 1
	since_boss += 1
	if e.is_boss():
		boss_kills += 1
		fx.slowmo(0.7, 0.35)
		main.hud.show_banner("%s 처치!" % String(T.name).replace(" (보스)", ""), 3.5, Color(1.0, 0.8, 0.3))
	audio.kill()
	reward.emit({"name": T.name, "coins": int(round(float(T.coins) * bounty)), "xp": int(T.xp), "items": items, "boss": e.is_boss(), "wave": false})


func _spawn_drop(kind: String, n: int, pos: Vector3) -> void:
	var col := Color.WHITE
	var txt := ""
	match kind:
		"mag":
			col = Color(1.0, 0.75, 0.2)
			txt = "탄창 +%d" % MAG_AMOUNT
		"missile":
			col = Color(1.0, 0.4, 0.35)
			txt = "유도탄 +%d" % n
		"repair":
			col = Color(0.4, 1.0, 0.55)
			txt = "수리 키트"
		_:
			var inf: Dictionary = ItemsScript.info(kind)
			col = inf.color
			txt = "%s ×%d" % [inf.name, n]
	var node := _make_item_node(kind, col, txt, 1.0)
	add_child(node)
	node.global_position = pos
	drops.append({"n": node, "p": pos, "vy": 6.0, "kind": kind, "cnt": n, "life": 80.0, "col": col, "txt": txt})


func _update_drops(dt: float) -> void:
	var keep: Array = []
	var P: Vector3 = drone.position
	var rad := 5.0 + 1.5 * int(drone.lv.get("magnet", 0))
	var pull := 16.0 + 6.0 * int(drone.lv.get("magnet", 0))
	for d in drops:
		d.life -= dt
		var n: Node3D = d.n
		var g: float = maxf(float(terrain.ground(d.p.x, d.p.z)), 0.0) + 1.6
		if d.p.y > g or d.vy > 0.0:
			d.vy -= 14.0 * dt
			d.p.y = maxf(d.p.y + d.vy * dt, g)
			if d.p.y <= g:
				d.vy = 0.0
		var dist: float = d.p.distance_to(P)
		if dist < pull and drone.state != "crashed":
			d.p += (P - d.p).normalized() * (14.0 + (pull - dist)) * dt
		n.global_position = d.p + Vector3(0, sin(Time.get_ticks_msec() / 400.0 + d.p.x) * 0.25, 0)
		_animate_item(n, dist, dt)
		if dist < rad and drone.state != "crashed":
			_collect(String(d.kind), int(d.cnt), String(d.txt))
			n.queue_free()
			continue
		if d.life <= 0.0:
			n.queue_free()
			continue
		keep.append(d)
	drops = keep


func _collect(kind: String, n: int, txt: String) -> void:
	audio.pick()
	main.hud.show_toast(txt, 1.6, Color(1.0, 0.95, 0.6))
	fx.burst(drone.position, Color(1.0, 0.9, 0.5), 12, 5.0, 0.07)
	match kind:
		"mag": ammo = mini(AMMO_MAX, ammo + MAG_AMOUNT)
		"missile": missile_n = mini(MISSILE_MAX, missile_n + n)
		"repair": drone.hp = minf(drone.hp_max, drone.hp + drone.hp_max * 0.45)
		_: main.add_loot(kind, n)


# ---------------------------------------------------------------- 공중 보급 아이템(30초 리젠)
func _hash(ix: int, iz: int, salt: int) -> int:
	var h := ix * 73856093 ^ iz * 19349663 ^ salt * 83492791
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


func _update_pickups(dt: float) -> void:
	for k in pk_cd.keys():
		pk_cd[k] -= dt
		if pk_cd[k] <= 0.0:
			pk_cd.erase(k)
	var P: Vector3 = drone.position
	var cx := int(floor(P.x / CELL))
	var cz := int(floor(P.z / CELL))
	for ix in range(cx - 2, cx + 3):
		for iz in range(cz - 2, cz + 3):
			var key := "%d,%d" % [ix, iz]
			if pickups.has(key) or pk_cd.has(key):
				continue
			if _hash(ix, iz, 1) % 100 >= 55:
				continue
			var r := _hash(ix, iz, 2) % 100
			var kind := "missile" if r < 65 else "repair"
			var px := (ix + 0.15 + float(_hash(ix, iz, 3) % 70) / 100.0) * CELL
			var pz := (iz + 0.15 + float(_hash(ix, iz, 4) % 70) / 100.0) * CELL
			var gy: float = terrain.ground(px, pz)
			var py := gy + (75.0 if world.kind == "city" else 34.0) + float(_hash(ix, iz, 5) % 22)
			var col := Color(1.0, 0.75, 0.2)
			var txt := "탄창 +%d" % MAG_AMOUNT
			if kind == "missile":
				col = Color(1.0, 0.4, 0.35)
				txt = "유도탄 +1"
			elif kind == "repair":
				col = Color(0.4, 1.0, 0.55)
				txt = "수리 키트"
			var node := _make_item_node(kind, col, txt, 1.35)
			add_child(node)
			node.global_position = Vector3(px, py, pz)
			pickups[key] = {"n": node, "p": Vector3(px, py, pz), "kind": kind, "txt": txt}
	var rad := 6.5 + 1.5 * int(drone.lv.get("magnet", 0))
	for key in pickups.keys():
		var pk: Dictionary = pickups[key]
		var n: Node3D = pk.n
		var dist: float = pk.p.distance_to(P)
		if dist > 900.0:
			n.queue_free()
			pickups.erase(key)
			continue
		n.global_position = pk.p + Vector3(0, sin(Time.get_ticks_msec() / 500.0 + pk.p.x) * 0.6, 0)
		_animate_item(n, dist, dt)
		if dist < rad and drone.state != "crashed":
			_collect(String(pk.kind), 1, String(pk.txt))
			n.queue_free()
			pickups.erase(key)
			pk_cd[key] = PICKUP_RESPAWN


func _animate_item(n: Node3D, dist: float, dt: float) -> void:
	var ring: Node3D = n.get_meta("ring")
	ring.rotate_y(dt * 2.4)
	var core: Node3D = n.get_meta("core")
	core.rotate_y(dt * 1.6)
	var lb: Label3D = n.get_meta("label")
	lb.visible = dist < 140.0


func _make_item_node(kind: String, col: Color, txt: String, big: float) -> Node3D:
	var n := Node3D.new()
	var em := StandardMaterial3D.new()
	em.albedo_color = col
	em.emission_enabled = true
	em.emission = col
	em.emission_energy_multiplier = 2.2
	em.roughness = 0.3
	var core := Node3D.new()
	n.add_child(core)
	match kind:
		"mag":
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.8, 1.0, 0.45) * big
			b.mesh = bm
			b.material_override = em
			core.add_child(b)
			for i in 3:
				var c := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.09 * big
				cm.bottom_radius = 0.09 * big
				cm.height = 0.5 * big
				c.mesh = cm
				c.position = Vector3((i - 1) * 0.22 * big, 0.7 * big, 0)
				var bm2 := StandardMaterial3D.new()
				bm2.albedo_color = Color(0.9, 0.85, 0.6)
				bm2.metallic = 0.8
				bm2.roughness = 0.25
				c.material_override = bm2
				core.add_child(c)
		"missile":
			var c2 := MeshInstance3D.new()
			var cm2 := CylinderMesh.new()
			cm2.top_radius = 0.2 * big
			cm2.bottom_radius = 0.2 * big
			cm2.height = 1.6 * big
			c2.mesh = cm2
			c2.material_override = em
			c2.rotation.z = PI * 0.5
			core.add_child(c2)
			var nz := MeshInstance3D.new()
			var nm := CylinderMesh.new()
			nm.top_radius = 0.0
			nm.bottom_radius = 0.2 * big
			nm.height = 0.5 * big
			nz.mesh = nm
			nz.material_override = em
			nz.rotation.z = -PI * 0.5
			nz.position = Vector3(1.0 * big, 0, 0)
			core.add_child(nz)
		"repair":
			for r in [Vector3(1.0, 0.3, 0.3), Vector3(0.3, 1.0, 0.3)]:
				var b3 := MeshInstance3D.new()
				var bm3 := BoxMesh.new()
				bm3.size = r * 0.9 * big
				b3.mesh = bm3
				b3.material_override = em
				core.add_child(b3)
		_:
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.5 * big
			sm.height = 1.0 * big
			sm.radial_segments = 10
			sm.rings = 5
			s.mesh = sm
			s.material_override = em
			core.add_child(s)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.05 * big
	tm.outer_radius = 1.2 * big
	ring.mesh = tm
	ring.material_override = em
	ring.rotation.x = 0.5
	var rn := Node3D.new()
	rn.add_child(ring)
	n.add_child(rn)
	var beam := MeshInstance3D.new()
	var cm3 := CylinderMesh.new()
	cm3.top_radius = 0.1
	cm3.bottom_radius = 0.1
	cm3.height = 36.0
	beam.mesh = cm3
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(col.r, col.g, col.b, 0.28)
	beam.material_override = bmat
	beam.position = Vector3(0, 18, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(beam)
	var lb := Label3D.new()
	lb.text = txt
	lb.font = UI.font("body")
	lb.font_size = 56
	lb.pixel_size = 0.014 * big
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.modulate = col.lightened(0.35)
	lb.outline_size = 12
	lb.position = Vector3(0, 2.1 * big, 0)
	lb.no_depth_test = true
	n.add_child(lb)
	n.set_meta("ring", rn)
	n.set_meta("core", core)
	n.set_meta("label", lb)
	return n


# ---------------------------------------------------------------- HUD
func hud_data() -> Dictionary:
	var cam: Camera3D = drone.cam
	var list: Array = []
	var cpos := cam.global_position
	var cyaw := cam.global_basis
	for e in enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var c: Vector3 = e.center()
		var behind := cam.is_position_behind(c)
		var top := cam.unproject_position(c + Vector3(0, e.rad + 0.8, 0))
		var rel := cyaw.inverse() * (c - cpos)
		list.append({"scr": top, "behind": behind, "name": e.T.name, "hp": e.hp / e.hp_max, "dist": cpos.distance_to(c), "boss": e.is_boss(),
			"tier": int(e.T.tier), "locked": e == lock_target and locked, "locking": e == lock_target and not locked and lock_prog > 0.0,
			"ang": atan2(rel.x, -rel.z), "scr_c": cam.unproject_position(c)})
	var marks: Array = []
	for m in dmg_marks:
		var rel2 := cyaw.inverse() * ((m.w as Vector3) - cpos)
		marks.append({"ang": atan2(rel2.x, -rel2.z), "a": clampf(m.t, 0.0, 1.0)})
	# 가장 가까운 공중 보급품 방향
	var pk_d := 1.0e9
	var pk_b := 0.0
	var pk_kind := ""
	var P: Vector3 = drone.position
	for key in pickups:
		var d: float = pickups[key].p.distance_to(P)
		if d < pk_d:
			pk_d = d
			var to: Vector3 = pickups[key].p - P
			pk_b = fposmod(rad_to_deg(atan2(to.x, -to.z)), 360.0)
			pk_kind = pickups[key].kind
	var dr_d := 1.0e9
	var dr_b := 0.0
	for d2 in drops:
		var dd: float = d2.p.distance_to(P)
		if dd < dr_d:
			dr_d = dd
			var to2: Vector3 = d2.p - P
			dr_b = fposmod(rad_to_deg(atan2(to2.x, -to2.z)), 360.0)
	return {"on": true, "mode": mode, "hp": drone.hp, "hp_max": drone.hp_max, "ammo": ammo, "missiles": missile_n,
		"lock": lock_prog, "locked": locked, "enemies": list, "hitm": hit_marker, "kill": kill_marker, "marks": marks,
		"wave": wave, "left": alive_count(), "kills": kills, "warn": warn_on, "hurt": hurt_flash, "wave_wait": (not wave_active) and mode == "duel",
		"wave_t": wave_t, "pk_d": pk_d, "pk_b": pk_b, "pk_kind": pk_kind, "dr_d": dr_d, "dr_b": dr_b, "boss_kills": boss_kills}
