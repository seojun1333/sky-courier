extends Node
## 처음 5분 안내: 이륙 → 이동 → 회전 → 고도 → 부스트 → 시점 → 미션 → 링 통과. 단계마다 완료 조건을 스스로 확인한다.

signal finished

const KeysScript := preload("res://keys.gd")

var drone: Node3D
var missions: Node3D
var terrain: Node3D
var profile: RefCounted
var active := false
var step := 0
var start_pos := Vector3.ZERO
var yaw_acc := 0.0
var last_yaw := 0.0
var boost_t := 0.0
var ring0 := 0.0
var done_t := 0.0

const TEXTS := [
	"<up> 키로 이륙하세요",
	"<move_fwd> 키로 앞으로 30m 날아가 보세요",
	"마우스 또는 <yaw_left> / <yaw_right> 로 방향을 돌려 보세요",
	"<up> 으로 오르거나, 마우스로 위를 보고 <move_fwd> 로 날아 지상 25m 위까지 올라가세요",
	"<boost> 를 누른 채 속도를 올려 보세요",
	"<toggle_view> 로 3인칭 시점으로 바꿔 보세요",
	"<mission> 키로 미션 메뉴를 열어 '항로 개척'을 시작하세요",
	"표시된 링을 통과해 보세요",
]


func setup(d: Node3D, m: Node3D, t: Node3D, p: RefCounted) -> void:
	drone = d
	missions = m
	terrain = t
	profile = p
	active = not p.data.tutorial_done
	step = 0
	last_yaw = d.yaw


func text() -> String:
	if not active or step >= TEXTS.size():
		return ""
	var s: String = TEXTS[step]
	for a in KeysScript.ACTIONS:
		s = s.replace("<%s>" % a.id, "[%s]" % KeysScript.key_name(a.id))
	return s


func progress_text() -> String:
	return "튜토리얼 %d / %d" % [mini(step + 1, TEXTS.size()), TEXTS.size()]


func skip() -> void:
	if active:
		active = false
		profile.data.tutorial_done = true


func _advance() -> void:
	step += 1
	start_pos = drone.position
	yaw_acc = 0.0
	last_yaw = drone.yaw
	boost_t = 0.0
	if step == 7:
		ring0 = profile.stat("rings")
	if step >= TEXTS.size():
		active = false
		profile.data.tutorial_done = true
		finished.emit()


func update(dt: float) -> void:
	if not active:
		return
	var pos: Vector3 = drone.position
	var alt: float = pos.y - terrain.ground(pos.x, pos.z)
	yaw_acc += absf(angle_difference(last_yaw, drone.yaw))
	last_yaw = drone.yaw
	var ok := false
	match step:
		0:
			ok = drone.state == "flying" and alt > 2.0
			if ok:
				start_pos = pos
		1:
			ok = Vector2(pos.x - start_pos.x, pos.z - start_pos.z).length() > 30.0
		2:
			ok = rad_to_deg(yaw_acc) > 80.0
		3:
			ok = alt >= 25.0
		4:
			if Input.is_action_pressed("boost"):
				boost_t += dt
			ok = boost_t > 1.0
		5:
			ok = drone.third
		6:
			ok = missions.active
		7:
			ok = profile.stat("rings") > ring0
	if ok:
		_advance()
