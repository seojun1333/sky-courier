extends Control
## 로비: 출격(맵 선택) · 목표 · 격납고(기체·외장) · 업그레이드 · 설정.

signal picked(id: String)
signal to_title

const UI := preload("res://ui.gd")
const WorldsScript := preload("res://worlds.gd")
const SettingsPanel := preload("res://settings_panel.gd")
const StoryScript := preload("res://story.gd")
const GoalsScript := preload("res://goals.gd")

var main: Node
var profile: RefCounted
var worlds: Array = []
var tab := 0
var content: Control
var coin_label: Label
var rank_label: Label
var xp_bar: ProgressBar
var tab_buttons: Array[Button] = []
var shop_rows: Array = []
var tab_names := ["출격", "목표", "격납고", "보관함", "업그레이드", "설정"]
var pv_root: Node3D
var pv_model: Node3D
var pv_fid := ""
var pv_sid := ""
const DroneScript := preload("res://drone.gd")
const DroneModel := preload("res://dronemodel.gd")
const InventoryScript := preload("res://inventory_panel.gd")
const MODES := [
	{"id": "free", "name": "자유 비행", "desc": "배송 의뢰와 탐험. 코인을 모아 기체를 키운다."},
	{"id": "duel", "name": "드론 대전", "desc": "적 드론이 웨이브로 몰려온다. 기관포와 유도탄(록온)으로 격추하고, 하늘의 탄창을 주워 싸운다."},
	{"id": "hunt", "name": "괴물 사냥", "desc": "슬라임부터 공허의 눈까지, 괴물마다 난이도와 드랍이 다르다. 전리품은 보관함에서 판다."},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	profile = main.profile
	worlds = WorldsScript.all()
	_build()
	get_viewport().size_changed.connect(_build)


func _build() -> void:
	for c in get_children():
		c.queue_free()
	tab_buttons.clear()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	# 상단 바
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	col.add_child(top)
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", -4)
	logo.add_child(UI.label(StoryScript.TITLE, 30, UI.TEXT, "head"))
	logo.add_child(UI.label(StoryScript.TITLE_KO, 14, UI.DIM))
	top.add_child(logo)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(tabs)
	for i in tab_names.size():
		var label: String = tab_names[i]
		if i == 1 and GoalsScript.ready_count(profile) > 0:
			label += "  ●%d" % GoalsScript.ready_count(profile)
		var b := UI.button(label, Vector2(150, 42))
		b.toggle_mode = true
		b.pressed.connect(_set_tab.bind(i))
		tabs.add_child(b)
		tab_buttons.append(b)
	var pilot := VBoxContainer.new()
	pilot.add_theme_constant_override("separation", 3)
	top.add_child(pilot)
	rank_label = UI.label("", 17, UI.TEXT, "head")
	pilot.add_child(rank_label)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(210, 8)
	xp_bar.show_percentage = false
	xp_bar.add_theme_stylebox_override("background", UI.box(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 4, 0, 0))
	xp_bar.add_theme_stylebox_override("fill", UI.box(UI.ACCENT, Color(0, 0, 0, 0), 4, 0, 0))
	pilot.add_child(xp_bar)
	coin_label = UI.label("", 24, UI.AMBER, "head")
	pilot.add_child(coin_label)

	content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.clip_contents = true
	col.add_child(content)

	var bottom := HBoxContainer.new()
	col.add_child(bottom)
	var tb := UI.button("타이틀로", Vector2(130, 36))
	tb.pressed.connect(func() -> void: to_title.emit())
	bottom.add_child(tb)
	var hint := UI.label("   %s  ·  조종사 %s  ·  플레이 %s" % [StoryScript.TAGLINE, profile.data.name, _hms(profile.data.playtime)], 14, UI.DIM)
	bottom.add_child(hint)
	_set_tab(tab)


func _hms(sec: float) -> String:
	return "%d시간 %02d분" % [int(sec) / 3600, (int(sec) % 3600) / 60]


func _set_tab(i: int) -> void:
	tab = i
	for j in tab_buttons.size():
		tab_buttons[j].set_pressed_no_signal(j == i)
	for c in content.get_children():
		c.queue_free()
	match i:
		0: _build_maps()
		1: _build_goals()
		2: _build_hangar()
		3: _build_inventory()
		4: _build_shop()
		5: _build_settings()
	for c in content.get_children():
		UI.fade_in(c, 0.22)
	_refresh_top()


func _refresh_top() -> void:
	if coin_label == null:
		return
	coin_label.text = "● %d" % profile.data.coins
	rank_label.text = "RANK %d  %s" % [profile.rank(), profile.rank_name()]
	xp_bar.value = profile.rank_progress() * 100.0


# ---------------- 출격 ----------------
func _thumb(id: String) -> Texture2D:
	var path := "res://shots/%s.png" % id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _build_maps() -> void:
	var vs := get_viewport_rect().size
	var gap := 20.0
	var w := clampf((vs.x - 96.0 - gap * 3.0) / 4.0, 230.0, 420.0)
	var root_v := VBoxContainer.new()
	root_v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_v.add_theme_constant_override("separation", 10)
	content.add_child(root_v)
	# 모드 선택
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 10)
	root_v.add_child(mrow)
	mrow.add_child(UI.label("모드", 16, UI.DIM, "head"))
	var cur: String = main.game_mode
	for md in MODES:
		var b := UI.button(String(md.name), Vector2(150, 40), cur == md.id)
		b.toggle_mode = true
		b.set_pressed_no_signal(cur == md.id)
		var mid: String = md.id
		b.pressed.connect(func() -> void:
			main.game_mode = mid
			profile.data.last_mode = mid
			_set_tab(0))
		mrow.add_child(b)
	var md_desc := ""
	for md in MODES:
		if md.id == cur:
			md_desc = md.desc
	var dl := UI.label(md_desc, 15, UI.ACCENT)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(dl)
	var cc := CenterContainer.new()
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(cc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(gap))
	cc.add_child(row)
	for i in worlds.size():
		row.add_child(_map_card(i, worlds[i], w))


