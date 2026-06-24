# 2026-06-22: 5つの環境ダメージを段階的に学ぶBoarボス戦。
extends "res://scripts/stage/StageBase.gd"

const BossIntroPresenterScript := preload("res://scripts/stage/BossIntroPresenter.gd")
const BoarBossBattleScript := preload("res://scripts/boss/battle/BoarBossBattle.gd")

enum Stage10CameraMode { ARENA, PLAYER_FOLLOW }

@export_group("Boss Battle")
@export var boss_path := NodePath("BoarBoss") # 攻略対象BossBoar。
@export var falling_trap_path := NodePath("Gimmicks/FallingRockTrap") # 初回SMASH罠。
@export var timed_trap_path := NodePath("Gimmicks/TimedDropTrap") # 初回DASH罠。
@export var rock_a_path := NodePath("Gimmicks/RockA") # 左再利用岩。
@export var rock_b_path := NodePath("Gimmicks/RockB") # 右再利用岩。
@export var stopper_path := NodePath("Gimmicks/StopperTrap") # 中盤ストッパー。
@export var final_wall_path := NodePath("Gimmicks/FinalWall") # 5撃目の最終壁。
@export var boss_sfx_path := NodePath("BoarBossSfx") # Boar固有イベントとSEを接続する部品。
@export var boss_music_bus_path := NodePath("BossMusicBus") # ボス戦BGM専用EQを構築する部品。
@export var boss_camera_feedback_path := NodePath("BoarBossCameraFeedback") # SMASH専用カメラ反動を接続する部品。
@export var boss_impact_feedback_path := NodePath("BossImpactFeedback") # ギミック接触の停止と素材FXを接続する部品。
@export var boss_title := "BOSS_BOAR" # イントロ表示名。

@export_group("Boss Intro")
@export_range(0.75, 2.5, 0.05) var boss_intro_duration_scale := 2.05 # イントロ全体を8秒のファンファーレへ合わせる時間倍率。
@export_range(0.75, 2.0, 0.05) var boss_intro_boar_scale := 1.25 # イントロ内Boarの表示倍率。

@export_group("Boss Audio")
@export_file("*.ogg") var boss_intro_bgm_path := "res://assets/bgm/rebite_boar_intro_fanfare.ogg" # ボス紹介中のファンファーレ。
@export_file("*.ogg") var boss_battle_bgm_path := "res://assets/bgm/boar_boss_pressure_theme.ogg" # イントロ後のボス戦ループ。
@export var boss_battle_bgm_volume_db := -19.5 # 通常曲との平均音量差を補正したボス戦音量。

@export_group("Stage10 Camera")
@export var camera_mode := Stage10CameraMode.ARENA # 開始時のカメラモード。
@export var arena_camera_position := Vector2(640.0, 340.0) # ボスアリーナ全体を収める固定中心。
@export var arena_camera_zoom := Vector2(0.82, 0.82) # 全景モードの引き倍率。
@export var player_camera_zoom := Vector2(1.08, 1.08) # Player追従モードの倍率。

var boss: Node # 攻略対象BossBoar。
var boss_battle: Node # ボス戦専用フェーズ管理。
var boss_intro: Node # 時間倍率を調整できるボス紹介演出。
var boss_sfx: Node # Boar固有SEの差し替えと再生を担当する部品。
var boss_music_bus: Node # ボス戦BGM専用のAudio BusとEQを担当する部品。
var boss_camera_feedback: Node # Boar攻撃とカメラ反動を接続する部品。
var boss_impact_feedback: Node # ボスギミック接触のヒットストップを担当する部品。

# 共通更新後、選択中のStage10専用カメラを反映する。
func _process(delta: float) -> void:
	super._process(delta)
	if camera == null or camera_cinematic:
		return
	if camera_mode == Stage10CameraMode.ARENA:
		camera.global_position = arena_camera_position
		camera.zoom = arena_camera_zoom
	else:
		camera.global_position = player.global_position + normal_camera_offset
		camera.zoom = player_camera_zoom

