extends Node
## 타격감 연출: 파티클 터뜨리기, 슬로모션, 화면 맥박.

var pulse := 0.0


func _process(dt: float) -> void:
	pulse = maxf(0.0, pulse - dt * 2.2)


## 월드 좌표에서 작은 빛 알갱이를 사방으로 터뜨린다
func burst(pos: Vector3, color: Color, amount := 26, speed := 7.0, size := 0.12) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -2.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	sm.material = mat
	p.mesh = sm
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.3).timeout.connect(p.queue_free)


## 피격 혈흔: 맞은 곳에서 dir 방향으로 튀는 핏방울. big 이면 사방으로 터진다. sparks 는 기계(불꽃)용.
func blood(pos: Vector3, dir: Vector3, color: Color, amount := 14, sparks := false, big := false) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 1.1 if big else 0.75
	p.explosiveness = 1.0
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = 180.0 if big else 38.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 15.0 if big else 9.0
	p.gravity = Vector3(0, -15.0, 0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5 if big else 1.1
	var sm := SphereMesh.new()
	sm.radius = 0.07 if big else 0.045
	sm.height = sm.radius * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.12)
	mat.roughness = 0.15
	mat.metallic_specular = 0.9
	mat.emission_enabled = sparks
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	sm.material = mat
	p.mesh = sm
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
	if sparks:
		burst(pos, Color(1.0, 0.85, 0.4), 8 if not big else 20, 10.0, 0.05)


## 폭발: 불꽃과 연기
func explosion(pos: Vector3, size := 1.0) -> void:
	burst(pos, Color(1.0, 0.65, 0.2), int(36 * size), 16.0 * size, 0.14 * size)
	burst(pos, Color(1.0, 0.95, 0.7), int(14 * size), 24.0 * size, 0.06)
	burst(pos, Color(0.18, 0.18, 0.2), int(20 * size), 7.0 * size, 0.2 * size)


## 잠깐 느리게 했다가 돌아온다(실제 시간 기준)
func slowmo(duration := 0.6, scale := 0.35) -> void:
	Engine.time_scale = scale
	get_tree().create_timer(duration, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func do_pulse() -> void:
	pulse = 1.0
