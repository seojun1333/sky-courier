extends HBoxContainer
## 설정 화면: 화면·소리·조작 옵션과 키 재설정. 값은 profile.data.settings에 바로 쓰고 changed를 내보낸다.

signal changed

const UI := preload("res://ui.gd")
const KeysScript := preload("res://keys.gd")

const SLIDERS := [
	{"key": "sens", "name": "마우스 감도", "min": 0.3, "max": 3.0, "step": 0.05, "fmt": "%d%%", "mul": 100.0},
	{"key": "fov", "name": "시야각", "min": 70.0, "max": 110.0, "step": 1.0, "fmt": "%d°", "mul": 1.0},
	{"key": "brightness", "name": "화면 밝기", "min": 0.6, "max": 1.6, "step": 0.05, "fmt": "%d%%", "mul": 100.0},
	{"key": "volume", "name": "전체 볼륨", "min": 0.0, "max": 1.0, "step": 0.05, "fmt": "%d%%", "mul": 100.0},
	{"key": "music", "name": "음악", "min": 0.0, "max": 1.0, "step": 0.05, "fmt": "%d%%", "mul": 100.0},
	{"key": "sfx", "name": "효과음", "min": 0.0, "max": 1.0, "step": 0.05, "fmt": "%d%%", "mul": 100.0},
	{"key": "shake", "name": "카메라 흔들림", "min": 0.0, "max": 1.5, "step": 0.05, "fmt": "%d%%", "mul": 100.0},
]
const CHECKS := [
	{"key": "assist", "name": "비행 보조 (키를 떼면 바로 멈춤)"},
	{"key": "invert", "name": "마우스 상하 반전"},
	{"key": "hud", "name": "계기판(OSD) 표시"},
	{"key": "minimap", "name": "미니맵 표시"},
	{"key": "speedlines", "name": "속도선 효과"},
]

var settings: Dictionary
var saved_keys: Dictionary
var waiting := ""
var key_buttons := {}


func setup(s: Dictionary, keys_saved: Dictionary) -> void:
	settings = s
	saved_keys = keys_saved
	add_theme_constant_override("separation", 40)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 9)
	add_child(left)
	left.add_child(UI.label("화면 · 소리", 22, UI.ACCENT, "head"))
	for d in SLIDERS:
		left.add_child(_slider(d))
	left.add_child(_cycle("quality", "그래픽 품질", ["낮음 (빠름)", "보통", "높음"]))
	left.add_child(_cycle("colorblind", "색약 모드", ["끔", "적색약", "녹색약", "청색약"]))
	for c in CHECKS:
		left.add_child(_check(c))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	add_child(right)
	right.add_child(UI.label("조작 키  (클릭 후 새 키를 누르세요)", 22, UI.ACCENT, "head"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	right.add_child(grid)
	for a in KeysScript.ACTIONS:
		var l := UI.label(a.name, 16, UI.DIM)
		l.custom_minimum_size = Vector2(110, 0)
		grid.add_child(l)
		var b := UI.button(KeysScript.key_name(a.id), Vector2(86, 32))
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(_begin_capture.bind(a.id))
		grid.add_child(b)
		key_buttons[a.id] = b
	var rb := UI.button("기본 키로 되돌리기", Vector2(0, 38))
	rb.pressed.connect(func() -> void:
		KeysScript.reset(saved_keys)
		_refresh_keys()
		changed.emit())
	right.add_child(rb)
	var info := UI.label("마우스: 시점 · 우클릭 줌  |  ESC: 일시정지  |  Tab: 튜토리얼 건너뛰기\n게임패드: 왼쪽 스틱 상승/회전 · 오른쪽 스틱 이동 · Y 시점 · X 미션 · B 사진", 14, UI.DIM)
	right.add_child(info)


func _slider(d: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lab := UI.label(d.name, 17, UI.TEXT)
	lab.custom_minimum_size = Vector2(130, 0)
	row.add_child(lab)
	var sl := HSlider.new()
	sl.min_value = d.min
	sl.max_value = d.max
	sl.step = d.step
	sl.value = float(settings[d.key])
	sl.custom_minimum_size = Vector2(230, 26)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sl)
	var val := UI.label(d.fmt % (sl.value * d.mul), 17, UI.AMBER, "head")
	val.custom_minimum_size = Vector2(64, 0)
	row.add_child(val)
	sl.value_changed.connect(func(v: float) -> void:
		settings[d.key] = v
		val.text = d.fmt % (v * d.mul)
		changed.emit())
	return row


func _check(c: Dictionary) -> Control:
	var cb := CheckButton.new()
	cb.text = c.name
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = bool(settings[c.key])
	cb.toggled.connect(func(on: bool) -> void:
		UI.click()
		settings[c.key] = on
		changed.emit())
	return cb


func _cycle(key: String, name: String, opts: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lab := UI.label(name, 17, UI.TEXT)
	lab.custom_minimum_size = Vector2(130, 0)
	row.add_child(lab)
	var b := UI.button(opts[int(settings[key]) % opts.size()], Vector2(200, 34))
	b.pressed.connect(func() -> void:
		settings[key] = (int(settings[key]) + 1) % opts.size()
		b.text = opts[int(settings[key])]
		changed.emit())
	row.add_child(b)
	return row


func _begin_capture(id: String) -> void:
	waiting = id
	for k in key_buttons:
		(key_buttons[k] as Button).text = KeysScript.key_name(k)
	(key_buttons[id] as Button).text = "키 입력…"


func _refresh_keys() -> void:
	for k in key_buttons:
		(key_buttons[k] as Button).text = KeysScript.key_name(k)


func _input(event: InputEvent) -> void:
	if waiting == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.keycode != KEY_ESCAPE:
		KeysScript.rebind(waiting, event.physical_keycode, saved_keys)
		UI.click()
		changed.emit()
	waiting = ""
	_refresh_keys()
