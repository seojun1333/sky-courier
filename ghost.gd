extends Node3D
## 창백한 여자 귀신. 모델의 앞쪽은 -Z.

var body_mat: ShaderMaterial
var rope: MeshInstance3D


func _ready() -> void:
	body_mat = ShaderMaterial.new()
	body_mat.shader = load("res://ghost.gdshader")
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.01, 0.01, 0.015)

	_part(CylinderMesh.new(), Vector3(0, 0.7, 0), Vector3.ONE, body_mat, func(m: CylinderMesh) -> void:
		m.top_radius = 0.13
		m.bottom_radius = 0.58
		m.height = 1.4
		m.radial_segments = 14)
	_part(CapsuleMesh.new(), Vector3(0, 1.52, 0), Vector3.ONE, body_mat, func(m: CapsuleMesh) -> void:
		m.radius = 0.17
		m.height = 0.72)
	for sx in [-1.0, 1.0]:
		var arm := _part(CylinderMesh.new(), Vector3(sx * 0.25, 1.2, -0.05), Vector3.ONE, body_mat, func(m: CylinderMesh) -> void:
			m.top_radius = 0.035
			m.bottom_radius = 0.03
			m.height = 1.0)
		arm.rotation.z = sx * 0.1
	_part(SphereMesh.new(), Vector3(0, 1.92, 0), Vector3.ONE, body_mat, func(m: SphereMesh) -> void:
		m.radius = 0.16
		m.height = 0.32)
	# 얼굴을 반쯤 가리는 긴 머리카락
	_part(SphereMesh.new(), Vector3(0, 1.8, 0.07), Vector3(1.0, 2.0, 0.8), black, func(m: SphereMesh) -> void:
		m.radius = 0.2
		m.height = 0.4)
	for sx in [-1.0, 1.0]:
		_part(SphereMesh.new(), Vector3(sx * 0.065, 1.93, -0.14), Vector3.ONE, black, func(m: SphereMesh) -> void:
			m.radius = 0.034
			m.height = 0.068)
	_part(SphereMesh.new(), Vector3(0, 1.84, -0.15), Vector3(0.7, 1.6, 0.4), black, func(m: SphereMesh) -> void:
		m.radius = 0.05
		m.height = 0.1)
	# 매달린 모습일 때만 보이는 밧줄
	rope = _part(CylinderMesh.new(), Vector3(0, 3.9, 0), Vector3.ONE, black, func(m: CylinderMesh) -> void:
		m.top_radius = 0.025
		m.bottom_radius = 0.025
		m.height = 4.0)
	rope.visible = false
	visible = false


func set_hanging(on: bool) -> void:
	rope.visible = on
	if not on:
		rotation.z = 0.0
		rotation.x = 0.0
	else:
		rotation.x = 0.12


func _part(mesh: PrimitiveMesh, at: Vector3, scl: Vector3, mat: Material, cfg: Callable) -> MeshInstance3D:
	cfg.call(mesh)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func face(target: Vector3) -> void:
	var d := target - global_position
	rotation.y = atan2(-d.x, -d.z)
