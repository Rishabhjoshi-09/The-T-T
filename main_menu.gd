extends Control

const MATCH_SCENE = preload("res://match.tscn")
const BUTTON_NORMAL = preload("res://ui/button_normal.png")
const BUTTON_HOVER = preload("res://ui/button_hover.png")
const BUTTON_PRESSED = preload("res://ui/button_pressed.png")
const BUTTON_DISABLED = preload("res://ui/button_disabled.png")

const SETTINGS_PATH = "user://the_tt_settings.cfg"
const FPS_OPTIONS = [30, 60, 120, 0]
const INK = Color("#182824")
const CREAM = Color("#F4ECD9")
const GOLD = Color("#E2B65F")

@onready var background: TextureRect = $Background
@onready var two_players_button: Button = $TwoPlayersButton
@onready var play_with_ai_button: Button = $PlayWithAIButton

var settings := ConfigFile.new()
var volume := 100.0
var dark_mode := false
var fps_index := 1
var settings_button: Button
var settings_panel: PanelContainer
var difficulty_list: VBoxContainer
var easy_button: Button


func _ready() -> void:
	settings.load(SETTINGS_PATH)
	volume = clampf(float(settings.get_value("settings", "volume", 100.0)), 0.0, 100.0)
	dark_mode = bool(settings.get_value("settings", "dark_mode", false))
	fps_index = clampi(int(settings.get_value("settings", "fps_index", 1)), 0, 3)

	build_settings_panel()
	build_difficulty_list()

	two_players_button.pressed.connect(start_match.bind(false, 270.0), CONNECT_DEFERRED)
	play_with_ai_button.pressed.connect(toggle_difficulty_list)

	apply_settings()


func build_settings_panel() -> void:
	settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.position = Vector2(24, 20)
	settings_button.size = Vector2(140, 40)
	settings_button.pressed.connect(toggle_settings_panel)
	add_child(settings_button)

	settings_panel = PanelContainer.new()
	settings_panel.position = Vector2(24, 68)
	settings_panel.custom_minimum_size.x = 260
	settings_panel.z_index = 5
	add_child(settings_panel)

	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 8)
	settings_panel.add_child(options)

	var volume_label := add_setting_label(options, "Sound: %d%%" % int(volume))
	var slider := HSlider.new()
	slider.max_value = 100
	slider.step = 1
	slider.value = volume
	options.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void:
		volume = value
		volume_label.text = "Sound: %d%%" % int(value)
		save_settings()
	)

	add_setting_label(options, "Appearance")
	var mode := OptionButton.new()
	mode.add_item("Light")
	mode.add_item("Dark")
	mode.select(1 if dark_mode else 0)
	options.add_child(mode)
	mode.item_selected.connect(func(index: int) -> void:
		dark_mode = index == 1
		save_settings()
	)

	add_setting_label(options, "FPS limit")
	var fps := OptionButton.new()
	for caption in ["30 FPS", "60 FPS", "120 FPS", "Unlimited"]:
		fps.add_item(caption)
	fps.select(fps_index)
	options.add_child(fps)
	fps.item_selected.connect(func(index: int) -> void:
		fps_index = index
		save_settings()
	)

	var done := Button.new()
	done.text = "Done"
	done.pressed.connect(settings_panel.hide)
	options.add_child(done)
	settings_panel.hide()


func add_setting_label(parent: VBoxContainer, caption: String) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override("font_color", CREAM)
	parent.add_child(label)
	return label


func toggle_settings_panel() -> void:
	difficulty_list.hide()
	settings_panel.visible = not settings_panel.visible


func save_settings() -> void:
	settings.set_value("settings", "volume", volume)
	settings.set_value("settings", "dark_mode", dark_mode)
	settings.set_value("settings", "fps_index", fps_index)
	settings.save(SETTINGS_PATH)
	apply_settings()


func apply_settings() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, volume <= 0.0)
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(volume / 100.0, 0.001)))

	Engine.max_fps = FPS_OPTIONS[fps_index]
	background.modulate = Color("#747E80") if dark_mode else Color.WHITE

	var panel_style := color_style(Color("#233730") if dark_mode else INK, GOLD)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 14
	settings_panel.add_theme_stylebox_override("panel", panel_style)

	style_main_button(two_players_button)
	style_main_button(play_with_ai_button)
	style_color_button(settings_button, INK, CREAM, 19)


func build_difficulty_list() -> void:
	difficulty_list = VBoxContainer.new()
	difficulty_list.add_theme_constant_override("separation", 8)
	add_child(difficulty_list)

	easy_button = add_difficulty_button("Easy", Color("#246452"), CREAM, 180.0)
	add_difficulty_button("Medium", GOLD, INK, 270.0)
	add_difficulty_button("Hard", Color("#C64633"), CREAM, 390.0)

	difficulty_list.hide()


func add_difficulty_button(caption: String, fill: Color, text_color: Color, speed: float) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(160, 44)
	style_color_button(button, fill, text_color, 22)
	button.pressed.connect(start_match.bind(true, speed), CONNECT_DEFERRED)
	difficulty_list.add_child(button)
	return button


func toggle_difficulty_list() -> void:
	settings_panel.hide()
	if difficulty_list.visible:
		difficulty_list.hide()
		return

	var ai_button_rect := play_with_ai_button.get_rect()
	difficulty_list.position = Vector2(ai_button_rect.end.x + 16, ai_button_rect.position.y)
	difficulty_list.show()
	easy_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if settings_panel.visible:
		settings_panel.hide()
		settings_button.grab_focus()
	elif difficulty_list.visible:
		difficulty_list.hide()
		play_with_ai_button.grab_focus()


func start_match(use_ai: bool, racket_speed: float) -> void:
	if is_queued_for_deletion():
		return

	var match_node := MATCH_SCENE.instantiate()
	match_node.set("play_with_ai", use_ai)
	match_node.set("ai_racket_speed", racket_speed)

	var tree := get_tree()
	tree.root.add_child(match_node)
	tree.current_scene = match_node
	queue_free()


func style_main_button(button: Button) -> void:
	if dark_mode:
		style_color_button(button, INK, CREAM, 24)
		return

	button.add_theme_stylebox_override("normal", texture_style(BUTTON_NORMAL))
	button.add_theme_stylebox_override("hover", texture_style(BUTTON_HOVER))
	button.add_theme_stylebox_override("pressed", texture_style(BUTTON_PRESSED))
	button.add_theme_stylebox_override("disabled", texture_style(BUTTON_DISABLED))
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_font_size_override("font_size", 24)


func style_color_button(button: Button, fill: Color, text_color: Color, font_size: int) -> void:
	button.add_theme_stylebox_override("normal", color_style(fill, INK))
	button.add_theme_stylebox_override("hover", color_style(fill.lightened(0.10), INK))
	button.add_theme_stylebox_override("pressed", color_style(fill.darkened(0.10), INK))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, text_color)
	button.add_theme_font_size_override("font_size", font_size)


func color_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


func texture_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	return style
