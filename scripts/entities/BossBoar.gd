# 2026-06-22: DASHとSMASHの記憶再演で環境攻略する大型Boarボス。
class_name BossBoar
extends "res://scripts/entities/MemoryEnemy.gd"

signal boss_hp_changed(current_hp: int, max_hp: int) # 環境ダメージ後のHPを通知する。
signal boss_defeated # HPが0になった瞬間を通知する。
signal action_committed(request: RefCounted) # Telegraphで方向確定した攻撃を通知する。
signal action_started(request: RefCounted) # DASHまたはSMASHの実行開始を通知する。
signal action_finished(request: RefCounted) # 攻撃実行終了を通知する。
signal smash_impact_started(request: RefCounted) # SMASH衝撃波と攻撃判定が発生した瞬間を通知する。
signal environment_damage_applied(event: Dictionary, current_hp: int, max_hp: int) # 環境ダメージの成立を通知する。

const SpriteFrameBuilder := preload("res://scripts/core/SpriteFrameBuilder.gd")
const BossActionRequestScript := preload("res://scripts/boss/core/BossActionRequest.gd")

@export_range(1, 10, 1) var max_hp := 5 # 撃破に必要な環境ダメージ回数。
@export var chase_speed := 72.0 # 攻撃判断まで主人公を追う速度。
@export var dash_speed := 315.0 # DASH実行速度。
@export var dash_duration := 1.0 # DASH実行時間。
@export var smash_speed := 122.0 # SMASH踏み込み速度。
@export var smash_duration := 0.85 # SMASH実行時間。
@export var smash_impact_start := 0.30 # SMASH攻撃判定の開始時刻。
@export var smash_impact_end := 0.56 # SMASH攻撃判定の終了時刻。
@export var recall_start_delay := 0.48 # タグ破壊から再演予備動作までの停止時間。

@export_group("Attack Placement")
@export var dash_hitbox_offset_x := 62.0 # DASH近接判定の本体中心からの距離。
@export var smash_hitbox_offset_x := 46.0 # SMASH近接判定の本体中心からの距離。
@export var smash_shockwave_hitbox_offset_x := 82.0 # SMASH衝撃波判定の本体中心からの距離。
@export var smash_shockwave_visual_offset_x := 76.0 # SMASH衝撃波表示の本体中心からの距離。

@export_group("Visual Grounding")
@export var idle_sprite_y := -66.0 # Idle画像の足元を床へ合わせるSprite位置。
@export var walk_sprite_y := -67.5 # Walk画像の足元を床へ合わせるSprite位置。
@export var dash_sprite_y := -67.5 # DASH画像の足元を床へ合わせるSprite位置。
@export var smash_sprite_y := -70.5 # SMASH画像の足元を床へ合わせるSprite位置。
@export var dead_sprite_y := -67.0 # Dead画像の足元を床へ合わせるSprite位置。

var current_hp := 5 # 現在HP。
var current_request: RefCounted # Telegraphで固定済みの攻撃要求。
var walk_direction := Vector2.LEFT # 現在の移動向き。
var player: Node # 攻撃対象Player。
var boss_brain: Node # 距離から通常攻撃を選ぶ部品。
var last_replay_msec := -1000000 # 最後に再演攻撃を始めた時刻。
var last_replay_action: StringName # 最後に再演した行動ID。
var _last_attack_was_replay := false # 直前攻撃が再演だったか。
var _base_sprite_scale := Vector2.ONE # ヒット姿勢復元用スプライト倍率。

@onready var shockwave_area: Area2D = $ShockwaveArea # SMASHの遠距離衝撃波判定。
@onready var shockwave_sprite: AnimatedSprite2D = $ShockwaveSprite # SMASH衝撃波表示。

# ボス部品、アニメーション、StateMachineを初期化する。
func _ready() -> void:
	setup_memory_enemy()
	attack_hitbox.collision_mask |= 16
	_build_animations()
	_build_shockwave_animation()
	current_hp = max_hp
	_base_sprite_scale = sprite.scale
	player = get_parent().get_node_or_null("Player")
	boss_brain = $BossBrain
	boss_brain.setup(self, player)
	shockwave_area.body_entered.connect(_on_shockwave_body_entered)
	set_shockwave_active(false)
	state_machine.initialize(self, &"Idle")

# 現在Stateの物理更新を進める。
func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)

