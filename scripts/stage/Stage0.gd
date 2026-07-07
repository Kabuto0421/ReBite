# 2026-07-07: 影キャラに記憶噛みを実演させるチュートリアルステージ。
extends "res://scripts/stage/StageBase.gd"

const ActionRecordScript := preload("res://scripts/core/ActionRecord.gd")
const MemoryTagScript := preload("res://scripts/entities/MemoryTag.gd")
const ShadowGuideScript := preload("res://scripts/entities/ShadowGuide.gd")
const TutorialSkullDropTargetScript := preload("res://scripts/entities/TutorialSkullDropTarget.gd")
const SkullMonsterScene := preload("res://entities/SkullMonster.tscn")
const PLAYER_GROUND_Y := 362.0
const SHADOW_GROUND_Y := 362.0
const SHADOW_STEP_Y := 318.0
const SKULL_GROUND_Y := 360.0
const PRACTICE_SKULL_START := Vector2(468.0, SKULL_GROUND_Y)
const PRACTICE_SKULL_MID := Vector2(628.0, SKULL_GROUND_Y)
const PRACTICE_SKULL_READY := Vector2(810.0, SKULL_GROUND_Y)
const PRACTICE_HOLE_LEFT_X := 884.0
const PRACTICE_HOLE_RIGHT_X := 1000.0
const PRACTICE_HOLE_CENTER_X := (PRACTICE_HOLE_LEFT_X + PRACTICE_HOLE_RIGHT_X) * 0.5
const PIT_LEFT_EDGE_X := 1150.0
const PIT_RIGHT_EDGE_X := 1380.0
const PIT_CENTER_X := (PIT_LEFT_EDGE_X + PIT_RIGHT_EDGE_X) * 0.5

@export var final_scene_path := "res://stage/Stage1.tscn" # 最後の落下演出後に遷移するScene。
@export var player_dash_tag_offset := Vector2(0.0, -72.0) # 主人公の頭上に出すDASHタグ位置。

var shadow_guide: ShadowGuide # 影キャラ演出用ノード。
var practice_target: TutorialSkullDropTarget # プレイヤーが噛む練習用Skull。
var gate_body: Node2D # 練習噛みで消える壁。
var practice_break_block: ActionBreakGroup # SkullのDASHで壊れる練習用BLOCK。
var practice_hole_cover: Node2D # Skull落下後に新規穴を塞ぐ床。
var final_trigger: Area2D # STAGE 1奈落前の演出開始判定。
var final_sequence_started := false # 最後の強制噛み演出が始まったか。
var player_dash_tag: MemoryTag # 主人公の頭上に出す記憶タグ。
var player_dash_record: Resource # 主人公を落とすDASH記憶。
var final_camera_override_active := false # Stage0終盤演出中に通常追従を上書きするか。
var final_camera_position := Vector2.ZERO # Stage0終盤演出用のカメラ位置。
var final_camera_zoom := Vector2.ONE # Stage0終盤演出用のカメラズーム。
var practice_drop_pending := false # Playerの牙がSkullタグへ届いたら落下演出を始めるか。

# 基盤初期化後に影キャラの演出を開始する。
func _ready() -> void:
	super._ready()
	call_deferred("_start_shadow_demo")

# 通常更新後、終盤演出中だけカメラをStage0専用制御で上書きする。
func _process(delta: float) -> void:
	super._process(delta)
	if final_camera_override_active and camera != null:
		camera.global_position = final_camera_position
		camera.zoom = final_camera_zoom

# Stage0専用の地形とチュートリアル部品を作る。
func _build_world() -> void:
	stage_display_name = "STAGE 0"
	next_stage_path = ""
	bgm_path = "res://assets/bgm/rebite_shadow_bite.ogg"
	normal_camera_offset = Vector2(230.0, -70.0)
	stage_briefing_hold_time = 1.0
	stage_briefing_transition_time = 0.75
	_build_background()
	_build_platforms()
	_build_gate()
	_build_practice_target()
	_build_final_trigger()
	_build_stage_one_sign()

