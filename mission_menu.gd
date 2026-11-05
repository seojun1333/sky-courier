extends Control
## 미션 선택 화면(N). 종류, 설명, 이 맵에서의 최고 기록과 별을 보여 준다.

signal picked(type: String)
signal closed

const UI := preload("res://ui.gd")
const StoryScript := preload("res://story.gd")

var profile: RefCounted
var missions: Node3D
var world_id := "city"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)
	col.add_child(UI.label("오늘의 배송 의뢰", 40, UI.TEXT, "head"))
	col.add_child(UI.label("관제 노을: 「어떤 일부터 해 볼까요?」  —  번호 키 또는 클릭 · ESC 닫기", 16, UI.DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var types: Array = missions.TYPES
	for i in types.size():
		row.add_child(_card(i, types[i]))
	UI.fade_in(self, 0.18)


func _card(i: int, type: String) -> Control:
	var ok: bool = missions.available(type)
	var key: String = missions.record_key(type)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 320)
	panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.35 if ok else 0.08), 14, 1, 16))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UI.label("%d" % (i + 1), 30, UI.ACCENT if ok else UI.DIM, "head"))
	v.add_child(UI.label(StoryScript.MISSION_NAMES[type], 24, UI.TEXT if ok else UI.DIM))
	var ds := UI.label(StoryScript.MISSION_DESC[type], 15, UI.DIM)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(218, 96)
	v.add_child(ds)
	var st: int = int(profile.data.stars.get(key, 0))
	v.add_child(UI.label(StoryScript.stars_text(st) if st > 0 else "아직 도전 전", 22, UI.AMBER if st > 0 else UI.DIM))
	var best: float = float(profile.data.records.get(key, 0.0))
	v.add_child(UI.label("최고 기록  %s" % ("%d:%02d" % [int(best) / 60, int(best) % 60] if best > 0.0 else "--:--"), 15, UI.DIM))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var b := UI.button("출발" if ok else "랭크 %d 필요" % int(missions.MIN_RANK[type]), Vector2(0, 42), ok)
	b.disabled = not ok
	b.pressed.connect(func() -> void: picked.emit(type))
	v.add_child(b)
	return panel


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.is_action_pressed("mission"):
			get_viewport().set_input_as_handled()
			closed.emit()
			return
		var n: int = event.keycode - KEY_1
		var types: Array = missions.TYPES
		if n >= 0 and n < types.size() and missions.available(types[n]):
			get_viewport().set_input_as_handled()
			picked.emit(types[n])
