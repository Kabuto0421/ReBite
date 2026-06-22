# 2026-06-21: ブロックから解放され、重力と坂で転がる落石ギミック。
class_name Rockfall
extends RigidBody2D

const ActionRecordScript := preload("res://scripts/core/ActionRecord.gd")

enum MotionState {
	RESTING,
	FALLING,
	ROLLING,
}

@export var kill_speed := 240.0 # Playerまたは敵を倒せる最低衝突速度。
@export var max_speed := 900.0 # すり抜けと過剰加速を防ぐ最高速度。
@export var max_angular_speed := 20.0 # 回転の最高角速度。
@export var resting_speed := 18.0 # 接地時に静止と見なす速度。
@export var impact_cooldown := 0.2 # 同じ対象への連続ダメージを防ぐ秒数。
@export var can_kill_player := true # 高速接触でPlayerを倒すか。
@export var can_kill_enemies := true # 高速接触で敵を倒すか。
@export var minimum_action_push_speed := 460.0 # DASH/SMASHで保証する最低押し出し速度。
@export var dash_push_multiplier := 1.3 # DASH記録速度から岩速度へ変換する倍率。
@export var smash_push_multiplier := 2.9 # SMASH記録速度から岩速度へ変換する倍率。
@export var dash_push_accept_max_speed := 72.0 # この速度を超えて転動中の岩はDASHを受け付けない。
@export var action_break_speed := 260.0 # ActionBreakGroupを破壊できる最低速度。
@export var powered_reset_speed := 72.0 # これ未満で接地すると行動押し状態を解除する速度。
@export var action_break_grace := 0.12 # 衝突解決後も直前の破壊速度を保持する秒数。
@export var powered_settle_delay := 0.18 # 停止後に行動押し状態を解除するまでの秒数。
@export var push_spin_speed := 20.0 # 行動で押された時に加える回転速度。
@export var push_source_immunity := 0.45 # 押した敵を岩の反動死から守る秒数。

var motion_state := MotionState.RESTING # 現在の物理状態分類。
var spawn_transform := Transform2D.IDENTITY # リセット時に戻る初期Transform。
var _recent_peak_speed := 0.0 # 衝突直前の速度を取りこぼさないための直近速度。
var _last_hit_msec_by_body: Dictionary = {} # 対象ごとの最終ダメージ時刻。
var _last_push_record_by_body: Dictionary = {} # 同じ行動記録による連続加速を防ぐ表。
var _push_immunity_until_by_body: Dictionary = {} # 押した敵の一時保護期限。
var _action_powered := false # MemoryEnemyのDASH/SMASHで押された状態か。
var _break_record: Resource # ActionBreakGroupへ渡す現在の岩移動記録。
var _break_momentum_until_msec := 0 # 直前の破壊速度を有効とする期限。
var _powered_below_speed_time := 0.0 # 接地して低速になった継続時間。

# 初期位置、接触通知、破壊グループとの接続を準備する。
func _ready() -> void:
	spawn_transform = global_transform
	contact_monitor = true
	max_contacts_reported = maxi(max_contacts_reported, 8)
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	call_deferred("_connect_action_break_groups")

# 接触中のMemoryEnemyがDASH/SMASHを開始した場合も押しを受け取る。
func _physics_process(_delta: float) -> void:
	for body in get_colliding_bodies():
		_try_apply_memory_action_push(body)

# 物理速度を制限し、静止・落下・転動を分類する。
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var speed := state.linear_velocity.length()
	var was_rolling := motion_state == MotionState.ROLLING
	_recent_peak_speed = maxf(speed, _recent_peak_speed * 0.9)
	if speed > max_speed:
		state.linear_velocity = state.linear_velocity.normalized() * max_speed
	state.angular_velocity = clampf(state.angular_velocity, -max_angular_speed, max_angular_speed)

	if state.get_contact_count() == 0:
		motion_state = MotionState.FALLING
	elif speed > resting_speed or absf(state.angular_velocity) > 0.35:
		motion_state = MotionState.ROLLING
	else:
		motion_state = MotionState.RESTING

	if _action_powered and speed > 0.0 and _break_record != null:
		_break_record.direction = state.linear_velocity.normalized()
		_break_record.velocity = state.linear_velocity
	var natural_rolling_break := was_rolling and state.get_contact_count() > 0
	if speed >= action_break_speed and (_action_powered or natural_rolling_break):
		_break_momentum_until_msec = Time.get_ticks_msec() + int(action_break_grace * 1000.0)
	if _action_powered and state.get_contact_count() > 0 and speed < powered_reset_speed:
		_powered_below_speed_time += state.step
		if _powered_below_speed_time >= powered_settle_delay:
			_action_powered = false
			_break_record = null
	else:
		_powered_below_speed_time = 0.0

# Inspectorやテストから確認できる現在状態名を返す。
func motion_state_name() -> StringName:
	match motion_state:
		MotionState.FALLING:
			return &"Falling"
		MotionState.ROLLING:
			return &"Rolling"
		_:
			return &"Resting"

# 支えが消えた後に物理sleepを解除する。
func release() -> void:
	sleeping = false

