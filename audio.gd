extends Node
## 파일 없이 합성하는 드론 모터음, 바람, 신호 잡음, 효과음.

const RATE := 22050.0

var motor_player: AudioStreamPlayer
var pb: AudioStreamGeneratorPlayback
var ph := [0.0, 0.0, 0.0, 0.0]
var cf := [150.0, 150.0, 150.0, 150.0]
var lp1 := 0.0
var lp2 := 0.0
var cur_motor := 0.0
var cur_wind := 0.0
var cur_stat := 0.0
var sfx_players: Array[AudioStreamPlayer] = []
var s_coin: AudioStreamWAV
var s_beep: AudioStreamWAV
var s_buy: AudioStreamWAV
var s_deny: AudioStreamWAV
var s_crash: AudioStreamWAV
var s_chirp: AudioStreamWAV
var s_scream: AudioStreamWAV
var s_boom: AudioStreamWAV
var s_creak: AudioStreamWAV
var s_whisper: AudioStreamWAV
var s_knock: AudioStreamWAV
var s_steps: AudioStreamWAV
var s_giggle: AudioStreamWAV
var sfx_i := 0
var s_horn: AudioStreamWAV
var s_thunder: AudioStreamWAV
var s_ring: AudioStreamWAV
var s_sparkle: AudioStreamWAV
var s_whoosh: AudioStreamWAV
var lp3 := 0.0
var cb_players: Array[AudioStreamPlayer] = []
var cb_i := 0
var s_gun: AudioStreamWAV
var s_egun: AudioStreamWAV
var s_missile: AudioStreamWAV
var s_hit: AudioStreamWAV
var s_hurt: AudioStreamWAV
var s_lock: AudioStreamWAV
var s_lockok: AudioStreamWAV
var s_warn: AudioStreamWAV
var s_pick: AudioStreamWAV
var s_kill: AudioStreamWAV
var s_pop: AudioStreamWAV
var siren_ph := 0.0
var siren_t := 0.0
var cur_hum := 0.0
var cur_rain := 0.0
var cur_siren := 0.0


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	motor_player = AudioStreamPlayer.new()
	motor_player.stream = gen
	motor_player.bus = "SFX"
	motor_player.volume_db = -3.0
	add_child(motor_player)
	motor_player.play()
	pb = motor_player.get_stream_playback()
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)
	s_coin = _tone([1319.0, 1976.0], 0.55, 5.0, 0.5)
	s_beep = _tone([1800.0], 0.16, 14.0, 0.45)
	s_buy = _tone([660.0, 880.0, 1320.0], 0.5, 6.0, 0.45)
	s_deny = _tone([140.0], 0.2, 10.0, 0.5)
	s_crash = _noise(0.7, 5.0, 0.8)
	s_chirp = _chirp()
	s_scream = _scream()
	s_boom = _boom()
	s_creak = _creak()
	s_whisper = _whisper()
	s_knock = _knock()
	s_steps = _steps()
	s_giggle = _giggle()
	s_horn = _tone([415.0, 523.0], 0.38, 3.0, 0.4)
	s_thunder = _thunder()
	s_ring = _tone([880.0, 1320.0, 1760.0], 0.4, 7.0, 0.5)
	s_sparkle = _tone([1568.0, 2093.0, 2637.0, 3136.0], 0.9, 3.5, 0.45)
	s_whoosh = _noise(0.35, 7.0, 0.5)
	for i in 8:
		var cp := AudioStreamPlayer.new()
		cp.bus = "SFX"
		add_child(cp)
		cb_players.append(cp)
	s_gun = _gun()
	s_egun = _tone([300.0, 450.0], 0.09, 28.0, 0.32)
	s_missile = _noise(0.6, 4.0, 0.55)
	s_hit = _tone([1000.0, 1500.0], 0.06, 45.0, 0.55)
	s_hurt = _tone([110.0, 90.0], 0.3, 9.0, 0.8)
	s_lock = _tone([1500.0], 0.06, 30.0, 0.4)
	s_lockok = _tone([1900.0, 2500.0], 0.3, 7.0, 0.5)
	s_warn = _tone([1100.0, 880.0], 0.22, 6.0, 0.5)
	s_pick = _tone([880.0, 1320.0, 1760.0], 0.35, 7.0, 0.5)
	s_kill = _tone([440.0, 660.0, 990.0], 0.35, 7.0, 0.5)
	s_pop = _noise(0.18, 16.0, 0.5)


