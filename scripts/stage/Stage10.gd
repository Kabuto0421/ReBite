# 2026-06-22: 大型Boarとの3ヒットボス戦ステージ。
extends "res://scripts/stage/StageBase.gd"

const BossIntroPresenterScript := preload("res://scripts/stage/BossIntroPresenter.gd")

@export_group("Boss Intro")
@export var boss_path := NodePath("BoarBoss") # クリア対象となるBossBoarのパス。
@export var boss_title := "BOSS_BOAR" # 青いバナーに表示するボス名。
@export var boss_command := "ボスを倒せ！！" # バナー滞在後に表示する命令。
@export var boss_banner_color := Color(0.035, 0.22, 0.62, 0.98) # ボスバナーの基調色。
@export_range(0.1, 2.0, 0.05) var boss_intro_enter_time := 0.45 # バナーが中央へ入る時間。
@export_range(0.1, 3.0, 0.05) var boss_intro_hold_time := 1.2 # ボス名を中央で見せる時間。
@export_range(0.1, 2.0, 0.05) var boss_intro_command_time := 0.7 # 命令を表示する時間。
@export_range(0.1, 2.0, 0.05) var boss_intro_exit_time := 0.35 # バナーが退場する時間。

var boss: Node # ステージクリア対象の大型Boar。
var boss_intro: Node # ボス専用イントロ表示部品。

# ボスアリーナの背景を生成する。
func _build_world() -> void:
	var background := ColorRect.new()
	background.color = Color(0.035, 0.045, 0.065)
	background.size = Vector2(3600, 1500)
	background.position = Vector2(-1200, -560)
	background.z_index = -20
	add_child(background)

# 通常命令の代わりにボス専用イントロと3ヒット目標を準備する。
func _start_stage_briefing() -> void:
	boss = get_node_or_null(boss_path)
	if boss == null:
		push_error("Stage10 boss was not found: %s" % boss_path)
		super._start_stage_briefing()
		return

	var max_hits: int = boss.max_hits
	stage_hud.set_defeat_objective("目標：ボスを倒す", 0, max_hits)
	stage_hud.prepare_persistent_hud(_resolved_stage_display_name(), "目標：ボスを倒す (0/%d)" % max_hits)
	if not boss.boss_health_changed.is_connected(_on_boss_health_changed):
		boss.boss_health_changed.connect(_on_boss_health_changed)

	boss_intro = BossIntroPresenterScript.new()
	boss_intro.name = "BossIntroPresenter"
	add_child(boss_intro)
	boss_intro.setup(self, boss, boss_title, boss_command, boss_banner_color)
	boss_intro.finished.connect(_on_boss_intro_finished)
	boss_intro.play(boss_intro_enter_time, boss_intro_hold_time, boss_intro_command_time, boss_intro_exit_time)

# ボスの残り耐久を右上の撃破進捗へ変換する。
func _on_boss_health_changed(current_hits: int, max_hits: int) -> void:
	stage_hud.set_defeat_progress(max_hits - current_hits, max_hits)

# イントロ退場後に常駐HUDを表示する。
func _on_boss_intro_finished() -> void:
	stage_hud.show_persistent_hud(0.0)
