extends RefCounted
## 도시: 블록 단위(160m)로 건물, 가로등, 가로수를 만들고 들어갈 수 있는 폐건물을 배치한다.
## 도로·인도·공원은 지면 셰이더가 그린다(청크 정점 색으로 블록 종류를 전달).

const MB := preload("res://mb.gd")
const CELL := 160.0
const RH := 11.0
const DOWN := Vector2(900, -900)       # 도심 중심

var terrain: Node3D
var buildings: Node3D
var mat: ShaderMaterial
var lamp_mesh: ArrayMesh
var lamp_head: StandardMaterial3D
var tree_mesh: ArrayMesh


func _init() -> void:
	mat = ShaderMaterial.new()
	mat.shader = load("res://city_building.gdshader")
	mat.set_shader_parameter("night", 0.7)
	_make_lamp()
	_make_tree()


func _rng(c: Vector2i, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector2i(c.x * 9973 + salt * 31, c.y * 60013 + salt * 7))
	return r


func _dist(c: Vector2i) -> float:
	return Vector2((c.x + 0.5) * CELL, (c.y + 0.5) * CELL).distance_to(DOWN)


## 0 건물 블록, 1 공원, 2 들판, 3 주차장
func _btype(c: Vector2i) -> int:
	if c == Vector2i(0, 0):
		return 1
	if c == Vector2i(1, 0) or c == Vector2i(0, 1) or c == Vector2i(-1, 0):
		return 0
	var d := _dist(c)
	var r := _rng(c, 1).randf()
	if d > 2300.0 and r < 0.75:
		return 2
	if r < 0.06:
		return 1
	if d > 500.0 and r > 0.94:
		return 3
	return 0


func block_info(c: Vector2i) -> Color:
	return Color(_btype(c) / 10.0, 0, 0, 1)


func on_free(c: Vector2i) -> void:
	if buildings != null:
		buildings.remove_solid(c)
		buildings.remove_enterable(c)


# ---------- 블록 ----------
func decorate(c: Vector2i, ring: int) -> Node3D:
	var btype := _btype(c)
	var node := Node3D.new()
	node.position = Vector3(c.x * CELL, 0, c.y * CELL)
	var ox := c.x * CELL
	var oz := c.y * CELL
	var rs := _rng(c, 2)
	var d := _dist(c)
	var mb := MB.new()
	var solids: Array = []
	if btype == 0:
		_fill_block(c, mb, solids, node, rs, d, ox, oz)
	if not mb.is_empty():
		var mi := MeshInstance3D.new()
		mi.mesh = mb.build()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ring <= 3 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	if not solids.is_empty() and buildings != null:
		buildings.add_solid(c, solids)
	if ring <= 5:
		_lamps(node, rs)
	if ring <= 4 or btype == 1:
		_trees(node, c, btype, rs, d)
	return node


func _B(mb: Object, solids: Array, ox: float, oz: float, mn: Vector3, mx: Vector3, col: Color) -> void:
	mb.box(mn, mx, col)
	solids.append({"min": Vector3(mn.x + ox, mn.y, mn.z + oz), "max": Vector3(mx.x + ox, mx.y, mx.z + oz)})


