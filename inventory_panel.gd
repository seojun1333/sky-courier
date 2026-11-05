extends VBoxContainer
## 보관함: 전투에서 모은 전리품을 보고 코인으로 판다. 로비 탭과 게임 중 팝업(I)에서 같이 쓴다.

signal changed
signal closed

const UI := preload("res://ui.gd")
const ItemsScript := preload("res://items.gd")

var main: Node
var modal := false
var list_box: VBoxContainer
var value_label: Label
var sell_all_btn: Button


func setup(m: Node, as_modal := false) -> void:
	main = m
	modal = as_modal
	theme = UI.theme()
	add_theme_constant_override("separation", 12)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	add_child(head)
	head.add_child(UI.label("보관함", 24, UI.ACCENT, "head"))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	value_label = UI.label("", 18, UI.AMBER)
	head.add_child(value_label)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	sc.add_child(list_box)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	add_child(foot)
	sell_all_btn = UI.button("", Vector2(300, 44), true)
	sell_all_btn.pressed.connect(func() -> void: _sell_everything())
	foot.add_child(sell_all_btn)
	if modal:
		var cb := UI.button("닫기  [I]", Vector2(150, 44))
		cb.pressed.connect(func() -> void: closed.emit())
		foot.add_child(cb)
	_rebuild()


func _inv() -> Dictionary:
	return main.save.inv


func _rebuild() -> void:
	for c in list_box.get_children():
		c.queue_free()
	var inv := _inv()
	var ids: Array = inv.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(ItemsScript.info(a).price) > int(ItemsScript.info(b).price))
	var total := 0
	for id in ids:
		if int(inv[id]) > 0:
			list_box.add_child(_row(String(id)))
			total += int(inv[id]) * int(ItemsScript.info(id).price)
	if total == 0:
		var l := UI.label("보관함이 비었습니다.\n드론 대전이나 괴물 사냥에서 적을 쓰러뜨리면 전리품이 떨어집니다.", 18, UI.DIM)
		list_box.add_child(l)
	value_label.text = "전리품 가치  ● %d" % total
	sell_all_btn.text = "전부 판매  ● %d" % total
	sell_all_btn.disabled = total == 0


func _row(id: String) -> Control:
	var inf: Dictionary = ItemsScript.info(id)
	var n: int = int(_inv()[id])
	var price: int = int(inf.price)
	var tier: int = int(inf.tier)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.PANEL, ItemsScript.TIER_COLORS[tier] * Color(1, 1, 1, 0.35), 12, 1, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	var sw := ColorRect.new()
	sw.color = inf.color
	sw.custom_minimum_size = Vector2(12, 44)
	h.add_child(sw)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)
	var nm := UI.label("%s   [%s]" % [inf.name, ItemsScript.TIER_NAMES[tier]], 19, ItemsScript.TIER_COLORS[tier])
	v.add_child(nm)
	v.add_child(UI.label(inf.desc, 13, UI.DIM))
	var cnt := UI.label("×%d" % n, 22, UI.TEXT, "head")
	cnt.custom_minimum_size = Vector2(60, 0)
	h.add_child(cnt)
	var pr := UI.label("● %d" % price, 18, UI.AMBER, "head")
	pr.custom_minimum_size = Vector2(80, 0)
	h.add_child(pr)
	var b1 := UI.button("1개 판매", Vector2(110, 38))
	b1.pressed.connect(func() -> void: _sell(id, 1))
	h.add_child(b1)
	var b2 := UI.button("전부  ● %d" % (price * n), Vector2(140, 38))
	b2.pressed.connect(func() -> void: _sell(id, n))
	h.add_child(b2)
	return p


func _sell(id: String, n: int) -> void:
	var inv := _inv()
	var have: int = int(inv.get(id, 0))
	n = mini(n, have)
	if n <= 0:
		return
	var gain: int = n * int(ItemsScript.info(id).price)
	inv[id] = have - n
	if int(inv[id]) <= 0:
		inv.erase(id)
	main.save.coins += gain
	main.save.total += gain
	main.profile.add_stat("sold_coins", float(gain))
	main.profile.add_stat("sold_items", float(n))
	UI.sfx.confirm()
	_rebuild()
	changed.emit()


func _sell_everything() -> void:
	var inv := _inv()
	var gain := 0
	var cnt := 0
	for id in inv.keys():
		var n: int = int(inv[id])
		gain += n * int(ItemsScript.info(id).price)
		cnt += n
	if gain <= 0:
		return
	inv.clear()
	main.save.coins += gain
	main.save.total += gain
	main.profile.add_stat("sold_coins", float(gain))
	main.profile.add_stat("sold_items", float(cnt))
	UI.sfx.jingle()
	_rebuild()
	changed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if modal and event is InputEventKey and event.pressed and not event.echo:
		if event.is_action("inventory") or event.keycode == KEY_ESCAPE:
			closed.emit()
			get_viewport().set_input_as_handled()
