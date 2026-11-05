extends Control
## 타이틀 화면: 실제 플레이 장면이 천천히 흐르는 배경, 로고, 저장 슬롯 3개.

signal slot_chosen(slot: int)

const UI := preload("res://ui.gd")
const StoryScript := preload("res://story.gd")
const ProfileScript := preload("res://profile.gd")
const IDS := ["city", "alpine", "farm", "mars"]

var bg: Array[TextureRect] = []
var which := 0
var t := 0.0
var idx := 0
var confirm_del := -1
var slots_box: HBoxContainer
var logo: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	clip_contents = true
	var base := ColorRect.new()
	base.color = UI.BG
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	for i in 2:
		var tr := TextureRect.new()
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.modulate.a = 0.0
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		bg.append(tr)
	_show_bg(0)
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.gradient = Gradient.new()
	gt.gradient.colors = PackedColorArray([Color(0.02, 0.03, 0.06, 0.25), Color(0.02, 0.03, 0.06, 0.55), Color(0.02, 0.03, 0.06, 0.96)])
	gt.gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	logo = VBoxContainer.new()
	logo.add_theme_constant_override("separation", -6)
	col.add_child(logo)
	var ko := UI.label(StoryScript.TITLE_KO, 118, Color.WHITE, "title")
	ko.add_theme_constant_override("outline_size", 10)
	ko.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.1, 0.9))
	logo.add_child(ko)
	var en := UI.label("S K Y   C O U R I E R", 34, UI.ACCENT, "head")
	logo.add_child(en)
	col.add_child(UI.label(StoryScript.TAGLINE, 22, UI.TEXT))

	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(sp)
	col.add_child(UI.label("저장 슬롯을 고르세요", 18, UI.DIM))
	slots_box = HBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 18)
	col.add_child(slots_box)
	_build_slots()
	col.add_child(UI.label("에셋: Quaternius(CC0) 캐릭터·애니메이션 · 글꼴: Rajdhani, Black Han Sans (OFL) · 음악·효과음은 게임 안에서 합성", 12, Color(1, 1, 1, 0.35)))
	UI.fade_in(margin, 0.8)
	# 로고가 숨 쉬듯 살짝 떠 있게
	var tw := logo.create_tween().set_loops()
	tw.tween_property(logo, "position:y", logo.position.y - 5.0, 2.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "position:y", logo.position.y + 5.0, 2.4).set_trans(Tween.TRANS_SINE)


func _show_bg(i: int) -> void:
	var id: String = IDS[i % IDS.size()]
	var path := "res://shots/%s.png" % id
	if not ResourceLoader.exists(path):
		return
	var n := bg[which]
	n.texture = load(path) as Texture2D
	n.pivot_offset = size * 0.5
	n.scale = Vector2(1.0, 1.0)
	n.modulate.a = 0.0
	var other := bg[1 - which]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(n, "modulate:a", 1.0, 1.6)
	tw.tween_property(other, "modulate:a", 0.0, 1.6)
	tw.tween_property(n, "scale", Vector2(1.09, 1.09), 9.0)
	which = 1 - which


func _process(dt: float) -> void:
	t += dt
	if t > 7.5:
		t = 0.0
		idx += 1
		_show_bg(idx)


func _build_slots() -> void:
	for c in slots_box.get_children():
		c.queue_free()
	for s in range(1, ProfileScript.SLOTS + 1):
		slots_box.add_child(_slot_card(s))


func _slot_card(s: int) -> Control:
	var info: Dictionary = ProfileScript.info(s)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(330, 0)
	p.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.08, 0.13, 0.86), UI.LINE, 14, 1, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UI.label("SLOT %d" % s, 15, UI.ACCENT, "head"))
	if info.is_empty():
		v.add_child(UI.label("새 게임", 24, UI.TEXT))
		v.add_child(UI.label("관제 노을이 첫 하늘길을 열어 둡니다.", 14, UI.DIM))
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, 22)
		v.add_child(sp)
		var b := UI.button("시작하기", Vector2(0, 42), true)
		b.pressed.connect(func() -> void: slot_chosen.emit(s))
		v.add_child(b)
	else:
		var xp: int = info.xp
		var r := 1
		for i in ProfileScript.XP_TABLE.size():
			if xp >= ProfileScript.XP_TABLE[i]:
				r = i + 1
		v.add_child(UI.label("RANK %d  %s" % [r, ProfileScript.RANK_NAMES[r - 1]], 22, UI.TEXT, "head"))
		v.add_child(UI.label("코인 %d  ·  미션 %d회" % [info.coins, info.missions], 14, UI.AMBER))
		v.add_child(UI.label("플레이 %d시간 %02d분" % [int(info.playtime) / 3600, (int(info.playtime) % 3600) / 60], 14, UI.DIM))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		v.add_child(h)
		var b2 := UI.button("이어하기", Vector2(0, 42), true)
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.pressed.connect(func() -> void: slot_chosen.emit(s))
		h.add_child(b2)
		var d := UI.button("삭제" if confirm_del != s else "정말?", Vector2(70, 42))
		d.pressed.connect(func() -> void:
			if confirm_del == s:
				ProfileScript.new().erase_slot(s)
				confirm_del = -1
			else:
				confirm_del = s
			_build_slots())
		h.add_child(d)
	return p
