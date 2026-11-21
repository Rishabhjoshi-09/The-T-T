extends Node2D

@export var play_with_ai := false
@export var ai_racket_speed := 270.0

const MAIN_MENU_PATH = "res://main_menu.tscn"
const SETTINGS_PATH = "user://the_tt_settings.cfg"
const SCORE_PANEL = preload("res://ui/score_panel.png")
const PLAYER_1_WIN = preload("res://ui/Player1Win.jpeg")
const PLAYER_2_WIN = preload("res://ui/Player2Win.jpeg")
const YOU_LOST = preload("res://ui/YouLost.jpeg")
const HIT_SPARK = preload("res://sprites/hit_spark.png")

const RACKET_SPEED = 450.0
const TOP_LIMIT = 162.0
const BOTTOM_LIMIT = 575.0
const RACKET_START_Y = 360.0

const BALL_START = Vector2(640, 280)
const START_SPEED = 560.0
const SPEED_PER_HIT = 25.0
const SPEED_PER_POINT = 30.0
const MAX_SPEED = 1150.0
const CENTER_HIT_RANGE = 12.0
const CENTER_HIT_MULTIPLIER = 1.65
const CENTER_HIT_MAX_SPEED = 1700.0
const SERVE_DELAY = 0.65

const BALL_TOP = 124.0
const BALL_BOTTOM = 613.0
const LEFT_EDGE = 115.0
const RIGHT_EDGE = 1164.0
const HIT_DISTANCE = 50.0
const HIT_HEIGHT = 50.0
const WIN_SCORE = 10
const MAX_HEALTH = 10

const INK = Color("#182824")
const CREAM = Color("#F4ECD9")
const GREEN = Color("#246452")
const YELLOW = Color("#E2B65F")
const RED = Color("#C64633")

@onready var racket_left: Sprite2D = $RacketLeft
@onready var racket_right: Sprite2D = $RacketRight
@onready var ball: Sprite2D = $Ball
@onready var hit_sound = $HitSound
@onready var point_sound = $PointSound
@onready var win_sound = $WinSound

var ball_velocity := Vector2.ZERO
var left_score := 0
var right_score := 0
var left_health := MAX_HEALTH
var right_health := MAX_HEALTH
var left_streak := 0
var right_streak := 0
var winner := 0
var rally_hits := 0
var serve_timer := 0.0
var first_serve_direction := 0.0

var score_label: Label
var fps_label: Label
var left_streak_label: Label
var right_streak_label: Label
var controls_label: Label
var difficulty_badge: Label
var health_hud: Control
var left_health_bar: ProgressBar
var right_health_bar: ProgressBar
var left_health_label: Label
var right_health_label: Label
var result_image: TextureRect
var result_fallback: Label
var pause_menu: ColorRect
var resume_button: Button
var miss_flash: ColorRect
var miss_tween: Tween

func _ready() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)

	var score_panel := TextureRect.new()
	score_panel.texture = SCORE_PANEL
	score_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	score_panel.position = Vector2(480, 12)
	score_panel.size = Vector2(320, 56)
	score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(score_panel)

	score_label = add_label(overlay, Vector2(480, 12), Vector2(320, 56), 28)
	score_label.add_theme_color_override("font_color", CREAM)

	left_streak_label = add_label(overlay, Vector2(260, 69), Vector2(180, 24), 18)
	right_streak_label = add_label(overlay, Vector2(840, 69), Vector2(180, 24), 18)
	left_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	right_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	controls_label = add_label(overlay, Vector2(0, 667), Vector2(1280, 32), 20)
	var controls_text := "Move: W / S" if play_with_ai else "P1: W / S   |   P2: ↑ / ↓"
	controls_label.text = "FIRST TO %d WINS   •   %s   •   Esc: Pause" % [WIN_SCORE, controls_text]

	fps_label = add_label(overlay, Vector2(1054, 667), Vector2(130, 32), 18)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()

	if play_with_ai:
		add_difficulty_badge(overlay)
	build_health_hud(overlay)

	miss_flash = ColorRect.new()
	miss_flash.color = Color("#FF4938")
	miss_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	miss_flash.hide()
	overlay.add_child(miss_flash)

	result_image = TextureRect.new()
	result_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_image.stretch_mode = TextureRect.STRETCH_SCALE
	result_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(result_image)
	result_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_image.hide()

	result_fallback = add_label(overlay, Vector2(0, 667), Vector2(1280, 32), 22)
	result_fallback.text = "YOU WON!   |   Enter to return to menu"
	result_fallback.hide()

	build_pause_menu(overlay)
	apply_saved_appearance()
	update_scoreboard()
	reset_ball()
	serve_ball()


