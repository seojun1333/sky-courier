extends Node3D
## SKY COURIER — 타이틀·로비·월드·진행·연출을 이어 붙이는 중심 스크립트.

const TerrainScript := preload("res://terrain.gd")
const DroneScript := preload("res://drone.gd")
const CoinsScript := preload("res://coins.gd")
const HudScript := preload("res://hud.gd")
const AudioScript := preload("res://audio.gd")
const BirdsScript := preload("res://birds.gd")
const PeopleScript := preload("res://people.gd")
const BuildingsScript := preload("res://buildings.gd")
const WorldsScript := preload("res://worlds.gd")
const PropsScript := preload("res://props.gd")
const TrafficScript := preload("res://traffic.gd")
const MissionsScript := preload("res://missions.gd")
const ProfileScript := preload("res://profile.gd")
const StoryScript := preload("res://story.gd")
const GoalsScript := preload("res://goals.gd")
const KeysScript := preload("res://keys.gd")
const UI := preload("res://ui.gd")
const UiAudioScript := preload("res://ui_audio.gd")
const TitleScript := preload("res://title.gd")
const IntroScript := preload("res://intro.gd")
const LobbyScript := preload("res://lobby.gd")
const PauseScript := preload("res://pause.gd")
const MissionMenuScript := preload("res://mission_menu.gd")
const DayNightScript := preload("res://daynight.gd")
const SecretsScript := preload("res://secrets.gd")
const MinimapScript := preload("res://minimap.gd")
const TutorialScript := preload("res://tutorial.gd")
const FxScript := preload("res://fx.gd")
const CombatScript := preload("res://combat.gd")
const InventoryScript := preload("res://inventory_panel.gd")
const ItemsScript := preload("res://items.gd")

const UPGRADES := [
	{"id": "speed", "max": 5, "base": 150},
	{"id": "battery", "max": 5, "base": 100},
	{"id": "gimbal", "max": 4, "base": 200},
	{"id": "signal", "max": 4, "base": 200},
	{"id": "color", "max": 5, "base": 100},
	{"id": "magnet", "max": 4, "base": 120},
	{"id": "zoom", "max": 3, "base": 150},
	{"id": "bounty", "max": 4, "base": 180},
]
const TIPS := [
	"링을 통과할 때마다 제한 시간이 4초 늘어납니다.",
	"도시의 신호등은 규칙대로 움직여요. 차 위로 낮게 날면 부딪힙니다.",
	"비행 보조(F)를 켜면 키를 뗄 때 기체가 바로 멈춥니다.",
	"숨겨진 상자는 교차로 위 높은 곳이나 외딴 능선에 있어요.",
	"밤에는 식별등이 켜지고 도시의 불빛이 살아납니다.",
	"M 키로 전체 지도를 볼 수 있고, 가 본 곳만 밝아집니다.",
	"사진 미션은 표식을 화면 가운데에 두고 셔터(P)를 누르세요.",
	"배터리가 20% 아래로 내려가면 귀환(R)을 서두르세요.",
	"전투 모드: 적을 십자선 가운데에 두면 록온됩니다. 록온 뒤 G 키로 유도탄을 쏘세요.",
	"탄창과 유도탄은 하늘에 떠 있어요. 한 번 먹으면 30초 뒤에 다시 생깁니다.",
	"괴물이 떨어뜨린 전리품은 보관함(I)에서 코인으로 팔 수 있어요.",
	"기지 위에 착륙하면 체력과 탄약이 채워집니다.",
]

var profile: RefCounted
var save: Dictionary                 # profile.data 와 같은 딕셔너리
var ui_audio: Node
var title_ui: Control
var lobby_ui: Control
var terrain: Node3D
var drone: Node3D
var coins: Node3D
var hud: Control
var audio: Node
var birds: Node3D
var people: Node3D
var buildings: Node3D
var traffic: Node3D
var missions: Node3D
var secrets: Node3D
var minimap: Control
var tutorial: Node
var daynight: Node
var fx: Node
var combat: Node3D
var game_mode := "free"              # free | duel | hunt
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var world := {}
var world_started := false
var no_assist := false
var lamp: SpotLight3D
var fx_mat: ShaderMaterial
var paused := false
var pause_ui: Control
var modal_ui: Control
var rec_time := 0.0
var flash := 0.0
var lightning_f := 0.0
var low_beep_t := 0.0
var frame_i := 0
var autosave_t := 0.0
var last_state := "idle"
var last_odo := 0.0
var dist_xp := 0.0
var was_night := false
var tutorial_hint_t := 0.0
var slowmo_guard := 0.0
var cursor_msg_t := 0.0
# 개발용 인자
var shot_dir := ""
var fly_test := false
var quick := false
var lineup_test := false
var thumb_path := ""
var pshot_dir := ""
var traffic_sim := false
var tshot := false
var cshot := false
var mtest := false
var selftest := false
var shot_out := ""
var tsim_t := 0.0
var tsim_log := 0.0


