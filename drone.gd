extends Node3D
## 1인칭 FPV 드론: 비행 물리, 배터리, 신호, 카메라 진동, 프로펠러.

const DroneModel := preload("res://dronemodel.gd")
const G := 9.81
const LED_COLORS := [Color(0.2, 1, 0.45), Color(0.2, 0.8, 1), Color(1, 0.3, 0.9), Color(1, 0.6, 0.15), Color(1, 0.25, 0.25), Color(1, 1, 1)]

signal crashed(reason: String)

var terrain: Node3D
var cam: Camera3D
var lv := {"speed": 0, "battery": 0, "gimbal": 0, "signal": 0, "color": 0, "magnet": 0, "zoom": 0, "bounty": 0}
var home := Vector3.ZERO
var vel := Vector3.ZERO
var yaw := 0.0
var tp := 0.0           # 앞뒤 기울기(앞이 +)
var tr := 0.0           # 좌우 기울기(오른쪽이 +)
var cam_tilt := 22.0
var battery := 100.0
var state := "idle"     # idle(착륙) flying crashed
var rpm := 0.0
var crash_t := 0.0
var crash_reason := ""
var signal_q := 1.0
var signal_lost_t := 0.0
var flight_time := 0.0
var odometer := 0.0
var gust := 0.0
var inp := {"fwd": 0.0, "right": 0.0, "yaw": 0.0, "thr": 0.0, "boost": 0.0}
var mouse_acc := Vector2.ZERO
var prop_nodes: Array[Node3D] = []
var led_mats: Array[StandardMaterial3D] = []
var cam_fov := 88.0
var test_input := {}   # 개발용: 값이 있으면 키보드 대신 사용
var buildings: Node3D = null
var traffic: Node3D = null
var indoor := 0.0
var climb_h_gain := 2.7     # 수평 추력 배율(이동 속도)
var assist := true          # 비행 보조: 키를 떼면 바로 멈추고 선회 때 옆으로 안 미끄러진다
var mouse_sens := 1.0
var cmd := {"fwd": 0.0, "right": 0.0, "yaw": 0.0, "thr": 0.0}   # 부드럽게 보정된 입력
var sm := {"fwd": 0.0, "right": 0.0, "yaw": 0.0, "thr": 0.0}
var yaw_pending := 0.0
var tilt_pending := 0.0
var third := false
var zoom_held := false
var wind_mul := 1.0
var frame := {"speed": 1.0, "battery": 1.0, "gimbal": 0, "zoom": 0}
var shell_mat: StandardMaterial3D
var skin := {"color": Color(0.16, 0.17, 0.2), "accent": Color(0.23, 0.86, 1.0)}
var vis_leds: Array[StandardMaterial3D] = []
var hp := 100.0
var hp_max := 100.0
var hit_t := 0.0
var land_speed := 0.0
var zoom_cur := 1.0
var vis: Node3D
var fpv_parts: Array[Node] = []
var prop_nodes3: Array[Node3D] = []
var fpv_tilt := 22.0
var cam_snap := false
var shake_mul := 1.0
var invert_y := false


func setup() -> void:
	home = Vector3(terrain.home_xz.x, terrain.height(terrain.home_xz.x, terrain.home_xz.y) + 0.2, terrain.home_xz.y)
	position = home
	cam = Camera3D.new()
	cam.fov = cam_fov
	cam.near = 0.04
	cam.far = 7000.0
	cam.position = Vector3(0, 0.03, -0.13)
	add_child(cam)
	_make_body()


func _make_body() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.04, 0.04, 0.05)
	dark.roughness = 0.5
	var blur := StandardMaterial3D.new()
	blur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blur.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur.albedo_color = Color(0.05, 0.05, 0.06, 0.16)
	blur.cull_mode = BaseMaterial3D.CULL_DISABLED
	for sx in [-1.0, 1.0]:
		# 앞쪽 암과 프로펠러: 카메라 화면 아래 모서리에 걸린다
		var n0 := get_child_count()
		var arm := MeshInstance3D.new()
		var ab := BoxMesh.new()
		ab.size = Vector3(0.121, 0.006, 0.009)
		arm.mesh = ab
		arm.material_override = dark
		arm.position = Vector3(sx * 0.0675, -0.0125, -0.1775)
		arm.rotation.y = sx * 0.67
		add_child(arm)

		var pr := Node3D.new()
		pr.position = Vector3(sx * 0.13, -0.022, -0.225)
		add_child(pr)
		var disc := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 0.07
		dm.bottom_radius = 0.07
		dm.height = 0.002
		disc.mesh = dm
		disc.material_override = blur
		pr.add_child(disc)
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.002, 0.008)
		blade.mesh = bm
		blade.material_override = dark
		pr.add_child(blade)
		prop_nodes.append(pr)

		var led := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.004
		lm.height = 0.008
		led.mesh = lm
		var lmat := StandardMaterial3D.new()
		lmat.emission_enabled = true
		lmat.emission_energy_multiplier = 1.6
		led.material_override = lmat
		led.position = Vector3(sx * 0.07, -0.004, -0.165)
		add_child(led)
		led_mats.append(lmat)
		for i in range(n0, get_child_count()):
			fpv_parts.append(get_child(i))
	_make_vis(dark, blur)
	apply_led()


