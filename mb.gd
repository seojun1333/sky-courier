extends RefCounted
## 단순한 메시 빌더: 상자, 원기둥/원뿔, 박공지붕을 정점 색과 함께 하나의 메시로 합친다.

var v := PackedVector3Array()
var n := PackedVector3Array()
var c := PackedColorArray()
var idx := PackedInt32Array()


func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, nrm: Vector3, col: Color) -> void:
	var base := v.size()
	var pts := [a, b, cc, d]
	if (b - a).cross(cc - a).dot(nrm) > 0.0:   # Godot의 앞면은 시계 방향
		pts = [a, d, cc, b]
	for p in pts:
		v.append(p)
		n.append(nrm)
		c.append(col)
	idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


func tri(a: Vector3, b: Vector3, cc: Vector3, nrm: Vector3, col: Color) -> void:
	var base := v.size()
	var pts := [a, b, cc]
	if (b - a).cross(cc - a).dot(nrm) > 0.0:
		pts = [a, cc, b]
	for p in pts:
		v.append(p)
		n.append(nrm)
		c.append(col)
	idx.append_array([base, base + 1, base + 2])


func box(mn: Vector3, mx: Vector3, col: Color) -> void:
	quad(Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mx.y, mn.z), Vector3(mn.x, mx.y, mn.z), Vector3(0, 0, -1), col)
	quad(Vector3(mn.x, mn.y, mx.z), Vector3(mx.x, mn.y, mx.z), Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z), Vector3(0, 0, 1), col)
	quad(Vector3(mn.x, mn.y, mn.z), Vector3(mn.x, mn.y, mx.z), Vector3(mn.x, mx.y, mx.z), Vector3(mn.x, mx.y, mn.z), Vector3(-1, 0, 0), col)
	quad(Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mn.y, mx.z), Vector3(mx.x, mx.y, mx.z), Vector3(mx.x, mx.y, mn.z), Vector3(1, 0, 0), col)
	quad(Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mn.y, mx.z), Vector3(mn.x, mn.y, mx.z), Vector3(0, -1, 0), col)
	quad(Vector3(mn.x, mx.y, mn.z), Vector3(mx.x, mx.y, mn.z), Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z), Vector3(0, 1, 0), col)


## 세운 원기둥/원뿔대. r_top 이 0 이면 원뿔
func cylinder(bottom: Vector3, r: float, h: float, seg: int, col: Color, r_top: float = -1.0, cap: bool = true, sc: Vector2 = Vector2.ONE) -> void:
	var rt := r if r_top < 0.0 else r_top
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := Vector3(cos(a0) * sc.x, 0, sin(a0) * sc.y)
		var p1 := Vector3(cos(a1) * sc.x, 0, sin(a1) * sc.y)
		var mid := (p0 + p1).normalized()
		var nrm := Vector3(mid.x * h, r - rt, mid.z * h).normalized()
		quad(bottom + p0 * r, bottom + p1 * r, bottom + Vector3(0, h, 0) + p1 * rt, bottom + Vector3(0, h, 0) + p0 * rt, nrm, col)
		if cap and rt > 0.01:
			tri(bottom + Vector3(0, h, 0), bottom + Vector3(0, h, 0) + p0 * rt, bottom + Vector3(0, h, 0) + p1 * rt, Vector3.UP, col)


## 타원체(부드러운 법선). r 은 축별 반지름
func sphere(ctr: Vector3, r: Vector3, seg: int, rings: int, col: Color) -> void:
	var base := v.size()
	for j in rings + 1:
		var la := PI * j / rings - PI / 2.0
		var yy := sin(la)
		var rr := cos(la)
		for i in seg + 1:
			var a := TAU * i / seg
			var d := Vector3(cos(a) * rr, yy, sin(a) * rr)
			v.append(ctr + Vector3(d.x * r.x, d.y * r.y, d.z * r.z))
			n.append(Vector3(d.x / r.x, d.y / r.y, d.z / r.z).normalized())
			c.append(col)
	var stride := seg + 1
	for j in rings:
		for i in seg:
			var a0 := base + j * stride + i
			var a1 := a0 + 1
			var b0 := a0 + stride
			var b1 := b0 + 1
			if (v[a1] - v[a0]).cross(v[b0] - v[a0]).dot(n[a0]) > 0.0:
				idx.append_array([a0, b0, a1])
			else:
				idx.append_array([a0, a1, b0])
			if (v[b1] - v[a1]).cross(v[b0] - v[a1]).dot(n[a1]) > 0.0:
				idx.append_array([a1, b0, b1])
			else:
				idx.append_array([a1, b1, b0])


## 박공지붕. mn.y 가 처마 높이, ridge 가 용마루 높이. axis_x 이면 용마루가 X 방향
func gable(mn: Vector3, mx: Vector3, ridge: float, axis_x: bool, col: Color) -> void:
	var y := mn.y
	var yr := y + ridge
	if axis_x:
		var zc := (mn.z + mx.z) * 0.5
		var hd := (mx.z - mn.z) * 0.5
		quad(Vector3(mn.x, y, mn.z), Vector3(mx.x, y, mn.z), Vector3(mx.x, yr, zc), Vector3(mn.x, yr, zc), Vector3(0, hd, -ridge).normalized(), col)
		quad(Vector3(mn.x, y, mx.z), Vector3(mx.x, y, mx.z), Vector3(mx.x, yr, zc), Vector3(mn.x, yr, zc), Vector3(0, hd, ridge).normalized(), col)
		tri(Vector3(mn.x, y, mn.z), Vector3(mn.x, y, mx.z), Vector3(mn.x, yr, zc), Vector3(-1, 0, 0), col)
		tri(Vector3(mx.x, y, mn.z), Vector3(mx.x, y, mx.z), Vector3(mx.x, yr, zc), Vector3(1, 0, 0), col)
	else:
		var xc := (mn.x + mx.x) * 0.5
		var hd := (mx.x - mn.x) * 0.5
		quad(Vector3(mn.x, y, mn.z), Vector3(mn.x, y, mx.z), Vector3(xc, yr, mx.z), Vector3(xc, yr, mn.z), Vector3(-hd, ridge, 0).normalized(), col)
		quad(Vector3(mx.x, y, mn.z), Vector3(mx.x, y, mx.z), Vector3(xc, yr, mx.z), Vector3(xc, yr, mn.z), Vector3(hd, ridge, 0).normalized(), col)
		tri(Vector3(mn.x, y, mn.z), Vector3(mx.x, y, mn.z), Vector3(xc, yr, mn.z), Vector3(0, 0, -1), col)
		tri(Vector3(mn.x, y, mx.z), Vector3(mx.x, y, mx.z), Vector3(xc, yr, mx.z), Vector3(0, 0, 1), col)


func is_empty() -> bool:
	return v.is_empty()


func build() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
