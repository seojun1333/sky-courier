extends Node3D
## 적 하나: 적 드론 4종(드론 대전)과 괴물 5종(괴물 사냥). 모양·체력·공격 패턴·드랍이 종류마다 다르다.
## 위치/AI 갱신은 combat.gd 가 tick(dt) 로 직접 호출한다.

const DM := preload("res://dronemodel.gd")
const HP_MULT := 2.4            # 체력 배율(전체 난이도)

# 난이도 tier: 1 쉬움 … 5 보스.  drops = [아이템, 확률, 최소, 최대]  (mag/missile/repair 는 전투 보급품)
const TYPES := {
	"scout": {"name": "정찰 드론", "mode": "duel", "tier": 1, "sc": 2.4, "hp": 40.0, "speed": 26.0, "r": 1.1, "fly": true, "coins": 14, "xp": 8,
		"rng": 55.0, "alt": 8.0, "fire_range": 130.0, "burst": 3, "gap": 0.17, "rest": 1.7, "spread": 5.0, "bspeed": 90.0, "bdmg": 3.0, "lead": 0.55,
		"blood": Color(1.0, 0.6, 0.15), "drops": [["scrap", 0.7, 1, 2], ["circuit", 0.2, 1, 1], ["mag", 0.4, 1, 1]]},
	"gunship": {"name": "건십", "mode": "duel", "tier": 2, "sc": 2.1, "hp": 95.0, "speed": 18.0, "r": 1.6, "fly": true, "coins": 32, "xp": 18,
		"rng": 75.0, "alt": 12.0, "fire_range": 170.0, "burst": 6, "gap": 0.11, "rest": 2.0, "spread": 3.5, "bspeed": 95.0, "bdmg": 4.0, "lead": 0.7,
		"blood": Color(1.0, 0.6, 0.15), "drops": [["scrap", 0.85, 1, 3], ["circuit", 0.45, 1, 2], ["mag", 0.5, 1, 1], ["missile", 0.15, 1, 1]]},
	"striker": {"name": "스트라이커", "mode": "duel", "tier": 3, "sc": 2.2, "hp": 80.0, "speed": 25.0, "r": 1.3, "fly": true, "coins": 52, "xp": 28,
		"rng": 95.0, "alt": 18.0, "fire_range": 160.0, "burst": 3, "gap": 0.14, "rest": 2.6, "spread": 3.0, "bspeed": 100.0, "bdmg": 4.0, "lead": 0.8, "mis_cd": 7.5,
		"blood": Color(1.0, 0.6, 0.15), "drops": [["circuit", 0.7, 1, 2], ["power_cell", 0.25, 1, 1], ["missile", 0.4, 1, 1], ["mag", 0.4, 1, 1]]},
	"ace": {"name": "에이스 (보스)", "mode": "duel", "tier": 5, "sc": 2.0, "hp": 360.0, "speed": 31.0, "r": 2.0, "fly": true, "coins": 190, "xp": 90, "boss": true, "armor": 0.7,
		"rng": 70.0, "alt": 10.0, "fire_range": 190.0, "burst": 8, "gap": 0.085, "rest": 1.5, "spread": 2.4, "bspeed": 110.0, "bdmg": 5.0, "lead": 0.9, "mis_cd": 5.0,
		"blood": Color(1.0, 0.6, 0.15), "drops": [["ace_chip", 0.55, 1, 1], ["power_cell", 0.8, 1, 2], ["circuit", 1.0, 2, 3], ["repair", 0.7, 1, 1], ["missile", 0.6, 1, 2]]},
	"slime": {"name": "슬라임", "mode": "hunt", "tier": 1, "sc": 1.8, "hp": 45.0, "speed": 6.0, "r": 1.4, "fly": false, "coins": 9, "xp": 6,
		"spit_cd": 3.4, "spit_dmg": 5.0, "spit_range": 85.0, "blood": Color(0.4, 0.9, 0.25),
		"drops": [["gel", 0.9, 1, 3], ["mag", 0.25, 1, 1]]},
	"bat": {"name": "흡혈박쥐", "mode": "hunt", "tier": 2, "sc": 2.2, "hp": 24.0, "speed": 24.0, "r": 0.9, "fly": true, "coins": 14, "xp": 9, "dmg": 6.0,
		"blood": Color(0.8, 0.05, 0.08), "drops": [["bat_wing", 0.7, 1, 2], ["fang", 0.25, 1, 1]]},
	"golem": {"name": "바위 골렘", "mode": "hunt", "tier": 3, "sc": 1.6, "hp": 300.0, "speed": 4.4, "r": 3.4, "fly": false, "coins": 70, "xp": 36, "armor": 0.5,
		"throw_cd": 4.6, "throw_dmg": 18.0, "throw_range": 140.0, "blood": Color(1.0, 0.45, 0.1), "cy": 3.0,
		"drops": [["rock_shard", 0.9, 1, 3], ["golem_core", 0.35, 1, 1], ["repair", 0.3, 1, 1], ["mag", 0.4, 1, 2]]},
	"wyvern": {"name": "와이번", "mode": "hunt", "tier": 4, "sc": 1.4, "hp": 230.0, "speed": 17.0, "r": 3.2, "fly": true, "coins": 120, "xp": 60,
		"rng": 85.0, "alt": 28.0, "breath_cd": 5.0, "blood": Color(0.85, 0.05, 0.08),
		"drops": [["wyvern_scale", 0.85, 1, 3], ["fire_gland", 0.3, 1, 1], ["fang", 0.5, 1, 2], ["missile", 0.4, 1, 1]]},
	"eye": {"name": "공허의 눈 (보스)", "mode": "hunt", "tier": 5, "hp": 760.0, "speed": 9.0, "r": 4.6, "fly": true, "coins": 320, "xp": 160, "boss": true, "armor": 0.75,
		"rng": 100.0, "alt": 26.0, "blood": Color(0.75, 0.1, 0.4), "orb_cd": 3.0, "laser_cd": 10.0,
		"drops": [["void_shard", 0.9, 1, 3], ["eye_lens", 0.6, 1, 1], ["repair", 0.85, 1, 1], ["missile", 0.7, 1, 2], ["mag", 0.8, 1, 2]]},
}

