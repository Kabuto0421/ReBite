# 2026-06-13: 全ステージで共有する基盤処理。
extends Node2D

const PredictionArrowScript := preload("res://scripts/stage/PredictionArrow.gd")
const StateMachineScript := preload("res://scripts/core/StateMachine.gd")
const StageNormalState := preload("res://scripts/states/stage/StageNormalState.gd")
const StageSpikeImpactState := preload("res://scripts/states/stage/StageSpikeImpactState.gd")
const StageClearState := preload("res://scripts/states/stage/StageClearState.gd")
const StageScoreStoreScript := preload("res://scripts/stage/StageScoreStore.gd")
const StageHudScript := preload("res://scripts/stage/StageHud.gd")
const StageCameraRigScript := preload("res://scripts/stage/StageCameraRig.gd")
const SpikeImpactPresenterScript := preload("res://scripts/stage/SpikeImpactPresenter.gd")
const StageEnemyTrackerScript := preload("res://scripts/stage/StageEnemyTracker.gd")
const StageGoalControllerScript := preload("res://scripts/stage/StageGoalController.gd")
const TileGroupBuilderScript := preload("res://scripts/stage/TileGroupBuilder.gd")
const EditableSpikesScript := preload("res://scripts/stage/EditableSpikes.gd")
const StageSfxScript := preload("res://scripts/stage/StageSfx.gd")
const StageBgmScript := preload("res://scripts/stage/StageBgm.gd")
const MobileControlsScript := preload("res://scripts/ui/MobileControls.gd")
const SpriteFrameBuilder := preload("res://scripts/core/SpriteFrameBuilder.gd")

@export var next_stage_path := "" # クリア後に遷移する次ステージ。
@export var mobile_controls_force_visible := false # PC上でもスマホ操作UIを強制表示するか。
@export var mobile_replay_button_visible := false # スマホ操作UIにリプレイボタンを出すか。

@export_group("Score")
@export var score_base := 1000 # クリア時に必ず入る基礎点。
@export var score_time_bonus_max := 3000 # 早解きボーナスの最大値。
@export var score_time_bonus_decay_per_second := 25 # 1秒ごとに減る早解きボーナス。
@export var score_no_death_bonus := 1500 # ノーデス時の最大ボーナス。
@export var score_death_penalty := 500 # 死亡1回ごとに減るボーナス。
@export var score_star_thresholds := PackedInt32Array([1800, 3000, 4500]) # 1/2/3星に必要なスコア。

@export_group("Stage Briefing")
@export var stage_display_name := "" # HUDに表示するステージ名。空ならルートノード名を使う。
@export_range(0.1, 3.0, 0.05) var stage_briefing_hold_time := 1.2 # 開始命令を中央で保持する時間。
@export_range(0.1, 1.0, 0.05) var stage_briefing_transition_time := 1.2 # 開始命令から常駐HUDへ切り替える時間。

@export_group("Goal")
@export var goal_area_path := NodePath("GoalArea") # ゴール型ステージで探すGoalAreaのパス。

@export_group("Camera")
@export var normal_camera_offset := Vector2(0.0, -60.0) # 通常時のプレイヤー基準カメラ位置。

@export_group("Spike Impact")
@export_range(0.0, 1.0, 0.01) var spike_impact_hold_time := 0.25 # 針ヒット時に世界を止める時間。
@export_range(1.0, 1.5, 0.01) var spike_impact_zoom_multiplier := 1.10 # 最後の敵撃破時のズーム倍率。
@export_range(0.0, 48.0, 1.0) var spike_impact_shake_strength := 30.0 # 針ヒット直後の揺れの強さ。
@export_range(0.0, 24.0, 1.0) var spike_impact_aftershock_strength := 6.0 # 死亡開始時の余韻揺れ。

@export_group("Audio")
@export var sfx_enabled := true # 効果音を再生するかどうか。
@export var bgm_enabled := true # BGMを再生するかどうか。
@export_file("*.wav", "*.ogg") var bgm_path := "res://assets/bgm/memory_bite_loop_02.wav" # 通常ステージで再生するBGM。
@export var bgm_autoplay := true # Stage初期化時に既定BGMを再生するか。
@export var bgm_volume_db := -23.0 # BGMの音量。
@export_range(0.0, 18.0, 0.5) var bgm_duck_db := 6.0 # 重要SE再生時にBGMを下げる量。
@export_range(0.0, 1.0, 0.01) var bgm_duck_hold_time := 0.16 # BGMを下げたまま保持する時間。
@export_range(0.0, 1.0, 0.01) var bgm_duck_recover_time := 0.18 # BGMが元の音量へ戻る時間。

