extends Control
## 미니맵과 전체 지도(M). 지형은 조금씩 그려 넣고, 가 본 곳만 밝게 보인다(안개 지우기).

const PX := 160                  # 지도 이미지 한 변(픽셀)
const MPP := 28.0                # 1픽셀 = 28m → 한 변 4.48km
const FOG_CELL := 70.0
const ROWS_PER_FRAME := 2

var terrain: Node3D
var world: Dictionary
var profile: RefCounted
var kind := "city"
var img: Image
var tex: ImageTexture
var fog_img: Image
var fog_tex: ImageTexture
var origin := Vector2.ZERO       # 이미지 (0,0) 픽셀의 월드 좌표
var next_row := PX
var explored := {}
var drone_pos := Vector3.ZERO
var yaw := 0.0
var markers: Array = []          # {pos: Vector3, kind: String}
var full := false
var ready_ok := false
var font: Font
var fog_dirty := false


func setup(t: Node3D, w: Dictionary, p: RefCounted) -> void:
	terrain = t
	world = w
	profile = p
	kind = w.kind
	font = load("res://ui.gd").font("head")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	img = Image.create(PX, PX, false, Image.FORMAT_RGB8)
	img.fill(Color(0.05, 0.07, 0.1))
	tex = ImageTexture.create_from_image(img)
	fog_img = Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	fog_tex = ImageTexture.create_from_image(fog_img)
	var saved: Array = p.data.explored.get(w.id, [])
	for k in saved:
		explored[int(k)] = true
	ready_ok = true
	_recenter(Vector2(drone_pos.x, drone_pos.z), true)


func flush() -> void:
	profile.data.explored[world.id] = explored.keys()


func _key(cx: int, cz: int) -> int:
	return (cx + 4000) * 8192 + (cz + 4000)


func _recenter(c: Vector2, force := false) -> void:
	var snap := Vector2(roundf(c.x / 280.0) * 280.0, roundf(c.y / 280.0) * 280.0)
	var org := snap - Vector2(PX, PX) * 0.5 * MPP
	if not force and org.is_equal_approx(origin):
		return
	origin = org
	next_row = 0
	_rebuild_fog()


func _rebuild_fog() -> void:
	fog_img.fill(Color(0.02, 0.03, 0.06, 0.8))
	var clear := Color(0, 0, 0, 0)
	var n := int(ceil(FOG_CELL / MPP)) + 1
	for k in explored.keys():
		var cx: int = int(k) / 8192 - 4000
		var cz: int = int(k) % 8192 - 4000
		var x0 := int((float(cx) * FOG_CELL - origin.x) / MPP)
		var z0 := int((float(cz) * FOG_CELL - origin.y) / MPP)
		if x0 + n < 0 or z0 + n < 0 or x0 >= PX or z0 >= PX:
			continue
		fog_img.fill_rect(Rect2i(maxi(x0, 0), maxi(z0, 0), mini(x0 + n, PX) - maxi(x0, 0), mini(z0 + n, PX) - maxi(z0, 0)), clear)
	fog_tex.update(fog_img)

func _mark(wx: float, wz: float) -> void:
	var cx := floori(wx / FOG_CELL)
	var cz := floori(wz / FOG_CELL)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			if dx * dx + dz * dz > 5:
				continue
			var k := _key(cx + dx, cz + dz)
			if explored.has(k):
				continue
			explored[k] = true
			var x0 := int((float(cx + dx) * FOG_CELL - origin.x) / MPP)
			var z0 := int((float(cz + dz) * FOG_CELL - origin.y) / MPP)
			var n := int(ceil(FOG_CELL / MPP)) + 1
			for yy in range(maxi(z0, 0), mini(z0 + n, PX)):
				for xx in range(maxi(x0, 0), mini(x0 + n, PX)):
					fog_img.set_pixel(xx, yy, Color(0, 0, 0, 0))
			fog_dirty = true