func _build_inventory() -> void:
	var p: VBoxContainer = InventoryScript.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(p)
	p.setup(main, false)
	p.changed.connect(_refresh_top)

func _map_card(i: int, wd: Dictionary, w: float) -> Control:
	var ok: bool = profile.map_unlocked(wd.id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(w, 0)
	var sb := UI.box(UI.PANEL, UI.LINE, 14, 1, 10)
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_entered.connect(func() -> void:
		sb.border_color = UI.ACCENT
		UI.hover())
	card.mouse_exited.connect(func() -> void: sb.border_color = UI.LINE)
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if ok:
				UI.click()
				picked.emit(wd.id)
			else:
				UI.sfx.error())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(v)
	var img := TextureRect.new()
	img.custom_minimum_size = Vector2(w - 20.0, (w - 20.0) * 9.0 / 16.0)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_PASS
	img.texture = _thumb(wd.id)
	if not ok:
		img.modulate = Color(0.35, 0.38, 0.45)
	v.add_child(img)
	var nm := UI.label("%s" % wd.name, 24, UI.TEXT if ok else UI.DIM)
	nm.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(nm)
	var tg := UI.label(StoryScript.MAP_TAGLINE.get(wd.id, ""), 15, UI.ACCENT if ok else UI.DIM)
	tg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tg.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(tg)
	var ds := UI.label(wd.desc, 14, UI.DIM)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(w - 20.0, 62)
	ds.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(ds)
	var found: int = (profile.data.secrets.get(wd.id, []) as Array).size()
	var stars := 0
	for t in ["ring", "delivery", "photo", "landing"]:
		stars += int(profile.data.stars.get("%s_%s" % [wd.id, t], 0))
	var itxt := ("상자 %d/10   별 %d/12" % [found, stars]) if ok else "랭크 %d 필요" % int(profile.MAP_RANK[wd.id])
	var info := UI.label(itxt, 14, UI.AMBER if ok else UI.BAD)
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(info)
	var go := UI.button(("[%d]  출격" % (i + 1)) if ok else "잠김", Vector2(0, 40), ok)
	go.disabled = not ok
	go.pressed.connect(func() -> void: picked.emit(wd.id))
	v.add_child(go)
	return card


# ---------------- 목표 ----------------
func _build_goals() -> void:
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(grid)
	var list: Array = GoalsScript.LIST.duplicate()
	list.sort_custom(func(a, b) -> bool:
		var ra: int = 0 if GoalsScript.ready(profile, a) else (2 if profile.data.goals.get(a.id, false) else 1)
		var rb: int = 0 if GoalsScript.ready(profile, b) else (2 if profile.data.goals.get(b.id, false) else 1)
		return ra < rb)
	for g in list:
		var done: bool = profile.data.goals.get(g.id, false)
		var ready: bool = GoalsScript.ready(profile, g)
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.GOOD if ready else UI.LINE, 12, 1, 12))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		p.add_child(h)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 3)
		h.add_child(info)
		info.add_child(UI.label(("✔ " if done else "") + g.name, 20, UI.GOOD if done else UI.TEXT))
		info.add_child(UI.label(g.desc, 14, UI.DIM))
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(0, 7)
		pb.show_percentage = false
		pb.max_value = g.target
		pb.value = GoalsScript.progress(profile, g)
		pb.add_theme_stylebox_override("background", UI.box(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 4, 0, 0))
		pb.add_theme_stylebox_override("fill", UI.box(UI.GOOD if (ready or done) else UI.ACCENT, Color(0, 0, 0, 0), 4, 0, 0))
		info.add_child(pb)
		var btxt := "완료"
		if not done:
			btxt = ("보상 받기  ●%d  +%dXP" if ready else "● %d  +%dXP") % [g.coins, g.xp]
		var b := UI.button(btxt, Vector2(170, 42), ready)
		b.disabled = not ready
		b.pressed.connect(func() -> void:
			main.claim_goal(g.id)
			_set_tab(1))
		h.add_child(b)
		grid.add_child(p)


