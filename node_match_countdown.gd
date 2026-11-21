extends Node

const COUNTDOWN_SECONDS := 3.0
const PLAY_MESSAGE_SECONDS := 0.45
const TOSS_DURATION := 1.65
const COIN_FACE_DURATION := 0.33

const CREAM := Color("#F4ECD9")
const INK := Color("#182824")
const GOLD := Color("#E2B65F")
const FLAME_ORANGE := Color("#F46A23")
const FLAME_YELLOW := Color("#FFD05A")

@onready var match_node: Node = get_parent()

var countdown_panel: VBoxContainer
var countdown_label: Label
var toss_label: Label
var coin_label: Label
var winner_panel: HBoxContainer
var winner_label: Label
var winner_flame: Node2D
var left_streak_label: Label
var right_streak_label: Label
var left_flame: Node2D
var right_flame: Node2D
var pause_menu: Control

var remaining := 0.0
var counting_down := false
var play_started := false
var first_server := 1
var right_name := "P2"


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	countdown_panel = VBoxContainer.new()
	countdown_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_panel.add_theme_constant_override("separation", 6)
	center.add_child(countdown_panel)

	countdown_label = make_label("", 86, 12)
	countdown_panel.add_child(countdown_label)

	var coin_row := CenterContainer.new()
	coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_panel.add_child(coin_row)

	coin_label = make_label("", 22, 0)
	coin_label.custom_minimum_size = Vector2(58, 58)
	coin_label.add_theme_color_override("font_color", INK)
	var coin_style := StyleBoxFlat.new()
	coin_style.bg_color = GOLD
	coin_style.border_color = Color("#9E6C28")
	coin_style.set_border_width_all(3)
	coin_style.set_corner_radius_all(29)
	coin_label.add_theme_stylebox_override("normal", coin_style)
	coin_row.add_child(coin_label)

	toss_label = make_label("", 24, 6)
	countdown_panel.add_child(toss_label)
	countdown_panel.hide()

	var winner_center := CenterContainer.new()
	winner_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(winner_center)
	winner_center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	winner_center.offset_top = 32.0
	winner_center.offset_bottom = 96.0

	winner_panel = HBoxContainer.new()
	winner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	winner_panel.add_theme_constant_override("separation", 12)
	winner_center.add_child(winner_panel)

	var flame_space := Control.new()
	flame_space.custom_minimum_size = Vector2(52, 50)
	flame_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	winner_panel.add_child(flame_space)
	winner_flame = make_flame(flame_space)
	winner_flame.position = Vector2(26, 25)

	winner_label = make_label("", 25, 7)
	winner_panel.add_child(winner_label)
	winner_panel.hide()

	match_node.ready.connect(setup_match, CONNECT_ONE_SHOT)


func setup_match() -> void:
	right_name = "AI" if bool(match_node.get("play_with_ai")) else "P2"

	left_streak_label = match_node.get("left_streak_label") as Label
	right_streak_label = match_node.get("right_streak_label") as Label
	left_flame = make_flame(left_streak_label)
	right_flame = make_flame(right_streak_label)

	pause_menu = match_node.get("pause_menu") as Control
	for node in pause_menu.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == "Restart Match":
			button.pressed.connect(start_countdown)
			break

	start_countdown()


func start_countdown() -> void:
	match_node.set_physics_process(false)
	first_server = randi_range(1, 2)
	remaining = COUNTDOWN_SECONDS
	counting_down = true
	play_started = false
	countdown_label.text = "3"
	coin_label.text = "P1"
	coin_label.scale = Vector2.ONE
	toss_label.text = "Coin toss…"
	countdown_panel.show()
	winner_panel.hide()


func _process(delta: float) -> void:
	if left_flame == null or right_flame == null:
		return

	var winner := int(match_node.get("winner"))
	var left_streak := int(match_node.get("left_streak"))
	var right_streak := int(match_node.get("right_streak"))

	if winner != 0:
		countdown_panel.hide()
		if not winner_panel.visible:
			var winning_streak := left_streak if winner == 1 else right_streak
			var winner_name := "P1" if winner == 1 else right_name
			winner_label.text = "%s  •  Final streak: %d" % [winner_name, winning_streak]
			winner_label.add_theme_font_size_override("font_size", 25 + mini(winning_streak, 10))
			update_flame(winner_flame, maxi(1, winning_streak))
			winner_panel.show()
		return

	update_streak_visual(left_streak_label, left_flame, left_streak, false)
	update_streak_visual(right_streak_label, right_flame, right_streak, true)

	if not counting_down:
		return

	countdown_panel.visible = not pause_menu.visible
	if pause_menu.visible:
		return

	remaining -= delta
	if remaining > 0.0:
		countdown_label.text = str(ceili(remaining))
		animate_coin(COUNTDOWN_SECONDS - remaining)
		return

	if not play_started:
		play_started = true
		remaining = 0.0
		countdown_label.text = "PLAY!"
		animate_coin(TOSS_DURATION)
		var direction:= 1.0 if first_server == 1 else -1.0
		match_node.set("first_serve_direction", direction)
		match_node.call("serve_ball")
		match_node.set_physics_process(true)
		return

	if remaining <= -PLAY_MESSAGE_SECONDS:
		counting_down = false
		countdown_panel.hide()


func animate_coin(elapsed: float) -> void:
	coin_label.pivot_offset = coin_label.size * 0.5
	if elapsed < TOSS_DURATION:
		var turns := elapsed / COIN_FACE_DURATION
		coin_label.text = "P1" if floori(turns) % 2 == 0 else right_name
		coin_label.scale.x = maxf(0.12, absf(cos(turns * PI)))
		return

	coin_label.scale = Vector2.ONE
	var server_name := "P1" if first_server == 1 else right_name
	coin_label.text = server_name
	toss_label.text = server_name + " serves first"


func update_streak_visual(label: Label, flame: Node2D, streak: int, right_aligned: bool) -> void:
	var font_size := 18 + mini(streak, 10)
	if label.get_theme_font_size("font_size") != font_size:
		label.add_theme_font_size_override("font_size", font_size)

	update_flame(flame, streak)
	if streak == 0:
		return

	var font := label.get_theme_font("font")
	var text_width := font.get_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x
	var gap := 6.0 + 10.0 * flame.scale.x
	var flame_x := label.size.x - text_width - gap if right_aligned else text_width + gap
	flame.position = Vector2(flame_x, label.size.y * 0.5)


func make_label(caption: String, font_size: int, outline_size: int) -> Label:
	var label := Label.new()
	label.text = caption
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CREAM)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", outline_size)
	return label


func make_flame(parent: Control) -> Node2D:
	var flame := Node2D.new()
	parent.add_child(flame)

	var outer := Polygon2D.new()
	outer.color = FLAME_ORANGE
	outer.polygon = PackedVector2Array([
		Vector2(0, -12), Vector2(7, -5), Vector2(10, 1),
		Vector2(7, 8), Vector2(0, 11), Vector2(-7, 8),
		Vector2(-10, 2), Vector2(-6, -5), Vector2(-3, 0)
	])
	flame.add_child(outer)

	var inner := Polygon2D.new()
	inner.color = FLAME_YELLOW
	inner.polygon = PackedVector2Array([
		Vector2(1, -4), Vector2(5, 2), Vector2(4, 7),
		Vector2(0, 9), Vector2(-4, 6), Vector2(-4, 2)
	])
	flame.add_child(inner)

	flame.hide()
	return flame


func update_flame(flame: Node2D, streak: int) -> void:
	flame.visible = streak > 0
	flame.scale = Vector2.ONE * (0.55 + mini(streak, 10) * 0.17)
