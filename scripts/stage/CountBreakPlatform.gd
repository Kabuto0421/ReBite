# 2026-08-19: 乗っているCharacter数で崩れる足場。
@tool
class_name CountBreakPlatform
extends Node2D

signal collapsed(current_count: int) # 足場が崩れた時に現在人数を通知する。

enum PlatformState { STABLE, WARNING, BROKEN }

@export_group("Break Rule")
@export_range(1, 12, 1) var required_character_count := 2 # 崩壊に必要なCharacter人数。
@export_range(0.0, 1.0, 0.01) var warning_time := 0.22 # 条件成立から崩壊までの警告時間。
@export var count_only_on_floor := true # 上に乗っているCharacterだけを数える。
@export var count_players := true # Playerを人数に含めるか。
@export var count_memory_enemies := true # MemoryEnemyを人数に含めるか。
@export var drop_kick_velocity := 120.0 # 崩壊時に乗っていたCharacterへ与える下向き速度。

@export_group("Shape")
@export var platform_collision_size := Vector2(192, 20) # 実際に乗れる当たり判定サイズ。
@export var platform_collision_offset := Vector2(0, -12) # 足場当たり判定の中心位置。
@export var count_sensor_size := Vector2(188, 34) # Characterを数える上面センサーサイズ。
@export var count_sensor_offset := Vector2(0, -39) # 上面センサーの中心位置。

@export_group("Visual")
@export_file("*.png") var platform_texture_path := "res://assets/gimmicks/count_break_platform.png" # 土台Sprite画像。
@export_file("*.png") var badge_texture_path := "res://assets/gimmicks/count_break_badge.png" # カウント表示枠画像。
@export var platform_visual_scale := Vector2.ONE # 土台Spriteの表示倍率。
@export var badge_offset := Vector2(0, -68) # カウント表示の位置。
@export var badge_scale := Vector2.ONE # カウント表示枠の倍率。
@export var stable_modulate := Color.WHITE # 通常時の表示色。
@export var warning_modulate := Color(1.25, 0.82, 0.82, 1.0) # 崩壊直前の表示色。

var state := PlatformState.STABLE # 現在の足場状態。
var _tracked_bodies: Dictionary = {} # センサー内にいる候補Character。
var _warning_tween: Tween # 警告揺れと崩壊遷移を管理するTween。
var _visual_root_start_position := Vector2.ZERO # 警告揺れ復帰用の表示初期位置。

@onready var visual_root: Node2D = $VisualRoot # 土台表示の親。
@onready var platform_sprite: Sprite2D = $VisualRoot/PlatformSprite # 土台Sprite。
@onready var badge_root: Node2D = $BadgeRoot # カウント表示の親。
@onready var badge_sprite: Sprite2D = $BadgeRoot/BadgeSprite # カウント枠Sprite。
@onready var count_label: Label = $BadgeRoot/CountLabel # 現在人数と必要人数の表示。
@onready var collision_body: StaticBody2D = $CollisionBody # 足場の物理衝突。
@onready var platform_collision: CollisionShape2D = $CollisionBody/PlatformCollision # 足場Shape。
@onready var count_sensor: Area2D = $CountSensor # 上面人数センサー。
@onready var count_sensor_collision: CollisionShape2D = $CountSensor/CountSensorCollision # 上面センサーShape。

# ノード参照と見た目、衝突、センサーを初期化する。
func _ready() -> void:
	add_to_group(&"count_break_platform")
	_visual_root_start_position = visual_root.position
	_apply_configuration()
	if Engine.is_editor_hint():
		return
	count_sensor.body_entered.connect(_on_count_sensor_body_entered)
	count_sensor.body_exited.connect(_on_count_sensor_body_exited)
	_update_count_display()

# エディタ上のInspector変更を即時プレビューへ反映する。
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_apply_configuration()
		queue_redraw()
		return
	if state == PlatformState.STABLE:
		_refresh_count()

# エディタ上に足場衝突と人数センサーの範囲を描く。
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var platform_rect := Rect2(platform_collision_offset - platform_collision_size * 0.5, platform_collision_size)
	var sensor_rect := Rect2(count_sensor_offset - count_sensor_size * 0.5, count_sensor_size)
	draw_rect(platform_rect, Color(0.55, 0.25, 0.78, 0.28), true)
	draw_rect(platform_rect, Color(1.0, 0.82, 0.38, 0.92), false, 2.0)
	draw_rect(sensor_rect, Color(0.25, 0.9, 1.0, 0.16), true)
	draw_rect(sensor_rect, Color(0.4, 0.95, 1.0, 0.82), false, 2.0)

# 足場を初期状態へ戻す。
func reset_platform() -> void:
	_transition_to(PlatformState.STABLE)
	_tracked_bodies.clear()
	_set_collision_active(true)
	visual_root.visible = true
	badge_root.visible = true
	visual_root.position = _visual_root_start_position
	_update_count_display()

# 外部ギミックから即時崩壊させる。
func force_collapse() -> void:
	if state == PlatformState.BROKEN:
		return
	_transition_to(PlatformState.BROKEN)

# センサー内に入ったCharacter候補を登録する。
func _on_count_sensor_body_entered(body: Node) -> void:
	if state != PlatformState.STABLE:
		return
	if not _is_countable_character(body):
		return
	_tracked_bodies[body.get_instance_id()] = body
	_refresh_count()

# センサーから出たCharacter候補を解除する。
func _on_count_sensor_body_exited(body: Node) -> void:
	_tracked_bodies.erase(body.get_instance_id())
	_refresh_count()

# 現在人数を再計算し、条件成立時は警告状態へ遷移する。
func _refresh_count() -> void:
	var current_count := _current_character_count()
	_update_count_display(current_count)
	if current_count >= required_character_count:
		_transition_to(PlatformState.WARNING)