## 3인칭 시점에서 보이는 드론 기체. 기체 종류·외장·업그레이드에 따라 모양이 다르다.
func _make_vis(_dark: StandardMaterial3D, _blur: StandardMaterial3D) -> void:
	vis = Node3D.new()
	vis.visible = false
	vis.scale = Vector3.ONE * 2.4
	add_child(vis)
	rebuild_vis()


func rebuild_vis() -> void:
	if vis == null:
		return
	for ch in vis.get_children():
		ch.queue_free()
	prop_nodes3.clear()
	vis_leds.clear()
	var fid: String = frame.get("id", "basic")
	var model: Dictionary = DroneModel.build(fid, skin, lv, led_color())
	vis.add_child(model.root)
	for p in model.props:
		prop_nodes3.append(p)
	for m in model.leds:
		vis_leds.append(m)
	shell_mat = model.shell
	vis.visible = third

func set_third(on: bool) -> void:
	if on == third:
		return
	third = on
	vis.visible = on
	for n in fpv_parts:
		n.visible = not on
	cam.top_level = on
	if on:
		fpv_tilt = cam_tilt
		cam_tilt = -10.0
	else:
		cam_tilt = fpv_tilt
		cam.position = Vector3(0, 0.03, -0.13)
	cam_snap = true


func gimbal_eff() -> float:
	return float(lv.gimbal) + float(frame.gimbal)


## 기체 종류와 외장을 적용한다(모양을 다시 만든다)
func set_frame(f: Dictionary, sk: Dictionary) -> void:
	frame = f
	skin = sk
	hp_max = float(f.get("hp", 100))
	hp = hp_max
	rebuild_vis()


func apply_led() -> void:
	var col: Color = LED_COLORS[clampi(lv.color, 0, LED_COLORS.size() - 1)]
	for m in led_mats:
		m.albedo_color = col
		m.emission = col
	for m in vis_leds:
		m.albedo_color = col
		m.emission = col


## 전투 피해. 체력이 0이 되면 격추된다.
func hurt(n: float) -> void:
	if state == "crashed" or n <= 0.0:
		return
	hp -= n
	hit_t = 0.25
	if hp <= 0.0:
		hp = 0.0
		_crash("SHOT DOWN")


func led_color() -> Color:
	return LED_COLORS[clampi(lv.color, 0, LED_COLORS.size() - 1)]


func mouse_look(rel: Vector2) -> void:
	mouse_acc += rel


func debug_place(p: Vector3, y_deg: float) -> void:
	position = p
	yaw = deg_to_rad(y_deg)
	vel = Vector3.ZERO
	state = "flying"


## 귀신이 드론을 낚아채 던진다
func yank(v: Vector3) -> void:
	vel += v
	yaw += randf_range(-1.1, 1.1)
	tr = randf_range(-0.7, 0.7)
	tp = randf_range(-0.4, 0.4)


func return_home() -> void:
	position = home
	vel = Vector3.ZERO
	yaw = 0.0
	tp = 0.0
	tr = 0.0
	state = "idle"
	battery = 100.0
	hp = hp_max
	signal_lost_t = 0.0


func _axis(v: float) -> float:
	return 0.0 if absf(v) < 0.12 else v