func _color_at(wx: float, wz: float) -> Color:
	if kind == "city":
		var rx := absf(fposmod(wx + 80.0, 160.0) - 80.0)
		var rz := absf(fposmod(wz + 80.0, 160.0) - 80.0)
		var dm := minf(rx, rz)
		var dd := Vector2(wx, wz).distance_to(Vector2(900, -900))
		var tall := exp(-dd / 700.0)
		if dm < 15.0:
			return Color(0.5, 0.56, 0.68)
		return Color(0.1 + 0.16 * tall, 0.14 + 0.16 * tall, 0.2 + 0.2 * tall)
	var h: float = terrain.height(wx, wz)
	var hx: float = h - terrain.height(wx + MPP, wz)
	var shade := clampf(1.0 + hx * 0.01, 0.6, 1.4)
	var c: Color
	if h < 0.0:
		c = Color(0.1, 0.28, 0.5).lerp(Color(0.16, 0.4, 0.62), clampf(h / -20.0 + 0.0, 0.0, 1.0) * 0.0 + 0.3)
		return c
	match kind:
		"mars":
			c = Color(0.55, 0.28, 0.17).lerp(Color(0.85, 0.55, 0.35), clampf(h / 90.0, 0.0, 1.0))
		"farm":
			c = Color(0.34, 0.52, 0.2).lerp(Color(0.62, 0.58, 0.3), clampf(h / 50.0, 0.0, 1.0))
		_:
			if h < 6.0:
				c = Color(0.72, 0.68, 0.5)
			elif h < 90.0:
				c = Color(0.2, 0.42, 0.2).lerp(Color(0.38, 0.5, 0.26), clampf((h - 6.0) / 84.0, 0.0, 1.0))
			else:
				c = Color(0.45, 0.43, 0.42).lerp(Color(0.95, 0.96, 1.0), clampf((h - 90.0) / 140.0, 0.0, 1.0))
	return Color(c.r * shade, c.g * shade, c.b * shade)


func update_state(pos: Vector3, y: float, mk: Array) -> void:
	if not ready_ok:
		return
	drone_pos = pos
	yaw = y
	markers = mk
	var c := Vector2(pos.x, pos.z)
	var rel := c - (origin + Vector2(PX, PX) * 0.5 * MPP)
	if absf(rel.x) > 800.0 or absf(rel.y) > 800.0:
		_recenter(c)
	var rows := 0
	while next_row < PX and rows < ROWS_PER_FRAME:
		for x in PX:
			img.set_pixel(x, next_row, _color_at(origin.x + (x + 0.5) * MPP, origin.y + (next_row + 0.5) * MPP))
		next_row += 1
		rows += 1
		if next_row >= PX:
			tex.update(img)
	_mark(pos.x, pos.z)
	if fog_dirty and Engine.get_process_frames() % 6 == 0:
		fog_tex.update(fog_img)
		fog_dirty = false
	queue_redraw()


func _to_px(p: Vector3) -> Vector2:
	return Vector2((p.x - origin.x) / MPP, (p.z - origin.y) / MPP)


func _marker_col(k: String) -> Color:
	match k:
		"home": return Color(1.0, 0.7, 0.2)
		"mission": return Color(0.35, 0.92, 1.0)
		"secret": return Color(1.0, 0.85, 0.3)
		_: return Color.WHITE


func _draw() -> void:
	if not ready_ok:
		return
	var vs := get_viewport_rect().size
	if full:
		_draw_full(vs)
	else:
		_draw_mini(vs)


