extends Control
## 드론 OSD(화면 위 계기판)와 상점 화면.

var d := {}
var font: Font
var kfont: Font
var accent := Color(0.2, 1.0, 0.45)
var shop_open := false
var shop_items: Array = []
var shop_levels := {}
var shop_coins := 0
var toast := ""
var toast_t := 0.0
var toast_col := Color(1, 1, 1)
var radio := ""
var radio_t := 0.0
var banner := ""
var banner_t := 0.0
var banner_col := Color(1, 0.85, 0.4)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	font = f
	var k := SystemFont.new()
	k.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR"])
	kfont = k


func show_toast(t: String, secs: float = 3.0, col: Color = Color(1, 1, 1)) -> void:
	toast = t
	toast_t = secs
	toast_col = col


## 관제 노을의 무전 (왼쪽 아래 말풍선)
func show_radio(t: String, secs: float = 5.0) -> void:
	if t == "":
		return
	radio = t
	radio_t = secs


## 화면 가운데 큰 글자 (미션 결과, 랭크 업 등)
func show_banner(t: String, secs: float = 3.2, col: Color = Color(1, 0.85, 0.4)) -> void:
	banner = t
	banner_t = secs
	banner_col = col


func set_data(data: Dictionary, dt: float) -> void:
	d = data
	toast_t = maxf(0.0, toast_t - dt)
	radio_t = maxf(0.0, radio_t - dt)
	banner_t = maxf(0.0, banner_t - dt)
	queue_redraw()


func _s(txt: String, p: Vector2, sz: int, col: Color, al: int = 0, fnt: Font = null) -> void:
	var fo := fnt if fnt != null else font
	var q := p
	if al == 1:
		q.x -= 400.0
	elif al == 2:
		q.x -= 800.0
	var w := -1.0 if al == 0 else (800.0 if al == 2 else 800.0)
	var ha := HORIZONTAL_ALIGNMENT_LEFT if al == 0 else (HORIZONTAL_ALIGNMENT_CENTER if al == 1 else HORIZONTAL_ALIGNMENT_RIGHT)
	draw_string(fo, q + Vector2(1.5, 1.5), txt, ha, w, sz, Color(0, 0, 0, 0.7))
	draw_string(fo, q, txt, ha, w, sz, col)


