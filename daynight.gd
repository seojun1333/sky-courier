extends Node
## 낮밤 순환과 날씨. 해·달 방향, 하늘색, 안개, 도시 불빛, 비와 번개, 화성 먼지 폭풍을 모두 여기서 맞춘다.

signal weather_changed(w: String)
signal lightning(strength: float)

const DAY_LEN := 840.0          # 하루(24시간)가 흐르는 실제 초
const NAMES := {"clear": "맑음", "cloudy": "흐림", "rain": "비", "storm": "뇌우", "fog": "안개", "dust": "먼지 폭풍"}
## 상태별 목표: 비, 흐림 정도, 안개 배수, 바람 배수
const WX := {
	"clear": {"rain": 0.0, "over": 0.0, "fog": 1.0, "wind": 1.0, "cover": 0.0},
	"cloudy": {"rain": 0.0, "over": 0.45, "fog": 1.3, "wind": 1.25, "cover": 0.6},
	"rain": {"rain": 0.75, "over": 0.8, "fog": 2.4, "wind": 1.7, "cover": 1.0},
	"storm": {"rain": 1.0, "over": 1.0, "fog": 3.2, "wind": 2.6, "cover": 1.0},
	"fog": {"rain": 0.0, "over": 0.5, "fog": 6.0, "wind": 0.7, "cover": 0.5},
	"dust": {"rain": 0.0, "over": 0.35, "fog": 5.0, "wind": 2.2, "cover": 0.0},
}

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var world: Dictionary
var deco: RefCounted
var cam: Camera3D

var hour := 12.0
var weather := "clear"
var target := "clear"
var wx_t := 120.0
var switch_t := 0.0
var wet := 0.0                  # 현재 비 세기 0~1
var over := 0.0
var fogm := 1.0
var wind_mul := 1.0
var cover := 0.0
var night_f := 0.0              # 0 낮 ~ 1 밤
var day_f := 1.0
var light_t := 8.0
var rain_node: GPUParticles3D
var indoor := 0.0


func setup(e: Environment, s: DirectionalLight3D, sm: ShaderMaterial, w: Dictionary, d: RefCounted, c: Camera3D) -> void:
	env = e
	sun = s
	sky_mat = sm
	world = w
	deco = d
	cam = c
	hour = float(w.get("start_hour", 12.0))
	_make_rain()
	apply(0.0)


func weather_name() -> String:
	return NAMES[weather]


func clock() -> String:
	var h := int(hour) % 24
	var m := int((hour - floor(hour)) * 60.0)
	return "%02d:%02d" % [h, m]


func _make_rain() -> void:
	rain_node = GPUParticles3D.new()
	rain_node.amount = 2200
	rain_node.lifetime = 1.3
	rain_node.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	rain_node.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(26, 1, 26)
	pm.direction = Vector3(0, -1, 0)
	pm.initial_velocity_min = 26.0
	pm.initial_velocity_max = 32.0
	pm.gravity = Vector3(0, -9, 0)
	rain_node.process_material = pm
	var q := BoxMesh.new()
	q.size = Vector3(0.012, 0.55, 0.012)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(0.75, 0.82, 0.95, 0.4)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = mm
	rain_node.draw_pass_1 = q
	rain_node.emitting = false
	rain_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain_node)


func _pick_weather() -> String:
	var opts: Array = ["clear", "clear", "cloudy", "rain", "storm", "fog"]
	if world.kind == "mars":
		opts = ["clear", "clear", "dust"]
	var w: String = opts[randi() % opts.size()]
	return w


func update(dt: float, cam_pos: Vector3, indoor_f: float) -> void:
	indoor = indoor_f
	hour = fposmod(hour + dt * 24.0 / DAY_LEN, 24.0)
	wx_t -= dt
	if wx_t <= 0.0:
		wx_t = randf_range(130.0, 260.0)
		var nw := _pick_weather()
		if nw == target:
			nw = "clear"
		target = nw
		switch_t = 9.0
	var tw: Dictionary = WX[target]
	var k := 1.0 - exp(-0.35 * dt)
	wet = lerpf(wet, float(tw.rain), k)
	over = lerpf(over, float(tw.over), k)
	fogm = lerpf(fogm, float(tw.fog), k)
	wind_mul = lerpf(wind_mul, float(tw.wind), k)
	cover = lerpf(cover, float(tw.cover), k)
	if weather != target:
		switch_t -= dt
		if switch_t <= 0.0:
			weather = target
			weather_changed.emit(weather)
	if target == "storm" and wet > 0.5:
		light_t -= dt
		if light_t <= 0.0:
			light_t = randf_range(6.0, 16.0)
			lightning.emit(randf_range(0.5, 1.0))
	apply(dt)
	if rain_node != null:
		rain_node.global_position = cam_pos + Vector3(0, 14, 0)
		rain_node.emitting = wet > 0.05 and world.kind != "mars" and indoor < 0.5
		rain_node.amount_ratio = clampf(wet, 0.05, 1.0)