func _draw_mini(vs: Vector2) -> void:
	var size := 176.0
	var rect := Rect2(vs.x - size - 36.0, 128.0, size, size)
	var span := 64.0                                    # 보여 주는 픽셀 수(약 1.8km)
	var pc := _to_px(drone_pos)
	var src := Rect2(pc - Vector2(span, span) * 0.5, Vector2(span, span))
	src.position = Vector2(clampf(src.position.x, 0.0, PX - span), clampf(src.position.y, 0.0, PX - span))
	draw_rect(rect.grow(3.0), Color(0, 0, 0, 0.55))
	draw_texture_rect_region(tex, rect, src)
	draw_texture_rect_region(fog_tex, rect, src)
	draw_rect(rect, Color(1, 1, 1, 0.35), false, 1.5)
	var sc := size / span
	for m in markers:
		var mp: Vector2 = (_to_px(m.pos) - src.position) * sc
		var col := _marker_col(m.kind)
		var inside := rect.size.x > mp.x and mp.x > 0.0 and rect.size.y > mp.y and mp.y > 0.0
		mp = Vector2(clampf(mp.x, 6.0, size - 6.0), clampf(mp.y, 6.0, size - 6.0))
		var p := rect.position + mp
		if m.kind == "secret" and not inside:
			continue
		draw_circle(p, 5.0 if inside else 4.0, col)
		draw_arc(p, 6.5, 0, TAU, 14, Color(0, 0, 0, 0.7), 1.5)
	var pp := rect.position + (pc - src.position) * sc
	_arrow(pp, 8.0)
	draw_string(font, rect.position + Vector2(size * 0.5 - 5.0, 15.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.8))


func _arrow(p: Vector2, r: float) -> void:
	var d := Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([p + d * r * 1.3, p - d * r * 0.8 + side * r * 0.8, p - d * r * 0.35, p - d * r * 0.8 - side * r * 0.8]), Color(0.3, 1.0, 0.55))
	draw_polyline(PackedVector2Array([p + d * r * 1.3, p - d * r * 0.8 + side * r * 0.8, p - d * r * 0.35, p - d * r * 0.8 - side * r * 0.8, p + d * r * 1.3]), Color(0, 0, 0, 0.8), 1.5)


func _draw_full(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.01, 0.02, 0.04, 0.82))
	var s := minf(vs.y * 0.82, vs.x * 0.7)
	var rect := Rect2((vs - Vector2(s, s)) * 0.5, Vector2(s, s))
	draw_rect(rect.grow(6.0), Color(0.075, 0.1, 0.16))
	draw_texture_rect(tex, rect, false)
	draw_texture_rect(fog_tex, rect, false)
	draw_rect(rect, Color(1, 1, 1, 0.3), false, 2.0)
	var sc := s / PX
	var ids := PackedInt32Array()
	for m in markers:
		var p := rect.position + _to_px(m.pos) * sc
		if not rect.has_point(p):
			continue
		var col := _marker_col(m.kind)
		draw_circle(p, 7.0, col)
		draw_arc(p, 9.0, 0, TAU, 16, Color(0, 0, 0, 0.7), 2.0)
		if m.kind == "secret":
			draw_string(font, p + Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.2, 0.12, 0.0))
	var pp := rect.position + _to_px(drone_pos) * sc
	_arrow(pp, 12.0)
	draw_string(font, Vector2(rect.position.x, rect.position.y - 14.0), "지도 · %s" % String(world.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.93, 0.96, 1.0))
	var pct := _explored_pct()
	draw_string(font, Vector2(rect.end.x - 260.0, rect.position.y - 14.0), "탐험률 %d%%" % pct, HORIZONTAL_ALIGNMENT_RIGHT, 260, 22, Color(0.4, 1.0, 0.62))
	draw_string(font, Vector2(rect.position.x, rect.end.y + 30.0), "● 귀환점   ● 미션 목표   ● 숨겨진 상자(근처에서 표시)    [M] 닫기", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.75, 0.82, 0.92))


func _explored_pct() -> int:
	var tot := 0.0
	var n := 0
	for y in range(0, PX, 4):
		for x in range(0, PX, 4):
			tot += 1.0
			if fog_img.get_pixel(x, y).a < 0.5:
				n += 1
	return int(100.0 * n / maxf(tot, 1.0))