func _fill_block(c: Vector2i, mb: Object, solids: Array, node: Node3D, rs: RandomNumberGenerator, d: float, ox: float, oz: float) -> void:
	var forced := ""
	if c == Vector2i(1, 0):
		forced = "apartment"
	elif c == Vector2i(0, 1):
		forced = "motel"
	elif c == Vector2i(-1, 0):
		forced = "shop"
	if forced != "":
		_enter(forced, c, node, rs, ox, oz, Vector2(80, 80))
		return
	var zone := 0 if d < 450.0 else (1 if d < 900.0 else 2)
	var X0 := 15.0
	var S := 130.0
	var lots: Array = []
	var r := rs.randf()
	if zone == 0:
		if r < 0.4:
			lots = [Rect2(X0, X0, S, S)]
		elif r < 0.75:
			lots = _split2(rs, X0, S)
		else:
			lots = _split4(X0, S)
	elif zone == 1:
		lots = _split2(rs, X0, S) if r < 0.4 else _split4(X0, S)
	else:
		if r < 0.45:
			for j in 3:
				for i in 3:
					lots.append(Rect2(X0 + i * S / 3.0, X0 + j * S / 3.0, S / 3.0 - 2.0, S / 3.0 - 2.0))
		elif r < 0.78:
			lots = _split4(X0, S)
		else:
			lots = _split2(rs, X0, S)
	var enterable_done := false
	for lot in lots:
		var kind := _pick(zone, lot, rs)
		if zone > 0 and not enterable_done and lot.size.x >= 55.0 and rs.randf() < 0.1:
			enterable_done = true
			_enter(["apartment", "motel", "shop"][rs.randi_range(0, 2)], c, node, rs, ox, oz, lot.get_center())
			continue
		match kind:
			"tower": _tower(mb, solids, ox, oz, lot, rs, zone)
			"office": _office(mb, solids, ox, oz, lot, rs)
			"apartment": _apartment(mb, solids, ox, oz, lot, rs, zone)
			"shop": _shop(mb, solids, ox, oz, lot, rs)
			"motel": _motel(mb, solids, ox, oz, lot, rs)
			"warehouse": _warehouse(mb, solids, ox, oz, lot, rs)
			_: _house(mb, solids, ox, oz, lot, rs)


func _split2(rs: RandomNumberGenerator, x0: float, s: float) -> Array:
	var h := s * 0.5 - 2.0
	if rs.randf() < 0.5:
		return [Rect2(x0, x0, h, s), Rect2(x0 + s * 0.5 + 2.0, x0, h, s)]
	return [Rect2(x0, x0, s, h), Rect2(x0, x0 + s * 0.5 + 2.0, s, h)]


func _split4(x0: float, s: float) -> Array:
	var h := s * 0.5 - 2.0
	var o := s * 0.5 + 2.0
	return [Rect2(x0, x0, h, h), Rect2(x0 + o, x0, h, h), Rect2(x0, x0 + o, h, h), Rect2(x0 + o, x0 + o, h, h)]


func _pick(zone: int, lot: Rect2, rs: RandomNumberGenerator) -> String:
	var r := rs.randf()
	if zone == 0:
		return "tower" if r < 0.5 else ("office" if r < 0.8 else ("apartment" if r < 0.92 else "shop"))
	if zone == 1:
		if r < 0.25: return "office"
		if r < 0.6: return "apartment"
		if r < 0.7: return "tower"
		if r < 0.85: return "shop"
		if r < 0.9: return "motel"
		return "warehouse"
	if lot.size.x < 50.0:
		return "house" if r < 0.85 else "shop"
	if r < 0.25: return "apartment"
	if r < 0.5: return "shop"
	if r < 0.62: return "motel"
	if r < 0.77: return "warehouse"
	if r < 0.87: return "office"
	return "house"


# ---------- 일반 건물(통짜 상자 + 셰이더 창) ----------
func _tower(mb: Object, solids: Array, ox: float, oz: float, lot: Rect2, rs: RandomNumberGenerator, zone: int) -> void:
	var ctr := lot.get_center()
	var w := lot.size.x * rs.randf_range(0.6, 0.85)
	var dd := lot.size.y * rs.randf_range(0.6, 0.85)
	var floors := rs.randi_range(28, 64) if zone == 0 else rs.randi_range(14, 30)
	var H := floors * 3.8
	var tint := rs.randf()
	var col := Color(0.0, tint, 0, 1)
	var pw := minf(lot.size.x - 4.0, w * 1.35)
	var pd := minf(lot.size.y - 4.0, dd * 1.35)
	_B(mb, solids, ox, oz, Vector3(ctr.x - pw / 2, 0, ctr.y - pd / 2), Vector3(ctr.x + pw / 2, 11.0, ctr.y + pd / 2), Color(0.1, rs.randf(), 0, 1))
	_B(mb, solids, ox, oz, Vector3(ctr.x - w / 2, 11.0, ctr.y - dd / 2), Vector3(ctr.x + w / 2, H * 0.88, ctr.y + dd / 2), col)
	_B(mb, solids, ox, oz, Vector3(ctr.x - w * 0.34, H * 0.88, ctr.y - dd * 0.34), Vector3(ctr.x + w * 0.34, H, ctr.y + dd * 0.34), col)
	if rs.randf() < 0.7:
		_B(mb, solids, ox, oz, Vector3(ctr.x - 0.5, H, ctr.y - 0.5), Vector3(ctr.x + 0.5, H + rs.randf_range(12.0, 32.0), ctr.y + 0.5), Color(0.5, 0, 0, 1))