var kind := "scout"
var T: Dictionary = {}
var ctx: Node = null
var hp := 40.0
var hp_max := 40.0
var vel := Vector3.ZERO
var alive := true
var t := 0.0
var phase := 0.0
var flash_t := 0.0
var blood_t := 0.0
var lock_by_player := 0.0
var cy := 0.0                 # 몸 중심 높이(피격 구 중심)
var mats: Array = []          # [재질, 발광켜짐, 발광색, 발광세기]
var props: Array[Node3D] = []
var wings: Array[Node3D] = []
var arm_nodes: Array[Node3D] = []
var tentacles: Array[Node3D] = []
var body: Node3D
var holder: Node3D
var sc := 1.0
var rad := 1.0
var beam: MeshInstance3D
var orbit_a := 0.0
var orbit_dir := 1.0
var burst_left := 0
var burst_t := 0.0
var rest_t := 1.5
var mis_t := 4.0
var hop_t := 1.0
var spit_t := 2.0
var throw_t := 3.0
var wind := 0.0               # 공격 준비 연출 0~1
var stomp_t := 5.0
var st := "orbit"
var st_t := 2.0
var bite_cd := 0.0
var beam_t := 0.0
var beam_dir := Vector3.FORWARD
var laser_t := 6.0
var orb_t := 2.0
var breath_left := 0
var breath_t := 0.0
var squash := 0.0
var dying := false
var ground_y := 0.0


func setup(k: String, context: Node) -> void:
	kind = k
	T = TYPES[k]
	ctx = context
	hp_max = float(T.hp) * HP_MULT
	hp = hp_max
	phase = randf() * 100.0
	orbit_dir = 1.0 if randf() < 0.5 else -1.0
	cy = float(T.get("cy", T.r * 0.6))
	sc = float(T.get("sc", 1.0))
	holder = Node3D.new()
	holder.scale = Vector3.ONE * sc
	add_child(holder)
	body = Node3D.new()
	holder.add_child(body)
	match k:
		"slime": _m_slime()
		"bat": _m_bat()
		"golem": _m_golem()
		"wyvern": _m_wyvern()
		"eye": _m_eye()
		_: _m_drone()
	cy *= sc
	rad = float(T.r) * sc


func is_boss() -> bool:
	return bool(T.get("boss", false))


func center() -> Vector3:
	return position + Vector3(0, cy, 0)