var player: Node # ステージ内のプレイヤー参照。
var skull: Node # 互換用の最初の敵参照。
var enemies: Array[Node] = [] # ステージ内の記憶敵一覧。
var defeated_enemies := 0 # 撃破済みの敵数。
var stage_cleared := false # ステージクリア済みかどうか。
var hud_label: Label # 操作説明を表示するラベル。
var clear_label: Label # クリアや撃破数を表示するラベル。
var replay_label: Label # リプレイ案内を表示するラベル。
var camera: Camera2D # 実際に画面を映すカメラ。
var goal_area: Area2D # ゴール型ステージで使うゴール領域。
var tile_texture: Texture2D # 自動生成足場に使うタイル画像。
var memory_overlay: ColorRect # 記憶受付中に画面を暗くする幕。
var prediction_arrow: Node2D # 記憶行動の予測矢印。
var low_tone_player: AudioStreamPlayer # 噛み成功時の低音再生用。
var stage_state_machine: Node # ステージ全体の状態遷移。
var stage_hud: Node # HUD表示を担当する部品。
var camera_rig: Node # カメラ生成とカメラ演出を担当する部品。
var spike_impact_presenter: Node # 針ヒット時の破片演出を担当する部品。
var enemy_tracker: Node # 敵一覧と撃破数を担当する部品。
var goal_controller: Node # ゴール到達判定を担当する部品。
var stage_sfx: Node # ステージ共通SEを担当する部品。
var stage_bgm: Node # ステージ共通BGMを担当する部品。
var mobile_controls: Node # スマホ向け操作UI。
var camera_base_zoom := Vector2(1.35, 1.35) # 通常時のカメラズーム。
var camera_cinematic := false # 通常追従ではないカメラ演出中かどうか。
var spike_impact_freeze_active := false # 針ヒットで世界停止中かどうか。
var locked_bite_target: Node # 噛み演出中に表示を固定する対象。
var stage_elapsed_seconds := 0.0 # 現在ステージの経過時間。
var stage_death_count := 0 # 現在ステージでプレイヤーが死亡した回数。
var stage_result_layer: CanvasLayer # クリア後のスコアと選択UI。
var stage_result_selected_index := 1 # 0=REPLAY、1=NEXT。
var stage_result_choices: Array[Dictionary] = [] # リザルト選択肢のノード参照。
var stage_result_player: AnimatedSprite2D # リザルト選択用のプレイヤー表示。
var stage_result_moving := false # リザルトの噛み演出中かどうか。

# ステージ共通部品を順番に初期化する。
func _ready() -> void:
	tile_texture = _load_texture("res://assets/tiles/dungeon_tileset.png")
	_build_world()
	_build_hud()
	_build_camera()
	_build_memory_focus()
	_build_audio()
	_build_stage_sfx()
	_build_stage_bgm()
	_build_mobile_controls()
	_setup_entities()
	_build_goal_controller()
	_start_stage_briefing()
	_build_spike_impact_presenter()
	_build_stage_state_machine()

# 終了時にpauseが残らないよう戻す。
func _exit_tree() -> void:
	if spike_impact_freeze_active and get_tree() != null:
		get_tree().paused = false

# 毎フレームの表示更新とステージ状態更新を行う。
func _process(delta: float) -> void:
	if not stage_cleared:
		stage_elapsed_seconds += delta
	_update_memory_focus()
	# 画面下部の大きなリプレイ案内は一時的に非表示にする。
	# _update_replay_prompt()
	_update_goal()
	if stage_state_machine != null:
		stage_state_machine.process_update(delta)

# 物理側のステージ状態更新を行う。
func _physics_process(delta: float) -> void:
	if stage_state_machine != null:
		stage_state_machine.physics_update(delta)

# リプレイ入力を受け付ける。
func _unhandled_input(event: InputEvent) -> void:
	if stage_cleared and stage_state_machine != null:
		stage_state_machine.handle_input(event)
		return
	if event.is_action_pressed("replay"):
		get_tree().reload_current_scene()

# 各ステージが地形を作るための差し替え口。
func _build_world() -> void:
	pass