func _office(mb: Object, solids: Array, ox: float, oz: float, lot: Rect2, rs: RandomNumberGenerator) -> void:
	var ctr := lot.get_center()
	var w := lot.size.x * rs.randf_range(0.7, 0.9)
	var dd := lot.size.y * rs.randf_range(0.7, 0.9)
	var floors := rs.randi_range(8, 22)
	var col := Color(0.1, rs.randf(), 0, 1)
	_B(mb, solids, ox, oz, Vector3(ctr.x - w / 2, 0, ctr.y - dd / 2), Vector3(ctr.x + w / 2, floors * 3.6, ctr.y + dd / 2), col)
	if rs.randf() < 0.5:
		_B(mb, solids, ox, oz, Vector3(ctr.x - w / 2, floors * 3.6, ctr.y - dd * 0.2), Vector3(ctr.x - w * 0.1, floors * 3.6 + 5.0, ctr.y + dd * 0.2), col)


func _apartment(mb: Object, solids: Array, ox: float, oz: float, lot: Rect2, rs: RandomNumberGenerator, zone: int) -> void:
	var ctr := lot.get_center()
	var w := minf(rs.randf_range(36.0, 56.0), lot.size.x - 8.0)
	var dd := minf(rs.randf_range(14.0, 18.0), lot.size.y - 8.0)
	if lot.size.y > lot.size.x:
		var tmp := w
		w = dd
		dd = tmp
		w = minf(w, lot.size.x - 8.0)
		dd = minf(dd, lot.size.y - 8.0)
	var floors := rs.randi_range(10, 22) if zone < 2 else rs.randi_range(6, 14)
	_B(mb, solids, ox, oz, Vector3(ctr.x - w / 2, 0, ctr.y - dd / 2), Vector3(ctr.x + w / 2, floors * 3.0, ctr.y + dd / 2), Color(0.2, rs.randf(), 0, 1))


func _shop(mb: Object, solids: Array, ox: float, oz: float, lot: Rect2, rs: RandomNumberGenerator) -> void:
	var ctr := lot.get_center()
	var w := lot.size.x * 0.9
	var dd := lot.size.y * 0.85
	var floors := rs.randi_range(2, 3)
	var tint := rs.randf()
	var top := floors * 3.6 + 2.0
	_B(mb, solids, ox, oz, Vector3(ctr.x - w / 2, 0, ctr.y - dd / 2), Vector3(ctr.x + w / 2, top, ctr.y + dd / 2), Color(0.3, tint, 0, 1))
	_B(mb, solids, ox, oz, Vector3(ctr.x - w * 0.3, top, ctr.y + dd / 2 - 0.6), Vector3(ctr.x + w * 0.3, top + 2.6, ctr.y + dd / 2 - 0.2), Color(0.8, rs.randf(), 0, 1))