# ---------------------------------------------------------------- 모델
func _mat(c: Color, em := 0.0, rough := 0.6, metal := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if em > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = em
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats.append([m, m.emission_enabled, m.emission, m.emission_energy_multiplier])
	return m


func _m_drone() -> void:
	var s := {"scout": 1.0, "gunship": 1.4, "striker": 1.2, "ace": 1.7}[kind] as float
	var col: Color = {"scout": Color(0.3, 0.32, 0.36), "gunship": Color(0.27, 0.33, 0.2), "striker": Color(0.75, 0.3, 0.1), "ace": Color(0.06, 0.06, 0.07)}[kind]
	var shell := _mat(col, 0.0, 0.35, 0.5)
	var dark := _mat(Color(0.05, 0.05, 0.06), 0.0, 0.5, 0.3)
	var eye_col: Color = Color(1.0, 0.75, 0.2) if kind == "ace" else Color(1.0, 0.12, 0.1)
	var eye := _mat(eye_col, 3.0)
	var blur := StandardMaterial3D.new()
	blur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blur.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blur.albedo_color = Color(0.1, 0.1, 0.12, 0.2)
	blur.cull_mode = BaseMaterial3D.CULL_DISABLED
	DM._box(body, Vector3(0.9, 0.34, 1.3) * s, Vector3.ZERO, shell)
	DM._sph(body, 0.38 * s, Vector3(0, 0.12 * s, -0.1 * s), shell, Vector3(1, 0.55, 1.4))
	DM._sph(body, 0.17 * s, Vector3(0, -0.02 * s, -0.7 * s), eye)
	DM._box(body, Vector3(0.6, 0.06, 0.9) * s, Vector3(0, 0.2 * s, 0.1 * s), dark)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var tip := Vector3(sx * 1.15, 0.12, sz * 1.0) * s
			DM._arm(body, Vector3(sx * 0.3, 0.0, sz * 0.3) * s, tip, 0.16 * s, 0.1 * s, dark)
			DM._cyl(body, 0.2 * s, 0.22 * s, tip, shell)
			var pr := Node3D.new()
			pr.position = tip + Vector3(0, 0.18 * s, 0)
			body.add_child(pr)
			DM._cyl(pr, 0.62 * s, 0.015, Vector3.ZERO, blur)
			DM._box(pr, Vector3(1.24 * s, 0.02, 0.1 * s), Vector3.ZERO, dark)
			props.append(pr)
	match kind:
		"gunship":
			for sx in [-1.0, 1.0]:
				DM._cyl(body, 0.07 * s, 0.9 * s, Vector3(sx * 0.3 * s, -0.22 * s, -0.7 * s), dark, Vector3(90, 0, 0))
		"striker":
			for sx in [-1.0, 1.0]:
				DM._box(body, Vector3(0.22, 0.2, 0.7) * s, Vector3(sx * 0.58 * s, -0.12 * s, -0.1 * s), dark)
				DM._cyl(body, 0.09 * s, 0.25 * s, Vector3(sx * 0.58 * s, -0.12 * s, -0.55 * s), _mat(Color(0.9, 0.2, 0.1), 0.0, 0.4), Vector3(90, 0, 0), 0.0)
		"ace":
			var gold := _mat(Color(1.0, 0.8, 0.25), 1.2, 0.2, 1.0)
			DM._box(body, Vector3(0.1, 0.5, 0.8) * s, Vector3(0, 0.35 * s, 0.5 * s), gold, Vector3(-15, 0, 0))
			for sx in [-1.0, 1.0]:
				DM._box(body, Vector3(1.1, 0.05, 0.5) * s, Vector3(sx * 0.9 * s, 0.0, 0.4 * s), shell, Vector3(0, sx * -25, 0))
				DM._cyl(body, 0.06 * s, 1.0 * s, Vector3(sx * 0.25 * s, -0.26 * s, -0.75 * s), gold, Vector3(90, 0, 0))
			DM._box(body, Vector3(0.12, 0.04, 1.2) * s, Vector3(0, 0.2 * s, 0.0), gold)
	cy = 0.0


func _m_slime() -> void:
	var gel := _mat(Color(0.35, 0.85, 0.3), 0.35, 0.12, 0.0, 0.78)
	var core := _mat(Color(0.7, 1.0, 0.45), 1.2, 0.3)
	var white := _mat(Color(1, 1, 1), 0.2, 0.3)
	var black := _mat(Color(0.02, 0.02, 0.02), 0.0, 0.3)
	DM._sph(body, 1.25, Vector3(0, 1.0, 0), gel, Vector3(1.0, 0.82, 1.0))
	DM._sph(body, 0.5, Vector3(0.1, 0.8, 0.1), core)
	for sx in [-1.0, 1.0]:
		DM._sph(body, 0.3, Vector3(sx * 0.5, 1.45, -0.95), white)
		DM._sph(body, 0.15, Vector3(sx * 0.5, 1.43, -1.2), black)
	for i in 4:
		DM._sph(body, 0.14 + 0.05 * (i % 2), Vector3(cos(i * 2.1) * 0.7, 0.9 + i * 0.18, sin(i * 2.1) * 0.6 + 0.2), core)
	cy = 1.0


func _m_bat() -> void:
	var fur := _mat(Color(0.22, 0.12, 0.25), 0.0, 0.8)
	var mem := _mat(Color(0.45, 0.2, 0.4), 0.0, 0.7, 0.0, 0.92)
	var red := _mat(Color(1.0, 0.1, 0.12), 3.0)
	var tooth := _mat(Color(1, 1, 0.9), 0.0, 0.3)
	DM._sph(body, 0.45, Vector3.ZERO, fur, Vector3(1.0, 0.85, 1.4))
	DM._sph(body, 0.3, Vector3(0, 0.1, -0.6), fur)
	for sx in [-1.0, 1.0]:
		DM._cyl(body, 0.07, 0.28, Vector3(sx * 0.16, 0.38, -0.62), fur, Vector3(0, 0, sx * -14), 0.0)
		DM._sph(body, 0.06, Vector3(sx * 0.12, 0.14, -0.86), red)
		DM._cyl(body, 0.025, 0.12, Vector3(sx * 0.07, -0.08, -0.86), tooth, Vector3(180, 0, 0), 0.0)
		var pv := Node3D.new()
		pv.position = Vector3(sx * 0.35, 0.05, -0.1)
		pv.set_meta("side", sx)
		body.add_child(pv)
		DM._box(pv, Vector3(0.9, 0.04, 0.09), Vector3(sx * 0.45, 0, 0), fur)
		DM._box(pv, Vector3(0.95, 0.02, 0.75), Vector3(sx * 0.6, 0, 0.3), mem, Vector3(0, sx * -10, 0))
		DM._box(pv, Vector3(0.7, 0.02, 0.6), Vector3(sx * 1.25, 0, 0.35), mem, Vector3(0, sx * -18, 0))
		wings.append(pv)
	cy = 0.0


func _m_golem() -> void:
	var rock := _mat(Color(0.34, 0.31, 0.29), 0.0, 0.95)
	var rock2 := _mat(Color(0.26, 0.24, 0.23), 0.0, 0.95)
	var lava := _mat(Color(1.0, 0.45, 0.1), 3.5)
	DM._box(body, Vector3(3.2, 3.2, 2.2), Vector3(0, 4.6, 0), rock)
	DM._box(body, Vector3(1.5, 1.3, 1.4), Vector3(0, 6.9, -0.2), rock2)
	DM._box(body, Vector3(0.45, 0.2, 0.1), Vector3(-0.36, 7.0, -0.93), lava)
	DM._box(body, Vector3(0.45, 0.2, 0.1), Vector3(0.36, 7.0, -0.93), lava)
	for sx in [-1.0, 1.0]:
		DM._sph(body, 1.0, Vector3(sx * 2.0, 5.9, 0), rock2, Vector3(1, 0.8, 1))
		DM._box(body, Vector3(1.3, 2.5, 1.3), Vector3(sx * 1.0, 1.4, 0), rock2)
		DM._box(body, Vector3(1.5, 0.5, 1.6), Vector3(sx * 1.0, 0.25, -0.1), rock)
		var ar := Node3D.new()
		ar.position = Vector3(sx * 2.15, 5.7, 0)
		ar.set_meta("side", sx)
		body.add_child(ar)
		DM._box(ar, Vector3(1.15, 3.0, 1.15), Vector3(0, -1.5, 0), rock)
		DM._box(ar, Vector3(1.6, 1.5, 1.6), Vector3(0, -3.2, 0), rock2)
		arm_nodes.append(ar)
	for i in 5:
		DM._box(body, Vector3(0.12, 1.1 + 0.2 * (i % 2), 0.1), Vector3(-1.1 + i * 0.55, 4.8 + (i % 3) * 0.3, -1.12), lava, Vector3(0, 0, (i - 2) * 12))
	DM._box(body, Vector3(1.0, 1.0, 0.1), Vector3(0, 4.5, -1.13), lava)
	cy = 4.0


func _m_wyvern() -> void:
	var skin := _mat(Color(0.18, 0.5, 0.45), 0.0, 0.5, 0.1)
	var belly := _mat(Color(0.85, 0.75, 0.5), 0.0, 0.7)
	var mem := _mat(Color(0.12, 0.3, 0.3), 0.0, 0.6, 0.0, 0.95)
	var horn := _mat(Color(0.9, 0.85, 0.7), 0.0, 0.4)
	var eye := _mat(Color(1.0, 0.55, 0.1), 3.0)
	DM._sph(body, 1.5, Vector3.ZERO, skin, Vector3(0.9, 0.8, 2.2))
	DM._sph(body, 1.2, Vector3(0, -0.4, -0.3), belly, Vector3(0.7, 0.5, 2.0))
	for i in 5:
		DM._cyl(body, 0.5 - i * 0.07, 1.2, Vector3(0, 0.5 + i * 0.1, -1.8 - i * 0.9), skin, Vector3(-60 + i * 8, 0, 0))
	DM._sph(body, 0.75, Vector3(0, 2.0, -6.1), skin, Vector3(0.9, 0.8, 1.5))
	DM._cyl(body, 0.28, 0.9, Vector3(0, 1.85, -7.1), skin, Vector3(90, 0, 0), 0.1)
	for sx in [-1.0, 1.0]:
		DM._sph(body, 0.14, Vector3(sx * 0.4, 2.3, -6.2), eye)
		DM._cyl(body, 0.12, 1.0, Vector3(sx * 0.35, 2.9, -5.5), horn, Vector3(-40, 0, sx * -12), 0.0)
	for i in 6:
		DM._cyl(body, 0.42 - i * 0.06, 1.8, Vector3(0, 0.0 - i * 0.05, 2.0 + i * 1.5), skin, Vector3(90, 0, 0), 0.4 - i * 0.07)
		if i % 2 == 0:
			DM._cyl(body, 0.15, 0.9, Vector3(0, 0.6, 1.2 + i * 1.5), horn, Vector3.ZERO, 0.0)
	for sx in [-1.0, 1.0]:
		var pv := Node3D.new()
		pv.position = Vector3(sx * 1.0, 0.8, -0.6)
		pv.set_meta("side", sx)
		body.add_child(pv)
		DM._box(pv, Vector3(4.2, 0.18, 0.28), Vector3(sx * 2.1, 0, 0), skin)
		DM._box(pv, Vector3(4.0, 0.06, 3.0), Vector3(sx * 2.2, 0, 1.4), mem, Vector3(0, sx * -8, 0))
		DM._box(pv, Vector3(3.4, 0.05, 2.4), Vector3(sx * 5.6, 0, 1.6), mem, Vector3(0, sx * -16, 0))
		DM._box(pv, Vector3(3.5, 0.15, 0.2), Vector3(sx * 5.6, 0, 0.3), skin, Vector3(0, sx * 10, 0))
		wings.append(pv)
		DM._cyl(body, 0.22, 1.4, Vector3(sx * 0.7, -1.2, 0.4), skin, Vector3(25, 0, 0), 0.12)
	cy = 0.0


func _m_eye() -> void:
	var flesh := _mat(Color(0.5, 0.12, 0.28), 0.3, 0.45)
	var white := _mat(Color(0.95, 0.93, 0.9), 0.25, 0.25)
	var iris := _mat(Color(0.9, 0.12, 0.3), 2.2)
	var pupil := _mat(Color(0.0, 0.0, 0.0), 0.0, 0.1)
	var vein := _mat(Color(0.7, 0.1, 0.15), 0.5)
	DM._sph(body, 4.4, Vector3.ZERO, flesh)
	DM._sph(body, 3.4, Vector3(0, 0, -1.4), white, Vector3(1, 1, 0.8))
	DM._sph(body, 1.9, Vector3(0, 0, -3.8), iris, Vector3(1, 1, 0.4))
	DM._sph(body, 0.95, Vector3(0, 0, -4.35), pupil, Vector3(0.7, 1.5, 0.4))
	for i in 7:
		var a := i * 0.9
		DM._cyl(body, 0.06, 1.8, Vector3(cos(a) * 2.2, sin(a) * 2.2, -3.0), vein, Vector3(sin(a) * 25, cos(a) * 25, 0))
	for i in 8:
		var a2 := i * TAU / 8.0
		var tn := Node3D.new()
		tn.position = Vector3(cos(a2) * 2.6, -2.6 + sin(a2) * 0.5, sin(a2) * 2.6 + 0.6)
		body.add_child(tn)
		for j in 5:
			DM._cyl(tn, 0.38 - j * 0.06, 1.5, Vector3(0, -j * 1.3, 0), flesh)
		tentacles.append(tn)
	for i in 6:
		var a3 := i * TAU / 6.0
		DM._cyl(body, 0.35, 1.5, Vector3(cos(a3) * 3.9, sin(a3) * 3.9, 0.5), flesh, Vector3(0, 0, rad_to_deg(a3) - 90.0), 0.0)
	beam = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 1.0
	bm.bottom_radius = 1.0
	bm.height = 1.0
	bm.radial_segments = 8
	beam.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(1.0, 0.25, 0.35, 0.8)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = bmat
	beam.visible = false
	beam.top_level = true
	add_child(beam)
	cy = 0.0


# ---------------------------------------------------------------- 피격·사망
func segment_hit(a: Vector3, b: Vector3, extra := 0.0) -> bool:
	var c := center()
	var r: float = rad + extra
	var ab := b - a
	var l2 := ab.length_squared()
	var tt := 0.0 if l2 < 0.0001 else clampf((c - a).dot(ab) / l2, 0.0, 1.0)
	return (a + ab * tt).distance_squared_to(c) <= r * r


func hurt(dmg: float, point: Vector3, dir: Vector3, src: String) -> void:
	if not alive:
		return
	var d := dmg
	if src == "bullet":
		d *= float(T.get("armor", 1.0))
	hp -= d
	flash_t = 0.09
	blood_t -= 0.0
	if blood_t <= 0.0:
		blood_t = 0.05
		ctx.fx.blood(point, -dir, T.blood, 14 if src == "bullet" else 40, kind in ["scout", "gunship", "striker", "ace"])
	if hp <= 0.0:
		_die(point)


func _die(point: Vector3) -> void:
	alive = false
	dying = true
	var drone_like: bool = kind in ["scout", "gunship", "striker", "ace"]
	ctx.fx.blood(center(), Vector3.UP, T.blood, 90 if is_boss() else 55, drone_like, true)
	if drone_like:
		ctx.fx.burst(center(), Color(1.0, 0.6, 0.2), 40, 14.0, 0.25)
		ctx.fx.burst(center(), Color(0.2, 0.2, 0.22), 24, 7.0, 0.35)
	ctx.on_enemy_die(self)
	var tw := create_tween()
	if drone_like:
		tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.12)
	elif is_boss():
		tw.tween_property(self, "scale", Vector3(1.1, 0.1, 1.1), 0.9).set_trans(Tween.TRANS_QUAD)
	else:
		tw.tween_property(self, "scale", Vector3(1.25, 0.05, 1.25), 0.35).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(queue_free)
	if beam != null:
		beam.visible = false