# プレイヤーと敵を検出してイベント接続する。
func _setup_entities() -> void:
	player = $Player
	player.bite_hit.connect(_on_player_bite_hit)
	player.bite_contact.connect(_on_player_bite_contact)
	player.bite_missed.connect(_on_player_bite_missed)
	if player.has_signal("death_started") and not player.death_started.is_connected(_on_player_death_started):
		player.death_started.connect(_on_player_death_started)

	enemy_tracker = StageEnemyTrackerScript.new()
	enemy_tracker.name = "StageEnemyTracker"
	add_child(enemy_tracker)
	enemy_tracker.setup(self)
	enemy_tracker.enemy_defeated.connect(_on_enemy_defeated)
	enemy_tracker.all_enemies_defeated.connect(_on_all_enemies_defeated)
	enemies = enemy_tracker.enemies
	defeated_enemies = enemy_tracker.defeated_enemies
	stage_cleared = false
	stage_elapsed_seconds = 0.0
	stage_death_count = 0
	locked_bite_target = null
	skull = enemy_tracker.first_enemy()

# カメラ部品を作成して公開参照を保持する。
func _build_camera() -> void:
	camera_rig = StageCameraRigScript.new()
	camera_rig.name = "StageCameraRig"
	add_child(camera_rig)
	camera_rig.setup(self, camera_base_zoom)
	camera = camera_rig.camera

# HUD部品を作成して公開ラベル参照を保持する。
func _build_hud() -> void:
	stage_hud = StageHudScript.new()
	stage_hud.name = "StageHud"
	add_child(stage_hud)
	stage_hud.setup(self)
	hud_label = stage_hud.hud_label
	clear_label = stage_hud.clear_label
	replay_label = stage_hud.replay_label

# クリア条件と敵数から開始命令と常駐目標を構成する。
func _start_stage_briefing() -> void:
	var display_name := _resolved_stage_display_name()
	if goal_area != null:
		stage_hud.play_briefing(
			display_name,
			"ゴールしろ！",
			"目標：ゴールに到達する",
			stage_briefing_hold_time,
			stage_briefing_transition_time
		)
		return

	var total := enemies.size()
	var defeat_text := "目標：敵を倒す" if total <= 1 else "目標：敵を全員倒す"
	var command_text := "敵を倒せ！" if total <= 1 else "敵を全員倒せ！"
	stage_hud.set_defeat_objective(defeat_text, defeated_enemies, total)
	stage_hud.play_briefing(
		display_name,
		command_text,
		"%s (%d/%d)" % [defeat_text, defeated_enemies, total],
		stage_briefing_hold_time,
		stage_briefing_transition_time
	)

# Inspector未設定時のルート名を読みやすいステージ表記へ変換する。
func _resolved_stage_display_name() -> String:
	if not stage_display_name.is_empty():
		return stage_display_name
	var node_name := str(name)
	if node_name.begins_with("Stage"):
		return "STAGE %s" % node_name.trim_prefix("Stage")
	return node_name

# 記憶ウィンドウ表示と予測矢印を作成する。
func _build_memory_focus() -> void:
	memory_overlay = ColorRect.new()
	memory_overlay.name = "MemoryWindowOverlay"
	memory_overlay.color = Color(0.0, 0.0, 0.0, 0.32)
	memory_overlay.size = Vector2(3600, 1400)
	memory_overlay.position = Vector2(-1200, -520)
	memory_overlay.z_index = 8
	memory_overlay.visible = false
	add_child(memory_overlay)

	prediction_arrow = PredictionArrowScript.new()
	prediction_arrow.name = "PredictionArrow"
	prediction_arrow.z_index = 12
	prediction_arrow.visible = false
	add_child(prediction_arrow)

# 噛み成功時の音を鳴らすプレイヤーを作成する。
func _build_audio() -> void:
	low_tone_player = AudioStreamPlayer.new()
	low_tone_player.name = "BiteLowTone"
	add_child(low_tone_player)

# ステージ共通SE部品を作成する。
func _build_stage_sfx() -> void:
	stage_sfx = StageSfxScript.new()
	stage_sfx.name = "StageSfx"
	stage_sfx.enabled = sfx_enabled
	add_child(stage_sfx)
	stage_sfx.setup()