func _ready() -> void:
	Engine.time_scale = 1.0
	DisplayServer.window_set_title("SKY COURIER — 하늘길 배달부")
	RenderingServer.global_shader_parameter_add("night_f", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	ui_audio = UiAudioScript.new()
	add_child(ui_audio)
	UI.sfx = ui_audio
	profile = ProfileScript.new()
	var pick := ""
	var lobbyshot := ""
	var titleshot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_dir = a.substr(7)
		elif a == "--flytest":
			fly_test = true
		elif a == "--noassist":
			no_assist = true
		elif a == "--quick":
			quick = true
		elif a == "--lineup":
			lineup_test = true
		elif a.begins_with("--selftest"):
			selftest = true
			shot_out = a.substr(11) if a.length() > 11 else ""
		elif a.begins_with("--world="):
			pick = a.substr(8)
		elif a.begins_with("--mtest="):
			pshot_dir = a.substr(8)
			mtest = true
		elif a.begins_with("--tshot="):
			pshot_dir = a.substr(8)
			tshot = true
		elif a.begins_with("--combat="):
			game_mode = a.substr(9)
		elif a.begins_with("--cshot="):
			pshot_dir = a.substr(8)
			cshot = true
		elif a == "--trafficsim":
			traffic_sim = true
		elif a.begins_with("--pshot="):
			pshot_dir = a.substr(8)
		elif a.begins_with("--thumb="):
			thumb_path = a.substr(8)
		elif a.begins_with("--lobbyshot="):
			lobbyshot = a.substr(12)
		elif a.begins_with("--titleshot="):
			titleshot = a.substr(12)
	var dev := shot_dir != "" or fly_test or thumb_path != "" or pshot_dir != "" or selftest or lineup_test
	if pick == "" and (shot_dir != "" or fly_test):
		pick = "alpine"
	if pick != "" or lobbyshot != "":
		profile.load_slot(1)
		_adopt_profile()
		if dev:
			profile.data.tutorial_done = true
		if pick != "":
			_start_world(pick)
		else:
			_show_lobby()
			_lobby_shots(lobbyshot)
		return
	if titleshot != "":
		_show_title()
		await get_tree().create_timer(2.5).timeout
		get_viewport().get_texture().get_image().save_png(titleshot.path_join("title.png"))
		get_tree().quit()
		return
	if Engine.has_meta("skip_title"):
		var s: int = int(Engine.get_meta("skip_title"))
		Engine.remove_meta("skip_title")
		profile.load_slot(s)
		_adopt_profile()
		_show_lobby()
	else:
		_show_title()


func _adopt_profile() -> void:
	save = profile.data
	if OS.get_cmdline_user_args().is_empty():
		game_mode = String(save.get("last_mode", "free"))
	KeysScript.setup(save.keys)
	apply_settings()


# ---------------------------------------------------------------- 화면 흐름
func _layer(n: int) -> CanvasLayer:
	var l := CanvasLayer.new()
	l.layer = n
	add_child(l)
	return l


func _show_title() -> void:
	var layer := _layer(5)
	title_ui = TitleScript.new()
	title_ui.slot_chosen.connect(_on_slot.bind(layer))
	layer.add_child(title_ui)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui_audio.music.play("title")


func _on_slot(s: int, layer: CanvasLayer) -> void:
	profile.load_slot(s)
	_adopt_profile()
	ui_audio.confirm()
	layer.queue_free()
	title_ui = null
	if not save.story_seen:
		var l2 := _layer(6)
		var intro: Control = IntroScript.new()
		l2.add_child(intro)
		intro.finished.connect(func() -> void:
			save.story_seen = true
			profile.save_now()
			l2.queue_free()
			_show_lobby())
	else:
		_show_lobby()


func _show_lobby() -> void:
	var layer := _layer(5)
	lobby_ui = LobbyScript.new()
	lobby_ui.main = self
	lobby_ui.picked.connect(_begin_world)
	lobby_ui.to_title.connect(func() -> void:
		profile.save_now()
		get_tree().reload_current_scene())
	layer.add_child(lobby_ui)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui_audio.music.play("title")


## 로딩 화면을 먼저 한 번 그려 주고 월드를 만든다(생성 중에는 화면이 멈추기 때문)
func _begin_world(id: String) -> void:
	if world_started:
		return
	ui_audio.start()
	var layer := _layer(30)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	cc.add_child(v)
	var wd: Dictionary = WorldsScript.find(id)
	var t1 := UI.label(String(wd.name), 54, UI.TEXT, "title")
	t1.theme = UI.theme()
	v.add_child(t1)
	v.add_child(UI.label("하늘길을 여는 중…", 22, UI.ACCENT, "head"))
	v.add_child(UI.label("TIP  " + String(TIPS[randi() % TIPS.size()]), 16, UI.DIM))
	await get_tree().process_frame
	await get_tree().process_frame
	if lobby_ui != null:
		lobby_ui.get_parent().queue_free()
		lobby_ui = null
	_start_world(id)
	await get_tree().process_frame
	layer.queue_free()


# ---------------------------------------------------------------- 월드 시작
func _start_world(id: String) -> void:
	if world_started:
		return
	world = WorldsScript.find(id)
	world_started = true
	if lobby_ui != null:
		lobby_ui.get_parent().queue_free()
		lobby_ui = null
	_make_environment()

	terrain = TerrainScript.new()
	terrain.profile = world
	var deco: RefCounted = null
	match String(world.kind):
		"farm", "mars":
			deco = PropsScript.new(world.kind)
		"city":
			deco = load("res://city.gd").new()
	if deco != null:
		deco.terrain = terrain
		terrain.decorator = deco
	add_child(terrain)
	drone = DroneScript.new()
	drone.terrain = terrain
	add_child(drone)
	drone.setup()
	drone.crashed.connect(_on_crashed)
	coins = CoinsScript.new()
	coins.terrain = terrain
	coins.kind = world.kind
	add_child(coins)
	audio = AudioScript.new()
	add_child(audio)
	birds = BirdsScript.new()
	birds.terrain = terrain
	birds.audio = audio
	birds.enabled = world.kind != "mars"
	add_child(birds)
	people = PeopleScript.new()
	people.terrain = terrain
	people.kind = world.kind
	people.enabled = world.kind != "mars"
	add_child(people)
	buildings = BuildingsScript.new()
	buildings.terrain = terrain
	buildings.audio = audio
	buildings.spawn_ruins = world.kind == "alpine" or world.kind == "farm"
	add_child(buildings)
	if deco != null:
		deco.buildings = buildings
	if world.kind == "city":
		traffic = TrafficScript.new()
		add_child(traffic)
		drone.traffic = traffic
		people.traffic = traffic
	drone.buildings = buildings
	fx = FxScript.new()
	add_child(fx)

	missions = MissionsScript.new()
	missions.terrain = terrain
	missions.drone = drone
	missions.profile = profile
	missions.world_id = world.id
	missions.kind_world = world.kind
	add_child(missions)
	missions.completed.connect(_on_mission_done)
	missions.failed.connect(_on_mission_failed)
	missions.progress.connect(_on_mission_progress)
	missions.photo_taken.connect(_on_photo_taken)

	secrets = SecretsScript.new()
	add_child(secrets)
	secrets.setup(terrain, world, profile)
	secrets.found.connect(_on_secret)

	lamp = SpotLight3D.new()
	lamp.spot_range = 34.0
	lamp.spot_angle = 44.0
	lamp.light_energy = 0.0
	lamp.light_color = Color(1.0, 0.97, 0.9)
	drone.cam.add_child(lamp)
	_make_screen_layers()

	daynight = DayNightScript.new()
	add_child(daynight)
	daynight.setup(env, sun, sky_mat, world, deco, drone.cam)
	daynight.weather_changed.connect(_on_weather)
	daynight.lightning.connect(_on_lightning)

	minimap = MinimapScript.new()
	hud.get_parent().add_child(minimap)
	minimap.drone_pos = drone.position
	minimap.setup(terrain, world, profile)

	tutorial = TutorialScript.new()
	add_child(tutorial)
	tutorial.setup(drone, missions, terrain, profile)
	tutorial.finished.connect(_on_tutorial_done)

	if game_mode != "free":
		combat = CombatScript.new()
		add_child(combat)
		combat.setup(self)
		combat.reward.connect(_on_combat_reward)
		tutorial.skip()
	_apply_upgrades()
	apply_settings()
	terrain.update(drone.position, 6000.0)
	profile.add_stat("visited_" + String(world.id), 1.0)
	var visited := 0
	for w in WorldsScript.all():
		if profile.stat("visited_" + String(w.id)) > 0.0:
			visited += 1
	profile.data.stats["maps_visited"] = float(visited)
	ui_audio.music.play("battle" if combat != null else String(world.kind))
	if combat != null:
		hud.show_radio("관제 노을: 「%s」" % ("적 드론이 접근 중이에요. 기관포 [좌클릭/J], 유도탄 [G] — 적을 가운데에 두면 록온돼요." if game_mode == "duel" else "이 구역에 괴물이 출몰해요. 하늘에 뜬 탄창을 챙기고, 전리품은 보관함에서 팔 수 있어요."), 9.0)
	if not (shot_dir != "" or fly_test or thumb_path != "" or pshot_dir != "" or selftest):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if save.tutorial_done:
			hud.show_radio(StoryScript.radio("takeoff"), 5.0)
		else:
			hud.show_radio("관제 노을: 「처음이시죠? 화면 위쪽 안내를 한 단계씩 따라 해 보세요.」", 8.0)


func _make_environment() -> void:
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://sky.gdshader")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = world.ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.fog_enabled = true
	env.fog_light_color = world.fog_color
	env.fog_density = world.fog_density
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.25
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = world.sun_rot
	sun.light_color = world.sun_color
	sun.light_energy = world.sun_energy
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 600.0
	add_child(sun)


func _make_screen_layers() -> void:
	var fx_layer := _layer(1)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = load("res://camera_fx.gdshader")
	rect.material = fx_mat
	fx_layer.add_child(rect)
	var hud_layer := _layer(2)
	hud = HudScript.new()
	hud_layer.add_child(hud)
	hud.shop_items = []


func _apply_upgrades() -> void:
	coins.pick_r2 = pow(3.0 + 4.0 * int(save.levels.magnet), 2.0)
	drone.lv = save.levels
	var fid: String = save.frames.equipped
	var skin: String = save.skins.equipped
	drone.set_frame(StoryScript.FRAMES[fid], StoryScript.SKINS[skin])
	missions.frame_reward = float(StoryScript.FRAMES[fid].reward)
	drone.apply_led()
	hud.accent = drone.led_color()


# ---------------------------------------------------------------- 저장·구매·설정
func save_now() -> void:
	if minimap != null:
		minimap.flush()
	profile.save_now()


func write_save() -> void:
	autosave_t = 0.0
	save_now()


func cost_of(i: int) -> int:
	var it: Dictionary = UPGRADES[i]
	return int(it.base) * (int(save.levels[it.id]) + 1)


func buy(i: int) -> bool:
	if i < 0 or i >= UPGRADES.size():
		return false
	var it: Dictionary = UPGRADES[i]
	var lvl: int = save.levels[it.id]
	var cost := cost_of(i)
	if lvl >= it.max or save.coins < cost:
		return false
	save.coins -= cost
	save.levels[it.id] = lvl + 1
	profile.save_now()
	return true


func buy_frame(id: String) -> void:
	var f: Dictionary = StoryScript.FRAMES[id]
	if (save.frames.owned as Array).has(id) or not profile.frame_unlocked(id) or save.coins < int(f.cost):
		ui_audio.error()
		return
	save.coins -= int(f.cost)
	(save.frames.owned as Array).append(id)
	save.frames.equipped = id
	ui_audio.confirm()
	profile.save_now()


func equip_frame(id: String) -> void:
	save.frames.equipped = id
	ui_audio.confirm()
	profile.save_now()


func buy_skin(id: String) -> void:
	var s: Dictionary = StoryScript.SKINS[id]
	if (save.skins.owned as Array).has(id) or save.coins < int(s.cost):
		ui_audio.error()
		return
	save.coins -= int(s.cost)
	(save.skins.owned as Array).append(id)
	save.skins.equipped = id
	ui_audio.confirm()
	profile.save_now()


func equip_skin(id: String) -> void:
	save.skins.equipped = id
	ui_audio.confirm()
	profile.save_now()


func claim_goal(id: String) -> void:
	var g: Dictionary = GoalsScript.by_id(id)
	if g.is_empty() or not GoalsScript.ready(profile, g):
		return
	save.goals[id] = true
	save.coins += int(g.coins)
	save.total += int(g.coins)
	profile.add_xp(int(g.xp))
	ui_audio.jingle()
	profile.save_now()


## 설정 값을 게임에 반영한다(로비·일시정지 화면에서도 호출)
func apply_settings() -> void:
	if save.is_empty():
		return
	var s: Dictionary = save.settings
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(s.volume), 0.0001)))
	ui_audio.set_volumes(float(s.music), float(s.sfx))
	if not world_started:
		return
	env.adjustment_brightness = float(s.brightness)
	drone.mouse_sens = float(s.sens)
	drone.cam_fov = float(s.fov)
	drone.assist = bool(s.assist) and not no_assist
	drone.invert_y = bool(s.invert)
	drone.shake_mul = float(s.shake)
	hud.visible = bool(s.hud)
	minimap.visible = bool(s.minimap)
	fx_mat.set_shader_parameter("cb_mode", int(s.colorblind))
	var q := int(s.quality)
	get_viewport().scaling_3d_scale = [0.7, 0.85, 1.0][q]
	env.ssao_enabled = q >= 2
	env.glow_enabled = q >= 1
	sun.shadow_enabled = q >= 1
	sun.directional_shadow_max_distance = [220.0, 420.0, 650.0][q]


