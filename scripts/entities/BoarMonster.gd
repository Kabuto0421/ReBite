# 2026-06-21: 前方SMASHを記憶し、タグ保持中に歩く敵。
class_name BoarMonster
extends "res://scripts/entities/MemoryEnemy.gd"

const SpriteFrameBuilder := preload("res://scripts/core/SpriteFrameBuilder.gd")
const ActionRecordScript := preload("res://scripts/core/ActionRecord.gd")

enum BehaviorMode { PLAYER_CHASE, PATROL_CARRIER }

@export var initial_direction := Vector2.LEFT # 初回SMASHと歩行を始める向き。
@export var walk_speed := 62.0 # 記憶タグを保持して歩く速度。
@export var smash_speed := 118.0 # SMASH中に前へ踏み込む速度。
@export var smash_duration := 1.2 # SMASHアニメーションと行動記録の長さ。
@export var smash_impact_start := 0.42 # SMASH開始から攻撃判定が出るまでの秒数。
@export var smash_impact_end := 0.78 # SMASH開始から攻撃判定が消えるまでの秒数。
@export var smash_hitbox_offset_x := 46.0 # 攻撃判定を本体前方へずらす距離。
@export var recall_start_delay := 0.62 # タグ破壊後、再演SMASHを始めるまでの停止時間。
@export var player_path := NodePath("../Player") # 追跡とSMASH距離判定に使うPlayer。
@export var smash_range := 150.0 # この距離以内ならSMASHへ入る。
@export var smash_lane_y_tolerance := 44.0 # PlayerとのY差がこの範囲内の時だけSMASHする。
@export var behavior_mode := BehaviorMode.PLAYER_CHASE # Playerを追うか、巡回点で記憶を運ぶか。
@export var memory_tag_urgency_enabled := false # タグ上書き直前の点滅を使うか。

@export_group("Patrol Carrier")
@export var patrol_smash_point := Vector2.ZERO # A地点。通常SMASHを作る場所。
@export var patrol_turn_point := Vector2.ZERO # B地点。通常時はここでAへ折り返す。
@export var patrol_branch_point := Vector2.ZERO # C地点。分岐解放後に記憶を運ぶ場所。
@export var patrol_smash_direction := Vector2.LEFT # A地点で作るSMASH記憶の向き。
@export var patrol_smash_target_path := NodePath("") # 設定時はこの標的の方向へSMASHする。
@export var patrol_arrival_distance := 12.0 # 巡回点へ到着したとみなす距離。

var walk_direction := Vector2.LEFT # タグ保持中に歩いている向き。
var player: Node # 追跡対象のPlayer。
var patrol_route_open := false # B地点からC地点へ進めるかどうか。
var patrol_target_point := Vector2.ZERO # 現在向かっている巡回点。
var patrol_target_id: StringName # 現在向かっている巡回点ID。
var patrol_waiting_at_branch := false # C地点でタグを噛ませるために停止中かどうか。

# 記憶敵、アニメーション、初期SMASH記録を準備する。
func _ready() -> void:
	setup_memory_enemy()
	_build_animations()
	player = get_node_or_null(player_path)
	walk_direction = _horizontal_direction(initial_direction)
	set_facing_direction(walk_direction)
	prepare_smash_record(walk_direction)
	if is_patrol_carrier():
		patrol_target_point = patrol_smash_point
		patrol_target_id = &"A"
	state_machine.initialize(self, &"Idle")

# 現在Stateの物理更新を進める。
func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)

# 指定方向のSMASH記録を次の自律行動用に準備する。
func prepare_smash_record(direction: Vector2) -> void:
	var smash_direction := _horizontal_direction(direction)
	last_record = ActionRecordScript.new(
		&"smash",
		smash_direction,
		smash_direction * smash_speed,
		smash_duration
	)

# 実行済みSMASHを最後の記憶としてタグへ表示する。
func commit_smash_record(record: Resource) -> void:
	if record == null:
		prepare_smash_record(walk_direction)
	else:
		last_record = ActionRecordScript.new(
			&"smash",
			_horizontal_direction(record.direction),
			record.velocity,
			record.duration
		)
	memory_tag.show_record(last_record)

# スプライトと攻撃判定を指定方向へ向ける。
func set_facing_direction(direction: Vector2) -> void:
	var horizontal := _horizontal_direction(direction)
	sprite.flip_h = horizontal.x > 0.0
	attack_hitbox.position.x = horizontal.x * smash_hitbox_offset_x

# 歩行方向を反転し、見た目も追従させる。
func reverse_walk_direction() -> void:
	walk_direction *= -1.0
	set_facing_direction(walk_direction)

# Stage9などで使う巡回搬送モードか返す。
func is_patrol_carrier() -> bool:
	return behavior_mode == BehaviorMode.PATROL_CARRIER

# Playerの方向へ歩行向きを更新する。
func face_player() -> void:
	if player == null:
		return
	walk_direction = _horizontal_direction(player.global_position - global_position)
	set_facing_direction(walk_direction)

# PlayerがSMASH射程内にいるか返す。
func is_player_in_smash_range() -> bool:
	if player == null:
		return true
	if absf(player.global_position.y - global_position.y) > smash_lane_y_tolerance:
		return false
	return absf(player.global_position.x - global_position.x) <= smash_range

# 記憶タグの期限警告表示を使うか返す。
func should_update_memory_tag_urgency() -> bool:
	return memory_tag_urgency_enabled

