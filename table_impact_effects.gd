extends Node2D

const HIT_SPARK_PATH = "res://sprites/hit_spark.png"
const SHAKE_DURATION := 0.24
const MARK_DURATION := 0.36
const MARK_COLOR := Color("#F4ECD9")

@onready var match_node: Node = get_parent()
@onready var table: Node2D = $"../Table"
@onready var net: Node2D = $"../Net"

var table_start: Vector2
var net_start: Vector2
var previous_total := 0
var shake_remaining := 0.0
var shake_strength := 0.0

var mark_position := Vector2.ZERO
var mark_remaining := 0.0


func _ready() -> void:
	table_start = table.position
	net_start = net.position
	z_index = 6
	match_node.child_entered_tree.connect(on_match_child_entered)


func _process(delta: float) -> void:
	var total := int(match_node.get("left_score")) + int(match_node.get("right_score"))

	if total > previous_total:
		shake_strength = minf(3.0 + total * 0.55, 13.0)
		shake_remaining = SHAKE_DURATION
	elif total < previous_total:
		shake_remaining = 0.0
		mark_remaining = 0.0
		table.position = table_start
		net.position = net_start
		queue_redraw()

	previous_total = total

	var pause_menu := match_node.get("pause_menu") as Control
	if pause_menu != null and pause_menu.visible:
		return

	if shake_remaining > 0.0:
		shake_remaining = maxf(0.0, shake_remaining - delta)
		var elapsed := SHAKE_DURATION - shake_remaining
		var strength := shake_strength * (shake_remaining / SHAKE_DURATION)
		var offset := Vector2(
			sin(elapsed * TAU * 15.0),
			sin(elapsed * TAU * 11.0) * 0.55
		) * strength

		table.position = table_start + offset
		net.position = net_start + offset

	if mark_remaining > 0.0:
		mark_remaining = maxf(0.0, mark_remaining - delta)
		queue_redraw()


func on_match_child_entered(child: Node) -> void:
	var spark := child as Sprite2D
	if spark == null or spark.texture == null:
		return
	if spark.texture.resource_path != HIT_SPARK_PATH:
		return

	mark_position = to_local(spark.global_position)
	mark_remaining = MARK_DURATION
	queue_redraw()


func _draw() -> void:
	if mark_remaining <= 0.0:
		return

	var fade := mark_remaining / MARK_DURATION
	var color := MARK_COLOR
	color.a = fade * 0.9
	draw_arc(mark_position, 10.0, 0.0, TAU, 24, color, 2.0, true)
	draw_circle(mark_position, 3.0, color, true, -1.0, true)
