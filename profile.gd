extends RefCounted
## 저장 슬롯 하나의 모든 진행 데이터: 코인·업그레이드·랭크·목표·기록·발견·설정.

const SLOTS := 3
const XP_TABLE := [0, 100, 260, 480, 760, 1100, 1500, 2000, 2600, 3300]
const RANK_NAMES := ["견습 배달부", "신입 파일럿", "골목 길잡이", "도시 항로사", "베테랑 배달부", "하늘길 장인", "급송 에이스", "구름 위 전문가", "전설의 파일럿", "하늘길의 주인"]

var slot := 1
var data: Dictionary = {}
var dirty_t := 0.0


static func path_of(s: int) -> String:
	return "user://save_%d.json" % s


static func default_data() -> Dictionary:
	return {
		"name": "PILOT", "coins": 0, "total": 0, "missions": 0, "xp": 0, "playtime": 0.0,
		"levels": {"speed": 0, "battery": 0, "gimbal": 0, "signal": 0, "color": 0, "magnet": 0, "zoom": 0, "bounty": 0},
		"settings": {"assist": true, "sens": 1.0, "fov": 88.0, "brightness": 1.0, "volume": 0.8, "music": 0.7, "sfx": 1.0,
			"shake": 1.0, "invert": false, "hud": true, "quality": 2, "colorblind": 0, "minimap": true, "speedlines": true},
		"stats": {}, "goals": {}, "records": {}, "stars": {},
		"frames": {"owned": ["basic"], "equipped": "basic"},
		"skins": {"owned": ["steel"], "equipped": "steel"},
		"secrets": {}, "explored": {}, "inv": {}, "last_mode": "free",
		"tutorial_done": false, "story_seen": false, "keys": {},
	}


static func info(s: int) -> Dictionary:
	var p := path_of(s)
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	return {"xp": int(d.get("xp", 0)), "coins": int(d.get("coins", 0)), "missions": int(d.get("missions", 0)),
		"playtime": float(d.get("playtime", 0.0)), "name": String(d.get("name", "PILOT"))}


func load_slot(s: int) -> void:
	slot = s
	data = default_data()
	var legacy := false
	var p := path_of(s)
	if not FileAccess.file_exists(p) and s == 1 and FileAccess.file_exists("user://save.json"):
		p = "user://save.json"        # 예전 단일 저장 파일을 1번 슬롯으로 가져온다(이미 모든 맵을 날아 본 플레이어라 랭크 5로 시작)
		legacy = true
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			_merge(data, d)
	for k in data.levels.keys():
		data.levels[k] = int(data.levels[k])
	data.coins = int(data.coins)
	data.total = int(data.total)
	data.xp = int(data.xp)
	if legacy:
		data.xp = maxi(data.xp, 760)
		data.tutorial_done = true


## 기본값 위에 저장된 값을 덮는다(새 항목이 추가돼도 옛 저장이 깨지지 않게)
func _merge(base: Dictionary, over: Dictionary) -> void:
	for k in over:
		if base.has(k) and typeof(base[k]) == TYPE_DICTIONARY and typeof(over[k]) == TYPE_DICTIONARY:
			_merge(base[k], over[k])
		else:
			base[k] = over[k]


func save_now() -> void:
	var f := FileAccess.open(path_of(slot), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	dirty_t = 0.0


func erase_slot(s: int) -> void:
	if FileAccess.file_exists(path_of(s)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path_of(s)))


# --- 랭크 ---
func rank() -> int:
	var r := 1
	for i in XP_TABLE.size():
		if data.xp >= XP_TABLE[i]:
			r = i + 1
	return r


func rank_name() -> String:
	return RANK_NAMES[rank() - 1]


## 현재 랭크 구간 안에서의 진행도 0~1 (최고 랭크는 1)
func rank_progress() -> float:
	var r := rank()
	if r >= XP_TABLE.size():
		return 1.0
	var lo: int = XP_TABLE[r - 1]
	var hi: int = XP_TABLE[r]
	return clampf(float(data.xp - lo) / float(hi - lo), 0.0, 1.0)


func xp_to_next() -> int:
	var r := rank()
	return 0 if r >= XP_TABLE.size() else int(XP_TABLE[r]) - int(data.xp)


## 올린 랭크 수를 돌려준다
func add_xp(n: int) -> int:
	var before := rank()
	data.xp += n
	return rank() - before


# --- 통계 ---
func stat(key: String) -> float:
	return float(data.stats.get(key, 0.0))


func add_stat(key: String, n: float) -> void:
	data.stats[key] = float(data.stats.get(key, 0.0)) + n


func set_max_stat(key: String, v: float) -> void:
	if v > float(data.stats.get(key, 0.0)):
		data.stats[key] = v


# --- 해금 ---
const MAP_RANK := {"city": 1, "farm": 2, "alpine": 3, "mars": 5}
const FRAME_RANK := {"basic": 1, "cargo": 2, "racer": 3, "camera": 4}


func map_unlocked(id: String) -> bool:
	return rank() >= int(MAP_RANK.get(id, 1))


func frame_unlocked(id: String) -> bool:
	return rank() >= int(FRAME_RANK.get(id, 1))


# --- 기록·별 ---
func record_time(key: String, t: float) -> bool:
	var best := float(data.records.get(key, 0.0))
	if best <= 0.0 or t < best:
		data.records[key] = t
		return true
	return false


func record_stars(key: String, n: int) -> void:
	if n > int(data.stars.get(key, 0)):
		data.stars[key] = n


func total_stars() -> int:
	var n := 0
	for k in data.stars:
		n += int(data.stars[k])
	return n
