# 2026-06-23: Boarボス戦の意味イベントを差し替え可能なSE Cueへ接続する。
class_name BoarBossSfx
extends "res://scripts/boss/audio/BossBattleSfx.gd"

@export_group("Boar Actions")
@export_file("*.wav", "*.mp3", "*.ogg") var dash_path := "res://assets/sfx/boss/01_boar_dash.wav" # DASH実行開始音。
@export_file("*.wav", "*.mp3", "*.ogg") var smash_path := "res://assets/sfx/boss/02_boar_smash.wav" # SMASH実行開始音。
@export_file("*.wav", "*.mp3", "*.ogg") var damage_path := "res://assets/sfx/boss/03_boar_damage.wav" # 非致命ダメージ音。
@export_file("*.wav", "*.mp3", "*.ogg") var defeat_path := "res://assets/sfx/boss/04_boar_defeat.wav" # 撃破音。
@export_file("*.wav", "*.mp3", "*.ogg") var wall_impact_path := "res://assets/sfx/boss/05_boar_wall_impact.wav" # 最終壁への激突音。

@export_group("Falling Objects")
@export_file("*.wav", "*.mp3", "*.ogg") var falling_warning_path := "res://assets/sfx/boss/06_falling_object_warning.wav" # 落下開始の予告音。
@export_file("*.wav", "*.mp3", "*.ogg") var falling_combined_path := "res://assets/sfx/boss/07_falling_object_and_impact.wav" # 固定長演出用の予備音。
@export_file("*.wav", "*.mp3", "*.ogg") var falling_impact_path := "res://assets/sfx/boss/08_falling_object_impact_only.wav" # 着地フレームの衝撃音。

@export_group("Timing")
@export_range(0.0, 0.5, 0.01) var defeat_delay := 0.12 # 壁激突と撃破音を分離する遅延。

# 音源を登録し、Boarとギミックの意味イベントへ接続する。
func setup(boss: Node, falling_trap: Node, timed_trap: Node, final_wall: Node) -> void:
	_register_boar_cues()
	boss.action_started.connect(_on_action_started)
	boss.environment_damage_applied.connect(_on_environment_damage_applied)
	boss.boss_defeated.connect(_on_boss_defeated)
	falling_trap.fall_started.connect(_on_fall_started)
	falling_trap.landing_contact.connect(_on_landing_contact)
	timed_trap.fall_started.connect(_on_fall_started)
	timed_trap.landing_contact.connect(_on_landing_contact)
	final_wall.wall_contact.connect(_on_wall_contact)

# Inspectorで指定されたファイルを意味Cueへ登録する。
func _register_boar_cues() -> void:
	register_cue(&"dash", dash_path)
	register_cue(&"smash", smash_path, 0.0, true)
	register_cue(&"damage", damage_path, 0.0, true)
	register_cue(&"defeat", defeat_path, 0.0, true)
	register_cue(&"wall_impact", wall_impact_path, 0.0, true)
	register_cue(&"falling_warning", falling_warning_path)
	register_cue(&"falling_combined", falling_combined_path, 0.0, true)
	register_cue(&"falling_impact", falling_impact_path, 0.0, true)

# 実行開始した攻撃種別に対応するCueを鳴らす。
func _on_action_started(request: RefCounted) -> void:
	if request != null and request.action_id in [&"dash", &"smash"]:
		play_cue(request.action_id)

# 非致命ダメージだけ苦鳴Cueを鳴らす。
func _on_environment_damage_applied(_event: Dictionary, current_hp: int, _max_hp: int) -> void:
	if current_hp > 0:
		play_cue(&"damage")

# 致命打は壁音から少し遅らせて撃破Cueを鳴らす。
func _on_boss_defeated() -> void:
	play_cue(&"defeat", defeat_delay)

# 落下開始時に予告Cueを鳴らす。
func _on_fall_started() -> void:
	play_cue(&"falling_warning")

# 岩の着地結果に関係なく接地フレームで衝撃Cueを鳴らす。
func _on_landing_contact(_trap: Node, _impact_position: Vector2, _hit: bool) -> void:
	play_cue(&"falling_impact")

# 最終壁の接触フレームで専用Cueを鳴らす。
func _on_wall_contact(_wall: Node, _event: Dictionary, _impact_position: Vector2) -> void:
	play_cue(&"wall_impact")