## 시각에 맞춰 환경을 갱신한다
func apply(_dt: float) -> void:
	var elev := 62.0 * sin(PI * (hour - 6.0) / 12.0)          # 태양 고도(도). 음수면 지평선 아래
	day_f = smoothstep(-5.0, 14.0, elev)
	night_f = 1.0 - day_f
	var warm := 1.0 - smoothstep(4.0, 30.0, elev)
	warm *= smoothstep(-8.0, 3.0, elev)                      # 노을 정도(해가 낮을 때)
	var s: Dictionary = world.sky
	var day_pal: Dictionary = world.get("day_sky", s)
	var night_top := Color(0.012, 0.022, 0.07)
	var night_mid := Color(0.03, 0.05, 0.12)
	var night_hor := Color(0.07, 0.09, 0.17)
	if world.kind == "mars":
		night_top = Color(0.04, 0.02, 0.03)
		night_mid = Color(0.09, 0.05, 0.05)
		night_hor = Color(0.18, 0.1, 0.09)
	var top := _v(day_pal.top).lerp(night_top, night_f)
	var mid := _v(day_pal.mid).lerp(night_mid, night_f)
	var hor := _v(day_pal.hor).lerp(night_hor, night_f)
	var dusk_hor := Color(1.0, 0.52, 0.28) if world.kind != "mars" else Color(0.35, 0.45, 0.7)
	hor = hor.lerp(dusk_hor, warm * 0.72)
	mid = mid.lerp(Color(0.52, 0.4, 0.58), warm * 0.4)
	var gray := 0.55 * over
	top = top.lerp(Color(0.3, 0.32, 0.36) * (0.25 + 0.75 * day_f), gray)
	mid = mid.lerp(Color(0.4, 0.42, 0.46) * (0.25 + 0.75 * day_f), gray)
	hor = hor.lerp(Color(0.5, 0.52, 0.55) * (0.2 + 0.8 * day_f), gray)
	sky_mat.set_shader_parameter("top_col", _vec(top))
	sky_mat.set_shader_parameter("mid_col", _vec(mid))
	sky_mat.set_shader_parameter("hor_col", _vec(hor))
	sky_mat.set_shader_parameter("gnd_col", _vec(Color(0.22, 0.21, 0.24) * (0.15 + 0.85 * day_f)))
	var base_sun: Vector3 = world.sky.sun_col
	var moon := Vector3(0.55, 0.66, 0.95)
	sky_mat.set_shader_parameter("sun_col", base_sun.lerp(moon, night_f))
	sky_mat.set_shader_parameter("sun_size", lerpf(float(world.sky.sun_size), 5200.0, night_f))
	sky_mat.set_shader_parameter("star_amt", night_f * night_f)
	sky_mat.set_shader_parameter("overcast", over)
	sky_mat.set_shader_parameter("cloud_cover", cover)
	sky_mat.set_shader_parameter("cloud_amount", float(world.sky.clouds) * (0.5 + 0.5 * (1.0 - night_f * 0.5)))
	# 해(또는 달) 빛
	var az: float = world.sun_rot.y + (hour - 12.0) * 7.0
	var pitch := -maxf(elev, 0.0)
	if elev < 3.0:
		pitch = -(26.0 + 14.0 * sin(hour))                  # 달: 밤새 비스듬히 떠 있다
		az += 150.0
	sun.rotation_degrees = Vector3(pitch, az, 0.0)
	var sun_col: Color = world.sun_color
	var golden := Color(1.0, 0.55, 0.28)
	var day_col := sun_col.lerp(golden, warm * 0.55)
	sun.light_color = Color(0.5, 0.62, 1.0).lerp(day_col, day_f)
	var e: float = float(world.sun_energy) * day_f * (1.0 - 0.62 * over) + 0.16 * night_f * (1.0 - 0.5 * over)
	sun.light_energy = e
	# 안개와 주변광
	var fog_c := hor.lerp(Color(0.5, 0.52, 0.56) * (0.15 + 0.85 * day_f), clampf(over * 0.6, 0.0, 1.0))
	env.fog_light_color = fog_c
	env.fog_density = float(world.fog_density) * fogm * (1.0 + 1.2 * night_f * (1.0 if world.kind == "city" else 0.0))
	var amb: float = float(world.ambient) * lerpf(0.2, 1.0, day_f) * (1.0 - 0.28 * over)
	env.ambient_light_energy = lerpf(amb, 0.05, indoor)
	RenderingServer.global_shader_parameter_set("night_f", night_f)
	# 도시 불빛
	if deco != null and deco.get("mat") is ShaderMaterial:
		(deco.mat as ShaderMaterial).set_shader_parameter("night", 0.04 + 0.78 * night_f)
	if deco != null and deco.get("lamp_head") is StandardMaterial3D:
		var lm: StandardMaterial3D = deco.lamp_head
		lm.albedo_color = Color(0.22, 0.21, 0.2).lerp(Color(1.0, 0.85, 0.55), night_f)
		lm.emission_energy_multiplier = 4.5 * night_f
		lm.emission_enabled = night_f > 0.05


static func _v(v: Vector3) -> Color:
	return Color(v.x, v.y, v.z)


static func _vec(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
