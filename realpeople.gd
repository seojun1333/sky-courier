extends Node3D
## 드론 가까이에 있는 사람만 진짜 스키닝 캐릭터(Quaternius CC0)로 그린다.
## 슬롯 풀(남 16·여 12)을 가까운 사람에게 빌려주고, 먼 사람은 people.gd의 가벼운 모델이 맡는다.
## 몸은 하나(남/여)뿐이라 옷·머리·소지품으로 13종을 구분한다.

const SLOTS_M := 16
const SLOTS_F := 12
const BODY_SHADER := preload("res://chars/body.gdshader")
const MALE := "res://chars/Superhero_Male_FullBody.gltf"
const FEMALE := "res://chars/Superhero_Female_FullBody.gltf"
const SKIN_TEX := {
	"m": ["res://chars/T_Superhero_Male_Dark.png", "res://chars/T_Superhero_Male_Ligh.png"],
	"f": ["res://chars/T_Superhero_Female_Dark_BaseColor.png", "res://chars/T_Superhero_Female_Light_BaseColor.png"],
}
const NORMAL_TEX := {"m": "res://chars/T_Superhero_Male_Normal.png", "f": "res://chars/T_Superhero_Female_Normal.png"}
const ROUGH_TEX := {"m": "res://chars/T_Superhero_Male_Roughness.png", "f": "res://chars/T_Superhero_Female_Roughness.png"}

## 종류별 모습. skin 0=짙은 톤 1=밝은 톤, sx=소매 끝(0.2=민소매, 0.34=반팔, 0.75=긴팔), py=바지 끝 높이(0=긴바지)
const LOOKS := {
	"office_m": {"sex": "m", "skin": 1, "hair": "Hair_SimpleParted", "hcol": Color(0.09, 0.06, 0.05), "shirt": Color(0.1, 0.12, 0.2), "pants": Color(0.1, 0.11, 0.17), "sx": 0.75, "acc": ["briefcase", "tie"]},
	"office_f": {"sex": "f", "skin": 1, "hair": "Hair_Buns", "hcol": Color(0.1, 0.07, 0.05), "shirt": Color(0.9, 0.9, 0.93), "pants": Color(0.14, 0.14, 0.18), "sx": 0.75, "py": 0.6, "sbot": 0.6, "acc": ["handbag"]},
	"kid": {"sex": "m", "skin": 1, "hair": "Hair_Buzzed", "hcol": Color(0.12, 0.08, 0.05), "shirt": Color(0.9, 0.3, 0.2), "pants": Color(0.2, 0.3, 0.55), "sx": 0.34, "py": 0.5, "acc": ["backpack"], "scale": 0.62, "walk": "Walk"},
	"club_f": {"sex": "f", "skin": 1, "hair": "Hair_Long", "hcol": Color(0.08, 0.05, 0.06), "shirt": Color(0.9, 0.08, 0.45), "pants": Color(0.9, 0.08, 0.45), "sx": 0.205, "py": 0.74, "sbot": 0.74, "acc": ["clutch"], "idle": "Dance"},
	"dogwalker": {"sex": "m", "skin": 0, "hair": "Hair_SimpleParted", "hcol": Color(0.3, 0.2, 0.1), "shirt": Color(0.2, 0.4, 0.3), "pants": Color(0.2, 0.28, 0.45), "sx": 0.75, "acc": []},
	"jogger": {"sex": "f", "skin": 0, "hair": "Hair_Buns", "hcol": Color(0.15, 0.1, 0.07), "shirt": Color(0.1, 0.75, 0.85), "pants": Color(0.08, 0.08, 0.1), "sx": 0.2, "py": 0.55, "walk": "Jog_Fwd"},
	"elder": {"sex": "m", "skin": 1, "hair": "Hair_Buzzed", "hcol": Color(0.8, 0.8, 0.82), "shirt": Color(0.2, 0.36, 0.3), "pants": Color(0.32, 0.3, 0.28), "sx": 0.75, "acc": ["cane", "beard"], "scale": 0.94, "walk": "Walk_Formal"},
	"courier": {"sex": "m", "skin": 0, "hair": "", "hcol": Color(0.1, 0.07, 0.05), "shirt": Color(0.9, 0.35, 0.08), "pants": Color(0.08, 0.08, 0.1), "sx": 0.75, "acc": ["helmet", "deliverybox"], "walk": "Jog_Fwd"},
	"police": {"sex": "m", "skin": 1, "hair": "", "hcol": Color(0.08, 0.06, 0.05), "shirt": Color(0.1, 0.15, 0.3), "pants": Color(0.07, 0.1, 0.2), "sx": 0.34, "acc": ["policecap"]},
	"student": {"sex": "f", "skin": 1, "hair": "Hair_Long", "hcol": Color(0.08, 0.06, 0.05), "shirt": Color(0.92, 0.92, 0.94), "pants": Color(0.12, 0.14, 0.3), "sx": 0.34, "py": 0.64, "sbot": 0.99, "acc": ["backpack"]},
	"tourist": {"sex": "m", "skin": 1, "hair": "Hair_SimpleParted", "hcol": Color(0.3, 0.2, 0.1), "shirt": Color(0.2, 0.62, 0.85), "shirt2": Color(0.95, 0.95, 0.9), "stripe": 1.0, "pants": Color(0.75, 0.68, 0.5), "sx": 0.34, "py": 0.5, "acc": ["straw", "backpack", "beard"]},
	"farmer": {"sex": "m", "skin": 0, "hair": "Hair_Buzzed", "hcol": Color(0.25, 0.18, 0.1), "shirt": Color(0.7, 0.2, 0.15), "shirt2": Color(0.45, 0.1, 0.08), "stripe": 1.0, "pants": Color(0.2, 0.3, 0.5), "sx": 0.75, "acc": ["straw"]},
	"worker": {"sex": "m", "skin": 0, "hair": "", "hcol": Color(0.1, 0.07, 0.05), "shirt": Color(0.95, 0.6, 0.08), "shirt2": Color(0.85, 0.85, 0.8), "stripe": 1.0, "pants": Color(0.28, 0.28, 0.3), "sx": 0.34, "acc": ["hardhat"]},
}

