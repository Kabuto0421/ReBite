# 2026-06-13: 敵の行動でまとめて壊れるタイル地形。
@tool
class_name ActionBreakGroup
extends Node2D

signal broken(by_enemy: Node, action_record: Resource) # 破壊成立時に通知する。

const TileGroupBuilderScript := preload("res://scripts/stage/TileGroupBuilder.gd")
const NORMAL_PLATFORM_LAYER := 1 # 通常床として敵もプレイヤーも見るレイヤー。
const PLAYER_ONLY_PLATFORM_LAYER := 8 # 敵を止めずプレイヤーだけが見る破壊タイル用レイヤー。

@export var accepted_actions: Array[StringName] = [&"dash", &"jump"] # 破壊を許可する行動名。
@export var action_probe_margin := 18.0 # 行動方向にある壁を先読みする検知余白。
@export_range(0.0, 1.0, 0.01) var direction_dot_threshold := 0.35 # 行動方向と壁方向がどれだけ一致すれば壊すか。
@export var blocks_player := true # プレイヤーを物理的に止めるかどうか。
@export var blocks_enemy := false # 敵を物理的に止めるかどうか。
@export var break_once := true # 一度壊れたら復活しないかどうか。
@export_file("*.png") var tile_texture_path := "res://assets/tiles/cracked_breakable_tile.png" # 壊れるタイルの見た目に使う画像。
@export var tile_modulate := Color.WHITE # 壊れるタイルの表示色。

var broken_state := false # 現在壊れているかどうか。
var _collision_body: StaticBody2D # タイルの物理衝突。
var _break_area: Area2D # 敵行動を検知する範囲。
var _visual_root: Node2D # タイル表示の親ノード。
var _last_parts_hash := 0 # エディタ更新検知用の子矩形ハッシュ。

# エディタプレビューと実行時の破壊グループを準備する。
func _ready() -> void:
	add_to_group(&"action_break_groups")
	_last_parts_hash = _parts_hash()
	queue_redraw()
	if not Engine.is_editor_hint():
		_build_runtime_tiles()

# エディタで矩形が変わったら再描画する。
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and _last_parts_hash != _parts_hash():
		_last_parts_hash = _parts_hash()
		queue_redraw()

# エディタ上の破壊タイル形状を描く。
func _draw() -> void:
	if Engine.is_editor_hint():
		TileGroupBuilderScript.draw_preview(self, get_tile_parts(), Color(0.42, 0.16, 0.18), Color(0.95, 0.5, 0.35))

# 壊れたタイルを復活させる。
func reset_group() -> void:
	broken_state = false
	_set_group_active(true)

# 実行時の見た目、衝突、破壊検知を生成する。
func _build_runtime_tiles() -> void:
	var parts := get_tile_parts()
	var collision_layer := 0
	if blocks_enemy:
		collision_layer |= NORMAL_PLATFORM_LAYER
	elif blocks_player:
		collision_layer |= PLAYER_ONLY_PLATFORM_LAYER
	if blocks_enemy:
		collision_layer |= NORMAL_PLATFORM_LAYER
	_collision_body = TileGroupBuilderScript.build_static_collision(self, parts, collision_layer, 0)
	_visual_root = TileGroupBuilderScript.build_visuals(self, parts, tile_modulate, "GeneratedTiles", tile_texture_path)
	_break_area = TileGroupBuilderScript.build_area(self, _probe_parts(), 0, 5, "BreakSensor")
	_break_area.body_entered.connect(_on_break_area_body_entered)
	_break_area.area_entered.connect(_on_break_area_area_entered)

# すでに検知範囲内にいる敵や落石が行動を開始した場合も再判定する。
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _break_area == null:
		return
	if broken_state and break_once:
		return
	for body in _break_area.get_overlapping_bodies():
		if _can_break_with(body):
			_break(body, _current_action_record(body))
			return
	for area in _break_area.get_overlapping_areas():
		var source := _break_source_from_area(area)
		if source != null and _can_break_with(source):
			_break(source, _current_action_record(source))
			return

# 破壊検知に入った敵の現在行動を確認する。
func _on_break_area_body_entered(body: Node) -> void:
	if broken_state and break_once:
		return
	if not _can_break_with(body):
		return
	var record := _current_action_record(body)
	_break(body, record)

# 攻撃Areaが検知範囲に入った場合、その親の現在行動で破壊できるか確認する。
func _on_break_area_area_entered(area: Area2D) -> void:
	if broken_state and break_once:
		return
	var source := _break_source_from_area(area)
	if source == null or not _can_break_with(source):
		return
	_break(source, _current_action_record(source))

# 指定bodyがこのグループを壊せるか判定する。
func _can_break_with(body: Node) -> bool:
	if body != null and body.has_method("can_break_action_group") and body.can_break_action_group(self):
		return true
	var record := _current_action_record(body)
	if record == null:
		return false
	if accepted_actions.size() > 0 and not accepted_actions.has(record.action_name):
		return false
	return _is_action_pointing_to_group(body, record)

# bodyから現在実行中の行動記録を取り出す。
func _current_action_record(body: Node) -> Resource:
	if body == null:
		return null
	if body.has_method("current_action_record"):
		return body.current_action_record()
	return null

# 攻撃Areaから行動を持つ親ノードを取り出す。
func _break_source_from_area(area: Area2D) -> Node:
	if area == null:
		return null
	var parent := area.get_parent()
	if parent != null and parent.has_method("current_action_record"):
		return parent
	return null

