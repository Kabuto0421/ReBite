# 2026-06-22: DASH、SMASH、記憶吸収、ボス名を可変時間で提示する導入演出。
class_name BossIntroPresenter
extends Node

signal finished # イントロ終了後にStage10へ通知する。

const INTRO_FRAME_DIR := "res://assets/boss/boss_intro/frames/"

static var _intro_seen := false # 同一実行中に初回イントロを見たか。

var canvas: CanvasLayer # 演出を最前面へ出すCanvas。
var overlay: ColorRect # 背景を暗くする幕。
var banner: ColorRect # 右から中央へ入る青いボスバナー。
var action_sprite: Sprite2D # Roar、DASH、SMASHを順に表示する。
var boss_portrait: AnimatedSprite2D # 記憶吸収とボス名表示に残すIdle姿。
var action_label: Label # 現在紹介中の行動名。
var title_label: Label # 最後にBOSS_BOARを表示する。
var hp_label: Label # 5区画のボスHPを表示する。
var memory_panel_left: Sprite2D # DASH記憶パネル。
var memory_panel_right: Sprite2D # SMASH記憶パネル。
var absorb_sprite: Sprite2D # 2つの記憶が吸収されるエフェクト。
var _tree_was_paused := false # 演出前のpause状態。
var _playing := false # イントロ実行中か。
var _intro_tween: Tween # 4秒タイムライン。
var _memory_tween: Tween # 記憶吸収パネルの補助Tween。
var _skippable := false # 2回目以降のイントロか。
var _duration_scale := 1.0 # Stage10 Inspectorから渡される時間倍率。
var _boar_scale := 1.0 # Stage10 Inspectorから渡されるBoar倍率。

# イントロ用UI部品を構築する。
func setup(stage: Node, boss: Node, title: String, boar_scale: float = 1.0) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_boar_scale = boar_scale
	canvas = CanvasLayer.new()
	canvas.name = "BossIntro"
	canvas.layer = 120
	stage.add_child(canvas)

	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.006, 0.012, 0.028, 0.86)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)

	banner = ColorRect.new()
	banner.color = Color(0.025, 0.18, 0.58, 0.98)
	banner.size = Vector2(920.0, 300.0)
	banner.position = Vector2(1320.0, 202.0)
	overlay.add_child(banner)

	var stripe := ColorRect.new()
	stripe.color = Color(0.18, 0.78, 1.0, 0.9)
	stripe.position = Vector2(0.0, 12.0)
	stripe.size = Vector2(920.0, 7.0)
	banner.add_child(stripe)

	action_sprite = Sprite2D.new()
	action_sprite.position = Vector2(270.0, 150.0)
	action_sprite.scale = Vector2(1.75, 1.75)
	action_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	banner.add_child(action_sprite)

	boss_portrait = AnimatedSprite2D.new()
	boss_portrait.position = Vector2(460.0, 154.0)
	boss_portrait.scale = Vector2(0.52, 0.52) * _boar_scale
	boss_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boss_portrait.process_mode = Node.PROCESS_MODE_ALWAYS
	boss_portrait.sprite_frames = boss.sprite.sprite_frames
	boss_portrait.animation = &"idle"
	boss_portrait.z_index = 1
	boss_portrait.visible = false
	boss_portrait.play()
	banner.add_child(boss_portrait)

	action_label = _make_label(Vector2(520, 108), Vector2(330, 88), 44, Color(1.0, 0.84, 0.25))
	banner.add_child(action_label)

	title_label = _make_label(Vector2(390, 82), Vector2(470, 74), 48, Color.WHITE)
	title_label.text = title
	title_label.visible = false
	banner.add_child(title_label)

	hp_label = _make_label(Vector2(420, 170), Vector2(420, 54), 28, Color(1.0, 0.74, 0.18))
	hp_label.text = "HP  ■ ■ ■ ■ ■"
	hp_label.visible = false
	banner.add_child(hp_label)

	memory_panel_left = _make_memory_panel(Vector2(250, 145), "memory_tag_components_01_dash_symbol.png")
	memory_panel_right = _make_memory_panel(Vector2(670, 145), "memory_tag_components_02_smash_symbol.png")
	absorb_sprite = Sprite2D.new()
	absorb_sprite.position = Vector2(460, 145)
	absorb_sprite.scale = Vector2(1.45, 1.45)
	absorb_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	absorb_sprite.z_index = 3
	absorb_sprite.visible = false
	banner.add_child(absorb_sprite)