func _tone(freqs: Array, dur: float, decay: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := i / RATE
		var env := exp(-t * decay)
		var s := 0.0
		for f in freqs:
			s += sin(TAU * f * t)
		s = s / freqs.size() * env * vol
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.stereo = false
	w.data = data
	return w


## 짧은 새소리: 위로 훑는 세 번의 지저귐
func _chirp() -> AudioStreamWAV:
	var n := int(0.5 * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := i / RATE
		var s := 0.0
		var k := int(t / 0.14)
		var lt := t - k * 0.14
		if k < 3 and lt < 0.08:
			var f := 3000.0 + 1800.0 * (lt / 0.08) + k * 250.0
			phase += TAU * f / RATE
			s = sin(phase) * sin(PI * lt / 0.08) * 0.35
		data.encode_s16(i * 2, int(s * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.stereo = false
	w.data = data
	return w


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.stereo = false
	w.data = data
	return w


## 비명: 기본음이 솟았다가 떨어지고, 포먼트(목소리 공명) 근처 배음을 강조한다
func _scream() -> AudioStreamWAV:
	var n := int(1.15 * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := i / RATE
		var f0 := 380.0 + 540.0 * smoothstep(0.0, 0.4, t) - 330.0 * smoothstep(0.4, 1.15, t) + 22.0 * sin(t * 47.0)
		phase += f0 / RATE
		var s := 0.0
		for h in range(1, 9):
			var fh := h * f0
			var amp := exp(-pow((fh - 1300.0) / 700.0, 2.0)) + 0.4 * exp(-pow((fh - 2700.0) / 900.0, 2.0))
			s += sin(TAU * phase * h) * amp / sqrt(float(h))
		s += (randf() * 2.0 - 1.0) * 0.3
		var env := minf(t / 0.03, 1.0) * exp(-maxf(t - 0.5, 0.0) * 2.2)
		data.encode_s16(i * 2, int(clampf(s * env * 0.3, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _boom() -> AudioStreamWAV:
	var n := int(1.1 * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := i / RATE
		phase += (30.0 + 40.0 * exp(-t * 6.0)) / RATE
		lp += (randf() * 2.0 - 1.0 - lp) * 0.2
		var s := sin(TAU * phase) * exp(-t * 3.2) + lp * exp(-t * 14.0) * 0.8
		data.encode_s16(i * 2, int(clampf(s * 0.9, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _creak() -> AudioStreamWAV:
	var n := int(1.0 * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := i / RATE
		phase += (85.0 + 70.0 * t + 9.0 * sin(t * 31.0)) / RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		var am := 0.5 + 0.5 * sin(t * 23.0)
		var env := sin(PI * t / 1.0)
		data.encode_s16(i * 2, int(clampf(saw * am * env * 0.22, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _whisper() -> AudioStreamWAV:
	var n := int(1.6 * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var a := 0.0
	var b := 0.0
	for i in n:
		var t := i / RATE
		var nz := randf() * 2.0 - 1.0
		a += (nz - a) * 0.5
		b += (nz - b) * 0.12
		var band := a - b          # 대역 통과 느낌의 치찰음
		var env := sin(PI * t / 1.6)
		env *= 0.55 + 0.45 * sin(t * 9.0 + sin(t * 3.0) * 2.0)
		data.encode_s16(i * 2, int(clampf(band * env * 0.5, -1.0, 1.0) * 32767.0))
	return _wav(data)


## 문을 두드리는 소리: 세 번
func _knock() -> AudioStreamWAV:
	var n := int(1.0 * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var times := [0.0, 0.32, 0.6]
	for i in n:
		var t := i / RATE
		lp += (randf() * 2.0 - 1.0 - lp) * 0.3
		var s := 0.0
		for kt in times:
			var lt: float = t - kt
			if lt >= 0.0:
				s += sin(TAU * 85.0 * lt) * exp(-lt * 30.0) + lp * exp(-lt * 70.0) * 0.5
		data.encode_s16(i * 2, int(clampf(s * 0.8, -1.0, 1.0) * 32767.0))
	return _wav(data)


## 누군가 뛰어오는 발소리: 점점 빨라진다
func _steps() -> AudioStreamWAV:
	var n := int(2.0 * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var times: Array[float] = []
	var tt := 0.0
	var gap := 0.34
	while tt < 1.9:
		times.append(tt)
		tt += gap
		gap = maxf(gap * 0.88, 0.13)
	var lp := 0.0
	for i in n:
		var t := i / RATE
		lp += (randf() * 2.0 - 1.0 - lp) * 0.22
		var s := 0.0
		for st in times:
			var lt: float = t - st
			if lt >= 0.0 and lt < 0.15:
				s += lp * exp(-lt * 38.0) + sin(TAU * 70.0 * lt) * exp(-lt * 26.0) * 0.6
		data.encode_s16(i * 2, int(clampf(s * 0.9, -1.0, 1.0) * 32767.0))
	return _wav(data)


## 아이 웃음 비슷한 높은 소리
func _giggle() -> AudioStreamWAV:
	var n := int(1.3 * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := i / RATE
		var k := int(t / 0.2)
		var lt := t - k * 0.2
		var s := 0.0
		if k < 5 and lt < 0.13:
			var f := 720.0 + k * 35.0 + 60.0 * sin(lt * 50.0) - lt * 400.0
			phase += TAU * f / RATE
			s = (sin(phase) + 0.45 * sin(phase * 2.0) + 0.2 * sin(phase * 3.0)) * sin(PI * lt / 0.13) * 0.28
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _noise(dur: float, decay: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := i / RATE
		lp += (randf() * 2.0 - 1.0 - lp) * 0.35
		data.encode_s16(i * 2, int(clampf(lp * exp(-t * decay) * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.stereo = false
	w.data = data
	return w


## 전투 효과음 전용 재생기(총소리가 다른 소리를 끊지 않게 따로 돌린다)
func play_c(stream: AudioStreamWAV, vol_db: float = 0.0, pitch := 1.0) -> void:
	var p := cb_players[cb_i]
	cb_i = (cb_i + 1) % cb_players.size()
	p.stream = stream
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func _gun() -> AudioStreamWAV:
	var n := int(0.1 * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := i / RATE
		lp += (randf() * 2.0 - 1.0 - lp) * 0.6
		var s := lp * exp(-t * 55.0) * 0.8 + sin(TAU * 150.0 * t) * exp(-t * 38.0) * 0.6
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)


func gun() -> void: play_c(s_gun, -9.0, randf_range(0.92, 1.08))
func egun(db: float) -> void: play_c(s_egun, db, randf_range(0.9, 1.1))
func missile() -> void: play_c(s_missile, -3.0)
func explode(db: float) -> void: play_c(s_boom, db, randf_range(0.9, 1.15))
func hit() -> void: play_c(s_hit, -6.0, randf_range(0.9, 1.2))
func hurt() -> void: play_c(s_hurt, -1.0)
func lock_tick() -> void: play_c(s_lock, -8.0)
func lock_ok() -> void: play_c(s_lockok, -4.0)
func warn() -> void: play_c(s_warn, -5.0)
func pick() -> void: play_c(s_pick, -4.0)
func kill() -> void: play_c(s_kill, -3.0)
func pop(db: float) -> void: play_c(s_pop, db, randf_range(0.8, 1.2))


func play(stream: AudioStreamWAV, vol_db: float = 0.0) -> void:
	var p := sfx_players[sfx_i]
	sfx_i = (sfx_i + 1) % sfx_players.size()
	p.stream = stream
	p.volume_db = vol_db
	p.play()


func coin() -> void: play(s_coin, -4.0)
func beep() -> void: play(s_beep, -8.0)
func buy() -> void: play(s_buy, -4.0)
func deny() -> void: play(s_deny, -4.0)
func crash() -> void: play(s_crash, 0.0)
func chirp() -> void: play(s_chirp, -10.0 + randf_range(-3.0, 0.0))
func scream() -> void: play(s_scream, 2.0)
func boom() -> void: play(s_boom, 0.0)
func creak() -> void: play(s_creak, -6.0)
func whisper() -> void: play(s_whisper, -4.0)
func knock() -> void: play(s_knock, -2.0)
func steps() -> void: play(s_steps, -3.0)
func giggle() -> void: play(s_giggle, -5.0)
func ring() -> void: play(s_ring, -3.0)
func sparkle() -> void: play(s_sparkle, -2.0)
func whoosh() -> void: play(s_whoosh, -6.0)
func horn(db: float) -> void: play(s_horn, db)
func thunder(db: float) -> void: play(s_thunder, db)


## rpm 0..1, wind 0..1, stat(신호 잡음) 0..1, motor_on 0..1, hum(도시 소음) 0..1, rain 0..1, siren(경찰차) 0..1
func update(rpm: float, wind: float, stat: float, motor_on: float, hum := 0.0, rain := 0.0, siren := 0.0) -> void:
	if pb == null:
		return
	var frames := pb.get_frames_available()
	if frames <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(frames)
	var base := 150.0 + 520.0 * rpm
	for i in frames:
		cur_motor += (motor_on - cur_motor) * 0.0004
		cur_wind += (wind - cur_wind) * 0.0004
		cur_stat += (stat - cur_stat) * 0.001
		cur_hum += (hum - cur_hum) * 0.0002
		cur_rain += (rain - cur_rain) * 0.0004
		cur_siren += (siren - cur_siren) * 0.0006
		var s := 0.0
		for v in 4:
			cf[v] += (base * (1.0 + v * 0.017 + (v % 2) * 0.006) - cf[v]) * 0.002
			ph[v] += cf[v] / RATE
			if ph[v] > 1.0:
				ph[v] -= 1.0
			var p: float = ph[v] * TAU
			s += sin(p) + 0.5 * sin(p * 2.0) + 0.3 * sin(p * 3.0) + 0.12 * sin(p * 5.0)
		s *= 0.05 * cur_motor
		var nz := randf() * 2.0 - 1.0
		lp1 += (nz - lp1) * 0.14
		lp2 += (nz - lp2) * 0.012
		s += lp1 * 0.10 * cur_motor * (0.4 + rpm) + lp2 * 0.55 * cur_wind + nz * 0.12 * cur_stat
		lp3 += (nz - lp3) * 0.02
		s += lp3 * 0.9 * cur_hum + (nz - lp1) * 0.22 * cur_rain
		if cur_siren > 0.01:
			siren_t += 1.0 / RATE
			siren_ph += (760.0 + 260.0 * sin(siren_t * 4.2)) / RATE
			s += sin(TAU * siren_ph) * 0.08 * cur_siren
		s = tanh(s * 1.4)
		buf[i] = Vector2(s, s)
	pb.push_buffer(buf)

## 천둥: 낮게 길게 울린다
func _thunder() -> AudioStreamWAV:
	var n := int(2.6 * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := i / RATE
		var nz := randf() * 2.0 - 1.0
		lp += (nz - lp) * 0.06
		lp2 += (lp - lp2) * 0.2
		var env := minf(t / 0.08, 1.0) * exp(-t * 1.5) * (0.7 + 0.3 * sin(t * 13.0))
		data.encode_s16(i * 2, int(clampf(lp2 * 3.2 * env, -1.0, 1.0) * 32767.0))
	return _wav(data)
