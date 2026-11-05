extends RefCounted
## 공통 UI: 색, 글꼴, 테마, 버튼·카드 만들기, 호버 연출.

const BG := Color(0.035, 0.05, 0.085)
const PANEL := Color(0.075, 0.10, 0.16)
const PANEL2 := Color(0.10, 0.135, 0.21)
const LINE := Color(1, 1, 1, 0.09)
const ACCENT := Color(0.23, 0.86, 1.0)
const AMBER := Color(1.0, 0.72, 0.28)
const GOOD := Color(0.4, 1.0, 0.62)
const BAD := Color(1.0, 0.38, 0.45)
const TEXT := Color(0.93, 0.96, 1.0)
const DIM := Color(0.62, 0.7, 0.82)

static var sfx: Node = null              # ui_audio.gd 인스턴스(main이 채운다)
static var _fonts := {}
static var _theme: Theme = null


static func _file_font(path: String) -> FontFile:
	return load(path).duplicate() as FontFile


static func _malgun(bold := false) -> SystemFont:
	var s := SystemFont.new()
	s.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR"])
	s.font_weight = 700 if bold else 400
	return s


## kind: body | head | title | mono
static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font
	match kind:
		"head":
			var h := _file_font("res://fonts/Rajdhani-Bold.ttf")
			h.fallbacks = [_malgun(true)]
			f = h
		"mono":
			var m := _file_font("res://fonts/Rajdhani-Medium.ttf")
			m.fallbacks = [_malgun()]
			f = m
		"title":
			f = _file_font("res://fonts/BlackHanSans-Regular.ttf")
		_:
			f = _malgun()
	_fonts[kind] = f
	return f


static func box(bg: Color, border := Color(0, 0, 0, 0), radius := 10, bw := 0, margin := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	for cls in ["Button", "CheckButton"]:
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, ACCENT)
		t.set_color("font_disabled_color", cls, Color(1, 1, 1, 0.32))
		t.set_color("font_focus_color", cls, TEXT)
	t.set_stylebox("normal", "Button", box(PANEL2, LINE, 9, 1, 10))
	t.set_stylebox("hover", "Button", box(Color(0.14, 0.2, 0.31), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.7), 9, 1, 10))
	t.set_stylebox("pressed", "Button", box(Color(0.08, 0.2, 0.28), ACCENT, 9, 1, 10))
	t.set_stylebox("disabled", "Button", box(Color(0.07, 0.09, 0.13), Color(1, 1, 1, 0.05), 9, 1, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 12, 1, 14))
	# 슬라이더
	var track := box(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 4, 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, Color(0, 0, 0, 0), 4, 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT.lightened(0.2), Color(0, 0, 0, 0), 4, 0, 0))
	var gr := GradientTexture2D.new()
	gr.width = 18
	gr.height = 18
	gr.fill = GradientTexture2D.FILL_RADIAL
	gr.fill_from = Vector2(0.5, 0.5)
	gr.fill_to = Vector2(1.0, 0.5)
	gr.gradient = Gradient.new()
	gr.gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	gr.gradient.offsets = PackedFloat32Array([0.0, 0.8, 1.0])
	t.set_icon("grabber", "HSlider", gr)
	t.set_icon("grabber_highlight", "HSlider", gr)
	t.set_icon("grabber_disabled", "HSlider", gr)
	_theme = t
	return t


# --- 소리 연동 ---
static func click() -> void:
	if sfx != null:
		sfx.click()


static func hover() -> void:
	if sfx != null:
		sfx.hover()


# --- 위젯 ---
## 호버 때 살짝 커지고 소리가 나는 버튼
static func button(text: String, min_size := Vector2(0, 44), accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	if accent:
		b.add_theme_stylebox_override("normal", box(Color(0.1, 0.42, 0.55), ACCENT, 9, 1, 10))
		b.add_theme_stylebox_override("hover", box(Color(0.14, 0.55, 0.7), Color.WHITE, 9, 1, 10))
		b.add_theme_stylebox_override("pressed", box(Color(0.08, 0.34, 0.45), ACCENT, 9, 1, 10))
		b.add_theme_font_override("font", font("head"))
		b.add_theme_font_size_override("font_size", 22)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			hover()
			pop(b, 1.04))
	b.mouse_exited.connect(func() -> void: pop(b, 1.0))
	b.pressed.connect(click)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	return b


static func pop(c: Control, s: float) -> void:
	if not c.is_inside_tree():
		return
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(s, s), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func label(text: String, size := 18, color := TEXT, kind := "body") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if kind != "body":
		l.add_theme_font_override("font", font(kind))
	return l


static func fade_in(c: Control, t := 0.25) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, t)
