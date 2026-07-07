# 2026-06-13: 移動、ジャンプ、記憶噛みを行うプレイヤー。
class_name Player
extends "res://scripts/entities/Character.gd"

signal bite_hit(target: Node)
signal bite_contact(target: Node) # 飛びついた牙が記憶タグへ届いた瞬間を通知する。
signal bite_missed
signal death_started # ボスEncounterへ死亡開始を通知する。
signal respawned # ボスEncounterへ復帰完了を通知する。

const StateMachineScript := preload("res://scripts/core/StateMachine.gd")
const SpriteFrameBuilder := preload("res://scripts/core/SpriteFrameBuilder.gd")
const PlayerGroundState := preload("res://scripts/states/player/PlayerGroundState.gd")
const PlayerAirState := preload("res://scripts/states/player/PlayerAirState.gd")
const PlayerBiteWindupState := preload("res://scripts/states/player/PlayerBiteWindupState.gd")
const PlayerBiteLungeState := preload("res://scripts/states/player/PlayerBiteLungeState.gd")
const PlayerBiteRecoverState := preload("res://scripts/states/player/PlayerBiteRecoverState.gd")
const PlayerDeadState := preload("res://scripts/states/player/PlayerDeadState.gd")
const REPLAY_OUTLINE_SHADER := preload("res://assets/shaders/skull_pixel_outline.gdshader")

@export var move_speed := 210.0
@export var jump_velocity := -410.0
@export var visual_scale := Vector2(1.35, 1.35) # 当たり判定と独立したSprite表示倍率。

@export_group("Movement Feel")
@export_range(500.0, 6000.0, 100.0) var ground_acceleration := 3000.0 # 地上で目標速度へ近づく速さ。
@export_range(500.0, 7000.0, 100.0) var ground_deceleration := 4200.0 # 地上で入力を離した時の停止速度。
@export_range(500.0, 8000.0, 100.0) var ground_turn_acceleration := 5000.0 # 地上で逆方向へ切り返す速さ。
@export_range(500.0, 5000.0, 100.0) var air_acceleration := 1800.0 # 空中で横速度を補正する速さ。
@export_range(0.0, 0.2, 0.01) var coyote_time := 0.08 # 足場を離れた後もジャンプできる猶予。
@export_range(0.0, 0.2, 0.01) var jump_buffer_time := 0.10 # 着地前のジャンプ入力を保存する時間。
@export_range(0.0, 1000.0, 10.0) var landing_feedback_speed := 240.0 # 着地変形を出す最小落下速度。

@export_group("Bite Safety")
@export_range(0.10, 0.20, 0.01) var bite_contact_immunity_max := 0.16 # 成功対象との重なりを保護する上限時間。
@export_range(0.0, 12.0, 1.0) var bite_separation_distance := 8.0 # 噛み成功時に後方へ離す最大距離。

var facing := 1
var is_dead := false
var bite_invulnerable := false
var contact_immunity_targets: Dictionary = {} # 噛み成功対象ごとの接触保護残り時間。
var coyote_timer := 0.0 # 現在残っているコヨーテタイム。
var jump_buffer_timer := 0.0 # 現在保存しているジャンプ入力時間。
var movement_feedback_tween: Tween # 離陸・着地変形を管理するTween。
var default_replay_material: Material # 再演輪郭解除時に戻すSprite Material。

@onready var bite_area: Area2D = $BiteArea
@onready var drop_bite_area: Area2D = $DropBiteArea

func _ready() -> void:
	remember_spawn_position()
	_build_animations()
	sprite.scale = visual_scale
	state_machine.initialize(self, &"Ground")

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	state_machine.handle_input(event)

func _physics_process(delta: float) -> void:
	_update_contact_immunity(delta)
	_update_jump_grace(delta)
	state_machine.physics_update(delta)