func _read_input() -> void:
	var f := 0.0
	var r := 0.0
	var y := 0.0
	var t := 0.0
	if Input.is_action_pressed("move_fwd"): f += 1.0
	if Input.is_action_pressed("move_back"): f -= 1.0
	if Input.is_action_pressed("move_right"): r += 1.0
	if Input.is_action_pressed("move_left"): r -= 1.0
	if Input.is_action_pressed("yaw_right"): y += 1.0
	if Input.is_action_pressed("yaw_left"): y -= 1.0
	if Input.is_action_pressed("up"): t += 1.0
	if Input.is_action_pressed("down"): t -= 1.0
	var b := 1.0 if Input.is_action_pressed("boost") else 0.0
	if Input.get_connected_joypads().size() > 0:
		var pad := Input.get_connected_joypads()[0]
		y += _axis(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X))
		t -= _axis(Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		r += _axis(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X))
		f -= _axis(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
		b = maxf(b, Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT))
	inp.fwd = clampf(f, -1.0, 1.0)
	inp.right = clampf(r, -1.0, 1.0)
	inp.yaw = clampf(y, -1.0, 1.0)
	inp.thr = clampf(t, -1.0, 1.0)
	inp.boost = b


## 입력을 목표값으로 일정 속도로 따라가게 한다(키보드의 0↔1 급변을 완화)
func _slew(cur: float, target: float, dt: float, attack: float, release: float) -> float:
	var rate := release if absf(target) < absf(cur) else attack
	return move_toward(cur, target, rate * dt)


## 중앙 부근은 둔감하게, 끝에서는 완전히 반응하게 한다
func _expo(x: float, e: float) -> float:
	return (1.0 - e) * x + e * x * x * x


func speed_mult() -> float:
	return (1.0 + 0.22 * lv.speed) * float(frame.speed)


func signal_range() -> float:
	return 2400.0 * (1.0 + 0.35 * lv.signal)