var slots: Array = []
var cache := {}
var lib: AnimationLibrary
var frame := 0


func _ready() -> void:
	var ual: Node = load("res://chars/UAL1_Standard.glb").instantiate()
	var ap: AnimationPlayer = ual.find_child("AnimationPlayer", true, false)
	lib = ap.get_animation_library("")
	for n in ["Walk", "Jog_Fwd", "Idle", "Idle_Talking", "Walk_Formal", "Dance", "Sprint"]:
		if lib.has_animation(n):
			lib.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	ual.free()
	for i in SLOTS_M:
		slots.append(_make_slot("m"))
	for i in SLOTS_F:
		slots.append(_make_slot("f"))


func _body_mesh(sex: String) -> ArrayMesh:
	var key := "mesh_" + sex
	if cache.has(key):
		return cache[key]
	var src: Node = load(MALE if sex == "m" else FEMALE).instantiate()
	var mi: MeshInstance3D = null
	for c in src.find_child("Skeleton3D", true, false).get_children():
		if c is MeshInstance3D and c.mesh.get_surface_count() > 0 and c.mesh.get_aabb().size.y > 1.0:
			mi = c
	var ar := mi.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
	var cols := PackedColorArray()
	cols.resize(vs.size())
	for i in vs.size():
		cols[i] = Color(vs[i].x * 0.5 + 0.5, vs[i].y * 0.5, vs[i].z * 0.5 + 0.5)
	ar[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	for i in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		ar[i] = null
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ar, [], {}, 0)
	cache[key] = m
	src.free()
	return m


func _hair(name: String) -> Array:
	if cache.has(name):
		return cache[name]
	var src: Node = load("res://chars/hair0/%s.gltf" % name).instantiate()
	var mi: MeshInstance3D = src.find_child(name, true, false)
	var r := [mi.mesh, mi.transform, mi.mesh.surface_get_material(0)]
	cache[name] = r
	src.free()
	return r


## 머리카락·수염: 모델 좌표계로 만든 메시를 머리뼈에 붙인다(뼈 기준자세의 역변환을 곱해 제자리에 놓는다)
func _attach_hair(s: Dictionary, name: String, col: Color) -> Node:
	var h := _hair(name)
	var hm: StandardMaterial3D = (h[2] as StandardMaterial3D).duplicate()
	hm.albedo_color = col if col.v > 0.5 else col.lightened(0.55)
	var sk: Skeleton3D = s.sk
	var rest := sk.get_bone_global_rest(sk.find_bone("Head"))
	var ba := BoneAttachment3D.new()
	ba.bone_name = "Head"
	sk.add_child(ba)
	var mi := MeshInstance3D.new()
	mi.mesh = h[0]
	mi.material_override = hm
	mi.transform = rest.affine_inverse() * (h[1] as Transform3D)
	ba.add_child(mi)
	return ba