# ---------------------------------------------------------------- 일시정지·메뉴
func _set_pause(open: bool) -> void:
	if open == paused:
		return
	paused = open
	if open:
		pause_ui = PauseScript.new()
		pause_ui.main = self
		pause_ui.resume.connect(_set_pause.bind(false))
		pause_ui.lobby.connect(_to_lobby)
		var layer := _layer(20)
		layer.name = "PauseLayer"
		layer.add_child(pause_ui)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		drone.zoom_held = false
	else:
		if pause_ui != null:
			save_now()
			pause_ui.get_parent().queue_free()
			pause_ui = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _to_lobby() -> void:
	save_now()
	Engine.set_meta("skip_title", profile.slot)
	get_tree().reload_current_scene()


func _open_mission_menu() -> void:
	paused = true
	var layer := _layer(20)
	var m: Control = MissionMenuScript.new()
	m.profile = profile
	m.missions = missions
	m.world_id = world.id
	layer.add_child(m)
	modal_ui = m
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	m.closed.connect(_close_modal.bind(layer))
	m.picked.connect(func(type: String) -> void:
		_close_modal(layer)
		missions.start(type, drone.position, -drone.cam.global_basis.z)
		ui_audio.start()
		hud.show_banner("%s 시작!" % StoryScript.MISSION_NAMES[type], 2.4, UI.ACCENT)
		hud.show_radio("관제 노을: 「%s」" % StoryScript.MISSION_DESC[type], 6.0)
		music_mission(true))


