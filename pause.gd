extends Control
## ESC 일시정지 메뉴: 계속하기 · 설정 · 로비로 나가기.

signal resume
signal lobby

const UI := preload("res://ui.gd")
const SettingsPanel := preload("res://settings_panel.gd")

var main: Node
var box: Control
var settings_box: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.025, 0.05, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.LINE, 16, 1, 28))
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	box = v
	v.add_child(UI.label("일시정지", 40, UI.TEXT, "head"))
	v.add_child(UI.label("관제 노을: 「잠깐 쉬어가요. 기체는 안전해요.」", 14, UI.DIM))
	var bs := [["계속하기", func() -> void: resume.emit()], ["설정", func() -> void: open_settings()], ["로비로 나가기", func() -> void: lobby.emit()]]
	for d in bs:
		var b := UI.button(d[0], Vector2(340, 50), d[0] == "계속하기")
		b.pressed.connect(d[1])
		v.add_child(b)

	var sc := PanelContainer.new()
	sc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.LINE, 16, 1, 24))
	sc.visible = false
	center.add_child(sc)
	settings_box = sc
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 14)
	sc.add_child(sv)
	sv.add_child(UI.label("설정", 32, UI.TEXT, "head"))
	var sp: HBoxContainer = SettingsPanel.new()
	sv.add_child(sp)
	sp.setup(main.profile.data.settings, main.profile.data.keys)
	sp.changed.connect(main.apply_settings)
	var back := UI.button("뒤로", Vector2(160, 44))
	back.pressed.connect(close_settings)
	sv.add_child(back)
	UI.fade_in(self, 0.15)


func open_settings() -> void:
	box.get_parent().visible = false
	settings_box.visible = true


func close_settings() -> void:
	settings_box.visible = false
	box.get_parent().visible = true
	main.save_now()


func in_settings() -> bool:
	return settings_box.visible