func _motel(mb: Object, solids: Array, ox: float, oz: float, lot: Rect2, rs: RandomNumberGenerator) -> void:
	var w := minf(36.0, lot.size.x - 8.0)
	var floors := rs.randi_range(2, 3)
	var h := floors * 3.2
	var tint := rs.randf()
	var col := Color(0.7, tint, 0, 1)
	var x0 := lot.position.x + 5.0
	var z0 := lot.position.y + 5.0
	_B(mb, solids, ox, oz, Vector3(x0, 0, z0), Vector3(x0 + w, h, z0 + 11.0), col)
	_B(mb, solids, ox, oz, Vector3(x0, 0, z0 + 11.0), Vector3(x0 + 11.0, h, minf(z0 + 34.0, lot.end.y - 4.0)), col)
	var px := lot.position.x + 2.0
	_B(mb, solids, ox, oz, Vector3(px, 0, lot.position.y + 1.0), Vector3(px + 0.5, 11.0, lot.position.y + 1.5), Color(0.5, 0, 0, 1))
	_B(mb, solids, ox, oz, Vector3(px - 2.0, 8.5, lot.position.y + 0.8), Vector3(px + 3.0, 11.5, lot.position.y + 1.6), Color(0.8, rs.randf(), 0, 1))


func _house(mb: Object, solids: Array, ox: float, oz: float, lot: Rect2, rs: RandomNumberGenerator) -> void:
	var ctr := lot.get_center()
	var w := minf(rs.randf_range(9.0, 12.0), lot.size.x - 8.0)
	var dd := minf(rs.randf_range(8.0, 11.0), lot.size.y - 8.0)
	var floors := rs.randi_range(1, 2)
	var h := 3.0 * floors
	var tint := rs.randf()
	_B(mb, solids, ox, oz, Vector3(ctr.x - w / 2, 0, ctr.y - dd / 2), Vector3(ctr.x + w / 2, h, ctr.y + dd / 2), Color(0.4, tint, 0, 1))
	mb.gable(Vector3(ctr.x - w / 2 - 0.5, h, ctr.y - dd / 2 - 0.5), Vector3(ctr.x + w / 2 + 0.5, h, ctr.y + dd / 2 + 0.5), 2.2, w > dd, Color(0.9, rs.randf(), 0, 1))
	solids.append({"min": Vector3(ctr.x - w / 2 + ox, h, ctr.y - dd / 2 + oz), "max": Vector3(ctr.x + w / 2 + ox, h + 2.2, ctr.y + dd / 2 + oz)})
	if rs.randf() < 0.6:
		_B(mb, solids, ox, oz, Vector3(ctr.x + w / 2, 0, ctr.y - 3.0), Vector3(ctr.x + w / 2 + 6.0, 2.6, ctr.y + 3.0), Color(0.4, tint, 0, 1))


func _warehouse(mb: Object, solids: Array, ox: float, oz: float, lot: Rect2, rs: RandomNumberGenerator) -> void:
	var ctr := lot.get_center()
	_B(mb, solids, ox, oz, Vector3(ctr.x - lot.size.x * 0.45, 0, ctr.y - lot.size.y * 0.45), Vector3(ctr.x + lot.size.x * 0.45, rs.randf_range(8.0, 11.0), ctr.y + lot.size.y * 0.45), Color(0.6, rs.randf(), 0, 1))


# ---------- 들어갈 수 있는 폐건물 ----------
func _shell(L: Array, hx: float, hz: float, F: int, fh: float, pitch: float, front_open: bool, col: Color) -> void:
	var T := 0.35
	var top := F * fh + 0.2
	var nx := maxi(2, int(round(2.0 * hx / pitch)))
	var nz := maxi(2, int(round(2.0 * hz / pitch)))
	var pw := 0.9
	for i in nx + 1:
		var x := -hx + i * (2.0 * hx / nx)
		for sz in [-1.0, 1.0]:
			if front_open and sz > 0.0:
				continue
			L.append([Vector3(x - pw / 2, 0.2, sz * hz - T / 2), Vector3(x + pw / 2, top, sz * hz + T / 2), col])
	for j in nz + 1:
		var z := -hz + j * (2.0 * hz / nz)
		for sx in [-1.0, 1.0]:
			L.append([Vector3(sx * hx - T / 2, 0.2, z - pw / 2), Vector3(sx * hx + T / 2, top, z + pw / 2), col])
	for f in F:
		var y0 := f * fh + 0.2
		for sz in [-1.0, 1.0]:
			if front_open and sz > 0.0:
				continue
			if not (f == 0 and sz > 0.0):
				L.append([Vector3(-hx, y0 + 0.25, sz * hz - T / 2), Vector3(hx, y0 + 1.0, sz * hz + T / 2), col])
			L.append([Vector3(-hx, y0 + fh - 1.0, sz * hz - T / 2), Vector3(hx, y0 + fh, sz * hz + T / 2), col])
		for sx in [-1.0, 1.0]:
			L.append([Vector3(sx * hx - T / 2, y0 + 0.25, -hz), Vector3(sx * hx + T / 2, y0 + 1.0, hz), col])
			L.append([Vector3(sx * hx - T / 2, y0 + fh - 1.0, -hz), Vector3(sx * hx + T / 2, y0 + fh, hz), col])