func _make_slot(sex: String) -> Dictionary:
	var root := Node3D.new()
	root.visible = false
	add_child(root)
	var ch: Node3D = load(MALE if sex == "m" else FEMALE).instantiate()
	root.add_child(ch)
	var sk: Skeleton3D = ch.find_child("Skeleton3D", true, false)
	var body: MeshInstance3D = null
	var brow: MeshInstance3D = null
	for c in sk.get_children():
		if c is MeshInstance3D:
			if c.mesh.get_aabb().size.y > 1.0:
				body = c
			elif c.name.begins_with("Eyebrows"):
				brow = c
	body.mesh = _body_mesh(sex)
	var mat := ShaderMaterial.new()
	mat.shader = BODY_SHADER
	mat.set_shader_parameter("normal_tex", load(NORMAL_TEX[sex]))
	mat.set_shader_parameter("rough_tex", load(ROUGH_TEX[sex]))
	body.material_override = mat
	var bm: Material = brow.mesh.surface_get_material(0).duplicate()
	brow.material_override = bm
	var ap := AnimationPlayer.new()
	root.add_child(ap)
	ap.root_node = ap.get_path_to(ch)
	ap.add_animation_library("", lib)
	var s := {"root": root, "ch": ch, "sk": sk, "sex": sex, "mat": mat, "brow": bm, "ap": ap, "ag": null, "used": -1,
		"look": "", "hair_mi": null, "acc": [], "anim": ""}
	return s