# 行動方向の先にこのグループがあるか判定する。
func _is_action_pointing_to_group(body: Node, record: Resource) -> bool:
	if body == null or not body is Node2D:
		return false
	var direction: Vector2 = record.direction.normalized()
	if direction == Vector2.ZERO:
		return false
	var body_position: Vector2 = (body as Node2D).global_position
	return _best_direction_dot_to_group(body_position, direction) >= direction_dot_threshold

# body位置から見て行動方向にある矩形がどれだけ一致するか返す。
func _best_direction_dot_to_group(global_point: Vector2, direction: Vector2) -> float:
	var local_point := to_local(global_point)
	var best_dot := -1.0
	for part in get_tile_parts():
		if not TileGroupBuilderScript.is_valid_part(part):
			continue
		var part_position: Vector2 = TileGroupBuilderScript.part_position(part)
		var part_size: Vector2 = TileGroupBuilderScript.part_size(part)
		var part_rotation: float = TileGroupBuilderScript.part_rotation(part)
		var point_in_part: Vector2 = (local_point - part_position).rotated(-part_rotation)
		var nearest_in_part := Vector2(
			clampf(point_in_part.x, 0.0, part_size.x),
			clampf(point_in_part.y, 0.0, part_size.y)
		)
		var nearest_point := part_position + nearest_in_part.rotated(part_rotation)
		var global_vector := to_global(nearest_point) - global_point
		if global_vector == Vector2.ZERO:
			return 1.0
		best_dot = maxf(best_dot, direction.dot(global_vector.normalized()))
	return best_dot

# 子TileRectPartから位置、サイズ、回転を保持した一覧を集める。
func get_tile_parts() -> Array:
	var parts: Array = []
	for child in get_children():
		if child.has_method("to_tile_part"):
			var part: Dictionary = child.to_tile_part()
			if TileGroupBuilderScript.is_valid_part(part):
				parts.append(part)
		elif child.has_method("to_rect"):
			var rect: Rect2 = child.to_rect()
			if TileGroupBuilderScript.is_valid_rect(rect):
				parts.append(rect)
	return parts

# 子TileRectPartからタイル矩形一覧を集める。
func get_tile_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for child in get_children():
		if child.has_method("to_rect"):
			var rect: Rect2 = child.to_rect()
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				rects.append(rect)
	return rects

# 子矩形の状態をまとめてハッシュ化する。
func _parts_hash() -> int:
	var values: Array = []
	for child in get_children():
		if child.has_method("to_tile_part"):
			values.append(child.name)
			values.append(child.to_tile_part())
		elif child.has_method("to_rect"):
			values.append(child.name)
			values.append(child.to_rect())
	return hash(values)

# 各パーツの回転を保ったまま周囲へ行動検知余白を加える。
func _probe_parts() -> Array:
	var probe_parts: Array = []
	for part in get_tile_parts():
		var part_position: Vector2 = TileGroupBuilderScript.part_position(part)
		var part_size: Vector2 = TileGroupBuilderScript.part_size(part)
		var part_rotation: float = TileGroupBuilderScript.part_rotation(part)
		probe_parts.append({
			"position": part_position + Vector2(-action_probe_margin, -action_probe_margin).rotated(part_rotation),
			"size": part_size + Vector2.ONE * action_probe_margin * 2.0,
			"rotation": part_rotation,
		})
	return probe_parts

# グループ全体を一括で壊す。
func _break(by_enemy: Node, action_record: Resource) -> void:
	broken_state = true
	_set_group_active(false)
	_play_stage_sfx(&"action_break_block")
	_spawn_break_shards()
	broken.emit(by_enemy, action_record)

# タイル表示と物理衝突の有効/無効を切り替える。
func _set_group_active(active: bool) -> void:
	if _collision_body != null:
		_collision_body.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		for child in _collision_body.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", not active)
	if _visual_root != null:
		_visual_root.visible = active
	if _break_area != null:
		_break_area.set_deferred("monitoring", active or not break_once)
		_break_area.set_deferred("monitorable", active or not break_once)

# 破壊時の軽い破片を出す。
func _spawn_break_shards() -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_parent()
	for part in get_tile_parts():
		var part_position: Vector2 = TileGroupBuilderScript.part_position(part)
		var part_size: Vector2 = TileGroupBuilderScript.part_size(part)
		var part_rotation: float = TileGroupBuilderScript.part_rotation(part)
		var shard_count := clampi(int(part_size.x * part_size.y / 1200.0), 4, 18)
		for i in shard_count:
			var shard := ColorRect.new()
			shard.color = Color(randf_range(0.42, 0.72), randf_range(0.12, 0.28), randf_range(0.12, 0.28), 1.0)
			shard.size = Vector2(randf_range(4.0, 9.0), randf_range(4.0, 9.0))
			var point_in_part := Vector2(randf_range(0.0, part_size.x), randf_range(0.0, part_size.y))
			shard.global_position = to_global(part_position + point_in_part.rotated(part_rotation))
			root.add_child(shard)
			var angle := randf_range(-PI, PI)
			var distance := randf_range(20.0, 70.0)
			var tween := shard.create_tween()
			tween.set_parallel(true)
			tween.tween_property(shard, "global_position", shard.global_position + Vector2(cos(angle), sin(angle)) * distance, 0.35)
			tween.tween_property(shard, "modulate:a", 0.0, 0.35)
			tween.set_parallel(false)
			tween.tween_callback(shard.queue_free)

# 現在ステージのSE再生口へ通知する。
func _play_stage_sfx(sound_name: StringName) -> void:
	var root := get_tree().current_scene
	if root != null and root.has_method("play_sfx"):
		root.play_sfx(sound_name)