func _slabs(L: Array, hx: float, hz: float, F: int, fh: float, hole: Rect2, col: Color) -> void:
	for f in range(1, F + 1):
		var y := f * fh + 0.2
		L.append([Vector3(-hx, y - 0.28, -hz), Vector3(hole.position.x, y, hz), col])
		L.append([Vector3(hole.end.x, y - 0.28, -hz), Vector3(hx, y, hz), col])
		L.append([Vector3(hole.position.x, y - 0.28, hole.end.y), Vector3(hole.end.x, y, hz), col])
		L.append([Vector3(hole.position.x, y - 0.28, -hz), Vector3(hole.end.x, y, hole.position.y), col])


func _hollow(kind: String, L: Array, rs: RandomNumberGenerator) -> Dictionary:
	var col := Color(0.5, rs.randf(), rs.randf(), 1)
	var sign_col := Color(0.8, rs.randf(), 0, 1)
	var hx := 15.0
	var hz := 6.0
	var F := 3
	var fh := 3.4
	var info := {}
	if kind == "apartment":
		hx = rs.randf_range(13.0, 17.0)
		hz = 6.0
		F = rs.randi_range(9, 14)
		fh = 3.4
		L.append([Vector3(-hx - 0.3, -3, -hz - 0.3), Vector3(hx + 0.3, 0.2, hz + 0.3), col])
		_shell(L, hx, hz, F, fh, 4.0, false, col)
		_slabs(L, hx, hz, F, fh, Rect2(-2.5, -2.0, 5.0, 4.0), col)
		for f in range(1, F):
			var y := f * fh + 0.2
			L.append([Vector3(-hx + 1.0, y - 0.25, hz), Vector3(hx - 1.0, y, hz + 1.4), col])
		for f in F:
			var y0 := f * fh + 0.2
			L.append([Vector3(-hx, y0, -0.17), Vector3(-1.4, y0 + fh - 0.28, 0.17), col])
			L.append([Vector3(1.4, y0, -0.17), Vector3(hx, y0 + fh - 0.28, 0.17), col])
		var nx := maxi(2, int(round(2.0 * hx / 4.0)))
		var wx := -hx + (nx / 2 + 0.5) * (2.0 * hx / nx)
		info = {"spot": Vector3(0, 0.2, -hz + 2.5), "hang": Vector3(-4.5, 1 * fh + 0.2, 3.0), "watch": Vector3(wx, 2 * fh + 0.2, hz - 0.7),
			"lights": [Vector3(-6, 1.8, 2), Vector3(6, 1.8, -2), Vector3(-5, fh + 1.8, 0), Vector3(5, 2 * fh + 1.8, 0), Vector3(0, 4 * fh + 1.8, 0)]}
	elif kind == "motel":
		hx = 18.0
		hz = 5.5
		F = 3
		fh = 3.2
		L.append([Vector3(-hx - 0.3, -3, -hz - 0.3), Vector3(hx + 0.3, 0.2, hz + 2.4), col])
		_shell(L, hx, hz, F, fh, 5.0, true, col)
		_slabs(L, hx, hz, F, fh, Rect2(-hx + 1.0, -1.5, 3.0, 3.0), col)
		var rooms := 7
		var rw := 2.0 * hx / rooms
		for f in F:
			var y0 := f * fh + 0.2
			for r in rooms:
				var xs := -hx + r * rw
				var xc := xs + rw * 0.5
				L.append([Vector3(xs, y0, hz - 0.17), Vector3(xc - 0.7, y0 + fh - 0.28, hz + 0.17), col])
				L.append([Vector3(xc + 0.7, y0, hz - 0.17), Vector3(xs + rw, y0 + fh - 0.28, hz + 0.17), col])
				L.append([Vector3(xc - 0.7, y0 + 2.4, hz - 0.17), Vector3(xc + 0.7, y0 + fh - 0.28, hz + 0.17), col])
				if r > 0:
					L.append([Vector3(xs - 0.12, y0, -hz), Vector3(xs + 0.12, y0 + fh - 0.28, hz), col])
			if f > 0:
				L.append([Vector3(-hx, y0 - 0.28, hz), Vector3(hx, y0, hz + 2.2), col])
				L.append([Vector3(-hx, y0, hz + 2.05), Vector3(hx, y0 + 1.0, hz + 2.15), col])
		L.append([Vector3(-hx, F * fh + 0.2 - 0.28, hz), Vector3(hx, F * fh + 0.2, hz + 2.2), col])
		L.append([Vector3(-hx + 8.0, 7.0, hz + 2.5), Vector3(-hx + 13.0, 10.0, hz + 3.1), sign_col])   # 옥상 간판
		var cx0 := -hx + rw * 3.5
		info = {"spot": Vector3(cx0, 0.2, 0.0), "hang": Vector3(-hx + rw * 4.5, fh + 0.2, 0.0), "watch": Vector3(-hx + rw * 5.5, 2 * fh + 0.2, hz - 0.7),
			"lights": [Vector3(cx0, 1.8, 0), Vector3(-hx + rw * 1.5, fh + 1.8, 0), Vector3(hx - rw * 1.5, fh + 1.8, 0), Vector3(0, 2 * fh + 1.8, 0)]}
	else:   # shop
		hx = 15.0
		hz = 8.0
		F = 3
		fh = 4.0
		L.append([Vector3(-hx - 0.3, -3, -hz - 0.3), Vector3(hx + 0.3, 0.2, hz + 0.3), col])
		_shell(L, hx, hz, F, fh, 5.0, true, col)
		_slabs(L, hx, hz, F, fh, Rect2(-6.0, -4.0, 12.0, 8.0), col)
		# 앞면: 1층은 기둥만, 위층은 창 있는 벽
		for i in 6:
			var x := -hx + i * (2.0 * hx / 5.0)
			L.append([Vector3(x - 0.3, 0.2, hz - 0.3), Vector3(x + 0.3, fh + 0.2, hz + 0.3), col])
		var nx2 := 6
		for i in nx2 + 1:
			var x2 := -hx + i * (2.0 * hx / nx2)
			L.append([Vector3(x2 - 0.45, fh + 0.2, hz - 0.17), Vector3(x2 + 0.45, F * fh + 0.2, hz + 0.17), col])
		for f in range(1, F):
			var y0 := f * fh + 0.2
			L.append([Vector3(-hx, y0 + 0.25, hz - 0.17), Vector3(hx, y0 + 1.0, hz + 0.17), col])
			L.append([Vector3(-hx, y0 + fh - 1.0, hz - 0.17), Vector3(hx, y0 + fh, hz + 0.17), col])
		L.append([Vector3(-hx + 2.0, fh + 0.4, hz + 0.2), Vector3(hx - 2.0, fh + 1.6, hz + 0.6), sign_col])   # 간판
		for k in 4:
			L.append([Vector3(-12.0 + k * 3.0, 0.2, -6.0), Vector3(-10.6 + k * 3.0, 1.1, -3.5), col])        # 진열대
		for k in 3:
			L.append([Vector3(8.0, 0.2, -5.0 + k * 3.5), Vector3(8.6, 2.2, -2.5 + k * 3.5), col])            # 선반
		for p in [Vector2(-9, 3), Vector2(9, 3), Vector2(-9, -3), Vector2(9, -3)]:
			L.append([Vector3(p.x - 0.35, 0.2, p.y - 0.35), Vector3(p.x + 0.35, fh, p.y + 0.35), col])       # 기둥
		info = {"spot": Vector3(0, 0.2, -5.0), "hang": Vector3(6.5, fh + 0.2, 0.0), "watch": Vector3(0, 2 * fh + 0.2, hz - 0.7),
			"lights": [Vector3(-6, 2.6, 2), Vector3(6, 2.6, -2), Vector3(0, fh + 2.2, 4), Vector3(0, 2 * fh + 2.2, 0)]}
	info.hx = hx
	info.hz = hz
	info.roof = F * fh + 0.5
	return info