func _draw() -> void:
	if d.is_empty():
		return
	var vs := get_viewport_rect().size
	var W := vs.x
	var H := vs.y
	var cx := W * 0.5
	var cy := H * 0.5
	var white := Color(1, 1, 1, 0.92)
	var dim := Color(1, 1, 1, 0.55)
	var warn_blink := fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.4

	# ---- 인공수평선 ----
	var ppd: float = H / maxf(d.fov, 30.0)
	draw_set_transform(Vector2(cx, cy), d.cam_roll, Vector2.ONE)
	for deg in range(-40, 41, 10):
		var y: float = (d.cam_pitch - deg) * ppd
		if absf(y) > H * 0.45:
			continue
		var w := 150.0 if deg == 0 else 54.0
		var c := Color(accent.r, accent.g, accent.b, 0.85 if deg == 0 else 0.45)
		draw_line(Vector2(-w, y), Vector2(-26.0 if deg == 0 else -w * 0.4, y), c, 2.0)
		draw_line(Vector2(26.0 if deg == 0 else w * 0.4, y), Vector2(w, y), c, 2.0)
		if deg != 0:
			draw_string(font, Vector2(w + 6, y + 5), str(deg), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 중앙 조준
	draw_circle(Vector2(cx, cy), 3.0, Color(accent.r, accent.g, accent.b, 0.9))
	for a in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1)]:
		draw_line(Vector2(cx, cy) + a * 10.0, Vector2(cx, cy) + a * 22.0, Color(accent.r, accent.g, accent.b, 0.7), 2.0)

	# ---- 상단 좌: 배터리 ----
	var bx := 36.0
	var by := 34.0
	var bat: float = d.batt
	var bcol := accent if bat > 25.0 else (Color(1, 0.8, 0.2) if bat > 12.0 else Color(1, 0.25, 0.25))
	draw_rect(Rect2(bx, by, 64, 24), white, false, 2.0)
	draw_rect(Rect2(bx + 64, by + 7, 5, 10), white)
	draw_rect(Rect2(bx + 3, by + 3, 58.0 * clampf(bat / 100.0, 0, 1), 18), bcol)
	_s("%d%%" % int(bat), Vector2(bx + 80, by + 20), 22, bcol)
	_s("%.1fV   %s" % [12.8 + 4.0 * bat / 100.0, _mmss(d.flight)], Vector2(bx, by + 50), 16, dim)

	# ---- 상단 중앙: REC / 카메라 설정 ----
	var rec_on := fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.7
	if rec_on:
		draw_circle(Vector2(cx - 78, 44), 7.0, Color(1, 0.15, 0.15))
	_s("REC " + _mmss(d.rec), Vector2(cx - 62, 51), 22, white)
	_s("4K 60fps   ISO 100   EV +0.0   WB 5600K", Vector2(cx, 80), 14, dim, 1)
	_s("MAP  " + String(d.world), Vector2(cx, 100), 14, Color(accent.r, accent.g, accent.b, 0.8), 1, kfont)

	# ---- 상단 우: GPS / 링크 ----
	var rx := W - 36.0
	var sig: float = d.signal
	for i in 5:
		var on: bool = sig * 5.0 > i + 0.3
		var col := accent if on else Color(1, 1, 1, 0.2)
		if sig < 0.3 and on:
			col = Color(1, 0.3, 0.3)
		draw_rect(Rect2(rx - 190 + i * 11, 54 - i * 4, 7, 6 + i * 4), col)
	_s("RC %d%%" % int(sig * 100.0), Vector2(rx, 34), 18, white, 2)
	var sats := int(18.0 * (1.0 - d.indoor))
	_s("GPS %d SAT%s" % [sats, "  NO FIX" if sats < 4 else ""], Vector2(rx, 56), 16, Color(1, 0.6, 0.3) if sats < 4 else dim, 2)
	_s("LINK 5.8GHz", Vector2(rx, 76), 14, dim, 2)

	# ---- 좌측: 고도 / 우측: 속도 ----
	_s("ALT", Vector2(60, cy - 14), 14, dim)
	_s("%.1f m" % d.alt, Vector2(60, cy + 14), 28, white)
	_s("V.SPD %+.1f" % d.vspd, Vector2(60, cy + 40), 15, dim)
	_s("SPD", Vector2(W - 60, cy - 14), 14, dim, 2)
	_s("%d km/h" % int(d.spd), Vector2(W - 60, cy + 14), 28, white, 2)
	_s("%.1f m/s" % (d.spd / 3.6), Vector2(W - 60, cy + 40), 15, dim, 2)

	# ---- 하단: 나침반 ----
	var ty := H - 70.0
	var hd: float = d.heading
	var pxd := 7.0
	draw_line(Vector2(cx - 300, ty), Vector2(cx + 300, ty), Color(1, 1, 1, 0.3), 1.5)
	for k in range(-45, 46):
		var deg := roundi(hd) + k
		var x := cx + (deg - hd) * pxd
		if absf(x - cx) > 300.0:
			continue
		var dd := posmod(deg, 360)
		if dd % 5 == 0:
			var tall := 14.0 if dd % 15 == 0 else 8.0
			draw_line(Vector2(x, ty), Vector2(x, ty - tall), white if dd % 15 == 0 else dim, 1.5)
		if dd % 45 == 0:
			var names := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
			_s(names[dd], Vector2(x, ty + 22), 16, accent if dd == 0 else white, 1)
	draw_colored_polygon(PackedVector2Array([Vector2(cx, ty - 20), Vector2(cx - 7, ty - 32), Vector2(cx + 7, ty - 32)]), accent)
	_s("%03d°" % int(hd), Vector2(cx, ty - 40), 20, white, 1)
	# 귀환점 / 가장 가까운 코인 표시
	var hrel := _wrap(d.home_bearing - hd)
	if absf(hrel) * pxd < 300.0:
		_s("H", Vector2(cx + hrel * pxd, ty - 6), 20, Color(1, 0.7, 0.2), 1)
	if d.bld_dist < 1.0e8:
		var brel := _wrap(d.bld_bearing - hd)
		var bxp := cx + clampf(brel * pxd, -300.0, 300.0)
		_s("▲", Vector2(bxp, ty + 20), 18, Color(1, 0.35, 0.3), 1, kfont)
		_s("%dm" % int(d.bld_dist), Vector2(bxp, ty + 84), 13, Color(1, 0.5, 0.45), 1)
	if d.coin_dist < 1.0e8:
		var crel := _wrap(d.coin_bearing - hd)
		var cxp := cx + clampf(crel * pxd, -300.0, 300.0)
		draw_circle(Vector2(cxp, ty + 40), 7.0, Color(1, 0.78, 0.2))
		_s("%dm" % int(d.coin_dist), Vector2(cxp, ty + 64), 13, Color(1, 0.85, 0.4), 1)
	_s("HOME %d m" % int(d.home_dist), Vector2(60, H - 50), 18, white)
	_s("ODO %.2f km   MODE %s" % [d.odo / 1000.0, "ASSIST" if d.assist else "MANUAL"], Vector2(60, H - 28), 14, dim)

	# ---- 코인 ----
	draw_circle(Vector2(W - 70, H - 62), 12.0, Color(1, 0.78, 0.2))
	draw_circle(Vector2(W - 70, H - 62), 8.0, Color(0.85, 0.55, 0.1))
	_s("%d" % shop_coins, Vector2(W - 48, H - 54), 26, Color(1, 0.88, 0.45))
	_s("[I] 보관함   [ESC] MENU", Vector2(W - 36, H - 28), 14, dim, 2, kfont)

	# ---- 미션 ----
	var ms: Dictionary = d.get("mission", {"on": false})
	if ms.on:
		var mc := Color(0.35, 0.92, 1.0) if ms.type == "ring" else (Color(1.0, 0.62, 0.2) if ms.type == "pickup" else Color(0.4, 1.0, 0.5))
		_s("MISSION · " + String(ms.title), Vector2(60, 132), 18, mc, 0, kfont)
		var prog := ""
		match String(ms.kind):
			"ring": prog = "링 %d / %d" % [ms.idx, ms.n]
			"delivery": prog = "소포 배달 중 → 목적지로" if ms.carry else "소포를 집으러 가세요"
			"photo": prog = "촬영 %d / %d" % [ms.idx, ms.n]
			_: prog = "착륙 패드 위에 내려앉으세요"
		_s(prog, Vector2(60, 158), 16, white, 0, kfont)
		var tl: float = ms.time
		_s("%d:%02d" % [int(tl) / 60, int(tl) % 60], Vector2(60, 192), 28, Color(1, 0.4, 0.35) if (tl < 15.0 and warn_blink) else white)
		var sp: Vector2 = ms.scr
		var mp := Vector2(clampf(sp.x, 80.0, W - 80.0), clampf(sp.y, 130.0, H - 150.0))
		if ms.behind:
			mp = Vector2(80.0 if sp.x > cx else W - 80.0, cy)
		var rr := 15.0
		var dia := PackedVector2Array([mp + Vector2(0, -rr), mp + Vector2(rr, 0), mp + Vector2(0, rr), mp + Vector2(-rr, 0)])
		draw_colored_polygon(dia, Color(mc.r, mc.g, mc.b, 0.28))
		draw_polyline(PackedVector2Array([dia[0], dia[1], dia[2], dia[3], dia[0]]), mc, 2.5)
		_s("%d m" % int(ms.dist), mp + Vector2(0, 38), 15, mc, 1)
	elif not bool((d.get("cmb", {}) as Dictionary).get("on", false)):
		_s("[%s] 배송 의뢰" % d.get("key_mission", "N"), Vector2(60, 132), 16, dim, 0, kfont)

	# ---- 경고 ----
	if d.state == "crashed":
		_s(d.crash_reason, Vector2(cx, cy - 20), 46, Color(1, 0.25, 0.25), 1)
		_s("RETURNING TO HOME...", Vector2(cx, cy + 24), 20, white, 1)
	else:
		if bat < 20.0 and warn_blink and d.state == "flying":
			_s("LOW BATTERY", Vector2(cx, 140), 30, Color(1, 0.3, 0.3), 1)
		if sig < 0.35 and warn_blink and d.state == "flying":
			_s("WEAK SIGNAL - RETURN TO HOME", Vector2(cx, 176), 22, Color(1, 0.7, 0.2), 1)
		if d.state == "idle":
			_s("LANDED · SPACE 로 이륙", Vector2(cx, cy + 120), 22, white, 1, kfont)

	if toast_t > 0.0:
		_s(toast, Vector2(cx, H * 0.28), 22, Color(toast_col.r, toast_col.g, toast_col.b, clampf(toast_t, 0.0, 1.0)), 1, kfont)

	_draw_combat(W, H, cx, cy, dim, white)
	_draw_extras(W, H, cx, cy, dim, white)

	if shop_open:
		_draw_shop(W, H)


