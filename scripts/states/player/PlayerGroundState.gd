# 2026-06-13: プレイヤーの地上操作状態。
extends "res://scripts/core/State.gd"

func enter(_payload: Variant = null) -> void:
	owner_node.play_animation(&"walk")

func physics_update(delta: float) -> void:
	owner_node.refresh_coyote_window()
	owner_node.apply_gravity(delta)
	owner_node.apply_ground_horizontal_input(delta)
	owner_node.move_and_slide()

	if not owner_node.is_on_floor():
		transition_requested.emit(&"Air", null)

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		owner_node.buffer_jump()
		if owner_node.try_consume_buffered_jump():
			transition_requested.emit(&"Air", null)
	elif event.is_action_pressed("bite"):
		transition_requested.emit(&"BiteWindup", owner_node.prepare_bite_context())