# ---------------------------------------------------------------- 갱신
func tick(dt: float) -> void:
	if dying:
		return
	t += dt
	_anim(dt)
	bite_cd = maxf(0.0, bite_cd - dt)
	var P: Vector3 = ctx.drone.position
	var dist := position.distance_to(P)
	match kind:
		"slime": _ai_slime(dt, P, dist)
		"bat": _ai_bat(dt, P, dist)
		"golem": _ai_golem(dt, P, dist)
		"wyvern": _ai_wyvern(dt, P, dist)
		"eye": _ai_eye(dt, P, dist)
		_: _ai_drone(dt, P, dist)


func _anim(dt: float) -> void:
	flash_t = maxf(0.0, flash_t - dt)
	blood_t = maxf(0.0, blood_t - dt)
	var on := flash_t > 0.0
	for e in mats:
		var m: StandardMaterial3D = e[0]
		if on:
			m.emission_enabled = true
			m.emission = Color(1, 0.85, 0.8)
			m.emission_energy_multiplier = 1.8
		else:
			m.emission_enabled = e[1]
			m.emission = e[2]
			m.emission_energy_multiplier = e[3]
	for p in props:
		p.rotate_y(dt * 60.0)
	for w in wings:
		var sd: float = w.get_meta("side")
		var spd := 14.0 if kind == "bat" else 3.6
		var amp := 0.7 if kind == "bat" else 0.55
		w.rotation.z = sd * sin(t * spd + phase) * amp
	for i in tentacles.size():
		tentacles[i].rotation.z = sin(t * 1.3 + i) * 0.25
		tentacles[i].rotation.x = cos(t * 1.1 + i * 1.7) * 0.25
	if kind == "golem":
		for a in arm_nodes:
			var sd2: float = a.get_meta("side")
			var raise := wind * 2.6
			a.rotation.x = -raise if sd2 > 0.0 else sin(t * 1.5) * 0.15
			if sd2 < 0.0:
				a.rotation.x = -raise * 0.0 + sin(t * 1.5) * 0.15
	if kind == "slime":
		squash = lerpf(squash, 0.0, 1.0 - exp(-9.0 * dt))
		body.scale = Vector3(1.0 + squash * 0.35 + wind * 0.2, 1.0 - squash * 0.35 - wind * 0.12, 1.0 + squash * 0.35 + wind * 0.2)
	if kind == "eye":
		body.position.y = sin(t * 0.9 + phase) * 0.8
		body.scale = Vector3.ONE * (1.0 + 0.03 * sin(t * 2.0))