func _close_modal(layer: CanvasLayer) -> void:
	if is_instance_valid(layer):
		layer.queue_free()
	modal_ui = null
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func music_mission(on: bool) -> void:
	ui_audio.music.play("mission" if on else ("battle" if combat != null else String(world.kind)))


func _toggle_map() -> void:
	minimap.full = not minimap.full
	paused = minimap.full
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- 이벤트
func _on_crashed(_reason: String) -> void:
	audio.crash()
	flash = 1.0
	profile.add_stat("crashes", 1.0)
	hud.show_radio(StoryScript.radio("crash"), 5.0)
	missions.fail("추락으로 미션 실패")
	if combat != null:
		combat.on_player_down()
		if _reason == "SHOT DOWN":
			hud.show_banner("격추당했다!", 2.5, Color(1.0, 0.35, 0.3))


## 처치·웨이브 보상을 받는다(코인·경험치·통계). 전리품은 주워야 보관함에 들어간다.
func _on_combat_reward(info: Dictionary) -> void:
	var c: int = int(info.coins)
	save.coins += c
	save.total += c
	if not bool(info.get("wave", false)):
		profile.add_stat("kills", 1.0)
		if bool(info.get("boss", false)):
			profile.add_stat("boss_kills", 1.0)
		var txt := "%s 처치!  +%d 코인" % [info.name, c]
		hud.show_toast(txt, 2.2, Color(1.0, 0.85, 0.4))
	else:
		hud.show_toast("%s  보너스 +%d 코인" % [info.name, c], 3.0, Color(0.5, 1.0, 0.6))
	_gain_xp(int(info.xp))


## 주운 전리품을 보관함에 넣는다
func add_loot(id: String, n: int) -> void:
	save.inv[id] = int(save.inv.get(id, 0)) + n
	profile.add_stat("loot", float(n))


func _open_inventory() -> void:
	paused = true
	var layer := _layer(20)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var mg := MarginContainer.new()
	mg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		mg.add_theme_constant_override("margin_" + side, 160)
	mg.add_theme_constant_override("margin_top", 70)
	mg.add_theme_constant_override("margin_bottom", 70)
	layer.add_child(mg)
	var inv: Control = InventoryScript.new()
	mg.add_child(inv)
	inv.setup(self, true)
	modal_ui = inv
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	inv.closed.connect(_close_modal.bind(layer))


func _gain_xp(n: int) -> void:
	var up: int = profile.add_xp(n)
	if up > 0:
		ui_audio.rank()
		hud.show_banner("랭크 %d  %s" % [profile.rank(), profile.rank_name()], 4.0, UI.AMBER)
		hud.show_radio(StoryScript.radio("rank_up"), 6.0)


func _on_mission_done(info: Dictionary) -> void:
	var r: int = info.reward
	save.coins += r
	save.total += r
	save.missions += 1
	profile.add_stat("missions", 1.0)
	match String(info.kind):
		"delivery": profile.add_stat("deliveries", 1.0)
		"photo": profile.add_stat("photos", 1.0)
		"landing": profile.add_stat("landings", 1.0)
	profile.data.stats["stars"] = float(profile.total_stars())
	_gain_xp(30 + 25 * int(info.stars))
	ui_audio.jingle()
	flash = 0.8
	fx.do_pulse()
	fx.slowmo(0.55, 0.4)
	fx.burst(drone.position + Vector3(0, 1, 0), Color(0.5, 1.0, 0.7), 40, 9.0)
	var best: String = "  ★ 신기록!" if info.record else ""
	hud.show_banner("%s  %s" % [info.title, StoryScript.stars_text(int(info.stars))], 4.2, UI.GOOD)
	hud.show_toast("%d:%02d 완료  ·  +%d 코인%s" % [int(info.time) / 60, int(info.time) % 60, r, best], 4.5, Color(0.5, 1.0, 0.6))
	hud.show_radio(StoryScript.radio("mission_done"), 5.0)
	music_mission(false)
	profile.save_now()


func _on_mission_failed(reason: String) -> void:
	ui_audio.fail()
	music_mission(false)
	if reason == "미션 취소":
		hud.show_toast("의뢰를 취소했습니다", 2.5, UI.DIM)
	else:
		hud.show_banner("의뢰 실패", 2.6, UI.BAD)
		hud.show_toast(reason, 3.0, Color(1.0, 0.45, 0.4))


func _on_mission_progress(msg: String) -> void:
	hud.show_toast(msg, 1.6, Color(0.4, 0.95, 1.0))
	if msg.begins_with("링"):
		audio.ring()
		profile.add_stat("rings", 1.0)
		_gain_xp(3)
		fx.do_pulse()
		var t: Vector3 = drone.position
		fx.burst(t, Color(0.4, 0.95, 1.0), 20, 6.0)
	elif msg.begins_with("소포"):
		audio.coin()


func _on_photo_taken(q: float) -> void:
	hud.show_toast("좋은 컷!  (완성도 %d%%)" % int(q * 100.0), 2.0, Color(1.0, 0.5, 0.9))
	hud.show_radio(StoryScript.radio("photo_ok"), 3.5)


func _on_secret(_id: String, n: int, total: int) -> void:
	var r := 40
	save.coins += r
	save.total += r
	profile.add_stat("secrets", 1.0)
	_gain_xp(60)
	audio.sparkle()
	flash = 0.9
	fx.do_pulse()
	fx.burst(drone.position, Color(1.0, 0.85, 0.3), 50, 9.0, 0.16)
	hud.show_banner("숨겨진 상자 발견!  %d / %d" % [n, total], 3.4, UI.AMBER)
	hud.show_toast("+%d 코인" % r, 2.0, Color(1.0, 0.88, 0.45))
	hud.show_radio(StoryScript.radio("secret"), 5.0)
	profile.save_now()


func _on_weather(w: String) -> void:
	var key := w
	if w == "cloudy" or w == "clear" or w == "fog":
		return
	hud.show_radio(StoryScript.radio(key), 6.0)


func _on_lightning(strength: float) -> void:
	lightning_f = strength
	var delay := randf_range(0.4, 2.2)
	get_tree().create_timer(delay).timeout.connect(func() -> void: audio.thunder(-4.0 - delay * 3.0))


func _on_tutorial_done() -> void:
	var r := 100
	save.coins += r
	save.total += r
	_gain_xp(60)
	ui_audio.jingle()
	hud.show_banner("튜토리얼 완료!  +%d 코인" % r, 4.0, UI.GOOD)
	hud.show_radio("관제 노을: 「이제 혼자서도 문제없겠어요. 의뢰 메뉴에서 일을 골라 보세요!」", 7.0)
	profile.save_now()


