# 2026-06-13: 跳躍を記憶として扱う敵。
class_name HopMonster
extends "res://scripts/entities/MemoryEnemy.gd"

const SpriteFrameBuilder := preload("res://scripts/core/SpriteFrameBuilder.gd")
const ActionRecordScript := preload("res://scripts/core/ActionRecord.gd")

@export var hop_velocity := -330.0
@export var hop_record_duration := 0.42
@export var recall_start_delay := 0.48

func _ready() -> void:
	setup_memory_enemy()
	_build_animations()
	prepare_hop_record()
	state_machine.initialize(self, &"Idle")

func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)

func prepare_hop_record() -> void:
	last_record = ActionRecordScript.new(&"jump", Vector2.UP, Vector2(0.0, hop_velocity), hop_record_duration)

func commit_hop_record() -> void:
	prepare_hop_record()
	memory_tag.show_record(last_record)

func replay_hop_velocity(record: Resource) -> Vector2:
	if record == null:
		return Vector2(0.0, hop_velocity)
	return Vector2(record.velocity.x, hop_velocity)

func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	set_attack_hitbox_active(false)
	memory_tag.hide_tag()
	prepare_hop_record()
	state_machine.change_state(&"Idle")

func spawn_death_burst() -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	for i in 16:
		var shard := ColorRect.new()
		shard.color = Color(randf_range(0.65, 0.95), 1.0, randf_range(0.55, 0.85), 1.0)
		shard.size = Vector2(randf_range(3.0, 7.0), randf_range(3.0, 7.0))
		shard.global_position = global_position + Vector2(randf_range(-18, 18), randf_range(-44, -8))
		root.add_child(shard)
		var angle := randf_range(-PI, PI)
		var distance := randf_range(38.0, 96.0)
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", shard.global_position + Vector2(cos(angle), sin(angle)) * distance, 0.38)
		tween.tween_property(shard, "modulate:a", 0.0, 0.38)
		tween.set_parallel(false)
		tween.tween_callback(shard.queue_free)

func _build_animations() -> void:
	var frames := SpriteFrameBuilder.from_folder("res://assets/enemies/hop/idle", &"idle", 5.0, true)
	SpriteFrameBuilder.add_animation(frames, "res://assets/enemies/hop/hop", &"hop", 10.0, false)
	SpriteFrameBuilder.add_animation(frames, "res://assets/enemies/hop/dead", &"dead", 12.0, false)
	sprite.sprite_frames = frames
	sprite.play(&"idle")
