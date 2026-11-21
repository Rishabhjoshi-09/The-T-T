extends Node

const CREAM = Color("#F4ECD9")
const RED = Color("#EF4036")
const SCORE_PULSE = Color("#FF8B77")
const SAMPLE_RATE = 22050
const BEAT_SECONDS = 0.28

@onready var match_node: Node = get_parent()

var effect_layer: CanvasLayer
var alert_border: Panel
var banner: Label
var music: AudioStreamPlayer
var is_active := false
var pulse_time := 0.0


func _ready() -> void:
	effect_layer = CanvasLayer.new()
	effect_layer.layer = 11
	add_child(effect_layer)

	var border_style := StyleBoxFlat.new()
	border_style.draw_center = false
	border_style.border_color = RED
	border_style.set_border_width_all(5)

	alert_border = Panel.new()
	alert_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_border.add_theme_stylebox_override("panel", border_style)
	effect_layer.add_child(alert_border)
	alert_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color("#A72E29")
	banner_style.set_corner_radius_all(5)

	banner = Label.new()
	banner.text = "MATCH POINT!"
	banner.position = Vector2(550, 70)
	banner.size = Vector2(180, 23)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("normal", banner_style)
	banner.add_theme_color_override("font_color", CREAM)
	banner.add_theme_font_size_override("font_size", 17)
	effect_layer.add_child(banner)

	music = AudioStreamPlayer.new()
	music.stream = build_tension_music()
	music.volume_db = -13.0
	add_child(music)

	effect_layer.hide()


func _process(delta: float) -> void:
	var score := match_node.get("score_label") as Label
	var pause_menu := match_node.get("pause_menu") as ColorRect
	if score == null or pause_menu == null:
		return

	var match_point := (
		int(match_node.get("winner")) == 0
		and (
			int(match_node.get("left_score")) >= 9
			or int(match_node.get("right_score")) >= 9
			or int(match_node.get("left_health")) <= 1
			or int(match_node.get("right_health")) <= 1
		)
	)

	if not match_point:
		if is_active:
			is_active = false
			music.stop()
			effect_layer.hide()
			score.self_modulate = Color.WHITE
		return

	if not is_active:
		is_active = true
		pulse_time = 0.0
		music.play()

	effect_layer.visible = not pause_menu.visible
	music.stream_paused = pause_menu.visible

	if pause_menu.visible:
		score.self_modulate = Color.WHITE
		return

	pulse_time += delta
	var pulse := 0.5 + 0.5 * sin(pulse_time * TAU * 1.4)
	alert_border.modulate.a = lerpf(0.60, 1.0, pulse)
	score.self_modulate = Color.WHITE.lerp(SCORE_PULSE, pulse)


func build_tension_music() -> AudioStreamWAV:
	var notes := [110.0, 130.81, 110.0, 155.56, 110.0, 130.81, 155.56, 164.81]
	var samples_per_beat := roundi(SAMPLE_RATE * BEAT_SECONDS)
	var total_samples := samples_per_beat * notes.size()
	var data := PackedByteArray()
	data.resize(total_samples * 2)

	for beat in range(notes.size()):
		var frequency: float = notes[beat]
		for sample in range(samples_per_beat):
			var time := float(sample) / SAMPLE_RATE
			var envelope := minf(time / 0.012, 1.0) * pow(1.0 - time / BEAT_SECONDS, 2.0)
			var tone := sin(TAU * frequency * time)
			tone += 0.35 * sin(TAU * frequency * 2.0 * time)
			var offset := (beat * samples_per_beat + sample) * 2
			data.encode_s16(offset, roundi(tone * envelope * 15000.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples
	return stream