# Stage0では練習用タグにも噛み案内を出す。
func _update_memory_tag_hints(active_target: Node) -> void:
	super._update_memory_tag_hints(active_target)
	if practice_target != null:
		practice_target.set_memory_bite_hint_active(active_target == practice_target)

# Stage0専用の開始命令を表示する。
func _start_stage_briefing() -> void:
	stage_hud.prepare_persistent_hud("STAGE 0", "目標：影を見ろ")
	stage_hud.show_persistent_hud(0.0)

# 背景を暗い洞窟風にする。
func _build_background() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.035, 0.036, 0.048)
	background.position = Vector2(-1600, -520)
	background.size = Vector2(4200, 1600)
	background.z_index = -30
	add_child(background)

	var fog := ColorRect.new()
	fog.name = "LowerFog"
	fog.color = Color(0.11, 0.06, 0.14, 0.22)
	fog.position = Vector2(-1600, 310)
	fog.size = Vector2(4200, 240)
	fog.z_index = -25
	add_child(fog)

# 歩く、ジャンプする、噛む、落とされる流れに必要な足場を置く。
func _build_platforms() -> void:
	_add_platform(Rect2(Vector2(20, 360), Vector2(864, 32)))
	_add_platform(Rect2(Vector2(300, 316), Vector2(150, 32)))
	_add_platform(Rect2(Vector2(PRACTICE_HOLE_RIGHT_X, 360), Vector2(150, 32)))
	_add_platform(Rect2(Vector2(1380, 360), Vector2(78, 32)))
	_add_platform(Rect2(Vector2(20, 168), Vector2(32, 224)))
	_add_platform(Rect2(Vector2(20, 168), Vector2(1438, 32)))
	_add_platform(Rect2(Vector2(1426, 168), Vector2(32, 224)))

# 練習タグを噛むまで通れない小さな壁を作る。
func _build_gate() -> void:
	practice_break_block = ActionBreakGroup.new()
	practice_break_block.name = "PracticeGate"
	practice_break_block.position = Vector2(850, 296)
	practice_break_block.z_index = -4
	practice_break_block.accepted_actions = [&"dash"]
	practice_break_block.blocks_player = true
	practice_break_block.blocks_enemy = false
	practice_break_block.break_once = true
	practice_break_block.broken.connect(_on_practice_block_broken)
	var part := TileRectPart.new()
	part.name = "Block"
	part.rect_name = "PracticeBlock"
	part.size = Vector2(32, 64)
	practice_break_block.add_child(part)
	add_child(practice_break_block)
	gate_body = practice_break_block

# プレイヤーが実際に噛む小さな練習対象を作る。
func _build_practice_target() -> void:
	var skull_instance := SkullMonsterScene.instantiate()
	skull_instance.set_script(TutorialSkullDropTargetScript)
	practice_target = skull_instance as TutorialSkullDropTarget
	practice_target.name = "PracticeSkullDropTarget"
	practice_target.position = PRACTICE_SKULL_START
	practice_target.starts_available = false
	practice_target.bitten.connect(_on_practice_target_bitten)
	practice_target.drop_finished.connect(_on_practice_skull_drop_finished)
	add_child(practice_target)

# 最後の奈落前で強制再演シーンを起動する判定を作る。
func _build_final_trigger() -> void:
	final_trigger = Area2D.new()
	final_trigger.name = "FinalShadowTrigger"
	final_trigger.position = Vector2(1068, 322)
	final_trigger.collision_layer = 0
	final_trigger.collision_mask = 2
	add_child(final_trigger)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(96, 156)
	collision.shape = shape
	final_trigger.add_child(collision)
	final_trigger.body_entered.connect(_on_final_trigger_body_entered)

# STAGE 1へ落とされる穴だと分かる看板を作る。
func _build_stage_one_sign() -> void:
	var label := Label.new()
	label.name = "StageOnePitLabel"
	label.text = "STAGE 1"
	label.position = Vector2(PIT_CENTER_X - 65.0, 308)
	label.size = Vector2(130, 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(label)

	var arrow := Label.new()
	arrow.name = "PitArrow"
	arrow.text = "↓"
	arrow.position = Vector2(PIT_CENTER_X - 21.0, 334)
	arrow.size = Vector2(42, 34)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 28)
	arrow.add_theme_color_override("font_color", Color(1.0, 0.24, 0.18))
	add_child(arrow)

