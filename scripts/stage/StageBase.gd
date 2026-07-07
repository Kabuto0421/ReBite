# 2026-06-13: 全ステージで共有する基盤処理。
extends Node2D

const PredictionArrowScript := preload("res://scripts/stage/PredictionArrow.gd")
const StateMachineScript := preload("res://scripts/core/StateMachine.gd")
const StageNormalState := preload("res://scripts/states/stage/StageNormalState.gd")
const StageSpikeImpactState := preload("res://scripts/states/stage/StageSpikeImpactState.gd")
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

@export var next_stage_path := "" # クリア後に遷移する次ステージ。
@export var mobile_controls_force_visible := false # PC上でもスマホ操作UIを強制表示するか。
@export var mobile_replay_button_visible := false # スマホ操作UIにリプレイボタンを出すか。

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

	enemy_tracker = StageEnemyTrackerScript.new()
	enemy_tracker.name = "StageEnemyTracker"
	add_child(enemy_tracker)
	enemy_tracker.setup(self)
	enemy_tracker.enemy_defeated.connect(_on_enemy_defeated)
	enemy_tracker.all_enemies_defeated.connect(_on_all_enemies_defeated)
	enemies = enemy_tracker.enemies
	defeated_enemies = enemy_tracker.defeated_enemies
	stage_cleared = false
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
	stage_hud.set_clear_text(message)
	_shake_camera(16.0, 0.22)
	if not next_stage_path.is_empty():
			var tween := create_tween()
			tween.tween_interval(1.15)
			tween.tween_callback(func(): get_tree().change_scene_to_file(next_stage_path))

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
