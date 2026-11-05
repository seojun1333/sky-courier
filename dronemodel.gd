extends RefCounted
## 드론 3D 모델. 기체 종류(4종)·외장 색(10종)·업그레이드 단계에 따라 모양이 확연히 달라진다.
## 앞쪽은 -Z. 크기는 실물(약 0.3m) 기준이며, 호출하는 쪽에서 배율을 곱한다.

const DEF_ACCENT := Color(0.23, 0.86, 1.0)


static func _m(c: Color, metal := 0.0, rough := 0.5, emis := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emis
	return m


static func _add(p: Node3D, mi: MeshInstance3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3) -> MeshInstance3D:
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	p.add_child(mi)
	return mi


static func _box(p: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _add(p, MeshInstance3D.new(), b, pos, mat, rot)


static func _cyl(p: Node3D, r: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, r2 := -1.0) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r if r2 < 0.0 else r2
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 14
	c.rings = 1
	return _add(p, MeshInstance3D.new(), c, pos, mat, rot)


static func _sph(p: Node3D, r: float, pos: Vector3, mat: Material, scl := Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	var mi := _add(p, MeshInstance3D.new(), s, pos, mat, Vector3.ZERO)
	mi.scale = scl
	return mi


static func _torus(p: Node3D, ri: float, ro: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = ri
	t.outer_radius = ro
	t.rings = 20
	t.ring_segments = 8
	return _add(p, MeshInstance3D.new(), t, pos, mat, rot)


## a에서 b까지 이어지는 막대(팔)
static func _arm(p: Node3D, a: Vector3, b: Vector3, w: float, h: float, mat: Material) -> MeshInstance3D:
	var d := b - a
	var mi := _box(p, Vector3(w, h, d.length()), (a + b) * 0.5, mat)
	mi.basis = Basis.looking_at(d.normalized(), Vector3.UP)
	return mi


static func _prop(c: Dictionary, pos: Vector3, r: float, blades: int) -> void:
	var n := Node3D.new()
	n.position = pos
	(c.root as Node3D).add_child(n)
	_cyl(n, r, 0.002, Vector3.ZERO, c.blur)
	var bl := Node3D.new()
	n.add_child(bl)
	for i in blades:
		var b := _box(bl, Vector3(r * 2.0, 0.002, r * 0.13), Vector3.ZERO, c.dark)
		b.rotation.y = PI * float(i) / float(blades)
	(c.props as Array).append(n)


static func _led(c: Dictionary, pos: Vector3, r := 0.006) -> void:
	var m := _m(c.led, 0.0, 0.5, 2.2)
	var s := _sph(c.root, r, pos, m)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(c.leds as Array).append(m)


static func build(fid: String, skin: Dictionary, lv: Dictionary, led: Color) -> Dictionary:
	var root := Node3D.new()
	var accent: Color = skin.get("accent", DEF_ACCENT)
	var glow: bool = skin.get("glow", false)
	var blur := StandardMaterial3D.new()
	blur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blur.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur.albedo_color = Color(0.05, 0.05, 0.06, 0.16)
	blur.cull_mode = BaseMaterial3D.CULL_DISABLED
	var c := {
		"root": root, "led": led, "props": [], "leds": [], "motors": [],
		"shell": _m(skin.color, float(skin.get("metal", 0.4)), float(skin.get("rough", 0.35))),
		"acc": _m(accent, 0.25, 0.4, 1.6 if glow else 0.0),
		"dark": _m(Color(0.04, 0.04, 0.05), 0.3, 0.5),
		"carbon": _m(Color(0.07, 0.07, 0.085), 0.65, 0.28),
		"glass": _m(Color(0.02, 0.03, 0.08), 1.0, 0.05),
		"blur": blur,
	}
	var anch: Dictionary
	match fid:
		"cargo": anch = _cargo(c)
		"racer": anch = _racer(c)
		"camera": anch = _camera(c)
		_: anch = _basic(c)
	_attach(c, anch, lv, fid)
	return {"root": root, "props": c.props, "leds": c.leds, "shell": c.shell}


# ---------------------------------------------------------------- 기체 4종
static func _basic(c: Dictionary) -> Dictionary:
	var r: Node3D = c.root
	_box(r, Vector3(0.1, 0.035, 0.17), Vector3.ZERO, c.shell)
	_box(r, Vector3(0.07, 0.014, 0.12), Vector3(0, 0.024, 0.01), c.dark)
	_sph(r, 0.034, Vector3(0, 0.03, -0.03), c.shell, Vector3(1.0, 0.5, 1.5))
	_box(r, Vector3(0.012, 0.006, 0.15), Vector3(0, 0.041, 0.0), c.acc)
	_box(r, Vector3(0.104, 0.008, 0.03), Vector3(0, 0.0, 0.05), c.acc)
	_box(r, Vector3(0.045, 0.045, 0.04), Vector3(0, 0, -0.11), c.dark)
	_sph(r, 0.014, Vector3(0, 0, -0.135), c.glass)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var tip := Vector3(sx * 0.115, 0.012, sz * 0.115)
			_arm(r, Vector3(sx * 0.03, 0, sz * 0.03), tip, 0.014, 0.008, c.dark)
			_cyl(r, 0.016, 0.026, tip + Vector3(0, 0.004, 0), c.shell)
			_prop(c, tip + Vector3(0, 0.024, 0), 0.065, 2)
			_led(c, tip + Vector3(0, -0.012, sz * 0.03))
			_cyl(r, 0.004, 0.045, Vector3(sx * 0.04, -0.03, sz * 0.06), c.dark)
			(c.motors as Array).append(tip + Vector3(0, 0.018, 0))
	return {"top": Vector3(0, 0.045, 0.03), "nose": Vector3(0, 0, -0.14), "belly": Vector3(0, -0.055, 0), "tail": Vector3(0, 0.02, 0.09),
		"lens": Vector3(0, 0, -0.14), "gimbal": false, "bat": 0.0}


static func _cargo(c: Dictionary) -> Dictionary:
	var r: Node3D = c.root
	_box(r, Vector3(0.17, 0.05, 0.24), Vector3.ZERO, c.shell)
	_box(r, Vector3(0.174, 0.012, 0.035), Vector3(0, 0.008, -0.075), c.acc)
	_box(r, Vector3(0.174, 0.012, 0.035), Vector3(0, 0.008, 0.075), c.acc)
	_box(r, Vector3(0.12, 0.035, 0.17), Vector3(0, 0.043, 0.0), c.dark)
	_box(r, Vector3(0.1, 0.006, 0.05), Vector3(0, 0.063, 0.0), c.acc)
	for i in 6:
		var a := deg_to_rad(30.0 + 60.0 * i)
		var d := Vector3(sin(a), 0.0, -cos(a))
		var tip := d * 0.2 + Vector3(0, 0.012, 0)
		_arm(r, d * 0.07, tip, 0.022, 0.014, c.carbon)
		_cyl(r, 0.02, 0.034, tip + Vector3(0, 0.006, 0), c.shell)
		_prop(c, tip + Vector3(0, 0.03, 0), 0.062, 3)
		_led(c, tip + Vector3(0, -0.016, 0), 0.007)
		(c.motors as Array).append(tip + Vector3(0, 0.022, 0))
	# 착륙 스키드와 화물칸
	for sx in [-1.0, 1.0]:
		_box(r, Vector3(0.012, 0.012, 0.32), Vector3(sx * 0.09, -0.13, 0.0), c.dark)
		for sz in [-1.0, 1.0]:
			_cyl(r, 0.005, 0.085, Vector3(sx * 0.09, -0.085, sz * 0.1), c.dark)
	_box(r, Vector3(0.14, 0.08, 0.16), Vector3(0, -0.07, 0.0), c.acc)
	_box(r, Vector3(0.144, 0.012, 0.03), Vector3(0, -0.07, -0.045), c.dark)
	_box(r, Vector3(0.144, 0.012, 0.03), Vector3(0, -0.07, 0.045), c.dark)
	_box(r, Vector3(0.05, 0.03, 0.05), Vector3(0, 0.0, -0.14), c.dark)
	_sph(r, 0.011, Vector3(0, 0, -0.168), c.glass)
	return {"top": Vector3(0, 0.07, 0.0), "nose": Vector3(0, 0, -0.17), "belly": Vector3(0, -0.15, 0), "tail": Vector3(0, 0.03, 0.12),
		"lens": Vector3(0, 0, -0.17), "gimbal": false, "bat": 0.0}


static func _racer(c: Dictionary) -> Dictionary:
	var r: Node3D = c.root
	_box(r, Vector3(0.06, 0.028, 0.23), Vector3.ZERO, c.carbon)
	_box(r, Vector3(0.016, 0.004, 0.21), Vector3(0, 0.016, 0.0), c.acc)
	_box(r, Vector3(0.046, 0.02, 0.1), Vector3(0, 0.025, -0.025), c.glass, Vector3(-12, 0, 0))
	_box(r, Vector3(0.004, 0.034, 0.07), Vector3(0, 0.032, 0.1), c.acc, Vector3(-18, 0, 0))
	_box(r, Vector3(0.04, 0.035, 0.035), Vector3(0, 0.004, -0.125), c.dark, Vector3(-25, 0, 0))
	_sph(r, 0.012, Vector3(0, 0.0, -0.146), c.glass)
	_box(r, Vector3(0.05, 0.003, 0.17), Vector3(0, -0.017, 0.0), _m(c.acc.albedo_color, 0.0, 0.4, 3.0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var tip := Vector3(sx * 0.125, 0.012, -0.1 if sz < 0.0 else 0.118)
			_arm(r, Vector3(sx * 0.02, 0.0, sz * 0.04), tip, 0.02, 0.006, c.carbon)
			_cyl(r, 0.013, 0.022, tip + Vector3(0, 0.004, 0), c.dark)
			_cyl(r, 0.0145, 0.008, tip + Vector3(0, 0.017, 0), c.acc)
			_prop(c, tip + Vector3(0, 0.024, 0), 0.052, 3)
			if sz > 0.0:
				_led(c, tip + Vector3(0, -0.01, 0.02))
			(c.motors as Array).append(tip + Vector3(0, 0.014, 0))
	_cyl(r, 0.0025, 0.07, Vector3(0.012, 0.045, 0.115), c.dark, Vector3(-30, 0, 0))
	return {"top": Vector3(0, 0.035, 0.03), "nose": Vector3(0, 0.004, -0.15), "belly": Vector3(0, -0.025, 0), "tail": Vector3(0, 0.03, 0.12),
		"lens": Vector3(0, 0.004, -0.15), "gimbal": false, "bat": 0.0}


static func _camera(c: Dictionary) -> Dictionary:
	var r: Node3D = c.root
	_box(r, Vector3(0.12, 0.05, 0.17), Vector3.ZERO, c.shell)
	_sph(r, 0.03, Vector3(0, 0.03, 0.03), c.glass, Vector3(1.0, 0.6, 1.0))
	_torus(r, 0.026, 0.033, Vector3(0, 0.028, 0.03), c.acc)
	for sx in [-1.0, 1.0]:
		_box(r, Vector3(0.02, 0.03, 0.13), Vector3(sx * 0.07, 0.0, 0.0), c.dark)
		_box(r, Vector3(0.022, 0.006, 0.1), Vector3(sx * 0.07, 0.016, 0.0), c.acc)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var base := Vector3(sx * 0.05, 0.015, sz * 0.06)
			var tip := Vector3(sx * 0.15, 0.05, sz * 0.13)
			_arm(r, base, tip, 0.014, 0.014, c.shell)
			_cyl(r, 0.012, 0.016, base.lerp(tip, 0.45), c.acc, Vector3(90, 0, 0))
			_cyl(r, 0.017, 0.03, tip + Vector3(0, 0.006, 0), c.dark)
			_prop(c, tip + Vector3(0, 0.026, 0), 0.075, 2)
			_led(c, tip + Vector3(0, -0.014, 0), 0.007)
			(c.motors as Array).append(tip + Vector3(0, 0.02, 0))
			# 착륙 다리
			var foot := Vector3(sx * 0.105, -0.12, sz * 0.105)
			_arm(r, Vector3(sx * 0.05, -0.02, sz * 0.06), foot, 0.008, 0.008, c.dark)
			_cyl(r, 0.012, 0.006, foot + Vector3(0, -0.003, 0), c.acc)
	# 짐벌 카메라
	for sx in [-1.0, 1.0]:
		_box(r, Vector3(0.006, 0.05, 0.006), Vector3(sx * 0.034, -0.062, -0.075), c.dark)
	_box(r, Vector3(0.07, 0.008, 0.012), Vector3(0, -0.032, -0.075), c.dark)
	_sph(r, 0.033, Vector3(0, -0.078, -0.075), c.dark)
	_cyl(r, 0.019, 0.026, Vector3(0, -0.078, -0.108), c.carbon, Vector3(90, 0, 0))
	_cyl(r, 0.015, 0.004, Vector3(0, -0.078, -0.122), c.glass, Vector3(90, 0, 0))
	_torus(r, 0.016, 0.021, Vector3(0, -0.078, -0.121), c.acc, Vector3(90, 0, 0))
	return {"top": Vector3(0, 0.065, 0.03), "nose": Vector3(0, -0.078, -0.12), "belly": Vector3(0, -0.125, 0.0), "tail": Vector3(0, 0.03, 0.09),
		"lens": Vector3(0, -0.078, -0.122), "gimbal": true, "bat": 0.0}


# ---------------------------------------------------------------- 업그레이드 부착물
static func _attach(c: Dictionary, a: Dictionary, lv: Dictionary, fid: String) -> void:
	var r: Node3D = c.root
	var top: Vector3 = a.top
	var tail: Vector3 = a.tail
	# 모터: 단계가 오르면 더 크고 빛나는 링이 붙는다
	if int(lv.get("speed", 0)) >= 2:
		for m in c.motors:
			var ring := _torus(r, 0.014, 0.02, m, _m(c.led, 0.0, 0.4, 2.4))
			(c.leds as Array).append(ring.material_override)
	if int(lv.get("speed", 0)) >= 4:
		for m in c.motors:
			_cyl(r, 0.006, 0.022, m + Vector3(0, -0.04, 0), c.dark, Vector3.ZERO, 0.012)
	# 배터리 팩
	var nb := int(lv.get("battery", 0)) / 2
	for k in nb:
		_box(r, Vector3(0.07, 0.02, 0.1), top + Vector3(0, 0.012 + 0.024 * k, 0.0), c.dark)
		_box(r, Vector3(0.072, 0.005, 0.02), top + Vector3(0, 0.012 + 0.024 * k, 0.0), c.acc)
	if int(lv.get("battery", 0)) >= 1:
		_box(r, Vector3(0.012, 0.012, 0.06), top + Vector3(0.05, 0.0, 0.0), c.dark)
	# 안테나
	var sg := int(lv.get("signal", 0))
	if sg >= 1:
		_cyl(r, 0.0025, 0.1, tail + Vector3(0.025, 0.05, 0.0), c.dark, Vector3(0, 0, -8))
		_sph(r, 0.005, tail + Vector3(0.033, 0.1, 0.0), _m(c.led, 0.0, 0.5, 2.5))
	if sg >= 3:
		_cyl(r, 0.0025, 0.1, tail + Vector3(-0.025, 0.05, 0.0), c.dark, Vector3(0, 0, 8))
		_sph(r, 0.005, tail + Vector3(-0.033, 0.1, 0.0), _m(c.led, 0.0, 0.5, 2.5))
	if sg >= 4:
		_cyl(r, 0.032, 0.004, tail + Vector3(0, 0.07, 0.03), c.acc, Vector3(70, 0, 0))
		_cyl(r, 0.003, 0.05, tail + Vector3(0, 0.05, 0.02), c.dark)
	# 짐벌 포드(카메라 기체는 이미 있다)
	var gm := int(lv.get("gimbal", 0))
	var lens: Vector3 = a.lens
	if gm >= 1 and not bool(a.gimbal):
		var pp: Vector3 = (a.nose as Vector3) + Vector3(0, -0.03, 0.02)
		_sph(r, 0.014 + 0.004 * gm, pp, c.dark)
		_torus(r, 0.012 + 0.004 * gm, 0.016 + 0.004 * gm, pp, c.acc, Vector3(0, 90, 0))
		_cyl(r, 0.01 + 0.002 * gm, 0.02, pp + Vector3(0, 0, -0.016), c.carbon, Vector3(90, 0, 0))
		lens = pp + Vector3(0, 0, -0.026)
	# 망원 렌즈
	var zm := int(lv.get("zoom", 0)) + (1 if fid == "camera" else 0)
	if zm >= 1:
		var L := 0.02 + 0.026 * zm
		var lr := 0.011 + 0.0016 * zm
		_cyl(r, lr, L, lens + Vector3(0, 0, -L * 0.5 - 0.004), c.carbon, Vector3(90, 0, 0))
		_torus(r, lr * 0.85, lr * 1.2, lens + Vector3(0, 0, -L - 0.002), c.acc, Vector3(90, 0, 0))
		_cyl(r, lr * 0.85, 0.003, lens + Vector3(0, 0, -L - 0.006), c.glass, Vector3(90, 0, 0))
	# 코인 흡착기: 바닥에 달린 말굽 자석
	var mg := int(lv.get("magnet", 0))
	if mg >= 1:
		var bp: Vector3 = (a.belly as Vector3) + Vector3(0, -0.012, 0)
		_torus(r, 0.016, 0.024, bp, _m(Color(0.85, 0.12, 0.12), 0.4, 0.4), Vector3(90, 0, 0))
		if mg >= 3:
			_torus(r, 0.016, 0.024, bp + Vector3(0, -0.012, 0), _m(Color(0.15, 0.3, 0.9), 0.4, 0.4), Vector3(90, 0, 0))
	# 야간 식별등: 단계가 오르면 밑면과 몸통에 빛이 번진다
	var cl := int(lv.get("color", 0))
	if cl >= 2:
		var gm2 := _m(c.led, 0.0, 0.5, 2.6)
		var disc := _cyl(r, 0.06, 0.003, (a.belly as Vector3) + Vector3(0, 0.03, 0.0), gm2)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(c.leds as Array).append(gm2)
	if cl >= 4:
		var gm3 := _m(c.led, 0.0, 0.5, 2.8)
		_torus(r, 0.092, 0.1, Vector3(0, 0.0, 0.0), gm3, Vector3(0, 0, 0))
		(c.leds as Array).append(gm3)
	# 수수료 협상: 금장 배지와 날개판
	var bn := int(lv.get("bounty", 0))
	if bn >= 1:
		var gold := _m(Color(1.0, 0.8, 0.25), 1.0, 0.2, 0.4)
		_cyl(r, 0.014, 0.004, top + Vector3(0, 0.004, 0.05), gold)
		if bn >= 3:
			for sx in [-1.0, 1.0]:
				_box(r, Vector3(0.05, 0.004, 0.012), tail + Vector3(sx * 0.05, 0.0, 0.03), gold, Vector3(0, sx * -20, sx * 8))