func _process(_delta: float) -> void:
	if fps_label.visible:
		var fps_text := "%d FPS" % Engine.get_frames_per_second()
		if fps_label.text != fps_text:
			fps_label.text = fps_text


func apply_saved_appearance() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) != OK:
		return
	if not bool(settings.get_value("settings", "dark_mode", false)):
		return

	$Floor.modulate = Color("#141418")
	$Table.modulate = Color("#7C8780")

	for label in [
		controls_label, fps_label, left_streak_label, right_streak_label,
		left_health_label, right_health_label, result_fallback
	]:
		label.add_theme_color_override("font_color", CREAM)


func add_label(parent: Node, at: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	parent.add_child(label)
	return label


func make_color_style(fill: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	return style


func add_difficulty_badge(overlay: CanvasLayer) -> void:
	var difficulty := "Medium"
	var fill := YELLOW
	var text_color := INK

	if is_equal_approx(ai_racket_speed, 180.0):
		difficulty = "Easy"
		fill = GREEN
		text_color = CREAM
	elif is_equal_approx(ai_racket_speed, 390.0):
		difficulty = "Hard"
		fill = RED
		text_color = CREAM

	difficulty_badge = add_label(overlay, Vector2(96, 20), Vector2(180, 40), 20)
	difficulty_badge.text = "Difficulty: " + difficulty
	difficulty_badge.add_theme_stylebox_override("normal", make_color_style(fill, 8))
	difficulty_badge.add_theme_color_override("font_color", text_color)


func build_health_hud(overlay: CanvasLayer) -> void:
	health_hud = Control.new()
	health_hud.position = Vector2(96, 61 if play_with_ai else 21)
	health_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(health_hud)

	var label_size := Vector2(145, 19)
	left_health_label = add_label(health_hud, Vector2(0, 0), label_size, 15)
	right_health_label = add_label(health_hud, Vector2(943, 0), label_size, 15)
	left_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	right_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	left_health_bar = add_health_bar(Vector2(0, 21))
	right_health_bar = add_health_bar(Vector2(943, 21))


func add_health_bar(at: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = at
	bar.max_value = MAX_HEALTH
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", make_color_style(INK, 4))
	health_hud.add_child(bar)
	bar.size = Vector2(145, 10)
	return bar


func update_health_bar(bar: ProgressBar, health: int) -> void:
	var fill := GREEN
	if health <= 3:
		fill = RED
	elif health <= 6:
		fill = YELLOW

	bar.add_theme_stylebox_override("fill", make_color_style(fill, 4))
	bar.value = health


func build_pause_menu(overlay: CanvasLayer) -> void:
	pause_menu = ColorRect.new()
	pause_menu.color = Color(0.04, 0.08, 0.06, 0.78)
	overlay.add_child(pause_menu)
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	pause_menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var options := VBoxContainer.new()
	options.custom_minimum_size.x = 280.0
	options.add_theme_constant_override("separation", 12)
	center.add_child(options)

	var title := Label.new()
	title.text = "MATCH PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", CREAM)
	options.add_child(title)

	resume_button = add_pause_button(options, "Resume", resume_match)
	add_pause_button(options, "Restart Match", restart_match)
	add_pause_button(options, "Main Menu", return_to_menu)
	pause_menu.hide()


func add_pause_button(options: VBoxContainer, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 48.0
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	options.add_child(button)
	return button


func resume_match() -> void:
	resume_button.release_focus()
	pause_menu.hide()


func restart_match() -> void:
	left_score = 0
	right_score = 0
	left_health = MAX_HEALTH
	right_health = MAX_HEALTH
	left_streak = 0
	right_streak = 0
	first_serve_direction = 0.0

	if miss_tween != null and miss_tween.is_valid():
		miss_tween.kill()
	miss_flash.hide()

	racket_left.position.y = RACKET_START_Y
	racket_right.position.y = RACKET_START_Y
	update_scoreboard()
	reset_ball()
	resume_match()
	serve_ball()


func return_to_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _physics_process(delta: float) -> void:
	if winner != 0 or pause_menu.visible:
		return

	move_rackets(delta)
	if ball_velocity == Vector2.ZERO:
		serve_timer -= delta
		if serve_timer <= 0.0:
			serve_ball()
		return

	move_ball(delta)


func _input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if winner != 0:
		if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			return_to_menu()
		return

	if key_event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if pause_menu.visible:
			resume_match()
		else:
			pause_menu.show()
			resume_button.grab_focus()


func get_ball_speed() -> float:
	var point_bonus := (left_score + right_score) * SPEED_PER_POINT
	var hit_bonus := rally_hits * SPEED_PER_HIT
	return minf(START_SPEED + point_bonus + hit_bonus, MAX_SPEED)


func serve_ball() -> void:
	var total_points := left_score + right_score
	var first_direction := 1.0 if play_with_ai else -1.0
	if first_serve_direction != 0.0:
		first_direction = first_serve_direction

	var direction := first_direction if total_points % 2 == 0 else -first_direction
	ball_velocity = Vector2(direction * get_ball_speed(), 110.0)


func reset_ball() -> void:
	ball.position = BALL_START
	ball_velocity = Vector2.ZERO
	rally_hits = 0
	serve_timer = SERVE_DELAY


func move_rackets(delta: float) -> void:
	var left_direction := 0.0
	if Input.is_physical_key_pressed(KEY_W):
		left_direction -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		left_direction += 1.0

	racket_left.position.y = clampf(
		racket_left.position.y + left_direction * RACKET_SPEED * delta,
		TOP_LIMIT, BOTTOM_LIMIT
	)

	if play_with_ai:
		var target_y := RACKET_START_Y
		if ball_velocity.x > 0.0:
			target_y = clampf(ball.position.y, TOP_LIMIT, BOTTOM_LIMIT)

		racket_right.position.y = move_toward(
			racket_right.position.y, target_y, ai_racket_speed * delta
		)
		return

	var right_direction := 0.0
	if Input.is_physical_key_pressed(KEY_UP):
		right_direction -= 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		right_direction += 1.0

	racket_right.position.y = clampf(
		racket_right.position.y + right_direction * RACKET_SPEED * delta,
		TOP_LIMIT, BOTTOM_LIMIT
	)


func move_ball(delta: float) -> void:
	var previous_position := ball.position
	ball.position += ball_velocity * delta

	if ball.position.y < BALL_TOP or ball.position.y > BALL_BOTTOM:
		ball.position.y = clampf(ball.position.y, BALL_TOP, BALL_BOTTOM)
		ball_velocity.y *= -1.0

	if ball_velocity.x > 0.0:
		var right_face := racket_right.position.x - HIT_DISTANCE
		if previous_position.x <= right_face and ball.position.x >= right_face:
			bounce_off_racket(racket_right, right_face, -1.0, previous_position)
	else:
		var left_face := racket_left.position.x + HIT_DISTANCE
		if previous_position.x >= left_face and ball.position.x <= left_face:
			bounce_off_racket(racket_left, left_face, 1.0, previous_position)

	if ball.position.x < LEFT_EDGE:
		score_point(2)
	elif ball.position.x > RIGHT_EDGE:
		score_point(1)


func bounce_off_racket(
	racket: Sprite2D, face_x: float, direction: float, previous_position: Vector2
) -> void:
	var hit_fraction := inverse_lerp(previous_position.x, ball.position.x, face_x)
	var hit_y := lerpf(previous_position.y, ball.position.y, hit_fraction)
	var hit_offset := hit_y - racket.position.y
	if absf(hit_offset) > HIT_HEIGHT:
		return

	rally_hits += 1
	if racket == racket_left:
		left_streak += 1
	else:
		right_streak += 1
	update_streak_labels()

	var speed := get_ball_speed()
	if absf(hit_offset) <= CENTER_HIT_RANGE:
		speed = minf(speed * CENTER_HIT_MULTIPLIER, CENTER_HIT_MAX_SPEED)

	hit_sound.play()
	spawn_hit_spark(Vector2(face_x, hit_y), direction)
	ball.position = Vector2(face_x, hit_y)
	ball_velocity = Vector2(direction * speed, hit_offset / HIT_HEIGHT * 340.0)


func spawn_hit_spark(hit_position: Vector2, direction: float) -> void:
	var spark := Sprite2D.new()
	spark.texture = HIT_SPARK
	spark.position = hit_position
	spark.flip_h = direction < 0.0
	spark.z_index = 5
	spark.scale = Vector2(0.7, 0.7)
	add_child(spark)

	var tween := spark.create_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "scale", Vector2(1.2, 1.2), 0.18)
	tween.tween_property(spark, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(spark.queue_free)


func score_point(player: int) -> void:
	point_sound.play()

	if player == 1:
		left_score += 1
		right_streak = 0
		left_health = mini(left_health + 1, MAX_HEALTH)
		right_health = maxi(right_health - 1, 0)
		if left_score >= WIN_SCORE:
			winner = 1
	else:
		right_score += 1
		left_streak = 0
		right_health = mini(right_health + 1, MAX_HEALTH)
		left_health = maxi(left_health - 1, 0)
		if right_score >= WIN_SCORE:
			winner = 2

	reset_ball()
	update_scoreboard()
	play_miss_effect(player == 2)

	if winner != 0:
		show_result()


func play_miss_effect(missed_left: bool) -> void:
	if miss_tween != null and miss_tween.is_valid():
		miss_tween.kill()

	var start_x := LEFT_EDGE if missed_left else BALL_START.x
	var end_x := BALL_START.x if missed_left else RIGHT_EDGE
	miss_flash.position = Vector2(start_x, BALL_TOP)
	miss_flash.size = Vector2(end_x - start_x, BALL_BOTTOM - BALL_TOP)
	miss_flash.modulate.a = 0.0
	miss_flash.show()

	miss_tween = miss_flash.create_tween()
	miss_tween.tween_property(miss_flash, "modulate:a", 0.26, 0.04)
	miss_tween.tween_property(miss_flash, "modulate:a", 0.08, 0.06)
	miss_tween.tween_property(miss_flash, "modulate:a", 0.20, 0.04)
	miss_tween.tween_property(miss_flash, "modulate:a", 0.0, 0.16)
	miss_tween.tween_callback(miss_flash.hide)


func update_streak_labels() -> void:
	var right_name := "AI" if play_with_ai else "P2"
	left_streak_label.text = "P1 Streak: %d" % left_streak
	right_streak_label.text = "%s Streak: %d" % [right_name, right_streak]


func update_scoreboard() -> void:
	var right_name := "AI" if play_with_ai else "P2"
	score_label.text = "P1   %d  –  %d   %s" % [left_score, right_score, right_name]
	left_health_label.text = "P1 HP  %d/%d" % [left_health, MAX_HEALTH]
	right_health_label.text = "%s HP  %d/%d" % [right_name, right_health, MAX_HEALTH]
	update_health_bar(left_health_bar, left_health)
	update_health_bar(right_health_bar, right_health)
	update_streak_labels()


func show_result() -> void:
	controls_label.hide()
	fps_label.hide()
	left_streak_label.hide()
	right_streak_label.hide()
	health_hud.hide()
	if difficulty_badge != null:
		difficulty_badge.hide()

	if play_with_ai:
		result_image.texture = load_you_won_image() if winner == 1 else YOU_LOST
	else:
		result_image.texture = PLAYER_1_WIN if winner == 1 else PLAYER_2_WIN

	if result_image.texture != null:
		result_image.show()
	else:
		result_fallback.show()

	if not play_with_ai or winner == 1:
		win_sound.play()


func load_you_won_image() -> Texture2D:
	for path in ["res://ui/YouWon.png", "res://ui/YouWon.jpeg", "res://ui/YouWon(1).jpeg"]:
		if ResourceLoader.exists(path, "Texture2D"):
			var texture := load(path) as Texture2D
			if texture != null:
				return texture
	return null