# 初期位置へ戻し、速度とヒット履歴をリセットする。
func reset_to_spawn() -> void:
	global_transform = spawn_transform
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_recent_peak_speed = 0.0
	_last_hit_msec_by_body.clear()
	_last_push_record_by_body.clear()
	_push_immunity_until_by_body.clear()
	_action_powered = false
	_break_record = null
	_break_momentum_until_msec = 0
	_powered_below_speed_time = 0.0
	motion_state = MotionState.RESTING
	sleeping = false

# ActionBreakGroupが問い合わせる現在の岩移動記録を返す。
func current_action_record() -> Resource:
	if _action_powered and _break_record != null:
		return _break_record
	if not can_break_action_group():
		return null
	var direction := linear_velocity.normalized()
	return ActionRecordScript.new(&"rockfall", direction, linear_velocity, 0.0)

# 原因を問わず規定速度以上ならActionBreakGroupを破壊できる。
func can_break_action_group(_group: Node = null) -> bool:
	var has_break_speed := linear_velocity.length() >= action_break_speed
	if _action_powered:
		return has_break_speed or Time.get_ticks_msec() <= _break_momentum_until_msec
	if motion_state != MotionState.ROLLING:
		return false
	return has_break_speed or Time.get_ticks_msec() <= _break_momentum_until_msec

# MemoryEnemyの攻撃Hitboxから確定済み行動記録を受け取る。
func receive_memory_action_push(source: Node, record: Resource) -> bool:
	return _apply_memory_action_push(source, record)

# 現在ステージ内の全ActionBreakGroupへwake処理を接続する。
func _connect_action_break_groups() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	for break_group in get_tree().get_nodes_in_group(&"action_break_groups"):
		if break_group.has_signal("broken") and not break_group.broken.is_connected(_on_action_break_group_broken):
			break_group.broken.connect(_on_action_break_group_broken)

# 破壊床の衝突が消えるタイミングでsleepを解除する。
func _on_action_break_group_broken(_by_enemy: Node, _action_record: Resource) -> void:
	release()

# 高速接触したPlayerまたは敵へ一度だけ死亡通知を送る。
func _on_body_entered(body: Node) -> void:
	if _try_apply_memory_action_push(body):
		return
	if body == null or not body.has_method("die"):
		return
	if not _can_damage_body(body):
		return
	var impact_speed := maxf(_recent_peak_speed, linear_velocity.length())
	if impact_speed < kill_speed:
		return
	var body_id := body.get_instance_id()
	var now_msec := Time.get_ticks_msec()
	if now_msec < int(_push_immunity_until_by_body.get(body_id, 0)):
		return
	var last_hit_msec := int(_last_hit_msec_by_body.get(body_id, -1000000))
	if now_msec - last_hit_msec < int(impact_cooldown * 1000.0):
		return
	_last_hit_msec_by_body[body_id] = now_msec
	body.die()

# MemoryEnemyの実行中DASH/SMASHを岩の速度と破壊記録へ変換する。
func _try_apply_memory_action_push(source: Node) -> bool:
	if source == null or not source.has_method("current_action_record"):
		return false
	var record: Resource = source.current_action_record()
	return _apply_memory_action_push(source, record)

# DASH/SMASH記録を岩の速度と破壊記録へ変換する。
func _apply_memory_action_push(source: Node, record: Resource) -> bool:
	if source == null:
		return false
	if record == null or not record.action_name in [&"dash", &"smash"]:
		return false
	if record.action_name == &"dash" and linear_velocity.length() > dash_push_accept_max_speed:
		return false
	var source_id := source.get_instance_id()
	var record_id := record.get_instance_id()
	if int(_last_push_record_by_body.get(source_id, 0)) == record_id:
		return false

	var direction: Vector2 = record.direction.normalized()
	if direction == Vector2.ZERO:
		direction = record.velocity.normalized()
	if direction == Vector2.ZERO:
		return false
	var multiplier := dash_push_multiplier if record.action_name == &"dash" else smash_push_multiplier
	var required_effect_speed := maxf(kill_speed, action_break_speed) + 1.0
	var target_speed := maxf(minimum_action_push_speed, maxf(required_effect_speed, record.velocity.length() * multiplier))
	var velocity_along_push := linear_velocity.dot(direction)
	var perpendicular_velocity := linear_velocity - direction * velocity_along_push
	linear_velocity = perpendicular_velocity + direction * maxf(target_speed, velocity_along_push)
	angular_velocity = clampf(direction.x * push_spin_speed, -max_angular_speed, max_angular_speed)
	sleeping = false
	_action_powered = true
	_break_record = ActionRecordScript.new(&"rockfall", direction, linear_velocity, 0.0)
	_break_momentum_until_msec = Time.get_ticks_msec() + int(action_break_grace * 1000.0)
	_powered_below_speed_time = 0.0
	_last_push_record_by_body[source_id] = record_id
	_push_immunity_until_by_body[source_id] = Time.get_ticks_msec() + int(push_source_immunity * 1000.0)
	return true

# 衝突レイヤーからPlayerまたは敵へのダメージ許可を判定する。
func _can_damage_body(body: Node) -> bool:
	if not body is CollisionObject2D:
		return false
	var layer := (body as CollisionObject2D).collision_layer
	if layer & 2:
		return can_kill_player
	if layer & 4:
		return can_kill_enemies
	return false