# アニメーションを再生し、素材ごとの透明余白に応じて足元を揃える。
func play_animation(animation_name: StringName) -> void:
	super.play_animation(animation_name)
	match animation_name:
		&"idle":
			sprite.position.y = idle_sprite_y
		&"walk":
			sprite.position.y = walk_sprite_y
		&"dash":
			sprite.position.y = dash_sprite_y
		&"smash":
			sprite.position.y = smash_sprite_y
		&"dead":
			sprite.position.y = dead_sprite_y

# 通常攻撃要求をBrainから取得する。
func choose_natural_action() -> RefCounted:
	return boss_brain.choose_action()

# Telegraph開始時に方向を固定し、通常攻撃だけ記憶を更新する。
func begin_telegraph(request: RefCounted) -> void:
	current_request = request
	set_facing_direction(request.direction, request.action_id)
	if request.source == &"NATURAL":
		last_record = request.to_action_record(_speed_for_action(request.action_id), _duration_for_action(request.action_id))
		action_committed.emit(request)

# Execute開始時に地形へ渡すActionRecordを有効化する。
func begin_attack(request: RefCounted) -> Resource:
	current_request = request
	var record: Resource = request.to_action_record(_speed_for_action(request.action_id), _duration_for_action(request.action_id))
	set_active_action_record(record)
	set_facing_direction(request.direction, request.action_id)
	if request.source == &"REBITE_REPLAY":
		last_replay_msec = Time.get_ticks_msec()
		last_replay_action = request.action_id
	action_started.emit(request)
	return record

# 攻撃終了時に判定を解除し、再演かどうかを保持する。
func finish_attack(request: RefCounted) -> void:
	_last_attack_was_replay = request != null and request.source == &"REBITE_REPLAY"
	if _last_attack_was_replay:
		set_replay_outline_active(false)
	clear_active_action_record()
	set_attack_hitbox_active(false)
	set_shockwave_active(false)
	action_finished.emit(request)

# 通常攻撃後だけ記憶タグを表示する。
func show_attack_memory_if_available() -> void:
	if _last_attack_was_replay or last_record == null:
		memory_tag.hide_tag()
		return
	memory_tag.show_record(last_record)

# 噛み開始時に固定された記憶を再演待ちStateへ渡す。
func receive_committed_bite(_player: Node, record: Resource = null) -> bool:
	if not is_biteable():
		return false
	if record == null:
		record = last_record
	if record == null or not record.action_name in [&"dash", &"smash"]:
		return false
	var request := BossActionRequestScript.new(record.action_name, record.direction, &"REBITE_REPLAY", global_position)
	state_machine.change_state(&"Replay", request)
	return true

# 通常の噛み受付を確定済み受付へ統一する。
func receive_bite(biting_player: Node) -> void:
	receive_committed_bite(biting_player, last_record)

# AttackRecovery中だけ記憶タグを噛める。
func is_biteable() -> bool:
	return memory_tag.visible and current_state_name() == &"AttackRecovery"

# 通常のdie通知ではHPを減らさない。
func die() -> void:
	pass

# ReplayDamageResolver承認済みの環境ダメージを適用する。
func apply_environment_damage(event: Dictionary) -> bool:
	if current_hp <= 0 or current_state_name() == &"Dying":
		return false
	current_hp = maxi(0, current_hp - int(event.get("damage", 1)))
	environment_damage_applied.emit(event, current_hp, max_hp)
	boss_hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		boss_defeated.emit()
		state_machine.change_state(&"Dying", null)
		return true
	state_machine.change_state(&"Stagger", event)
	return true

# 指定行動の再演が直近に行われたか返す。
func was_recent_replay(action_id: StringName, window_seconds: float) -> bool:
	return last_replay_action == action_id and Time.get_ticks_msec() - last_replay_msec <= int(window_seconds * 1000.0)

# 現在実行中の行動が指定再演か返す。
func is_executing_replay(action_id: StringName = &"") -> bool:
	var record := current_action_record()
	if record == null or record.source != &"REBITE_REPLAY":
		return false
	return action_id == &"" or record.action_name == action_id

# 攻撃種類ごとの距離を使って見た目と判定を攻撃方向へ向ける。
func set_facing_direction(direction: Vector2, action_id: StringName = &"dash") -> void:
	walk_direction = Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	sprite.flip_h = walk_direction.x > 0.0
	var hitbox_offset := smash_hitbox_offset_x if action_id == &"smash" else dash_hitbox_offset_x
	attack_hitbox.position.x = walk_direction.x * hitbox_offset
	shockwave_area.position.x = walk_direction.x * smash_shockwave_hitbox_offset_x
	shockwave_sprite.position.x = walk_direction.x * smash_shockwave_visual_offset_x
	shockwave_sprite.flip_h = walk_direction.x < 0.0

