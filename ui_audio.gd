extends Node
## 메뉴 효과음과 배경음악. 게임 월드가 없어도 항상 살아 있다.

const MusicScript := preload("res://music.gd")
const RATE := 22050

var music: Node
var players: Array[AudioStreamPlayer] = []
var i := 0
var s := {}


func _ready() -> void:
	_buses()
	music = MusicScript.new()
	add_child(music)
	for k in 4:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
	s.hover = _blip([2200.0], 0.035, 60.0, 0.18, 0.0)
	s.click = _blip([900.0, 1350.0], 0.07, 40.0, 0.3, 0.0)
	s.back = _blip([620.0, 410.0], 0.1, 28.0, 0.28, -0.4)
	s.error = _blip([180.0, 150.0], 0.2, 12.0, 0.35, 0.0)
	s.confirm = _arp([523.0, 659.0, 784.0, 1047.0], 0.09, 0.4)
	s.jingle = _arp([523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0], 0.11, 0.42)
	s.fail = _arp([392.0, 330.0, 262.0, 196.0], 0.14, 0.4)
	s.start = _arp([440.0, 660.0, 880.0], 0.08, 0.4)
	s.rank = _arp([392.0, 523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0], 0.1, 0.42)
	s.shutter = _shutter()


## 마스터·음악·효과 버스를 만든다
func _buses() -> void:
	for nm in ["Music", "SFX"]:
		if AudioServer.get_bus_index(nm) < 0:
			AudioServer.add_bus()
			var ix := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(ix, nm)
			AudioServer.set_bus_send(ix, "Master")


func set_volumes(music_v: float, sfx_v: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_v, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_v, 0.0001)))


func play(name: String, db := 0.0) -> void:
	var p := players[i]
	i = (i + 1) % players.size()
	p.stream = s[name]
	p.volume_db = db
	p.play()


func click() -> void: play("click", -4.0)
func hover() -> void: play("hover", -10.0)
func back() -> void: play("back", -4.0)
func error() -> void: play("error", -3.0)
func confirm() -> void: play("confirm", -4.0)
func jingle() -> void: play("jingle", -3.0)
func fail() -> void: play("fail", -3.0)
func start() -> void: play("start", -3.0)
func rank() -> void: play("rank", -2.0)
func shutter() -> void: play("shutter", -2.0)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


func _blip(freqs: Array, dur: float, decay: float, vol: float, slide: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := [0.0, 0.0, 0.0]
	for k in n:
		var t := float(k) / RATE
		var v := 0.0
		for fi in freqs.size():
			ph[fi] += float(freqs[fi]) * (1.0 + slide * t / dur) / RATE
			v += sin(TAU * ph[fi])
		v = v / freqs.size() * exp(-t * decay) * vol
		data.encode_s16(k * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


## 음을 순서대로 울리는 짧은 팡파르
func _arp(freqs: Array, gap: float, vol: float) -> AudioStreamWAV:
	var n := int((gap * freqs.size() + 0.7) * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for fi in freqs.size():
		var s0 := int(fi * gap * RATE)
		var ph := 0.0
		for k in int(0.6 * RATE):
			if s0 + k >= n:
				break
			var t := float(k) / RATE
			ph += float(freqs[fi]) / RATE
			buf[s0 + k] += (sin(TAU * ph) + 0.4 * sin(TAU * ph * 2.0)) * exp(-t * 6.0) * vol * 0.6
	for k in n:
		data.encode_s16(k * 2, int(clampf(buf[k], -1.0, 1.0) * 32767.0))
	return _wav(data)


func _shutter() -> AudioStreamWAV:
	var n := int(0.18 * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for k in n:
		var t := float(k) / RATE
		lp += (randf() * 2.0 - 1.0 - lp) * 0.5
		var late: float = 1.0 if t >= 0.08 else 0.0
		var v: float = lp * (exp(-t * 90.0) + 0.8 * exp(-maxf(t - 0.08, 0.0) * 80.0) * late) * 0.7
		data.encode_s16(k * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)
