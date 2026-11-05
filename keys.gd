extends RefCounted
## 조작 키 목록과 재설정. 키보드 입력은 모두 InputMap 액션을 거친다.

const ACTIONS := [
	{"id": "move_fwd", "name": "앞으로", "keys": [KEY_W]},
	{"id": "move_back", "name": "뒤로", "keys": [KEY_S]},
	{"id": "move_left", "name": "왼쪽", "keys": [KEY_A]},
	{"id": "move_right", "name": "오른쪽", "keys": [KEY_D]},
	{"id": "up", "name": "상승", "keys": [KEY_SPACE, KEY_UP]},
	{"id": "down", "name": "하강", "keys": [KEY_CTRL, KEY_C, KEY_DOWN]},
	{"id": "yaw_left", "name": "좌회전", "keys": [KEY_Q, KEY_LEFT]},
	{"id": "yaw_right", "name": "우회전", "keys": [KEY_E, KEY_RIGHT]},
	{"id": "boost", "name": "부스트", "keys": [KEY_SHIFT]},
	{"id": "cam_down", "name": "카메라 내리기", "keys": [KEY_Z]},
	{"id": "cam_up", "name": "카메라 올리기", "keys": [KEY_X]},
	{"id": "toggle_view", "name": "시점 전환", "keys": [KEY_V]},
	{"id": "mission", "name": "미션 메뉴", "keys": [KEY_N]},
	{"id": "photo", "name": "사진 촬영", "keys": [KEY_P]},
	{"id": "map", "name": "전체 지도", "keys": [KEY_M]},
	{"id": "assist", "name": "비행 보조", "keys": [KEY_F]},
	{"id": "go_home", "name": "귀환", "keys": [KEY_R]},
	{"id": "settings", "name": "설정", "keys": [KEY_O]},
	{"id": "fire", "name": "기관포 발사 (전투)", "keys": [KEY_J]},
	{"id": "missile", "name": "유도탄 발사 (전투)", "keys": [KEY_G]},
	{"id": "inventory", "name": "보관함", "keys": [KEY_I]},
]


static func setup(saved: Dictionary) -> void:
	for a in ACTIONS:
		var id: String = a.id
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		InputMap.action_erase_events(id)
		var codes: Array = [int(saved[id])] if saved.has(id) else a.keys
		for k in codes:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(k)
			InputMap.action_add_event(id, ev)
	# 게임패드 단추(시점 Y, 미션 X, 사진 B, 부스트 오른쪽 범퍼)
	_pad("toggle_view", JOY_BUTTON_Y)
	_pad("mission", JOY_BUTTON_X)
	_pad("photo", JOY_BUTTON_B)
	_pad("boost", JOY_BUTTON_RIGHT_SHOULDER)
	_pad("assist", JOY_BUTTON_LEFT_SHOULDER)
	_pad("map", JOY_BUTTON_BACK)
	_pad("go_home", JOY_BUTTON_DPAD_DOWN)
	_pad("fire", JOY_BUTTON_A)
	_pad("missile", JOY_BUTTON_LEFT_STICK)
	_pad("inventory", JOY_BUTTON_DPAD_UP)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", mb)


static func _pad(action: String, btn: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = btn
	InputMap.action_add_event(action, ev)


static func key_name(id: String) -> String:
	for ev in InputMap.action_get_events(id):
		if ev is InputEventKey:
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode))
	return "-"


## 이미 다른 액션이 쓰는 키면 서로 바꾼다. 돌려주는 값: 바뀐 액션 id(없으면 "")
static func rebind(id: String, code: int, saved: Dictionary) -> String:
	if code == KEY_ESCAPE:
		return ""
	var swapped := ""
	var old_code := -1
	for ev in InputMap.action_get_events(id):
		if ev is InputEventKey:
			old_code = ev.physical_keycode
			break
	for a in ACTIONS:
		if a.id == id:
			continue
		for ev in InputMap.action_get_events(a.id):
			if ev is InputEventKey and ev.physical_keycode == code:
				swapped = a.id
				saved[a.id] = old_code if old_code > 0 else a.keys[0]
	saved[id] = code
	setup(saved)
	return swapped


static func reset(saved: Dictionary) -> void:
	saved.clear()
	setup(saved)