# ---------------------------------------------------------------- 입력
func _unhandled_input(event: InputEvent) -> void:
	if not world_started:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		drone.zoom_held = event.pressed and not paused
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused:
		drone.mouse_look(event.relative)
		return
	if event is InputEventMouseButton and event.pressed and not paused:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_LEFT and missions.active and missions.kind == "photo":
			_shutter()
		return
	var pressed: bool = (event is InputEventKey or event is InputEventJoypadButton) and event.pressed and not event.is_echo()
	if not pressed:
		return
	if minimap.full:
		if event.is_action_pressed("map") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
			_toggle_map()
		return
	if paused and modal_ui != null:
		return
	var esc: bool = (event is InputEventKey and event.keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START)
	if esc:
		if paused and pause_ui != null and pause_ui.in_settings():
			pause_ui.close_settings()
		else:
			_set_pause(not paused)
		return
	if event.is_action_pressed("settings"):
		if not paused:
			_set_pause(true)
			pause_ui.open_settings()
		elif pause_ui != null:
			if pause_ui.in_settings():
				pause_ui.close_settings()
			else:
				pause_ui.open_settings()
		return
	if paused:
		return
	if event is InputEventKey and event.keycode == KEY_TAB:
		tutorial.skip()
		hud.show_toast("튜토리얼을 건너뛰었습니다", 2.0)
	elif event.is_action_pressed("inventory"):
		_open_inventory()
	elif event.is_action_pressed("missile"):
		if combat != null:
			combat.fire_missile()
	elif event.is_action_pressed("mission"):
		if combat != null:
			hud.show_toast("전투 모드에서는 배송 의뢰를 받을 수 없습니다", 2.0, UI.DIM)
		elif missions.active:
			missions.cancel()
		else:
			_open_mission_menu()
	elif event.is_action_pressed("map"):
		_toggle_map()
	elif event.is_action_pressed("toggle_view"):
		drone.set_third(not drone.third)
		hud.show_toast("3인칭 시점" if drone.third else "1인칭 (FPV) 시점", 1.6)
	elif event.is_action_pressed("photo"):
		_shutter()
	elif event.is_action_pressed("go_home"):
		drone.return_home()
	elif event.is_action_pressed("assist"):
		drone.assist = not drone.assist
		save.settings.assist = drone.assist
		hud.show_toast("비행 보조: " + ("켜짐 (키를 떼면 바로 멈춤)" if drone.assist else "꺼짐 (수동)"), 2.5)
	elif event is InputEventKey and (event.keycode == KEY_MINUS or event.keycode == KEY_EQUAL):
		var f := 1.18 if event.keycode == KEY_EQUAL else 1.0 / 1.18
		drone.mouse_sens = clampf(drone.mouse_sens * f, 0.3, 3.0)
		save.settings.sens = drone.mouse_sens
		hud.show_toast("마우스 감도 %d%%" % int(round(drone.mouse_sens * 100.0)), 1.5)


func _shutter() -> void:
	ui_audio.shutter()
	flash = 0.9
	var r: int = missions.try_photo(drone.cam)
	if r < 0:
		hud.show_toast("찰칵!", 0.8, UI.DIM)