# ---------------- 격납고 ----------------
func _build_hangar() -> void:
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 18)
	content.add_child(hb)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	sc.add_child(v)
	v.add_child(UI.label("기체", 24, UI.ACCENT, "head"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for id in StoryScript.FRAMES:
		row.add_child(_frame_card(id))
	v.add_child(UI.label("외장", 24, UI.ACCENT, "head"))
	var srow := GridContainer.new()
	srow.columns = 5
	srow.add_theme_constant_override("h_separation", 10)
	srow.add_theme_constant_override("v_separation", 10)
	v.add_child(srow)
	for id in StoryScript.SKINS:
		srow.add_child(_skin_card(id))
	hb.add_child(_make_preview())
	_preview(profile.data.frames.equipped, profile.data.skins.equipped)


## 격납고 3D 미리보기: 기체·외장·업그레이드가 반영된 모양을 돌려 보여 준다
func _make_preview() -> Control:
	pv_fid = ""
	pv_sid = ""
	pv_model = null
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.07, 0.11), UI.LINE, 14, 1, 6))
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.custom_minimum_size = Vector2(380, 380)
	vb.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.handle_input_locally = false
	svc.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.08, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.75)
	env.ambient_light_energy = 0.8
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 35, 0)
	sun.light_energy = 1.5
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 200, 0)
	rim.light_energy = 0.8
	rim.light_color = Color(0.5, 0.7, 1.0)
	vp.add_child(rim)
	pv_root = Node3D.new()
	vp.add_child(pv_root)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.28, 1.15)
	cam.rotation_degrees = Vector3(-12, 0, 0)
	cam.fov = 36.0
	vp.add_child(cam)
	return panel


func _preview(fid: String, sid: String) -> void:
	if pv_root == null or not is_instance_valid(pv_root):
		return
	if fid == pv_fid and sid == pv_sid:
		return
	pv_fid = fid
	pv_sid = sid
	var rot := 0.0
	if pv_model != null and is_instance_valid(pv_model):
		rot = pv_model.rotation.y
		pv_model.queue_free()
	var lv: Dictionary = profile.data.levels
	var led: Color = DroneScript.LED_COLORS[clampi(int(lv.color), 0, DroneScript.LED_COLORS.size() - 1)]
	var m: Dictionary = DroneModel.build(fid, StoryScript.SKINS[sid], lv, led)
	pv_model = Node3D.new()
	pv_model.scale = Vector3.ONE * 1.25
	pv_model.rotation.y = rot
	pv_model.rotation.x = deg_to_rad(10)
	pv_model.add_child(m.root)
	pv_root.add_child(pv_model)


func _process(dt: float) -> void:
	if pv_model != null and is_instance_valid(pv_model):
		pv_model.rotation.y += dt * 0.7

func _bar(name: String, val: float, mx: float) -> Control:
	var h := HBoxContainer.new()
	var l := UI.label(name, 14, UI.DIM)
	l.custom_minimum_size = Vector2(64, 0)
	h.add_child(l)
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(110, 7)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.show_percentage = false
	pb.max_value = mx
	pb.value = val
	pb.add_theme_stylebox_override("background", UI.box(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 4, 0, 0))
	pb.add_theme_stylebox_override("fill", UI.box(UI.ACCENT, Color(0, 0, 0, 0), 4, 0, 0))
	h.add_child(pb)
	return h