## 부드럽게 목표 지점으로 날아간다(지형·건물 회피 포함)
func _steer(target: Vector3, speed: float, accel: float, dt: float) -> void:
	var want := target - position
	var d := want.length()
	var v := Vector3.ZERO if d < 0.05 else want / d * minf(speed, d * 1.5)
	vel = vel.lerp(v, 1.0 - exp(-accel * dt))
	_move(dt, 5.0)


func _move(dt: float, clear: float) -> void:
	position += vel * dt
	var g: float = ctx.terrain.ground(position.x, position.z)
	if position.y < g + clear:
		position.y = g + clear
		if vel.y < 0.0:
			vel.y = 0.0
	if ctx.buildings != null:
		var cr: Dictionary = ctx.buildings.collide(position, vel, maxf(rad * 0.8, 1.0))
		position = cr.pos
		vel = cr.vel


func _face(dir: Vector3, k: float, dt: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-k * dt))


func _lead(P: Vector3, spd: float, factor: float) -> Vector3:
	var d := position.distance_to(P)
	return P + (ctx.drone.vel as Vector3) * (d / maxf(spd, 1.0)) * factor


func _spread(dir: Vector3, deg: float) -> Vector3:
	var b := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	var a := randf() * TAU
	var r := tan(deg_to_rad(deg)) * sqrt(randf())
	return (b * Vector3(cos(a) * r, sin(a) * r, -1.0)).normalized()