func update(dt: float, blocked: bool) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	hit_t = maxf(0.0, hit_t - dt)
	if blocked:
		inp = {"fwd": 0.0, "right": 0.0, "yaw": 0.0, "thr": 0.0, "boost": 0.0}
	else:
		_read_input()
		if not test_input.is_empty():
			inp = test_input.duplicate()
		# 마우스는 몇 프레임에 걸쳐 부드럽게 반영한다(총량은 그대로)
		yaw_pending -= mouse_acc.x * deg_to_rad(0.11) * mouse_sens / zoom_cur
		tilt_pending -= mouse_acc.y * 0.1 * mouse_sens * (-1.0 if invert_y else 1.0) / zoom_cur
		if Input.is_action_pressed("cam_down"):
			cam_tilt -= 35.0 * dt
		if Input.is_action_pressed("cam_up"):
			cam_tilt += 35.0 * dt
	mouse_acc = Vector2.ZERO
	var py := yaw_pending * (1.0 - exp(-30.0 * dt))
	yaw += py
	yaw_pending -= py
	var pt := tilt_pending * (1.0 - exp(-30.0 * dt))
	cam_tilt = clampf(cam_tilt + pt, -60.0 if third else -70.0, 80.0)
	tilt_pending -= pt
	sm.fwd = _slew(sm.fwd, inp.fwd, dt, 7.0, 10.0)
	sm.right = _slew(sm.right, inp.right, dt, 7.0, 10.0)
	sm.yaw = _slew(sm.yaw, inp.yaw, dt, 6.0, 9.0)
	sm.thr = _slew(sm.thr, inp.thr, dt, 5.0, 8.0)
	cmd.fwd = _expo(sm.fwd, 0.3)
	cmd.right = _expo(sm.right, 0.3)
	cmd.yaw = sm.yaw
	cmd.thr = _expo(sm.thr, 0.3)
	# 마우스 에임 추종: 앞으로 갈 때 보는 방향(위/아래)대로 오르내린다
	var aim_thr := 0.0
	if sm.fwd > 0.05 and state == "flying":
		aim_thr = clampf(sin(deg_to_rad(cam_tilt - (22.0 if not third else -10.0))) * 1.6, -1.0, 1.0) * sm.fwd
		cmd.thr = clampf(cmd.thr + aim_thr, -1.0, 1.0)

	if state == "crashed":
		crash_t -= dt
		rpm = lerpf(rpm, 0.0, dt * 4.0)
		if crash_t <= 0.0:
			return_home()
		_update_camera(t, dt)
		return

	# 자세: 입력 방향으로 기울이고, 입력이 없으면 수평으로 돌아온다
	var boost: float = inp.boost
	var max_tilt := deg_to_rad(36.0 + 18.0 * boost)
	var k := 1.0 - exp(-7.0 * dt)
	tp = lerpf(tp, cmd.fwd * max_tilt, k)
	tr = lerpf(tr, cmd.right * max_tilt, k)
	yaw -= cmd.yaw * deg_to_rad(110.0) * dt
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -tp) * Basis(Vector3.BACK, -tr)
	basis = b
	var upv := b.y

	var thr: float = cmd.thr
	if state == "idle" and inp.thr > 0.1 and battery > 0.0:
		state = "flying"
	var powered := state == "flying" and battery > 0.0
	var hover := G / maxf(upv.y, 0.4)
	var thrust := Vector3.ZERO
	if powered:
		# 상승·하강 추력(부스트를 누르면 더 강하게)
		var coll: float = hover + thr * (26.0 + 3.0 * lv.speed) * (1.0 + 0.6 * boost) * (1.45 if thr < 0.0 else 1.0)
		thrust = upv * coll
		# 하강 중에도 앞으로 가도록, 수평 추력은 하강 명령에 줄어들지 않게 한다
		var hcoll := maxf(coll, hover * 0.85)
		thrust.x = upv.x * hcoll * climb_h_gain   # 수평 추력: 출발과 방향 전환을 민첩하게
		thrust.z = upv.z * hcoll * climb_h_gain

	var kh := 0.95 / speed_mult()
	var acc := thrust + Vector3(0, -G, 0)
	acc.x -= vel.x * kh
	acc.z -= vel.z * kh
	acc.y -= vel.y * 1.0
	var alt: float = position.y - terrain.ground(position.x, position.z)
	if assist and state == "flying":
		# 지면 근처에서 빠르게 내려오면 알아서 속도를 줄인다(플레어)
		var flare_h := clampf(10.0 + absf(vel.y) * 1.6, 16.0, 70.0)
		if alt < flare_h and vel.y < -4.0:
			acc.y += -vel.y * 3.6 * (1.0 - alt / flare_h)
		# 보조: 앞뒤/좌우 입력이 없는 축은 빨리 멈추고, 고도도 붙잡는다
		var rgt := Vector3(cos(yaw), 0.0, -sin(yaw))
		var fwd_h := Vector3(-sin(yaw), 0.0, -cos(yaw))
		if absf(inp.fwd) < 0.05:
			acc -= fwd_h * vel.dot(fwd_h) * 1.9
		if absf(inp.right) < 0.05:
			acc -= rgt * vel.dot(rgt) * 1.9
		if absf(inp.thr) < 0.05 and absf(aim_thr) < 0.05:
			acc.y -= vel.y * 1.8
	var wscale := clampf(alt / 150.0, 0.15, 1.2) * (0.5 if assist else 1.0) * wind_mul
	gust = (sin(t * 0.31) * 0.6 + sin(t * 0.93) * 0.3) * wscale
	if state == "flying":
		acc += Vector3(gust * 0.9, 0.0, cos(t * 0.27) * 0.5 * wscale)
	vel += acc * dt
	var prev := position
	position += vel * dt
	odometer += prev.distance_to(position)

	# 지면 충돌
	var h: float = terrain.height(position.x, position.z)
	var gh: float = maxf(h, 0.0)
	if position.y < gh + 0.18:
		# 지형의 법선 방향으로 부딪힌 속도만 충격으로 친다(낮게 스치듯 나는 건 괜찮다)
		var tn := Vector3(
			terrain.height(position.x - 1.5, position.z) - terrain.height(position.x + 1.5, position.z), 3.0,
			terrain.height(position.x, position.z - 1.5) - terrain.height(position.x, position.z + 1.5)).normalized()
		var vn := vel.dot(tn)
		var impact := maxf(-vn, 0.0)
		if state == "flying" and (h < 0.0 or impact > 9.0):
			_crash("SPLASHDOWN" if h < 0.0 else "CRASH")
			return
		position.y = gh + 0.18
		if vn < 0.0:
			vel -= tn * vn
		if vel.y < 0.0:
			vel.y = 0.0
		var fr := exp(-(7.0 if state == "idle" else 1.2) * dt)
		vel.x *= fr
		vel.z *= fr
		if state == "flying" and thr <= 0.0 and vel.length() < 1.2 and absf(tp) < 0.2 and absf(tr) < 0.2:
			state = "idle"

	# 건물 벽 충돌
	if buildings != null:
		var cr: Dictionary = buildings.collide(position, vel, 0.2)
		position = cr.pos
		vel = cr.vel
		if state == "flying" and cr.impact > 9.0:
			_crash("CRASH")
			return
		if cr.up and state == "flying" and thr <= 0.0 and vel.length() < 1.2 and absf(tp) < 0.2 and absf(tr) < 0.2:
			state = "idle"

	# 차량 충돌
	if traffic != null:
		var ct: Dictionary = traffic.collide(position, vel, 0.2)
		position = ct.pos
		vel = ct.vel
		if state == "flying" and ct.impact > 9.0:
			_crash("CRASH")
			return

	# 배터리
	if state == "flying":
		var spd_frac := clampf(Vector2(vel.x, vel.z).length() / 20.0, 0.0, 1.0)
		var bat_mult: float = (1.0 + 0.25 * lv.battery) * float(frame.battery)
		battery -= dt * (100.0 / (420.0 * bat_mult)) * (1.0 + 0.8 * boost + 0.5 * absf(thr) + 0.4 * spd_frac)
		flight_time += dt
		if battery <= 0.0:
			battery = 0.0
	elif state == "idle" and position.distance_to(home) < 6.0:
		battery = minf(100.0, battery + 12.0 * dt)

	# 신호
	var dist := Vector2(position.x - home.x, position.z - home.z).length()
	signal_q = (1.0 - smoothstep(0.55, 1.0, dist / signal_range())) * (1.0 - 0.4 * indoor)
	if signal_q < 0.03 and state == "flying":
		signal_lost_t += dt
		if signal_lost_t > 1.2:
			_crash("SIGNAL LOST")
			return
	else:
		signal_lost_t = 0.0

	var target_rpm := 0.0
	if state == "flying" and battery > 0.0:
		target_rpm = clampf(0.42 + 0.3 * thr + 0.3 * boost + 0.25 * Vector2(tp, tr).length(), 0.3, 1.0)
	elif state == "idle":
		target_rpm = 0.0
	rpm = lerpf(rpm, target_rpm, dt * 5.0)
	# 속도감: 빠를수록 화각이 넓어진다
	var spd_h := Vector2(vel.x, vel.z).length()
	var zoom_t: float = (1.6 + 0.5 * (float(lv.zoom) + float(frame.zoom))) if zoom_held else 1.0
	zoom_cur = lerpf(zoom_cur, zoom_t, 1.0 - exp(-9.0 * dt))
	cam.fov = lerpf(cam.fov, (cam_fov + 9.0 * clampf(spd_h / 25.0, 0.0, 1.0) + 4.0 * boost) / zoom_cur, 1.0 - exp(-8.0 * dt))
	_update_camera(t, dt)