# 地上入力へ短い加速、速い停止、素早い切り返しを適用する。
func apply_ground_horizontal_input(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	var target_speed := axis * move_speed
	var acceleration := ground_acceleration
	if is_zero_approx(axis):
		acceleration = ground_deceleration
	elif not is_zero_approx(velocity.x) and signf(axis) != signf(velocity.x):
		acceleration = ground_turn_acceleration
	velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	_update_facing(axis)

# 空中入力を弱い加速で反映し、跳躍中の慣性と着地点調整を両立する。
func apply_air_horizontal_input(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, axis * move_speed, air_acceleration * delta)
	_update_facing(axis)

# 上向き速度を設定してジャンプ猶予を消費する。
func jump() -> void:
	velocity.y = jump_velocity
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	_play_takeoff_feedback()
	_play_stage_sfx(&"hop_launch")

# 地上にいる間、足場を離れた直後のジャンプ猶予を更新する。
func refresh_coyote_window() -> void:
	coyote_timer = coyote_time

# ジャンプ入力を着地まで短時間保存する。
func buffer_jump() -> void:
	jump_buffer_timer = jump_buffer_time

# 地上またはコヨーテ時間中なら保存済みジャンプを実行する。
func try_consume_buffered_jump() -> bool:
	if jump_buffer_timer <= 0.0:
		return false
	if not is_on_floor() and coyote_timer <= 0.0:
		return false
	jump()
	return true

# 落下速度に応じて着地変形と小さな埃を出す。
func play_landing_feedback(fall_speed: float) -> void:
	if fall_speed < landing_feedback_speed:
		return
	_kill_movement_feedback_tween()
	sprite.scale = visual_scale * Vector2(1.12, 0.88)
	movement_feedback_tween = create_tween()
	movement_feedback_tween.set_trans(Tween.TRANS_QUAD)
	movement_feedback_tween.set_ease(Tween.EASE_OUT)
	movement_feedback_tween.tween_property(sprite, "scale", visual_scale, 0.08)
	_spawn_landing_dust()

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

# K入力時点で対象と記憶を固定し、移動中の対象へ噛み開始を通知する。
func prepare_bite_context() -> Dictionary:
	var target := pick_bite_target()
	if target == null:
		return {}
	var record: Resource
	if target.has_method("bite_commit_record"):
		record = target.bite_commit_record()
	var replay_started := false
	if target.has_method("begin_committed_bite"):
		replay_started = bool(target.begin_committed_bite(self, record))
	if replay_started:
		grant_contact_immunity(target)
		_separate_from_target(target, record)
	return {
		"target": target,
		"record": record,
		"replay_started": replay_started,
	}

# 噛み成功対象だけを一時的な接触無効リストへ登録する。
func grant_contact_immunity(target: Node) -> void:
	if is_instance_valid(target):
		contact_immunity_targets[target.get_instance_id()] = {
			"target": weakref(target),
			"remaining": bite_contact_immunity_max,
			"elapsed": 0.0,
			"has_overlapped": _collision_bounds_overlap(target),
		}

# 指定した敵からの接触だけを無効化しているか返す。
func is_contact_immune_from(source: Node) -> bool:
	return is_instance_valid(source) and contact_immunity_targets.has(source.get_instance_id())

func reset_to_spawn() -> void:
	is_dead = false
	set_bite_invulnerable(false)
	contact_immunity_targets.clear()
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	_kill_movement_feedback_tween()
	global_position = spawn_position
	velocity = Vector2.ZERO
	sprite.modulate = Color.WHITE
	sprite.rotation = 0.0
	sprite.scale = visual_scale
	bite_area.set_deferred("monitoring", true)
	bite_area.set_deferred("monitorable", true)
	drop_bite_area.set_deferred("monitoring", true)
	drop_bite_area.set_deferred("monitorable", true)
	state_machine.change_state(&"Ground")
	respawned.emit()

func die() -> void:
	if is_dead or bite_invulnerable:
		return
	is_dead = true
	contact_immunity_targets.clear()
	death_started.emit()
	state_machine.change_state(&"Dead", null)

func set_bite_invulnerable(active: bool) -> void:
	bite_invulnerable = active

# プレイヤーが記憶再演させられている間の紫輪郭を切り替える。
func set_replay_outline_active(active: bool) -> void:
	if sprite == null:
		return
	if active:
		if default_replay_material == null:
			default_replay_material = sprite.material
		var material := ShaderMaterial.new()
		material.shader = REPLAY_OUTLINE_SHADER
		material.set_shader_parameter("outline_color", Color("#c86bff"))
		material.set_shader_parameter("outline_size", 1.65)
		material.set_shader_parameter("tint_color", Color.WHITE)
		sprite.material = material
	else:
		sprite.material = default_replay_material
		default_replay_material = null

# 対象と離れた時点、または安全時間上限で接触保護を解除する。
func _update_contact_immunity(delta: float) -> void:
	var expired: Array[int] = []
	for instance_id in contact_immunity_targets:
		var entry: Dictionary = contact_immunity_targets[instance_id]
		var target: Node = (entry.target as WeakRef).get_ref()
		if not is_instance_valid(target):
			expired.append(instance_id)
			continue
		entry.remaining = float(entry.remaining) - delta
		entry.elapsed = float(entry.elapsed) + delta
		var overlaps := _collision_bounds_overlap(target)
		entry.has_overlapped = bool(entry.has_overlapped) or overlaps
		contact_immunity_targets[instance_id] = entry
		if entry.remaining <= 0.0 or (entry.elapsed >= 0.02 and bool(entry.has_overlapped) and not overlaps):
			expired.append(instance_id)
	for instance_id in expired:
		contact_immunity_targets.erase(instance_id)

# 壁へ押し込まない範囲で、噛んだ対象から数ピクセル後退する。
func _separate_from_target(target: Node, record: Resource) -> void:
	var away_x := signf(global_position.x - target.global_position.x)
	if is_zero_approx(away_x) and record != null:
		away_x = -signf(record.direction.x)
	if is_zero_approx(away_x):
		away_x = -float(facing)
	var step := Vector2(away_x, 0.0)
	for i in int(bite_separation_distance):
		if test_move(global_transform, step):
			break
		global_position += step

# Playerと対象の主要CollisionShapeの矩形領域が重なっているか返す。
func _collision_bounds_overlap(target: Node) -> bool:
	var own_bounds := _collision_bounds(self)
	var target_bounds := _collision_bounds(target)
	if own_bounds.size == Vector2.ZERO or target_bounds.size == Vector2.ZERO:
		return global_position.distance_to(target.global_position) < 40.0
	return own_bounds.intersects(target_bounds, true)

# CharacterBody2Dの主要CollisionShapeから軸平行の判定領域を作る。
func _collision_bounds(body: Node) -> Rect2:
	var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return Rect2()
	var size := Vector2.ZERO
	if collision.shape is RectangleShape2D:
		size = (collision.shape as RectangleShape2D).size
	elif collision.shape is CapsuleShape2D:
		var capsule := collision.shape as CapsuleShape2D
		size = Vector2(capsule.radius * 2.0, capsule.height)
	elif collision.shape is CircleShape2D:
		var diameter := (collision.shape as CircleShape2D).radius * 2.0
		size = Vector2(diameter, diameter)
	if size == Vector2.ZERO:
		return Rect2()
	size *= collision.global_scale.abs()
	return Rect2(collision.global_position - size * 0.5, size)

func play_death_animation() -> void:
	_kill_movement_feedback_tween()
	sprite.modulate = Color.WHITE
	sprite.rotation = 0.0
	sprite.scale = visual_scale
	play_animation(&"dead")

# 入力方向へ見た目と噛み判定の向きを揃える。
func _update_facing(axis: float) -> void:
	if is_zero_approx(axis):
		return
	facing = -1 if axis < 0.0 else 1
	sprite.flip_h = facing < 0
	bite_area.position.x = 34.0 * facing

# コヨーテタイムとジャンプ入力保存時間を進める。
func _update_jump_grace(delta: float) -> void:
	coyote_timer = maxf(0.0, coyote_timer - delta)
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)