# ---- 적 드론 ----
func _ai_drone(dt: float, P: Vector3, dist: float) -> void:
	if orbit_a == 0.0:
		orbit_a = atan2(position.z - P.z, position.x - P.x)
	var rr: float = float(T.rng) + sin(t * 0.5 + phase) * 18.0
	orbit_a += orbit_dir * (float(T.speed) / maxf(rr, 20.0)) * dt * 0.55
	var base := P + Vector3(cos(orbit_a), 0.0, sin(orbit_a)) * rr
	base.y = P.y + float(T.alt) + sin(t * 0.7 + phase) * 7.0
	_steer(base, float(T.speed), 1.7, dt)
	var aim := (P - position)
	_face(aim, 5.0, dt)
	body.rotation.z = lerpf(body.rotation.z, clampf(-vel.dot(global_transform.basis.x) * 0.03, -0.5, 0.5), 1.0 - exp(-5.0 * dt))
	body.rotation.x = lerpf(body.rotation.x, clampf(vel.dot(global_transform.basis.z) * 0.02, -0.4, 0.4), 1.0 - exp(-5.0 * dt))
	rest_t -= dt
	if burst_left > 0:
		burst_t -= dt
		if burst_t <= 0.0:
			burst_left -= 1
			burst_t = float(T.gap)
			var muzzle := position + global_transform.basis * (Vector3(0, -0.2, -1.2) * sc)
			var tgt := _lead(P, float(T.bspeed), float(T.lead))
			ctx.enemy_shot(muzzle, _spread((tgt - muzzle).normalized(), float(T.spread)), float(T.bspeed), float(T.bdmg), Color(1.0, 0.3, 0.15), 0, 2.0, 0.0)
	elif rest_t <= 0.0 and dist < float(T.fire_range):
		burst_left = int(T.burst)
		burst_t = 0.0
		rest_t = float(T.burst) * float(T.gap) + float(T.rest) + randf() * 0.9
	if T.has("mis_cd"):
		mis_t -= dt
		if mis_t <= 0.0 and dist > 50.0 and dist < 280.0:
			mis_t = float(T.mis_cd) + randf() * 2.0
			ctx.enemy_missile(self)


