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
const TELEGRAPH_TEXTURE := preload("res://assets/enemies/skull/attack/attack_02.png")

@export var dash_speed := 260.0
@export var dash_duration := 0.34
@export_range(0.0, 1.0, 0.01) var recall_start_delay := 0.62
@export_enum("NONE", "DASH_LEFT", "DASH_RIGHT") var initial_dash_memory := 0 # 開始時から表示するDASH記憶タグ。

var next_dash_direction := Vector2.LEFT

@onready var attack_warning_eyes: Node2D = $Sprite/AttackWarningEyes # 攻撃予告を示す赤目表示。

func _ready() -> void:
	setup_memory_enemy()
	_build_animations()
	_setup_initial_memory()
	if not memory_tag.memory_injected.is_connected(_on_memory_injected):
		memory_tag.memory_injected.connect(_on_memory_injected)
	state_machine.initialize(self, &"Idle")

func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)

# 攻撃前の赤目表示を切り替える。
func set_attack_warning_active(active: bool) -> void:
	if attack_warning_eyes != null:
		attack_warning_eyes.set_active(active)

# 指定方向・速度・距離を持つDASH行動データを生成する。
func build_dash_record(direction: Vector2, source: StringName = &"NATURAL") -> Resource:
	var normalized := direction.normalized()
	return ActionRecordScript.new(&"dash", normalized, normalized * dash_speed, dash_duration, source)

# 完了したDASHを記憶へ保存し、次の自然DASH方向を反転する。
func commit_dash_record(direction: Vector2, source: StringName = &"NATURAL", reform := false) -> void:
	var record := build_dash_record(direction, source)
	commit_memory_record(record, source, reform)
	next_dash_direction = -record.direction

# 次にAIが実行する自然DASHを生成する。
func build_natural_dash_record() -> Resource:
	return build_dash_record(next_dash_direction, &"NATURAL")

# 外向きDASH記憶を保持したまま逆方向の戻り行動を生成する。
func build_return_dash_record() -> Resource:
	var outward_direction: Vector2 = last_record.direction if last_record != null else Vector2.LEFT
	var return_direction: Vector2 = -outward_direction.normalized()
	return build_dash_record(return_direction)

# DASH方向へSpriteを向き直す。
func set_dash_direction_visual(direction: Vector2) -> void:
	if not is_zero_approx(direction.x):
		sprite.flip_h = direction.x < 0.0
		if attack_warning_eyes != null and attack_warning_eyes.has_method("sync_to_sprite"):
			attack_warning_eyes.sync_to_sprite()

# 壁まで実行したDASHを記憶へ確定し、次の自然DASHを反対方向へ向ける。
func handle_blocked_dash(record: Resource, source_type: StringName = &"NATURAL", reform := false) -> void:
	velocity.x = 0.0
	if record == null or is_zero_approx(record.direction.x):
		return
	commit_dash_record(record.direction, source_type, reform)
	next_dash_direction = -record.direction.normalized()

# 記憶矢印の注入時に見た目を再演方向へ反転する。
func _on_memory_injected(direction: Vector2, _memory_id: int) -> void:
	if current_state_name() != &"Recalled":
		return
	set_dash_direction_visual(direction)
	set_replay_outline_active(true)

# 再演開始の瞬間に小さなカメラキックと足元破片を発生させる。
func play_replay_launch_feedback(direction: Vector2) -> void:
	var root := get_tree().current_scene
	if root != null and root.has_method("shake_camera"):
		root.shake_camera(5.0, 0.09)
	if root == null:
		root = get_parent()
	for i in 7:
		var dust := ColorRect.new()
		dust.color = Color(0.68, 0.58, 0.78, 0.9)
		dust.size = Vector2(randf_range(2.0, 5.0), randf_range(2.0, 5.0))
		dust.global_position = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-5.0, 1.0))
		root.add_child(dust)
		var drift := Vector2(-signf(direction.x) * randf_range(10.0, 26.0), randf_range(-8.0, -2.0))
		var tween := dust.create_tween()
		tween.set_parallel(true)
		tween.tween_property(dust, "global_position", dust.global_position + drift, 0.18)
		tween.tween_property(dust, "modulate:a", 0.0, 0.18)
		tween.set_parallel(false)
		tween.tween_callback(dust.queue_free)

# 利用可能な記憶がある間は停止中・予備動作中・自然DASH中に噛める。
func is_biteable() -> bool:
	return last_record != null and last_record.is_available and memory_tag.is_available() and current_state_name() in [&"Idle", &"Telegraph", &"Dash", &"Recover", &"RightDash"]

# K入力フレームで現在行動を破棄し、保存済み記憶の再演Stateへ入る。
func begin_committed_bite(player: Node, record: Resource) -> bool:
	return receive_committed_bite(player, record)

# 同一記憶の二重使用を拒否して即時再演へ移行する。
func receive_committed_bite(_player: Node, record: Resource = null) -> bool:
	if current_state_name() == &"Dying" or not consume_memory_record(record):
		return false
	set_attack_hitbox_active(false)
	state_machine.change_state(&"Recalled", record)
	return true

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
	set_attack_warning_active(false)
	set_replay_outline_active(false)
	memory_tag.hide_tag()
	last_record = null
	next_dash_direction = Vector2.LEFT
	_setup_initial_memory()
	state_machine.change_state(&"Idle")

# Inspector設定から初期記憶と最初の自然DASH方向を準備する。
func _setup_initial_memory() -> void:
	last_record = null
	next_dash_direction = Vector2.LEFT
	if initial_dash_memory == 1:
		commit_dash_record(Vector2.LEFT)
	elif initial_dash_memory == 2:
		commit_dash_record(Vector2.RIGHT)

func _build_animations() -> void:
	var frames := SpriteFrameBuilder.from_folder("res://assets/enemies/skull/idle", &"idle", 4.0, true)
	SpriteFrameBuilder.add_animation(frames, "res://assets/enemies/skull/walk", &"walk", 7.0, true)
	frames.add_animation(&"telegraph")
	frames.set_animation_loop(&"telegraph", false)
	frames.set_animation_speed(&"telegraph", 1.0)
	frames.add_frame(&"telegraph", TELEGRAPH_TEXTURE)
	SpriteFrameBuilder.add_animation(frames, "res://assets/enemies/skull/attack", &"dash", 10.0, true)
	SpriteFrameBuilder.add_animation(frames, "res://assets/enemies/skull/dead", &"dead", 8.0, false)
	sprite.sprite_frames = frames
	sprite.play(&"idle")
