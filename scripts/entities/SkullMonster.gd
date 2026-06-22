# 2026-06-13: 左右突進を記憶として扱う敵。
class_name SkullMonster
extends "res://scripts/entities/MemoryEnemy.gd"

const StateMachineScript := preload("res://scripts/core/StateMachine.gd")
const SpriteFrameBuilder := preload("res://scripts/core/SpriteFrameBuilder.gd")
const ActionRecordScript := preload("res://scripts/core/ActionRecord.gd")
const EnemyIdleState := preload("res://scripts/states/enemy/EnemyIdleState.gd")
const EnemyTelegraphState := preload("res://scripts/states/enemy/EnemyTelegraphState.gd")
const EnemyDashState := preload("res://scripts/states/enemy/EnemyDashState.gd")
const EnemyRecoverState := preload("res://scripts/states/enemy/EnemyRecoverState.gd")
const EnemyRecalledState := preload("res://scripts/states/enemy/EnemyRecalledState.gd")
const EnemyRightDashState := preload("res://scripts/states/enemy/EnemyRightDashState.gd")
const EnemyDyingState := preload("res://scripts/states/enemy/EnemyDyingState.gd")

@export var dash_speed := 260.0
@export var dash_duration := 0.34
@export var recall_start_delay := 0.62

func _ready() -> void:
	setup_memory_enemy()
	_build_animations()
	prepare_dash_record(Vector2.LEFT)
	state_machine.initialize(self, &"Idle")

func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)

func prepare_dash_record(direction: Vector2) -> void:
	last_record = ActionRecordScript.new(&"dash", direction.normalized(), direction.normalized() * dash_speed, dash_duration)

func commit_dash_record(direction: Vector2) -> void:
	prepare_dash_record(direction)
	memory_tag.show_record(last_record)

func spawn_death_burst() -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	for i in 18:
		var shard := ColorRect.new()
		shard.color = Color(1.0, randf_range(0.25, 0.75), randf_range(0.15, 0.25), 1.0)
		shard.size = Vector2(randf_range(4.0, 9.0), randf_range(4.0, 9.0))
		shard.global_position = global_position + Vector2(randf_range(-18, 18), randf_range(-48, -12))
		root.add_child(shard)
		var angle := randf_range(-PI, PI)
		var distance := randf_range(42.0, 118.0)
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", shard.global_position + Vector2(cos(angle), sin(angle)) * distance, 0.45)
		tween.tween_property(shard, "modulate:a", 0.0, 0.45)
		tween.set_parallel(false)
		tween.tween_callback(shard.queue_free)

func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	set_attack_hitbox_active(false)
	memory_tag.hide_tag()
	prepare_dash_record(Vector2.LEFT)
	state_machine.change_state(&"Idle")

func _build_animations() -> void:
	var frames := SpriteFrameBuilder.from_folder("res://assets/enemies/skull/idle", &"idle", 4.0, true)
	SpriteFrameBuilder.add_animation(frames, "res://assets/enemies/skull/walk", &"walk", 7.0, true)
	SpriteFrameBuilder.add_animation(frames, "res://assets/enemies/skull/attack", &"dash", 10.0, true)
	SpriteFrameBuilder.add_animation(frames, "res://assets/enemies/skull/dead", &"dead", 8.0, false)
	sprite.sprite_frames = frames
	sprite.play(&"idle")