func _enter(kind: String, c: Vector2i, node: Node3D, rs: RandomNumberGenerator, ox: float, oz: float, ctr: Vector2) -> void:
	var L: Array = []
	var info := _hollow(kind, L, rs)
	var mb := MB.new()
	var aabbs: Array = []
	var off := Vector3(ctr.x, 0, ctr.y)
	var wof := Vector3(ox + ctr.x, 0, oz + ctr.y)
	for b in L:
		mb.box(b[0] + off, b[1] + off, b[2])
		aabbs.append({"min": b[0] + wof, "max": b[1] + wof})
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	mi.material_override = mat
	node.add_child(mi)
	var lights: Array = []
	for p in info.lights:
		var l := OmniLight3D.new()
		l.position = off + p
		l.light_color = Color(0.6, 0.78, 0.7)
		l.omni_range = 9.0
		l.light_energy = 0.45
		l.distance_fade_enabled = true
		l.distance_fade_begin = 90.0
		l.distance_fade_length = 40.0
		node.add_child(l)
		lights.append({"node": l, "base": 0.45, "ph": rs.randf() * 20.0})
	var b := {"origin": wof, "yaw": 0.0, "rot": Basis.IDENTITY, "base": 0.0, "aabbs": aabbs, "node": node, "lights": lights,
		"armed": true, "type": rs.randi_range(0, 4), "dark_until": 0.0,
		"spot": wof + info.spot, "hang": wof + info.hang, "watch": wof + info.watch, "front": info.hz,
		"hx": info.hx, "hz": info.hz, "roof": info.roof, "reach": maxf(info.hx, info.hz) + 10.0}
	if buildings != null:
		buildings.add_enterable(c, b)


