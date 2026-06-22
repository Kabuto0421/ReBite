# 2026-06-22: 青いバナーでボス名と開始命令を見せるイントロ演出。
class_name BossIntroPresenter
extends Node

signal finished # イントロ終了後にステージ再開を通知する。

var canvas: CanvasLayer # ボスイントロを最前面へ表示するCanvas。
var overlay: ColorRect # ステージ画面を暗くする幕。
var banner: ColorRect # 右から登場する青い横長バナー。
var portrait: AnimatedSprite2D # バナー内でIdleするボス画像。
var title_label: Label # BOSS_BOARを表示するラベル。
var command_label: Label # ボスを倒せという命令を表示するラベル。
var _tree_was_paused := false # 演出前のpause状態。
var _playing := false # 現在イントロを再生しているか。
var _intro_tween: Tween # 二重終了を防ぐイントロTween。

# バナー部品を生成する。
func setup(stage: Node, boss: Node, title: String, command: String, banner_color: Color) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = CanvasLayer.new()
	canvas.name = "BossIntro"
	canvas.layer = 120
	stage.add_child(canvas)

	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.01, 0.015, 0.025, 0.68)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)

	banner = ColorRect.new()
	banner.color = banner_color
	banner.size = Vector2(960.0, 230.0)
	banner.position = Vector2(1330.0, 245.0)
	overlay.add_child(banner)

	var stripe := ColorRect.new()
	stripe.color = Color(0.22, 0.72, 1.0, 0.72)
	stripe.position = Vector2(0.0, 12.0)
	stripe.size = Vector2(960.0, 8.0)
	banner.add_child(stripe)

	portrait = AnimatedSprite2D.new()
	portrait.position = Vector2(235.0, 170.0)
	portrait.sprite_frames = boss.sprite.sprite_frames
	portrait.animation = &"idle"
	portrait.scale = Vector2(0.48, 0.48)
	portrait.play()
	banner.add_child(portrait)

	title_label = Label.new()
	title_label.position = Vector2(410.0, 56.0)
	title_label.size = Vector2(500.0, 76.0)
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 50)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.04, 0.12))
	title_label.add_theme_constant_override("shadow_offset_x", 4)
	title_label.add_theme_constant_override("shadow_offset_y", 5)
	banner.add_child(title_label)

	command_label = Label.new()
	command_label.anchor_left = 0.0
	command_label.anchor_right = 1.0
	command_label.anchor_top = 0.5
	command_label.anchor_bottom = 0.5
	command_label.offset_top = 72.0
	command_label.offset_bottom = 150.0
	command_label.text = command
	command_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	command_label.add_theme_font_size_override("font_size", 42)
	command_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
	command_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	command_label.add_theme_constant_override("shadow_offset_x", 3)
	command_label.add_theme_constant_override("shadow_offset_y", 4)
	command_label.modulate.a = 0.0
	overlay.add_child(command_label)

# 世界を停止し、登場・滞在・命令・退場を順に再生する。
func play(enter_time: float, hold_time: float, command_time: float, exit_time: float) -> void:
	_tree_was_paused = get_tree().paused
	_playing = true
	get_tree().paused = true
	var viewport_width := get_viewport().get_visible_rect().size.x
	var centered_x := (viewport_width - banner.size.x) * 0.5
	_intro_tween = create_tween()
	_intro_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_intro_tween.set_trans(Tween.TRANS_QUART)
	_intro_tween.set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(banner, "position:x", centered_x, enter_time)
	_intro_tween.tween_interval(hold_time)
	_intro_tween.tween_property(command_label, "modulate:a", 1.0, 0.15)
	_intro_tween.tween_interval(command_time)
	_intro_tween.set_parallel(true)
	_intro_tween.tween_property(banner, "position:x", -banner.size.x - 40.0, exit_time)
	_intro_tween.tween_property(overlay, "modulate:a", 0.0, exit_time)
	_intro_tween.set_parallel(false)
	_intro_tween.tween_callback(_finish)

# pauseを復元してイントロノードを破棄する。
func _finish() -> void:
	if not _playing:
		return
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = null
	get_tree().paused = _tree_was_paused
	_playing = false
	finished.emit()
	if is_instance_valid(canvas):
		canvas.queue_free()

# イントロ途中でシーンが破棄されてもpauseを残さない。
func _exit_tree() -> void:
	if _playing and get_tree() != null:
		get_tree().paused = _tree_was_paused
