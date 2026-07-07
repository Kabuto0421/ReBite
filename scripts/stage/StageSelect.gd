# 2026-06-14: ステージ選択画面の箱配置と入力移動。
extends Node2D

const SpriteFrameBuilder := preload("res://scripts/core/SpriteFrameBuilder.gd")
const StageBgmScript := preload("res://scripts/stage/StageBgm.gd")
const StageScoreStoreScript := preload("res://scripts/stage/StageScoreStore.gd")
const BOX_SIZE := Vector2(132, 104) # ステージ箱の表示サイズ。
const BOX_GAP := 44.0 # 箱同士の間隔。
const BOX_Y := 136.0 # Stage0箱の上端Y座標。
const STAGE_GRID_Y := 322.0 # Stage1以降の箱を並べ始めるY座標。
const BOX_ROW_GAP := 170.0 # 箱の段同士の間隔。
const BOX_COLUMNS := 5 # 1段に並べる箱数。
const PLAYER_Y_OFFSET := 38.0 # プレイヤーが箱から離れる距離。
const PLAYER_SCALE := Vector2(1.7, 1.7) # ステージ選択用プレイヤーの表示倍率。
const BITE_LUNGE_DISTANCE := 72.0 # 噛み入力時に箱へ寄る距離。
const ROOM_WIDTH := 1280.0 # ステージ選択画面の基準幅。
const ROOM_HEIGHT := 720.0 # ステージ選択画面の基準高さ。

var stage_paths: Array[String] = [ # 各箱が開くステージScene。
	"res://stage/Stage0.tscn",
	"res://stage/Stage1.tscn",
	"res://stage/Stage2.tscn",
	"res://stage/Stage3.tscn",
	"res://stage/Stage4.tscn",
	"res://stage/Stage5.tscn",
	"res://stage/Stage6.tscn",
	"res://stage/Stage7.tscn",
	"res://stage/Stage8.tscn",
	"res://stage/Stage9.tscn",
	"res://stage/Stage10.tscn",
]

var selected_index := 0 # 現在選択中のステージ番号。
var boxes: Array[Node2D] = [] # ステージ箱ノード一覧。
var player_sprite: AnimatedSprite2D # 箱の前にいるプレイヤー。
var stage_bgm: Node # 選択画面BGMを担当する部品。
var moving := false # 噛み演出中かどうか。
var bite_hint: Node2D # 選択箱をKで噛むことを示す表示。
var unlocked_indices: Array[int] = [] # 選択可能なステージ番号。

# 画面要素を生成する。
func _ready() -> void:
	_refresh_unlocked_indices()
	_build_background()
	_build_bgm()
	_build_stage_boxes()
	_build_player()
	selected_index = unlocked_indices[0] if not unlocked_indices.is_empty() else 0
	_update_selection(false)

# 左右移動と噛み入力を受け付ける。
func _unhandled_input(event: InputEvent) -> void:
	if moving:
		return
	if event.is_action_pressed("move_left"):
		_move_selection_linear(-1)
	elif event.is_action_pressed("move_right"):
		_move_selection_linear(1)
	elif _is_key_pressed(event, [KEY_UP, KEY_W]):
		_move_selection_vertical(-1)
	elif _is_key_pressed(event, [KEY_DOWN, KEY_S]):
		_move_selection_vertical(1)
	elif event.is_action_pressed("bite"):
		_bite_selected_stage()

# 背景と床を作る。
func _build_background() -> void:
	var background := ColorRect.new()
	background.color = Color("#080914")
	background.size = Vector2(ROOM_WIDTH, ROOM_HEIGHT)
	background.z_index = -20
	add_child(background)

	for i in 9:
		var band := ColorRect.new()
		var alpha := 0.07 + float(i) * 0.012
		band.color = Color(0.22, 0.13, 0.31, alpha)
		band.position = Vector2(0, 90 + i * 58)
		band.size = Vector2(ROOM_WIDTH, 24)
		band.z_index = -18
		add_child(band)

	var header := Label.new()
	header.text = "STAGE SELECT"
	header.position = Vector2(0, 42)
	header.size = Vector2(ROOM_WIDTH, 54)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 34)
	header.add_theme_color_override("font_color", Color("#fff0a8"))
	header.add_theme_color_override("font_shadow_color", Color("#2d1648"))
	header.add_theme_constant_override("shadow_offset_x", 4)
	header.add_theme_constant_override("shadow_offset_y", 4)
	add_child(header)

	var ranking := StageScoreStoreScript.ranking_payload()
	var total := Label.new()
	total.text = "TOTAL SCORE  %d    CLEAR  %d/%d" % [
		int(ranking.get("total_score", 0)),
		int(ranking.get("completed_stage_count", 0)),
		int(ranking.get("stage_count", 0)),
	]
	total.position = Vector2(0, 88)
	total.size = Vector2(ROOM_WIDTH, 32)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	total.add_theme_font_size_override("font_size", 20)
	total.add_theme_color_override("font_color", Color("#d5d9e2"))
	total.add_theme_color_override("font_shadow_color", Color("#11121f"))
	total.add_theme_constant_override("shadow_offset_x", 2)
	total.add_theme_constant_override("shadow_offset_y", 2)
	add_child(total)

