extends RefCounted
## 전리품 목록. 적을 쓰러뜨리면 떨어지고, 보관함에서 코인으로 판다.
## tier: 1 흔함 / 2 쓸만함 / 3 귀함 / 4 전설

const ITEMS := {
	"gel": {"name": "슬라임 젤", "price": 14, "tier": 1, "color": Color(0.45, 0.95, 0.4), "desc": "끈적하고 말랑한 젤. 연구소에서 찾는다."},
	"bat_wing": {"name": "박쥐 날개막", "price": 24, "tier": 1, "color": Color(0.6, 0.35, 0.55), "desc": "질긴 가죽막. 우산 공방이 좋아한다."},
	"fang": {"name": "날카로운 송곳니", "price": 48, "tier": 2, "color": Color(0.95, 0.93, 0.82), "desc": "상처 하나 없이 빛나는 이빨."},
	"rock_shard": {"name": "마력 암석 조각", "price": 70, "tier": 2, "color": Color(0.75, 0.55, 0.35), "desc": "안쪽에서 희미하게 빛나는 돌."},
	"golem_core": {"name": "골렘 핵", "price": 240, "tier": 3, "color": Color(1.0, 0.55, 0.15), "desc": "아직 따뜻하다. 수집가들이 웃돈을 낸다."},
	"wyvern_scale": {"name": "와이번 비늘", "price": 170, "tier": 3, "color": Color(0.3, 0.8, 0.7), "desc": "가볍고 단단한 푸른 비늘."},
	"fire_gland": {"name": "불꽃샘", "price": 380, "tier": 3, "color": Color(1.0, 0.4, 0.2), "desc": "건드리면 뜨거운 와이번의 분비샘."},
	"void_shard": {"name": "공허 결정", "price": 520, "tier": 4, "color": Color(0.7, 0.4, 1.0), "desc": "들여다보면 시선이 빨려 들어간다."},
	"eye_lens": {"name": "공허의 눈알", "price": 900, "tier": 4, "color": Color(0.95, 0.3, 0.55), "desc": "아직도 이쪽을 보고 있다."},
	"scrap": {"name": "고철 부품", "price": 18, "tier": 1, "color": Color(0.7, 0.72, 0.78), "desc": "격추한 드론의 잔해."},
	"circuit": {"name": "전자 회로", "price": 45, "tier": 2, "color": Color(0.3, 0.9, 0.55), "desc": "쓸 만한 제어 기판."},
	"power_cell": {"name": "고출력 셀", "price": 130, "tier": 3, "color": Color(0.35, 0.8, 1.0), "desc": "군용 규격 배터리 셀."},
	"ace_chip": {"name": "에이스 칩", "price": 420, "tier": 4, "color": Color(1.0, 0.82, 0.3), "desc": "적 에이스 기체의 전투 AI 칩."},
}

const TIER_NAMES := ["", "일반", "고급", "희귀", "전설"]
const TIER_COLORS := [Color.WHITE, Color(0.8, 0.85, 0.9), Color(0.4, 0.85, 1.0), Color(0.8, 0.5, 1.0), Color(1.0, 0.75, 0.25)]


static func info(id: String) -> Dictionary:
	return ITEMS.get(id, {"name": id, "price": 1, "tier": 1, "color": Color.WHITE, "desc": ""})


static func total_value(inv: Dictionary) -> int:
	var v := 0
	for id in inv:
		v += int(inv[id]) * int(info(id).price)
	return v