# ---------------------------------------------------------------- 매 프레임
func _process(delta: float) -> void:
	if not world_started:
		return
	frame_i += 1
	delta = minf(delta, 0.05)
	if shot_dir != "":
		_shot_script()
	if thumb_path != "":
		_thumb_script()
	if mtest:
		_mtest_script()
	elif tshot:
		_tshot_script()
	elif pshot_dir != "" and not cshot:
		_pshot_script()
	if cshot:
		_cshot_script()
	if selftest:
		_selftest_script()
	if fly_test:
		_fly_test(delta)

	if not paused:
		drone.update(delta, false)
		rec_time += delta
		save.playtime += delta
	var pos: Vector3 = drone.position
	var tp0 := Time.get_ticks_usec()
	terrain.update(pos)
	_prof("terrain", tp0)
	var indoor: float = buildings.indoor_f
	if not paused:
		tp0 = Time.get_ticks_usec()
		birds.update(pos, delta)
		_prof("birds", tp0)
		tp0 = Time.get_ticks_usec()
		people.update(pos, delta)
		_prof("people", tp0)
		if traffic != null:
			tp0 = Time.get_ticks_usec()
			traffic.update(pos, delta)
			_prof("traffic", tp0)
			if traffic_sim:
				_traffic_sim(pos)
		tp0 = Time.get_ticks_usec()
		buildings.update(drone, delta)
		_prof("buildings", tp0)
		tp0 = Time.get_ticks_usec()
		missions.update(pos, delta, 1.0 + 0.25 * int(save.levels.bounty))
		_prof("missions", tp0)
		if combat != null:
			tp0 = Time.get_ticks_usec()
			combat.update(delta)
			_prof("combat", tp0)
		tp0 = Time.get_ticks_usec()
		secrets.update(pos, delta)
		_prof("secrets", tp0)
		tp0 = Time.get_ticks_usec()
		tutorial.update(delta)
		_prof("tutorial", tp0)
		tp0 = Time.get_ticks_usec()
		daynight.update(delta, pos, indoor)
		_prof("daynight", tp0)
		_track_stats(delta, pos)
	drone.indoor = indoor
	drone.wind_mul = daynight.wind_mul
	env.fog_light_color = env.fog_light_color.lerp(Color(0.04, 0.05, 0.07), indoor)
	lamp.light_energy = maxf(indoor * 2.2 * (1.0 - buildings.blackout), daynight.night_f * 1.4)
	while not buildings.msg_q.is_empty():
		hud.show_toast(buildings.msg_q.pop_front(), 3.2, Color(1.0, 0.25, 0.25))
	var got: int = coins.update(pos, delta) if not paused else 0
	if got > 0:
		save.coins += got * 5
		save.total += got * 5
		profile.add_stat("coin_pick", float(got))
		_gain_xp(got)
		audio.coin()
		flash = 0.6
		fx.burst(pos + Vector3(0, 0.2, 0), Color(1.0, 0.82, 0.25), 10, 4.0, 0.08)
		hud.show_toast("+%d 코인" % (got * 5), 1.2)
	if traffic != null:
		for hd in traffic.honks:
			audio.horn(-8.0 - float(hd) / 12.0)

	# 계기판 데이터
	var cam: Camera3D = drone.cam
	var fwd := -cam.global_basis.z
	var heading := fposmod(rad_to_deg(atan2(fwd.x, -fwd.z)), 360.0)
	var to_home: Vector3 = drone.home - pos
	var home_bearing := fposmod(rad_to_deg(atan2(to_home.x, -to_home.z)), 360.0)
	var cd: float = coins.nearest_dist
	var coin_bearing := 0.0
	if cd < 1.0e8:
		var tc: Vector3 = coins.nearest_pos - pos
		coin_bearing = fposmod(rad_to_deg(atan2(tc.x, -tc.z)), 360.0)
	var sec: Dictionary = secrets.nearest(pos)
	var sec_b := 0.0
	if sec.dist < 1.0e8:
		var ts: Vector3 = sec.pos - pos
		sec_b = fposmod(rad_to_deg(atan2(ts.x, -ts.z)), 360.0)
	var hvel := Vector2(drone.vel.x, drone.vel.z)
	hud.set_data({
		"alt": pos.y - terrain.ground(pos.x, pos.z),
		"spd": hvel.length() * 3.6,
		"vspd": drone.vel.y,
		"batt": drone.battery,
		"flight": drone.flight_time,
		"rec": rec_time,
		"signal": drone.signal_q,
		"heading": heading,
		"home_bearing": home_bearing,
		"home_dist": Vector2(to_home.x, to_home.z).length(),
		"coin_bearing": coin_bearing,
		"coin_dist": cd if cd < 1.0e8 else 1.0e9,
		"odo": drone.odometer,
		"cam_pitch": rad_to_deg(asin(clampf(fwd.y, -1.0, 1.0))),
		"cam_roll": atan2(cam.global_basis.x.y, cam.global_basis.y.y),
		"fov": cam.fov,
		"state": drone.state,
		"crash_reason": drone.crash_reason,
		"indoor": indoor,
		"assist": drone.assist,
		"world": world.name,
		"bld_bearing": fposmod(rad_to_deg(atan2(buildings.nearest_pos.x - pos.x, -(buildings.nearest_pos.z - pos.z))), 360.0),
		"bld_dist": buildings.nearest_dist,
		"mission": missions.hud_info(pos, cam),
		"clock": daynight.clock(),
		"weather": daynight.weather_name(),
		"tutorial": tutorial.text(),
		"tutorial_prog": tutorial.progress_text(),
		"secret_dist": sec.dist if sec.dist < 1.0e8 else 1.0e9,
		"secret_bearing": sec_b,
		"rank": profile.rank(),
		"rank_name": profile.rank_name(),
		"xp_prog": profile.rank_progress(),
		"key_mission": KeysScript.key_name("mission"),
		"key_photo": KeysScript.key_name("photo"),
		"key_missile": KeysScript.key_name("missile"),
		"cmb": combat.hud_data() if combat != null else {},
	}, delta)
	hud.shop_coins = save.coins
	tp0 = Time.get_ticks_usec()
	_update_minimap(pos)
	_prof("minimap", tp0)

	# 후처리
	var glitch := clampf((0.4 - drone.signal_q) / 0.4, 0.0, 1.0)
	glitch = pow(glitch, 1.6)
	glitch = maxf(glitch, buildings.scare_glitch)
	if drone.state == "crashed":
		glitch = 1.0
	flash = maxf(0.0, flash - delta * 2.5)
	lightning_f = maxf(0.0, lightning_f - delta * 5.0)
	var vib: float = 0.0004 + 0.0014 * drone.rpm * (1.0 - 0.15 * drone.gimbal_eff()) + buildings.scare_glitch * 0.012
	if combat != null:
		vib += combat.shake * 0.006
	fx_mat.set_shader_parameter("white_flash", maxf(buildings.scare_flash, lightning_f * 0.85))
	fx_mat.set_shader_parameter("face", buildings.face)
	var size := get_viewport().get_visible_rect().size
	fx_mat.set_shader_parameter("aspect", size.x / size.y)
	fx_mat.set_shader_parameter("glitch", glitch)
	fx_mat.set_shader_parameter("shake", vib)
	fx_mat.set_shader_parameter("flash", flash)
	var spd_n: float = clampf((hvel.length() - 10.0) / 20.0 + (0.25 if Input.is_action_pressed("boost") else 0.0), 0.0, 1.0)
	fx_mat.set_shader_parameter("speed_lines", spd_n if bool(save.settings.speedlines) and not paused else 0.0)
	fx_mat.set_shader_parameter("rain_drops", daynight.wet * (1.0 - indoor) if not drone.third else 0.0)
	fx_mat.set_shader_parameter("pulse", fx.pulse)

	# 소리
	var spd: float = hvel.length()
	var motor_on := 0.0 if (drone.state == "idle" and drone.rpm < 0.05) else 1.0
	if drone.state == "idle":
		motor_on = 0.25 * clampf(drone.rpm * 3.0, 0.0, 1.0)
	var alt: float = pos.y - terrain.ground(pos.x, pos.z)
	var hum := 0.0
	if world.kind == "city":
		hum = clampf(1.0 - alt / 160.0, 0.0, 1.0) * 0.45 * (1.0 - indoor)
	var siren_k := 0.0
	if traffic != null:
		siren_k = clampf(1.0 - float(traffic.siren_dist) / 260.0, 0.0, 1.0)
	audio.update(drone.rpm, clampf(spd / 25.0 + absf(drone.vel.y) / 15.0, 0.0, 1.0) * (0.8 + 0.4 * daynight.wind_mul), glitch, motor_on, hum, daynight.wet * (1.0 - indoor), siren_k)
	if drone.battery < 20.0 and drone.state == "flying":
		low_beep_t -= delta
		if low_beep_t <= 0.0:
			audio.beep()
			low_beep_t = 0.9
	autosave_t += delta
	if autosave_t > 25.0:
		save_now()
		autosave_t = 0.0


var prof := {}
var prof_n := 0


func _prof(k: String, t0: int) -> void:
	prof[k] = float(prof.get(k, 0.0)) + float(Time.get_ticks_usec() - t0) / 1000.0


func _track_stats(delta: float, pos: Vector3) -> void:
	if drone.state != last_state:
		if drone.state == "flying" and last_state == "idle":
			profile.add_stat("flights", 1.0)
			if save.tutorial_done:
				hud.show_radio(StoryScript.radio("takeoff"), 4.0)
		last_state = drone.state
	var d: float = drone.odometer - last_odo
	last_odo = drone.odometer
	if d > 0.0 and d < 100.0:
		profile.add_stat("dist_km", d / 1000.0)
		dist_xp += d
		if dist_xp >= 100.0:
			_gain_xp(1)
			dist_xp -= 100.0
	if drone.state == "flying":
		if daynight.night_f > 0.7:
			profile.add_stat("night_min", delta / 60.0)
		if daynight.wet > 0.4 or daynight.weather == "dust":
			profile.add_stat("storm_min", delta / 60.0)
	var night: bool = daynight.night_f > 0.8
	if night != was_night:
		was_night = night
		hud.show_radio(StoryScript.radio("night" if night else "dawn"), 5.0)
	if drone.battery < 20.0 and drone.state == "flying" and tutorial_hint_t <= 0.0:
		tutorial_hint_t = 40.0
		hud.show_radio(StoryScript.radio("low_battery"), 5.0)
	tutorial_hint_t = maxf(0.0, tutorial_hint_t - delta)


