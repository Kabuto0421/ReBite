# 2026-06-14: ステージ選択画面の箱配置と入力移動。
extends Node2D

const SpriteFrameBuilder := preload("res://scripts/core/SpriteFrameBuilder.gd")
const StageBgmScript := preload("res://scripts/stage/StageBgm.gd")
const STAGE_COUNT := 8 # 選択可能なステージ数。
const BOX_SIZE := Vector2(142, 118) # ステージ箱の表示サイズ。
const BOX_GAP := 35.0 # 箱同士の間隔。
const BOX_Y := 330.0 # 箱の上端Y座標。
const PLAYER_Y_OFFSET := 66.0 # プレイヤーが箱から離れる距離。
const PLAYER_SCALE := Vector2(1.7, 1.7) # ステージ選択用プレイヤーの表示倍率。
const BITE_LUNGE_DISTANCE := 72.0 # 噛み入力時に箱へ寄る距離。

var stage_paths: Array[String] = [ # 各箱が開くステージScene。
	"res://stage/Stage1.tscn",
	"res://stage/Stage2.tscn",
	"res://stage/Stage3.tscn",
	"res://stage/Stage4.tscn",
	"res://stage/Stage5.tscn",
	"res://stage/Stage6.tscn",
	"res://stage/Stage7.tscn",
	"res://stage/Stage8.tscn",
]

var selected_index := 0 # 現在選択中のステージ番号。
var boxes: Array[Node2D] = [] # ステージ箱ノード一覧。
var player_sprite: AnimatedSprite2D # 箱の前にいるプレイヤー。
var stage_bgm: Node # 選択画面BGMを担当する部品。
var moving := false # 噛み演出中かどうか。

# 画面要素を生成する。
func _ready() -> void:
	_build_background()
	_build_bgm()
	_build_stage_boxes()
	_build_player()
	_update_selection(false)

# 左右移動と噛み入力を受け付ける。
func _unhandled_input(event: InputEvent) -> void:
	if moving:
		return
	if event.is_action_pressed("move_left"):
		selected_index = posmod(selected_index - 1, boxes.size())
		_update_selection()
	elif event.is_action_pressed("move_right"):
		selected_index = posmod(selected_index + 1, boxes.size())
		_update_selection()
	elif event.is_action_pressed("bite"):
		_bite_selected_stage()

# 背景と床を作る。
func _build_background() -> void:
	var background := ColorRect.new()
	background.color = Color(0.055, 0.06, 0.075)
	background.size = Vector2(1280, 720)
	background.z_index = -20
	add_child(background)

	var floor := ColorRect.new()
	floor.color = Color(0.13, 0.135, 0.15)
	floor.position = Vector2(0, BOX_Y + BOX_SIZE.y + 52.0)
	floor.size = Vector2(1280, 170)
	floor.z_index = -10
	add_child(floor)

# 選択画面BGMを作成する。
func _build_bgm() -> void:
	stage_bgm = StageBgmScript.new()
	stage_bgm.name = "StageBgm"
	add_child(stage_bgm)
	stage_bgm.setup()

# 5つのステージ箱を横に並べる。
func _build_stage_boxes() -> void:
	var total_width := STAGE_COUNT * BOX_SIZE.x + (STAGE_COUNT - 1) * BOX_GAP
	var start_x := (1280.0 - total_width) * 0.5
	for i in STAGE_COUNT:
		var box := _create_stage_box(i + 1)
		box.position = Vector2(start_x + i * (BOX_SIZE.x + BOX_GAP), BOX_Y)
		add_child(box)
		boxes.append(box)

# 1つぶんの白いステージ箱を作る。
func _create_stage_box(stage_number: int) -> Node2D:
	var root := Node2D.new()
	root.name = "StageBox%d" % stage_number

	var shadow := ColorRect.new()
	shadow.color = Color(0.0, 0.0, 0.0, 0.32)
	shadow.position = Vector2(10, 12)
	shadow.size = BOX_SIZE
	root.add_child(shadow)

	var face := ColorRect.new()
	face.name = "Face"
	face.color = Color(0.94, 0.95, 0.92)
	face.size = BOX_SIZE
	root.add_child(face)

	var top_edge := ColorRect.new()
	top_edge.color = Color(1.0, 1.0, 1.0)
	top_edge.size = Vector2(BOX_SIZE.x, 10)
	root.add_child(top_edge)

	var left_edge := ColorRect.new()
	left_edge.color = Color(1.0, 1.0, 1.0)
	left_edge.size = Vector2(10, BOX_SIZE.y)
	root.add_child(left_edge)

	var right_edge := ColorRect.new()
	right_edge.color = Color(0.68, 0.7, 0.72)
	right_edge.position = Vector2(BOX_SIZE.x - 10, 0)
	right_edge.size = Vector2(10, BOX_SIZE.y)
	root.add_child(right_edge)

	var bottom_edge := ColorRect.new()
	bottom_edge.color = Color(0.62, 0.64, 0.66)
	bottom_edge.position = Vector2(0, BOX_SIZE.y - 10)
	bottom_edge.size = Vector2(BOX_SIZE.x, 10)
	root.add_child(bottom_edge)

	var label := Label.new()
	label.text = "Stage\n%d" % stage_number
	label.position = Vector2(0, 20)
	label.size = Vector2(BOX_SIZE.x, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.08, 0.085, 0.1))
	label.add_theme_color_override("font_shadow_color", Color(0.86, 0.88, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(label)

	return root

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
		var face := boxes[i].get_node("Face") as ColorRect
		face.color = Color(1.0, 0.98, 0.88) if i == selected_index else Color(0.94, 0.95, 0.92)
		boxes[i].scale = Vector2(1.06, 1.06) if i == selected_index else Vector2.ONE

	var target_position := _player_position_for_index(selected_index)
	if animated:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(player_sprite, "global_position", target_position, 0.12)
	else:
		player_sprite.global_position = target_position
	player_sprite.play(&"walk")

# 指定箱の前に立つプレイヤー位置を返す。
func _player_position_for_index(index: int) -> Vector2:
	var box := boxes[index]
	return box.global_position + Vector2(BOX_SIZE.x * 0.5, BOX_SIZE.y + PLAYER_Y_OFFSET)

# 選択中の箱に噛みついてステージへ移動する。
func _bite_selected_stage() -> void:
	moving = true
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