# 影キャラの実演シーケンスを再生する。
func _start_shadow_demo() -> void:
	shadow_guide = ShadowGuideScript.new()
	shadow_guide.name = "ShadowGuide"
	shadow_guide.global_position = Vector2(126, SHADOW_GROUND_Y)
	add_child(shadow_guide)
	if practice_target != null:
		practice_target.prepare_scripted_memory_hint(true)
	_set_player_control_enabled(false)
	_set_stage_objective("目標：影を追え")

	shadow_guide.play_walk(1.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(shadow_guide, "global_position", Vector2(272, SHADOW_GROUND_Y), 0.92)
	tween.tween_callback(func(): _set_stage_objective("目標：段差を越える動きを見ろ"))
	tween.tween_property(shadow_guide, "global_position", Vector2(338, SHADOW_STEP_Y), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(shadow_guide, "global_position", Vector2(424, SHADOW_STEP_Y), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _set_stage_objective("目標：記憶タグを噛む瞬間を見ろ"))
	tween.tween_interval(0.28)
	tween.tween_callback(func():
		shadow_guide.bite_memory_tag(practice_target, func():
			if practice_target != null:
				practice_target.play_scripted_dash_to(PRACTICE_SKULL_MID, 0.42, true)
			play_sfx(&"bite_hit")
			play_sfx(&"memory_tag_crack")
			shake_camera(7.0, 0.14)
		)
	)
	tween.tween_interval(0.74)
	tween.tween_callback(func():
		shadow_guide.play_walk(1.0)
		_set_stage_objective("目標：記憶を運ぶ流れを見ろ")
	)
	tween.tween_property(shadow_guide, "global_position", PRACTICE_SKULL_MID + Vector2(-46, 0), 0.48)
	tween.tween_interval(0.16)
	tween.tween_callback(func():
		shadow_guide.bite_memory_tag(practice_target, func():
			if practice_target != null:
				practice_target.play_scripted_dash_to(PRACTICE_SKULL_READY, 0.48, true)
			play_sfx(&"bite_hit")
			play_sfx(&"memory_tag_crack")
			shake_camera(7.5, 0.14)
		)
	)
	tween.tween_interval(0.82)
	tween.tween_callback(func():
		shadow_guide.visible = false
		if practice_target != null:
			practice_target.set_available(true)
		_set_stage_objective("目標：KでSkullのDASHを噛め")
		_set_player_control_enabled(true)
	)

# 練習SkullのDASHを噛んだら右の穴へ落としてから道を安全にする。
func _on_practice_target_bitten() -> void:
	_set_stage_objective("目標：Skullが落ちるのを見ろ")
	practice_drop_pending = true

# Playerの牙が実際にタグへ届いたタイミングで練習Skull落下演出を始める。
func _on_player_bite_contact(target: Node) -> void:
	super._on_player_bite_contact(target)
	if target != practice_target or not practice_drop_pending:
		return
	practice_drop_pending = false
	call_deferred("_play_practice_skull_drop_cinematic")

# 練習用BLOCKがDASHで壊れた瞬間の手応えを出す。
func _on_practice_block_broken(_by_enemy: Node, _action_record: Resource) -> void:
	shake_camera(10.0, 0.16)

# 噛み成立後、短く停止してからSkullを穴へ落とす。
func _play_practice_skull_drop_cinematic() -> void:
	_set_player_control_enabled(false)
	final_camera_override_active = true
	final_camera_zoom = Vector2(1.72, 1.72)
	if practice_target != null:
		final_camera_position = practice_target.global_position + Vector2(70, -62)
		shake_camera(8.0, 0.14)
	var tween := create_tween()
	tween.tween_interval(0.28)
	tween.tween_callback(func():
		if practice_target != null:
			final_camera_override_active = false
			play_sfx(&"skull_dash")
			practice_target.play_drop_dash(PRACTICE_HOLE_CENTER_X, 650.0)
	)

# Skullが落ちた後に穴を塞ぎ、ブロックを消して先へ進ませる。
func _on_practice_skull_drop_finished() -> void:
	_set_stage_objective("目標：塞がった穴を越えて進め")
	shake_camera(10.0, 0.16)
	_build_practice_hole_cover()
	var tween := create_tween()
	tween.tween_interval(0.24)
	tween.tween_callback(func():
		final_camera_override_active = false
		_set_player_control_enabled(true)
	)

# Skull落下後だけ新規穴を床で塞ぐ。
func _build_practice_hole_cover() -> void:
	if practice_hole_cover != null:
		return
	practice_hole_cover = Node2D.new()
	practice_hole_cover.name = "PracticeHoleCover"
	practice_hole_cover.position = Vector2(PRACTICE_HOLE_LEFT_X, 360)
	practice_hole_cover.z_index = -5
	add_child(practice_hole_cover)
	var rects := [Rect2(Vector2.ZERO, Vector2(PRACTICE_HOLE_RIGHT_X - PRACTICE_HOLE_LEFT_X, 32))]
	TileGroupBuilderScript.build_static_collision(practice_hole_cover, rects)
	TileGroupBuilderScript.build_visuals(practice_hole_cover, rects, Color(0.62, 0.38, 0.68))

# 最後の演出開始判定。
func _on_final_trigger_body_entered(body: Node) -> void:
	if final_sequence_started or body != player:
		return
	final_sequence_started = true
	_set_stage_objective("目標：STAGE 1へ向かえ")
	_play_final_shadow_bite()

# 主人公にDASHタグを出し、影キャラが背後から噛んでStage1へ落とす。
func _play_final_shadow_bite() -> void:
	_set_player_control_enabled(false)
	player.velocity = Vector2.ZERO
	_set_stage_objective("目標：背後に注意")
	player_dash_record = ActionRecordScript.new(&"dash", Vector2.RIGHT, Vector2(330.0, 0.0), 0.46)
	player_dash_record.mark_as_memory(2000, &"NATURAL")
	player_dash_tag = _create_memory_tag("PlayerDashTag")
	player_dash_tag.global_position = player.global_position + player_dash_tag_offset
	add_child(player_dash_tag)
	player_dash_tag.show_record(player_dash_record)
	player_dash_tag.set_bite_hint_active(true)
	final_camera_override_active = true
	final_camera_position = player.global_position + Vector2(20, -58)
	final_camera_zoom = camera_base_zoom

	var question := _show_reaction_text("?", player.global_position + Vector2(0, -116), 34, Color(1.0, 0.95, 0.42))

	if shadow_guide == null:
		shadow_guide = ShadowGuideScript.new()
		shadow_guide.name = "ShadowGuide"
		add_child(shadow_guide)
	shadow_guide.visible = true
	shadow_guide.global_position = player.global_position + Vector2(-138, 0)
	shadow_guide.play_walk(1.0)
	shadow_guide.flash_eyes()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "final_camera_position", player.global_position + Vector2(18, -62), 0.20)
	tween.parallel().tween_property(self, "final_camera_zoom", Vector2(2.18, 2.18), 0.20)
	tween.tween_interval(0.26)
	tween.tween_property(shadow_guide, "global_position", player.global_position + Vector2(-58, -4), 0.36)
	tween.tween_interval(0.10)
	tween.tween_property(shadow_guide, "global_position", player.global_position + Vector2(-34, -4), 0.14)
	tween.tween_callback(func():
		if is_instance_valid(question):
			question.queue_free()
		_show_reaction_text("!?", player.global_position + Vector2(0, -120), 34, Color(1.0, 0.38, 0.18), 0.52)
		shadow_guide.play_bite(1.0)
		play_sfx(&"memory_tag_crack")
		shake_camera(18.0, 0.18)
	)
	tween.tween_interval(0.34)
	tween.tween_callback(func():
		player_dash_tag.begin_breaking(player_dash_record)
	)
	tween.tween_interval(0.18)
	tween.tween_callback(func():
		play_sfx(&"bite_hit")
		shadow_guide.visible = false
		player.set_replay_outline_active(true)
		player.play_animation(&"walk")
	)
	tween.tween_property(self, "final_camera_zoom", Vector2(1.92, 1.92), 0.10)
	tween.parallel().tween_property(player, "global_position", Vector2(PIT_CENTER_X, player.global_position.y), 0.56)
	tween.parallel().tween_property(self, "final_camera_position", Vector2(PIT_CENTER_X, player.global_position.y - 42), 0.56)
	tween.tween_callback(func():
		player.pause_animation()
		player.set_replay_outline_active(false)
		_show_reaction_text("!!!!!!!", player.global_position + Vector2(0, -122), 30, Color(1.0, 0.86, 0.24), 0.76)
		shake_camera(10.0, 0.12)
	)
	tween.tween_interval(0.72)
	tween.tween_callback(func():
		player.resume_animation()
		player.play_animation(&"walk")
	)
	tween.tween_property(player, "global_position", Vector2(PIT_CENTER_X, 700), 1.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.24)
	tween.tween_callback(func():
		StageScoreStoreScript.mark_stage_completed("Stage0")
		get_tree().change_scene_to_file(final_scene_path)
	)

# プレイヤー入力と物理をまとめて止める。
func _set_player_control_enabled(enabled: bool) -> void:
	if player == null:
		return
	player.set_process_unhandled_input(enabled)
	player.set_physics_process(enabled)
	if not enabled:
		player.velocity = Vector2.ZERO

# 右上の常駐目標表示を更新する。
func _set_stage_objective(text: String) -> void:
	if stage_hud != null and stage_hud.objective_label != null:
		stage_hud.objective_label.text = text

# 終盤演出用のリアクション文字をワールド上に表示する。
func _show_reaction_text(text: String, position: Vector2, font_size: int, color: Color, lifetime := 0.0) -> Label:
	var label := Label.new()
	label.name = "ReactionText"
	label.text = text
	label.global_position = position
	label.size = Vector2(180, 56)
	label.pivot_offset = label.size * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.z_index = 80
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	add_child(label)

	var tween := label.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	label.scale = Vector2(0.4, 0.4)
	tween.tween_property(label, "scale", Vector2.ONE, 0.10)
	if lifetime > 0.0:
		tween.tween_interval(lifetime)
		tween.tween_property(label, "modulate:a", 0.0, 0.12)
		tween.tween_callback(label.queue_free)
	return label

# MemoryTagが期待する子ノード込みでタグを生成する。
func _create_memory_tag(node_name: String) -> MemoryTag:
	var tag := MemoryTagScript.new()
	tag.name = node_name
	tag.z_index = 30

	var plaque := Sprite2D.new()
	plaque.name = "Plaque"
	plaque.scale = Vector2(0.05, 0.05)
	tag.add_child(plaque)

	var label := Label.new()
	label.name = "Label"
	label.offset_left = -43.0
	label.offset_top = -13.0
	label.offset_right = 43.0
	label.offset_bottom = 15.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	tag.add_child(label)

	var crack := Label.new()
	crack.name = "Crack"
	crack.text = "◆"
	crack.offset_left = -20.0
	crack.offset_top = 2.0
	crack.offset_right = 20.0
	crack.offset_bottom = 34.0
	crack.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crack.add_theme_font_size_override("font_size", 28)
	crack.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	crack.add_theme_color_override("font_shadow_color", Color.BLACK)
	tag.add_child(crack)

	return tag

# ゲート破壊の簡易破片を出す。
func _spawn_gate_shards(origin: Vector2) -> void:
	for i in 18:
		var shard := ColorRect.new()
		shard.color = [Color(0.7, 0.42, 0.17), Color(1.0, 0.72, 0.32), Color(0.39, 0.22, 0.12)][i % 3]
		shard.size = Vector2(randf_range(5, 12), randf_range(5, 14))
		shard.global_position = origin + Vector2(randf_range(-20, 20), randf_range(-28, 28))
		add_child(shard)
		var angle := randf_range(-PI, PI)
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", shard.global_position + Vector2(cos(angle), sin(angle)) * randf_range(42, 90), 0.34)
		tween.tween_property(shard, "modulate:a", 0.0, 0.34)
		tween.set_parallel(false)
		tween.tween_callback(shard.queue_free)