func _update_minimap(pos: Vector3) -> void:
	var mk: Array = []
	mk.append({"pos": drone.home, "kind": "home"})
	var mt: Vector3 = missions.target()
	if mt != Vector3.INF:
		mk.append({"pos": mt, "kind": "mission"})
	for sp in secrets.remaining_positions():
		if sp.distance_to(pos) < 420.0 or minimap.full:
			mk.append({"pos": sp, "kind": "secret"})
	minimap.update_state(pos, drone.yaw, mk)


# ---------------------------------------------------------------- 개발·검증용
var sim_t := 0.0
var sim_log := 0.0
var sim_placed := false


func _fly_test(delta: float) -> void:
	if not sim_placed:
		sim_placed = true
		drone.debug_place(Vector3(0, 160, 0), 0.0)
	sim_t += delta
	var ti := {"fwd": 0.0, "right": 0.0, "yaw": 0.0, "thr": 0.0, "boost": 0.0}
	var phase := "brake"
	if sim_t < 3.0:
		ti.fwd = 1.0
		phase = "forward"
	elif sim_t < 6.0:
		phase = "release"
	elif sim_t < 7.0:
		ti.yaw = 1.0
		phase = "yaw"
	elif sim_t < 8.0:
		ti.thr = 1.0
		phase = "climb"
	elif sim_t < 13.0:
		ti.thr = -1.0
		ti.fwd = 1.0
		phase = "descend"
	elif sim_t < 14.0:
		phase = "settle"
	elif sim_t < 16.0:
		ti.fwd = 1.0
		ti.yaw = 1.0
		phase = "carve"
	drone.test_input = ti
	sim_log += delta
	if sim_log >= 0.25:
		sim_log = 0.0
		var hv := Vector2(drone.vel.x, drone.vel.z)
		var rgt := Vector2(cos(drone.yaw), -sin(drone.yaw))
		print("t=%.2f %-8s alt=%5.1f hspd=%5.1f m/s  vspd=%+5.1f  slip=%+5.1f  yaw=%6.1f deg  tilt=%5.1f deg  fov=%.0f" % [
			sim_t, phase, drone.position.y - terrain.ground(drone.position.x, drone.position.z), hv.length(), drone.vel.y, hv.dot(rgt),
			rad_to_deg(drone.yaw), rad_to_deg(drone.tp), drone.cam.fov])
	if sim_t > 16.5:
		get_tree().quit()


func _traffic_sim(pos: Vector3) -> void:
	for i in 11:
		traffic.update(pos, 0.05)
	tsim_t += 0.05 * 12.0
	tsim_log += 0.05 * 12.0
	if tsim_log >= 20.0:
		tsim_log = 0.0
		print("SIM t=%.0f %s" % [tsim_t, str(traffic.stats())])
	if tsim_t > 400.0:
		get_tree().quit()


func _lobby_shots(dir: String) -> void:
	save.coins = maxi(save.coins, 230)
	save.inv["golem_core"] = 2
	save.inv["gel"] = 5
	save.inv["wyvern_scale"] = 1
	for i in 6:
		await get_tree().create_timer(0.8).timeout
		lobby_ui._set_tab(i)
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("lobby_%d.png" % i))
	get_tree().quit()


func _save_shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var d := shot_out if shot_out != "" else (shot_dir if shot_dir != "" else (thumb_path if thumb_path != "" else pshot_dir))
	img.save_png(d.path_join(name + ".png"))
	print("saved ", name)


func _look_at(target: Vector3, offset: Vector3) -> void:
	if target == Vector3.INF:
		return
	var p := target + offset
	var to := target - p
	drone.debug_place(p, rad_to_deg(atan2(-to.x, -to.z)))
	drone.cam_tilt = rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length()))
	terrain.update(p, 6000.0)


func _shot_script() -> void:
	if lineup_test:
		var hx: float = terrain.home_xz.x + 14.0
		var hz: float = terrain.home_xz.y + 8.0
		var gy: float = terrain.ground(hx, hz)
		if frame_i == 5:
			drone.debug_place(Vector3(hx, gy + 1.7, hz), 0.0)
			drone.cam_tilt = 0.0
			drone.cam_fov = 60.0
			people.debug_lineup(Vector3(hx, gy, hz - 7.0), 0.0)
		if frame_i == 120:
			_save_shot("lineup_a")
			get_tree().quit()
		return
	if frame_i == 5:
		drone.debug_place(Vector3(0, 70, 0), 0.0)
		drone.cam_tilt = 20.0
	if frame_i == 100:
		_save_shot("01_start")
		get_tree().quit()


const THUMB_CANDS := {
	"city": [[330.0, -330.0, 48.0, -45.0, 6.0], [520.0, -480.0, 70.0, -45.0, 2.0]],
	"alpine": [[-300.0, 300.0, 90.0, 140.0, 10.0]],
	"farm": [[-200.0, 400.0, 28.0, 150.0, 12.0]],
	"mars": [[55.0, 25.0, 9.0, 280.0, 8.0]],
}


func _thumb_script() -> void:
	hud.visible = false
	minimap.visible = false
	var cands: Array = THUMB_CANDS.get(world.id, [])
	var idx := (frame_i - 5) / 130
	var ph := (frame_i - 5) % 130
	if frame_i < 5 or idx >= cands.size():
		if frame_i > 5 and idx >= cands.size():
			get_tree().quit()
		return
	var c: Array = cands[idx]
	if ph == 0:
		var p := Vector3(c[0], 0.0, c[1])
		p.y = terrain.ground(p.x, p.z) + c[2]
		drone.debug_place(p, c[3])
		drone.cam_tilt = c[4]
		terrain.update(p, 6000.0)
		daynight.hour = 11.0 if world.kind != "city" else 17.6
	elif ph == 120:
		_save_shot("%s_cand%d" % [world.id, idx])


func _tshot_script() -> void:
	hud.visible = false
	if frame_i == 3:
		var p := Vector3(160.0 - 34.0, 17.0, 160.0 + 34.0)
		drone.debug_place(p, -45.0)
		drone.cam_tilt = -14.0
	if frame_i in [400, 700]:
		_save_shot("t_%d" % frame_i)
	if frame_i == 701:
		get_tree().quit()


func _pshot_script() -> void:
	if frame_i == 5:
		var p := Vector3(terrain.home_xz.x + 20.0, 0.0, terrain.home_xz.y + 10.0)
		p.y = terrain.ground(p.x, p.z) + 14.0
		drone.debug_place(p, -40.0)
		drone.set_third(true)
		drone.cam_tilt = -14.0
	if frame_i == 120:
		_save_shot("p_third")
		_set_pause(true)
	if frame_i == 150:
		_save_shot("p_pause")
		pause_ui.open_settings()
	if frame_i == 180:
		_save_shot("p_settings")
		get_tree().quit()