# ---- 슬라임 ----
func _ai_slime(dt: float, P: Vector3, dist: float) -> void:
	var g: float = ctx.terrain.ground(position.x, position.z)
	var on_g := position.y <= g + 0.05
	if not on_g:
		vel.y -= 22.0 * dt
	else:
		position.y = g
		vel.x *= exp(-6.0 * dt)
		vel.z *= exp(-6.0 * dt)
		if vel.y < 0.0:
			vel.y = 0.0
		hop_t -= dt
		if hop_t <= 0.0 and dist < 320.0:
			var h := Vector3(P.x - position.x, 0.0, P.z - position.z)
			if h.length() > 10.0:
				h = h.normalized()
				vel = h * float(T.speed) * 1.3 + Vector3(0, 8.0, 0)
				_face(h, 100.0, 1.0)
				squash = -0.6
			else:
				vel.y = 5.0
			hop_t = randf_range(1.0, 1.7)
	position += vel * dt
	if position.y < g:
		position.y = g
		if vel.y < -2.0:
			squash = 0.7
	spit_t -= dt
	wind = clampf(1.0 - spit_t / 0.5, 0.0, 1.0) if spit_t < 0.5 else 0.0
	if spit_t <= 0.0:
		spit_t = float(T.spit_cd) + randf() * 1.0
		if dist < float(T.spit_range):
			var muzzle := position + Vector3(0, 1.6, 0) * sc
			var tgt := _lead(P, 30.0, 0.5)
			ctx.enemy_shot(muzzle, _spread((tgt - muzzle).normalized(), 3.0), 30.0, float(T.spit_dmg), Color(0.45, 0.95, 0.25), 1, 2.8, 0.0, 0.45)
			ctx.audio_pop(position)


# ---- 박쥐 ----
func _ai_bat(dt: float, P: Vector3, dist: float) -> void:
	st_t -= dt
	match st:
		"orbit":
			if orbit_a == 0.0:
				orbit_a = atan2(position.z - P.z, position.x - P.x)
			orbit_a += orbit_dir * 0.9 * dt
			var rr := 22.0 + sin(t * 1.3 + phase) * 8.0
			var tp := P + Vector3(cos(orbit_a) * rr, 5.0 + sin(t * 2.1 + phase) * 6.0, sin(orbit_a) * rr)
			_steer(tp, float(T.speed), 3.0, dt)
			if st_t <= 0.0:
				st = "dive"
				st_t = 1.7
		"dive":
			_steer(P, 36.0, 4.0, dt)
			if dist < 3.2 and bite_cd <= 0.0:
				bite_cd = 1.0
				ctx.hurt_player(float(T.dmg), position)
				st = "retreat"
				st_t = 1.4
			elif st_t <= 0.0:
				st = "retreat"
				st_t = 1.0
		_:
			var away := (position - P).normalized()
			_steer(position + away * 25.0 + Vector3(0, 10, 0), 24.0, 3.0, dt)
			if st_t <= 0.0:
				st = "orbit"
				st_t = randf_range(2.5, 5.0)
				orbit_a = atan2(position.z - P.z, position.x - P.x)
	_face(vel, 6.0, dt)
	body.rotation.x = lerpf(body.rotation.x, clampf(-vel.y * 0.03, -0.6, 0.6), 1.0 - exp(-4.0 * dt))


# ---- 골렘 ----
func _ai_golem(dt: float, P: Vector3, dist: float) -> void:
	var h := Vector3(P.x - position.x, 0.0, P.z - position.z)
	var hd := h.length()
	if hd > 60.0:
		vel = h.normalized() * float(T.speed)
	else:
		vel = vel.lerp(Vector3.ZERO, 1.0 - exp(-3.0 * dt))
	position += vel * dt
	position.y = ctx.terrain.ground(position.x, position.z)
	_face(h, 2.5, dt)
	body.position.y = absf(sin(t * 3.0)) * 0.25 * clampf(vel.length() / 4.0, 0.0, 1.0)
	throw_t -= dt
	wind = clampf(1.0 - throw_t / 0.9, 0.0, 1.0) if throw_t < 0.9 else 0.0
	if throw_t <= 0.0:
		throw_t = float(T.throw_cd) + randf() * 1.2
		if dist < float(T.throw_range):
			var muzzle := position + Vector3(0, 8.0, 0) * sc
			var tgt := _lead(P, 40.0, 0.8)
			ctx.enemy_shot(muzzle, _spread((tgt - muzzle).normalized(), 2.0), 40.0, float(T.throw_dmg), Color(0.5, 0.42, 0.34), 1, 4.0, 4.0, 1.1)
			ctx.audio_pop(position)
	stomp_t -= dt
	if stomp_t <= 0.0 and hd < 24.0 and P.y - position.y < 14.0:
		stomp_t = 6.0
		ctx.shockwave(position, 24.0, 14.0)


