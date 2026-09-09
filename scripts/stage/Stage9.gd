# 2026-08-19: SkullMonsterを人数土台へ集めて一斉に落とすステージ。
extends "res://scripts/stage/StageBase.gd"

var count_platform: Node # 5体到達で崩壊する人数土台。

# 共通初期化後、Stage9専用ギミックを接続する。
func _ready() -> void:
	super._ready()
	count_platform = get_node_or_null("CountBreakPlatform")
	if count_platform != null and count_platform.has_signal("collapsed"):
		count_platform.collapsed.connect(_on_count_platform_collapsed)

# Stage9用の暗い背景を作る。
func _build_world() -> void:
	var background := ColorRect.new()
	background.color = Color(0.045, 0.052, 0.078)
	background.size = Vector2(4200, 2200)
	background.position = Vector2(-1200, -760)
	background.z_index = -20
	add_child(background)

# 人数土台が崩れた瞬間に手応えを足す。
func _on_count_platform_collapsed(_current_count: int) -> void:
	shake_camera(14.0, 0.18)
	play_sfx(&"action_break_block")