func _crash(reason: String) -> void:
	state = "crashed"
	crash_reason = reason
	crash_t = 2.4
	vel = Vector3.ZERO
	crashed.emit(reason)


func _update_camera(t: float, dt: float) -> void:
	if third:
		for p in prop_nodes3:
			p.rotate_y(rpm * 140.0 * dt)
			p.get_child(1).visible = rpm < 0.25
		var cb := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(cam_tilt))
		var pivot := position + Vector3(0, 0.25, 0)
		var want := pivot + cb * Vector3(0, 0.45, 3.8)
		var floor_y: float = terrain.ground(want.x, want.z) + 0.7
		want.y = maxf(want.y, floor_y)
		if cam_snap:
			cam.global_position = want
			cam_snap = false
		else:
			cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-16.0 * dt))
		cam.global_basis = cb
		return
	var stab: float = 0.5 + 0.1 * gimbal_eff()
	var roll_stab: float = 0.2 * gimbal_eff()
	var vib: float = (0.3 + 0.7 * rpm) * (1.0 - 0.16 * gimbal_eff()) * shake_mul
	var spd := Vector2(vel.x, vel.z).length()
	var j1 := (sin(t * 47.0) + sin(t * 73.0 + 1.3)) * 0.5
	var j2 := (sin(t * 53.0 + 0.7) + sin(t * 89.0)) * 0.5
	var turb: float = (0.25 + clampf(spd / 25.0, 0.0, 1.0) * 0.6) * (1.0 - 0.12 * gimbal_eff())
	cam.rotation_degrees = Vector3(
		cam_tilt + rad_to_deg(tp) * stab + j1 * 0.16 * vib + sin(t * 1.9) * 0.35 * turb * absf(gust),
		j2 * 0.12 * vib,
		rad_to_deg(tr) * roll_stab + sin(t * 61.0) * 0.1 * vib)
	cam.position = Vector3(j1 * 0.0007 * vib, 0.03 + j2 * 0.0007 * vib, -0.13)
	for p in prop_nodes:
		p.rotate_y(rpm * 140.0 * dt)
		p.get_child(1).visible = rpm < 0.25   # 빨리 돌 때는 블러 원반만 보인다