# 離陸時に小さく潰し、短時間で通常形状へ戻す。
func _play_takeoff_feedback() -> void:
	_kill_movement_feedback_tween()
	sprite.scale = visual_scale * Vector2(1.08, 0.92)
	movement_feedback_tween = create_tween()
	movement_feedback_tween.set_trans(Tween.TRANS_QUAD)
	movement_feedback_tween.set_ease(Tween.EASE_OUT)
	movement_feedback_tween.tween_property(sprite, "scale", visual_scale, 0.06)

# 着地点の左右へ小さなドット埃を飛ばす。
func _spawn_landing_dust() -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	for direction in [-1.0, 1.0]:
		for index in 2:
			var dust := ColorRect.new()
			dust.color = Color(0.66, 0.60, 0.78, 0.72)
			dust.size = Vector2(3.0 + index, 3.0 + index)
			dust.global_position = global_position + Vector2(direction * (5.0 + index * 3.0), -3.0)
			root.add_child(dust)
			var drift := Vector2(direction * (12.0 + index * 5.0), -5.0 - index * 2.0)
			var tween := dust.create_tween()
			tween.set_parallel(true)
			tween.tween_property(dust, "global_position", dust.global_position + drift, 0.16)
			tween.tween_property(dust, "modulate:a", 0.0, 0.16)
			tween.set_parallel(false)
			tween.tween_callback(dust.queue_free)

# 競合する離陸・着地変形を停止する。
func _kill_movement_feedback_tween() -> void:
	if movement_feedback_tween != null and movement_feedback_tween.is_valid():
		movement_feedback_tween.kill()
	movement_feedback_tween = null

# 現在ステージの共通SE再生口へ通知する。
func _play_stage_sfx(sound_name: StringName) -> void:
	var root := get_tree().current_scene
	if root != null and root.has_method("play_sfx"):
		root.play_sfx(sound_name)

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