# ---------- 가로등 / 가로수 ----------
func _make_lamp() -> void:
	var pole := MB.new()
	pole.cylinder(Vector3(0, 0, 0), 0.14, 8.0, 6, Color(0.16, 0.17, 0.18))
	pole.box(Vector3(0, 7.9, -0.07), Vector3(2.6, 8.05, 0.07), Color(0.16, 0.17, 0.18))
	var head := MB.new()
	head.box(Vector3(2.0, 7.7, -0.22), Vector3(2.9, 7.88, 0.22), Color(1.0, 0.9, 0.7))
	lamp_mesh = ArrayMesh.new()
	var a1 := []
	a1.resize(Mesh.ARRAY_MAX)
	a1[Mesh.ARRAY_VERTEX] = pole.v
	a1[Mesh.ARRAY_NORMAL] = pole.n
	a1[Mesh.ARRAY_COLOR] = pole.c
	a1[Mesh.ARRAY_INDEX] = pole.idx
	lamp_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a1)
	var a2 := []
	a2.resize(Mesh.ARRAY_MAX)
	a2[Mesh.ARRAY_VERTEX] = head.v
	a2[Mesh.ARRAY_NORMAL] = head.n
	a2[Mesh.ARRAY_COLOR] = head.c
	a2[Mesh.ARRAY_INDEX] = head.idx
	lamp_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
	var pm := StandardMaterial3D.new()
	pm.vertex_color_use_as_albedo = true
	pm.roughness = 0.6
	pm.metallic = 0.4
	lamp_mesh.surface_set_material(0, pm)
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.albedo_color = Color(1.0, 0.85, 0.55)
	hm.emission_enabled = true
	hm.emission = Color(1.0, 0.75, 0.4)
	hm.emission_energy_multiplier = 4.0
	lamp_mesh.surface_set_material(1, hm)
	lamp_head = hm


