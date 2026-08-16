class_name DvorikKnock
extends RefCounted

## Короткий деревянный стук. Без музыки и голоса.


static func make_stream() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.045)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * 55.0)
		var click := sin(TAU * 180.0 * t) * 0.55
		var thump := sin(TAU * 90.0 * t) * 0.35
		var noise := (rng.randf() * 2.0 - 1.0) * 0.18
		var s := clampf((click + thump + noise) * env, -1.0, 1.0)
		var v := int(s * 28000.0)
		data.encode_s16(i * 2, v)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