# Cキーでアリーナ全景とPlayer追従を切り替える。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		camera_mode = Stage10CameraMode.PLAYER_FOLLOW if camera_mode == Stage10CameraMode.ARENA else Stage10CameraMode.ARENA
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

# ボスアリーナの暗い背景帯を生成する。
func _build_world() -> void:
	var background := ColorRect.new()
	background.color = Color(0.025, 0.031, 0.052)
	background.size = Vector2(3600, 1500)
	background.position = Vector2(-1200, -560)
	background.z_index = -20
	add_child(background)

# 通常ブリーフィングを使わず、ボス戦管理と専用イントロを開始する。
func _start_stage_briefing() -> void:
	boss = get_node_or_null(boss_path)
	var nodes := [
		boss,
		get_node_or_null(falling_trap_path),
		get_node_or_null(timed_trap_path),
		get_node_or_null(rock_a_path),
		get_node_or_null(rock_b_path),
		get_node_or_null(stopper_path),
		get_node_or_null(final_wall_path),
		get_node_or_null(boss_sfx_path),
		get_node_or_null(boss_music_bus_path),
		get_node_or_null(boss_camera_feedback_path),
		get_node_or_null(boss_impact_feedback_path),
	]
	if nodes.any(func(node): return node == null):
		push_error("Stage10 boss battle nodes are incomplete.")
		super._start_stage_briefing()
		return

	stage_hud.set_defeat_objective("目標：ボスを倒す", 0, boss.max_hp)
	stage_hud.prepare_persistent_hud(_resolved_stage_display_name(), "目標：ボスを倒す (0/%d)" % boss.max_hp)
	stage_hud.set_hud_text("A/D or ←/→: move   Space: jump   K: bite memory tag   C: camera   R: replay")

	boss_battle = BoarBossBattleScript.new()
	boss_battle.name = "BoarBossBattle"
	add_child(boss_battle)
	boss_battle.setup(self, boss, player, nodes[1], nodes[2], nodes[3], nodes[4], nodes[5], nodes[6])
	boss_battle.progress_changed.connect(_on_boss_progress_changed)
	boss_battle.battle_cleared.connect(_on_boss_battle_cleared)
	boss_sfx = nodes[7]
	boss_sfx.enabled = sfx_enabled
	boss_sfx.setup(boss, nodes[1], nodes[2], nodes[6])
	boss_sfx.important_sound_played.connect(_on_important_sfx_played)
	boss_music_bus = nodes[8]
	boss_camera_feedback = nodes[9]
	boss_camera_feedback.setup(self, boss)
	boss_impact_feedback = nodes[10]
	boss_impact_feedback.setup(self, boss, nodes[1], nodes[2], nodes[3], nodes[4], nodes[5], nodes[6])

	boss_intro = BossIntroPresenterScript.new()
	boss_intro.name = "BossIntroPresenter"
	add_child(boss_intro)
	boss_intro.setup(self, boss, boss_title, boss_intro_boar_scale)
	boss_intro.finished.connect(_on_boss_intro_finished)
	stage_bgm.play_track(boss_intro_bgm_path, false, bgm_volume_db)
	boss_intro.play(boss_intro_duration_scale)

# ボスの累積ダメージを右上HUDへ反映する。
func _on_boss_progress_changed(damage: int, max_damage: int) -> void:
	stage_hud.set_defeat_progress(damage, max_damage)

# イントロ終了時に常駐HUDと最初の攻略フェーズを開始する。
func _on_boss_intro_finished() -> void:
	boss_music_bus.setup()
	stage_bgm.set_output_bus(boss_music_bus.bus_name)
	stage_bgm.play_track(boss_battle_bgm_path, true, boss_battle_bgm_volume_db)
	stage_hud.show_persistent_hud(0.18)
	boss_battle.finish_intro()

# 5撃目の成立時に目標を達成表示へ変える。
func _on_boss_battle_cleared() -> void:
	stage_hud.set_defeat_progress(boss.max_hp, boss.max_hp)
	stage_hud.mark_objective_complete()

# 共通EnemyTrackerの1体表記でボス進捗を上書きせずクリアする。
func _on_all_enemies_defeated() -> void:
	if stage_cleared:
		return
	complete_stage()