# 世界を止め、Stage10指定倍率のタイムラインを再生する。
func play(duration_scale: float = 1.0) -> void:
	_duration_scale = duration_scale
	_skippable = _intro_seen
	_intro_seen = true
	_tree_was_paused = get_tree().paused
	_playing = true
	get_tree().paused = true
	var centered_x := (get_viewport().get_visible_rect().size.x - banner.size.x) * 0.5
	_intro_tween = create_tween()
	_intro_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_intro_tween.tween_property(banner, "position:x", centered_x, _scaled_time(0.25)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_callback(func(): _show_action("boar_intro_actions_00_roar.png", "ROAR"))
	_intro_tween.tween_interval(_scaled_time(0.40))
	_intro_tween.tween_callback(func(): _show_action("boar_intro_actions_01_dash_anticipation.png", "DASH"))
	_intro_tween.tween_interval(_scaled_time(0.28))
	_intro_tween.tween_callback(func(): _show_action("boar_intro_actions_02_dash_launch.png", "DASH"))
	_intro_tween.tween_interval(_scaled_time(0.42))
	_intro_tween.tween_callback(func(): _show_action("boar_intro_actions_03_smash_anticipation.png", "SMASH"))
	_intro_tween.tween_interval(_scaled_time(0.28))
	_intro_tween.tween_callback(func(): _show_action("boar_intro_actions_04_smash_impact.png", "SMASH"))
	_intro_tween.tween_interval(_scaled_time(0.42))
	_intro_tween.tween_callback(_show_memory_absorb)
	_intro_tween.tween_interval(_scaled_time(0.85))
	_intro_tween.tween_callback(_show_boss_title)
	_intro_tween.tween_interval(_scaled_time(0.72))
	_intro_tween.tween_property(overlay, "modulate:a", 0.0, _scaled_time(0.28))
	_intro_tween.tween_callback(_finish)

# 2回目以降だけKまたは決定入力でイントロを終了する。
func _input(event: InputEvent) -> void:
	if _playing and _skippable and (event.is_action_pressed("bite") or event.is_action_pressed("ui_accept")):
		_finish()
		get_viewport().set_input_as_handled()

# 行動紹介フレームとラベルを切り替える。
func _show_action(file_name: String, label_text: String) -> void:
	_hide_memory_parts()
	boss_portrait.visible = false
	action_sprite.visible = true
	action_sprite.texture = load(INTRO_FRAME_DIR + file_name)
	action_label.visible = true
	action_label.text = label_text

# DASHとSMASHの記憶が中央へ吸収される場面を表示する。
func _show_memory_absorb() -> void:
	action_sprite.visible = false
	action_label.visible = false
	boss_portrait.position = Vector2(460, 154)
	boss_portrait.scale = Vector2(0.52, 0.52) * _boar_scale
	boss_portrait.modulate = Color.WHITE
	boss_portrait.visible = true
	memory_panel_left.position = Vector2(250, 145)
	memory_panel_left.scale = Vector2(1.15, 1.15)
	memory_panel_left.modulate = Color.WHITE
	memory_panel_right.position = Vector2(670, 145)
	memory_panel_right.scale = Vector2(1.15, 1.15)
	memory_panel_right.modulate = Color.WHITE
	memory_panel_left.visible = true
	memory_panel_right.visible = true
	absorb_sprite.visible = true
	absorb_sprite.texture = load(INTRO_FRAME_DIR + "memory_absorb_fx_02_spiral.png")
	_memory_tween = create_tween()
	_memory_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_memory_tween.set_parallel(true)
	_memory_tween.tween_property(memory_panel_left, "position", Vector2(460, 145), _scaled_time(0.52))
	_memory_tween.tween_property(memory_panel_right, "position", Vector2(460, 145), _scaled_time(0.52))
	_memory_tween.tween_property(memory_panel_left, "scale", Vector2(0.3, 0.3), _scaled_time(0.52))
	_memory_tween.tween_property(memory_panel_right, "scale", Vector2(0.3, 0.3), _scaled_time(0.52))
	_memory_tween.tween_property(memory_panel_left, "modulate:a", 0.0, _scaled_time(0.52))
	_memory_tween.tween_property(memory_panel_right, "modulate:a", 0.0, _scaled_time(0.52))
	_memory_tween.set_parallel(false)
	_memory_tween.tween_callback(func(): absorb_sprite.texture = load(INTRO_FRAME_DIR + "memory_absorb_fx_03_flash.png"))

# 最後にボス名と5区画HPを固定表示する。
func _show_boss_title() -> void:
	_hide_memory_parts()
	boss_portrait.position = Vector2(235, 154)
	boss_portrait.scale = Vector2(0.54, 0.54) * _boar_scale
	boss_portrait.modulate = Color.WHITE
	boss_portrait.visible = true
	title_label.visible = true
	hp_label.visible = true

# 記憶紹介部品を隠す。
func _hide_memory_parts() -> void:
	memory_panel_left.visible = false
	memory_panel_right.visible = false
	absorb_sprite.visible = false

# 記憶パネルとシンボルを重ねたSpriteを作る。
func _make_memory_panel(panel_position: Vector2, symbol_file: String) -> Sprite2D:
	var container := Sprite2D.new()
	container.position = panel_position
	container.scale = Vector2(1.15, 1.15)
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.z_index = 2
	container.texture = load(INTRO_FRAME_DIR + "memory_tag_components_00_empty_panel.png")
	container.visible = false
	banner.add_child(container)
	var symbol := Sprite2D.new()
	symbol.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	symbol.texture = load(INTRO_FRAME_DIR + symbol_file)
	container.add_child(symbol)
	return container

# 共通書式のラベルを作る。
func _make_label(label_position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 4)
	return label

# 基準秒数へStage10指定の時間倍率を適用する。
func _scaled_time(base_seconds: float) -> float:
	return base_seconds * _duration_scale

# pauseを戻し、Stage10へ開始可能を通知する。
func _finish() -> void:
	if not _playing:
		return
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = null
	if _memory_tween != null and _memory_tween.is_valid():
		_memory_tween.kill()
	_memory_tween = null
	_playing = false
	get_tree().paused = _tree_was_paused
	finished.emit()
	if is_instance_valid(canvas):
		canvas.queue_free()

# シーン破棄時にpauseを残さない。
func _exit_tree() -> void:
	if _playing and get_tree() != null:
		get_tree().paused = _tree_was_paused