# ステージ共通BGM部品を作成する。
func _build_stage_bgm() -> void:
	stage_bgm = StageBgmScript.new()
	stage_bgm.name = "StageBgm"
	stage_bgm.enabled = bgm_enabled
	stage_bgm.bgm_path = bgm_path
	stage_bgm.volume_db = bgm_volume_db
	stage_bgm.duck_db = bgm_duck_db
	stage_bgm.duck_hold_time = bgm_duck_hold_time
	stage_bgm.duck_recover_time = bgm_duck_recover_time
	add_child(stage_bgm)
	stage_bgm.setup(bgm_autoplay)
	if stage_sfx != null and not stage_sfx.important_sound_played.is_connected(_on_important_sfx_played):
		stage_sfx.important_sound_played.connect(_on_important_sfx_played)

# スマホ向け操作UIを作成する。
func _build_mobile_controls() -> void:
	mobile_controls = MobileControlsScript.new()
	mobile_controls.name = "MobileControls"
	mobile_controls.force_visible = mobile_controls_force_visible
	mobile_controls.show_replay_button = mobile_replay_button_visible
	add_child(mobile_controls)

# ゴール判定部品を作成する。
func _build_goal_controller() -> void:
	goal_controller = StageGoalControllerScript.new()
	goal_controller.name = "StageGoalController"
	add_child(goal_controller)
	goal_area = goal_controller.setup(self, goal_area_path, player)
	if not goal_controller.goal_reached.is_connected(_on_goal_reached):
		goal_controller.goal_reached.connect(_on_goal_reached)

# 針ヒット演出部品を作成する。
func _build_spike_impact_presenter() -> void:
	spike_impact_presenter = SpikeImpactPresenterScript.new()
	spike_impact_presenter.name = "SpikeImpactPresenter"
	add_child(spike_impact_presenter)
	spike_impact_presenter.setup(self)

# ステージ全体の状態機械を作成する。
func _build_stage_state_machine() -> void:
	stage_state_machine = StateMachineScript.new()
	stage_state_machine.name = "StageStateMachine"
	stage_state_machine.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(stage_state_machine)

	var normal := StageNormalState.new()
	normal.name = "Normal"
	stage_state_machine.add_child(normal)

	var spike_impact := StageSpikeImpactState.new()
	spike_impact.name = "SpikeImpact"
	stage_state_machine.add_child(spike_impact)

	var clear := StageClearState.new()
	clear.name = "Clear"
	stage_state_machine.add_child(clear)

	stage_state_machine.initialize(self, &"Normal")

# 指定範囲にタイル付きの床や壁を作る。
func _add_platform(rect: Rect2) -> void:
	var body := Node2D.new()
	body.name = "Platform"
	body.position = rect.position
	body.z_index = -5
	add_child(body)
	TileGroupBuilderScript.build_static_collision(body, [Rect2(Vector2.ZERO, rect.size)])
	TileGroupBuilderScript.build_visuals(body, [Rect2(Vector2.ZERO, rect.size)])

# 指定範囲に針トラップを作る。
func _add_spikes(rect: Rect2) -> void:
	var spikes := EditableSpikesScript.new()
	spikes.name = "Spikes"
	spikes.position = rect.position
	spikes.z_index = -3
	spikes.size = rect.size
	add_child(spikes)

# タイルセットから指定範囲のテクスチャを切り出す。
func _atlas(position: Vector2i, size: Vector2i) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = tile_texture
	atlas.region = Rect2(position, size)
	return atlas