# 状態遷移を一箇所に集約する。
func _transition_to(next_state: PlatformState) -> void:
	if state == next_state:
		return
	_kill_warning_tween()
	state = next_state
	match state:
		PlatformState.STABLE:
			_enter_stable()
		PlatformState.WARNING:
			_enter_warning()
		PlatformState.BROKEN:
			_enter_broken()

# 通常状態の表示へ戻す。
func _enter_stable() -> void:
	visual_root.modulate = stable_modulate
	badge_root.modulate = Color.WHITE

# 崩壊直前の揺れと強調を開始する。
func _enter_warning() -> void:
	visual_root.modulate = warning_modulate
	badge_root.modulate = warning_modulate
	_warning_tween = create_tween()
	_warning_tween.set_parallel(true)
	_warning_tween.tween_property(visual_root, "position:x", _visual_root_start_position.x + 3.0, warning_time * 0.25)
	_warning_tween.tween_property(badge_root, "scale", badge_scale * 1.16, warning_time * 0.45)
	_warning_tween.set_parallel(false)
	_warning_tween.tween_property(visual_root, "position:x", _visual_root_start_position.x - 3.0, warning_time * 0.25)
	_warning_tween.tween_property(visual_root, "position:x", _visual_root_start_position.x, warning_time * 0.25)
	_warning_tween.tween_callback(func() -> void: _transition_to(PlatformState.BROKEN))

# 衝突を消し、乗っていたCharacterを落とし、破片を出す。
func _enter_broken() -> void:
	var current_count := _current_character_count()
	_set_collision_active(false)
	_drop_tracked_characters()
	_spawn_break_debris()
	visual_root.visible = false
	badge_root.visible = false
	collapsed.emit(current_count)

# Inspectorの値を子ノードへ反映する。
func _apply_configuration() -> void:
	if not is_inside_tree():
		return
	_load_sprite_texture(platform_sprite, platform_texture_path)
	_load_sprite_texture(badge_sprite, badge_texture_path)
	platform_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	platform_sprite.scale = platform_visual_scale
	badge_root.position = badge_offset
	badge_root.scale = badge_scale
	if platform_collision.shape is RectangleShape2D:
		(platform_collision.shape as RectangleShape2D).size = platform_collision_size
	platform_collision.position = platform_collision_offset
	if count_sensor_collision.shape is RectangleShape2D:
		(count_sensor_collision.shape as RectangleShape2D).size = count_sensor_size
	count_sensor_collision.position = count_sensor_offset
	_update_count_display()

# ファイルパスからSpriteへ画像を読み込む。
func _load_sprite_texture(sprite_node: Sprite2D, path: String) -> void:
	if sprite_node == null or path.is_empty():
		return
	var texture := load(path)
	if texture is Texture2D:
		sprite_node.texture = texture

# カウント表示を更新する。
func _update_count_display(current_count := -1) -> void:
	if count_label == null:
		return
	if current_count < 0:
		current_count = _current_character_count() if not Engine.is_editor_hint() else 0
	count_label.text = "%d/%d" % [current_count, required_character_count]

# 現在センサー内にいる有効Character数を返す。
func _current_character_count() -> int:
	var count := 0
	var expired: Array[int] = []
	for id in _tracked_bodies.keys():
		var body: Node = _tracked_bodies[id]
		if not is_instance_valid(body) or not _is_countable_character(body):
			expired.append(id)
			continue
		if count_only_on_floor and body.has_method("is_on_floor") and not body.is_on_floor():
			continue
		count += 1
	for id in expired:
		_tracked_bodies.erase(id)
	return count

# このギミックで人数として扱うCharacterか判定する。
func _is_countable_character(body: Node) -> bool:
	if body == null or not body is CharacterBody2D:
		return false
	if body is Player:
		return count_players
	if body is MemoryEnemy:
		return count_memory_enemies
	if not count_players and body.is_in_group(&"player"):
		return false
	if body.is_in_group(&"character"):
		return true
	return body.has_method("current_state_name") and body.get_node_or_null("Sprite") != null

# 足場の衝突を有効/無効にする。
func _set_collision_active(active: bool) -> void:
	collision_body.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	platform_collision.set_deferred("disabled", not active)
	count_sensor.set_deferred("monitoring", active)
	count_sensor.set_deferred("monitorable", active)

# 崩壊時、足場上のCharacterへ下向き速度を加えて同時落下を見せる。
func _drop_tracked_characters() -> void:
	for body in _tracked_bodies.values():
		if not is_instance_valid(body) or not body is CharacterBody2D:
			continue
		var character := body as CharacterBody2D
		character.velocity.y = maxf(character.velocity.y, drop_kick_velocity)

# 軽い崩壊破片を出す。
func _spawn_break_debris() -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	for i in 10:
		var shard := ColorRect.new()
		shard.color = Color(randf_range(0.42, 0.72), randf_range(0.18, 0.32), randf_range(0.55, 0.85), 1.0)
		shard.size = Vector2(randf_range(4.0, 10.0), randf_range(4.0, 8.0))
		shard.global_position = global_position + platform_collision_offset + Vector2(randf_range(-platform_collision_size.x * 0.45, platform_collision_size.x * 0.45), randf_range(-8.0, 8.0))
		root.add_child(shard)
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", shard.global_position + Vector2(randf_range(-36.0, 36.0), randf_range(32.0, 84.0)), 0.42)
		tween.tween_property(shard, "modulate:a", 0.0, 0.42)
		tween.set_parallel(false)
		tween.tween_callback(shard.queue_free)

# 進行中Tweenを破棄する。
func _kill_warning_tween() -> void:
	if _warning_tween != null and _warning_tween.is_valid():
		_warning_tween.kill()
	_warning_tween = null
