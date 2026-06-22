# 2026-06-22: ステージ開始命令、目標進捗、クリア表示を管理する。
class_name StageHud
extends Node

var hud_label: Label # 操作説明を表示するラベル。
var clear_label: Label # ステージクリアを表示するラベル。
var replay_label: Label # リプレイ案内を表示するラベル。
var stage_info_label: Label # ステージ名を左上に表示するラベル。
var objective_label: Label # 現在の目標と進捗を右上に表示するラベル。
var briefing_overlay: ColorRect # 開始命令の背後を暗くする幕。
var briefing_stage_label: Label # 開始演出中のステージ名。
var briefing_command_label: Label # 開始演出中の大きな命令文。
var objective_prefix := "" # 撃破進捗の前に表示する目標文。

# HUDノード一式を生成する。
func setup(stage: Node) -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	canvas.layer = 100
	stage.add_child(canvas)

	hud_label = Label.new()
	hud_label.text = "A/D or ←/→: move   Space: jump   K: bite memory tag   R: replay"
	hud_label.anchor_top = 1.0
	hud_label.anchor_bottom = 1.0
	hud_label.offset_left = 20.0
	hud_label.offset_top = -38.0
	hud_label.offset_right = 760.0
	hud_label.offset_bottom = -12.0
	hud_label.add_theme_font_size_override("font_size", 14)
	hud_label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88, 0.78))
	hud_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud_label.add_theme_constant_override("shadow_offset_x", 2)
	hud_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(hud_label)

	stage_info_label = Label.new()
	stage_info_label.offset_left = 24.0
	stage_info_label.offset_top = 20.0
	stage_info_label.offset_right = 550.0
	stage_info_label.offset_bottom = 88.0
	stage_info_label.add_theme_font_size_override("font_size", 20)
	stage_info_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.58))
	stage_info_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	stage_info_label.add_theme_constant_override("shadow_offset_x", 2)
	stage_info_label.add_theme_constant_override("shadow_offset_y", 2)
	stage_info_label.modulate.a = 0.0
	canvas.add_child(stage_info_label)

	objective_label = Label.new()
	objective_label.anchor_left = 1.0
	objective_label.anchor_right = 1.0
	objective_label.offset_left = -540.0
	objective_label.offset_top = 24.0
	objective_label.offset_right = -24.0
	objective_label.offset_bottom = 66.0
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.add_theme_font_size_override("font_size", 22)
	objective_label.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
	objective_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	objective_label.add_theme_constant_override("shadow_offset_x", 2)
	objective_label.add_theme_constant_override("shadow_offset_y", 2)
	objective_label.modulate.a = 0.0
	canvas.add_child(objective_label)

	clear_label = Label.new()
	clear_label.text = ""
	clear_label.anchor_left = 0.0
	clear_label.anchor_right = 1.0
	clear_label.offset_left = -12.0
	clear_label.offset_right = -12.0
	clear_label.offset_top = 150.0
	clear_label.offset_bottom = 210.0
	clear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clear_label.add_theme_font_size_override("font_size", 42)
	clear_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))
	clear_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	clear_label.add_theme_constant_override("shadow_offset_x", 3)
	clear_label.add_theme_constant_override("shadow_offset_y", 3)
	canvas.add_child(clear_label)

	replay_label = Label.new()
	replay_label.text = ""
	replay_label.position = Vector2(500, 640)
	replay_label.add_theme_font_size_override("font_size", 26)
	replay_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
	replay_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	replay_label.add_theme_constant_override("shadow_offset_x", 3)
	replay_label.add_theme_constant_override("shadow_offset_y", 3)
	canvas.add_child(replay_label)

	briefing_overlay = ColorRect.new()
	briefing_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	briefing_overlay.color = Color(0.015, 0.02, 0.03, 0.74)
	briefing_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	briefing_overlay.visible = false
	canvas.add_child(briefing_overlay)

	briefing_stage_label = Label.new()
	briefing_stage_label.anchor_left = 0.0
	briefing_stage_label.anchor_right = 1.0
	briefing_stage_label.anchor_top = 0.5
	briefing_stage_label.anchor_bottom = 0.5
	briefing_stage_label.offset_top = -106.0
	briefing_stage_label.offset_bottom = -58.0
	briefing_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	briefing_stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	briefing_stage_label.add_theme_font_size_override("font_size", 24)
	briefing_stage_label.add_theme_color_override("font_color", Color(0.74, 0.82, 0.9))
	briefing_stage_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	briefing_stage_label.add_theme_constant_override("shadow_offset_x", 2)
	briefing_stage_label.add_theme_constant_override("shadow_offset_y", 2)
	briefing_overlay.add_child(briefing_stage_label)

	briefing_command_label = Label.new()
	briefing_command_label.anchor_left = 0.0
	briefing_command_label.anchor_right = 1.0
	briefing_command_label.anchor_top = 0.5
	briefing_command_label.anchor_bottom = 0.5
	briefing_command_label.offset_top = -58.0
	briefing_command_label.offset_bottom = 54.0
	briefing_command_label.pivot_offset = Vector2(640.0, 56.0)
	briefing_command_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	briefing_command_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	briefing_command_label.add_theme_font_size_override("font_size", 56)
	briefing_command_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	briefing_command_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.02, 0.01))
	briefing_command_label.add_theme_constant_override("shadow_offset_x", 4)
	briefing_command_label.add_theme_constant_override("shadow_offset_y", 5)
	briefing_overlay.add_child(briefing_command_label)

