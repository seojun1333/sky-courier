extends RefCounted
## 세계관과 문구. 게임 안의 모든 말투는 여기서 정한다.
## 설정: 도로가 늘 막히는 바쁜 도시, 낡은 드론 한 대로 하늘길 배송을 이어 가는 배달부와 관제 요원 '노을'.

const TITLE := "SKY COURIER"
const TITLE_KO := "하늘길 배달부"
const TAGLINE := "길이 막히면, 하늘로 간다"

const INTRO := [
	"도시는 오늘도 바쁘게 돌아갑니다. 막히는 도로, 늦어지는 택배.",
	"하지만 하늘은 언제나 비어 있죠.",
	"낡은 드론 한 대와, 기다리는 사람들. 오늘의 배송이 시작됩니다.",
	"관제 노을: 「배달부님, 이륙 준비되셨죠? 첫 하늘길은 제가 열어 둘게요.」",
]

const MAP_TAGLINE := {
	"city": "막히는 도로 위로 — 가장 바쁜 하늘길",
	"farm": "끝없는 들판, 느긋한 급송 구간",
	"alpine": "호수와 능선 사이의 외딴 배송지",
	"mars": "지구 밖 기지로 가는 마지막 우편",
}

const MISSION_NAMES := {
	"ring": "항로 개척", "delivery": "급송 배달", "photo": "하늘 사진관", "landing": "정밀 착륙",
}
const MISSION_DESC := {
	"ring": "표시된 관문 링을 순서대로 통과하세요. 통과할 때마다 시간이 늘어납니다.",
	"delivery": "소포를 싣고 목적지에 떨어뜨리세요. 추락하면 소포가 망가집니다.",
	"photo": "표식을 화면 한가운데에 두고 셔터를 누르세요. 너무 멀면 흐릿하게 찍힙니다.",
	"landing": "표시된 패드 위에 부드럽게 착륙하세요. 속도를 줄이고 수평을 맞추세요.",
}

# 상점·격납고 이름
const UPGRADE_NAMES := {
	"speed": ["고출력 모터", "추력과 최고 속도"],
	"battery": ["장거리 배터리", "비행 시간 연장"],
	"gimbal": ["삼축 짐벌", "카메라 흔들림 보정"],
	"signal": ["중계 안테나", "조종 가능 거리"],
	"color": ["야간 식별등", "LED 색 변경"],
	"magnet": ["코인 흡착기", "코인을 더 멀리서 끌어옴"],
	"zoom": ["망원 렌즈", "우클릭으로 확대 — 배율 증가"],
	"bounty": ["배송 수수료 협상", "미션 보상 +25% (단계당)"],
}

const FRAMES := {
	"basic": {"id": "basic", "name": "스파로 V1", "desc": "누구나 처음 타는 기본 쿼드콥터. 무난하고 튼튼하다.", "cost": 0,
		"speed": 1.0, "battery": 1.0, "gimbal": 0, "zoom": 0, "reward": 1.0, "hp": 100},
	"cargo": {"id": "cargo", "name": "헤비 카고", "desc": "6개 프로펠러와 화물칸. 느리지만 오래 나고 맷집이 좋다. 배송 보상 +30%.", "cost": 400,
		"speed": 0.88, "battery": 1.4, "gimbal": 0, "zoom": 0, "reward": 1.3, "hp": 160},
	"racer": {"id": "racer", "name": "스트릭 레이서", "desc": "카본 프레임의 레이싱 기체. 빠르고 날카롭지만 배터리와 장갑이 약하다.", "cost": 700,
		"speed": 1.28, "battery": 0.78, "gimbal": 0, "zoom": 0, "reward": 1.0, "hp": 70},
	"camera": {"id": "camera", "name": "아이리스 촬영기", "desc": "접이식 암과 대형 짐벌 카메라. 안정적이고 줌이 강하다.", "cost": 900,
		"speed": 0.94, "battery": 1.1, "gimbal": 2, "zoom": 1, "reward": 1.0, "hp": 90},
}

const SKINS := {
	"steel": {"name": "스틸 그레이", "cost": 0, "color": Color(0.16, 0.17, 0.2), "accent": Color(0.23, 0.86, 1.0), "metal": 0.5, "rough": 0.35},
	"crimson": {"name": "크림슨", "cost": 150, "color": Color(0.55, 0.08, 0.1), "accent": Color(1.0, 0.85, 0.3), "metal": 0.3, "rough": 0.3},
	"ocean": {"name": "오션 블루", "cost": 150, "color": Color(0.08, 0.28, 0.6), "accent": Color(0.9, 0.97, 1.0), "metal": 0.3, "rough": 0.3},
	"forest": {"name": "포레스트", "cost": 150, "color": Color(0.1, 0.4, 0.22), "accent": Color(0.85, 0.75, 0.4), "metal": 0.1, "rough": 0.7},
	"sakura": {"name": "사쿠라", "cost": 250, "color": Color(0.93, 0.62, 0.74), "accent": Color(1.0, 1.0, 1.0), "metal": 0.1, "rough": 0.4},
	"hazard": {"name": "하자드", "cost": 300, "color": Color(0.95, 0.75, 0.05), "accent": Color(0.06, 0.06, 0.06), "metal": 0.1, "rough": 0.5},
	"gold": {"name": "골드 러시", "cost": 500, "color": Color(0.8, 0.62, 0.12), "accent": Color(0.15, 0.1, 0.02), "metal": 1.0, "rough": 0.18},
	"ghost": {"name": "고스트 화이트", "cost": 500, "color": Color(0.85, 0.87, 0.9), "accent": Color(0.3, 0.55, 1.0), "metal": 0.2, "rough": 0.25},
	"stealth": {"name": "스텔스 블랙", "cost": 600, "color": Color(0.03, 0.03, 0.035), "accent": Color(1.0, 0.1, 0.12), "metal": 0.8, "rough": 0.55, "glow": true},
	"neon": {"name": "네온 시티", "cost": 700, "color": Color(0.06, 0.04, 0.12), "accent": Color(1.0, 0.2, 0.85), "metal": 0.6, "rough": 0.25, "glow": true},
}
const RADIO := {
	"takeoff": ["관제 노을: 「이륙 확인. 바람 좋네요.」", "관제 노을: 「시야 양호. 안전 비행하세요!」"],
	"low_battery": ["관제 노을: 「배터리 경고! 귀환 경로를 잡으세요.」"],
	"rank_up": ["관제 노을: 「랭크 상승! 이제 더 먼 하늘길도 열려요.」"],
	"crash": ["관제 노을: 「신호 끊김… 기체 회수합니다. 괜찮아요, 다시 가요.」"],
	"rain": ["관제 노을: 「비가 옵니다. 시야와 바람에 주의하세요.」"],
	"storm": ["관제 노을: 「뇌우 접근 중. 가능하면 낮게 나세요.」"],
	"dust": ["관제 노을: 「먼지 폭풍이에요. 시야가 급격히 줄어들어요.」"],
	"night": ["관제 노을: 「해가 졌어요. 식별등을 믿고 날아요.」"],
	"dawn": ["관제 노을: 「동이 트네요. 오늘도 수고했어요.」"],
	"secret": ["관제 노을: 「어? 방금 그거… 누군가의 비밀 상자였나 봐요!」"],
	"photo_ok": ["관제 노을: 「좋은 컷이에요!」"],
	"mission_done": ["관제 노을: 「배송 완료! 깔끔했어요.」"],
}


static func radio(key: String) -> String:
	var arr: Array = RADIO.get(key, [])
	return "" if arr.is_empty() else String(arr[randi() % arr.size()])


static func stars_text(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(3 - n)