# SMASHの攻撃区間か返す。
func is_smash_impact_active(elapsed: float) -> bool:
	return elapsed >= smash_impact_start and elapsed <= smash_impact_end

# SMASH Stateから衝撃発生の意味イベントを通知する。
func notify_smash_impact_started(request: RefCounted) -> void:
	smash_impact_started.emit(request)

# SMASH衝撃波の表示と判定を切り替える。
func set_shockwave_active(active: bool) -> void:
	shockwave_area.set_deferred("monitoring", active)
	shockwave_area.set_deferred("monitorable", active)
	shockwave_sprite.visible = active
	if active:
		shockwave_sprite.play(&"shockwave")

# 非致命被弾後の通常姿勢を復元する。
func restore_boss_sprite_transform() -> void:
	set_replay_outline_active(false)
	sprite.scale = _base_sprite_scale
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE

# Encounterリセット時にHP、位置、記憶、状態を初期化する。
func reset_boss() -> void:
	current_hp = max_hp
	global_position = spawn_position
	velocity = Vector2.ZERO
	last_record = null
	current_request = null
	last_replay_msec = -1000000
	last_replay_action = &""
	clear_active_action_record()
	set_attack_hitbox_active(false)
	set_shockwave_active(false)
	set_replay_outline_active(false)
	memory_tag.hide_tag()
	restore_boss_sprite_transform()
	state_machine.change_state(&"Idle", null)
	boss_hp_changed.emit(current_hp, max_hp)

# Boar素材からゲーム内アニメーションを構築する。
func _build_animations() -> void:
	var frames := SpriteFrameBuilder.from_folder("res://assets/enemies/boar/idle", &"idle", 6.25, true)
	SpriteFrameBuilder.add_animation(frames, "res://assets/enemies/boar/walk", &"walk", 10.0, true)
	SpriteFrameBuilder.add_animation(frames, "res://assets/enemies/boar/dash", &"dash", 10.0, false, "boar_dash_")
	SpriteFrameBuilder.add_animation(frames, "res://assets/enemies/boar/smash", &"smash", 8.333, false)
	SpriteFrameBuilder.add_animation(frames, "res://assets/enemies/boar/dead", &"dead", 6.25, false)
	sprite.sprite_frames = frames
	sprite.play(&"idle")

# パッケージの衝撃波フレームをアニメーション化する。
func _build_shockwave_animation() -> void:
	var frames := SpriteFrameBuilder.from_folder("res://assets/boss/boss_intro/frames", &"shockwave", 14.0, false, "smash_shockwave_")
	shockwave_sprite.sprite_frames = frames

# 衝撃波へ入ったPlayerを倒す。
func _on_shockwave_body_entered(body: Node) -> void:
	if shockwave_area.monitoring and body.has_method("die"):
		body.die()

# 行動IDに対応する速度を返す。
func _speed_for_action(action_id: StringName) -> float:
	return dash_speed if action_id == &"dash" else smash_speed

# 行動IDに対応する実行時間を返す。
func _duration_for_action(action_id: StringName) -> float:
	return dash_duration if action_id == &"dash" else smash_duration

# 通常ハザードではボスが倒れないため、共通の最終撃破演出対象から除外する。
func will_die_from_next_hit() -> bool:
	return false

# 専用BossBattleSfxが撃破音を担当するため共通死亡音を無効化する。
func death_sfx_name() -> StringName:
	return &""

# Boar色の死亡破片を生成する。
func spawn_death_burst() -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	if root == null:
		return
	for i in 34:
		var shard := ColorRect.new()
		shard.color = Color(randf_range(0.22, 0.55), randf_range(0.12, 0.34), randf_range(0.08, 0.20), 1.0)
		shard.size = Vector2(randf_range(5.0, 13.0), randf_range(5.0, 13.0))
		shard.global_position = global_position + Vector2(randf_range(-70, 70), randf_range(-100, -10))
		root.add_child(shard)
		var tween := shard.create_tween()
		tween.parallel().tween_property(shard, "global_position", shard.global_position + Vector2(randf_range(-150, 150), randf_range(-130, 60)), 0.55)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.55)
		tween.tween_callback(shard.queue_free)