# ---- 와이번 ----
func _ai_wyvern(dt: float, P: Vector3, dist: float) -> void:
	if orbit_a == 0.0:
		orbit_a = atan2(position.z - P.z, position.x - P.x)
	orbit_a += orbit_dir * (float(T.speed) / float(T.rng)) * dt * 0.7
	var tp := P + Vector3(cos(orbit_a), 0.0, sin(orbit_a)) * float(T.rng)
	tp.y = P.y + float(T.alt) + sin(t * 0.6 + phase) * 8.0
	_steer(tp, float(T.speed), 1.4, dt)
	_face(vel if breath_left == 0 and wind <= 0.0 else (P - position), 3.0, dt)
	body.rotation.z = lerpf(body.rotation.z, clampf(-orbit_dir * 0.35, -0.5, 0.5), 1.0 - exp(-2.0 * dt))
	st_t -= dt
	wind = clampf(1.0 - st_t / 0.9, 0.0, 1.0) if st_t < 0.9 and breath_left == 0 else 0.0
	if st_t <= 0.0 and breath_left == 0:
		breath_left = 5
		breath_t = 0.0
		st_t = float(T.breath_cd) + randf() * 1.5
	if breath_left > 0:
		breath_t -= dt
		if breath_t <= 0.0:
			breath_left -= 1
			breath_t = 0.14
			var muzzle := position + global_transform.basis * (Vector3(0, 2.0, -7.4) * sc)
			var tgt := _lead(P, 55.0, 0.8)
			ctx.enemy_shot(muzzle, _spread((tgt - muzzle).normalized(), 2.5), 55.0, 9.0, Color(1.0, 0.45, 0.1), 1, 3.0, 0.0, 0.65)


# ---- 공허의 눈 ----
func _ai_eye(dt: float, P: Vector3, dist: float) -> void:
	if orbit_a == 0.0:
		orbit_a = atan2(position.z - P.z, position.x - P.x)
	orbit_a += orbit_dir * 0.06 * dt
	var tp := P + Vector3(cos(orbit_a), 0.0, sin(orbit_a)) * float(T.rng)
	tp.y = P.y + float(T.alt)
	_steer(tp, float(T.speed), 1.0, dt)
	_face(P - position, 3.0, dt)
	orb_t -= dt
	if orb_t <= 0.0 and beam_t <= 0.0:
		orb_t = float(T.orb_cd)
		var muzzle := position + global_transform.basis * (Vector3(0, 0, -5.5) * sc)
		var tgt := _lead(P, 36.0, 0.5)
		var base := (tgt - muzzle).normalized()
		var rgt := base.cross(Vector3.UP).normalized()
		for k in range(-3, 4):
			var d := (base + rgt * (k * 0.07)).normalized()
			ctx.enemy_shot(muzzle, d, 36.0, 7.0, Color(0.95, 0.2, 0.7), 1, 5.0, 0.0, 0.55)
		ctx.audio_pop(position)
	laser_t -= dt
	if beam_t <= 0.0 and laser_t <= 0.0 and dist < 260.0:
		beam_t = 2.1
		laser_t = float(T.laser_cd)
		beam_dir = (P - center()).normalized()
	if beam_t > 0.0:
		var prev := beam_t
		beam_t -= dt
		var want := (P - center()).normalized()
		beam_dir = beam_dir.slerp(want, 1.0 - exp(-(1.2 if beam_t > 0.5 else 0.0) * dt)).normalized()
		var firing := beam_t < 0.45
		var L := 280.0
		var mid := center() + beam_dir * (L * 0.5)
		beam.visible = true
		beam.global_position = mid
		beam.global_basis = Basis.looking_at(beam_dir, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
		var th := 0.22 if not firing else 1.6
		beam.scale = Vector3(th, L, th)
		(beam.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.2, 0.3, 0.3 if not firing else 0.7)
		if firing and prev >= 0.45:
			ctx.audio_pop(position)
		if firing:
			var a := center()
			var ab := beam_dir * L
			var tt := clampf((P - a).dot(ab) / (L * L), 0.0, 1.0)
			if (a + ab * tt).distance_to(P) < 3.8 and bite_cd <= 0.0:
				bite_cd = 1.0
				ctx.hurt_player(38.0, position)
		if beam_t <= 0.0:
			beam.visible = false
