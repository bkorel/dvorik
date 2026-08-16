class_name DvorikKnock
extends RefCounted

## Короткий каменный стук. Без музыки и голоса.


static func make_stream() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.032)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * 95.0)
		var tap := sin(TAU * 520.0 * t) * 0.42
		var body := sin(TAU * 160.0 * t) * 0.28
		var grit := (rng.randf() * 2.0 - 1.0) * 0.22 * exp(-t * 140.0)
		var s := clampf((tap + body + grit) * env, -1.0, 1.0)
		var v := int(s * 26000.0)
		data.encode_s16(i * 2, v)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
