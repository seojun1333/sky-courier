extends Node
## 파일 없이 만드는 배경음악. 맵마다 분위기가 다른 짧은 곡(8마디)을 스레드에서 합성해 이어 붙여 재생한다.

const RATE := 22050
const MOODS := {
	"title": {"bpm": 68, "root": 45, "minor": true, "chords": [0, -4, 3, -2], "pad": 1.0, "arp": 2, "bass": 1, "drums": 0, "bell": 0.0},
	"city": {"bpm": 102, "root": 50, "minor": true, "chords": [0, -4, -9, -7], "pad": 0.7, "arp": 4, "bass": 2, "drums": 1, "bell": 0.0},
	"alpine": {"bpm": 74, "root": 48, "minor": false, "chords": [0, -3, -7, -5], "pad": 1.0, "arp": 0, "bass": 1, "drums": 0, "bell": 0.5},
	"farm": {"bpm": 90, "root": 43, "minor": false, "chords": [0, 5, -3, 7], "pad": 0.35, "arp": 2, "bass": 1, "drums": 2, "bell": 0.0},
	"mars": {"bpm": 58, "root": 40, "minor": true, "chords": [0, 1, -2, 0], "pad": 1.0, "arp": 0, "bass": 1, "drums": 0, "bell": 0.7},
	"battle": {"bpm": 138, "root": 41, "minor": true, "chords": [0, 0, 3, -2], "pad": 0.4, "arp": 4, "bass": 2, "drums": 1, "bell": 0.0},
	"mission": {"bpm": 126, "root": 45, "minor": true, "chords": [0, 0, -4, -2], "pad": 0.45, "arp": 4, "bass": 2, "drums": 1, "bell": 0.0},
}

var players: Array[AudioStreamPlayer] = []
var cur := 0
var mood := ""
var cache := {}
var thread: Thread
var pending := ""
var vol_db := -3.0
var tween: Tween


func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -60.0
		add_child(p)
		players.append(p)


func _exit_tree() -> void:
	if thread != null:
		thread.wait_to_finish()
		thread = null


func _process(_dt: float) -> void:
	if thread != null and not thread.is_alive():
		var res = thread.wait_to_finish()
		thread = null
		if res is Array:
			cache[res[0]] = res[1]
		if pending != "" and cache.has(pending):
			var m := pending
			pending = ""
			_start(m)
	if thread == null:
		# 요청받은 곡이 아직 없으면 만들고, 한가하면 나머지 곡도 미리 만들어 둔다
		var want := ""
		if pending != "" and not cache.has(pending):
			want = pending
		else:
			for k in MOODS.keys():
				if not cache.has(k):
					want = k
					break
		if want != "":
			thread = Thread.new()
			thread.start(_render.bind(want))


## 곡을 바꾼다. 아직 합성하지 않았다면 만든 뒤에 크로스페이드로 들어온다.
func play(m: String) -> void:
	if not MOODS.has(m):
		return
	if m == mood:
		pending = ""
		return
	if cache.has(m):
		pending = ""
		_start(m)
		return
	pending = m


func stop(fade := 1.0) -> void:
	mood = ""
	pending = ""
	for p in players:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -60.0, fade)


func _start(m: String) -> void:
	mood = m
	var old := players[cur]
	cur = 1 - cur
	var p := players[cur]
	p.stream = cache[m]
	p.volume_db = -60.0
	p.play()
	if tween != null:
		tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_property(p, "volume_db", vol_db, 2.2)
	if old.playing:
		tween.tween_property(old, "volume_db", -60.0, 2.2)


# ---------------- 합성 ----------------
static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