func _lamps(node: Node3D, rs: RandomNumberGenerator) -> void:
	var xf: Array[Transform3D] = []
	var sw := RH + 1.4
	for k in 4:
		for i in 4:
			var t := 20.0 + i * 38.0
			var p := Vector3.ZERO
			var yaw := 0.0
			match k:
				0:
					p = Vector3(sw, 0, t)
					yaw = PI
				1:
					p = Vector3(CELL - sw, 0, t)
					yaw = 0.0
				2:
					p = Vector3(t, 0, sw)
					yaw = PI / 2.0
				_:
					p = Vector3(t, 0, CELL - sw)
					yaw = -PI / 2.0
			xf.append(Transform3D(Basis(Vector3.UP, yaw), p))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = lamp_mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mmi)


func _make_tree() -> void:
	tree_mesh = ArrayMesh.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.14
	trunk.bottom_radius = 0.2
	trunk.height = 3.2
	trunk.radial_segments = 6
	trunk.rings = 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 1.6, 0)))
	st.commit(tree_mesh)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.25, 0.16, 0.1)
	tm.roughness = 1.0
	tree_mesh.surface_set_material(0, tm)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var sp := SphereMesh.new()
		sp.radius = 2.2 - k * 0.7
		sp.height = (4.0 - k * 1.2)
		sp.radial_segments = 8
		sp.rings = 5
		st2.append_from(sp, 0, Transform3D(Basis(), Vector3(k * 0.3, 4.4 + k * 1.6, 0)))
	st2.commit(tree_mesh)
	var lm := StandardMaterial3D.new()
	lm.vertex_color_use_as_albedo = true
	lm.roughness = 0.95
	tree_mesh.surface_set_material(1, lm)


func _trees(node: Node3D, c: Vector2i, btype: int, rs: RandomNumberGenerator, d: float) -> void:
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	var zone_p := 0.15 if d < 450.0 else (0.4 if d < 900.0 else 0.7)
	if btype == 1:
		for i in 46:
			var p := Vector3(rs.randf_range(18.0, 142.0), 0, rs.randf_range(18.0, 142.0))
			if c == Vector2i(0, 0) and Vector2(p.x, p.z).distance_to(Vector2(80, 80)) < 14.0:
				continue
			var s := rs.randf_range(0.9, 1.7)
			xf.append(Transform3D(Basis(Vector3.UP, rs.randf() * TAU).scaled(Vector3(s, s * rs.randf_range(0.9, 1.3), s)), p))
	elif btype == 2:
		for i in rs.randi_range(6, 14):
			var p := Vector3(rs.randf_range(16.0, 144.0), 0, 18.0 + rs.randf() * 4.0)
			var s := rs.randf_range(0.9, 1.6)
			xf.append(Transform3D(Basis(Vector3.UP, rs.randf() * TAU).scaled(Vector3(s, s, s)), p))
	else:
		var off := RH + 2.8
		for k in 4:
			for i in 9:
				if rs.randf() > zone_p:
					continue
				var t := 12.0 + i * 16.0 + 8.0
				var p := Vector3.ZERO
				match k:
					0: p = Vector3(off, 0, t)
					1: p = Vector3(CELL - off, 0, t)
					2: p = Vector3(t, 0, off)
					_: p = Vector3(t, 0, CELL - off)
				var s := rs.randf_range(0.7, 1.1)
				xf.append(Transform3D(Basis(Vector3.UP, rs.randf() * TAU).scaled(Vector3(s, s, s)), p))
	if xf.is_empty():
		return
	for i in xf.size():
		cols.append(Color.from_hsv(rs.randf_range(0.18, 0.32), rs.randf_range(0.5, 0.8), rs.randf_range(0.25, 0.5)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tree_mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mmi)