const TIER_COL := [Color.WHITE, Color(0.85, 0.9, 0.95), Color(0.45, 0.88, 1.0), Color(0.8, 0.55, 1.0), Color(1.0, 0.65, 0.25), Color(1.0, 0.35, 0.35)]


## 전투 HUD: 적 체력·록온·내 체력/탄약·피격 방향·보급품 방향
func _draw_combat(W: float, H: float, cx: float, cy: float, dim: Color, white: Color) -> void:
	var c: Dictionary = d.get("cmb", {})
	if not bool(c.get("on", false)):
		return
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.3
	# 피격 붉은 테두리
	var hf: float = c.hurt
	if hf > 0.01:
		var e := 90.0
		var a0 := Color(1, 0.05, 0.05, 0.5 * hf)
		var a1 := Color(1, 0.05, 0.05, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, e), Vector2(0, e)]), PackedColorArray([a0, a0, a1, a1]))
		draw_polygon(PackedVector2Array([Vector2(0, H - e), Vector2(W, H - e), Vector2(W, H), Vector2(0, H)]), PackedColorArray([a1, a1, a0, a0]))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(e, 0), Vector2(e, H), Vector2(0, H)]), PackedColorArray([a0, a1, a1, a0]))
		draw_polygon(PackedVector2Array([Vector2(W - e, 0), Vector2(W, 0), Vector2(W, H), Vector2(W - e, H)]), PackedColorArray([a1, a0, a0, a1]))
	# 조준 링
	draw_arc(Vector2(cx, cy), 36.0, 0.0, TAU, 40, Color(1, 1, 1, 0.22), 1.5)
	# 맞은 곳 표시
	if float(c.hitm) > 0.0:
		var hc := Color(1, 0.3, 0.3) if bool(c.kill) else Color(1, 1, 1)
		for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(Vector2(cx, cy) + s * 8.0, Vector2(cx, cy) + s * 18.0, hc, 3.0)
	# 피격 방향
	for mk in c.marks:
		var ang: float = mk.ang
		var p0 := Vector2(cx + sin(ang) * 170.0, cy - cos(ang) * 170.0)
		var dirv := Vector2(sin(ang), -cos(ang))
		var side := Vector2(-dirv.y, dirv.x)
		draw_colored_polygon(PackedVector2Array([p0 + dirv * 22.0, p0 + side * 12.0, p0 - side * 12.0]), Color(1, 0.2, 0.2, 0.85 * float(mk.a)))
	# 적 표시
	var boss: Dictionary = {}
	for en in c.enemies:
		var tcol: Color = TIER_COL[clampi(int(en.tier), 0, 5)]
		var sp: Vector2 = en.scr
		var sc: Vector2 = en.scr_c
		var onscreen: bool = (not bool(en.behind)) and sp.x > 20.0 and sp.x < W - 20.0 and sp.y > 20.0 and sp.y < H - 20.0
		if bool(en.boss):
			boss = en
		if onscreen:
			var bw := 76.0 if not bool(en.boss) else 120.0
			var hp: float = en.hp
			var hcol := Color(0.4, 1.0, 0.5) if hp > 0.5 else (Color(1.0, 0.8, 0.3) if hp > 0.25 else Color(1.0, 0.3, 0.3))
			draw_rect(Rect2(sp.x - bw * 0.5 - 1.0, sp.y - 13.0, bw + 2.0, 8.0), Color(0, 0, 0, 0.65))
			draw_rect(Rect2(sp.x - bw * 0.5, sp.y - 12.0, bw * hp, 6.0), hcol)
			_s("%s  %dm" % [en.name, int(en.dist)], Vector2(sp.x, sp.y - 20.0), 14, tcol, 1, kfont)
			var bc := Color(1.0, 0.25, 0.25, 0.85)
			var bs := 15.0
			if bool(en.locked):
				bs = 24.0
				bc = Color(1.0, 0.1, 0.1)
				_s("LOCK", Vector2(sc.x, sc.y + bs + 18.0), 16, bc, 1)
			elif bool(en.locking):
				bs = 44.0 - 20.0 * float(c.lock)
				bc = Color(1.0, 0.85, 0.2)
			else:
				bc = Color(1.0, 1.0, 1.0, 0.35)
			var ln := 7.0
			for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				var cc: Vector2 = sc + s * bs
				draw_line(cc, cc - Vector2(s.x * ln, 0), bc, 2.5)
				draw_line(cc, cc - Vector2(0, s.y * ln), bc, 2.5)
		else:
			# 화면 밖: 가장자리 화살표
			var ang2: float = en.ang
			var dv := Vector2(sin(ang2), -cos(ang2))
			var k := minf((W * 0.5 - 50.0) / maxf(absf(dv.x), 0.001), (H * 0.5 - 90.0) / maxf(absf(dv.y), 0.001))
			var ap := Vector2(cx, cy) + dv * k
			var sd := Vector2(-dv.y, dv.x)
			draw_colored_polygon(PackedVector2Array([ap + dv * 14.0, ap + sd * 9.0, ap - sd * 9.0]), Color(tcol.r, tcol.g, tcol.b, 0.85))
			_s("%dm" % int(en.dist), ap - dv * 22.0 + Vector2(0, 5), 12, tcol, 1)
	# 보스 체력 바
	if not boss.is_empty():
		var bw2 := 520.0
		var bx2 := cx - bw2 * 0.5
		_s(String(boss.name), Vector2(cx, 150), 20, Color(1.0, 0.5, 0.4), 1, kfont)
		draw_rect(Rect2(bx2 - 2.0, 158.0, bw2 + 4.0, 14.0), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bx2, 160.0, bw2 * float(boss.hp), 10.0), Color(0.95, 0.25, 0.3))
	# 모드 안내
	var title := "DRONE DUEL" if c.mode == "duel" else "MONSTER HUNT"
	_s(title, Vector2(60, 132), 20, Color(1.0, 0.55, 0.4), 0, font)
	if c.mode == "duel":
		_s("WAVE %d   남은 적 %d   격추 %d" % [c.wave, c.left, c.kills], Vector2(60, 158), 16, white, 0, kfont)
		if bool(c.wave_wait):
			_s("다음 웨이브까지 %d초" % int(ceil(float(c.wave_t))), Vector2(60, 184), 16, Color(0.6, 1.0, 0.7), 0, kfont)
	else:
		_s("처치 %d   보스 %d   근처 적 %d" % [c.kills, c.boss_kills, c.left], Vector2(60, 158), 16, white, 0, kfont)
	# 경고
	if bool(c.warn) and blink:
		_s("▲ MISSILE INCOMING ▲", Vector2(cx, 200), 30, Color(1.0, 0.25, 0.2), 1, kfont)
	# 내 체력
	var hpf: float = clampf(float(c.hp) / maxf(float(c.hp_max), 1.0), 0.0, 1.0)
	var hc2 := Color(0.4, 1.0, 0.55) if hpf > 0.5 else (Color(1.0, 0.8, 0.3) if hpf > 0.25 else Color(1.0, 0.3, 0.3))
	var hx := 60.0
	var hy := H - 100.0
	_s("HP  %d / %d" % [int(ceil(float(c.hp))), int(c.hp_max)], Vector2(hx, hy - 6.0), 18, hc2)
	draw_rect(Rect2(hx - 2.0, hy - 2.0, 244.0, 14.0), Color(0, 0, 0, 0.65))
	draw_rect(Rect2(hx, hy, 240.0 * hpf, 10.0), hc2)
	if hpf < 0.3 and blink:
		_s("HP LOW", Vector2(hx + 130.0, hy - 6.0), 16, Color(1, 0.3, 0.3))
	# 탄약·유도탄
	var ax := W - 280.0
	var ay := H - 190.0
	_s("AMMO  ∞", Vector2(ax, ay), 24, white, 0, kfont)
	_s("MISSILE  " + "▲".repeat(int(c.missiles)) + ("  (0)" if int(c.missiles) == 0 else ""), Vector2(ax, ay + 28.0), 18, Color(1.0, 0.7, 0.45), 0, kfont)
	var lock_txt := "LOCKED — [%s] 발사" % d.get("key_missile", "G") if bool(c.locked) else ("록온 중…" if float(c.lock) > 0.0 else "록온 대기")
	_s(lock_txt, Vector2(ax, ay + 52.0), 15, Color(1.0, 0.3, 0.3) if bool(c.locked) else dim, 0, kfont)
	# 나침반 위 보급품 표시
	var hd: float = d.heading
	var ty := H - 70.0
	if float(c.pk_d) < 1.0e8:
		var rel: float = _wrap(float(c.pk_b) - hd)
		var xp := cx + clampf(rel * 7.0, -300.0, 300.0)
		var pcol := Color(1.0, 0.75, 0.2) if c.pk_kind == "mag" else (Color(1.0, 0.4, 0.35) if c.pk_kind == "missile" else Color(0.4, 1.0, 0.55))
		draw_rect(Rect2(xp - 6.0, ty - 74.0, 12.0, 12.0), pcol)
		_s("%dm" % int(c.pk_d), Vector2(xp, ty - 78.0), 12, pcol, 1)
	if float(c.dr_d) < 400.0:
		var rel2: float = _wrap(float(c.dr_b) - hd)
		var xp2 := cx + clampf(rel2 * 7.0, -300.0, 300.0)
		draw_circle(Vector2(xp2, ty - 54.0), 6.0, Color(1.0, 0.95, 0.5))
		_s("%dm" % int(c.dr_d), Vector2(xp2, ty - 62.0), 12, Color(1.0, 0.95, 0.6), 1)