# 選択画面BGMを作成する。
func _build_bgm() -> void:
	stage_bgm = StageBgmScript.new()
	stage_bgm.name = "StageBgm"
	add_child(stage_bgm)
	stage_bgm.setup()

# ステージ箱を5列グリッドで並べる。
func _build_stage_boxes() -> void:
	var total_width := BOX_COLUMNS * BOX_SIZE.x + (BOX_COLUMNS - 1) * BOX_GAP
	var start_x := (1280.0 - total_width) * 0.5
	_build_route_tracks(start_x)
	for i in stage_paths.size():
		var box := _create_stage_box(i)
		box.position = _stage_box_position(i, start_x)
		box.visible = _is_stage_unlocked(i)
		add_child(box)
		boxes.append(box)
	_build_bite_hint()

# 箱の下をつなぐレールと足場を描く。
func _build_route_tracks(start_x: float) -> void:
	for index in unlocked_indices:
		var position := _stage_box_position(index, start_x)
		var center_x := position.x + BOX_SIZE.x * 0.5
		var y := position.y + BOX_SIZE.y + 50.0
		_add_track_bar(Vector2(center_x - 46.0, y - 8.0), Vector2(92.0, 10.0), Color("#d5a53c"))
		_add_track_bar(Vector2(center_x - 36.0, y - 2.0), Vector2(72.0, 5.0), Color("#fff0a8"))

	var rows := int(ceil(max(0.0, float(unlocked_indices.size() - 1)) / float(BOX_COLUMNS)))
	for row in rows:
		var count := mini(BOX_COLUMNS, unlocked_indices.size() - 1 - row * BOX_COLUMNS)
		if count <= 0:
			continue
		var y := STAGE_GRID_Y + row * BOX_ROW_GAP + BOX_SIZE.y + 50.0
		var first_center := start_x + BOX_SIZE.x * 0.5
		var last_center := start_x + (count - 1) * (BOX_SIZE.x + BOX_GAP) + BOX_SIZE.x * 0.5
		_add_track_bar(Vector2(first_center - 42.0, y), Vector2(last_center - first_center + 84.0, 16.0), Color("#3a254e"))
		_add_track_bar(Vector2(first_center - 42.0, y + 16.0), Vector2(last_center - first_center + 84.0, 8.0), Color("#17101f"))

# ステージ番号から箱の配置を返す。
func _stage_box_position(index: int, start_x: float) -> Vector2:
	if index == 0:
		return Vector2((ROOM_WIDTH - BOX_SIZE.x) * 0.5, BOX_Y)
	var adjusted := index - 1
	var column := adjusted % BOX_COLUMNS
	var row := int(adjusted / BOX_COLUMNS)
	return Vector2(start_x + column * (BOX_SIZE.x + BOX_GAP), STAGE_GRID_Y + row * BOX_ROW_GAP)

# レール用の矩形を追加する。
func _add_track_bar(position: Vector2, size: Vector2, color: Color) -> void:
	var bar := ColorRect.new()
	bar.color = color
	bar.position = position
	bar.size = size
	bar.z_index = -8
	add_child(bar)