# ファイルパスから画像テクスチャを読み込む。
func _load_texture(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Failed to load image: %s" % path)
		return null
	return ImageTexture.create_from_image(image)

# 針に入ったbodyを共通処理へ渡す。
func _on_spike_body_entered(body: Node) -> void:
	handle_spike_body_entered(body, body.global_position)

# 針接触時の死亡またはリセット処理を選ぶ。
func handle_spike_body_entered(body: Node, impact_position: Vector2) -> void:
	if _should_play_enemy_spike_impact(body):
		play_sfx(&"spike_hit")
		if not should_use_defeat_camera_for_enemy(body):
			spawn_spike_impact_burst(impact_position)
			body.die()
			return
		play_spike_impact(body, impact_position)
		return
	if body != null and body.has_method("die"):
		play_sfx(&"spike_hit")
		body.die()
	elif body != null and body.has_method("reset_to_spawn"):
		body.reset_to_spawn()

# 敵用の針ヒット演出を使うべきか判定する。
func _should_play_enemy_spike_impact(body: Node) -> bool:
	if body == null or not body.has_method("receive_bite") or not body.has_signal("died"):
		return false
	if body.has_method("current_state_name") and body.current_state_name() == &"Dying":
		return false
	return true

# 針ヒット状態へ遷移させる。
func play_spike_impact(body: Node, impact_position: Vector2) -> void:
	if not _should_play_enemy_spike_impact(body):
		return
	stage_state_machine.change_state(&"SpikeImpact", {
		"body": body,
		"impact_position": impact_position,
		"use_camera_impact": should_use_defeat_camera_for_enemy(body),
	})

# 最後の敵撃破カメラを使うか判定する。
func should_use_defeat_camera_for_enemy(body: Node) -> bool:
	if body != null and body.has_method("will_die_from_next_hit") and not body.will_die_from_next_hit():
		return false
	return remaining_active_enemy_count(body) <= 1

# 現在生きている敵数を返す。
func remaining_active_enemy_count(_defeated_body: Node = null) -> int:
	return enemy_tracker.remaining_active_enemy_count() if enemy_tracker != null else 0

# 針ヒットの停止姿勢を敵に反映する。
func pose_spike_impact_body(body: Node, impact_position: Vector2) -> void:
	if body.has_method("pause_animation"):
		body.pause_animation()
	body.velocity = Vector2.ZERO
	var direction: Vector2 = body.global_position - impact_position
	if direction.length_squared() < 1.0:
		direction = Vector2.DOWN
	direction = direction.normalized()
	body.global_position += direction * 4.0
	if body.has_method("pose_spike_impact_hold"):
		body.pose_spike_impact_hold(direction)
		return
	if body.has_method("pause_animation"):
		body.pause_animation()

# 針ヒットによる世界停止を解除する。
func end_spike_impact_freeze() -> void:
	if not spike_impact_freeze_active:
		return
	spike_impact_freeze_active = false
	get_tree().paused = false

# プレイヤーの噛み成功イベントを受け取る。
func _on_player_bite_hit(target: Node) -> void:
	locked_bite_target = target
	play_sfx(&"bite_hit")
	_play_bite_camera(target)
	_play_bite_low_tone()

# 牙がタグへ届いた瞬間に破砕音を鳴らし、旧仕様のザシュからぱりんの順序を保つ。
func _on_player_bite_contact(_target: Node) -> void:
	play_sfx(&"memory_tag_crack")

# プレイヤーの噛み失敗イベントを受け取る。
func _on_player_bite_missed() -> void:
	locked_bite_target = null
	_shake_camera(2.0, 0.08)

# 途中撃破時のHUD更新と軽い揺れを行う。
func _on_enemy_defeated(defeated: int, total: int) -> void:
	if stage_cleared:
		return
	defeated_enemies = defeated
	if goal_area == null:
		stage_hud.set_defeat_progress(defeated, total)
	_shake_camera(10.0, 0.14)

# 全敵撃破時にステージクリアへ進める。
func _on_all_enemies_defeated() -> void:
	if stage_cleared:
		return
	defeated_enemies = enemy_tracker.defeated_enemies if enemy_tracker != null else defeated_enemies + 1
	if goal_area != null:
		return
	stage_hud.set_defeat_progress(defeated_enemies, enemies.size())
	stage_hud.mark_objective_complete()
	complete_stage()

# ステージクリア表示と次ステージ遷移を行う。
func complete_stage(message: String = "STAGE CLEAR") -> void:
	if stage_cleared:
		return
	stage_cleared = true
	stage_hud.set_clear_text("")
	_shake_camera(16.0, 0.22)
	stage_state_machine.change_state(&"Clear", {
		"message": message,
	})

# プレイヤー死亡数をスコア用に記録する。
func _on_player_death_started() -> void:
	if stage_cleared:
		return
	stage_death_count += 1

# クリア時のスコア内訳を作る。
func build_stage_score_result() -> Dictionary:
	var time_bonus := maxi(0, int(round(float(score_time_bonus_max) - stage_elapsed_seconds * float(score_time_bonus_decay_per_second))))
	var death_bonus := maxi(0, score_no_death_bonus - stage_death_count * score_death_penalty)
	var score := score_base + time_bonus + death_bonus
	var stars := _stars_for_score(score)
	return {
		"stage_id": _score_stage_id(),
		"stage_name": _resolved_stage_display_name(),
		"score": score,
		"stars": stars,
		"elapsed": stage_elapsed_seconds,
		"deaths": stage_death_count,
		"base": score_base,
		"time_bonus": time_bonus,
		"death_bonus": death_bonus,
	}

# スコアから星数を計算する。
func _stars_for_score(score: int) -> int:
	var stars := 0
	for threshold in score_star_thresholds:
		if score >= int(threshold):
			stars += 1
	return stars

# スコア保存に使うステージIDを返す。
func _score_stage_id() -> String:
	var scene_path := scene_file_path
	if scene_path.is_empty() and get_tree().current_scene != null:
		scene_path = get_tree().current_scene.scene_file_path
	if scene_path.is_empty():
		return str(name)
	return scene_path.get_file().get_basename()

# クリア後のスコア画面を表示する。
func show_stage_result(payload: Dictionary) -> void:
	if stage_result_layer != null:
		return
	var message := str(payload.get("message", "STAGE CLEAR"))
	var result := build_stage_score_result()
	var best := StageScoreStoreScript.record_result(str(result.get("stage_id", _score_stage_id())), result)
	var ranking := StageScoreStoreScript.ranking_payload()
	stage_result_selected_index = 1 if not next_stage_path.is_empty() else 0
	stage_result_choices.clear()
	stage_result_moving = false

	stage_result_layer = CanvasLayer.new()
	stage_result_layer.name = "StageResultLayer"
	stage_result_layer.layer = 80
	add_child(stage_result_layer)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.66)
	dim.size = Vector2(1280, 720)
	stage_result_layer.add_child(dim)

	var panel := Control.new()
	panel.name = "Panel"
	panel.position = Vector2(310, 92)
	panel.size = Vector2(660, 470)
	stage_result_layer.add_child(panel)

	var title := _create_result_label(message, 56, Color("#fff2a8"), Vector2(0, 0), Vector2(660, 70))
	panel.add_child(title)

	var stage_name := _create_result_label(str(result.get("stage_name", _resolved_stage_display_name())), 22, Color("#b7dcff"), Vector2(0, 74), Vector2(660, 30))
	panel.add_child(stage_name)

	var star_label := _create_result_label(_star_text(int(result.get("stars", 0))), 46, Color("#ffd45b"), Vector2(0, 110), Vector2(660, 58))
	panel.add_child(star_label)

	var score_label := _create_result_label("SCORE  %d" % int(result.get("score", 0)), 42, Color.WHITE, Vector2(0, 180), Vector2(660, 54))
	panel.add_child(score_label)

	var detail := _create_result_label(
		"TIME %.2fs  +%d    DEATH %d  +%d    BEST %d" % [
			float(result.get("elapsed", 0.0)),
			int(result.get("time_bonus", 0)),
			int(result.get("deaths", 0)),
			int(result.get("death_bonus", 0)),
			int(best.get("score", result.get("score", 0))),
		],
		21,
		Color("#d5d9e2"),
		Vector2(0, 244),
		Vector2(660, 32)
	)
	panel.add_child(detail)

	var total := _create_result_label(
		"TOTAL SCORE  %d   CLEAR %d/%d" % [
			int(ranking.get("total_score", 0)),
			int(ranking.get("completed_stage_count", 0)),
			int(ranking.get("stage_count", 0)),
		],
		23,
		Color("#fff0a8"),
		Vector2(0, 282),
		Vector2(660, 32)
	)
	panel.add_child(total)

	_create_result_choice(panel, "REPLAY", 0, Vector2(92, 330))
	if not next_stage_path.is_empty():
		_create_result_choice(panel, "NEXT", 1, Vector2(382, 330))

	stage_result_player = AnimatedSprite2D.new()
	stage_result_player.name = "ResultPlayer"
	var frames := SpriteFrameBuilder.from_folder("res://assets/player/walk", &"walk", 8.0, true)
	SpriteFrameBuilder.add_animation(frames, "res://assets/player/bite", &"bite", 12.0, false)
	stage_result_player.sprite_frames = frames
	stage_result_player.scale = Vector2(1.75, 1.75)
	stage_result_player.play(&"walk")
	panel.add_child(stage_result_player)
	_update_stage_result_selection(false)

