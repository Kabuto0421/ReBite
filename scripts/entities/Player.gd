# 2026-06-13: 移動、ジャンプ、記憶噛みを行うプレイヤー。
class_name Player
extends "res://scripts/entities/Character.gd"

signal bite_hit(target: Node)
signal bite_missed

const StateMachineScript := preload("res://scripts/core/StateMachine.gd")
const SpriteFrameBuilder := preload("res://scripts/core/SpriteFrameBuilder.gd")
const PlayerGroundState := preload("res://scripts/states/player/PlayerGroundState.gd")
const PlayerAirState := preload("res://scripts/states/player/PlayerAirState.gd")
const PlayerBiteWindupState := preload("res://scripts/states/player/PlayerBiteWindupState.gd")
const PlayerBiteLungeState := preload("res://scripts/states/player/PlayerBiteLungeState.gd")
const PlayerBiteRecoverState := preload("res://scripts/states/player/PlayerBiteRecoverState.gd")
const PlayerDeadState := preload("res://scripts/states/player/PlayerDeadState.gd")

@export var move_speed := 210.0
@export var jump_velocity := -410.0

var facing := 1
var is_dead := false
var bite_invulnerable := false

@onready var bite_area: Area2D = $BiteArea
@onready var drop_bite_area: Area2D = $DropBiteArea

func _ready() -> void:
	remember_spawn_position()
	_build_animations()
	state_machine.initialize(self, &"Ground")

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	state_machine.handle_input(event)

func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)

func apply_horizontal_input() -> void:
	var axis := Input.get_axis("move_left", "move_right")
	velocity.x = axis * move_speed
	if not is_zero_approx(axis):
		facing = -1 if axis < 0.0 else 1
		sprite.flip_h = facing < 0
		bite_area.position.x = 34.0 * facing

func jump() -> void:
	velocity.y = jump_velocity

func pick_bite_target() -> Node:
	var best: Node = null
	var best_distance := INF
	for area in [bite_area, drop_bite_area]:
		if not area.monitoring:
			continue
		for body in area.get_overlapping_bodies():
			if body == self:
				continue
			if body.has_method("receive_bite") and (not body.has_method("is_biteable") or body.is_biteable()):
				var distance := global_position.distance_squared_to(body.global_position)
				if distance < best_distance:
					best_distance = distance
					best = body
	return best

func reset_to_spawn() -> void:
	is_dead = false
	set_bite_invulnerable(false)
	global_position = spawn_position
	velocity = Vector2.ZERO
	sprite.modulate = Color.WHITE
	sprite.rotation = 0.0
	sprite.scale = Vector2(1.35, 1.35)
	bite_area.set_deferred("monitoring", true)
	bite_area.set_deferred("monitorable", true)
	drop_bite_area.set_deferred("monitoring", true)
	drop_bite_area.set_deferred("monitorable", true)
	state_machine.change_state(&"Ground")

func die() -> void:
	if is_dead or bite_invulnerable:
		return
	is_dead = true
	state_machine.change_state(&"Dead", null)

func set_bite_invulnerable(active: bool) -> void:
	bite_invulnerable = active

func play_death_animation() -> void:
	sprite.modulate = Color.WHITE
	sprite.rotation = 0.0
	sprite.scale = Vector2(1.35, 1.35)
	play_animation(&"dead")

func spawn_death_burst() -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	for i in 14:
		var shard := ColorRect.new()
		shard.color = Color(0.65 + randf_range(0.0, 0.25), 0.85, 1.0, 1.0)
		shard.size = Vector2(randf_range(3.0, 7.0), randf_range(3.0, 7.0))
		shard.global_position = global_position + Vector2(randf_range(-14, 14), randf_range(-42, -10))
		root.add_child(shard)
		var angle := randf_range(-PI, PI)
		var distance := randf_range(34.0, 86.0)
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", shard.global_position + Vector2(cos(angle), sin(angle)) * distance, 0.36)
		tween.tween_property(shard, "modulate:a", 0.0, 0.36)
		tween.set_parallel(false)
		tween.tween_callback(shard.queue_free)

func _build_animations() -> void:
	var frames := SpriteFrameBuilder.from_folder("res://assets/player/walk", &"walk", 8.0, true)
	SpriteFrameBuilder.add_animation(frames, "res://assets/player/bite", &"bite", 12.0, false)
	SpriteFrameBuilder.add_animation(frames, "res://assets/player/dead", &"dead", 10.0, false)
	sprite.sprite_frames = frames
	sprite.play(&"walk")
