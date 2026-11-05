extends Control
## 첫 실행 때 한 번 보이는 오프닝 자막. 클릭이나 아무 키로 넘기고, 끝나면 finished를 낸다.

signal finished

const UI := preload("res://ui.gd")
const StoryScript := preload("res://story.gd")

var lines: Array = StoryScript.INTRO
var i := -1
var label: Label
var hint: Label
var busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.03)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	label = UI.label("", 30, UI.TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(900, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cc.add_child(label)
	hint = UI.label("클릭 또는 아무 키 · ESC 건너뛰기", 14, Color(1, 1, 1, 0.3))
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position.y -= 40.0
	hint.position.x -= 140.0
	add_child(hint)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_next()


func _next() -> void:
	if busy:
		return
	i += 1
	if i >= lines.size():
		finished.emit()
		return
	busy = true
	var tw := create_tween()
	if i > 0:
		tw.tween_property(label, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		label.text = String(lines[i])
		label.modulate.a = 0.0)
	tw.tween_property(label, "modulate:a", 1.0, 0.8)
	tw.tween_callback(func() -> void: busy = false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_next()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			finished.emit()
		else:
			_next()