# クリア後のスコア画面を消す。
func hide_stage_result() -> void:
	if stage_result_layer != null:
		stage_result_layer.queue_free()
	stage_result_layer = null
	stage_result_choices.clear()
	stage_result_player = null
	stage_result_moving = false

# リザルト選択の入力を処理する。
func handle_stage_result_input(event: InputEvent) -> void:
	if stage_result_layer == null or stage_result_moving:
		return
	if event.is_action_pressed("replay"):
		get_tree().reload_current_scene()
		return
	if event.is_action_pressed("move_left"):
		_select_stage_result_choice(-1)
	elif event.is_action_pressed("move_right"):
		_select_stage_result_choice(1)
	elif event.is_action_pressed("bite"):
		_bite_stage_result_choice()

# リザルトのテキストラベルを作る。
func _create_result_label(text: String, font_size: int, color: Color, position: Vector2, size: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	return label

# 星数を文字表示へ変換する。
func _star_text(stars: int) -> String:
	var text := ""
	for i in 3:
		text += "★" if i < stars else "☆"
	return text

# REPLAY/NEXTの噛み選択箱を作る。
func _create_result_choice(parent: Node, text: String, index: int, position: Vector2) -> void:
	var root := Node2D.new()
	root.name = "Choice%s" % text
	root.position = position
	parent.add_child(root)

	var shadow := ColorRect.new()
	shadow.color = Color(0.0, 0.0, 0.0, 0.38)
	shadow.position = Vector2(8, 10)
	shadow.size = Vector2(186, 76)
	root.add_child(shadow)

	var face := ColorRect.new()
	face.name = "Face"
	face.color = Color("#f3f0d6")
	face.size = Vector2(186, 76)
	root.add_child(face)

	var label := _create_result_label(text, 28, Color("#1b1730"), Vector2.ZERO, Vector2(186, 76))
	root.add_child(label)

	stage_result_choices.append({
		"index": index,
		"node": root,
		"face": face,
	})

# リザルト選択を左右へ移動する。
func _select_stage_result_choice(delta: int) -> void:
	if stage_result_choices.is_empty():
		return
	var current := _stage_result_choice_array_index(stage_result_selected_index)
	current = posmod(current + delta, stage_result_choices.size())
	stage_result_selected_index = int(stage_result_choices[current].index)
	_update_stage_result_selection(true)

# 現在の選択IDが配列上のどこか返す。
func _stage_result_choice_array_index(choice_index: int) -> int:
	for i in stage_result_choices.size():
		if int(stage_result_choices[i].index) == choice_index:
			return i
	return 0

# リザルト選択状態の見た目を更新する。
func _update_stage_result_selection(animated := true) -> void:
	for choice in stage_result_choices:
		var selected := int(choice.get("index", -1)) == stage_result_selected_index
		var face := choice.get("face") as ColorRect
		var node := choice.get("node") as Node2D
		face.color = Color("#fff0a8") if selected else Color("#f3f0d6")
		node.scale = Vector2(1.06, 1.06) if selected else Vector2.ONE

	if stage_result_player == null:
		return
	var target := _stage_result_player_position()
	if animated:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(stage_result_player, "position", target, 0.12)
	else:
		stage_result_player.position = target
	stage_result_player.play(&"walk")

# 選択箱の手前に立つプレイヤー位置を返す。
func _stage_result_player_position() -> Vector2:
	for choice in stage_result_choices:
		if int(choice.get("index", -1)) == stage_result_selected_index:
			var node := choice.get("node") as Node2D
			return node.position + Vector2(93, 120)
	return Vector2(330, 450)

# 選択中の箱へ噛みつき、対応する遷移を実行する。
func _bite_stage_result_choice() -> void:
	stage_result_moving = true
	var selected_choice: Dictionary
	for choice in stage_result_choices:
		if int(choice.get("index", -1)) == stage_result_selected_index:
			selected_choice = choice
			break
	var choice_node := selected_choice.get("node") as Node2D
	var start_position := stage_result_player.position
	var bite_position := choice_node.position + Vector2(93, 78)
	stage_result_player.play(&"bite")
	play_sfx(&"bite_hit")
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(stage_result_player, "position", bite_position, 0.10)
	tween.tween_callback(func(): _break_stage_result_choice(choice_node))
	tween.tween_interval(0.18)
	tween.tween_callback(_activate_stage_result_choice)

# 選択箱を簡易破砕する。
func _break_stage_result_choice(choice_node: Node2D) -> void:
	if choice_node == null:
		return
	choice_node.visible = false
	for i in 18:
		var shard := ColorRect.new()
		shard.color = [Color("#fff0a8"), Color("#f3f0d6"), Color("#726b8e")][i % 3]
		shard.size = Vector2(randf_range(7.0, 16.0), randf_range(5.0, 14.0))
		shard.global_position = choice_node.global_position + Vector2(randf_range(10.0, 176.0), randf_range(8.0, 66.0))
		stage_result_layer.add_child(shard)
		var angle := randf_range(-PI * 0.95, -PI * 0.05)
		var distance := randf_range(50.0, 118.0)
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", shard.global_position + Vector2(cos(angle), sin(angle)) * distance, 0.36)
		tween.tween_property(shard, "rotation", randf_range(-2.4, 2.4), 0.36)
		tween.tween_property(shard, "modulate:a", 0.0, 0.36)
		tween.set_parallel(false)
		tween.tween_callback(shard.queue_free)

# リザルト選択の行き先へ遷移する。
func _activate_stage_result_choice() -> void:
	if stage_result_selected_index == 0 or next_stage_path.is_empty():
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(next_stage_path)

# 噛み成功時のカメラ演出を再生する。
func _play_bite_camera(target: Node) -> void:
	camera_cinematic = true
	_shake_camera(10.0, 0.18)
	camera_rig.play_bite_focus(self, target, func():
		camera_cinematic = false
		locked_bite_target = null
	)

# 針ヒットの破片演出を再生する。
func spawn_spike_impact_burst(impact_position: Vector2) -> void:
	spike_impact_presenter.spawn_burst(impact_position)

# 記憶ウィンドウと予測矢印を更新する。
func _update_memory_focus() -> void:
	if memory_overlay == null:
		return
	var target := _current_prediction_target()
	var active: bool = target != null and (not target.has_method("is_biteable") or target.is_biteable())
	memory_overlay.visible = active or camera_cinematic
	_update_memory_tag_hints(target if active else null)
	if active and target.last_record != null:
		var start: Vector2 = target.global_position
		var end: Vector2 = start + target.last_record.velocity * target.last_record.duration
		prediction_arrow.show_path(start + Vector2(0, -26), end + Vector2(0, -26))
	else:
		prediction_arrow.hide_path()

# リプレイ案内表示を更新する。
func _update_replay_prompt() -> void:
	stage_hud.update_replay_prompt(player, enemies)

# ゴール型ステージならゴール重なりを確認する。
func _update_goal() -> void:
	if goal_controller != null:
		goal_controller.process_update(stage_cleared)

# ゴール到達をステージクリアへ変換する。
func _on_goal_reached() -> void:
	stage_hud.mark_objective_complete()
	complete_stage("STAGE CLEAR")

# 現在噛める敵を返す。
func _current_biteable_enemy() -> Node:
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_biteable") and enemy.is_biteable():
			return enemy
	return null

# 予測矢印の表示対象を返す。
func _current_prediction_target() -> Node:
	if is_instance_valid(locked_bite_target):
		return locked_bite_target
	if player != null and player.has_method("pick_bite_target"):
		return player.pick_bite_target()
	return null

# 予測矢印の対象と同じ敵だけタグの噛み案内を強調する。
func _update_memory_tag_hints(active_target: Node) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("set_memory_bite_hint_active"):
			enemy.set_memory_bite_hint_active(enemy == active_target)

# 噛み成功時の低音を生成して鳴らす。
func _play_bite_low_tone() -> void:
	if not sfx_enabled:
		return
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.25
	low_tone_player.stream = stream
	low_tone_player.play()
	var playback := low_tone_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames := int(stream.mix_rate * 0.22)
	for i in frames:
		var t: float = float(i) / stream.mix_rate
		var envelope: float = max(0.0, 1.0 - t / 0.22)
		var sample: float = sin(TAU * 74.0 * t) * 0.18 * envelope
		playback.push_frame(Vector2(sample, sample))

# 互換用にカメラ揺れを呼び出す。
func _shake_camera(strength: float, duration: float) -> void:
	shake_camera(strength, duration)

# カメラ部品へ揺れを依頼する。
func shake_camera(strength: float, duration: float) -> void:
	camera_rig.shake(self, strength, duration, spike_impact_freeze_active)

# ヒットストップ中も進むカメラ揺れを開始する。
func shake_camera_while_paused(strength: float, duration: float) -> void:
	camera_rig.shake(self, strength, duration, true)

# pause中でも進むTweenを作成する。
func create_spike_impact_tween() -> Tween:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween

# ステージ内イベント用のSEを鳴らす。
func play_sfx(sound_name: StringName) -> void:
	if not sfx_enabled:
		return
	if stage_sfx != null and stage_sfx.has_method("play"):
		stage_sfx.play(sound_name)

# 重要SE再生中はBGMを短く下げる。
func _on_important_sfx_played(_sound_name: StringName) -> void:
	if stage_bgm != null and stage_bgm.has_method("duck"):
		stage_bgm.duck()
