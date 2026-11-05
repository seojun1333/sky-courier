extends RefCounted
## 목표(업적) 목록. 통계(stat) 값이 target에 닿으면 보상을 받을 수 있다.

const LIST := [
	{"id": "first_flight", "name": "첫 이륙", "desc": "처음 하늘로 떠오르기", "stat": "flights", "target": 1, "coins": 20, "xp": 20},
	{"id": "coins_50", "name": "푼돈 모으기", "desc": "코인 50개 줍기", "stat": "coin_pick", "target": 50, "coins": 40, "xp": 30},
	{"id": "coins_500", "name": "코인 부자", "desc": "코인 500개 줍기", "stat": "coin_pick", "target": 500, "coins": 200, "xp": 120},
	{"id": "ring_10", "name": "링 수집가", "desc": "링 10개 통과", "stat": "rings", "target": 10, "coins": 40, "xp": 40},
	{"id": "ring_100", "name": "관문 돌파자", "desc": "링 100개 통과", "stat": "rings", "target": 100, "coins": 250, "xp": 160},
	{"id": "mission_1", "name": "첫 배송", "desc": "미션 1회 완료", "stat": "missions", "target": 1, "coins": 40, "xp": 40},
	{"id": "mission_10", "name": "단골 배달부", "desc": "미션 10회 완료", "stat": "missions", "target": 10, "coins": 200, "xp": 150},
	{"id": "deliver_3", "name": "믿음직한 손", "desc": "택배 배달 3회 성공", "stat": "deliveries", "target": 3, "coins": 90, "xp": 70},
	{"id": "photo_3", "name": "하늘 사진가", "desc": "사진 미션 3회 성공", "stat": "photos", "target": 3, "coins": 90, "xp": 70},
	{"id": "landing_2", "name": "부드러운 착지", "desc": "정밀 착륙 2회 성공", "stat": "landings", "target": 2, "coins": 80, "xp": 60},
	{"id": "dist_5", "name": "5km 비행", "desc": "누적 5km 날기", "stat": "dist_km", "target": 5, "coins": 60, "xp": 50},
	{"id": "dist_50", "name": "50km 비행", "desc": "누적 50km 날기", "stat": "dist_km", "target": 50, "coins": 300, "xp": 200},
	{"id": "secret_3", "name": "호기심 많은 배달부", "desc": "숨겨진 상자 3개 찾기", "stat": "secrets", "target": 3, "coins": 100, "xp": 80},
	{"id": "secret_12", "name": "비밀 수집가", "desc": "숨겨진 상자 12개 찾기", "stat": "secrets", "target": 12, "coins": 350, "xp": 250},
	{"id": "stars_10", "name": "별 10개", "desc": "미션 별 합계 10개", "stat": "stars", "target": 10, "coins": 150, "xp": 120},
	{"id": "night_5", "name": "밤하늘 비행", "desc": "밤에 5분 이상 날기", "stat": "night_min", "target": 5, "coins": 80, "xp": 60},
	{"id": "rain_3", "name": "비 오는 날의 배달", "desc": "악천후에서 3분 이상 날기", "stat": "storm_min", "target": 3, "coins": 90, "xp": 70},
	{"id": "kill_5", "name": "첫 사냥", "desc": "적 5마리 격추·사냥", "stat": "kills", "target": 5, "coins": 80, "xp": 60},
	{"id": "kill_50", "name": "하늘의 사냥꾼", "desc": "적 50마리 격추·사냥", "stat": "kills", "target": 50, "coins": 400, "xp": 250},
	{"id": "boss_1", "name": "거물 사냥", "desc": "보스급 적 1체 처치", "stat": "boss_kills", "target": 1, "coins": 300, "xp": 200},
	{"id": "sell_500", "name": "수완 좋은 상인", "desc": "전리품 판매로 500코인 벌기", "stat": "sold_coins", "target": 500, "coins": 150, "xp": 100},
	{"id": "maps_4", "name": "세계 일주", "desc": "네 개의 맵 모두 방문", "stat": "maps_visited", "target": 4, "coins": 200, "xp": 150},
]


static func by_id(id: String) -> Dictionary:
	for g in LIST:
		if g.id == id:
			return g
	return {}


static func progress(p: RefCounted, g: Dictionary) -> float:
	return minf(float(p.stat(g.stat)), float(g.target))


static func ready(p: RefCounted, g: Dictionary) -> bool:
	return not p.data.goals.get(g.id, false) and float(p.stat(g.stat)) >= float(g.target)


static func ready_count(p: RefCounted) -> int:
	var n := 0
	for g in LIST:
		if ready(p, g):
			n += 1
	return n