## 시계·날씨, 튜토리얼, 무전, 사진 뷰파인더, 랭크 바, 숨겨진 상자 표시
func _draw_extras(W: float, H: float, cx: float, cy: float, dim: Color, white: Color) -> void:
	if d.has("clock"):
		_s("%s  ·  %s" % [d.clock, d.weather], Vector2(cx, 118), 15, dim, 1, kfont)
	# 튜토리얼
	var tt: String = d.get("tutorial", "")
	if tt != "":
		var w := 760.0
		var r := Rect2(cx - w * 0.5, 146.0, w, 66.0)
		draw_rect(r, Color(0.03, 0.06, 0.1, 0.72))
		draw_rect(r, Color(0.35, 0.92, 1.0, 0.5), false, 1.5)
		_s(String(d.get("tutorial_prog", "")), Vector2(cx, 168), 13, Color(0.35, 0.92, 1.0), 1, kfont)
		_s(tt, Vector2(cx, 196), 21, white, 1, kfont)
		_s("[Tab] 튜토리얼 건너뛰기", Vector2(cx, 232), 12, dim, 1, kfont)
	# 사진 미션 뷰파인더
	var ms: Dictionary = d.get("mission", {"on": false})
	if ms.on and ms.type == "photo":
		var vc := Color(1.0, 0.45, 0.88, 0.9)
		var hw := 150.0
		var hh := 96.0
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var c0 := Vector2(cx + sx * hw, cy + sy * hh)
				draw_line(c0, c0 + Vector2(-sx * 34.0, 0), vc, 3.0)
				draw_line(c0, c0 + Vector2(0, -sy * 34.0), vc, 3.0)
		draw_circle(Vector2(cx, cy), 3.0, vc)
		_s("[%s] 셔터" % d.get("key_photo", "P"), Vector2(cx, cy + hh + 36.0), 16, vc, 1, kfont)
	# 숨겨진 상자
	if d.get("secret_dist", 1.0e9) < 380.0:
		var hd: float = d.heading
		var rel := _wrap(d.secret_bearing - hd)
		var xp := cx + clampf(rel * 7.0, -300.0, 300.0)
		_s("?", Vector2(xp, H - 94.0), 22, Color(1, 0.85, 0.3), 1)
		_s("%dm" % int(d.secret_dist), Vector2(xp, H - 110.0), 12, Color(1, 0.85, 0.4), 1)
	# 랭크 바
	if d.has("rank"):
		var bx := W - 280.0
		var by := H - 112.0
		_s("RANK %d  %s" % [d.rank, d.rank_name], Vector2(bx, by), 15, white, 0, kfont)
		draw_rect(Rect2(bx, by + 8.0, 220.0, 6.0), Color(1, 1, 1, 0.14))
		draw_rect(Rect2(bx, by + 8.0, 220.0 * float(d.xp_prog), 6.0), Color(0.35, 0.92, 1.0))
	# 무전
	if radio_t > 0.0:
		var a := clampf(radio_t, 0.0, 1.0)
		var wr := 520.0
		var rr := Rect2(52.0, H - 190.0, wr, 62.0)
		draw_rect(rr, Color(0.03, 0.06, 0.1, 0.78 * a))
		draw_rect(Rect2(rr.position, Vector2(4.0, rr.size.y)), Color(0.4, 1.0, 0.62, a))
		_s(radio, rr.position + Vector2(16.0, 38.0), 18, Color(0.92, 1.0, 0.95, a), 0, kfont)
	# 큰 안내 문구
	if banner_t > 0.0:
		var ba := clampf(banner_t / 0.6, 0.0, 1.0)
		_s(banner, Vector2(cx, cy - 140.0), 44, Color(banner_col.r, banner_col.g, banner_col.b, ba), 1, kfont)