## 전투 점검: 적 모델 늘어놓기 → 사격 → 유도탄 (--world=<id> --combat=hunt|duel --cshot=<폴더>)
func _cshot_script() -> void:
	if combat == null:
		return
	if frame_i == 5:
		var gp: Vector2 = terrain.home_xz
		drone.debug_place(Vector3(gp.x, terrain.ground(gp.x, gp.y) + 40.0, gp.y), 0.0)
		drone.cam_tilt = 4.0
		terrain.update(drone.position, 6000.0)
		combat.spawn_t = 99999.0
		combat.wave_t = 99999.0
	if frame_i == 20:
		var kinds: Array = ["slime", "bat", "golem", "wyvern", "eye"] if game_mode == "hunt" else ["scout", "gunship", "striker", "ace"]
		var P: Vector3 = drone.position
		for i in kinds.size():
			var x := (i - (kinds.size() - 1) * 0.5) * 38.0
			var z := P.z - 80.0 - i * 4.0
			var gy: float = terrain.ground(P.x + x, z)
			var y := gy if kinds[i] in ["slime", "golem"] else P.y + 6.0 + i * 3.0
			combat.spawn_at(kinds[i], Vector3(P.x + x, y, z))
	if frame_i == 70:
		_save_shot("c_lineup")
	if frame_i == 80:
		combat.test_fire = true
		drone.debug_place(drone.position, 0.0)
	if frame_i == 120:
		_save_shot("c_fire")
	if frame_i == 170:
		combat.test_fire = false
		var tgt: Node3D = combat.enemies[combat.enemies.size() - 1] if not combat.enemies.is_empty() else null
		if tgt != null:
			combat.lock_target = tgt
			combat.locked = true
			combat.missile_n = 5
			combat.fire_missile()
	if frame_i == 190:
		_save_shot("c_missile")
	if frame_i == 200:
		combat.test_fire = true
		var P2: Vector3 = drone.position
		var k := 0
		for e in combat.enemies:
			if is_instance_valid(e) and e.alive:
				e.position = Vector3(P2.x + (k - 2) * 9.0, maxf(P2.y + 2.0, terrain.ground(P2.x + (k - 2) * 9.0, P2.z - 40.0) + (0.0 if not e.T.fly else 6.0)), P2.z - 40.0)
				if not e.T.fly:
					e.position.y = terrain.ground(e.position.x, e.position.z)
				k += 1
	if frame_i >= 200 and frame_i < 520 and frame_i % 40 == 0:
		drone.hp = drone.hp_max
	if frame_i == 300:
		_save_shot("c_kill")
	if frame_i == 420:
		_save_shot("c_drops")
	if frame_i == 505:
		save.inv["golem_core"] = 1
		save.inv["gel"] = 3
		_open_inventory()
	if frame_i == 515:
		_save_shot("c_inv")
	if frame_i == 520:
		print("CSHOT kills=", combat.kills, " ammo=", combat.ammo, " drops=", combat.drops.size(), " hp=", drone.hp, " alive=", combat.alive_count(), " bullets=", combat.bullets.size(), " inv=", save.inv, " coins=", save.coins)
		print("CSHOT ms ", prof)
		get_tree().quit()


func _mtest_script() -> void:
	if frame_i == 5:
		var gp: Vector2 = terrain.home_xz
		drone.debug_place(Vector3(gp.x, terrain.ground(gp.x, gp.y) + 30.0, gp.y), 0.0)
		drone.cam_tilt = 0.0
		terrain.update(drone.position, 6000.0)
	if frame_i == 20:
		missions.start("ring", drone.position, -drone.cam.global_basis.z)
		print("MTEST start ", missions.kind, " n=", missions.wps.size(), " time=", missions.time_left)
	if frame_i == 60:
		_save_shot("m_start")
	if frame_i >= 140 and frame_i % 12 == 0 and missions.active:
		drone.debug_place(missions.target(), drone.yaw * 57.29578)
	if frame_i == 140 + 12 * 14:
		print("MTEST end active=", missions.active, " coins=", save.coins, " missions=", save.missions)
		get_tree().quit()


## 자동 점검: 시간대·날씨·미션 4종·지도·사진을 차례로 돌려 보고 오류가 없는지 본다 (--world=<id> --selftest)
var st_phase := 0


func _selftest_script() -> void:
	if frame_i == 5:
		var gp: Vector2 = terrain.home_xz
		drone.debug_place(Vector3(gp.x, terrain.ground(gp.x, gp.y) + 40.0, gp.y), 0.0)
		terrain.update(drone.position, 6000.0)
		profile.data.xp = 9999
		print("SELFTEST levels=", save.levels, " accent=", hud.accent, " led=", drone.led_color())
	if frame_i == 30:
		missions.start("photo", drone.position, -drone.cam.global_basis.z)
		_shutter()
	if frame_i == 60:
		missions.start("landing", drone.position, -drone.cam.global_basis.z)
	if frame_i == 90:
		missions.start("delivery", drone.position, -drone.cam.global_basis.z)
	if frame_i == 120:
		missions.start("ring", drone.position, -drone.cam.global_basis.z)
	var hours := [3.0, 8.0, 12.0, 18.0, 21.5]
	var wx := ["rain", "storm", "fog", "dust", "clear"]
	if frame_i >= 150 and frame_i % 60 == 0 and st_phase < hours.size():
		daynight.hour = hours[st_phase]
		daynight.target = wx[st_phase] if (world.kind != "mars" or wx[st_phase] == "dust" or wx[st_phase] == "clear") else "clear"
		daynight.weather = daynight.target
		daynight.wx_t = 100.0
		print("SELFTEST hour=", hours[st_phase], " wx=", daynight.target, " fps=", Engine.get_frames_per_second())
		st_phase += 1
	if frame_i == 250:
		_open_mission_menu()
	if frame_i == 275:
		_save_shot("self_menu")
		if modal_ui != null:
			modal_ui.closed.emit()
	if frame_i == 190:
		_toggle_map()
	if frame_i == 200:
		_save_shot("self_map")
		_toggle_map()
	if frame_i == 230:
		_save_shot("self_dusk")
	if frame_i == 480:
		var avg := {}
		for k in prof:
			avg[k] = snappedf(float(prof[k]) / float(maxi(frame_i - 5, 1)), 0.01)
		print("SELFTEST ms/frame ", avg)
		print("SELFTEST done world=", world.id, " fps=", Engine.get_frames_per_second(), " proc_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		get_tree().quit()