func _frame_card(id: String) -> Control:
	var f: Dictionary = StoryScript.FRAMES[id]
	var owned: bool = (profile.data.frames.owned as Array).has(id)
	var eq: bool = profile.data.frames.equipped == id
	var unlocked: bool = profile.frame_unlocked(id)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(250, 0)
	p.add_theme_stylebox_override("panel", UI.box(UI.PANEL2 if eq else UI.PANEL, UI.ACCENT if eq else UI.LINE, 14, 1, 14))
	p.mouse_entered.connect(func() -> void: _preview(id, profile.data.skins.equipped))
	p.mouse_exited.connect(func() -> void: _preview(profile.data.frames.equipped, profile.data.skins.equipped))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	p.add_child(v)
	v.add_child(UI.label(f.name, 22, UI.TEXT if unlocked else UI.DIM))
	var ds := UI.label(f.desc, 14, UI.DIM)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(225, 60)
	v.add_child(ds)
	v.add_child(_bar("속도", float(f.speed), 1.4))
	v.add_child(_bar("배터리", float(f.battery), 1.5))
	v.add_child(_bar("안정성", 1.0 + float(f.gimbal), 4.0))
	v.add_child(_bar("망원", 1.0 + float(f.zoom), 3.0))
	var text := "장착 중"
	if not eq:
		if owned:
			text = "장착"
		elif unlocked:
			text = "● %d  구매" % int(f.cost)
		else:
			text = "랭크 %d 필요" % int(profile.FRAME_RANK[id])
	var b := UI.button(text, Vector2(0, 40), (not eq) and (owned or unlocked))
	b.disabled = eq or ((not owned) and ((not unlocked) or profile.data.coins < int(f.cost)))
	b.pressed.connect(func() -> void:
		if owned:
			main.equip_frame(id)
		else:
			main.buy_frame(id)
		_set_tab(2))
	v.add_child(b)
	return p


func _skin_card(id: String) -> Control:
	var s: Dictionary = StoryScript.SKINS[id]
	var owned: bool = (profile.data.skins.owned as Array).has(id)
	var eq: bool = profile.data.skins.equipped == id
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.PANEL2 if eq else UI.PANEL, UI.ACCENT if eq else UI.LINE, 12, 1, 10))
	p.mouse_entered.connect(func() -> void: _preview(profile.data.frames.equipped, id))
	p.mouse_exited.connect(func() -> void: _preview(profile.data.frames.equipped, profile.data.skins.equipped))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var sw := ColorRect.new()
	sw.color = s.color
	sw.custom_minimum_size = Vector2(110, 30)
	v.add_child(sw)
	v.add_child(UI.label(s.name, 15, UI.TEXT))
	var btxt := "장착 중" if eq else ("장착" if owned else "● %d" % int(s.cost))
	var b := UI.button(btxt, Vector2(0, 34))
	b.disabled = eq or ((not owned) and profile.data.coins < int(s.cost))
	b.pressed.connect(func() -> void:
		if owned:
			main.equip_skin(id)
		else:
			main.buy_skin(id)
		_set_tab(2))
	v.add_child(b)
	return p


# ---------------- 업그레이드 ----------------
func _build_shop() -> void:
	shop_rows.clear()
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	var items: Array = main.UPGRADES
	for i in items.size():
		var it: Dictionary = items[i]
		var names: Array = StoryScript.UPGRADE_NAMES[it.id]
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.LINE, 12, 1, 9))
		v.add_child(panel)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 20)
		panel.add_child(h)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 1)
		h.add_child(info)
		info.add_child(UI.label(names[0], 20, UI.TEXT))
		info.add_child(UI.label(names[1], 14, UI.DIM))
		var pips := UI.label("", 22, UI.ACCENT)
		pips.custom_minimum_size = Vector2(170, 0)
		h.add_child(pips)
		var btn := UI.button("", Vector2(190, 38))
		btn.pressed.connect(_on_buy.bind(i))
		h.add_child(btn)
		shop_rows.append({"pips": pips, "btn": btn})
	_refresh_shop()


func _refresh_shop() -> void:
	var items: Array = main.UPGRADES
	for i in items.size():
		var it: Dictionary = items[i]
		var lvl: int = profile.data.levels[it.id]
		var r: Dictionary = shop_rows[i]
		r.pips.text = "●".repeat(lvl) + "○".repeat(it.max - lvl)
		var btn: Button = r.btn
		if lvl >= it.max:
			btn.text = "최대 단계"
			btn.disabled = true
		else:
			var cost: int = main.cost_of(i)
			btn.text = "● %d  구매" % cost
			btn.disabled = profile.data.coins < cost
	_refresh_top()


func _on_buy(i: int) -> void:
	if main.buy(i):
		UI.sfx.confirm()
	else:
		UI.sfx.error()
	_refresh_shop()


# ---------------- 설정 ----------------
func _build_settings() -> void:
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(sc)
	var sp: HBoxContainer = SettingsPanel.new()
	sc.add_child(sp)
	sp.setup(profile.data.settings, profile.data.keys)
	sp.changed.connect(main.apply_settings)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and tab == 0:
		var n: int = event.keycode - KEY_1
		if n >= 0 and n < worlds.size() and profile.map_unlocked(worlds[n].id):
			picked.emit(worlds[n].id)