func _draw_shop(W: float, H: float) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.72))
	var pw := 820.0
	var ph := 470.0
	var px := (W - pw) * 0.5
	var py := (H - ph) * 0.5
	draw_rect(Rect2(px, py, pw, ph), Color(0.07, 0.08, 0.12, 0.96))
	draw_rect(Rect2(px, py, pw, ph), accent, false, 2.0)
	_s("DRONE SHOP", Vector2(px + 30, py + 52), 34, accent)
	_s("코인  %d" % shop_coins, Vector2(px + pw - 30, py + 50), 26, Color(1, 0.88, 0.45), 2, kfont)
	var y := py + 100.0
	var n := 1
	for it in shop_items:
		var lvl: int = shop_levels[it.id]
		var maxed: bool = lvl >= it.max
		var cost: int = it.base * (lvl + 1)
		_s("[%d]  %s" % [n, it.name], Vector2(px + 30, y + 20), 22, Color(1, 1, 1), 0, kfont)
		_s(it.desc, Vector2(px + 62, y + 46), 15, Color(1, 1, 1, 0.55), 0, kfont)
		for k in it.max:
			draw_rect(Rect2(px + 470 + k * 26, y + 8, 20, 14), accent if k < lvl else Color(1, 1, 1, 0.15))
		var label := "MAX" if maxed else "%d 코인" % cost
		var col := Color(0.6, 0.6, 0.6) if maxed else (Color(1, 0.88, 0.45) if shop_coins >= cost else Color(1, 0.4, 0.4))
		_s(label, Vector2(px + pw - 30, y + 24), 20, col, 2, kfont)
		y += 64.0
		n += 1
	_s("숫자 키로 구매  ·  TAB 닫기", Vector2(px + pw * 0.5, py + ph - 22), 17, Color(1, 1, 1, 0.6), 1, kfont)


func _mmss(t: float) -> String:
	return "%02d:%02d" % [int(t) / 60, int(t) % 60]


func _wrap(a: float) -> float:
	return fposmod(a + 180.0, 360.0) - 180.0
