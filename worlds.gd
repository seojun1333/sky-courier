extends RefCounted
## 맵(월드) 프로필: 지형 종류, 하늘, 안개, 조명, 스폰 위치.

static func all() -> Array:
	return [
		{
			"id": "city", "kind": "city", "name": "도시 외곽 ~ 도심",
			"desc": "도로와 가로등, 달리는 차들, 폐모텔·폐상가·폐아파트, 그리고 멀리 보이는 초고층 빌딩 숲.",
			"home": Vector2(80, 80), "radius": 9, "water": false, "night": 0.7, "start_hour": 17.4,
			"day_sky": {"top": Vector3(0.17, 0.32, 0.62), "mid": Vector3(0.50, 0.65, 0.84), "hor": Vector3(0.86, 0.82, 0.78)},
			"sky": {"top": Vector3(0.10, 0.17, 0.42), "mid": Vector3(0.50, 0.42, 0.56), "hor": Vector3(1.0, 0.56, 0.30), "gnd": Vector3(0.22, 0.20, 0.24),
				"clouds": 0.7, "sun_col": Vector3(1.0, 0.6, 0.3), "sun_size": 1800.0},
			"sun_rot": Vector3(-9, -62, 0), "sun_color": Color(1.0, 0.6, 0.34), "sun_energy": 1.25,
			"ambient": 0.6, "fog_color": Color(0.80, 0.56, 0.48), "fog_density": 0.0009,
		},
		{
			"id": "alpine", "kind": "alpine", "name": "알프스 호수",
			"desc": "산, 호수, 숲 위를 나는 대자연 여행. 어딘가에 폐건물이 숨어 있습니다.",
			"home": Vector2(0, 0), "radius": 11, "water": true, "night": 0.0, "start_hour": 10.0,
			"sky": {"top": Vector3(0.14, 0.31, 0.66), "mid": Vector3(0.42, 0.60, 0.84), "hor": Vector3(0.84, 0.77, 0.70), "gnd": Vector3(0.30, 0.30, 0.34),
				"clouds": 1.0, "sun_col": Vector3(1.0, 0.85, 0.6), "sun_size": 2500.0},
			"sun_rot": Vector3(-24, -38, 0), "sun_color": Color(1.0, 0.92, 0.80), "sun_energy": 1.45,
			"ambient": 0.62, "fog_color": Color(0.70, 0.74, 0.82), "fog_density": 0.00055,
		},
		{
			"id": "farm", "kind": "farm", "name": "시골 농장",
			"desc": "끝없이 이어진 들판과 농가, 사일로, 비포장길. 느긋하게 풍경을 즐기는 비행.",
			"home": Vector2(0, 0), "radius": 11, "water": false, "night": 0.0, "start_hour": 14.0,
			"sky": {"top": Vector3(0.20, 0.42, 0.78), "mid": Vector3(0.55, 0.72, 0.92), "hor": Vector3(0.92, 0.88, 0.80), "gnd": Vector3(0.35, 0.38, 0.30),
				"clouds": 1.0, "sun_col": Vector3(1.0, 0.9, 0.7), "sun_size": 2500.0},
			"sun_rot": Vector3(-38, -30, 0), "sun_color": Color(1.0, 0.95, 0.85), "sun_energy": 1.15,
			"ambient": 0.5, "fog_color": Color(0.74, 0.80, 0.88), "fog_density": 0.0003,
		},
		{
			"id": "mars", "kind": "mars", "name": "화성",
			"desc": "붉은 사막, 운석 구덩이, 깊은 협곡. 버려진 기지와 로버가 흩어져 있습니다.",
			"home": Vector2(0, 0), "radius": 11, "water": false, "night": 0.0, "start_hour": 14.0,
			"sky": {"top": Vector3(0.36, 0.26, 0.22), "mid": Vector3(0.70, 0.48, 0.34), "hor": Vector3(0.86, 0.62, 0.45), "gnd": Vector3(0.45, 0.26, 0.18),
				"clouds": 0.0, "sun_col": Vector3(0.8, 0.85, 1.0), "sun_size": 6000.0},
			"sun_rot": Vector3(-30, -50, 0), "sun_color": Color(1.0, 0.82, 0.68), "sun_energy": 1.35,
			"ambient": 0.55, "fog_color": Color(0.80, 0.52, 0.38), "fog_density": 0.0007,
		},
	]


static func find(id: String) -> Dictionary:
	for w in all():
		if w.id == id:
			return w
	return all()[0]