# 1つぶんのステージ箱を作る。
func _create_stage_box(stage_number: int) -> Node2D:
	var root := Node2D.new()
	root.name = "StageBox%d" % stage_number

	var shadow := ColorRect.new()
	shadow.color = Color(0.0, 0.0, 0.0, 0.32)
	shadow.position = Vector2(10, 12)
	shadow.size = BOX_SIZE
	root.add_child(shadow)

	var pedestal_shadow := ColorRect.new()
	pedestal_shadow.color = Color(0.0, 0.0, 0.0, 0.28)
	pedestal_shadow.position = Vector2(12, BOX_SIZE.y + 8)
	pedestal_shadow.size = Vector2(BOX_SIZE.x - 24, 18)
	root.add_child(pedestal_shadow)

	var face := ColorRect.new()
	face.name = "Face"
	face.color = Color("#eee5c0")
	face.size = BOX_SIZE
	root.add_child(face)

	var top_edge := ColorRect.new()
	top_edge.color = Color("#fff6d8")
	top_edge.size = Vector2(BOX_SIZE.x, 10)
	root.add_child(top_edge)

	var left_edge := ColorRect.new()
	left_edge.color = Color("#fff6d8")
	left_edge.size = Vector2(10, BOX_SIZE.y)
	root.add_child(left_edge)

	var right_edge := ColorRect.new()
	right_edge.color = Color("#7b6684")
	right_edge.position = Vector2(BOX_SIZE.x - 10, 0)
	right_edge.size = Vector2(10, BOX_SIZE.y)
	root.add_child(right_edge)

	var bottom_edge := ColorRect.new()
	bottom_edge.color = Color("#5c4c68")
	bottom_edge.position = Vector2(0, BOX_SIZE.y - 10)
	bottom_edge.size = Vector2(BOX_SIZE.x, 10)
	root.add_child(bottom_edge)

	var label := Label.new()
	label.text = "STAGE\n%d" % stage_number
	label.position = Vector2(0, 13)
	label.size = Vector2(BOX_SIZE.x, 64)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.08, 0.085, 0.1))
	label.add_theme_color_override("font_shadow_color", Color("#cfae62"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(label)

	var stars := Label.new()
	stars.text = _stage_star_text(stage_number)
	stars.position = Vector2(0, 70)
	stars.size = Vector2(BOX_SIZE.x, 24)
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stars.add_theme_font_size_override("font_size", 20)
	stars.add_theme_color_override("font_color", Color("#ffd45b"))
	stars.add_theme_color_override("font_shadow_color", Color("#1b1730"))
	stars.add_theme_constant_override("shadow_offset_x", 2)
	stars.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(stars)

	var pedestal := ColorRect.new()
	pedestal.color = Color("#3b2850")
	pedestal.position = Vector2(16, BOX_SIZE.y + 2)
	pedestal.size = Vector2(BOX_SIZE.x - 32, 14)
	root.add_child(pedestal)

	return root

# 保存済み進行度から選択可能ステージ一覧を作る。
func _refresh_unlocked_indices() -> void:
	unlocked_indices.clear()
	for i in stage_paths.size():
		if _is_stage_unlocked(i):
			unlocked_indices.append(i)

# 指定ステージ番号が解放済みか返す。
func _is_stage_unlocked(index: int) -> bool:
	return StageScoreStoreScript.is_stage_unlocked(_stage_id_for_index(index))

# Kで選ぶことを選択箱の近くに表示する。
func _build_bite_hint() -> void:
	bite_hint = Node2D.new()
	bite_hint.name = "BiteHint"
	bite_hint.z_index = 12
	add_child(bite_hint)

	var key := Label.new()
	key.name = "Key"
	key.text = "K"
	key.position = Vector2(-24, -18)
	key.size = Vector2(48, 36)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", 26)
	key.add_theme_color_override("font_color", Color("#fff0a8"))
	key.add_theme_color_override("font_shadow_color", Color("#10101a"))
	key.add_theme_constant_override("shadow_offset_x", 3)
	key.add_theme_constant_override("shadow_offset_y", 3)
	bite_hint.add_child(key)

	var top_fang := _create_hint_fang(Vector2(0, -18), false)
	var bottom_fang := _create_hint_fang(Vector2(0, 18), true)
	bite_hint.add_child(top_fang)
	bite_hint.add_child(bottom_fang)

# 簡易的な牙マーカーを作る。
func _create_hint_fang(position_value: Vector2, flip_vertical: bool) -> Polygon2D:
	var fang := Polygon2D.new()
	fang.position = position_value
	fang.polygon = PackedVector2Array([Vector2(-10, -7), Vector2(10, -7), Vector2(0, 12)])
	fang.color = Color("#99e8ff")
	if flip_vertical:
		fang.scale.y = -1.0
	return fang

# プレイヤーキャラクターを作る。
func _build_player() -> void:
	player_sprite = AnimatedSprite2D.new()
	player_sprite.name = "Player"
	var frames := SpriteFrameBuilder.from_folder("res://assets/player/walk", &"walk", 8.0, true)
	SpriteFrameBuilder.add_animation(frames, "res://assets/player/bite", &"bite", 12.0, false)
	player_sprite.sprite_frames = frames
	player_sprite.scale = PLAYER_SCALE
	player_sprite.play(&"walk")
	add_child(player_sprite)

# 選択状態の見た目とプレイヤー位置を更新する。
func _update_selection(animated := true) -> void:
	for i in boxes.size():
		boxes[i].visible = _is_stage_unlocked(i)
		var face := boxes[i].get_node("Face") as ColorRect
		var selected := i == selected_index and _is_stage_unlocked(i)
		face.color = Color("#fff0a8") if selected else Color("#eee5c0")
		boxes[i].modulate = Color.WHITE
		boxes[i].scale = Vector2(1.06, 1.06) if selected else Vector2.ONE

	var target_position := _player_position_for_index(selected_index)
	if animated:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(player_sprite, "global_position", target_position, 0.12)
	else:
		player_sprite.global_position = target_position
	player_sprite.play(&"walk")
	if bite_hint != null:
		bite_hint.global_position = target_position + Vector2(0, -32)
		bite_hint.visible = _is_stage_unlocked(selected_index)

# 指定箱の前に立つプレイヤー位置を返す。
func _player_position_for_index(index: int) -> Vector2:
	var box := boxes[index]
	return box.global_position + Vector2(BOX_SIZE.x * 0.5, BOX_SIZE.y + PLAYER_Y_OFFSET)

# 選択中の箱に噛みついてステージへ移動する。
func _bite_selected_stage() -> void:
	if not _is_stage_unlocked(selected_index):
		return
	moving = true
	if bite_hint != null:
		bite_hint.visible = false
	var selected_box := boxes[selected_index]
	var start_position := player_sprite.global_position
	var bite_position := start_position + Vector2(0, -BITE_LUNGE_DISTANCE)
	player_sprite.play(&"bite")
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(player_sprite, "global_position", bite_position, 0.10)
	tween.tween_callback(func(): _break_stage_box(selected_box))
	tween.tween_interval(0.18)
	tween.tween_property(player_sprite, "global_position", start_position, 0.10)
	tween.tween_callback(func(): get_tree().change_scene_to_file(stage_paths[selected_index]))

# 左右入力では解放済みステージだけを巡回する。
func _move_selection_linear(delta: int) -> void:
	if unlocked_indices.is_empty():
		return
	var current := unlocked_indices.find(selected_index)
	if current < 0:
		current = 0
	current = posmod(current + delta, unlocked_indices.size())
	selected_index = unlocked_indices[current]
	_update_selection()

# 上下入力ではStage0とStage1以降の段を移動する。
func _move_selection_vertical(direction: int) -> void:
	if selected_index == 0 and direction > 0 and _is_stage_unlocked(1):
		selected_index = 1
	else:
		var target := selected_index + direction * BOX_COLUMNS
		if selected_index > 0 and direction < 0 and target < 1:
			selected_index = 0
			_update_selection()
			return
		if target < 1 or target >= boxes.size() or not _is_stage_unlocked(target):
			return
		selected_index = target
	_update_selection()

# 噛まれた箱を砕いて消す。
func _break_stage_box(box: Node2D) -> void:
	box.visible = false
	var root := get_tree().current_scene
	if root == null:
		root = self
	for i in 24:
		var shard := ColorRect.new()
		shard.color = [Color.WHITE, Color(0.86, 0.88, 0.9), Color(0.64, 0.66, 0.7)][i % 3]
		shard.size = Vector2(randf_range(8.0, 18.0), randf_range(6.0, 16.0))
		shard.global_position = box.global_position + Vector2(randf_range(8.0, BOX_SIZE.x - 8.0), randf_range(8.0, BOX_SIZE.y - 8.0))
		root.add_child(shard)
		var angle := randf_range(-PI * 0.95, -PI * 0.05)
		var distance := randf_range(54.0, 132.0)
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", shard.global_position + Vector2(cos(angle), sin(angle)) * distance, 0.38)
		tween.tween_property(shard, "rotation", randf_range(-2.8, 2.8), 0.38)
		tween.tween_property(shard, "modulate:a", 0.0, 0.38)
		tween.set_parallel(false)
		tween.tween_callback(shard.queue_free)

# 指定キー群の押下を返す。
func _is_key_pressed(event: InputEvent, keys: Array[int]) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	return keys.has(key_event.keycode)

# 保存済みスコアからステージの星を表示する。
func _stage_star_text(stage_number: int) -> String:
	var best := StageScoreStoreScript.best_for_stage("Stage%d" % stage_number)
	var stars := int(best.get("stars", 0))
	var text := ""
	for i in stars:
		text += "★"
	return text

# stage_pathsから進行度保存用IDを作る。
func _stage_id_for_index(index: int) -> String:
	return stage_paths[index].get_file().get_basename()