func _material(c: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _attach(s: Dictionary, bone: String, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> void:
	var sk: Skeleton3D = s.sk
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	sk.add_child(ba)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	ba.add_child(mi)
	s.acc.append(ba)


func _box(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = sz
	return b


func _cyl(r: float, h: float, top_r := -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if top_r < 0.0 else top_r
	c.height = h
	return c


## 뼈 로컬축은 모델마다 달라서, 머리·등 부위는 모델 기준 오프셋을 뼈 기준자세로 역변환해서 붙인다.
func _attach_at(s: Dictionary, bone: String, mesh: Mesh, mat: Material, model_pos: Vector3, model_rot := Vector3.ZERO) -> void:
	var sk: Skeleton3D = s.sk
	var bi := sk.find_bone(bone)
	var rest := sk.get_bone_global_rest(bi)
	var want := Transform3D(Basis.from_euler(model_rot), model_pos)
	var local := rest.affine_inverse() * want
	var sc: Vector3 = sk.global_transform.basis.get_scale()
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	sk.add_child(ba)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = local
	ba.add_child(mi)
	s.acc.append(ba)


func _style(s: Dictionary, id: String) -> void:
	var L: Dictionary = LOOKS[id]
	s.look = id
	var sex: String = s.sex
	var mat: ShaderMaterial = s.mat
	mat.set_shader_parameter("skin_tex", load(SKIN_TEX[sex][int(L.skin)]))
	mat.set_shader_parameter("shirt_col", Vector3(L.shirt.r, L.shirt.g, L.shirt.b))
	var s2: Color = L.get("shirt2", L.shirt)
	mat.set_shader_parameter("shirt2_col", Vector3(s2.r, s2.g, s2.b))
	mat.set_shader_parameter("stripe", L.get("stripe", 0.0))
	mat.set_shader_parameter("pants_col", Vector3(L.pants.r, L.pants.g, L.pants.b))
	mat.set_shader_parameter("sleeve_x", L.get("sx", 0.34))
	mat.set_shader_parameter("pants_y", L.get("py", 0.0))
	mat.set_shader_parameter("shirt_bottom", L.get("sbot", 0.99))
	mat.set_shader_parameter("shoe_col", Vector3(0.9, 0.9, 0.9) if id == "jogger" or id == "kid" else Vector3(0.07, 0.07, 0.08))
	var hc: Color = L.hcol
	(s.brow as BaseMaterial3D).albedo_color = hc.lightened(0.25)
	# 머리
	if s.hair_mi != null:
		s.hair_mi.queue_free()
		s.hair_mi = null
	if L.hair != "":
		s.hair_mi = _attach_hair(s, L.hair, hc)
	# 소지품
	for a in s.acc:
		a.queue_free()
	s.acc.clear()
	for a in L.get("acc", []):
		_add_acc(s, a, L)


func _add_acc(s: Dictionary, a: String, L: Dictionary) -> void:
	match a:
		"briefcase":
			_attach_at(s, "hand_r", _box(Vector3(0.38, 0.28, 0.08)), _material(Color(0.12, 0.1, 0.08), 0.5), Vector3(-0.76, 0.98, 0.0), Vector3.ZERO)
		"handbag":
			_attach_at(s, "hand_r", _box(Vector3(0.28, 0.2, 0.1)), _material(Color(0.5, 0.2, 0.15), 0.45), Vector3(-0.76, 1.0, 0.0))
		"clutch":
			_attach_at(s, "hand_r", _box(Vector3(0.2, 0.1, 0.05)), _material(Color(0.95, 0.8, 0.3), 0.3, 0.6), Vector3(-0.72, 1.12, 0.0))
		"tie":
			_attach_at(s, "spine_03", _box(Vector3(0.05, 0.3, 0.02)), _material(Color(0.6, 0.1, 0.15), 0.6), Vector3(0.0, 1.32, 0.17))
		"backpack":
			var col := Color(0.15, 0.4, 0.75) if L.get("scale", 1.0) < 0.9 else Color(0.15, 0.17, 0.2)
			_attach_at(s, "spine_03", _box(Vector3(0.3, 0.4, 0.17)), _material(col, 0.8), Vector3(0.0, 1.3, -0.17))
		"deliverybox":
			_attach_at(s, "spine_03", _box(Vector3(0.5, 0.5, 0.5)), _material(Color(0.1, 0.7, 0.65), 0.6), Vector3(0.0, 1.32, -0.34))
		"cane":
			_attach_at(s, "hand_r", _cyl(0.014, 0.9), _material(Color(0.35, 0.22, 0.12), 0.6), Vector3(-0.76, 0.45, 0.0))
		"beard":
			s.acc.append(_attach_hair(s, "Hair_Beard", L.hcol))
		"helmet":
			_attach_at(s, "Head", _sphere(0.125, 0.8), _material(Color(0.05, 0.05, 0.06), 0.3), Vector3(0.0, 1.75, 0.0))
		"policecap":
			_attach_at(s, "Head", _cyl(0.12, 0.09, 0.105), _material(Color(0.06, 0.09, 0.2), 0.6), Vector3(0.0, 1.8, 0.0))
		"hardhat":
			_attach_at(s, "Head", _sphere(0.125, 0.8), _material(Color(0.98, 0.85, 0.1), 0.35), Vector3(0.0, 1.76, 0.0))
		"straw":
			_attach_at(s, "Head", _cyl(0.26, 0.02), _material(Color(0.88, 0.75, 0.45), 0.9), Vector3(0.0, 1.77, 0.0))
			_attach_at(s, "Head", _cyl(0.12, 0.1), _material(Color(0.88, 0.75, 0.45), 0.9), Vector3(0.0, 1.81, 0.0))


func _sphere(r: float, squash: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 * squash
	return m


## 가까운 사람 하나를 슬롯에 붙여 그린다. 슬롯이 없거나 모르는 종류면 false(호출 쪽이 가벼운 모델로 그림).
func draw(ag: Dictionary, xf: Transform3D, scale_mul: float) -> bool:
	if not LOOKS.has(ag.type):
		return false
	var L: Dictionary = LOOKS[ag.type]
	var s: Dictionary = {}
	var si: int = ag.get("slot", -1)
	if si >= 0 and slots[si].ag == ag:
		s = slots[si]
	else:
		var from := 0 if L.sex == "m" else SLOTS_M
		var to := SLOTS_M if L.sex == "m" else SLOTS_M + SLOTS_F
		for i in range(from, to):
			if slots[i].ag == null:
				s = slots[i]
				s.ag = ag
				ag.slot = i
				break
		if s.is_empty():
			return false
	s.used = frame
	if s.look != ag.type:
		_style(s, ag.type)
	var root: Node3D = s.root
	var k: float = L.get("scale", 1.0) * scale_mul
	root.transform = Transform3D(xf.basis.rotated(Vector3.UP, PI).scaled(Vector3(k, k, k)), xf.origin)
	root.visible = true
	var walking: float = ag.walk
	var want: String
	var spd := 1.0
	if walking > 0.3:
		want = L.get("walk", "Walk")
		spd = clampf(ag.v / ag.base, 0.7, 1.4) * (1.0 if want != "Walk" else 1.05)
		if ag.type == "kid":
			spd *= 1.25
	else:
		want = "Idle_Talking" if ag.get("talk", false) else L.get("idle", "Idle")
	var ap: AnimationPlayer = s.ap
	if s.anim != want:
		s.anim = want
		ap.play(want, 0.3)
		ap.seek(fposmod(float(ag.seed) * 9.0, 1.0) * ap.current_animation_length)
	ap.speed_scale = spd
	return true


func release(ag: Dictionary) -> void:
	var si: int = ag.get("slot", -1)
	if si >= 0 and slots[si].ag == ag:
		slots[si].ag = null
		slots[si].root.visible = false
		slots[si].anim = ""
		slots[si].look = ""
	ag.slot = -1


func finish() -> void:
	frame += 1
	for s in slots:
		if s.ag != null and s.used < frame - 1:
			s.ag.slot = -1
			s.ag = null
			s.root.visible = false
			s.anim = ""