static func _render(m: String) -> Array:
	var sp: Dictionary = MOODS[m]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(m)
	var beat := 60.0 / float(sp.bpm)
	var bars := 8
	var total := beat * 4.0 * bars
	var n := int(total * RATE)
	var L := PackedFloat32Array()
	var R := PackedFloat32Array()
	L.resize(n)
	R.resize(n)
	var root: int = sp.root
	var minor: bool = sp.minor
	var chord_semis: Array = [0, 3, 7] if minor else [0, 4, 7]
	var scale: Array = [0, 2, 3, 5, 7, 8, 10] if minor else [0, 2, 4, 5, 7, 9, 11]
	var chords: Array = sp.chords
	var arp_l := PackedFloat32Array()
	var arp_r := PackedFloat32Array()
	arp_l.resize(n)
	arp_r.resize(n)
	for ci in 4:
		var cr: int = root + int(chords[ci])
		var qual: Array = chord_semis
		if m == "mars" and ci == 1:
			qual = [0, 1, 7]
		var t0 := ci * 2.0 * 4.0 * beat
		var clen := 2.0 * 4.0 * beat
		# 패드
		if float(sp.pad) > 0.0:
			for k in qual:
				for oct in [0, 12]:
					_voice_pad(L, R, n, t0, clen + 0.8, _hz(cr + k + oct), 0.05 * float(sp.pad), rng.randf_range(-0.6, 0.6))
		# 베이스
		if int(sp.bass) == 1:
			_voice_bass(L, R, n, t0, clen, _hz(cr - 12), 0.16)
		elif int(sp.bass) == 2:
			for b8 in 16:
				var tt := t0 + b8 * beat * 0.5
				var f := _hz(cr - 12 + (7 if b8 % 8 == 6 else 0))
				_voice_bass(L, R, n, tt, beat * 0.42, f, 0.15)
		# 아르페지오
		if int(sp.arp) > 0:
			var step: float = beat * (0.25 if int(sp.arp) == 4 else 0.5)
			var count := int(clen / step)
			var notes := [0, 1, 2, 1, 2, 1]
			for i in count:
				var q: int = qual[notes[i % notes.size()] % 3]
				var oct2 := 12 if (i % 8) < 4 else 24
				_voice_pluck(arp_l, arp_r, n, t0 + i * step, _hz(cr + q + oct2), 0.07, 0.5 + 0.35 * sin(i * 0.7))
		# 종소리 같은 멜로디
		if float(sp.bell) > 0.0:
			for i in 3:
				var deg: int = scale[rng.randi() % scale.size()]
				var tt2 := t0 + rng.randf() * clen * 0.8
				_voice_bell(arp_l, arp_r, n, tt2, _hz(root + 24 + deg), 0.08 * float(sp.bell), rng.randf_range(-0.7, 0.7))
		# 드럼
		if int(sp.drums) == 1:
			for b in 8:
				var tb := t0 + b * beat
				_voice_kick(L, R, n, tb, 0.3)
				_voice_hat(L, R, n, tb + beat * 0.5, 0.05)
		elif int(sp.drums) == 2:
			for b in 8:
				_voice_hat(L, R, n, t0 + b * beat * 0.5 + (beat * 0.25 if b % 2 == 1 else 0.0), 0.03)
	# 아르페지오에 에코를 얹는다
	var d1 := int(beat * 0.75 * RATE)
	for i in n:
		var j := (i - d1 + n) % n
		L[i] += arp_l[i] + arp_r[j] * 0.35
		R[i] += arp_r[i] + arp_l[j] * 0.35
	var peak := 0.001
	for i in n:
		peak = maxf(peak, maxf(absf(L[i]), absf(R[i])))
	var g := 0.82 / peak
	var data := PackedByteArray()
	data.resize(n * 4)
	for i in n:
		data.encode_s16(i * 4, int(clampf(L[i] * g, -1.0, 1.0) * 32767.0))
		data.encode_s16(i * 4 + 2, int(clampf(R[i] * g, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = true
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return [m, w]


static func _add(L: PackedFloat32Array, R: PackedFloat32Array, n: int, i: int, v: float, pan: float) -> void:
	var j := i % n
	L[j] += v * (1.0 - maxf(pan, 0.0))
	R[j] += v * (1.0 + minf(pan, 0.0))


static func _voice_pad(L: PackedFloat32Array, R: PackedFloat32Array, n: int, t0: float, dur: float, f: float, amp: float, pan: float) -> void:
	var count := int(dur * RATE)
	var s0 := int(t0 * RATE)
	var ph1 := 0.0
	var ph2 := 0.0
	var f2 := f * 1.004
	for i in count:
		var t := float(i) / RATE
		var env := minf(t / 0.9, 1.0) * minf((dur - t) / 1.1, 1.0)
		ph1 += f / RATE
		ph2 += f2 / RATE
		var v := (sin(TAU * ph1) + sin(TAU * ph2) + 0.35 * sin(TAU * ph1 * 2.0)) * amp * env * (0.85 + 0.15 * sin(t * 0.9))
		_add(L, R, n, s0 + i, v, pan)


static func _voice_bass(L: PackedFloat32Array, R: PackedFloat32Array, n: int, t0: float, dur: float, f: float, amp: float) -> void:
	var count := int(dur * RATE)
	var s0 := int(t0 * RATE)
	var ph := 0.0
	for i in count:
		var t := float(i) / RATE
		var env := minf(t / 0.015, 1.0) * exp(-t * (2.0 if dur > 1.0 else 5.0)) * minf((dur - t) / 0.05, 1.0)
		ph += f / RATE
		var v := (sin(TAU * ph) + 0.4 * sin(TAU * ph * 2.0) + 0.15 * sin(TAU * ph * 3.0)) * amp * env
		_add(L, R, n, s0 + i, v, 0.0)


static func _voice_pluck(L: PackedFloat32Array, R: PackedFloat32Array, n: int, t0: float, f: float, amp: float, pan: float) -> void:
	var count := int(0.45 * RATE)
	var s0 := int(t0 * RATE)
	var ph := 0.0
	for i in count:
		var t := float(i) / RATE
		var env := exp(-t * 9.0)
		ph += f / RATE
		var v := (sin(TAU * ph) + 0.5 * sin(TAU * ph * 2.0) * exp(-t * 14.0) + 0.25 * sin(TAU * ph * 3.0) * exp(-t * 20.0)) * amp * env
		_add(L, R, n, s0 + i, v, pan * 0.8)


static func _voice_bell(L: PackedFloat32Array, R: PackedFloat32Array, n: int, t0: float, f: float, amp: float, pan: float) -> void:
	var count := int(2.6 * RATE)
	var s0 := int(t0 * RATE)
	var p1 := 0.0
	var p2 := 0.0
	for i in count:
		var t := float(i) / RATE
		var env := exp(-t * 1.5) * minf(t / 0.004, 1.0)
		p1 += f / RATE
		p2 += f * 2.76 / RATE
		var v := (sin(TAU * p1) + 0.35 * sin(TAU * p2) * exp(-t * 3.0)) * amp * env
		_add(L, R, n, s0 + i, v, pan)


static func _voice_kick(L: PackedFloat32Array, R: PackedFloat32Array, n: int, t0: float, amp: float) -> void:
	var count := int(0.25 * RATE)
	var s0 := int(t0 * RATE)
	var ph := 0.0
	for i in count:
		var t := float(i) / RATE
		ph += (46.0 + 90.0 * exp(-t * 28.0)) / RATE
		_add(L, R, n, s0 + i, sin(TAU * ph) * exp(-t * 14.0) * amp, 0.0)


static func _voice_hat(L: PackedFloat32Array, R: PackedFloat32Array, n: int, t0: float, amp: float) -> void:
	var count := int(0.06 * RATE)
	var s0 := int(t0 * RATE)
	var prev := 0.0
	for i in count:
		var t := float(i) / RATE
		var nz := randf() * 2.0 - 1.0
		var hp := nz - prev
		prev = nz
		_add(L, R, n, s0 + i, hp * exp(-t * 70.0) * amp, 0.3)