# ステージ開始命令を表示し、常駐HUDへ切り替える。
func play_briefing(stage_name: String, command_text: String, objective_text: String, hold_time: float, transition_time: float) -> void:
	briefing_stage_label.text = stage_name
	briefing_command_label.text = command_text
	prepare_persistent_hud(stage_name, objective_text)
	briefing_overlay.visible = true
	briefing_overlay.modulate.a = 1.0
	briefing_command_label.scale = Vector2(0.82, 0.82)
	stage_info_label.modulate.a = 0.0
	objective_label.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(briefing_command_label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(briefing_overlay, "color", Color(0.015, 0.02, 0.03, 0.58), 0.16)
	tween.set_parallel(false)
	tween.tween_interval(hold_time)
	tween.set_parallel(true)
	tween.tween_property(briefing_overlay, "modulate:a", 0.0, transition_time)
	tween.tween_property(stage_info_label, "modulate:a", 1.0, transition_time)
	tween.tween_property(objective_label, "modulate:a", 1.0, transition_time)
	tween.set_parallel(false)
	tween.tween_callback(func(): briefing_overlay.visible = false)

# ボス演出など外部イントロ用に常駐HUDの内容を準備する。
func prepare_persistent_hud(stage_name: String, objective_text: String) -> void:
	stage_info_label.text = stage_name
	objective_label.text = objective_text
	stage_info_label.modulate.a = 0.0
	objective_label.modulate.a = 0.0

# 準備済みのステージ名と目標を表示する。
func show_persistent_hud(transition_time: float = 0.25) -> void:
	if transition_time <= 0.0:
		stage_info_label.modulate.a = 1.0
		objective_label.modulate.a = 1.0
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(stage_info_label, "modulate:a", 1.0, transition_time)
	tween.tween_property(objective_label, "modulate:a", 1.0, transition_time)

# 操作説明を変更する。
func set_hud_text(text: String) -> void:
	if hud_label != null:
		hud_label.text = text

# クリア表示を変更する。
func set_clear_text(text: String) -> void:
	if clear_label != null:
		clear_label.text = text

# リプレイ案内を変更する。
func set_replay_text(text: String) -> void:
	if replay_label != null:
		replay_label.text = text

# 右上の撃破進捗を更新する。
func set_defeat_progress(defeated: int, total: int) -> void:
	if objective_label != null:
		objective_label.text = "%s (%d/%d)" % [objective_prefix, defeated, total]

# 撃破進捗に使う目標文を設定する。
func set_defeat_objective(text: String, defeated: int, total: int) -> void:
	objective_prefix = text
	set_defeat_progress(defeated, total)

# 現在の目標を達成済み表示にする。
func mark_objective_complete() -> void:
	if objective_label != null:
		objective_label.text += "  達成"
		objective_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32))

# プレイヤーや敵が復帰不能になった場合の案内を更新する。
func update_replay_prompt(player: Node, enemies: Array[Node]) -> void:
	if replay_label == null or player == null:
		return
	var player_low: bool = player.global_position.y > 520.0
	var enemy_stuck := false
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_low: bool = enemy.global_position.y > 560.0
		var enemy_far: bool = enemy.global_position.x < -120.0 or enemy.global_position.x > 1320.0
		if enemy_low or enemy_far:
			enemy_stuck = true
			break
	set_replay_text("R: replay" if player_low or enemy_stuck else "")
