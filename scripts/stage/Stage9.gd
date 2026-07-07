# 2026-06-29: BoarにSMASH記憶を運ばせる記憶搬送路ステージ。
extends "res://scripts/stage/StageBase.gd"

# 共通初期化後、留め具破壊でBoar巡回路をCへ切り替える。
func _ready() -> void:
	super._ready()
	var latch := get_node_or_null("EditableGeometry/ActionBreakGroups/ActionBreakGroup_RouteLatch")
	var boar := get_node_or_null("BoarMonster")
	if latch != null and boar != null and boar.has_method("open_patrol_branch"):
		latch.broken.connect(func(_enemy: Node, _record: Resource): boar.open_patrol_branch())

func _build_world() -> void:
	var background := ColorRect.new()
	background.color = Color(0.052, 0.06, 0.082)
	background.size = Vector2(4200, 1800)
	background.position = Vector2(-1300, -620)
	background.z_index = -20
	add_child(background)