# 現在の行動原理に応じた自律SMASH記録を作る。
func build_autonomous_smash_record() -> Resource:
	if is_patrol_carrier():
		patrol_waiting_at_branch = false
		var smash_direction := _patrol_smash_direction()
		prepare_smash_record(smash_direction)
		set_facing_direction(smash_direction)
		return last_record
	face_player()
	prepare_smash_record(walk_direction)
	return last_record

# 自律SMASH後、SMASH記憶を保持したままB地点へ運び始める。
func on_autonomous_smash_finished() -> void:
	if not is_patrol_carrier():
		return
	_set_patrol_target(&"B", patrol_turn_point)

# 留め具破壊後、次にBへ到着した時の行き先をCへ差し替える。
func open_patrol_branch() -> void:
	patrol_route_open = true

# 現在の巡回点へ向かう歩行方向を設定する。
func face_patrol_target() -> void:
	if patrol_waiting_at_branch:
		velocity.x = 0.0
		return
	var delta := patrol_target_point - global_position
	if absf(delta.x) <= patrol_arrival_distance:
		return
	walk_direction = _horizontal_direction(delta)
	set_facing_direction(walk_direction)

# 巡回点への到着に応じて次の状態を返す。
func update_patrol_route_after_move() -> StringName:
	if patrol_waiting_at_branch:
		velocity.x = 0.0
		return &""
	if absf(global_position.x - patrol_target_point.x) > patrol_arrival_distance:
		return &""
	match patrol_target_id:
		&"B":
			if patrol_route_open:
				_set_patrol_target(&"C", patrol_branch_point)
			else:
				_set_patrol_target(&"A", patrol_smash_point)
		&"A":
			return &"Idle"
		&"C":
			patrol_waiting_at_branch = true
			velocity.x = 0.0
			play_animation(&"idle")
	return &""

# A地点でSMASHできる状態か返す。
func can_start_patrol_smash() -> bool:
	return is_patrol_carrier() and not patrol_waiting_at_branch and absf(global_position.x - patrol_smash_point.x) <= patrol_arrival_distance

# SMASH開始からの経過時間が攻撃区間内か返す。
func is_smash_impact_active(elapsed: float) -> bool:
	return elapsed >= smash_impact_start and elapsed <= smash_impact_end

# SMASHの攻撃区間だけ前へ踏み込む速度を返す。
func smash_velocity(record: Resource, elapsed: float) -> Vector2:
	if record == null or not is_smash_impact_active(elapsed):
		return Vector2.ZERO
	return record.velocity

# リプレイやステージ再開時に初期位置と初期状態へ戻す。
func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	clear_active_action_record()
	set_attack_hitbox_active(false)
	memory_tag.hide_tag()
	walk_direction = _horizontal_direction(initial_direction)
	set_facing_direction(walk_direction)
	prepare_smash_record(walk_direction)
	patrol_route_open = false
	patrol_waiting_at_branch = false
	if is_patrol_carrier():
		_set_patrol_target(&"A", patrol_smash_point)
	state_machine.change_state(&"Idle")

# Boar向けの破片色で死亡バーストを生成する。
func spawn_death_burst() -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	for i in 20:
		var shard := ColorRect.new()
		shard.color = Color(
			randf_range(0.22, 0.42),
			randf_range(0.16, 0.30),
			randf_range(0.12, 0.22),
			1.0
		)
		shard.size = Vector2(randf_range(4.0, 10.0), randf_range(4.0, 10.0))
		shard.global_position = global_position + Vector2(randf_range(-34, 34), randf_range(-52, -8))
		root.add_child(shard)
		var angle := randf_range(-PI, PI)
		var distance := randf_range(46.0, 122.0)
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", shard.global_position + Vector2(cos(angle), sin(angle)) * distance, 0.46)
		tween.tween_property(shard, "modulate:a", 0.0, 0.46)
		tween.set_parallel(false)
		tween.tween_callback(shard.queue_free)

# Boar用PNG列から各アニメーションを構築する。
func _build_animations() -> void:
	var frames := SpriteFrameBuilder.from_folder("res://assets/enemies/boar/idle", &"idle", 6.25, true)
	SpriteFrameBuilder.add_animation(frames, "res://assets/enemies/boar/walk", &"walk", 10.0, true)
	SpriteFrameBuilder.add_animation(frames, "res://assets/enemies/boar/smash", &"smash", 8.333, false)
	SpriteFrameBuilder.add_animation(frames, "res://assets/enemies/boar/dead", &"dead", 6.25, false)
	sprite.sprite_frames = frames
	sprite.play(&"idle")

# 任意のVector2を左右どちらかの単位方向へ揃える。
func _horizontal_direction(direction: Vector2) -> Vector2:
	return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT

# 巡回点の目的地を更新する。
func _set_patrol_target(point_id: StringName, point: Vector2) -> void:
	patrol_target_id = point_id
	patrol_target_point = point
	patrol_waiting_at_branch = false

# 巡回A地点でSMASHする向きを、標的があれば標的位置から決める。
func _patrol_smash_direction() -> Vector2:
	if not patrol_smash_target_path.is_empty():
		var target := get_node_or_null(patrol_smash_target_path)
		if target != null and target is Node2D:
			var delta: Vector2 = (target as Node2D).global_position - global_position
			if not is_zero_approx(delta.x):
				return _horizontal_direction(delta)
	return patrol_smash_direction
